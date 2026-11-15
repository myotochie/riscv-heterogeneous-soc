# CF-05.1 — Matrice RV64I et preuves

État audité au commit de départ 6beccd1, sans modification RTL. Les 52 lignes
excluent HINTs/pseudoinstructions, Zicsr/Zifencei et privilège. Présent signifie
support identifié dans le RTL, pas preuve exhaustive de conformité.

D/A = tests unitaires décodeur et ALU ; P = intégration dirigée ;
M = mémoire ; B = matrice de branches ; J = intégration de sauts.
« À établir » signifie que la couverture pipeline de cette instruction
n’a pas été établie par ce jalon. Les rejets logiciels ne sont pas des tests RTL.

Les occurrences sont statiques : objets sur 48 configurations, ELF sur 117
liens réussis répartis sur trois layouts. Elles ne sont ni des fréquences
dynamiques ni un pourcentage de couverture.

| Instruction | RTL | Preuve positive citée | Pipeline | Objets | ELF liés |
|---|---|---|---|---:|---:|
| ADD | Présent | D/A | P | 126 | 342 |
| SUB | Présent | D/A | À établir | 6 | 18 |
| SLL | Présent | D/A | À établir | 6 | 18 |
| SLT | Présent | D/A | À établir | 0 | 0 |
| SLTU | Présent | D/A | À établir | 6 | 18 |
| XOR | Présent | D/A | À établir | 18 | 54 |
| SRL | Présent | D/A | À établir | 6 | 18 |
| SRA | Présent | D/A | À établir | 0 | 0 |
| OR | Présent | D/A | À établir | 12 | 36 |
| AND | Présent | D/A | À établir | 12 | 36 |
| ADDI | Présent | D/P | Dirigé | 368 | 882 |
| SLTI | Absent | — | Non implémenté | 6 | 18 |
| SLTIU | Absent | — | Non implémenté | 6 | 18 |
| XORI | Absent | — | Non implémenté | 6 | 18 |
| ORI | Absent | — | Non implémenté | 12 | 18 |
| ANDI | Absent | — | Non implémenté | 40 | 120 |
| SLLI | Absent | — | Non implémenté | 30 | 90 |
| SRLI | Absent | — | Non implémenté | 18 | 54 |
| SRAI | Absent | — | Non implémenté | 10 | 30 |
| LUI | Absent | — | Non implémenté | 16 | 45 |
| AUIPC | Absent | — | Non implémenté | 58 | 114 |
| LB | Absent | — | Non implémenté | 6 | 18 |
| LH | Absent | — | Non implémenté | 6 | 18 |
| LW | Absent | — | Non implémenté | 40 | 120 |
| LD | Présent | D/M | Dirigé | 254 | 645 |
| LBU | Absent | — | Non implémenté | 6 | 18 |
| LHU | Absent | — | Non implémenté | 6 | 18 |
| LWU | Absent | — | Non implémenté | 6 | 18 |
| SB | Absent | — | Non implémenté | 6 | 18 |
| SH | Absent | — | Non implémenté | 6 | 18 |
| SW | Absent | — | Non implémenté | 26 | 78 |
| SD | Présent | M | Dirigé | 182 | 453 |
| ADDIW | Absent | — | Non implémenté | 36 | 108 |
| SLLIW | Absent | — | Non implémenté | 6 | 18 |
| SRLIW | Absent | — | Non implémenté | 6 | 18 |
| SRAIW | Absent | — | Non implémenté | 2 | 6 |
| ADDW | Absent | — | Non implémenté | 24 | 72 |
| SUBW | Absent | — | Non implémenté | 6 | 18 |
| SLLW | Absent | — | Non implémenté | 6 | 18 |
| SRLW | Absent | — | Non implémenté | 6 | 18 |
| SRAW | Absent | — | Non implémenté | 6 | 18 |
| BEQ | Présent | D/B | Dirigé | 4 | 12 |
| BNE | Présent | D/B | Dirigé | 4 | 12 |
| BLT | Présent | D/B | Dirigé | 8 | 24 |
| BGE | Présent | D/B | Dirigé | 4 | 12 |
| BLTU | Présent | D/B | Dirigé | 2 | 6 |
| BGEU | Présent | D/B | Dirigé | 0 | 0 |
| JAL | Présent | D/J | Dirigé | 8 | 24 |
| JALR | Présent | D/J | Dirigé | 184 | 462 |
| FENCE | Absent | — | Non implémenté | 0 | 0 |
| ECALL | Absent | — | Non implémenté | 0 | 0 |
| EBREAK | Absent | — | Non implémenté | 0 | 0 |

## Sources des preuves

- [verification/integration/tb_branch_matrix.cpp](../../verification/integration/tb_branch_matrix.cpp)
- [verification/integration/tb_jump_pipeline.cpp](../../verification/integration/tb_jump_pipeline.cpp)
- [verification/integration/tb_rv64_full_width.cpp](../../verification/integration/tb_rv64_full_width.cpp)
- [verification/integration/tb_rv64_load.cpp](../../verification/integration/tb_rv64_load.cpp)
- [verification/integration/tb_rv64_pipeline.cpp](../../verification/integration/tb_rv64_pipeline.cpp)
- [verification/integration/tb_rv64_raw_forwarding.cpp](../../verification/integration/tb_rv64_raw_forwarding.cpp)
- [verification/integration/tb_rv64_store.cpp](../../verification/integration/tb_rv64_store.cpp)
- [verification/unit/alu/tb_alu.cpp](../../verification/unit/alu/tb_alu.cpp)
- [verification/unit/decoder/tb_branch_decoder.cpp](../../verification/unit/decoder/tb_branch_decoder.cpp)
- [verification/unit/decoder/tb_decoder.cpp](../../verification/unit/decoder/tb_decoder.cpp)
- [verification/unit/decoder/tb_jump_decoder.cpp](../../verification/unit/decoder/tb_jump_decoder.cpp)

Les sources RTL primaires sont decoder.sv, alu.sv, imm_gen.sv, execute_stage.sv,
data_memory.sv et le pipeline. CSR et MRET restent des fonctionnalités
séparées, partielles ; FENCE.I, M/A/F/D/C ne sont pas implémentés.

Génération reproductible des données : run_cf05_inventory.sh produit
inventory.json et isa_matrix.tsv. Cette vue Markdown est une photo des
observations avec GCC 10.2.0/Binutils 2.35.1, à actualiser lors des ajouts RTL.
