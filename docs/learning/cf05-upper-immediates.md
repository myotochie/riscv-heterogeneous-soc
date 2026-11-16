# CF-05.2a — Comprendre et défendre LUI/AUIPC

## Pourquoi deux instructions pour construire des adresses ?

Une instruction RISC-V occupe ici 32 bits. Elle ne peut pas transporter
une constante arbitraire de 64 bits avec son opcode et rd. Le format U réserve
20 bits pour une valeur placée en haut d'un mot 32 bits, les 12 bits bas étant
nuls. ADDI peut compléter les bits bas. AUIPC ajoute plutôt cette valeur au PC
de l'instruction et sert notamment aux adresses relatives et aux appels avec
JALR. Les relocations du linker déterminent les immédiats d'une paire réelle.
Ce lot ne réimplémente pas les relocations dans le RTL.

## Signe et largeur, exemple reproductible

```asm
lui   x5,0x80000  # mot 800002b7 -> ffffffff80000000
auipc x6,0x80000  # mot 80000317 à PC 80000004 -> 0000000000000004
auipc x7,0xfffff  # mot fffff397 à PC 80000008 -> 000000007ffff008
```

Les trois valeurs attendues sont contrôlées dans le scénario edges. La seconde
addition vaut 0x80000004 + (-0x80000000). Le résultat n'est pas 0x100000004 :
la valeur U est signée avant la somme 64 bits. Pour un PC au-delà de 4 Gio,
AUIPC doit également préserver les bits hauts du PC ; le test unitaire utilise
0x1234567880000004 et le débordement modulo 2^64.

Commande :

```bash
VERILATOR=/opt/verilator-modern/bin/verilator \
BUILD_ROOT=/tmp/cf05-upper-check bash verification/scripts/run_upper_immediates.sh
```

Voir programs/edges.S, programs/edges.hex et programs/edges.expected et la ligne PASS U pipeline edges. Les registres source n'ont
aucune valeur initiale requise : ces trois instructions ne les lisent pas.

## Du décodeur au front d'horloge

ID décode opcode, rd et immédiat ; ID/EX les capture avec le PC. En EX,
alu_src sélectionne l'immédiat comme B et le nouveau mux choisit zéro ou PC
comme A. ADD calcule le résultat ; EX/MEM le capture au front montant.
L'instruction suivante peut déjà le lire par forwarding pendant son EX, sans
attendre que WB écrive le banc. MEM/WB le capture ensuite et WB qualifie
l'écriture, avec rd non nul, valid et absence d'annulation.

Considérer deux LUI successives vers x22, suivies d'ADD lisant x22 : pendant
EX de l'ADD, EX/MEM porte la valeur récente et MEM/WB l'ancienne. La priorité
EX/MEM est donc essentielle. Dans le test data, ADD doit observer 8192 et non
4096. SD utilise aussi forwarded_rs2 pour la donnée à écrire, même quand
l'ALU choisit son immédiat pour calculer l'adresse.

## Un faux hazard n'est pas une dépendance

LUI x14,0x68 a le mot 00068737. Les bits 19:15 valent 13 ; ils ne désignent
pas x13. Un LD x13 juste avant ne doit pas bloquer cette instruction. L'unité
de hazards consulte uses_rs1/uses_rs2, pas seulement les indices bruts. Un
mux de forwarding peut sélectionner des données parasites à EX sans erreur
si la sélection finale d'opérandes U les ignore. Les deux niveaux sont testés.

## Annuler et préserver dans le même cycle

Lors d'un défaut LD en MEM, une U plus jeune en EX est supprimée, mais une U
plus ancienne en WB reste autorisée. « Tout arrêter » pourrait perdre une
écriture architecturale légitime. De même, un MRET retraité doit supprimer les
U qui l'ont suivi dans le pipeline. Le test vérifie les valeurs et que les
collisions ont effectivement eu lieu. Un test de valeur finale seul pourrait
manquer une écriture parasite ensuite écrasée ; une séquence WB exacte évite
ce défaut d'observation pour les registres testés.

## Ce qu'il faut maîtriser

- Format U, extension de signe, addition modulo XLEN et PC propre.
- Sources architecturales versus champs binaires ressemblant à des registres.
- Disponibilité en EX/MEM et priorité des bypasses.
- Qualification WB, x0, annulation et ordre des exceptions.
- Différence entre test combinatoire complet du payload et preuve du pipeline.

Fichiers à relire : decoder.sv, imm_gen.sv, execute_stage.sv,
forwarding_unit.sv, rv64_pipeline.sv et tb_upper_pipeline.cpp. Signaux à suivre :
uses_rs1/2, id_ex_pc, alu_operand_a/b, ex_mem_alu_result, forward_a/b,
mem_wb_alu_result, wb_we, trap_valid_o et mret_retire.

Expériences : exécuter edges ; suivre LUI/ADDI cycle par cycle ; comparer les
deux valeurs x22 ; inspecter le seul stall de data ; retrouver l'écriture x5
simultanée au trap et l'absence de x7/x8. Comparer les muxes dédiés aux U
avec une alternative à opérations ALU dédiées : complexité de contrôle plus
large, disponibilité similaire en EX, bénéfices physiques non mesurés.

### Cinq questions techniques

1. Pourquoi LUI 0x80000 donne-t-il ffffffff80000000 et non 0000000080000000 ?
2. Quel PC AUIPC doit-il utiliser, et pourquoi le PC de fetch serait faux ?
3. Comment un load peut-il sembler créer un hazard avec LUI sans dépendance réelle ?
4. Pourquoi EX/MEM doit-il gagner sur MEM/WB lorsque les deux rd correspondent ?
5. Au trap d'un LD, pourquoi peut-on écrire une U ancienne et supprimer une U jeune ?

### Réponses expliquées

1. Le format construit un mot 32 bits dont le bit 31 vaut un. RV64 étend son
   signe sur les 32 bits hauts. L'extension zéro donnerait une autre valeur.
2. Le PC capturé avec AUIPC dans ID/EX. Fetch a avancé et peut être arrêté ou
   redirigé ; son PC ne représente pas la position de l'instruction en EX.
3. Les bits immédiats peuvent coïncider avec l'indice du registre chargé.
   uses_rs1/2 faux empêchent le stall ; la sélection U à EX ignore le bypass.
4. EX/MEM contient le producteur le plus récent dans ce pipeline en ordre.
   Choisir MEM/WB prendrait une valeur ancienne encore en cours de WB.
5. Les effets plus anciens précèdent architecturalement le défaut et doivent
   rester visibles. Les instructions jeunes n'ont pas le droit de modifier
   l'état après ce défaut ; les annulations doivent respecter cet ordre.
