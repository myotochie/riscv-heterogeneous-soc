# CF-05.1 — Vérification de l'inspection GCC

## Reproduction et sens du résultat

```bash
BUILD_ROOT=/tmp/cf05-check bash verification/scripts/run_cf05_inventory.sh
# Inspection seule, sans unittest :
BUILD_ROOT=/tmp/cf05-inventory bash scripts/inspect_c_toolchain.sh
```

RISCV_GCC et RISCV_PREFIX permettent de choisir des installations existantes,
avec chemins absolus pour le snapshot. Les scripts n'installent rien et ne
sautent pas les contrôles en cas de dépendance absente. Aucune sonde C n'est
exécutée sur le CPU : audit_completed signifie que la génération et ses
résultats ont été inspectés, pas que le C est fonctionnel sur notre cœur.

## Matrice des vérifications

| Test / fichier | Stimulus et attente | Résultat ciblé |
|---|---|---|
| isa_base.S + test_gas_oracle | 52 encodages assemblés par GNU as ; noms exacts, largeur 32 bits, garde courant = 21 formes | PASS |
| test_matrix_complete | 52 lignes uniques, 21 présentes, références de tests existantes | PASS |
| test_disassembly | Instructions et ligne de relocation entre elles | Deux instructions comptées, relocation exclue |
| test_rejects_compressed | Sortie vide, mot 16 bits, encodage JALR réservé | Rejet ou UNKNOWN selon contrat |
| test_symbol_parsing | Symboles définis et UND, entrée nulle sans nom | Valeur et helper extraits exactement |
| test_report_dimensions | Huit sources × trois optimisations × deux modèles × trois RAM | 48 objets, 144 liens, aucun mot UNKNOWN |
| test_runtime_and_relocation | Diagnostics connus de l'expérience | Refus restent visibles ; aucune exécution C prétendue |
| test_compiler_resolver | GCC natif x86 et chemin absent | Erreur explicite, pas de fallback silencieux |

Fichier des huit méthodes : verification/unit/cf05_inventory/tb_inventory.py.
Elles comportent notamment 52 sous-cas d'encodage ; ce n'est pas une campagne
RTL de 52 instructions. Le garde CF-04 n'est pas modifié ou contourné.

## Résultats ciblés observés

GCC 10.2.0 et Binutils 2.35.1 compilent les 48 configurations avec Werror.
Les macros relevées confirment XLEN=64, int=4 octets et long=8 octets.
Les huit méthodes Python passent avec code 0.

Sur les 144 liens :

- 117 sont liés, avec statut explicite linked_not_executed ;
- 9 refusent R_RISCV_HI20 dans function_pointer/medlow ;
- 18 refusent __muldi3, __udivdi3 et __umoddi3 non définis, puisque libgcc
  n'est pas lié dans runtime_helpers.

Ces 27 refus ne sont pas dissimulés comme des succès de programmes. Ils sont
des observations attendues et identifiées du corpus. Toute autre erreur de
lien ou de compilation fait échouer le runner. Les commandes et stderr sont
conservés dans chaque répertoire. Une source modifiée pendant l'inspection
provoque une erreur si son empreinte finale ne correspond plus à l'initiale.

Vingt-huit formes absentes du RTL sont observées dans les objets. Les trois
formes absentes non observées sont FENCE, ECALL et EBREAK. Dix-huit des formes
présentes sont observées ; l'absence de SLT/SRA/BGEU dans ce corpus n'annule
pas leurs tests unitaires ou de branches existants. Voir la matrice exhaustive
[cf05-isa-matrix.md](cf05-isa-matrix.md).

Six cas late_globals/medany (trois optimisations, RAM 0 ou 0x100) montrent un
changement du multiensemble d'opcodes : AUIPC dans l'objet, LUI dans l'ELF.
Le layout RAM 0x800 ne montre pas ce changement. Il s'agit d'une observation
avec cette version de GNU ld ; pas d'une promesse pour toute toolchain.
Le comparateur de compteurs ne prouve pas l'équivalence des opérandes ou le
comportement du programme : les dumps complets sont conservés pour l'examen.

## Incidents de mise au point conservés

Le premier essai privé de GCC avec -B suivi du seul répertoire bin sélectionnait
l'as x86, qui refusait rv64i. L'usage du préfixe complet et la vérification des
programmes as/ld résolvent ce problème ; les tests négatifs du résolveur le
couvrent. Le premier essai de layout plaçait --defsym après -T, ce qui laissait
MEMORY utiliser sa valeur par défaut. L'ordre est corrigé et les symboles de
chaque ELF lié confirment désormais la base RAM réellement utilisée.
Aucun de ces incidents n'a été compté comme exécution RTL réussie.

## Preuves et régression complète

Preuves ciblées : /tmp/cf05-check.log et /tmp/cf05-check/inspection/.
Les rapports inventory.json, summary.tsv et isa_matrix.tsv décrivent les
résultats ; les sous-répertoires gardent .i/.s/.o, commandes, symboles,
relocations, maps, dumps d'ELF et diagnostics. Les choix multilib et libgcc
sont relevés mais les archives ne sont pas liées ni exécutées.

La régression finale du 2026-11-15 termine avec code 0 : **28 suites PASS,
0 FAIL**, sous Verilator 5.040, g++ 11.4.0, Python 3.10.12, GNU GCC RISC-V
10.2.0 et Binutils 2.35.1. Elle réexécute les 27 suites antérieures et le
runner d'inspection. Les preuves CF-04.3/4 sont archivées dans
/tmp/cf04-assembled-validation ; les objets inchangés sont réutilisés par make,
mais tous les exécutables et contrôles sont relancés.

Un premier passage 28 PASS est conservé dans /tmp/cf05-first-validation.
La revue a ensuite ajouté aux artefacts CI les trois rapports agrégés ; YAML
et chemins sont contrôlés, puis la configuration finale repasse les 28 suites.
Aucune exécution CI distante de ce jalon n'est revendiquée avant publication.

Le log courant est /tmp/cf05-full-validation.log. Résumé, manifest et revue
finale sont dans /tmp/cf04-full-validation/{summary.tsv,manifest.json,final-source-review.json}.
Le nom historique de ce répertoire est conservé pour réutiliser les builds.
Il contient le bilan courant de 28 suites, pas les anciennes preuves 27 suites.
Snapshot source SHA256 :
ecf9400324a9efdc7a393e612accb12a18ecb092ce61d46d3fad3973a18be586.
Les 151 sources exécutables courantes correspondent au snapshot, avec les huit
.c, probe.ld et la fixture ISA ; les binaires .tools/ sont exclus.
Empreinte de ces sources exécutables :
ba137aa098d506302ca4622102100ca6aef553c853028fa35981c2632aa86cc7.
Aucun RTL ou garde d'images CF-04 n'a changé depuis 6beccd1. Les mises à jour
documentaires postérieures ne changent pas le code exécuté. Les artefacts
sont temporaires ; les commandes ci-dessus permettent leur reproduction.

## Limites

Corpus synthétique ciblé, huit sources et un compilateur : pas un inventaire
de tous les programmes C possibles. Pas de validation dynamique d'ABI, de
startup, de data/BSS, de C sur RTL ou de performances. Pas de preuve exhaustive
ISA/ELF. Les mots sont décodés pour l'inventaire, pas interprétés comme une
machine de référence CF-06. Aucun runtime n'est validé par sa seule présence
dans la distribution GCC. Les 21 formes RTL existantes restent un sous-ensemble.
