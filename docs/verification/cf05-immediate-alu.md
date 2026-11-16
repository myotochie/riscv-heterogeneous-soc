# CF-05.2b — Vérification des opérations immédiates

## Contrat et reproduction

```bash
VERILATOR=/opt/verilator-modern/bin/verilator \
BUILD_ROOT=/tmp/cf05-immediate-check \
bash verification/scripts/run_immediate_alu.sh
BUILD_ROOT=/tmp/cf05-immediate-inventory bash verification/scripts/run_cf05_inventory.sh
```

Ce lot est vérifié par simulation RTL dirigée et exploration combinatoire,
pas par preuve formelle exhaustive du pipeline. Les ELF/BIN/HEX, assembleurs,
attentes et logs sont conservés dans BUILD_ROOT. Les fixtures sont des tests
internes ; les paddings .org des handlers ne passent pas par le filtre ELF.
Le filtre est testé séparément sur de vrais ELF du programme CF-04.

## Unitaire : décodeur, immédiat, EX et hazards

Fichier : verification/unit/immediate_alu/tb_immediate.cpp ; wrapper réutilisé :
verification/unit/upper_immediates/upper_probe.sv. Le wrapper relie les vrais
modules de production, sans constituer une nouvelle implémentation CPU.

- Tous les 4096 imm12 × 8 funct3 OP-IMM sont vérifiés.
- 24768 combinaisons légales et 8000 préfixes réservés sont distingués.
- Les commandes GPR/mémoire, sources réelles, rd et extension du signe sont
  contrôlés ; une fausse dépendance rs2 doit être absente et une vraie rs1
  doit produire le hazard attendu (sauf x0).
- Neuf valeurs limites sont essayées avec trois sélections de forwarding A,
  tandis que la sélection B parasite varie : le résultat doit utiliser
  l'immédiat, jamais la valeur rs2/bypass B.
- Le stimulus inclut zéro, un, 63, 64, INT64_MAX, INT64_MIN, -1, -2^31 et
  0x123456789abcdef0 ; les bypasses produisent aussi leurs compléments/xor.
- Une matrice des 32 rd × 32 rs1 et des shifts limites contrôle les indices
  et shamt[5]. valid=0 ou illegal forcé supprime l'écriture à EX.

L'oracle exprime l'immédiat négatif par soustraction de 4096 en uint64_t,
l'ordre signé en inversant le bit de signe avant comparaison non signée, et
SRAI par shift logique avec remplissage explicite du haut. Il évite de dépendre
d'un shift C++ signé négatif. Les quantités 0 sont traitées sans shift de 64.
Les encodages illégaux ne sont pas évalués comme opérations architecturales.

Résultat ciblé : **899 072 contrôles PASS** sous Verilator 5.040, ainsi que
sous 4.038 dans `/tmp/cf05-immediate-unit-v4.log`. Cela ne signifie pas que
la régression pipeline complète a été exécutée sous 4.038.

## Contrat du datapath pédagogique

Fichier : tb_teaching_contract.cpp. x5 reçoit d'abord 17 par ADDI. Les huit
nouvelles familles, toutes dirigées vers x5, doivent être rejetées dans ce
module historique ; après chaque front, une lecture par ADDI retrouve 17.
Résultat ciblé : huit rejets sans écriture GPR parasite. Les anciennes suites
R/ADDI restent incluses dans la régression, pour ne pas confondre protection
du contrat et désactivation du module. Le pipeline complet accepte ces formes.

## Intégration pipeline : 14 exécutions

Fichiers : make_programs.py, tb_immediate_pipeline.cpp et run_immediate_alu.sh.
Chaque simulation démarre un processus neuf et vérifie la séquence entière des
écritures WB, pas seulement des valeurs finales qui pourraient masquer une
erreur ensuite écrasée. WB est observé avant le front montant.

| Fixture / modes | Stimulus et assertions | Résultat ciblé observé |
|---|---|---|
| data | Huit familles, signe, seuil SLTIU négatif, shamt 0/32/63, rd0, producteurs même rd, bypass EX/MEM et MEM/WB | 31 écritures exactes, aucun trap |
| data : hazards | LD x24→ANDI x25 réel ; LD x13→XORI x8,x9,13 avec faux rs2 | exactement un stall ; faux alias atteint sans stall |
| reserved | Quatre préfixes de shifts réservés vers x5 déjà initialisé | quatre slots illégaux atteints, seulement deux écritures légales, x5 conservé, aucun trap général prétendu |
| branch | BEQ pris, SLLI/XORI sur chemin annulé | une écriture autorisée ; aucune dans x30/x31 |
| trap | XORI ancienne en WB, LD désaligné en MEM, SLLI jeune en EX | une écriture ancienne préservée ; trap unique cause=4, EPC=0x80000004, tval=1 ; jeunes annulées |
| mret | MEPC fixé à 0x80000080 ; MRET devant SLLI/SLTIU | trois écritures exactes ; un MRET avec OP-IMM jeune en EX réellement observé |
| control : normal/stall/flush/reset | XORI x5,x0,-1, injection quand elle atteint EX | une écriture en normal/reprise ; zéro dans la fenêtre d'annulation |
| control_shift : mêmes quatre modes | ADDI x5=-1 puis SRAI x6,x5,63 | deux écritures en normal/reprise ; zéro dans la fenêtre d'annulation |
| consumers | ANDI→BEQ ; ORI/XORI→adresse/donnée SD ; SLLI rd=rs1→LD ; LD→SLTI | neuf écritures exactes, signature mémoire -1 à l'adresse 64 ; un vrai stall |

Il y a huit fixtures : six exécutées une fois et deux exécutées dans quatre
modes, soit quatorze exécutions. data a deux lignes explicatives dans le tableau,
mais ne compte qu'une exécution. Les bypasses, faux hazards et collisions sont
comptés pour vérifier que les conditions annoncées ont réellement été atteintes.
La priorité EX/MEM est éprouvée par deux XORI successives vers x22 : ANDI doit
consommer 2, pas l'ancienne valeur 1. Avant ANDI→BEQ, x2 est explicitement initialisé à -1 pour que la branche
distingue la valeur récente zéro de son ancienne valeur ; un état initial
implicitement nul ne peut masquer un défaut de forwarding.
Le scénario consumers utilise une base
non nulle : sans forwarding, une ancienne base 1 pour LD serait désalignée.

Stall dure trois cycles ; WB/trap sont supprimés et PC doit rester tenu.
Flush/reset sont observés dans une fenêtre de trois cycles suivant annulation,
avant la réexécution possible après reset. La plupart des scénarios continuent
jusqu'à 160 cycles, toute écriture supplémentaire fait échouer la séquence.
La mémoire utilisée pour vérifier une donnée est écrite avant lecture ; le LD
désaligné teste uniquement la faute, pas une valeur RAM non initialisée.

## Cohérence ELF et inventaire

Les tests ELF ajoutent dix encodages légaux (huit familles et limites de shift)
et quatre rejets réservés. Les autres refus de sous-ensemble sont conservés.
Un ancien test de décodeur sur SLLI 42 change légitimement de contrat : positif,
complété par un préfixe réservé négatif. Les attentes ne sont pas réduites
pour masquer une défaillance.

L'inventaire garde l'oracle GAS de 52 formes et contrôle les 32768 payloads
OP-IMM dans le garde Python. Les dix méthodes d'inventaire passent. Les
48 configurations objets et 144 tentatives de liaison restent des mesures
statiques, avec 117 liens non exécutés, 9 refus de relocation et 18 refus de
helpers. Aucun programme C n'est exécuté sur RTL.

## Limites connues

Les encodages illégaux sont neutralisés, sans exception illegal-instruction
générale : limitation architecturale existante et explicitement hors de ce lot.
Pas d'aléatoire long, Spike, preuve formelle, FPGA ni synthèse. Les observations
hiérarchiques ne constituent pas une trace générale de retraite architecturale.
La matrice actuelle à 31 formes n'est pas une conformité RV64I complète.
La régression complète comprend le nouveau lanceur et totalise 30 suites PASS.

## Bilan complet final et provenance

```bash
VERILATOR=/opt/verilator-modern/bin/verilator \
CLEAN_ROOT=/tmp/cf04-clean-validation LOG_ROOT=/tmp/cf04-full-validation \
bash scripts/run_clean_regression.sh
```

Résultat : **code 0, 30 suites PASS, 0 FAIL**, Verilator 5.040. La passe finale
inclut le test ANDI→BEQ renforcé avec ancienne valeur distincte. Son scénario
consumers produit neuf écritures, et la suite compte bien 14 exécutions.
La première passe complète avec la version initiale de ce stimulus a également
réussi (30 PASS) et reste archivée dans `/tmp/cf05-immediate-first-validation`.
Aucune défaillance n'a été supprimée ou remplacée par un résultat attendu.

Base Git : dfa4ce4, lot immédiat non commité. Empreinte des sources finales :
`e02703c3587e7d260a1a7037c866a5888d4f9e96510a282b757e543f575b06f7`.
Les 162 entrées du manifest ont été comparées aux fichiers courants : identiques.
La ROM de fetch et le smoke assembleur CF-04 sont inchangés. ALU, imm_gen et
execute_stage restent identiques à HEAD ; les deux seuls RTL modifiés sont
le décodeur et le filtre du datapath pédagogique.

Preuves locales conservées :

- `/tmp/cf05-immediate-final-validation.log` : bilan global ;
- `/tmp/cf04-full-validation/manifest.json` et `summary.tsv` : sources et suites ;
- `/tmp/cf04-full-validation/run_immediate_alu.log` : compte unitaire et 14 cas ;
- `/tmp/cf04-full-validation/cf05-immediate-source-review.json` : contrôle des sources ;
- `/tmp/cf04-full-validation/build/run_immediate_alu/programs` : fixtures finales ;
- `/tmp/cf05-immediate-unit-v4.log` : unitaire 4.038 ;
- `/tmp/cf05-immediate-inventory.log` : dix méthodes d'inventaire ciblées.

Les 16 méthodes de tests ELF passent ; les dix méthodes d'inventaire passent,
avec 31 formes présentes et liens 117/9/18 inchangés. L'exemple d'apprentissage
à six instructions a aussi été assemblé indépendamment : ses six mots machine
correspondent à GNU as (artefacts `/tmp/cf05-immediate-example.1u0_1h66`).
Cela vérifie ses encodages ; les résultats fonctionnels de ces cas sont
contrôlés dans les bancs unitaires et la fixture data, avec d'autres registres.

Les ajouts documentaires postérieurs ne changent pas les sources exécutées.
Aucune CI distante de ce lot n'est revendiquée avant publication autorisée.
