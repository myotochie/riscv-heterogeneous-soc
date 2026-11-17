# Vérification CF-05.2d — LW et SW

`verification/scripts/run_word_memory.sh` teste la mémoire isolée puis cinq
programmes sur le pipeline. Les cas dirigés couvrent la préservation des octets
voisins, les deux moitiés d'un double mot, l'extension de signe, la dernière
adresse valide, la priorité des fautes et l'absence d'écriture après faute ou
reset. Le programme normal couvre le forwarding, une dépendance load-use, x0,
et le mélange LW/SW/LD/SD. Quatre programmes vérifient séparément les causes,
PC et adresses des traps de chargement et stockage mal alignés ou hors limites,
ainsi que la suppression d'écritures plus jeunes.

Ces tests dirigés ne prouvent pas tous les entrelacements ou la conformité ISA
complète. Les tests du filtre ELF vérifient aussi l'acceptation de LW/SW et le
rejet des autres tailles encore absentes.

```sh
VERILATOR=/path/to/verilator-5.040/bin/verilator \
  bash verification/scripts/run_word_memory.sh
```
