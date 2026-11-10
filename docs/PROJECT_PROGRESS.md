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
| CF-01 : décodage six branches | Commit local | bc4a80b |
| CF-02 : branches en EX | Commit local, suites existantes | 81eb817 |
| CF-03 : JAL/JALR et défauts de cible | Réalisation corrigée et validée localement ; publication en cours | Commit identifié par son message et le journal Git ; manifest de validation |
| CF-04 : chargement instructions externe | Proposition seulement | Aucun |
| CF-05 : ISA nécessaire au C et ABI | Futur | Aucun |
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
- ROM de programmes intégrés, NOP hors adresses définies, pas de faute fetch.
- RAM 4 Kio à lecture combinatoire ; pas de bus à latence variable ni MMIO général.
- Pas de reset général GPR/RAM : initialisation nécessaire aux tests/logiciels.
- Deux anciens bancs load-invalid conservés comme historiques et catalogués,
  car leurs attentes de poursuite après faute contredisent les traps précis.
- Pas de trace architecturale complète, Spike, mesures CPI de référence ou FPGA.
- Le workflow corrigé doit encore être exécuté sur GitHub après publication
  autorisée ; les anciens jobs verts de main ne valident pas CF-03.

## Git et décisions en attente

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

1. Réaliser le commit local autorisé et vérifier son contenu.
2. Rétablir l'accès GitHub, pousser la branche puis attendre la CI du commit publié.
3. Fusionner par avance rapide si main est ancêtre et si les contrôles réussissent.
4. Audit CF-04 : mémoire d'instructions, toolchain disponible, linker/mapping.
5. Plan détaillé puis accord avant toute implémentation CF-04.

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
