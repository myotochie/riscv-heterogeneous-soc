# CF-03 — Vérification, reproductibilité et limites des preuves

## 1. Contrat de preuve

Les contrôles sont des assertions de test C++ dirigées, plus le banc SV CSR
avec assertions temporisées. Leur réussite n'est ni une preuve formelle ni une
conformité RV64I complète. Les observations internes sont activées par les
options de simulation, sans ajouter de port fonctionnel au processeur.

Ce dossier distingue les premiers résultats avant revue des résultats de la
version corrective. Les premiers logs ne suffisent pas à valider les nouvelles
sources, même quand leurs chiffres étaient corrects.

## 2. Commandes de reproduction

Prérequis de la régression complète : Bash, Python 3, GNU Make, compilateur C++
et Verilator >=5. La référence préparée pour la CI est 5.040. Aucun script de
vérification n'installe de dépendance. Si le binaire est dans le PATH :

```bash
VERILATOR=verilator bash scripts/run_clean_regression.sh
```

Ou choisir explicitement une installation, sans dépendance implicite à /opt :

```bash
VERILATOR=/chemin/vers/verilator-5.040/bin/verilator \
  CLEAN_ROOT=/tmp/rv64-etude-propre \
  LOG_ROOT=/tmp/rv64-etude-resultats \
  bash scripts/run_clean_regression.sh
```

Choisir un nouveau répertoire pour une validation à froid. Aucun répertoire
existant n'est supprimé automatiquement. Le snapshot exclut les fichiers
ignorés par Git et inclut les sources nouvelles non ignorées avant commit.
Le HEAD enregistré identifie le parent, pas les modifications non commitées :
les empreintes individuelles sont donc indispensables.

Le lanceur complet continue après l'échec d'une suite pour produire un bilan,
puis retourne un code non nul si au moins une suite échoue. Il ne transforme
pas un échec en PASS. Les bancs historiques sont explicitement identifiés et
ne sont pas des suites réussies.

## 3. Provenance des résultats

Le répertoire de résultats contient :
- `manifest.json` : SHA256 par source exécutable, empreinte globale, versions de
  Verilator, g++, Make, Python et HEAD parent transmis ;
- `summary.tsv` : résultat de chacune des 25 suites actives ;
- `run_*.log` : commandes, compilations et assertions des suites ;
- `build/` : modèles, sous-logs et fixtures générées de cette exécution.

Les unités de comptage sont différentes : une suite shell peut lancer plusieurs
programmes ; un programme peut vérifier de nombreuses assertions. Il ne faut
pas additionner « 25 suites » et « 21 scénarios » comme deux nombres de tests
indépendants.

## 4. Tests unitaires CF-03

Commande commune :

```bash
VERILATOR=/chemin/verilator bash verification/scripts/run_jump_unit.sh
```

| Banc | Stimulus | Attente et nombre de checks |
|---|---|---|
| `unit/decoder/tb_jump_decoder.cpp` | 32 rd × 32 champs source, JAL et 8 funct3 JALR | 9 216 : légalité, commandes, indices et usage des sources |
| `unit/branch_target/tb_branch_target.cpp` | B/J signés, bornes J, I=-2048…2047, bases 64 bits et bits bas variés | 33 : cibles et masque conformes aux attentes calculées |
| `unit/execute_stage/tb_jump_execute.cpp` | JAL/JALR, sélections de forwarding, valeurs hautes, wrap et invalidité | 17 : lien XLEN, opérandes, absence d'écriture invalide |

Total : 9 266 checks dirigés. L'énumération exhaustive de certains champs de
décodage ne rend pas exhaustive la vérification des valeurs ou du pipeline.
Les checks invalid/illegal portent sur l'enable architectural, pas sur une
valeur ALU inutilisée.

Le banc `unit/pipeline_ex_mem/tb_pipeline_ex_mem.cpp`, inclus dans les suites
générale et datapath, vérifie aussi les nouveaux champs : capture complète,
conservation pendant stall, invalidité, flush et reset. Sa première extension
comptait 68 checks, inchangés dans la revue corrective.

## 5. Intégration : matrice des programmes

Commande :

```bash
VERILATOR=/chemin/verilator-5.040 \
  BUILD_ROOT=/tmp/rv64-jumps \
  bash verification/scripts/run_jump_pipeline.sh
```

Le runner construit chaque PROGRAM_ID puis lance
`/tmp/rv64-jumps/program_ID/Vrv64_pipeline ID MODE`.
Le tableau exprime les résultats attendus ; les résultats effectivement
observés pour les sources courantes sont enregistrés plus bas.

| ID | Stimulus principal | Assertions importantes |
|---|---|---|
| 36 | Appels imbriqués, sauvegarde RA, x5, RET, rd=rs1, offset négatif et cible impaire | Liens 0x80000008/4c/98/bc, retour, absence des effets du mauvais chemin |
| 37 | ALU → JALR, MEPC → JALR, LD → JALR | Sélections EX/MEM ALU/CSR et MEM/WB réellement observées ; exactement un interlock load-use |
| 38 | JAL +2 à PC=0x80000004 | Cause 0, EPC=0x80000004, TVAL=0x80000006, pas de lien et WB ancien préservé |
| 39 | JALR rd=rs1 vers somme 0x80000023 | Cible masquée 0x80000022, EPC=0x80000024, ancien RA conservé |
| 40 | LD mal aligné MEM et JAL EX | Cause LD=4, lien jeune et cible annulés |
| 41 | MRET WB, JAL fautif MEM, JALR EX | Un seul trap initial et un MRET, reprise à 0x80000008, deux liens jeunes annulés |
| 42 | Écriture MTVEC WB et JAL fautif MEM | Gestionnaire 0x80000180, pas l'ancien 0x80000100 |
| 43 | Sept funct3 JALR réservés | Pas d'écriture ni de redirection selon la politique actuelle des illégales |
| 44 | Deux producteurs du même registre, puis producteur MEM/WB | Valeur la plus récente et bypass MEM/WB |
| 45 | LD x5 puis JAL dont l'immédiat ressemble à rs1=x5 | Aucun faux load-use et bon lien à la cible |
| 46 | BNE non pris puis BEQ pris avec cible +2 | Seule la branche prise faute, EPC/TVAL exacts |
| 47 | LD fautif MEM et JALR EX | Collision observée une fois, trap ancien prioritaire et cible basse interdite |

Le programme 37 utilise MEPC, réellement implémenté. Une ancienne version
utilisait mscratch et pouvait exercer le forwarding d'une écriture qui ne
serait pas stockée architecturalement. Ce cas a été corrigé sans ajouter
un CSR au matériel pour satisfaire le banc.

## 6. Modes de contrôle externe

| ID | Modes exécutés | Point d'injection |
|---|---|---|
| Tous 36–47 | 0 | Exécution normale |
| 36 | 1, 2, 3 | Stall 3 cycles, flush, reset sur le premier JAL en EX |
| 38 | 4, 5, 6 | Stall 3 cycles, flush, reset sur la faute en MEM |
| 36 | 7, 8, 9 | Stall 3 cycles, flush, reset sur le RET JALR à 0x80000050 |

Cela représente **21 scénarios** : 12 normaux et 9 supplémentaires.
Le banc vérifie les enables GPR/CSR/mémoire pendant les contrôles, la stabilité
du PC pendant stall, la reprise unique, et l'absence d'arrivée à l'appelant
lorsque le retour est annulé. Les tests d'annulation n'observent qu'une fenêtre
courte, avant une éventuelle réexécution après reset : ils ne prouvent pas
l'absence de toute activité ultérieure du programme redémarré.

## 7. Effets architecturaux et initialisation

Le runner initialise explicitement les huit octets à l'adresse zéro. Les
programmes initialisent leurs autres données avant de les relire. Un store
annulé écrit une valeur non nulle : relire zéro détecte une écriture indue,
au lieu de comparer deux zéros indiscernables. Le CSR annulé visé est MTVEC,
qui existe et dont le gestionnaire vérifie la valeur attendue.

Les assertions WB vérifient PC+4 pour chaque saut autorisé à écrire. Les
compteurs d'accès aux mux établissent les chemins de dépendance exercés.
Le dictionnaire nommé `retired` n'est qu'une observation MEM/WB qualifiée :
il ne doit pas devenir une trace de référence ISA sans traiter séparément
stores, instructions neutralisées, exceptions et ordre des effets.

## 8. Régressions complémentaires

- La suite générale conserve les tests ALU, décodeur, registres de pipeline,
  fetch/decode/execute, WB et hazards. Ses observateurs de registres supportent
  les API C++ ancienne et moderne de Verilator.
- Le datapath historique rejette JAL/JALR et les autres familles sans chemin
  d'exécution ; x1 initialisé est relu après chaque tentative d'écriture.
- Le banc CSR modernisé conserve les 15 cas initiaux et ajoute 3 checks des
  adresses indépendantes de lecture/écriture.
- Les suites CF-02, CSR, traps mémoire et MRET restent actives et inchangées
  dans leurs objectifs. Leur sélection outil/build est rendue portable.
- Les programmes 0–35 sont comparés à HEAD ; les cas CF-03 36–46 sont renforcés
  mais conservent leurs objectifs et leurs IDs. Le cas 47 complète la matrice.

Les deux sources historiques de poursuite après load fautif restent inchangées.
Voir [le catalogue](../../verification/historical/README.md). Leur exclusion
est une différence de contrat architectural documentée, pas un PASS.

## 9. CI préparée et dépendances

Le workflow sélectionne v5.040 depuis `verilator/verilator`, construit l'outil
dans le runner Ubuntu 22.04 puis appelle la même commande de snapshot propre.
Il journalise le commit résolu du tag et les versions des paquets, vérifie
l'absence de changement dans le checkout et conserve les preuves en artefact.

| Dépendance | Version / identification | Usage / licence |
|---|---|---|
| Verilator | Référence 5.040 ; comparaison locale possible 4.038 | Simulation ; distribution sous LGPL-3.0 ou Artistic-2.0, vérifier les fichiers de licence de la version |
| g++, Make, Bash, Git, Python | Versions du système, enregistrées par les logs/manifest | Compilation et orchestration ; outils déjà requis/disponibles localement |
| autoconf, bison, flex, help2man | Paquets Ubuntu dont versions sont journalisées dans CI | Construction de Verilator dans le runner, pas d'installation locale |
| actions/checkout | v4 | Action GitHub existante, MIT |
| actions/upload-artifact | v4 | Archivage CI, MIT |

Les en-têtes runtime Verilator locaux annoncent explicitement
`LGPL-3.0-only OR Artistic-2.0`. Les outils GNU de construction conservent leurs
licences propres (GPL et exceptions selon composant), Flex sa licence BSD et
Python la licence PSF. Les licences de ces outils ne remplacent pas la licence
Apache-2.0 du dépôt. Aucune nouvelle bibliothèque n'est liée au RTL applicatif.
Les paquets système ne sont pas figés par numéro Debian : leurs versions
exactes doivent donc être conservées pour interpréter une différence future.

La préparation suit les étapes autoconf/configure/make de la
[documentation officielle d'installation](https://verilator.org/guide/latest/install.html),
avec un préfixe dans le runner et la version sélectionnée plutôt que la branche
courante. Cette référence décrit la procédure générale ; les versions locales
effectivement exécutées figurent dans le manifest.

Le workflow local n'est pas une exécution GitHub réussie. Push et PR restent
soumis à autorisation ; aucun résultat CI de main antérieur à CF-03 ne valide
ce livrable.

## 10. Résultats et limites

### Première réalisation, avant revue corrective

Les logs locaux du 2026-11-10 annonçaient 25 suites actives, 17 scénarios et
9 266 checks sur 4.038/5.040. L'audit les a retrouvés, mais a aussi identifié
la fixture ignorée, le datapath historique et les accès au CSR non implémenté.
Ils sont donc des résultats historiques, pas la preuve des sources corrigées.

### Réalisation corrective

Validation locale achevée le **2026-11-10**. Le processus
`run_clean_regression.sh` s'est terminé avec le code **0**. Le résumé contient
**25 suites actives PASS, 0 FAIL**, dont les suites CF-02, CSR, mémoire et MRET.
Les deux bancs historiques ne sont pas inclus dans ce nombre.

| Mesure réellement observée | Résultat |
|---|---|
| Lanceur complet du snapshot propre, Verilator 5.040 | 25/25 suites |
| Intégration JAL/JALR, programmes 36–47 et injections | 21/21 scénarios |
| Unités JAL/JALR, Verilator 5.040 | 9 266 checks, 0 échec |
| Unités JAL/JALR, Verilator 4.038 | 9 266 checks, 0 échec |
| Banc CSR modernisé | 18 checks, 0 échec |
| Datapath historique et rejets sans effet | 19 checks, 0 échec |
| Registre EX/MEM et contexte de faute | 68 checks, 0 échec |
| Préservation des programmes 0–35 et du câblage fetch | Comparaison exacte à HEAD réussie |
| Sources des deux bancs historiques | Comparaison exacte à HEAD réussie |
| Contrôles de fichiers | bash -n, YAML, liens Markdown et git diff --check réussis |

Preuves : [manifest local](/tmp/cf03-review-validation/manifest.json),
[résumé des suites](/tmp/cf03-review-validation/summary.tsv),
[journal du lanceur](/tmp/cf03-review-clean.log). Ces chemins sont des artefacts
locaux temporaires ; les commandes de reproduction ci-dessus restent la
référence portable. La CI préparée conservera ses propres artefacts après une
publication autorisée ; elle n'a pas été exécutée sur GitHub dans cette phase.

Empreinte des sources exécutables testées :

```text
f463c9560a8ee0d804a030bcf7b202ea4ab3e261183cd909bc258e28d941066a
```

Parent Git : `81eb817a04dd2ed56b4bc227f35ade74bbaa501b`. Les sources non commitées sont identifiées par
leurs hashes dans le manifest, pas par ce seul parent. La comparaison finale
confirme que chaque source exécutable courante correspond au manifest. Les
images ont été générées dans le build ; le snapshot ne contient pas l'ancien
HEX ignoré. Aucune compilation préexistante de l'arbre de travail n'a été copiée.

Environnement observé : Verilator 5.040 2025-08-30 rev v5.040,
g++ (Ubuntu 11.4.0-1ubuntu1~22.04.3) 11.4.0, GNU Make 4.3, Python 3.10.12.
La documentation a été finalisée après les tests, sans modifier les sources
exécutables correspondant à ces empreintes.

### Résultats ciblés obtenus pendant la revue

| Exécution réelle | Résultat observé |
|---|---|
| Suite générale, arbre de travail, 5.040 | PASS final, y compris les observateurs GPR adaptés |
| Suite datapath complémentaire, 5.040 | PASS ; CSR=18 checks, sans exclusion du banc CSR |
| Datapath historique dans la suite générale | 19 checks, zéro échec |
| Intégration corrigée, 5.040 | 21 scénarios, zéro échec |
| Unités CF-03, 4.038 | 9 216 + 33 + 17 checks, zéro échec |
| Syntaxe des trois observateurs GPR avec headers 5.040 | Compilation syntaxique réussie |
| Scripts et workflow | bash -n et analyse YAML réussis |

Logs ciblés : `/tmp/cf03-corrections-base.log`,
`/tmp/cf03-corrections-datapath.log`, `/tmp/cf03-corrections-jump.log`,
`/tmp/cf03-review-unit4.log`. La régression propre conserve ses preuves sous
`/tmp/cf03-review-validation/`, avec snapshot sous `/tmp/cf03-review-clean/source`.
Des builds indépendants de ce même snapshot sont préparés en parallèle pour
réduire l'attente ; le lanceur complet rejoue leurs assertions. Aucun modèle
précompilé de l'arbre de travail n'est copié dans cette validation.

### Ce qui ne sera pas prouvé par ces tests

Pas de conformité RV64I entière, de preuve exhaustive des combinaisons, de
synthèse/placement FPGA, de fréquence maximale, de cohérence multicœur ou de
comparaison Spike. La mémoire a une latence simplifiée. Les fautes de fetch,
traps d'instructions illégales et restrictions CSR de privilège restent partiels
ou absents. Aucun chiffre de CPI moyen n'est présenté comme mesure.

## 11. Préparation de publication après validation

Après autorisation de commit/push/merge, le déclenchement `push` du workflow
inclut aussi `feat/rv64-program-loader`. Cela permet de vérifier le commit
publié avant une avance rapide vers main, sans créer automatiquement de PR.
Seule cette sélection d'événements et la documentation de statut ont changé
après la validation locale consignée plus haut. Le manifest garde l'empreinte
du workflow testé comme source de configuration, avant cette modification ;
les sources RTL, bancs et scripts de vérification restent identiques.

La syntaxe YAML et le diff de ce changement sont contrôlés séparément. Le
premier accès SSH de publication a été refusé (publickey) : aucun résultat
distant de publication, fusion ou CI CF-03 n'est présumé.

## 12. Premier essai GitHub : validation du contexte avant exécution

La branche publiée pointe sur `66e4a882198a76de69f82ffd7c535a2d6a95ee52`.
[Actions 42911082817](https://github.com/myotochie/riscv-heterogeneous-soc/actions/runs/42911082817)
se termine en échec immédiat, avec zéro job et zéro check-run. L'annotation
publique donne exactement la cause : ligne 19, contexte runner indisponible
pour l'expression runner.temp. Il s'agit d'un rejet du workflow, pas d'un test
matériel échoué. Le parsing YAML local ne vérifie pas ces règles sémantiques.

Selon la [table officielle des contextes](https://docs.github.com/en/actions/reference/workflows-and-actions/contexts#context-availability),
`jobs.<job_id>.env` n'autorise pas runner, tandis que
`jobs.<job_id>.steps.env` l'autorise. Le correctif déplace donc la variable
VALIDATION_ROOT au niveau de la seule étape qui la consomme. Les chemins de
snapshot et d'artefacts utilisent déjà runner.temp dans des étapes valides.

Contrôles locaux : parsing YAML ; absence de runner dans l'env du job ;
présence de la variable dans l'env de Record dependency versions ; conservation
des sources RTL/bancs/scripts par comparaison au manifest ; git diff --check.
Ces contrôles ne remplacent pas une nouvelle exécution GitHub après publication.
Les 25 suites locales restent le résultat du snapshot précédent, et aucune
réussite distante n'est revendiquée pour le correctif tant qu'elle n'est pas
observée. Aucun changement matériel ne justifie de relancer ces 25 suites pour
ce déplacement de variable de workflow.
