# Vérification CF-04 — Résultats par jalon

## Périmètre et commandes

Les tests sont des simulations dirigées. Ils ne prouvent ni conformité ISA
complète ni synthèse FPGA. La première partie conserve les résultats historiques CF-04.1/2. Les nouvelles
commandes de régression incluent aussi la suite assemblée CF-04.3/4, qui exige
Binutils RISC-V. Les fixtures HEX initiales restent indépendantes de ces outils.

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

Preuves historiques : summary.tsv, manifest.json et final-source-review.json
archivés dans /tmp/cf04-hex-only-validation. Empreinte des seules sources exécutables validées :
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

## CF-04.3/4 — Programme assemblé, conversion et exécution

### Commandes

```bash
BUILD_DIR=/tmp/cf04-baremetal-build bash scripts/build_baremetal.sh
VERILATOR=/opt/verilator-modern/bin/verilator \
BUILD_ROOT=/tmp/cf04-assembled-check \
bash verification/scripts/run_baremetal_program.sh
```

Le résolveur utilise l'installation privée locale ou les outils standard du
PATH. RISCV_PREFIX peut désigner une autre installation. Aucun des runners
n'installe de dépendance. La CI est préparée pour fournir le paquet Binutils.
Le programme C, libc et un startup général ne font pas partie de ce jalon.

### Objectifs et stimuli

| Test | Stimulus / résultat attendu |
|---|---|
| ELF réel | Huit mots identiques au tableau du smoke CF-04.1/2, entrée 0x80000000, 32 octets |
| Identité/en-têtes | ELF32, big-endian, mauvais EM/type/version/flags/tailles/comptes ou tables tronquées rejetés |
| Configuration ROM | Base désalignée, capacité nulle/négative, entrée différente et débordement RV64 rejetés |
| Segments | Plages hors ROM, tailles incompatibles, BSS, permissions, LMA/VMA différents et alignements invalides rejetés |
| Chevauchement | Deux PT_LOAD superposés rejetés |
| Sections | Données/BSS allouées, noms invalides et mapping incohérent rejetés |
| ISA | LUI, AUIPC, ADDIW, MUL, LW, ECALL, forme JALR invalide et mots compressés rejetés |
| Relogeable | Objet as non lié refusé par le convertisseur |
| CLI | Erreur de validation préserve entrée et sortie préexistante ; alias symlink/hardlink refusés |
| Segments espacés | Deux mots aux offsets 0 et 12 produisent deux NOP entre eux |
| Linker | Section .data et texte de 4100 octets provoquent une erreur explicite |
| Comparaison indépendante | Octets objcopy .text identiques à la reconstruction little-endian du HEX |
| Pipeline | Exactement cinq writebacks GPR attendus, signature SD/LD 42, aucun trap, au moins trois slots done sur 100 cycles |

Fichiers : tb_elf_to_hex.py, tb_baremetal_program.cpp et
run_baremetal_program.sh. Les 13 méthodes unittest comprennent des variantes
paramétrées ; le nombre 13 ne représente pas un nombre d'instructions couvertes
ou une preuve exhaustive. Aucun test n'est sauté si la toolchain manque.

### Résultats ciblés observés

GNU as et ld 2.35.1 produisent l'ELF64 attendu. La sortie objdump sans alias
confirme les huit instructions et la cible function = 0x80000018. Le convertisseur
émet les mêmes mots que la fixture de référence. Les 13 méthodes Python
réussissent après ajout des tests du linker.

Le premier essai du cas de dépassement attendait le diagnostic « overflowed ».
Binutils 2.35.1 rejetait correctement le texte, avec « not within region ».
Une assertion explicite SIZEOF(.text) <= LENGTH(IMEM) fournit maintenant le
message stable « text exceeds instruction ROM » ; le test exige ce message.
La vérification de taille n'a pas été supprimée ou assouplie.

Le banc RTL ciblé puis la suite complète réussissent : cinq écritures GPR exactes, signature 42, 29 slots
MEM/WB de la boucle terminale, aucun trap sur 100 cycles. Logs initiaux :
/tmp/cf04-assembled-check.log ; fichiers ELF/BIN/HEX, désassemblage, readelf et
SHA256 dans /tmp/cf04-assembled-check/firmware.

La régression finale du 2026-11-14 termine avec code 0 : **27 suites PASS,
0 FAIL**, sous Verilator 5.040, g++ 11.4.0, Make 4.3, Python 3.10.12 et
GNU Binutils 2.35.1. La suite assemblée inclut les 13 méthodes Python et le
banc RTL ; les 26 suites antérieures sont également réexécutées.
Log : /tmp/cf04-full-validation.log. Résumé, manifest et revue finale :
/tmp/cf04-full-validation/{summary.tsv,manifest.json,final-source-review.json}.
Leurs 135 sources exécutables courantes correspondent au snapshot testé ;
aucun fichier RTL n'a changé depuis d336ca7.
Empreinte du snapshot :
3295d9d54ed543ed8a74bfda09d08945d37f378dadd35311742597a3cb702d18.
Empreinte des seules sources exécutables (.S et .ld inclus) :
776bd0cdd717465f9ac20d5a3e01018390d83bf73e4739b9a0467a002f45ad57.
Les résultats documentaires sont actualisés après validation ; ils ne changent
pas les octets des programmes, scripts et RTL exécutés. Les artefacts restent
temporaires et peuvent être reproduits par les commandes indiquées.

### Preuves et limites

La suite complète inclut maintenant 27 suites. Le manifest inclut les sources
software/ (.S et .ld) et les versions des cinq outils.
Les anciennes preuves 26 suites sont historiques et doivent être conservées
avant réutilisation des répertoires de build. La réutilisation d'objets dont
les entrées restent inchangées ne transforme pas un ancien résultat en PASS :
tous les exécutables sont relancés et le bilan courant est reconstruit.

Aucun test C, data/BSS startup, ELF dynamique/TLS, changement d'ISA, handler
externe ou synthèse FPGA n'est revendiqué. La comparaison objcopy indépendante
porte sur le smoke .text dense ; le cas multi-segment à trous est vérifié par
une fixture ELF synthétique. Le filtre d'instructions ne prouve pas les
adresses de tous les sauts ni le comportement d'un programme arbitraire.
Les slots MEM/WB observés ne constituent pas une trace architecturale CF-06.
