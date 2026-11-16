# CF-05.2a — Vérification LUI/AUIPC

> État courant après CF-05.2b : huit opérations immédiates supplémentaires,
> soit 31 formes présentes. Les résultats ci-dessous restent ceux du jalon
> historique ; voir [le lot immédiat](cf05-immediate-alu.md).

## Contrat de preuve

Les tests sont des simulations dirigées et une exploration combinatoire de
l'immédiat U. Ils ne sont ni une preuve séquentielle exhaustive, ni une
certification RV64I, ni une validation FPGA/synthèse. Les quinze scénarios
pipeline s'exécutent sur le vrai rv64_pipeline avec images externes.
Les programmes intégrés historiques ne sont pas remplacés.

## Tests unitaires

Fichiers : verification/unit/upper_immediates/upper_probe.sv et tb_upper.cpp.
Le wrapper connecte le décodeur, l'immédiat, EX avec forwarding et l'unité de
hazards existants. Deux boucles couvrent :

- Tous les 2^20 payloads, pour les deux opcodes, en faisant varier rd et le
  registre destination d'un load simulé. Vérification des sources absentes,
  de la légalité, de l'immédiat, du résultat et de l'absence d'effet mémoire.
- Cinq immédiats limites, quatre PC (0, 0x80000004, 0x1234567880000004 et
  0xfffffffffffffffc), 32 rd et neuf paires de sélections de forwarding.
  Les sources parasites doivent être ignorées ; forwarded_rs1_out doit
  conserver sa valeur. valid=0 ou illegal=1 supprime l'autorisation d'écriture.

Oracle : le signe est calculé par soustraction numérique de 2^32 quand
imm20 >= 0x80000 ; la somme utilise uint64_t modulo 2^64. Il ne recopie pas
la concaténation RTL. Résultat ciblé : **6 337 536 contrôles PASS**.
La valeur rd=0 est un contrôle EX, pas une écriture réelle du banc ; l'absence
d'écriture architecturale x0 est vérifiée dans le pipeline.

## Tests pipeline et résultats ciblés

Sources générées par make_programs.py, assemblées/ liées par GNU Binutils,
modèle observé par verification/integration/tb_upper_pipeline.cpp.

| Scénario | Stimulus / assertions | Résultat ciblé observé |
|---|---|---|
| data | LUI/ADDI/ADD, AUIPC/ADDI/JALR, rd0, deux U successives même rd, EX/MEM prioritaire sur MEM/WB | 21 écritures exactes, aucun trap |
| data : mémoire/hazards | SD/LD, une vraie dépendance LD/ADDI, LD x13 suivi de LUI dont les bits 19:15 valent 13 | exactement un stall réel ; alias U observé sans stall ; bypass EX/MEM et MEM/WB atteints |
| branch | BEQ pris, LUI/AUIPC sur chemin annulé | une seule écriture autorisée, aucune dans x30/x31 |
| trap | LUI plus ancienne, LD désaligné, LUI en EX au trap | écriture ancienne préservée ; un trap cause 4, EPC=0x80000004, tval=1 ; aucune écriture jeune |
| mret | AUIPC/ADDI fixe mepc=0x80000080 ; MRET avant deux U | trois écritures exactes ; un MRET avec U simultanée en EX, U en MEM également annulée |
| control normal | LUI ou AUIPC puis boucle terminale | une écriture, pas de trap |
| control stall | trois cycles d'arrêt avec LUI puis AUIPC en EX | PC tenu, WB/trap supprimés pendant arrêt, une seule écriture après reprise |
| control flush | flush externe avec U en EX | aucune écriture dans la fenêtre d'annulation |
| control reset | reset avec U en EX | aucune écriture dans la fenêtre avant réexécution possible |
| jump | AUIPC→JALR direct, ancien même rd=64 ; rd du lien non nul ; deux U sur chemin annulé | quatre écritures exactes, lien=0x8000000c, aucune écriture jeune |
| edges | LUI négative et AUIPC à 0x80000004 avec U négatif | ffffffff80000000, 4, 7ffff008 ; aucun trap |
| memory | LUI→SD immédiat ; LUI→bases LD/SD immédiates non nulles | onze écritures exactes ; bases U=4096, anciennes valeurs=64, offsets -8/-16 valides |

Il y a quinze exécutions : data compte pour une, control et control_pc
comptent chacun pour quatre, et les six autres scénarios comptent chacun pour une. Les séquences attendues sont explicites dans les fichiers .expected.
Les compteurs de collision vérifient que le stimulus concurrent a réellement
été atteint. Les observations hiérarchiques de hazards/forwarding ne constituent
pas une interface de retraite architecturale générale.

Les quatre modes control sont exécutés pour LUI et pour AUIPC (control_pc).
Le stall AUIPC vérifie ainsi le PC propre pendant que fetch est tenu.
Le test mémoire initialise les adresses parasites et vérifie les accès par
une base indépendante : une ancienne base 64 ne peut masquer la base U=4096.

Flush/reset sont observés pendant trois cycles suivant l'annulation. Après un
reset, le programme pourrait naturellement recommencer ; le test ne prétend
pas interdire cette réexécution. La boucle terminale est exécutée jusqu'à
160 cycles pour les autres scénarios. Toute écriture inattendue, même tardive,
fait échouer la comparaison de séquence. Les lectures dont la donnée est vérifiée sont précédées de SD ; le LD
désaligné vérifie uniquement le trap, jamais une donnée RAM non initialisée.

## Reproduction

```bash
VERILATOR=/opt/verilator-modern/bin/verilator \
BUILD_ROOT=/tmp/cf05-upper-check \
bash verification/scripts/run_upper_immediates.sh
BUILD_ROOT=/tmp/cf05-upper-inventory bash verification/scripts/run_cf05_inventory.sh
```

Les images, sources assembleur, objets, ELF, BIN, attentes et journaux sont
conservés sous BUILD_ROOT. Le lanceur complet découvre automatiquement
run_upper_immediates.sh, portant le nombre de suites actives de 28 à 29.
La suite ciblée finale de quinze exécutions réussit ; un premier lancement intermédiaire avait
échoué au dernier cp car le scénario edges avait été ajouté après la génération
des images. La relance complète avec toutes les fixtures générées a réussi ;
aucun échec RTL n'a été masqué ou modifié pour obtenir un PASS.

## Contrat logiciel et limites

Le garde ELF accepte désormais U pour chaque payload et continue de refuser
les formes non supportées. Les tests ELF valident les nouveaux cas positifs
ainsi que les rejets précédents pertinents. L'oracle GAS de 52 instructions et
la matrice dynamique contrôlent les 23 formes désormais présentes. Les mesures
CF-05.1 historiques restent à 21 formes. Les 48 objets/144 liens ne sont pas
une exécution C ; les résultats de liaison restent 117/9/18.

Non couvert : vérification formelle des annulations, aléatoire long, timing
après synthèse, FPGA et comparaison Spike. Le banc pipeline nouveau emploie
les observations hiérarchiques de Verilator 5 ; la régression complète exige
cette version majeure. Aucun chiffre de CPI, fréquence ou surface n'est déduit.

## Compatibilité du test combinatoire

Le wrapper unitaire et son oracle ont également été compilés avec
`/usr/bin/verilator` 4.038 et exécutés : 6 337 536 contrôles PASS. Journal :
`/tmp/cf05-upper-unit-v4.log`, modèle dans `/tmp/cf05-upper-unit-v4`.
Ce résultat concerne le test unitaire U, pas la totalité des tests pipeline
avec l'ancienne version. La régression complète reste exécutée avec 5.040.

## Régression complète finale et provenance

```bash
VERILATOR=/opt/verilator-modern/bin/verilator \
CLEAN_ROOT=/tmp/cf04-clean-validation LOG_ROOT=/tmp/cf04-full-validation \
bash scripts/run_clean_regression.sh
```

Résultat final : **code 0, 29 suites PASS, 0 FAIL**, Verilator 5.040.
La nouvelle suite compte quinze exécutions pipeline U réussies, plus
6 337 536 contrôles combinatoires. La régression inclut les tests historiques
de branches, sauts, hazards, mémoire, CSR, exceptions et MRET. Les 14 tests
ELF et les neuf tests d'inventaire passent ; celui-ci conserve 48 objets,
117 liens réussis non exécutés, 9 refus de relocation et 18 refus de helpers.

Empreinte des sources de la passe finale :
`7493daf1ec3cefe13c62bc034171087cf33449655cbc9c4de446a197ebeefbcf`.
Base Git : 6b38e8a, changements U non commitées. Les 157 entrées du manifest
correspondent aux fichiers courants après validation. Aucun programme de
fetch intégré n'est modifié, ni le programme assembleur CF-04 existant.

Preuves locales :

- `/tmp/cf05-upper-final-validation.log` : sortie globale finale ;
- `/tmp/cf04-full-validation/manifest.json` et `summary.tsv` : sources et suites ;
- `/tmp/cf04-full-validation/run_upper_immediates.log` : quinze cas U et compte unitaire ;
- `/tmp/cf04-full-validation/cf05-upper-source-review.json` : contrôle des sources ;
- `/tmp/cf04-full-validation/build/run_upper_immediates/programs` : fixtures finales ;
- `/tmp/cf05-upper-unit-v4.log` : résultat unitaire sous 4.038.

Le premier snapshot complet, avant renforcement des tests mémoire/AUIPC, est
archivé dans `/tmp/cf05-upper-first-validation` (29 PASS). La passe finale
inclut tous les tests renforcés. Les ajouts documentaires postérieurs n'affectent
pas le manifest des sources exécutées. Aucune CI distante de ce lot n'est
revendiquée avant commit et push autorisés.
