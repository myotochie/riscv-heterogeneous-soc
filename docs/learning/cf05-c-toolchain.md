# CF-05.1 — Comprendre C, ISA, ABI et édition de liens

## Le compilateur vise une ISA, pas notre fichier decoder.sv

-march=rv64i autorise les opérations de la base RV64I complète. Le compilateur
ne sait pas que notre cœur n'en reconnaît que 21 formes. Un programme C peut
être parfaitement compilé et encore incompatible avec le RTL. Il faut
inspecter le code et garder le filtre de chargement, puis valider les effets
architecturaux lorsque le programme est réellement exécuté.

Exemple mesuré, arith32/O2 :

```asm
addw  a5,a0,a1
slliw a4,a0,3
subw  a1,a0,a1
srliw a0,a0,5
```

Les GPR physiques ont 64 bits, mais int a 32 bits dans LP64. Les opérations W
conservent le résultat bas 32 bits puis étendent son bit 31 vers le haut. Le
résultat ADDW 0x7fffffff + 1 doit devenir 0xffffffff80000000, pas
0x0000000080000000. À l'inverse, LWU charge un unsigned 32 bits et met les
bits hauts à zéro. Le résultat d'une opération et l'extension d'un load ne
sont pas interchangeables.

Dans probe_widen, GCC émet SLLI de 32 puis SRLI de 32 pour transformer une
valeur unsigned int reçue dans un registre en unsigned long. Dans
probe_signed_shift/O2, il peut employer SRAI plutôt que SRAIW en exploitant
les conventions de représentation des valeurs reçues. Une opération C ne
correspond donc pas nécessairement à une unique instruction fixe.

## Les appels relient ISA et conventions logicielles

calls/O2 montre une frame de 32 octets, SD de ra/s0/s1 et LD de restauration.
Les arguments et résultats passent notamment par a0/a1. Le processeur ne
sauvegarde pas automatiquement les callee-saved : c'est le code logiciel qui
le fait. L'appel utilise AUIPC/JALR ; la sauvegarde de ra protège le retour
quand une fonction appelle une autre fonction.

Observer ce code ne valide pas l'ABI dans notre CPU. Il faudra une pile
initialisée et alignée, des arguments déterministes, des registres sentinelles
à préserver et des vérifications après retour. Les phases IF/ID/EX/MEM/WB et
le forwarding devront traiter les nouveaux résultats comme les anciens.

## Pourquoi un lien réussi ne suffit pas

Un objet possède des relocations encore non résolues. Dans l'expérience, le
linker résout trois layouts RAM. function_pointer/medlow échoue sur une
adresse de fonction située à 0x80000000. LUI 0x80000 produit une valeur
sign-étendue 0xffffffff80000000, pas le PC positif 0x0000000080000000.
Le modèle medany emploie des références PC-relatives. Cependant, l'objet
late_globals/medany a un AUIPC que le linker remplace par LUI pour certaines
adresses basses, même avec les options no-relax demandées. Il faut lire les
instructions finales, pas uniquement les mnémoniques du source C ou de l'objet.

Le linker expérimental accepte data/BSS et un point d'entrée de fonction sans
startup. Cet ELF n'est pas une image CPU à exécuter telle quelle. Le linker
CF-04 et son garde de chargement restent volontairement plus stricts.

## Startup et mémoire Harvard

Le fetch voit une ROM de mots ; LD/SD voient une RAM séparée de 4 Kio. Une
adresse valide pour le fetch n'est pas automatiquement lisible par LD.
Un startup qui ferait LD depuis les initialiseurs stockés dans la ROM
provoquerait donc une faute données. Il faut choisir et documenter l'origine
réelle de .data : image RAM initialisée par l'hôte, zone source RAM pour une
copie, ou nouveau chemin matériel de lecture ROM.

## Expérience reproductible

```bash
BUILD_ROOT=/tmp/cf05-study bash verification/scripts/run_cf05_inventory.sh
```

Lire inspection/calls/O2/medany/object-disassembly.log et ses relocations,
puis late_globals/O2/medany/object-disassembly.log et
ram_000/linked-disassembly.log. Comparer ensuite les layouts ram_100 et
ram_800. Dans runtime_helpers, lire object-symbols.log et link.log : les
fonctions __muldi3/__udivdi3/__umoddi3 ne sont pas définies par le seul drapeau
freestanding. Le fichier gcc-libgcc-selection.log indique une archive
rv64i/lp64 disponible, mais son contenu et sa compatibilité ne sont pas validés
par ces inspections. N'exécuter aucune sonde comme programme bare-metal.

## Ce que je dois maîtriser

Concepts : LP64 et largeurs C, extension signée/non signée, modèles medlow et
medany, relocations, helpers runtime, séparation ISA/ABI, limites du mapping.
Fichiers : arith32.c, calls.c, function_pointer.c, late_globals.c, probe.ld,
inspect_c_toolchain.py, riscv_isa_inventory.py et la matrice de vérification.
Signaux à suivre plus tard sur RTL : immediate, alu_operand_a/b, alu_result,
uses_rs1/rs2, forwarding et wb_we/rd/data ; tailles/extensions en MEM.
Expériences : comparer O0/O2, objet/ELF, trois bases RAM et deux modèles de code.
Changer les entrées dans une copie dédiée, puis constater les nouvelles
instructions sans affirmer qu'elles sont exécutables sur le cœur.

### Cinq questions

1. Pourquoi un cœur RV64 a-t-il besoin d'instructions W pour le C ?
2. Pourquoi LUI ne produit-il pas forcément l'adresse positive attendue ?
3. Pourquoi LD/SD seuls ne suffisent-ils pas pour tous les tableaux C ?
4. Pourquoi notre startup ne peut-il pas simplement copier .data depuis la ROM ?
5. Pourquoi freestanding et l'absence de bibliothèques ne suppriment-ils pas tous les appels runtime ?

### Réponses expliquées

1. XLEN=64 ne change pas int en entier 64 bits. Les formes W réalisent les
   calculs 32 bits et leur extension de signe correcte ; elles devront aussi
   fournir ces valeurs étendues au forwarding avant le WB.
2. LUI construit une valeur 32 bits puis étend son signe. Le bit 31 à un
   remplit les 32 bits hauts de uns. La construction d'une adresse dépend donc
   du modèle de code, des relocations et du PC réellement choisi.
3. char, short et int occupent typiquement 1, 2 et 4 octets ici. Les accès
   doivent préserver les éléments voisins et appliquer l'extension adéquate.
   Remplacer un SB par un SD écraserait des octets sans rapport ; un LD peut
   aussi être désaligné ou dépasser la fin de la RAM là où un LB serait valide.
4. La ROM n'est pas connectée au chemin LD. Le fetch et les données n'ont pas
   une mémoire unifiée. Une initialisation hôte doit être nommée comme telle,
   et une copie réelle demande une source effectivement lisible par le CPU.
5. Le compilateur peut traduire une opération du langage en helper, par
   exemple multiplication ou division sans M. -nostdlib empêcherait les
   bibliothèques implicites au lien, pas la génération de ces appels. Dans
   notre expérience, GNU ld est invoqué directement sans librairie et les
   références restent visibles. Il faudra choisir une implémentation logicielle
   compatible ou évaluer M, puis tester les résultats sur la machine.
