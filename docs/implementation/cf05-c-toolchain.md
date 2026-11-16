# CF-05.1 — Implémentation du corpus et de l'inventaire

> État courant après CF-05.2b : huit opérations immédiates supplémentaires,
> soit 31 formes présentes. Les résultats ci-dessous restent ceux du jalon
> historique ; voir [le lot immédiat](cf05-immediate-alu.md).

> Résultats historiques CF-05.1 : 21 formes présentes avant ajout RTL.
> CF-05.2a ajoute LUI/AUIPC ; la matrice dynamique et le garde ELF
> au jalon CF-05.2a comptent 23 formes. Voir [le lot U](cf05-upper-immediates.md).

## Dépendances et installation privée

GCC RISC-V n'était pas installé. Après accord, le paquet Ubuntu Jammy amd64
`gcc-riscv64-unknown-elf` 10.2.0-0ubuntu1 a été téléchargé puis extrait dans
.tools/gcc-riscv64-unknown-elf-10.2.0/. Aucun paquet système n'est installé et
PATH n'est pas modifié. .tools/ est déjà exclu de Git par CF-04.

SHA256 du paquet vérifié contre APT :
3385ad3d2e8f9b076fe73a2559393ff34f14c51556ec2f3595f042d6e6e06bfb.
GCC indique 10.2.0, cible riscv64-unknown-elf. Le copyright du paquet indique
GPL version 3 ou ultérieure pour GCC ; les composants runtime ont leurs termes
spécifiques. Aucun runtime de ce paquet n'est lié aux expériences.
Les dépendances hôte libc, libgcc-s1, gmp, mpc, mpfr, libstdc++ et zlib étaient
déjà présentes. Binutils 2.35.1 reste l'installation privée CF-04.

Recette privée Ubuntu 22.04 amd64, depuis la racine après accord :

```bash
cf05_pkgdir="$(mktemp -d /tmp/cf05-gcc.XXXXXX)"
(cd "$cf05_pkgdir" && apt-get download gcc-riscv64-unknown-elf=10.2.0-0ubuntu1)
cf05_pkg="$cf05_pkgdir/gcc-riscv64-unknown-elf_10.2.0-0ubuntu1_amd64.deb"
printf '%s  %s\n' 3385ad3d2e8f9b076fe73a2559393ff34f14c51556ec2f3595f042d6e6e06bfb "$cf05_pkg" | sha256sum -c -
mkdir -p .tools/gcc-riscv64-unknown-elf-10.2.0
dpkg-deb -x "$cf05_pkg" .tools/gcc-riscv64-unknown-elf-10.2.0
```

## Résolution explicite du compilateur et des outils

scripts/riscv_c_toolchain_env.sh source le résolveur Binutils existant.
RISCV_GCC explicite prime ; sinon le gcc bare-metal dans PATH, puis le chemin
privé du projet. La cible doit être riscv64-unknown-elf.

Le premier essai avec -B suivi du seul répertoire bin sélectionnait l'as natif
x86 et échouait sur -march=rv64i. Le préfixe retenu est maintenant le chemin
absolu de RISCV_AS sans son suffixe as : .../riscv64-unknown-elf-.
Le helper vérifie -print-prog-name=as et =ld contre les outils choisis,
par identité du fichier exécutable après résolution par command -v.
Un compilateur natif ou absent est rejeté. Cela évite une compilation croisée
apparemment configurée qui appellerait des outils d'une autre cible.

## Corpus software/baremetal/cf05-probes

| Fichier | Question mesurée |
|---|---|
| arith64.c | Opérations 64 bits, immédiats, shifts variables et conditions signées |
| arith32.c | Calcul unsigned 32 bits, shifts W, extension vers unsigned long |
| memory.c | Somme de tableau 64 bits, six tailles/extensions de loads, quatre stores |
| calls.c | Appels imbriqués noinline, sauvegardes et restaurations observées |
| globals.c | data, bss, table rodata, adresses selon modèle de code |
| function_pointer.c | Adresse d'une fonction dans la ROM haute |
| runtime_helpers.c | Multiplication/division/reste sans extension M |
| late_globals.c | Accès à une donnée basse depuis du code près de la fin de ROM |
| probe.ld | Layout d'inspection, code/late et données basses, sans startup |

Les opérations unsigned évitent les débordements signés indéfinis. Les shifts
variables sont masqués à 31 ou 63. Le shift signé suit ici la génération GNU
pour cette cible. runtime_helpers n'est jamais exécuté. Son diviseur est rendu non nul par OR
avec 1 ; aucun harness ne fournit cependant des arguments ou un startup aux sondes.

## Scripts d'analyse

scripts/inspect_c_toolchain.sh résout les outils et lance le Python sans créer
de dépendance Python externe. BUILD_ROOT doit être un répertoire de résultats,
par défaut temporaire. Les chemins explicites de toolchain doivent être absolus
pour pouvoir être transmis à un snapshot propre.

scripts/inspect_c_toolchain.py compile chaque source à O0/O1/O2 et medlow/medany
avec -save-temps=obj. Il conserve .i, .s, .o, les commandes et leurs diagnostics.
readelf consigne les attributs, relocations et symboles ; objdump utilise -d -z
-M no-aliases. Le zéro est désassemblé et les formes non 32 bits sont refusées.
Le choix de libgcc/multilib est enregistré mais aucune bibliothèque n'est liée.

Chaque objet est lié pour trois bases RAM. --defsym est placé avant -T :
l'expression MEMORY doit voir la valeur choisie. Les symboles de l'ELF lié
confirment que CF05_RAM_BASE correspond effectivement à la valeur demandée.

Seuls deux refus sont classés comme résultats attendus de l'expérience :
helpers connus non résolus dans runtime_helpers ; R_RISCV_HI20 hors plage dans
function_pointer/medlow. Toute compilation échouée, autre erreur de lien,
outil manquant ou mot inconnu dans les tests fait échouer l'inspection.
Les diagnostics bruts restent conservés ; aucune exception n'est présentée
comme succès d'exécution C. Les sources sont hachées avant/après pour détecter
une édition persistante du corpus pendant l'inspection.

Sorties : inventory.json contient configurations, compteurs, symboles non
résolus, états de lien et matrice ; summary.tsv liste les 144 résultats ;
isa_matrix.tsv fournit les 52 lignes. Les ELF portent l'état linked_not_executed.

## Décodeur logiciel et preuves de couverture

scripts/riscv_isa_inventory.py nomme les formes de base à partir des bits,
et réutilise le garde CF-04 pour l'acceptation actuelle des encodages. La table
RTL est un inventaire audité, pas une preuve formelle extraite du SystemVerilog.
Chaque ligne distingue présence, sources de tests et limite de couverture.

verification/unit/cf05_inventory/isa_base.S contient une forme de chacune des
52 instructions de base. GNU as/objcopy fournissent un oracle indépendant de
bits pour tester le décodeur logiciel. Cette fixture n'est pas exécutée sur
le CPU. tb_inventory.py teste aussi parseurs, rapports et choix du compilateur.
run_cf05_inventory.sh l'intègre au lanceur sans modifier les bancs existants.

## Intégration aux manifests et CI

Les deux lanceurs complets résolvent GCC avant le snapshot et héritent du
préfixe des outils privés. Les empreintes incluent désormais les fichiers .c.
Le manifest relève la version GCC en plus des cinq Binutils. La CI ajoute le
paquet GCC bare-metal à l'installation et au relevé des versions ; elle conserve
aussi inventory.json, summary.tsv et isa_matrix.tsv dans les artefacts. Les suites
RTL isolées restent utilisables séparément sans le corpus GCC.
Aucun module RTL, filtre elf_to_hex, programme historique ou comportement
architectural n'est modifié dans ce jalon.

## Correctif de portabilité du résolveur après publication CF-05.1

Le workflow 43769889000 du commit d0b0a97 échoue avant les tests :
`[ERROR] GCC target/as/ld do not match the selected bare-metal Binutils`.
La construction de Verilator et l'enregistrement des dépendances réussissent.
Les chemins exacts du runner ne figuraient pas dans le diagnostic initial :
leur différence de représentation reste une hypothèse à confirmer en CI.

Le contrôle initial utilisait `!=` entre chaînes. Il rejetait donc un chemin
avec `../` ou un lien symbolique vers le bon outil. Le nouveau contrôle garde
la cible exacte `riscv64-unknown-elf`, résout les noms avec `command -v`,
exige des fichiers exécutables, puis utilise le test Bash `-ef` : deux chemins
sont équivalents lorsqu'ils désignent le même fichier (périphérique/inode).
Il ne suffit pas que deux binaires annoncent la même version.

La fonction de contrôle s'exécute dans un sous-shell pour garder ses variables
internes locales, puis est supprimée. Les variables publiques et le préfixe
`-B .../riscv64-unknown-elf-` restent inchangés. En cas de désaccord, le script
affiche GCC, sa cible, les chemins sélectionnés, rapportés et résolus pour
as/ld. Une erreur de commande GCC est également propagée. Aucun fallback
silencieux vers l'assembleur natif n'est ajouté.

Le test `test_compiler_resolver_tool_identity_and_diagnostics` utilise un
pilote factice limité aux requêtes de découverte : chemins avec `../` et
symlinks, nom trouvé dans PATH, assembleur distinct, linker inexistant et cible
incorrecte. Les compilations et liens du corpus utilisent séparément les vrais
outils. Ce correctif ne modifie aucun RTL ni format ELF/HEX.
