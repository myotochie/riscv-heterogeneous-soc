# CF-05.2b — Décisions techniques

## D-I01 — Réutiliser les opérations ALU déjà présentes

ADD, SLT/SLTU, XOR/OR/AND et SLL/SRL/SRA ont les bonnes largeurs et sont déjà
testés comme opérations registre-registre. Seul leur décodage immédiat manque.
Ajouter des opérations ALU distinctes OP-IMM dupliquerait les fonctions et
augmenterait les points de maintenance, sans gain démontré. Le choix réutilise
EX, WB et les bypasses sans port supplémentaire. Aucun chiffre de fréquence,
surface ou CPI n'est inféré de ce choix.

## D-I02 — Vérifier funct6 pour les shifts RV64

Le bit 25 est shamt[5], pas un bit fixe de funct7. Vérifier funct7==0 ou 0x20
comme pour des shifts RV32 rejetterait la moitié des shifts RV64 légaux.
Le choix est de vérifier instr[31:26] et laisser l'ALU prendre les six bits bas.
L'alternative de normaliser le shamt dans imm_gen ajouterait une distinction
sans besoin fonctionnel ; le générateur I et l'ALU restent inchangés.

## D-I03 — Garder l'extension de signe pour SLTIU et les logiques

Le suffixe U concerne la comparaison, pas la construction de l'immédiat.
Étendre zéro serait erroné pour les valeurs négatives, comme XORI -1 ou
SLTIU avec rs1 haut et un seuil -2048. L'oracle et les stimuli distinguent ces
cas au lieu de seulement essayer des petits entiers positifs.

## D-I04 — Préserver explicitement le datapath pédagogique R/ADDI

Le filtre antérieur autorisait l'opcode entier 0x13, mais seule ADDI était
reconnue dans le décodeur. Le lot aurait ainsi élargi son interface par effet
de bord. Le choix précise le filtre funct3=000 et teste les refus sans effet
GPR. Une extension pédagogique explicite resterait possible avec son propre
contrat et ses tests. Le vrai pipeline accepte les huit nouvelles formes.
Cette restriction conserve toutes les fonctionnalités préexistantes.

## D-I05 — Ne pas élargir silencieusement la gestion des instructions illégales

Les préfixes réservés sont détectés et ne modifient pas l'état. Le cœur n'a
pas encore de trap général illegal-instruction. Ajouter cette exception
exigerait un lot sur cause/EPC/tval, priorités et précision avec les autres
traps ; cela dépasse les huit instructions et ne doit pas être revendiqué
à partir d'un simple rejet de décodage. Ce manque reste documenté.

## D-I06 — Garder les preuves historiques et faire évoluer les gardes

Les statuts 21 puis 23 formes appartiennent aux anciens jalons ; la matrice
vivante passe à 31 après les preuves RTL ciblées. Le filtre ELF suit exactement
le nouveau sous-ensemble, avec refus des préfixes réservés et des autres
instructions absentes. SLLI 42 devient un test positif et un vrai préfixe
réservé fournit le négatif. Aucun échec ne doit être converti en PASS en
changeant seulement une attente contraire à la sémantique requise.

## D-I07 — Aucun nouveau mécanisme système ou multicœur

Le lot ne décide ni mapping .data, ni startup, ni synchronisation. Les
alternatives de chargement des initialiseurs, puis l'ABI et les formes W et
mémoire restantes doivent encore être examinées. Ce décodage ne nécessite
ni cache cohérent, ni bus, ni atomicité supplémentaire et n'en fournit aucun.
Les programmes intégrés et le smoke CF-04 sont préservés ; aucune dépendance
externe ou licence nouvelle n'est introduite.
