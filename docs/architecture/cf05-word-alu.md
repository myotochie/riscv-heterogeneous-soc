# CF-05.2c — Opérations RV64 sur mots de 32 bits

Ce lot ajoute les neuf formes de RV64I : ADDIW, SLLIW, SRLIW, SRAIW,
ADDW, SUBW, SLLW, SRLW et SRAW. L'opération utilise les 32 bits de poids
faible et son résultat de 32 bits est étendu avec son signe jusqu'à 64 bits.
Les décalages utilisent les cinq bits de poids faible de la seconde opérande.
Pour les formes immédiates, les bits réservés sont contrôlés au décodage.

Le décodeur produit des opérations ALU dédiées ; les contrôles de source et
les chemins de forwarding et de writeback ordinaires sont réutilisés. Les
encodages réservés restent sans effet sur les registres, sans trap général
illegal-instruction (limitation préexistante). Le datapath pédagogique reste
limité à son contrat historique. Le filtre ELF accepte les nouvelles formes
valides et l'inventaire indiquait alors 40 formes sur 52 présentes : cela ne constitue
pas une revendication de conformité RV64I complète.

La mémoire reste limitée à LD/SD. Ce lot n'ajoute ni startup, ni initialisation
.data/.bss, ni exécution de C sur le RTL.
