# CF-04 — Mémoire externe et chaîne assembleur bare-metal

## Périmètre et problème initial

Avant ce jalon, fetch_path contient uniquement des instructions choisies par
PROGRAM_ID. Changer de programme exige de modifier le RTL. CF-04.1/2 ajoutent
une image HEX externe sans modifier le protocole temporel du pipeline.
Le programme externe de vérification est encodé explicitement ; il n'est pas
encore issu d'un assembleur. Cette première partie décrit CF-04.1/2. La chaîne assembleur et la conversion
ELF/BIN réalisées ensuite sont détaillées dans la section CF-04.3/4 ci-dessous.

## Configuration et espace d'adressage

| Paramètre du frontend/top | Défaut | Sens |
|---|---|---|
| IMEM_FILE | chaîne vide | Vide : programmes historiques ; sinon image externe |
| IMEM_WORDS | 1024 | Capacité en mots de 32 bits, soit 4 Kio par défaut |
| IMEM_BASE | 0x80000000 | Adresse du premier mot, alignée sur quatre octets |
| PROGRAM_ID / RAW_TEST_PROGRAM | inchangés | Sélection historique lorsque IMEM_FILE est vide |

La dernière instruction accessible est à base + 4 × (WORDS − 1). La capacité
est strictement positive ; la plage ne doit pas déborder de l'espace 64 bits.
Le PC de reset reste 0x80000000 : changer IMEM_BASE ne change pas le reset.
Un autre placement demande donc un choix explicite du système de démarrage.

Pour une adresse valide, index = (adresse − base) / 4. La soustraction et le
contrôle de plage utilisent 64 bits avant toute conversion d'index : une
adresse haute ne doit pas aliaser la ROM par troncature de ses bits supérieurs.
Tous les mots non fournis par l'image sont initialisés au NOP 00000013.

## Format externe

Image dense : chaque jeton contient exactement huit chiffres hexadécimaux.
Les espaces, retours à la ligne et tabulations séparent les jetons. Un mot
par ligne est la convention recommandée. Pas de @adresse, commentaire, 0x,
underscore, valeur X/Z ou jeton d'un seul octet. Une image vide est rejetée.

Exemple : 00500093 désigne directement ADDI x1,x0,5. Ce mot aurait les octets
93 00 50 00 dans un fichier binaire little-endian. Le HEX de mots ne demande
pas d'inverser son texte. Un futur convertisseur ELF devra reconstruire ces
mots et vérifier placement, trous et limites de sections.

## Chemin de données et timing

```mermaid
flowchart LR
  PC[PC 64 bits] --> A[Soustraction base et contrôle plage/alignement]
  A --> ROM[ROM externe de mots 32 bits]
  LEG[Programmes intégrés 0 à 47] --> SEL[Sélection statique par IMEM_FILE]
  ROM --> SEL
  SEL --> IFID[IF/ID au front montant]
  IFID --> ID[Décodage existant]
  CTL[Reset / stall / flush / redirection] --> PC
  CTL --> IFID
```

La ROM est combinatoire. Au front montant, IF/ID capture le mot correspondant
à l'ancien PC ; le PC peut simultanément avancer. Aucun étage, handshake ou
cycle d'attente n'est ajouté. Le reset invalide IF/ID. Le flush prime sur son
stall. Les priorités PC reset, redirection puis stall restent celles de pc.sv.
Les paramètres sont transmis dans les wrappers fetch/decode/execute/top.

## Erreurs et précision

Le module ROM expose address_fault et retourne un NOP pour une adresse
invalide. En mode externe, fetch_path arrête la simulation au front si :
!reset && !flush && !stall_if_id && address_fault.
C'est un diagnostic de banc, pas une exception ISA : aucun mcause/mepc n'est
créé. Une adresse annulée par redirection avec flush ne doit pas faire échouer
la simulation. Une adresse tenue pendant un stall n'est pas encore acceptée.

MTVEC est remis à 0x80000100 dans csr_file.sv. Cette adresse est dans la
ROM par défaut, mais une petite image peut n’y fournir que le remplissage NOP.
Un futur programme avec traps devra installer un handler ou reconfigurer MTVEC.
Le smoke refuse explicitement tout trap ; il ne valide pas un handler externe.

Les erreurs de fichier sont détectées avant le chargement : fichier absent,
jeton invalide, image vide ou capacité dépassée. Le diagnostic initial est
exclu sous SYNTHESIS ; les opérations de fichiers sont des services de
simulation. Leur prise en charge par un outil FPGA doit être vérifiée.

## Mémoire de données et logiciel

La RAM données reste distincte : 4096 octets aux adresses basses, LD/SD alignés
à huit, little-endian. MEM_INIT_FILE reste indépendant de IMEM_FILE. Le smoke
utilise l'adresse 64 et n'exige aucune donnée initiale : SD précède LD.
Ce mapping Harvard simplifié n'est ni une mémoire unifiée ni un contrat ELF
complet. Au jalon CF-04, LUI/AUIPC et plusieurs instructions RV64I restaient
absentes. CF-05.2a ajoute désormais LUI/AUIPC ; voir
[le lot U](cf05-upper-immediates.md) pour les preuves et limites actuelles.

## Alternatives et évolution

| Choix | Avantage | Coût / limite |
|---|---|---|
| ROM combinatoire retenue | Préserve timing et contrôle existants | Inférence BRAM synchrone non assurée |
| ROM synchrone | Adaptée à certaines mémoires FPGA | Gestion de latence et réponses annulées à concevoir |
| Bus requête/réponse | Arbitrage et mémoire partagée futurs | Stall, suivi des transactions et redirections supplémentaires |
| Injection hiérarchique C++ | Peu de RTL initial | Couplage au simulateur et faible portabilité |

Aucune mesure de fréquence, de CPI ou de ressources n'est revendiquée. Ce
jalon n'ajoute pas de cycle mémoire par construction ; cela ne mesure pas le
CPI d'un programme. Le multicœur demandera une interface mémoire explicite.

Voir [implémentation](../implementation/cf04-program-loader.md),
[vérification](../verification/cf04-program-loader.md),
[cours](../learning/cf04-program-loader.md) et
[décisions](../decisions/cf04-program-loader.md).

## CF-04.3/4 — Du source assembleur au programme exécuté

Le jalon suivant utilise maintenant un véritable assembleur et un linker
GNU RISC-V. Le premier programme n'est plus une liste de constantes HEX :
start.S produit un objet relogeable, puis un ELF lié à l'adresse de reset.

```mermaid
flowchart LR
  ASM[start.S] --> AS[GNU as rv64i / lp64 / no-relax]
  AS --> OBJ[Objet relogeable]
  OBJ --> LD[GNU ld + link.ld]
  LD --> ELF[ELF64 RISC-V little-endian]
  ELF --> CHECK[Contrôles ELF / segments / sections / instructions]
  CHECK --> HEX[HEX dense de mots]
  HEX --> ROM[ROM externe existante]
  ROM --> CPU[Pipeline inchangé]
  CPU --> TB[WB attendu + signature 42 + boucle finale]
  ELF --> OBJCOPY[Extraction indépendante objcopy .text]
  OBJCOPY --> BIN[Octets BIN comparés au HEX]
```

### Mapping logiciel et point d'entrée

Le linker fixe _start = 0x80000000 et borne .text à 4096 octets. Un unique
PT_LOAD de lecture/exécution contient le texte. .data, .rodata, .bss et leurs
formes small-data sont refusées : aucun démarrage de données ou de libc n'est
introduit. La RAM basse reste indépendante ; le programme écrit 42 à
l'adresse 64 avant de la relire. Les registres employés sont initialisés par
les instructions du programme ; aucun reset implicite de toute la RAM/GPR
n'est supposé. Le reset matériel ne lit pas e_entry : notre chaîne impose
que e_entry corresponde au reset existant.

Le programme est identique instruction par instruction au smoke encodé du
premier jalon. La relocation JAL est cette fois résolue par GNU ld. La boucle
done à 0x80000014 est un signal de fin observé par le banc, pas une instruction
d'arrêt matérielle. Le test laisse fonctionner 100 cycles et exige la bonne
séquence de writeback et plusieurs passages par le slot MEM/WB de done.
Ce slot n'est pas une interface de trace architecturale CF-06.

### Contrat de conversion ELF

elf_to_hex.py utilise struct, argparse et pathlib de Python, sans pyelftools.
Il accepte un ELF64 little-endian version 1, ET_EXEC, EM_RISCV, flags zéro
(contrat LP64 sans RVC/float/RVE), avec tables ordinaires de programmes et
sections. Il refuse les objets non liés, les programmes dynamiques/interprétés
ou TLS, et les segments PT_LOAD autres que lecture/exécution.

Chaque segment chargé doit avoir des tailles fichier/mémoire identiques,
positives et multiples de quatre, des adresses physique/virtuelle identiques,
un alignement cohérent, une plage dans la ROM et aucun chevauchement avec
un autre segment chargé. Les sections allouées non vides doivent être du
code PROGBITS non writable et être mappées de façon cohérente dans un segment.
Les trous entre segments deviennent NOP, sans concaténation qui perdrait les
adresses. Les en-têtes et données tronqués sont rejetés avant indexation.

Les mots émis sont filtrés selon le sous-ensemble courant : opérations R
prises en charge, ADDI, LD/SD, six branches, JAL/JALR légaux, MRET et formes
CSR sur les cinq adresses machine connues. Cette liste est volontairement
plus restrictive que l'ensemble RV64I autorisé par l'assembleur. Ce contrôle
n'est pas une preuve du comportement des programmes ni de conformité des CSR.

### Toolchain et limites

Binutils bare-metal suffit pour ce programme assembleur. Aucun compilateur
C ni libc n'est installé. L'extension C et la relaxation sont désactivées
explicitement. Les binaires outils sont des dépendances hôte ; le CPU ne
charge pas un ELF lui-même et ne connaît pas le système de fichiers.
Le RTL, les mécanismes de forwarding et les priorités de traps ne changent pas.
