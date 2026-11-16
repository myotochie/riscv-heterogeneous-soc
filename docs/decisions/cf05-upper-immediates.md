# CF-05.2a — Décisions LUI/AUIPC

> État courant après CF-05.2b : huit opérations immédiates supplémentaires,
> soit 31 formes présentes. Les résultats ci-dessous restent ceux du jalon
> historique ; voir [le lot immédiat](cf05-immediate-alu.md).

## D-U01 — Réutiliser ADD dans EX

Problème : les U requièrent zéro ou PC en opérande A et un immédiat signé en B.
Choix : multiplexeur combinatoire local dans execute_stage. L'alternative
ajoute deux opérations au package ALU et à ses tests ; une résolution en ID
introduit un autre chemin de calcul. Réutiliser EX conserve les interfaces et
les règles de disponibilité. Aucun cycle supplémentaire n'est introduit dans
l'ordonnancement prévu ; aucune performance physique n'a été mesurée.

## D-U02 — Choisir le PC ID/EX, préserver le forwarding rs1

AUIPC consomme son propre PC, déjà enregistré. Le PC courant de fetch serait
incorrect pendant l'avance du pipeline et ses stalls/redirections. Seule
l'entrée A de l'ALU change : forwarded_rs1_out reste une source réelle pour
les branches, JALR et les CSR. Modifier globalement le résultat de forwarding
risquerait de mélanger ces responsabilités.

## D-U03 — Ne pas inventer des dépendances de format R/I

Les champs ressemblant à rs1/rs2 appartiennent à l'immédiat U. Le décodeur
annonce zéro source. Les muxes EX peuvent recevoir une sélection parasite,
mais l'ALU doit l'ignorer. Ajouter des ports uses_rs à l'unité de forwarding
serait possible, mais n'est pas nécessaire à la correction et élargirait ce lot.
Le test du faux load-use et l'exploration de tous les payloads protègent ce choix.

## D-U04 — Garder le chemin WB et les annulations existants

Le résultat est prêt à la fin d'EX et voyage comme un résultat ALU ordinaire.
Un chemin WB dédié introduirait une sélection et un bypass supplémentaires.
Les règles x0, traps et MRET restent communes ; leurs collisions avec les U
sont testées, y compris la conservation d'une écriture plus ancienne au trap.
Le lot est neutre pour l'organisation multicœur future ; il ne fournit aucune
synchronisation ou cohérence.

## D-U05 — Images externes et corpus historique préservé

Les tests U sont assemblés et liés dans le build. Ajouter d'autres PROGRAM_ID
figerait des instructions supplémentaires dans la ROM pédagogique. Les images
externes vérifient aussi le backend CF-04 et évitent de modifier les programmes
0 à 47. Binutils et Verilator sont déjà des dépendances déclarées, aucune
nouvelle bibliothèque, installation ou licence externe n'est ajoutée.

## D-U06 — Support U avant startup, sans élargir le contrat de mémoire

Le filtre ELF et la matrice changent après les preuves RTL ciblées. Les tests
de rejet U sont remplacés car leur contrat a effectivement évolué ; les autres
rejets restent. La matrice CF-05.1 publiée est conservée comme historique.
Le choix du mapping et de la source des initialiseurs .data reste en attente.
Un LD dans la ROM n'est pas implémenté ; aucun démarrage C autonome ne peut
être déduit du seul ajout U. Les alternatives RAM préchargée/staging ou ROM
lisible par LD devront être comparées dans le lot startup approuvé.
