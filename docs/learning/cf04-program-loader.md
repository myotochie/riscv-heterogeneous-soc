# Comprendre le fetch et le chargement HEX

## Du PC à l'instruction

Le PC est une adresse en octets. La ROM contient ici des mots de 32 bits :
quatre octets par entrée. À la base 0x80000000, le PC 0x8000000c sélectionne
l'entrée 3. Utiliser directement les bits bas du PC sans vérifier les bits
hauts ferait aliaser plusieurs régions de l'espace RV64.

La ROM répond pendant le cycle. Au front suivant, IF/ID mémorise ensemble PC,
instruction et validité. Le PC passe alors à son successeur ou à une cible.
Il est normal d'observer simultanément le nouveau PC et l'ancienne instruction
dans IF/ID : les deux signaux ne décrivent pas le même instant de fetch.

| Front | Événement | PC après front | IF/ID après front |
|---|---|---|---|
| R | reset actif | 0x80000000 | invalide |
| F1 | premier fetch accepté | 0x80000004 | mot 0, PC 0x80000000 |
| F2 | deuxième fetch accepté | 0x80000008 | mot 1, PC 0x80000004 |
| F3 | PC et IF/ID stallés | inchangé | inchangé |
| F4 | redirection avec flush | cible | invalide |
| F5 | reprise | cible + 4 | instruction de la cible |

Ce tableau décrit les commandes d'un fetch isolé ; le pipeline ajoute ses
hazards et décisions de transfert. Une ROM synchrone déplacerait la réponse
d'un cycle, ce qui exige de transporter son PC et d'annuler une réponse qui
reviendrait après un flush.

## Endianness et représentation textuelle

Le mot 00500093 code ADDI x1,x0,5. Sa représentation binaire little-endian est
93 00 50 00. Le fichier HEX de ce jalon contient le mot 00500093, pas quatre
lignes d'octets. Le parseur exige huit caractères pour empêcher une image
d'octets de passer silencieusement pour une suite d'instructions.

Un ELF apporte sections, adresses et point d'entrée. $readmemh ne connaît
rien de cela. Lui fournir directement un ELF ne charge pas un programme.
La future conversion devra vérifier placement, taille et sous-ensemble ISA.

## Simulation et architecture

$fatal est un arrêt du simulateur ; il n'écrit aucun CSR du processeur. Une
exception architecturale demande au contraire d'identifier l'instruction
fautive, de purger les plus jeunes et de préserver les plus anciennes.
CF-04.2 diagnostique seulement les accès invalides réellement acceptés par
IF/ID. Cela évite qu'un ancien PC abandonné pendant un flush provoque un faux
échec. Le signal address_fault de la ROM n'est pas un trap.

Les mots non fournis mais encore dans la capacité valent NOP. L'accès hors
capacité est distinct d'un accès après le dernier mot du fichier. Une boucle
qui tombe dans le remplissage peut ne jamais produire de faute : signature
et limite de cycles sont donc nécessaires.

## Exercice reproductible

Exécuter run_instruction_memory.sh avec un BUILD_ROOT dans /tmp. Lire le
fichier instructions.hex après la suite : il contient le smoke du pipeline,
pas les premiers mots de la ROM unitaire. Comparer ces huit mots au tableau
du document d'implémentation. Relancer le modèle pipeline après avoir changé
le calcul addi x5,x5,2 en addi x5,x5,3 : le banc doit refuser la valeur 43.
Effectuer cette expérience dans un nouveau répertoire, sans altérer les
preuves de validation déjà conservées. Cette variante n'est pas un résultat
rapporté tant qu'elle n'a pas été exécutée.

Le smoke initialise x2 et x5, appelle une fonction, écrit 42 en RAM puis le
relit dans x10. Aucun état initial de GPR autre que x0 n'est supposé. Le banc
contrôle le lien et le résultat, pas seulement l'avancement du PC.

## Ce que je dois maîtriser

Concepts : adresse octet contre index mot ; lecture combinatoire ; capture au
front ; validité et annulation ; paramètres d'élaboration ; HEX contre ELF ;
diagnostic de simulation contre trap matériel.

Fichiers à relire : instruction_memory.sv, fetch_path.sv, pc.sv,
pipeline_if_id.sv, tb_external_fetch.cpp et tb_external_program.cpp.
Signaux à suivre : pc_value, offset, address_fault, instr_mem_data, selected_instr_data,
if_id_pc/instr/valid, flush, stall_if_id, wb_we/rd/data.
Expériences : lecture de la première/dernière entrée, adresse base+2, image
vide, redirection avec flush, signature fausse et délai maximal.

### Cinq questions

1. Pourquoi soustraire la base avant de diviser le PC par quatre ?
2. Comment distinguer HEX de mots et HEX d'octets pour 00500093 ?
3. Pourquoi une ROM synchrone complique-t-elle un saut ?
4. Pourquoi le remplissage NOP ne suffit-il pas à valider un programme ?
5. Pourquoi -march=rv64i ne garantit-il pas l'exécution sur ce cœur ?

### Réponses expliquées

1. Le tableau commence à l'indice zéro alors que le PC commence à une adresse
   non nulle. La soustraction convertit une adresse architecturale en offset.
   Le contrôle 64 bits empêche les alias hors région et précède l'indexation.
2. HEX de mots : un jeton 00500093. HEX d'octets little-endian : 93, 00, 50,
   00 dans cet ordre. La mémoire cible et le convertisseur fixent le sens.
3. La réponse arrive après la requête. Un saut peut rendre cette réponse
   obsolète ; il faut mémoriser le PC demandé et annuler le bon retour.
4. Un programme erroné peut traverser des NOP sans produire la signature.
   La vérification demande des effets observables et une borne temporelle.
5. Ce drapeau autorise toutes les instructions RV64I, alors que notre
   implémentation est partielle. LUI/AUIPC, formes W et plusieurs opérations
   immédiates ou mémoire manquent encore. Il faut examiner le code généré.

## CF-04.3/4 — Comprendre la chaîne assembleur et ELF

### Pourquoi un ELF avant le HEX ?

L'assembleur connaît les instructions et produit un objet avec symboles et
relocations. Dans jal x1,function, la distance finale dépend du placement.
Le linker place le texte et résout cette relocation. Un objet .o n'est donc
pas encore une image d'instructions prête pour notre reset PC.

Un ELF lié conserve machine, classe, endianness, entrée, segments, sections
et symboles. Le CPU ne lit aucune de ces structures : la ROM voit seulement
les mots HEX. C'est le logiciel hôte qui vérifie que l'image correspond au
matériel avant de lui retirer ses métadonnées.

### Segments, sections et adresses

Une section décrit une partie du fichier destinée à l'édition de liens et à
l'analyse. Un PT_LOAD décrit une plage à placer en mémoire. Le convertisseur
utilise les segments pour le placement, et vérifie les sections allouées pour
refuser données/BSS et code mal mappé. Additionner des sections sans conserver
leurs adresses supprimerait les trous et déplacerait les cibles de saut.

VMA et LMA doivent ici être égales : pas de MMU et pas de copie de code au
startup. e_entry doit valoir le reset matériel, car notre PC ne lit pas l'ELF.
.memsz supérieur à filesz annoncerait une zone à initialiser sans octets dans
le fichier, typiquement BSS. Ce jalon la refuse ; CF-05 devra définir son startup.

### Expérience reproductible

Exécuter build_baremetal.sh avec BUILD_DIR=/tmp/cf04-study. Lire
program.readelf.log et program.disassembly.log, puis comparer program.hex au
tableau de l'implémentation. La cible function est 0x80000018 ; le lien est
0x8000000c. Les octets BIN de la première instruction sont 13 01 00 04,
alors que le mot HEX est 04000113.

Lancer ensuite run_baremetal_program.sh. Le banc attend les écritures x2=64,
x5=40, x1=lien, x5=42 et x10=42. La séquence complète détecte notamment une
exécution supplémentaire de la fonction sur un mauvais chemin. Le JAL final
continue de parcourir le pipeline : « fin » signifie que le banc a observé
les résultats et une boucle stable, pas que le matériel possède un HALT.
La fonction utilise x5 comme résultat temporaire ; ce n'est pas une validation
générale de l'ABI ou des appels imbriqués.

### Ce que je dois maîtriser pour ce jalon

Concepts : objet relogeable, symbole, relocation, édition de liens, ELF64,
PT_LOAD, VMA/LMA, code contre données, relaxation et validation du sous-ensemble.
Fichiers : start.S, link.ld, elf_to_hex.py, build_baremetal.sh,
tb_elf_to_hex.py et tb_baremetal_program.cpp. Signaux : wb_we/rd/data,
mem_wb_valid/pc/instr et trap_valid_o. Expériences : consulter les deux vues
readelf/objdump, ajouter une .data puis constater le refus, ajouter une
instruction non implémentée puis constater le refus du convertisseur. Faire
ces expériences dans une copie dédiée, pas dans les sources validées.

### Cinq questions — chaîne logicielle

1. Que contient un ELF qu'un BIN ne contient plus ?
2. Pourquoi le point d'entrée doit-il correspondre au reset PC ?
3. Pourquoi désassembler après l'édition de liens ?
4. Comment convertir quatre octets little-endian en un mot HEX ?
5. Pourquoi Binutils suffit-il pour ce premier programme ?

### Réponses — chaîne logicielle

1. L'ELF conserve notamment adresses, entrée, segments, sections et symboles.
   Le BIN est une suite d'octets sans ce contrat ; son placement doit être connu.
2. Le matériel redémarre à une constante. Il n'analyse pas e_entry ; le build
   impose l'égalité au lieu d'espérer qu'un point d'entrée arbitraire soit suivi.
3. Le linker résout les relocations et peut transformer du code par relaxation.
   Le désassemblage final montre les instructions effectivement chargées.
4. Pour 13 01 00 04, le mot est 0x04000113. Le premier octet occupe les bits
   faibles ; la ligne HEX représente le mot et non quatre jetons d'octets.
5. Le source est déjà en assembleur. as et ld produisent le programme ; les
   autres outils permettent extraction et inspection. GCC sert à compiler C
   et demanderait de contrôler un ensemble d'instructions et un startup plus larges.
