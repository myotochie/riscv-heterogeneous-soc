# CF-03 — Guide d'implémentation

## 1. Lecture recommandée

Lire d'abord [le contrat architectural](../architecture/cf03-jumps.md), puis
`decoder → decode_stage → pipeline_id_ex → fetch_decode_execute_path →
execute_stage → pipeline_ex_mem → rv64_pipeline → writeback_stage`.
Cette liste représente la circulation d'une instruction ; les instanciations
hiérarchiques ne correspondent pas exactement à cet ordre de lecture.

## 2. Décodeur : légalité, effets, dépendances

Fichier : `rtl/core/decoder/decoder.sv`.
Avant CF-03, les opcodes 1101111 et 1100111 restaient dans les valeurs par
défaut illégales. Désormais JAL est légal pour tout immédiat/rd ; JALR exige
funct3=000. Le décodeur active reg_write, mais ni mem_read, ni mem_write,
ni CSR, ni MRET. `rd=x0` n'est pas une instruction illégale : le WB supprimera
son écriture, pas son transfert de contrôle.

```systemverilog
if (opcode == 7'b1101111 ||
    (opcode == 7'b1100111 && funct3 == 3'b000)) begin
    reg_write     = 1'b1;
    illegal_instr = 1'b0;
end
```

L'ajout de JAL requiert aussi une correction du calcul uses_rs1. Sans elle,
une partie de l'immédiat J serait interprétée comme un registre source par le
hazard detector et pourrait provoquer un arrêt injustifié après LD. Le test 45
place précisément cette collision de numéros dans les bits d'instruction.
Les indices rs1/rs2 continuent à refléter les champs physiques du mot ; ce sont
les flags d'usage qui expriment la dépendance sémantique.

`decode_stage`, `fetch_decode_path` et `pipeline_id_ex` ne reçoivent pas de
nouveau port de saut : ils transportent déjà le PC, l'instruction complète,
les valeurs sources, les indices, valid et illegal.

## 3. EX : calcul du lien et des cibles

### `rtl/core/execute/execute_stage.sv`

Avant : alu_result_out était toujours le résultat de l'ALU.
Après : un saut reconnu sélectionne PC+4. Tous les autres résultats ALU et les
contrôles mémoire gardent leur comportement. Le calcul combinatoire du lien
peut exister sur une bulle ; seul le contrôle d'écriture qualifié par valid et
illegal peut rendre ce résultat architectural.

```systemverilog
alu_result_out = is_jump ? pc_in + 64'd4 : alu_result;
reg_write_out  = valid_in && !illegal_instr_in
                 && (reg_write_in || csr_valid_in);
```

Les mux de forwarding restent en amont : forwarded_rs1 sert au calcul JALR
et à csr_execute. Le port rs2_value_out reste la source forwardée d'un store.
Le test unitaire force séparément chaque sélection et utilise des valeurs
avec bits hauts non nuls pour détecter une éventuelle troncature RV32.

### `rtl/core/control/branch_target.sv` et `branch_decision.sv`

Les modules existaient avant CF-03 et leur RTL est réutilisé. target_kind vaut
00 pour B, 01 pour J et 10 pour JR. Le calcul des immédiats J/B est local au
bloc ; `imm_gen`, qui sert principalement aux opérandes arithmétiques et aux
adresses de données, n'a donc pas besoin de produire l'immédiat J.

`branch_decision` rend un saut inconditionnel pris. La légalité JALR est
qualifiée avant de lui transmettre is_jalr. Cela évite qu'un funct3 réservé
redirige malgré illegal_instr.

## 4. Frontend : arbitrage, flush et exception en attente

Fichier : `rtl/core/pipeline/fetch_decode_execute_path.sv`.

Les entrées is_jal/is_jalr, auparavant forcées à zéro, sont maintenant issues
du slot ID/EX valide et légal. Le type de cible est sélectionné selon le saut.
Les noms internes ex_branch_* sont conservés pour éviter un renommage massif ;
ils désignent maintenant l'ensemble des transferts de contrôle résolus en EX.

```systemverilog
assign ex_target_misaligned = ex_branch_taken && !ex_branch_illegal &&
                              (ex_branch_target[1:0] != 2'b00);
```

La redirection EX exige aussi l'absence de faute, reset, stall, flush et
redirection/flush d'un événement plus ancien. Elle annule IF/ID et ID/EX,
mais pas EX/MEM. Le signal trap_redirect reçu de rv64_pipeline représente
l'arbitrage architectural ancien et prime dans le mux de cible vers le PC.

Le défaut d'alignement coupe reg_write à l'entrée EX/MEM :

```systemverilog
.reg_write_in(ex_reg_write && !ex_target_misaligned)
```

Ce point est nécessaire même avant le trap MEM : EX/MEM alimente le forwarding.
Le drapeau de faute doit survivre à un stall et disparaître avec une annulation.

## 5. Nouveau contexte séquentiel EX/MEM

Fichier : `rtl/core/pipeline/pipeline_ex_mem.sv`.

| Ports ajoutés | Largeur | Sens |
|---|---|---|
| target_misaligned_in/out | 1 bit | Faute d'adresse d'instruction détectée en EX |
| control_target_in/out | 64 bits | Cible finale destinée à mtval |

À chaque front actif sans stall, le registre capture la cible et le flag
qualifié par valid_in. Reset/flush effacent le flag et la cible et ont priorité
sur stall. Une bulle ne peut pas déclencher de faute même si ses données
contiennent une cible non alignée. Un stall conserve tous les champs.

Ce coût est 65 bits de contexte de pipeline au niveau RTL. Il ne s'agit pas
d'un nombre de cellules après synthèse : l'outil peut optimiser la structure.
Le banc EX/MEM vérifie capture 64 bits, conservation, invalidité et priorités.
Le wrapper SV CSR `tb_csr_pipeline_90_8d4.sv` raccorde ces entrées à zéro, car
ses stimuli n'injectent pas de transfert de contrôle.

## 6. Trap MEM et état machine

### `rtl/core/exception/exception_controller.sv`

Le module reçoit mem_target_misaligned et mem_control_target. Pour un slot MEM
valide hors reset/stall, ce défaut produit cause=0, mem_pc et la cible complète.
La classification LD/SD conserve les causes 4/5/6/7. Dans le CPU actuel, un
slot ne peut pas être simultanément un saut et un accès mémoire : la priorité
écrite dans ce bloc n'est pas un arbitrage entre deux instructions distinctes.

### `rtl/core/pipeline/rv64_pipeline.sv`

Deux fils raccordent le contexte EX/MEM au contrôleur. mem_valid est qualifié
par !flush, pour empêcher une annulation externe de créer un trap architectural.
Les mécanismes existants sont réutilisés :
- mret_retire qualifie MRET en WB, hors stall/reset/flush ;
- trap_take supprime une faute jeune lors d'un MRET ancien ;
- redirect_valid purge les étages jeunes et MEM/WB ;
- trap_mtvec_effective tient compte du CSR MTVEC qui termine en WB.

`writeback_stage.sv`, `forwarding_unit.sv` et `regfile.sv` ne nécessitent pas
de nouveau mux de lien. Leurs garde-fous valid, faute, rd!=0 et priorité des
sources servent aussi aux sauts. La RAM bloque son front d'écriture pendant
reset ; son enable fourni par le pipeline bloque stall, flush et MRET ancien.

### `rtl/core/csr/csr_file.sv`

L'architecture des CSR n'est pas étendue. Seul un commentaire périmé sur MRET
est corrigé. `mscratch` n'est pas implémenté : la revue a donc remplacé son
usage dans les tests CF-03 par MEPC pour une dépendance et MTVEC pour observer
les effets annulés. Aucun nouveau CSR n'est ajouté pour satisfaire un test.

## 7. Compatibilité du datapath pédagogique

Fichier : `rtl/core/rv64_datapath.sv`.
Ce module n'a ni PC, ni mémoire, ni exécution CSR. L'élargissement du décodeur
partagé l'amenait à accepter un saut puis à écrire une addition ordinaire.
Sa légalité locale est maintenant :

```systemverilog
assign supported_opcode = (instr[6:0] == 7'b0110011) ||
                          (instr[6:0] == 7'b0010011);
assign illegal_instr = decoded_illegal || !supported_opcode;
```

Le contrôle du décodeur est conservé pour rejeter les funct3/funct7 non pris
en charge à l'intérieur de ces familles. Ce garde-fou n'altère pas le pipeline.
Le banc initialise x1=42, tente JAL/JALR/LD/CSR/branche/MRET, puis relit x1 après
chaque tentative. Le résultat ALU d'une instruction illégale n'est pas une
valeur architecturale à tester ; l'absence d'écriture et illegal le sont.

## 8. Programmes intégrés et assertions

`rtl/core/pipeline/fetch_path.sv` conserve les programmes 0–35. Les programmes
36–47 constituent des stimuli, pas une extension de l'interface matérielle.
La ROM retourne encore NOP à toute adresse non spécifiée.

Le test C++ `tb_jump_pipeline.cpp` observe les interfaces WB/trap et certains
signaux internes rendus publics seulement par l'option Verilator de son runner.
Les modes 0–9 sélectionnent normal, arrêt ou annulation ; le runner n'exécute
que les combinaisons définies dans le dossier de vérification.
Le programme 47 ajoute une collision faute MEM/JALR EX. Les modes 7–9 ciblent
un retour JALR après restauration de RA plutôt que le premier JAL du programme.
Les tests inspectent aussi les enables de commit GPR/CSR et mémoire pendant
les contrôles externes. Ce sont des observations de simulation, pas des ports
matériels supplémentaires.

## 9. Scripts et compatibilité Verilator

Tous les runners sourcent `scripts/verilator_env.sh`, qui résout VERILATOR
explicitement ou utilise le PATH. Il n'installe rien et ne cherche pas une
installation privée /opt. Les scripts CSR auparavant liés à ce chemin sont
ainsi portables. Deux nettoyages `rm -rf` de builds sont remplacés par mkdir :
une exécution ne supprime plus un répertoire choisi par l'appelant.

Les trois bancs d'observation du registre (`tb_rv64_regfile.cpp`,
`tb_rv64_raw_forwarding.cpp`, `tb_rv64_forwarding_priority.cpp`) utilisent
rootp si le header moderne existe et l'accès ancien sinon. Les assertions
fonctionnelles sont conservées ; seule la manière d'accéder au signal change.
Le runner général accepte BASE_BUILD_DIR et utilise des chemins C++ absolus.
Les scripts dédiés acceptent BUILD_DIR/BUILD_ROOT afin d'isoler leurs modèles.
Le banc CSR temporisé requiert la version moderne pour --binary/--timing ;
le lanceur complet annonce donc une exigence Verilator >=5 et la CI choisit
5.040. Les petits tests compatibles peuvent encore tourner sous 4.038.

`run_datapath_regression.sh` génère les images LD et pleine largeur ;
`run_jump_pipeline.sh` initialise explicitement les 8 octets à l'adresse zéro.
Aucun runner actif ne dépend du fichier HEX local ignoré.

`run_clean_regression.sh` copie les fichiers suivis et nouveaux non ignorés
vers un snapshot temporaire, sans checkout ni copie de .git. Le lanceur complet
utilise ce snapshot, des builds neufs, des logs, un résumé PASS/FAIL et un
manifest des SHA256 des sources RTL/bancs/scripts et versions des outils.
Une modification documentaire ne change pas la logique testée ; les sources
exécutables figurent individuellement dans le manifest.

## 10. CI et périmètre de preuve

`.github/workflows/rtl-ci.yml` prépare Verilator v5.040 depuis le dépôt officiel
dans le runner GitHub et lance la régression complète du snapshot. Les versions
des paquets et le commit source de Verilator sont journalisés. Un job vérifie
que le checkout est inchangé et archive logs/manifest/résumé, y compris en échec.

Ce workflow est préparé localement. Il n'est pas exécuté sur GitHub tant que
le code n'est pas publié par une action expressément autorisée. Le test local
du runner ne prouve pas que la construction des outils ou la collecte des
artefacts a déjà réussi sur GitHub.

## 11. Index des fichiers de vérification touchés

Tous les scripts ci-dessous sont sous `verification/scripts/`. Leur modification
commune est la résolution de VERILATOR et l'acceptation des builds isolés. Les
assertions des suites antérieures restent identiques, sauf extensions de bancs
explicitement décrites. Le script complet conserve chaque suite comme unité de
résultat ; il ne remplace pas plusieurs tests par un seul test superficiel.

| Fichier | Responsabilité / contrôle inchangé ou renforcé |
|---|---|
| `run_branch_collisions.sh` | Programmes 34/35 : branches face aux traps/MRET |
| `run_branch_decoder.sh` | Décodage des six branches et usages sources |
| `run_branch_hazards.sh` | Programmes 32/33 : RAW et load-use des branches |
| `run_branch_matrix.sh` | Matrice des conditions de branchement |
| `run_branch_pipeline.sh` | Programmes 24/25 : branches et boucle |
| `run_csr_commit_integration.sh` | Programme 14 : commit architectural CSR |
| `run_csr_decoder.sh` | Décodage des six formes CSR |
| `run_csr_execute.sh` | Opérations et enables CSR combinatoires |
| `run_csr_forward_priority.sh` | Programme 17 : priorité des producteurs CSR |
| `run_csr_gpr_writeback.sh` | Programme 15 : ancienne valeur CSR vers GPR |
| `run_csr_mem_wb_forwarding.sh` | Programme 19 : bypass WB de CSR vers ALU |
| `run_csr_mem_wb_observe.sh` | Programme 19 : observation des sélections internes |
| `run_csr_pipeline.sh` | Registres CSR pipeline, banc SV temporisé |
| `run_csr_precise_trap.sh` | Programme 20 : CSR et faute précise |
| `run_csr_raw_hazard.sh` | Programme 16 : dépendances CSR |
| `run_csr_to_alu.sh` | Programme 18 : ancienne valeur CSR vers ALU |
| `run_csr_trap_priority.sh` | État CSR et mises à jour simultanées du trap |
| `run_datapath_regression.sh` | Banc CSR réactivé, mémoire, forwarding et pipelines complémentaires |
| `run_jump_pipeline.sh` | 21 scénarios sur les programmes 36–47 |
| `run_jump_unit.sh` | 9266 checks JAL/JALR/liaison EX |
| `run_memory_traps.sh` | Programmes 10–13 : causes mémoire et précision |
| `run_mret_collision.sh` | Programme 22 : priorité MRET sur faute jeune |
| `run_mret_integration.sh` | Programme 21 : retour de trap |
| `run_mret_store.sh` | Programme 23 : annulation de store jeune |

Les trois adaptations d'API C++ concernent uniquement les observateurs de
registres nommés à la section 9. Le banc `tb_datapath.cpp` étend les tests de
contrat du module historique ; `tb_csr_file.cpp` modernise l'interface et ajoute
l'indépendance des ports. `tb_branch_target.cpp`, `tb_jump_decoder.cpp`,
`tb_jump_execute.cpp`, `tb_jump_pipeline.cpp` et `tb_pipeline_ex_mem.cpp`
correspondent aux matrices du dossier de vérification. Les deux anciens bancs
load-invalid ne sont ni modifiés ni déplacés ; leur statut figure dans le
catalogue `verification/historical/README.md`.

Le README redirige l'état courant vers l'overview et décrit les commandes.
Les documents système/microarchitecture v0.1 reçoivent seulement un avertissement
de spécification cible/historique : leurs exigences ne sont pas déclarées
réalisées. Les cinq documents CF-03 apportent chacun une perspective différente,
et PROJECT_PROGRESS distingue travail local, commit et publication.
