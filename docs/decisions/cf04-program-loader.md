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
