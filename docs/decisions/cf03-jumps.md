# CF-03 — Journal des décisions

Statut : décisions de réalisation autorisées, commit et publication en attente.
Les décisions portent sur le cœur actuel ; elles ne figent pas le futur SoC.

## D01 — Résoudre les sauts en EX

**Problème.** JALR peut dépendre immédiatement d'un résultat ALU/CSR ou d'un load.
CF-02 possède déjà en EX les opérandes forwardés et la redirection de branche.

| Option | Avantages | Coûts / limites |
|---|---|---|
| EX (retenue) | Réutilise forwarding, immédiats et flush CF-02 | Deux slots jeunes à annuler dans le chemin actuel |
| ID | Pourrait réduire le travail annulé | Nouveau forwarding vers ID, nouveaux interlocks et arbitrage |
| MEM/WB | Contrôle tardif plus centralisé | Plus d'instructions jeunes à bloquer/annuler |

Aucune amélioration de CPI n'est annoncée. L'option EX limite la complexité de
cette étape. Une prédiction de branche relèvera d'une décision ultérieure.

## D02 — Faire transiter le lien dans le résultat ALU

**Retenu :** sélectionner PC+4 en EX, conserver la chaîne EX/MEM/MEM/WB et WB.
Cela rend la donnée disponible aux chemins existants, y compris le bypass WB
vers ID. La cible garde un signal séparé.

**Alternative :** transporter PC+4 et un sélecteur de writeback dédiés. Le rôle
des données serait plus explicite, mais il faudrait étendre les registres et
les sélecteurs WB/forwarding. Les deux choix sont du RTL synthétisable en
principe ; aucune comparaison de surface ou fréquence n'a été mesurée.

**Dette acceptée :** le nom alu_result désigne aussi le lien d'un saut. Cette
sémantique est documentée plutôt que de renommer toute la chaîne dans CF-03.

## D03 — Traiter la faute de cible en MEM

**Problème.** Un transfert fautif en EX est plus jeune qu'une instruction MEM
et qu'une instruction WB. Une redirection immédiate de trap depuis EX doit
respecter ces âges et permettre le retirement ancien.

**Retenu :** 1 flag + 64 bits de cible dans EX/MEM, suppression du lien dès EX,
traitement par le contrôleur MEM existant. Le contexte est conservé par stall
et annulé par flush/reset. Le mécanisme couvre également les branches prises.

**Alternative :** arbitrage de fautes multi-étages et commit unique. C'est une
architecture plus générale, intéressante pour les futures fautes de fetch,
mais elle exigerait une refonte plus large que ce livrable.

Les 65 bits sont un coût RTL logique, pas une estimation de ressources placées.

## D04 — Ne pas inventer une faute d'accès instruction

Le fetch actuel est une ROM de test avec NOP par défaut. Une cible alignée
hors programme n'est pas aujourd'hui une faute d'accès. CF-04 devra définir
plage, validité, latence et annulation des réponses avant d'ajouter cette faute.
Une telle faute doit être rapportée avec son instruction et son âge : un
simple test combinatoire du PC courant ne suffit pas.

## D05 — Préserver le contrat du datapath historique

Ajouter JAL/JALR au décodeur partagé rendait le datapath sans PC capable de
les accepter et d'écrire un faux résultat ALU. Le correctif local restreint le
contrat aux opérations R légales et ADDI déjà documentées. Dupliquer tout le
décodeur ou ajouter un faux PC dans ce module aurait augmenté la maintenance
et brouillé sa vocation pédagogique. Le pipeline conserve le support étendu.

## D06 — Réparer les preuves, pas élargir le CPU pour les tests

La revue a identifié des accès à mscratch non implémenté. Un accès pouvait
paraître fonctionner transitoirement via le forwarding de CSR en attente,
sans prouver le stockage architectural. Les tests utilisent maintenant MEPC
et MTVEC, qui existent effectivement. Ajouter mscratch seulement pour garder
ces stimuli aurait masqué le défaut de couverture et élargi le périmètre ISA.

Les stores annulés utilisent une donnée non nulle et une mémoire initialisée.
Les écritures CSR annulées visent un registre observable. Le critère est leur
absence d'effet, pas seulement l'absence d'un événement de WB dans le banc.

## D07 — Sources historiques et banc CSR

Le banc CSR à port unique est modernisé car ses objectifs sont toujours
pertinents ; il teste aussi l'indépendance des deux adresses. Ses priorités
locales trap/MRET restent distinctes de l'arbitrage par âge du pipeline.

Les deux bancs invalid_load qui attendent une poursuite après faute restent
inchangés et sont catalogués comme historiques. Ils ne sont ni PASS ni tests
actifs ignorés silencieusement. Les suites précises couvrent la conservation
de l'ancien registre et l'annulation des jeunes. Une future variante de
reprise devra exécuter un vrai gestionnaire et MRET, dans un nouveau programme.

## D08 — Générer les fixtures et valider un snapshot propre

Une fixture LD locale était ignorée par *.hex : les succès locaux ne prouvaient
pas la reproductibilité depuis Git. Les petites images sont générées par les
runners dans le build. Les images produites par une future toolchain CF-04
resteront elles aussi des artefacts générés ; les sources assembleur/C seront
versionnées. Une exception globale pour tous les HEX n'est donc pas ajoutée.

Le snapshot inclut les fichiers non suivis non ignorés pour permettre la revue
avant commit. Ce n'est pas une preuve que ces fichiers sont déjà publiés :
le commit futur doit les sélectionner. Le manifest lie la validation aux
contenus précis, sans dépendre uniquement du HEAD qui ne contient pas CF-03.

## D09 — Version CI explicite et builds isolés

La CI précédente ne lançait que la suite générale. La régression complète a
besoin des bancs temporisés/rootp modernes ; Verilator 5.040 est la référence
CI. Les petits tests restent comparables à 4.038. Les versions exactes de la
machine, le commit outil utilisé dans CI et les empreintes des sources sont
journalisés. Le tag choisi est explicite ; sa résolution en commit est conservée.
Les répertoires distincts empêchent les modèles de deux suites de s'écraser.

Une seule variable VERILATOR est résolue et propagée. Aucun chemin privé /opt
n'est imposé. La compilation de l'outil se déroule dans le runner ; aucune
installation système locale n'est faite par ces scripts de vérification.

## Décisions encore ouvertes

- Revue du diff et autorisation du commit, push, PR puis merge séparément.
- Durcissement éventuel de la référence outil par SHA immuable du tag CI.
- Organisation future des programmes intégrés après le chargement CF-04.
- Trace de commit et traitement des fautes IF lors de CF-06.
- Interfaces mémoire à latence variable et arbitrage lors de CF-04/CF-07.
