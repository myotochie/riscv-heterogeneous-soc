# CF-05.2b — Comprendre les opérations immédiates RV64

## Pourquoi étendre le décodage sans ajouter d'ALU ?

ADD/SLT/SLTU et les fonctions logiques/shifts existent pour les instructions
registre-registre. Une instruction immédiate change la provenance de B, pas
la fonction mathématique. ID sélectionne la même opération et alu_src=1 ;
EX lit rs1 forwardé et l'immédiat signé au lieu d'un registre rs2. La fonction
ALU reste commune, ce qui concentre ses règles de largeur et de signe.

Les bits 24:20 ressemblent à un indice rs2 quand on lit le mot comme un
format R. Dans OP-IMM, ils appartiennent à l'immédiat ou au shamt. Un hazard
sur ces bits serait artificiel. En revanche, un load écrivant le vrai rs1
exige une bulle lorsque la donnée ne sera disponible qu'après MEM.

## Signé, non signé et extension

L'immédiat est construit avant de choisir l'interprétation de comparaison.
SLTI compare deux nombres signés. SLTIU compare les mêmes vecteurs 64 bits
comme nombres non signés. -1 est donc 0xffffffffffffffff dans les deux cas,
mais représente -1 ou 2^64-1 selon l'opération.

Pour rs1=0x8000000000000000 et imm=-2048 :

| Opération | Interprétation | Résultat |
|---|---|---|
| SLTI | -2^63 < -2048 | 1 |
| SLTIU | 2^63 < 2^64-2048 | 1 |
| Comparaison fautive avec extension zéro | 2^63 < 2048 | 0 |

La même extension vaut pour les opérations logiques : XORI -1 inverse tous
les 64 bits ; ANDI -1 les conserve ; ORI -2048 force les bits hauts à un.
Le suffixe U n'autorise donc pas à changer imm_gen.

## Shamt RV64 et signe du résultat

Un registre de 64 bits nécessite six bits de quantité de décalage. SLLI 32
et SLLI 63 ont instr[25]=1 tout en étant légaux. Pour les shifts, instr[31:26]
code la famille ; tester sept bits fixes produirait une erreur RV32/RV64.
Les quantités 64 et plus ne sont pas des shamt immédiats RV64I légaux : ces
bits appartiendraient à un préfixe réservé, pas à un shift modulo 64 accepté
par le décodeur. L'ALU masque les quantités après ce contrôle de légalité.

Pour a=0x8000000000000000 : SRLI 63 produit 1 ; SRAI 63 produit -1 car le
bit de signe est répliqué. SLLI 63 appliqué à 1 construit ce bit haut.
Pour un shift zéro, les trois opérations rendent la valeur inchangée.

## Exemple assembleur reproductible

```asm
addi  x1,x0,-1      # fff00093 : x1 = ffffffffffffffff
slti  x2,x1,0       # 0000a113 : x2 = 1
slli  x3,x2,63      # 03f11193 : x3 = 8000000000000000
srli  x4,x3,63      # 03f1d213 : x4 = 1
srai  x5,x3,63      # 43f1d293 : x5 = ffffffffffffffff
sltiu x6,x3,-2048   # 8001b313 : x6 = 1
```

Aucune valeur initiale de x1..x6 n'est requise : chaque source est écrite avant
usage. Ce sous-ensemble de cas figure dans la fixture data, avec d'autres
numéros de registres pour poursuivre les tests. Les sources assembleur et les
HEX générés par GNU as/ld sont conservés dans programs sous BUILD_ROOT :

```bash
VERILATOR=/opt/verilator-modern/bin/verilator \
BUILD_ROOT=/tmp/cf05-immediate-check bash verification/scripts/run_immediate_alu.sh
```

La sortie ciblée indique 31 écritures exactes pour data et un seul load-use
stall. Les fixtures attendent des résultats explicites ; elles n'exécutent
pas des sondes C ni un modèle de référence Spike.

## Fronts et forwarding : expérience à suivre

Dans data, XORI écrit x22=1, puis XORI écrit x22=2 et ANDI lit x22.
Lorsque ANDI arrive en EX, le producteur récent est en EX/MEM et l'ancien en
MEM/WB. Une priorité inversée donnerait 1 plutôt que 2. Le tableau de cycles
de l'architecture décrit le chemin sans stall. WB n'a pas besoin d'avoir déjà
écrit le banc pour que le consommateur utilise le bon résultat.

Autre cas : LD x13 suivi de XORI x8,x9,13. Le 13 immédiat ressemble au champ
rs2, mais XORI n'utilise que x9. Le compteur de hazard ne doit pas augmenter.
LD x24 suivi d'ANDI x25,x24,255 doit au contraire intercaler une bulle.
Les deux scénarios sont présents, pour distinguer suppression d'un faux
hazard et suppression erronée d'une dépendance réelle.

## Annulation et précision

Au trap du LD désaligné, une XORI plus ancienne est en WB et doit écrire,
tandis qu'une SLLI jeune en EX doit être annulée. La priorité ne consiste pas
à bloquer indistinctement toutes les écritures. MRET retraité doit également
annuler les opérations jeunes déjà en MEM/EX. Stall tient les registres du
pipeline et supprime les commits, puis la reprise ne doit pas dupliquer WB.

Une instruction réservée est différente d'une instruction légale annulée.
Le décodeur marque la première illégale ; le contrôle de validité élimine la
seconde. Dans le cœur actuel, l'instruction illégale reste neutralisée sans
trap général : il faut connaître cette limite pour expliquer la conformité.

## Ce qu'il faut maîtriser

Concepts : immédiat signé, ordre signé/non signé, funct6 et shamt[5], bypass,
hazard réel/faux, rd=x0, annulation et ordre des instructions au trap.

Fichiers à relire : decoder.sv, imm_gen.sv, alu.sv, execute_stage.sv,
forwarding_unit.sv, hazard_detection_unit.sv et tb_immediate_pipeline.cpp.
Suivre alu_op, alu_src, uses_rs1/2, immediate_in, forward_a/b, id_ex_valid,
id_ex_illegal_instr, wb_we, trap_valid_o et mret_retire. Le datapath pédagogique
conserve séparément R/ADDI : suivre son filtre supported_opcode.

Expériences : comparer SLLI 31/32/63 ; comparer SRLI et SRAI sur le bit 63 ;
exécuter SLTIU avec -2048 ; suivre les deux écritures x22 ; observer les deux
hazards distincts ; retrouver XORI ancienne au trap et l'absence de SLLI jeune.

### Cinq questions techniques

1. Pourquoi SLTIU étend-il son immédiat avec signe ?
2. Pourquoi vérifier funct7 comme en RV32 rejetterait-il SLLI 42 ?
3. Comment distingue-t-on SRLI et SRAI sur une valeur négative ?
4. Pourquoi les bits du shamt ou de l'immédiat ne constituent-ils pas rs2 ?
5. Comment vérifier qu'une instruction annulée n'a pas écrit un résultat ?

### Réponses expliquées

1. La formation de l'immédiat I est commune et précède l'interprétation des
   opérandes. U rend la comparaison non signée ; un imm négatif devient donc
   un grand seuil non signé, pas une petite constante de douze bits.
2. 42 vaut 101010 en binaire : shamt[5]=1 occupe instr[25]. Ce bit appartient
   à funct7 si on regarde sept bits, mais ne fait pas partie du préfixe fixe
   RV64. Il faut tester instr[31:26].
3. SRLI remplit les bits hauts avec zéro, SRAI avec le signe de rs1. Décaler
   le seul bit 63 de 63 places donne respectivement 1 et tous les bits à un.
4. Le format de l'opcode définit les sources. OP-IMM n'a qu'un registre source ;
   uses_rs2 doit être faux même si les bits bruts correspondent au rd d'un load.
5. Observer la séquence WB entière, pas seulement l'état final, et vérifier
   que le stimulus d'annulation a réellement eu lieu. Pour les traps, vérifier
   aussi les métadonnées et préserver les écritures plus anciennes autorisées.
