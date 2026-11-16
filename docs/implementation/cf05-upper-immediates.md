# CF-05.2a — Implémentation des immédiats U

## RTL : trois changements locaux

### rtl/core/decoder/decoder.sv

Avant : opcodes 0x37 et 0x17 illégaux. Après : ils activent reg_write et alu_src
avec l'addition par défaut et sont légaux pour chaque payload U. Aucun contrôle
mémoire, CSR ou MRET n'est activé. Le calcul final uses_rs1 exclut explicitement
les deux opcodes ; uses_rs2 reste faux puisque ces opcodes n'appartiennent pas
aux familles R, SD ou branches. Les indices bruts restent extraits des bits de
l'instruction, mais ne créent pas de dépendance.

### rtl/core/imm_gen/imm_gen.sv

Un cas U précède les cas S/I existants :

```systemverilog
// Le bit 31 est le signe de la valeur 32 bits déjà décalée.
imm = {{32{instr[31]}}, instr[31:12], 12'b0};
```

Le résultat est combinatoire et ne possède aucun état. Les immédiats I/S
conservent leur logique précédente. Aucun immediate U non signé n'est utilisé.

### rtl/core/execute/execute_stage.sv

Une variable combinatoire alu_operand_a est ajoutée :

```systemverilog
case (instr_in[6:0])
    7'b0110111: alu_operand_a = 64'b0;
    7'b0010111: alu_operand_a = pc_in;
    default:   alu_operand_a = forwarded_rs1;
endcase
```

Le port a de l'ALU reçoit cette variable. Son entrée b conserve la sélection
alu_src entre immediate_in et forwarded_rs2. forwarded_rs1_out reste intact,
ainsi que le remplacement du résultat par PC+4 pour JAL/JALR et les gardes
valid/illegal. Aucun signal enregistré, port public ou état séquentiel n'est
ajouté. Les registres existants capturent les résultats aux fronts montants.

## Vérification et outillage

- upper_probe.sv : composition de vérification du vrai décodeur, imm_gen,
  execute_stage et hazard_detection_unit. Ce wrapper n'est pas un module CPU.
- tb_upper.cpp : oracle numérique indépendant pour l'immédiat et la somme ;
  tous les payloads U et matrice de PC 64 bits, rd et sélections de bypass.
- make_programs.py : sources assembleur générées avec attentes explicites,
  assemblées et liées par GNU Binutils ; ELF/BIN/HEX et attentes conservés
  dans le build. Les programmes n'utilisent que des instructions supportées.
- tb_upper_pipeline.cpp : séquence des écritures WB observée avant chaque front,
  traps, stalls, collisions et compteurs de couverture des scénarios.
- run_upper_immediates.sh : une compilation unitaire, une du pipeline externe,
  puis réutilisation du modèle dans des processus séparés pour chaque image.
  Le fichier d'image est remplacé seulement entre deux simulations.

Après validation RTL ciblée, elf_to_hex.py accepte les deux opcodes ; le test
ELF remplace leur ancien rejet par des tests d'acceptation. Les autres rejets
(ADDIW, MUL, LW, ECALL, mauvais JALR, etc.) restent applicables.
La matrice dynamique et ses tests passent à 23 formes, avec références vers
les nouveaux tests U. Les résultats CF-05.1 à 21 formes restent des mesures
historiques, pas une description du nouvel état.

## Reproduction et lecture du code

```bash
VERILATOR=/opt/verilator-modern/bin/verilator \
BUILD_ROOT=/tmp/cf05-upper-check \
bash verification/scripts/run_upper_immediates.sh
```

Lire les trois modules RTL dans l'ordre décodeur → immédiat → EX, puis suivre
ex_mem_alu_result, le forwarding et mem_wb_alu_result dans rv64_pipeline.sv.
Aucun script ne nécessite une installation système supplémentaire. Les outils
existants sont Verilator 5.040, GCC 10.2.0 et Binutils 2.35.1, dont versions,
origines et licences sont décrites par CF-04 et CF-05.1.

Le support U ne résout pas les 9 relocations medlow hors plage ni les 18 liens
nécessitant des helpers runtime de l'inventaire. Aucun C n'est exécuté par ce
lot et aucun changement de startup, linker général ou RAM n'est introduit.

Le lot concerne le pipeline rv64_pipeline. Le module rv64_datapath reste un
support pédagogique à sous-ensemble restreint, sans PC ; son contrat n'est
pas étendu implicitement à AUIPC. Les zones de padding .org des fixtures de
trap/MRET ne sont pas des instructions de programme exécutées. Ces fixtures
internes produisent le HEX via objcopy ; l'acceptation U par le filtre ELF est
vérifiée séparément dans les tests du convertisseur.

La revue des tests a renforcé les bases LD/SD : LUI produit 4096, les offsets
négatifs accèdent à 4088/4080, et les anciennes valeurs 64 et signatures
initialisées rendent un bypass erroné observable. Un test AUIPC→JALR direct
avec rd réécrit vérifie la priorité du producteur récent. Les quatre modes
normal/stall/flush/reset sont exécutés pour LUI et AUIPC. Cela porte à quinze
les exécutions pipeline sans élargissement du RTL.
