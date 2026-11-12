# Implémentation CF-04.1/2

## Module instruction_memory

Nouveau fichier rtl/core/memory/instruction_memory.sv. Il isole le tableau de
mots de 32 bits du contrôle PC et des registres du pipeline. Entrée : address,
64 bits. Sorties : instruction, 32 bits, et address_fault, un bit.

L'initialisation préremplit le tableau de NOP. En simulation, elle ouvre le
fichier et lit chaque jeton par $fscanf. La longueur et chaque caractère sont
vérifiés avant $readmemh : cela évite de dépendre de la tolérance du parseur
Verilator aux jetons tronqués ou aux adresses hors plage. La passe de lecture
est volontairement double ; l'image ne doit pas changer pendant l'initialisation.
Le fichier doit être un fichier texte ordinaire lisible.

```systemverilog
// offset est calculé en 64 bits avant la sélection du tableau.
offset = address - BASE_ADDR;
address_fault = address[1:0] != 0 || address < BASE_ADDR || offset >= CAPACITY_BYTES;
instruction = 32'h00000013;
if (!address_fault) instruction = mem[int'(offset >> 2)];
```

Le tableau est borné par WORDS. Le contrôle exclut toute lecture à un index
invalide. Ce bloc est combinatoire ; aucune écriture n'a lieu après init.
La capacité est destinée à des ROM de simulation raisonnables, pas à une
allocation couvrant tout l'espace RV64. Les très grandes capacités ne sont
pas validées. Les conditions de configuration sont vérifiées en simulation.

## Fetch et propagation des paramètres

| Fichier | Modification et responsabilité |
|---|---|
| fetch_path.sv | Conserve la table historique ; ajoute le generate externe et le diagnostic au front |
| fetch_decode_path.sv | Transmet IMEM_FILE/WORDS/BASE à fetch_path |
| fetch_decode_execute_path.sv | Transmet les paramètres au wrapper fetch/decode |
| rv64_pipeline.sv | Rend la configuration accessible au top |

Le signal historique instr_mem_data et toute sa table restent identiques.
Un nouveau signal selected_instr_data alimente IF/ID : IMEM_FILE vide
sélectionne instr_mem_data, sinon la sortie du nouveau module. Les noms et
ports de pc et IF/ID ne changent pas. Les nouveaux paramètres
sont ajoutés après les paramètres existants, afin de conserver aussi les
instanciations positionnelles. Aucun changement ALU, décodeur, forwarding
ou exception_controller.

```systemverilog
// Un slot annulé ou retenu ne constitue pas une nouvelle lecture acceptée.
if (!reset && !flush && !stall_if_id && address_fault)
    $fatal(1, "IMEM_FETCH_ADDRESS: invalid accepted PC %h", pc_value);
```

Le flush reçu par fetch inclut les redirections déjà présentes. Cette
condition ne remplace pas un chemin de trap. Le diagnostic est absent sous
SYNTHESIS : les comportements de synthèse doivent être étudiés séparément.

## Scripts et vérification ajoutés

scripts/run_unit_tests.sh et les quatre runners branch_pipeline,
branch_hazards, branch_matrix et branch_collisions ont des listes explicites :
instruction_memory.sv y est ajouté. Les autres runners découvrent les modules
automatiquement. Aucune commande ou sélection de programme n'est supprimée.

Nouveaux fichiers :

- verification/unit/instruction_memory/tb_instruction_memory.cpp : mots exacts,
  bornes, NOP de remplissage, alignement et absence d'alias 64 bits.
- verification/integration/tb_external_fetch.cpp : interaction ROM/PC/IFID.
- verification/integration/tb_external_program.cpp : top complet et signature.
- verification/scripts/run_instruction_memory.sh : génère les fixtures dans
  BUILD_ROOT, compile les trois tops et vérifie les erreurs attendues.

La nouvelle suite est découverte par run_full_regression.sh. Les fichiers HEX
restent générés hors du dépôt ; aucune exception au .gitignore n'est nécessaire.
Les exécutions négatives vérifient le marqueur d'erreur en plus du statut non
nul : un crash sans rapport n'est pas compté comme réussite.

## Reproduction de l'intégration externe

```bash
VERILATOR=/opt/verilator-modern/bin/verilator \
BUILD_ROOT=/tmp/rv64-imem-study \
bash verification/scripts/run_instruction_memory.sh
```

Le chemin /opt est une installation locale observée, pas une dépendance
codée dans le runner. La variable VERILATOR accepte un autre exécutable.
L'image est un paramètre d'élaboration (-GIMEM_FILE), donc changer le chemin
demande une reconstruction du modèle. Modifier le contenu du même fichier
avant une nouvelle exécution du modèle recharge l'image au démarrage.

## Programme de démonstration encodé

| Offset | Mot machine | Instruction |
|---|---|---|
| 0x00 | 04000113 | addi x2,x0,64 |
| 0x04 | 02800293 | addi x5,x0,40 |
| 0x08 | 010000ef | jal x1,function |
| 0x0c | 00513023 | sd x5,0(x2) |
| 0x10 | 00013503 | ld x10,0(x2) |
| 0x14 | 0000006f | jal x0,0 |
| 0x18 | 00228293 | function: addi x5,x5,2 |
| 0x1c | 00008067 | jalr x0,0(x1) |

Le banc attend x1 = 0x8000000c et un writeback x10 = 42, sans trap sur
100 cycles. Les GPR/RAM non utilisés ne sont pas supposés remis à zéro.
L'arrêt est celui du banc après la fenêtre bornée ; la boucle reste une
instruction matérielle normale. Aucun ELF ni appel de runtime n'est impliqué.
