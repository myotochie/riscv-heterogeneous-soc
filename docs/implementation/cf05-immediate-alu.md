# CF-05.2b — Implémentation OP-IMM

## Modifications RTL

### rtl/core/decoder/decoder.sv

Avant : seul funct3=000 de l'opcode 0x13 est légal. Après : case funct3
sélectionne ADD, SLT, SLTU, XOR, OR, AND ou un shift validé par instr[31:26].
Les opérations existent déjà dans core_pkg::alu_op_t. Pour SLLI le préfixe
doit être zéro ; pour les shifts droits, zéro sélectionne SRL et 010000 SRA.
Le décodage garde illegal_instr=1 par défaut et l'efface seulement sur les
formes reconnues. Les commandes d'écriture et de source immédiate sont
activées après validation :

```systemverilog
if (!illegal_instr) begin
    reg_write = 1'b1;
    alu_src   = 1'b1;
end
```

Le calcul existant de uses_rs1/uses_rs2 convient : OP-IMM légal consomme rs1,
jamais rs2. Aucun nouveau signal public, état ou registre séquentiel.
Les commandes mémoire/CSR/MRET restent à zéro pour cette famille.

### rtl/core/rv64_datapath.sv

Le module pédagogique sans PC utilisait une liste R-type/OP-IMM, alors que son
commentaire promet le contrat historique R/ADDI. L'élargissement du décodeur
aurait accepté silencieusement les huit nouvelles formes dans ce module.
Le filtre exige maintenant instr[14:12]==000 pour l'opcode 0x13. Cela conserve
son comportement antérieur ; le décodeur du pipeline n'est pas restreint.
Le test dédié vérifie que les instructions rejetées ne modifient pas x5.

### Modules réutilisés sans modification

- imm_gen.sv : extension du signe des 12 bits I ;
- alu.sv : opérations existantes, shifts par b[5:0] ;
- execute_stage.sv : rs1 forwardé et sélection immédiate en B ;
- registres du pipeline, unités de hazards/forwarding, WB : disponibilité,
  priorité EX/MEM, x0 et annulations inchangées.

Le matériel reste combinatoire en ID/EX et enregistré par les fronts montants
existants. Aucune nouvelle latence, unité multicycle ou interface mémoire.
Aucune synthèse n'est effectuée pour qualifier fréquence ou ressources.

## Sources de vérification

- verification/unit/immediate_alu/tb_immediate.cpp : compose le vrai décodeur,
  imm_gen, EX et hazard_detection via upper_probe.sv existant. Le nom historique
  du wrapper U ne limite pas ses ports à U ; aucun changement de ce wrapper.
  Oracle C++ indépendant pour le signe, l'ordre signé et les shifts droits.
- tb_teaching_contract.cpp : initialise x5=17 puis essaie chacune des huit
  familles ; illegal doit rester vrai et une lecture ultérieure retrouve 17.
- make_programs.py : huit fixtures assembleur produisant ELF/BIN/HEX et
  attentes WB explicites. Il ne convertit ni n'exécute des sondes C.
- verification/integration/tb_immediate_pipeline.cpp : driver du vrai pipeline,
  lecture pré-front des écritures WB, compteurs hazards/bypasses/traps/MRET et
  injection stall/flush/reset ; même méthode d'observation que le lot U.
- run_immediate_alu.sh : compile les deux tops unitaires et un top pipeline,
  puis relance ce dernier dans un processus distinct par fixture/mode.
  Les images sont remplacées seulement entre simulations.

Dans data, l'immédiat XORI 13 ressemble à rs2=x13 après LD x13 mais rs1=x9 :
le driver exige absence de stall et vérifie que ce cas a réellement été vu.
Le cas LD x24→ANDI x25 doit au contraire produire exactement un stall.
Le test consumers utilise des bases non nulles et initialisées, notamment
SLLI x5,x5,6 produisant 64 juste avant LD ; une ancienne base 1 provoquerait
une erreur observable. Il vérifie aussi le résultat OP-IMM consommé en EX
par une branche (ancien x2=-1, nouveau x2=0) et le forwarding simultané
adresse/donnée vers SD. Cette ancienne valeur distincte rend observable une
absence de bypass vers la branche.

## Adaptation des anciens tests

verification/unit/decoder/tb_decoder.cpp rejetait le mot SLLI 42, auparavant
non implémenté. Le même mot devient un test positif de shamt[5]. Un cas
supplémentaire SLLI avec immédiat brut 106 vérifie un préfixe réellement
réservé. Le test négatif n'est donc pas supprimé pour obtenir un PASS : la
frontière légale a changé et un contrôle de rejet pertinent reste présent.

## Filtre d'images et inventaire

Après les tests RTL ciblés, scripts/elf_to_hex.py accepte les nouveaux
funct3 OP-IMM, avec les mêmes restrictions de préfixe de shifts. Les tests
ELF ajoutent dix mots légaux et quatre mots réservés. Les rejets ADDIW, MUL,
LW, ECALL, JALR mal formé, etc. restent actifs.

scripts/riscv_isa_inventory.py connaissait déjà les noms et encodages de ces
instructions. Leur statut passe à présent ; les lignes citent les nouveaux
bancs comme preuves. Le test d'inventaire attend 31 formes présentes et ajoute
une vérification des 32768 couples imm12/funct3, dont 24768 sont acceptés.
L'oracle GAS des 52 formes reste indépendant du RTL et du filtre Python.

## Commandes et dépendances

```bash
VERILATOR=/opt/verilator-modern/bin/verilator \
BUILD_ROOT=/tmp/cf05-immediate-check bash verification/scripts/run_immediate_alu.sh
BUILD_ROOT=/tmp/cf05-immediate-inventory bash verification/scripts/run_cf05_inventory.sh
```

Les dépendances restent les outils existants : Verilator 5.040, GNU GCC
10.2.0 et Binutils 2.35.1, Python standard et compilateur C++ hôte. Leurs
origines/licences sont décrites par CF-04 et CF-05.1 ; aucun nouvel outil ou
paquet système n'est installé. Le test combinatoire est aussi compilé avec
Verilator 4.038, sans étendre cette revendication à toute la régression.

README, matrice historique, journal et vue d'ensemble indiquent le nouvel
état. Les documents CF-05.1 et CF-05.2a conservent leurs mesures historiques,
avec renvoi vers ce lot pour l'état courant. La ROM des programmes 0 à 47
et le programme assembleur CF-04 ne sont pas modifiés.
