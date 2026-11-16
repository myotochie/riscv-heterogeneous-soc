# CF-05.1 — Journal des décisions

> État courant après CF-05.2b : huit opérations immédiates supplémentaires,
> soit 31 formes présentes. Les résultats ci-dessous restent ceux du jalon
> historique ; voir [le lot immédiat](cf05-immediate-alu.md).

> Résultats historiques CF-05.1 : 21 formes présentes avant ajout RTL.
> CF-05.2a ajoute LUI/AUIPC ; la matrice dynamique et le garde ELF
> au jalon CF-05.2a comptent 23 formes. Voir [le lot U](cf05-upper-immediates.md).

## D05-01 — Mesurer avant d'étendre le cœur

Le seul drapeau rv64i autorise plus d'instructions que les 21 formes présentes.
Décision : inventorier objets et ELF avant de choisir un lot RTL. Le corpus
est volontairement ciblé sur les types/opérateurs C ; ses fréquences statiques
ne prédisent pas les performances d'une application. Les 52 lignes servent à
éviter les omissions, sans imposer arbitrairement toutes les extensions.

## D05-02 — GCC privé et Binutils explicitement associés

Le paquet 10.2.0-0ubuntu1 disponible est extrait sans privilège, comme Binutils.
Une compilation depuis les sources aurait ajouté temps de construction et
dépendances inutiles au premier inventaire ; LLVM aurait constitué une autre
toolchain à qualifier. Le résolveur accepte néanmoins un GCC explicite.
-B reçoit le préfixe complet des outils et les programmes sélectionnés sont
vérifiés, après un essai initial qui avait sélectionné l'as natif.

## D05-03 — Deux modèles de code et trois placements de données

Le code commence à 0x80000000, les données restent dans la RAM basse. Choisir
un modèle sans tester les relocations masquerait une contrainte de placement.
Le test late_globals explore la fin de ROM ; les symboles liés confirment le
layout réel. Le paramètre --defsym est passé avant le linker script pour
éviter que sa valeur par défaut soit évaluée avant la définition.

## D05-04 — Désassembler les ELF, même sans relaxation demandée

Les six cas AUIPC→LUI observés dans late_globals/medany sont une propriété de
ces outils/layouts, pas une garantie universelle de GNU ld. Ils montrent que
l'inventaire d'objets seul serait insuffisant. Les commandes, relocations et
deux désassemblages sont conservés pour reproduire l'observation.

## D05-05 — Garder visibles les liens refusés

Les neuf refus de relocation et dix-huit refus de helpers ne sont pas des
programmes réussis. L'inspection est réussie quand elle a mesuré et classé ces
résultats attendus, sans erreurs non classées. Les ELF liés ne sont pas exécutés.
Le filtre d'images normal n'est ni désactivé ni assoupli pour faire passer le C.

## D05-06 — Ne pas ajouter M sur la seule présence d'une multiplication C

GCC génère des helpers et fournit une sélection multilib rv64i/lp64 de libgcc.
La compatibilité et le coût d'une émulation logicielle resteraient à qualifier
avant utilisation. Une unité M ajouterait du matériel et éventuellement des
latences/contrôles ; aucune mesure ne justifie ce choix dans CF-05.1.

## D05-07 — Reporter le startup et les ajouts RTL à des lots approuvés

Le Harvard actuel n'offre pas de lecture LD de la ROM. Préchargement RAM,
copie depuis une zone RAM et accès données à la ROM sont des alternatives
réelles à comparer. Aucun de ces choix n'est introduit silencieusement ici.
Ordre candidat : U-types/immédiats, formes W, tailles mémoire, puis startup/ABI
et programmes C exécutés. Les critères incluront forwarding, x0, annulation,
extension des résultats, bornes mémoire et effets précis des exceptions.

## D05-08 — Comparer l'identité des outils, pas leurs noms de chemin

Après l'échec CI de d0b0a97 avant les tests, le contrôle de découverte conserve
la cible exacte et exige que les outils trouvés soient exécutables. `command -v`
résout un nom rapporté par GCC ; Bash `-ef` compare ensuite les fichiers réels.
L'alternative `readlink -f` puis comparaison de chaînes accepterait les symlinks
mais distinguerait encore deux liens physiques vers le même fichier. Comparer
seulement les versions accepterait deux outils différents ; supprimer le
contrôle masquerait une mauvaise configuration. Le test d'identité exprime
le contrat voulu sans dépendance nouvelle. Le coût est exclusivement logiciel,
au lancement des scripts ; pipeline, CPI et synthèse ne sont pas affectés.
Les valeurs du runner initial sont inconnues : les nouveaux diagnostics
permettront de distinguer un alias de chemin d'une incompatibilité réelle.
