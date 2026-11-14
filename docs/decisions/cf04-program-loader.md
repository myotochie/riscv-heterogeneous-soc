# Décisions CF-04.1/2

## D04-01 — Backend externe optionnel

Problème : remplacer immédiatement la table historique rendrait les tests de
contrôle dépendants d'une migration de 48 programmes. Décision : IMEM_FILE vide
conserve le comportement historique, une chaîne non vide active la ROM externe.
Conséquence : sélection au build, pas de mux logiciel ni nouvelle instruction.
Les deux chemins partagent PC et IF/ID ; la table historique n'est pas déplacée.

## D04-02 — Mots HEX denses et stricts

Alternatives : octets BIN, HEX avec @adresses, chargement direct ELF, mots HEX.
Décision : mots de huit chiffres hexadécimaux. La validation peut détecter une
image trop grande avant son chargement. L'absence de @adresses évite de
confondre adresse absolue et indice. Coût : conversion préalable nécessaire
pour les futurs ELF ; commentaires interdits. $readmemh seul est insuffisant
pour imposer ce contrat portable ; une passe de validation précède la lecture.

## D04-03 — Latence combinatoire inchangée

La ROM synchrone et le bus requête/réponse sont utiles pour FPGA/multicœur,
mais ajoutent du suivi de réponses et de l'annulation après branchement.
Le jalon actuel isole stockage et fetch sans ajouter ces états. Aucun gain
matériel ou temporel mesuré n'est prétendu. La synthèse reste à valider.

## D04-04 — Diagnostic de simulation pour les accès invalides

Le cœur ne transporte pas de faute d'accès fetch. Décision : diagnostic fatal
sur fetch accepté, masqué par reset, flush et stall IF/ID. Une vraie exception
instruction-access-fault nécessitera PC/validité et priorité face aux fautes
plus anciennes. Le NOP de sortie de ROM est une valeur sûre, pas une promesse
de poursuite architecturale après faute. Le remplissage NOP dans la capacité
est en revanche intentionnel et peut masquer un saut au-delà de l'image :
ce risque impose des délais/signatures au banc.

## D04-05 — Pas d'installation ou d'extension ISA implicite

Aucun outil croisé n'a été trouvé dans les emplacements inspectés. Ce jalon
utilise donc une fixture encodée, documentée instruction par instruction.
Choix/version/licence de toolchain et installation éventuelle seront soumis
à l'utilisateur au jalon suivant. Aucun support C, ELF, BIN ou conformité
RV64I complète ne découle de la réussite de ce smoke.

## D04-06 — Binutils sans compilateur C pour le premier programme

Le programme assembleur a seulement besoin de as, ld, objcopy, objdump et
readelf. Ajouter GCC/libc maintenant ne démontrerait pas que leurs instructions
sont prises en charge. Le choix retenu est le paquet bare-metal Binutils
2.35.1-0ubuntu1 disponible dans APT. Version, licence et empreinte sont relevées.
L'installation système n'étant pas accessible sans saisie sudo, le même paquet
est extrait dans un répertoire privé ignoré. Cette installation est isolée,
reproductible et ne change pas PATH ; elle n'est pas incluse dans Git.

## D04-07 — Contrôle ELF avant émission du HEX

objcopy -O binary seul perd adresses, sections et entrée. La solution retenue
est un parseur restreint ELF64 little-endian avec la bibliothèque standard
Python, puis comparaison indépendante à objcopy pour notre .text dense.
Alternative pyelftools : moins de parsing à maintenir, mais nouvelle dépendance
à versionner ; alternative parsing texte readelf : fragile aux versions/locales.
Le parseur restreint n'est pas un chargeur ELF universel : tables étendues,
dynamique, TLS, initialisation data/BSS et LMA/VMA différents sont refusés.

## D04-08 — Instructions finales inspectées et filtrées

-march=rv64i reste plus large que le cœur. L'assembleur exclut C et la
relaxation ; le convertisseur vérifie chaque mot selon une liste explicite.
Cette liste doit évoluer avec le RTL et ses tests lors de CF-05, sans annoncer
une conformité RV64I sur la base de ce seul filtre. Les pseudo-instructions
call/ret et les adresses matérialisées par LUI/AUIPC ne sont pas utilisées.

## D04-09 — Fin déterministe observée par le banc

Le programme boucle sur JAL x0,done. Le banc contrôle la totalité des cinq
writebacks attendus, la signature 42 et plusieurs slots de boucle sur 100 cycles.
Alternative ECALL/EBREAK : ces traps ne sont pas implémentés. Alternative MMIO
tohost : périphérique supplémentaire hors périmètre. Aucun HALT propriétaire
ou mécanisme de retrait architectural CF-06 n'est ajouté.
