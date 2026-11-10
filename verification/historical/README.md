# Bancs antérieurs aux traps précis

Ce répertoire catalogue deux sources conservées à leur emplacement d'origine,
avec leurs attentes historiques. Elles ne font pas partie des tests actifs et
ne doivent jamais être comptées comme PASS.

| Source | Attente historique | Comportement architectural actuel |
|---|---|---|
| `../integration/tb_rv64_invalid_load.cpp` | L'ADDI après le load fautif écrit x6=7 | Le trap annule cette instruction plus jeune |
| `../integration/tb_rv64_invalid_load_dependency.cpp` | ADD après le load fautif lit l'ancien x5, puis ADDI écrit x7 | Les deux instructions sont annulées |

Les sources réelles sont `verification/integration/…` (les chemins ci-dessus
sont relatifs à ce catalogue). Leurs programmes intégrés 8/9 restent inchangés.

La propriété encore pertinente est la conservation de la valeur précédente de
x5 : un load fautif ne doit pas l'écraser. Elle est testée activement dans
`verification/unit/rv64_pipeline/tb_precise_trap.cpp` et les suites de traps
mémoire/CSR. Ces suites vérifient aussi le PC fautif et l'annulation des jeunes.
Une future variante avec gestionnaire MRET devra tester le consommateur après
une reprise explicite, avec un nouvel ID, sans rétablir l'ancienne sémantique.

`tb_csr_file.cpp` n'est plus exclu : ses ports séparés de lecture/écriture sont
modernisés et ses 15 vérifications antérieures sont conservées, complétées par
3 vérifications d'accès simultanés indépendants.

Pour examiner les anciens bancs : lire leurs assertions et les comparer aux
programmes 8/9. Les exécuter contre le CPU actuel doit être considéré comme une
expérience de divergence attendue, pas comme une validation de l'architecture.
