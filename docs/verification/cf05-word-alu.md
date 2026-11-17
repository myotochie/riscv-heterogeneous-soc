# Vérification CF-05.2c — opérations W

`verification/scripts/run_word_alu.sh` compose le décodeur, le générateur
immédiat, le détecteur de dépendances et l'étage EX. Le banc vérifie les
combinaisons de funct3/funct7, les 32 valeurs du champ rs2 ou shamt, des
opérandes aux limites, l'extension de signe, les hazards et les chemins de
forwarding ; les encodages non valides doivent neutraliser les écritures.

Le programme assembleur dirigé exécute les neuf opérations sur le pipeline,
avec chaînes de dépendances, résultat transmis à une branche, load-use, écriture
x0 et encodages réservés. Le banc compare la séquence de writeback et observe
les bypasses, l'arrêt load-use et l'absence de trap. Ces tests ne sont pas une
preuve séquentielle exhaustive, ni une vérification de conformité complète.

Le filtre ELF est testé sur les neuf formes et sur des encodages réservés ;
l'inventaire compare ses décisions sur les combinaisons funct3/funct7.
La suite ciblée exige GNU Binutils RISC-V et Verilator 5 pour le banc pipeline :

```sh
VERILATOR=/path/to/verilator-5.040/bin/verilator \
  bash verification/scripts/run_word_alu.sh
```

La régression complète `scripts/run_clean_regression.sh` inclut automatiquement
cette suite et conserve les versions, empreintes et journaux dans son répertoire
de résultats.
