# CF-05.2d — Accès mémoire LW et SW

LW charge quatre octets little-endian et étend le bit 31 jusqu'au bit 63.
SW écrit uniquement les quatre octets de poids faible du registre source.
Les accès doivent être alignés sur quatre octets et rester entièrement dans
la RAM ; LD et SD conservent leur alignement et leur taille de huit octets.
Le champ funct3 de l'instruction mémorisée en EX/MEM sélectionne la taille.
Les fautes conservent leur classification et leur priorité préexistantes :
si une adresse est à la fois mal alignée et hors limites, la faute d'alignement
est signalée en premier. Les accès fautifs ne modifient pas la mémoire.

Le filtre ELF et l'inventaire sont alignés avec ces ajouts. LB, LH, LBU,
LHU, LWU, SB et SH restent non implémentés. La RAM garde ses limites et
l'exécution de C nécessite encore un mapping et un startup définis.
