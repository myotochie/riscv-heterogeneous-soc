# Journal d'avancement du projet

## Convention de preuve

Un commit identifie un état versionné. Un travail local peut être réalisé sans
être commité ; ses preuves doivent alors citer les sources/empreintes du
manifest de validation. « Testé » signifie simulation dirigée sauf mention
contraire. Aucun FPGA, résultat de synthèse ou conformité complète n'est déduit
d'un PASS Verilator.

## Fonctionnalités et versions

| Travail | État vérifié | Commit / référence |
|---|---|---|
| Cœur cinq étages, ALU, GPR, hazards et forwarding | Existant, tests dirigés | Historique antérieur à CF-01 |
| LD/SD et traps mémoire précis | Existant, suites dédiées | Historique intégré dans main |
| CSR machine partiels et MRET | Existant, suites dédiées | main inclut 70ca6cd et travaux associés |
| CF-01 : décodage six branches | Intégré dans main | bc4a80b |
| CF-02 : branches en EX | Intégré dans main, suites existantes | 81eb817 |
| CF-03 : JAL/JALR et défauts de cible | Intégré dans main, CI réussie | 66e4a88 ; correctifs CI fefe06f et 1df38f7 |
| CF-04.1/2 : mémoire instructions HEX | Publié et intégré dans main, CI réussie | d336ca7 |
| CF-04.3/4 : chaîne assembleur/ELF | Publié et intégré dans main, CI réussie | 6beccd1 |
| CF-05.1 : GCC et matrice ISA | Fusionné dans main ; CI réussie | d0b0a97, correctif 6b38e8a ; workflow main 43932603325 |
| CF-05.2a : LUI/AUIPC | Fusionné dans main, CI réussie ; 29 suites locales PASS | dfa4ce4 ; CI main 43947114463 |
| CF-05.2b : huit opérations immédiates | Validé localement : 30 suites PASS, 0 FAIL ; 14 exécutions OP-IMM | Modifications non commitées |
| CF-05.2 suite–5 : ISA, ABI, startup et C exécuté | Futur ; plan à valider après mesures | Aucun |
| CF-06 : trace et comparaison référence | Futur | Aucun |
| CF-07 : multicœur et intégrations | Futur | Aucun |

## Revue corrective CF-03 autorisée

- Fixture LD autrefois locale/ignorée : génération dans le build.
- Datapath pédagogique : restriction à son sous-ensemble sans PC ; test de
  rejet de JAL/JALR et des familles non exécutables, sans altérer le pipeline.
- Banc CSR : ports lecture/écriture modernisés et test d'adresses indépendantes.
- Stimuli CSR CF-03 : utilisation de MEPC/MTVEC réellement implémentés,
  à la place d'un mscratch dont le stockage n'existe pas.
- Contrôles JALR : arrêt/flush/reset ajoutés ; nouvelle collision MEM/JALR (ID 47).
- Initialisation explicite de la donnée observée pour les stores annulés.
- Sélection outil et répertoires de build homogénéisés ; suppression des
  nettoyages destructifs automatiques des runners CSR.
- Lanceur complet et snapshot sans fichiers ignorés, manifest SHA256 et bilan.
- Workflow CI complet préparé avec Verilator 5.040 et conservation des preuves.
- Dossiers architecture/implémentation/vérification/cours/décisions ajoutés ;
  README et vue d'ensemble alignés sur l'état effectif.

## Tests et résultats

Les premiers résultats CF-03 (avant cette revue) annonçaient 25 suites, 17
scénarios et 9 266 checks sur deux versions. L'audit a confirmé ces logs mais
a identifié des limites de reproductibilité et de stimuli. Ne pas réutiliser
ces résultats comme preuve des corrections ultérieures.

La régression corrective a terminé le 2026-11-10 avec code 0 : **25 suites
actives PASS, 0 FAIL**, depuis un snapshot sans fichiers ignorés. Les 21
scénarios JAL/JALR passent sous 5.040 ; les 9 266 checks unitaires passent sous
4.038 et 5.040. Le banc CSR passe 18 checks, le datapath historique 19 et le
registre EX/MEM 68. Les programmes 0–35 et les deux sources historiques sont
préservés exactement par rapport à HEAD.

Manifest : `/tmp/cf03-review-validation/manifest.json` ; résumé :
`/tmp/cf03-review-validation/summary.tsv`. Empreinte des sources exécutables :
`f463c9560a8ee0d804a030bcf7b202ea4ab3e261183cd909bc258e28d941066a`.
Les artefacts locaux sont temporaires ; les commandes permettent leur
reproduction. Aucune publication ni exécution CI distante n'a été effectuée.
Le dossier [vérification CF-03](verification/cf03-jumps.md)
contient les commandes, objectifs, limites et références des résultats réels.

## Limitations et dette technique connues

- Sous-ensemble RV64I incomplet ; pas de M/A/F/D/C, LUI/AUIPC et plusieurs
  instructions de base manquent. Pas de revendication de conformité entière.
- CSR partiels ; pas de trap général illegal instruction, pas d'interruptions.
- ROM intégrée ou image HEX externe ; pas de trap architectural de faute fetch.
- RAM 4 Kio à lecture combinatoire ; pas de bus à latence variable ni MMIO général.
- Pas de reset général GPR/RAM : initialisation nécessaire aux tests/logiciels.
- Deux anciens bancs load-invalid conservés comme historiques et catalogués,
  car leurs attentes de poursuite après faute contredisent les traps précis.
- Pas de trace architecturale complète, Spike, mesures CPI de référence ou FPGA.
- La CI de main valide CF-03 sur 1df38f7 ; CF-04 reste local et non publié.

## Git : état initial de la revue CF-03 (historique)

Branche de travail : feat/rv64-program-loader. Parent : 81eb817.
L'audit distant du 2026-11-10, en lecture seule, a constaté main=aec569b et l'absence de la
branche courante sur GitHub ; il s'agit d'un constat daté, pas d'une garantie
sur un futur état distant. La PR #1 mémoire était encore ouverte et la PR #2
corrective CI fusionnée. Aucun fetch n'a été nécessaire à ce constat API.

Le 2026-11-10, après revue des résultats, l'utilisateur a autorisé commit,
push et merge avant CF-04. La publication reste conditionnée à un accès GitHub
fonctionnel et la fusion à une CI réussie sur le commit publié. La création
d'une PR n'a pas été demandée ; une avance rapide sera utilisée si possible.

Le premier contrôle SSH de publication retourne `Permission denied (publickey)`.
L'environnement ne présente ni agent SSH accessible ni identifiant HTTPS GitHub
configuré. Le commit local peut être réalisé ; aucun push, merge ni succès de
CI distante ne peut être déclaré sur cette base. Message du commit préparé :
`feat(rv64): validate jumps and precise control-flow traps`.

Le workflow est maintenant déclenché également par les pushes de la branche
courante, pour vérifier la CI avant une fusion sans PR. Ce changement de
sélection des événements est postérieur à la régression locale : il ne modifie
ni RTL, ni banc, ni commande de vérification. Les résultats locaux et leurs
empreintes antérieures restent conservés ; une CI distante devra valider le
commit final incluant ce déclenchement.

## Prochains jalons

1. Revoir le lot CF-05.2b, validé par la régression finale de 30 suites.
2. Attendre les accords distincts de commit, push et fusion du lot immédiat.
3. Proposer le lot ISA suivant à partir des besoins GCC mesurés, avec tests
   de forwarding, annulation, x0 et limites avant implémentation.
4. Définir mapping, origine des initialiseurs, ABI/pile et startup avant C exécuté.
5. Évaluer un runtime logiciel compatible avant toute décision d'ajouter M.

## Publication CF-03 : incident de démarrage CI

Le commit CF-03 `66e4a882198a76de69f82ffd7c535a2d6a95ee52` a été créé, puis
poussé par l'utilisateur sur origin/feat/rv64-program-loader. Le 2026-11-10,
l'API GitHub confirme ce SHA sur la branche. L'exécution Actions
[42911082817](https://github.com/myotochie/riscv-heterogeneous-soc/actions/runs/42911082817)
a échoué à la validation du workflow : aucun job ni test RTL n'a été lancé.
L'annotation signale à la ligne 19 le contexte runner non reconnu dans
jobs.rtl-regression.env.

Correctif préparé : déplacer VALIDATION_ROOT dans l'env de l'étape
Record dependency versions, qui est son seul consommateur. Les autres emplois
de runner.temp sont déjà dans des contextes d'étape valides. Les sources RTL,
les bancs et les scripts restent identiques aux sources vérifiées localement.
Le correctif n'est pas encore commité ; une nouvelle exécution distante doit
réussir sur son commit avant fusion. main reste aec569b lors de ce contrôle.

### Deuxième exécution : état observé le 2026-11-11

Le correctif de contexte a été commité en `fefe06f` et poussé par l'utilisateur.
L'exécution [42912197307](https://github.com/myotochie/riscv-heterogeneous-soc/actions/runs/42912197307)
démarre correctement mais échoue pendant la compilation de Verilator (code 2).
Les tests RTL n'ont pas été exécutés. Les journaux détaillés nécessitent un
accès GitHub authentifié indisponible dans l'environnement de diagnostic.

Une reproduction locale avec les sources officielles v5.040 avait été lancée dans
`/tmp/cf03-ci-build.BE1eQk`. Une modification locale du workflow conserve dès
le début le journal de compilation dans les artefacts, y compris en cas
d'échec ; sa propagation des erreurs et son écriture de journal sont vérifiées.
La cause distante reste à confirmer. Aucun nouveau commit, push ni merge
n'est réalisé. Les détails et limites figurent dans la section 13 du document
de vérification CF-03.

Le journal distant fourni ensuite par l'utilisateur confirme la cause :
`FlexLexer.h` introuvable pendant la compilation de V3ParseLex.cpp. Le workflow
local ajoute explicitement `libfl-dev`, son relevé de version et un contrôle
immédiat d'inclusion de l'en-tête. La compilation de ce contrôle réussit
localement ; YAML et Bash sont vérifiés. Aucun paquet système local n'est
installé. Le correctif attend commit/push autorisés puis une nouvelle CI ;
aucune réussite distante ni fusion n'est encore annoncée.

## Clôture CF-03 et démarrage CF-04.1/2

La branche main a été avancée de aec569b vers 1df38f7 le 2026-11-11 après
autorisation. La consultation GitHub du 2026-11-12 confirme le succès de
[la CI main 43008983835](https://github.com/myotochie/riscv-heterogeneous-soc/actions/runs/43008983835)
sur ce SHA. Les mentions précédentes d'absence de publication sont historiques.

Après audit en lecture seule et accord explicite, ajout d'une ROM externe de
mots HEX et transmission de ses paramètres dans les frontends. Les programmes
0–47 sont préservés ; comparaison exacte de la table réussie. Le défaut conserve le chemin historique.

Validation ciblée sous Verilator 5.040 : 24 contrôles ROM positifs, neuf erreurs
de fichier attendues, fetch externe reset/stall/flush/redirection, erreur
d'adresse acceptée attendue et smoke pipeline JAL/JALR + SD/LD de signature 42
réussissent. La régression complète finale depuis snapshot termine avec
code 0 : **26 suites PASS, 0 FAIL**, dans la nuit du 12 au 13 novembre 2026.
La première tentative, interrompue pour revue de compatibilité après 19 PASS,
n'est pas comptée comme régression complète ; ses preuves restent conservées.
Logs finaux : /tmp/cf04-imem-final-check.log et /tmp/cf04-full-validation.log.
Manifest, summary.tsv et final-source-review.json : /tmp/cf04-full-validation.
Les 127 sources exécutables courantes correspondent au snapshot final ; la
table 0–47 et l'ordre des anciens paramètres sont conservés.
Empreinte des sources exécutables :
6623014a8403d98bc7359a4854c9565d8f7477b6b793b2bbe031598e90bf8dec.

Documentation CF-04 : architecture, implémentation, vérification, apprentissage
et décisions, fichiers cf04-program-loader.md dans les cinq dossiers dédiés.
Aucun paquet installé ; aucun commit/push/merge CF-04. Toolchain et programme
assemblé restent à préparer après revue de CF-04.1/2. Limite importante : les
adresses fetch invalides sont des diagnostics de simulation, sans trap ISA.

## CF-04.1/2 publié ; démarrage CF-04.3/4

Après accord, d336ca7 a été créé, poussé et intégré par avance rapide dans main.
Les CI [branche 43325835380](https://github.com/myotochie/riscv-heterogeneous-soc/actions/runs/43325835380)
et [main 43371380763](https://github.com/myotochie/riscv-heterogeneous-soc/actions/runs/43371380763)
ont réussi. Preuve locale de publication : /tmp/cf04-publication.json.
Les mentions antérieures de CF-04 non publié décrivent la revue précédente.

L'audit CF-04.3/4 puis le plan ont été approuvés le 2026-11-14. Aucune toolchain
RISC-V n'était disponible dans les emplacements inspectés. L'installation sudo
non interactive exigeait un mot de passe ; le paquet approuvé Binutils
2.35.1-0ubuntu1 a été extrait dans .tools/, ignoré par Git. Son SHA256 est
vérifié ; GNU as/ld ciblent riscv64-unknown-elf et indiquent GPLv3 ou ultérieure.
Aucun paquet système, compilateur C ni libc n'est installé.

Le programme start.S et link.ld produisent un ELF64 little-endian de huit
instructions à 0x80000000. Le convertisseur contrôle les structures, segments,
sections et instructions ; objcopy confirme indépendamment les octets. Les
13 méthodes de tests Python passent avec leurs variantes négatives. Le banc
RTL observe les cinq writebacks attendus, la signature mémoire 42, 29 slots
de boucle terminale et aucun trap sur 100 cycles. La régression complète
finale du 2026-11-14 termine avec code 0 : **27 suites PASS, 0 FAIL**.
Les 135 sources exécutables correspondent au snapshot, software/ inclus ;
aucun RTL ne change depuis d336ca7. Preuves actuelles :
/tmp/cf04-full-validation/{manifest.json,summary.tsv,final-source-review.json}
et /tmp/cf04-full-validation.log. Preuves antérieures 26 suites archivées dans
/tmp/cf04-hex-only-validation. Empreinte des sources exécutables :
776bd0cdd717465f9ac20d5a3e01018390d83bf73e4739b9a0467a002f45ad57.

Les cinq documents CF-04 et les manifests sont étendus à software/ et aux
versions Binutils. Aucun RTL n'est modifié. Aucun commit/push/merge de
CF-04.3/4 n'est autorisé ni réalisé à ce stade.

## Publication CF-04.3/4 et démarrage CF-05.1

Après accord explicite, CF-04.3/4 a été publié en 6beccd1 et intégré dans main.
Les CI [branche 43639600602](https://github.com/myotochie/riscv-heterogeneous-soc/actions/runs/43639600602)
et [main 43640716641](https://github.com/myotochie/riscv-heterogeneous-soc/actions/runs/43640716641)
ont réussi. Publication consignée dans /tmp/cf04-asm-publication.json.
L'audit CF-05 du 2026-11-15 confirme ce SHA sur main et la branche courante,
un checkout initial propre et aucun GCC RISC-V disponible.

Après accord limité à CF-05.1, GCC 10.2.0-0ubuntu1 est téléchargé et extrait
dans .tools/, avec SHA256 vérifié. Aucun paquet système ni libc invité n'est
installé. Le résolveur utilise les Binutils 2.35.1 déjà présents et vérifie
que GCC sélectionne bien leur as/ld. Le premier -B trop général avait
sélectionné l'as x86 ; le préfixe complet est désormais vérifié par les tests.

Huit sondes C produisent 48 configurations objets et 144 tentatives de lien :
117 liées non exécutées, 9 refus de relocation et 18 refus de helpers non liés.
Les huit méthodes de tests de l'inventaire passent. La matrice de 52 formes
indique 21 présentes dans le RTL et 28 absentes observées dans les objets.
Six cas montrent AUIPC dans l'objet puis LUI dans l'ELF final. Aucun programme
C de ces sondes n'est exécuté sur RTL. Aucun module RTL, garde de chargement
CF-04 ou programme historique n'est modifié.

Cinq documents CF-05.1 et une matrice détaillée sont créés. La régression
complète finale du 2026-11-15 termine avec code 0 : **28 suites PASS, 0 FAIL**.
Les 151 sources exécutables correspondent au snapshot ; les huit tests de
l'inventaire incluent un oracle GNU as pour 52 formes, jamais exécutées sur RTL.
Les preuves courantes sont /tmp/cf05-full-validation.log et
/tmp/cf04-full-validation/{manifest.json,summary.tsv,final-source-review.json}.
Empreinte des sources exécutables :
ba137aa098d506302ca4622102100ca6aef553c853028fa35981c2632aa86cc7.
Les trois rapports agrégés sont prévus dans les artefacts CI ; le workflow
préparé n'est pas encore publié. Les choix ISA,
startup et mapping mémoire nécessitent un plan ultérieur. Aucun commit, push
ou merge CF-05 n'est autorisé ou réalisé à ce stade.

Les répertoires de builds CF-04 sont réutilisés pour éviter de recompiler les
modèles inchangés. Les résultats historiques restent distincts : 26 suites
dans /tmp/cf04-hex-only-validation, puis 27 suites dans
/tmp/cf04-assembled-validation. Les chemins /tmp/cf04-full-validation cités
dans les anciennes entrées sont ceux de leur exécution initiale ; ce dossier
contient désormais le bilan courant CF-05.1, et son pilote est
/tmp/cf05-full-validation.log.

## Correctif du résolveur GCC/Binutils — après d0b0a97

- Workflow 43769889000 en échec : contrôle de cohérence des outils avant RTL.
- Comparaison textuelle remplacée par identité du fichier exécutable, cible
  bare-metal et caractère exécutable toujours requis ; diagnostics détaillés.
- Vérification ciblée : neuf méthodes PASS, dont cinq scénarios de résolution.
- Régression complète du correctif : 28 suites PASS, 0 FAIL, Verilator 5.040.
- Aucun changement RTL ; LUI/AUIPC suspendu pour publier CF-05.1 séparément.
- Commit, push et fusion du correctif soumis aux autorisations distinctes.
- Résolution distante confirmée après publication : CI main 43932603325 réussie
  sur 6b38e8a, fusion vérifiée le 2026-11-16.

## CF-05.2a — Lot LUI/AUIPC approuvé

- Trois modules RTL : décodage sans sources, immédiat U signé, choix A en EX.
- Chemins ordinaires de forwarding/WB et gardes d'annulation préservés.
- Ciblé Verilator 5.040 : 6 337 536 contrôles unitaires, quinze scénarios pipeline.
- Tests : signe, PC 64 bits, rd0, faux load-use, bypasses, SD/LD, JALR,
  priorités de producteurs, branch/flush/reset/stall, trap précis et MRET.
- Filtre ELF et matrice dynamique mis à jour : 23 formes sur 52 présentes.
- Inventaire GCC : neuf méthodes PASS, 48 objets, liens 117/9/18 inchangés ;
  aucune exécution C sur le RTL.
- Startup et origine des initialiseurs .data non implémentés, décision future.
- Documentation dédiée dans les cinq dossiers ; aucun commit/push/merge autorisé
  pour ce nouveau lot à ce stade.

### Bilan final local CF-05.2a

La passe finale termine avec code 0 : **29 suites PASS, 0 FAIL**, Verilator
5.040, quinze exécutions pipeline U. Le test combinatoire produit 6 337 536
contrôles PASS sous 5.040 et, séparément, sous 4.038. Les 157 fichiers de
sources du manifest ont été comparés aux fichiers courants : identiques.
Les programmes de fetch intégrés et le smoke assembleur CF-04 sont inchangés.

Snapshot final :
`7493daf1ec3cefe13c62bc034171087cf33449655cbc9c4de446a197ebeefbcf`.
Preuves : `/tmp/cf04-full-validation/manifest.json`, `summary.tsv`,
`cf05-upper-source-review.json` et `/tmp/cf05-upper-final-validation.log`.
Le nom historique cf04 du répertoire de build ne désigne pas le contenu du
lot ; le manifest identifie les sources réellement exécutées.

La première passe complète (29 PASS sur les premiers tests U) est conservée
sous `/tmp/cf05-upper-first-validation`. La revue a ensuite renforcé les
bases mémoire, le forwarding AUIPC→JALR direct et les contrôles AUIPC ; la
passe finale couvre ces tests. Seuls des documents ont été mis à jour après
ce dernier snapshot, sans changement des sources exécutables. Publication
et CI distante du lot U restent en attente d'autorisations.

## Publication CF-05.2a et démarrage CF-05.2b

Le commit dfa4ce4 ajoute LUI/AUIPC, est poussé puis fusionné dans main par
avance rapide après autorisations distinctes. CI de branche 43942823876 et
CI main 43947114463 réussies ; cette dernière vérifiée le 2026-11-16.
Le répertoire local était propre sur feat/rv64-program-loader avant le lot suivant.

Après audit et validation du plan, CF-05.2b ajoute SLTI, SLTIU, XORI, ORI,
ANDI, SLLI, SRLI, SRAI par décodage, avec contrôle funct6 des shifts et
préservation explicite du datapath pédagogique R/ADDI. ALU/imm_gen/EX et
registres de pipeline restent inchangés. Les anciens programmes sont préservés.

Tests ciblés : 899 072 contrôles PASS sous Verilator 5.040 et 4.038, dont
8000 encodages réservés rejetés ; huit rejets dans le datapath pédagogique ;
14 exécutions pipeline PASS (valeurs, hazards, forwarding, consommateurs,
rd0, branch, trap précis, MRET et contrôles externes). Le filtre ELF et la
matrice sont alignés : 31 formes présentes. Dix méthodes d'inventaire PASS,
48 objets et liens 117/9/18 inchangés ; toujours aucun C exécuté sur RTL.

La régression complète finale termine avec 30 suites PASS, 0 FAIL depuis un
snapshot des sources. Les cinq documents CF-05.2b sont rédigés. Les encodages réservés
restent neutralisés sans trap général illegal-instruction, limitation
préexistante documentée. Formes W, tailles mémoire, mapping/origine .data,
ABI et startup restent à traiter dans des lots approuvés.
Aucun commit, push ou merge du lot CF-05.2b n'est autorisé à ce stade.

### Bilan final local CF-05.2b

Code de sortie 0, 30 suites PASS, 0 FAIL sous Verilator 5.040. Le nouveau lot
compte 899 072 contrôles combinatoires (également PASS sous 4.038), 8000
encodages réservés rejetés, huit refus sans effet GPR dans le datapath
pédagogique et 14 exécutions pipeline. Les 16 tests ELF et dix tests
d'inventaire passent. Les programmes historiques sont inchangés, comme ALU,
imm_gen et EX ; seuls decoder.sv et rv64_datapath.sv changent dans le RTL.

La revue a renforcé le cas ANDI→BEQ : x2 commence à -1 puis reçoit zéro,
pour distinguer un vrai bypass d'une valeur initiale nulle. Les tests ciblés
renforcés passent ; une dernière régression complète couvre exactement cette
version. La première passe (30 PASS) est archivée sous
`/tmp/cf05-immediate-first-validation`.

Snapshot final :
`e02703c3587e7d260a1a7037c866a5888d4f9e96510a282b757e543f575b06f7`.
Les 162 fichiers du manifest correspondent aux sources courantes.
Preuves : `/tmp/cf05-immediate-final-validation.log`,
`/tmp/cf04-full-validation/manifest.json`, `summary.tsv` et
`cf05-immediate-source-review.json`. Seuls des documents sont mis à jour
après validation, sans changement des sources exécutables.
Commit, push et fusion du lot CF-05.2b restent en attente d'accords distincts.
