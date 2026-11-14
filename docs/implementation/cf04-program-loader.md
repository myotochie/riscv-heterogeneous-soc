# Implémentation CF-04 — HEX et programme assemblé

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

## CF-04.3/4 — Nouveaux fichiers logiciels et scripts

| Fichier | Responsabilité et changement |
|---|---|
| software/baremetal/cf04-smoke/start.S | Huit instructions réelles, labels _start/function/done ; appel direct et retour JALR |
| software/baremetal/cf04-smoke/link.ld | Entrée, région IMEM, PHDR exécutable, assertions de capacité et refus des sections nécessitant un startup |
| scripts/riscv_toolchain_env.sh | Résout et exporte les cinq outils ; aucun téléchargement ni installation implicite |
| scripts/build_baremetal.sh | Assemble, lie, désassemble, contrôle/convertit, extrait le BIN et compare ses octets au HEX |
| scripts/elf_to_hex.py | Analyse les structures ELF64, contrôle le mapping et les instructions, produit des mots little-endian |
| verification/unit/elf_to_hex/tb_elf_to_hex.py | Cas positifs réels/synthétiques et corruption ciblée d'ELF ; erreurs du linker |
| verification/integration/tb_baremetal_program.cpp | Séquence GPR complète attendue, x0 protégé, aucun trap et boucle terminale |
| verification/scripts/run_baremetal_program.sh | Construction logicielle puis simulation sur rv64_pipeline avec l'image réellement assemblée |

Le banc initial tb_external_program.cpp et les fixtures historiques restent
inchangés. Le nouveau banc exige, dans l'ordre : x2=64, x5=40,
x1=0x8000000c, x5=42, x10=42. Toute écriture GPR supplémentaire fait échouer
la comparaison. La signature relue dans x10 couvre SD puis LD. Au moins trois
slots MEM/WB du JAL terminal sont requis sur une fenêtre de 100 cycles.
Ce n'est ni un HALT ni une trace générale des effets architecturaux.

### Outils privés ou installation système

La tentative sudo sans interaction a été refusée car un mot de passe est
requis. Le paquet approuvé a donc été téléchargé et extrait sans privilège
sous .tools/binutils-riscv64-unknown-elf-2.35.1/. Aucun paquet système n'a été
installé. .gitignore exclut /.tools/ ; les binaires ne sont pas versionnés.

Dépendance : paquet Ubuntu Jammy binutils-riscv64-unknown-elf 2.35.1-0ubuntu1,
GNU Binutils 2.35.1, hôte amd64, cible riscv64-unknown-elf. Licence des outils
as/ld : GNU GPL version 3 ou ultérieure, confirmée par --version et le fichier
usr/share/doc/binutils-riscv64-unknown-elf/copyright du paquet.
SHA256 du .deb, vérifié contre les métadonnées APT :
e843ec1406f5ddfd19fb517c6328ec2ec71481949126986bd9d2502cfb347267.

Recette de reproduction privée (Ubuntu 22.04 amd64, après accord de
 téléchargement/extraction), depuis la racine du dépôt :

```bash
cf04_pkgdir="$(mktemp -d /tmp/cf04-binutils.XXXXXX)"
(cd "$cf04_pkgdir" && apt-get download binutils-riscv64-unknown-elf=2.35.1-0ubuntu1)
cf04_pkg="$cf04_pkgdir/binutils-riscv64-unknown-elf_2.35.1-0ubuntu1_amd64.deb"
printf '%s  %s\n' e843ec1406f5ddfd19fb517c6328ec2ec71481949126986bd9d2502cfb347267 "$cf04_pkg" | sha256sum -c -
mkdir -p .tools/binutils-riscv64-unknown-elf-2.35.1
dpkg-deb -x "$cf04_pkg" .tools/binutils-riscv64-unknown-elf-2.35.1
```

Priorité du résolveur : RISCV_PREFIX explicite ; sinon préfixe standard dans
PATH ; sinon emplacement privé du projet. Un outil absent provoque une erreur,
jamais un test sauté. La variable PATH n'est pas modifiée. Les scripts de
validation n'installent rien. Une machine différente doit fournir ces outils
ou configurer RISCV_PREFIX ; .tools/ n'est pas copié dans le snapshot source.

```bash
# Installation système, à exécuter par l'utilisateur après accord si souhaité :
sudo apt-get install binutils-riscv64-unknown-elf
# Une installation existante dans un autre répertoire :
RISCV_PREFIX=/chemin/bin/riscv64-unknown-elf- \
BUILD_DIR=/tmp/cf04-build bash scripts/build_baremetal.sh
# Installation privée locale déjà préparée :
BUILD_DIR=/tmp/cf04-build bash scripts/build_baremetal.sh
```

Le build exécute as -march=rv64i -mabi=lp64 -mno-relax, puis ld --no-relax
avec le linker script explicite. objdump -d -M no-aliases permet de lire les
instructions réelles. readelf conserve en-têtes, segments, sections et attributs.
La conversion directe ELF vers HEX est suivie d'une extraction indépendante
objcopy -O binary --only-section=.text ; les octets doivent coïncider.

### Conversion et préservation des fichiers

La fonction convert prend des octets et retourne texte HEX et métadonnées.
Elle vérifie toutes les plages avant copie. Les mots sont reconstruits avec
int.from_bytes(..., 'little'), puis formatés sur huit chiffres. Les données
BSS ne sont pas silencieusement interprétées comme des instructions.

La CLI refuse un même chemin en entrée/sortie, y compris les alias symboliques
et les liens physiques vers le même fichier. Un échec de validation laisse
l'entrée et un éventuel ancien fichier de sortie intacts. Ce convertisseur
reste limité au contrat text-only ; les cas ELF étendus ne sont pas supportés.

### Intégration de validation et CI

run_clean_regression.sh résout la toolchain avant de copier les sources,
puis exporte son préfixe absolu si l'installation privée est utilisée.
run_full_regression.sh inclut désormais software/ et les suffixes .S/.s/.ld
dans les empreintes et consigne les cinq versions Binutils dans le manifest.
La nouvelle suite est découverte automatiquement, portant le total attendu à 27.

Le workflow CI ajoute le paquet binutils-riscv64-unknown-elf à l'installation
et au relevé des versions. Cette modification prépare une future CI après
publication ; aucun résultat distant de ce nouveau jalon n'est présumé.
Aucun fichier RTL n'est modifié dans CF-04.3/4.
