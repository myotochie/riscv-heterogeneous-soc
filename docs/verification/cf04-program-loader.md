# Vérification CF-04.1/2

## Périmètre et commandes

Les tests sont des simulations dirigées. Ils ne prouvent ni conformité ISA
complète ni synthèse FPGA. Aucun compilateur croisé n'est nécessaire pour
les fixtures encodées de ce jalon.

```bash
VERILATOR=/opt/verilator-modern/bin/verilator \
BUILD_ROOT=/tmp/cf04-imem-check \
bash verification/scripts/run_instruction_memory.sh

VERILATOR=/opt/verilator-modern/bin/verilator \
CLEAN_ROOT=/tmp/cf04-clean-validation \
LOG_ROOT=/tmp/cf04-full-validation \
bash scripts/run_clean_regression.sh
```

Le premier runner construit trois tops. Le second copie sources suivies et
nouvelles sources non ignorées, calcule leurs empreintes et exécute les suites
actives. Les images HEX sont générées dans BUILD_ROOT, jamais nécessaires
comme fichiers locaux cachés dans le dépôt. Aucun test historique n'est retiré.

## Matrice de tests

| Banc / stimulus | Vérification attendue | Limite |
|---|---|---|
| tb_instruction_memory : image de quatre mots | Première/dernière instruction et mots intermédiaires exacts | Capacité testée = 4 |
| Même banc, image de deux mots | Deux derniers mots NOP | Pas de faute après fin d'image dans la capacité |
| Adresses base−4, base+16, base+1/+2/+3, zéro, max64, base+2^32 | address_fault, sortie NOP | Pas de trap architectural |
| Sept images mal formées/vides | IMEM_FORMAT et statut non nul | Format dense uniquement |
| Cinq mots pour capacité quatre | IMEM_SIZE | Pas de conversion ELF |
| Fichier absent | IMEM_FILE | Permissions et I/O concurrents non injectés |
| tb_external_fetch | Reset, capture, stall, flush, redirection, PC invalide annulé | Fetch isolé |
| Fetch invalide effectivement accepté | IMEM_FETCH_ADDRESS et statut non nul | Diagnostic simulation |
| tb_external_program | Lien x1=0x8000000c, SD/LD relu dans x10=42, aucun trap, 100 cycles | Fixture encodée à la main |
| Régression générale | Toutes suites actives réussissent | Couverture dirigée non exhaustive |

Les erreurs attendues vérifient avec grep le texte IMEM_* pour ne pas accepter un
échec de compilation ou un crash sans rapport. Les core dumps sont désactivés
pour ces processus. Les positifs lèvent une erreur si une valeur diffère.

## Résultats

La suite ciblée termine avec code 0 sous Verilator 5.040 : 24 contrôles
ROM positifs, neuf erreurs de fichier attendues, scénario fetch positif,
erreur fetch acceptée attendue et smoke pipeline de signature 42 réussis.
Le modèle pipeline est exécuté pendant 100 cycles sans trap.
Log initial : /tmp/cf04-imem-check.log ; validation ciblée finale après revue
de compatibilité : /tmp/cf04-imem-final-check.log, code 0. Builds et journaux
détaillés dans
/tmp/cf04-imem-check. Lint du nouveau module, syntaxe des scripts et
git diff --check sont également contrôlés. Le lint du module passe sous
Verilator 4.038 et 5.040 ; le lint avec SYNTHESIS défini passe sous 5.040.
Cela ne constitue pas une validation de synthèse ni une exécution fonctionnelle
sous 4.038. Outils fonctionnels : g++ 11.4.0, Make 4.3, Python 3.10.12.

La première régression a été interrompue volontairement (code 143) après
19 suites PASS, sans échec de suite signalé, pour appliquer la revue de
compatibilité : ordre des paramètres existants préservé, table historique
inchangée et contrôle des erreurs attendues avec grep. Ce n'est pas une
régression complète réussie. Les preuves sont conservées dans
/tmp/cf04-attempt1-evidence, avec le snapshot de cette tentative.

La seconde régression termine avec code 0 : **26 suites PASS, 0 FAIL**,
sous Verilator 5.040, dans la nuit du 12 au 13 novembre 2026 (heure de Paris).
Elle inclut la nouvelle suite instruction_memory et les 25 suites antérieures.
Log
/tmp/cf04-full-validation.log et manifest
/tmp/cf04-full-validation/manifest.json. Empreinte de ce snapshot :
57ad98e2a36851d72740e89e1aa4bbc97a9316b94a86c86f931d6060bf0c9ff0.
Les builds externes existants sont réutilisés par make lorsque leurs entrées
sont inchangées ; le répertoire source du snapshot ne contient aucun build.
Les documents de résultats sont actualisés après l'exécution. La comparaison
finale confirme les 127 fichiers RTL/bancs/scripts/configuration exécutables
courants identiques à ceux du manifest, ainsi que la table historique exacte
et l'ordre des anciens paramètres. Les changements documentaires postérieurs
au snapshot ne changent pas les sources exécutables testées.

Preuves : summary.tsv, manifest.json et final-source-review.json dans
/tmp/cf04-full-validation. Empreinte des seules sources exécutables validées :
6623014a8403d98bc7359a4854c9565d8f7477b6b793b2bbe031598e90bf8dec.
Les 21 scénarios d'intégration JAL/JALR de CF-03 réussissent aussi. Les
artefacts sont temporaires : les commandes ci-dessus permettent de reproduire
les tests. Aucune réussite CI distante n'est revendiquée pour CF-04 local.

## Préservation et limites

Comparaison réalisée avec 1df38f7 : extraire dans fetch_path.sv le bloc entre
`    always_comb begin` et `    // Program counter.`, sans renommer de signal. Les deux textes sont identiques, avec l'empreinte
SHA256 :
006c6b6f8cd04349500696093b081e0271162c82f4e3147c577a74f6aec77175.
Cela contrôle aussi les adresses et les branches de sélection, pas seulement
la liste des mots machine.

Les tables de programmes 0–47 conservent leurs valeurs ; leur destination
interne instr_mem_data est conservée. Les wrappers ajoutent seulement des
paramètres par défaut neutres et les scripts ajoutent le nouveau module aux
listes explicites. La comparaison au commit de base et les résultats de
régression doivent être contrôlés ensemble : préserver des encodages ne prouve
pas l'absence de régression temporelle.

Les deux anciens tests load-invalid restent historiques. Pas d'installation,
ELF/BIN, toolchain, C, interface mémoire variable, injection de fetch faults
architecturaux ou preuve de synthèse. Les configurations extrêmes de capacité,
les bases non standard, les handlers de trap externes, les erreurs d'I/O en
cours de lecture et toutes les combinaisons de stalls et
exceptions ne sont pas couvertes exhaustivement.
