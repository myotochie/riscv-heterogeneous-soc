# CF-03 — Cours : comprendre un appel de fonction dans le pipeline

## 1. Ce qu'il faut distinguer

Une instruction de saut produit un effet de contrôle (le prochain PC) et peut
produire une donnée (l'adresse de retour). Les deux valeurs ne sont pas
interchangeables. Un saut vers une fonction située loin de l'appelant doit
écrire l'adresse située immédiatement après l'appel, pas la cible.

Le PC fourni à EX est celui de l'instruction dans ID/EX, pas le PC courant du
fetch. Au moment où EX résout un saut, IF a déjà avancé et peut être en train
de lire une instruction qui sera annulée. Calculer le lien depuis le PC IF
serait donc faux, même si un petit programme sans hazard semble fonctionner.

## 2. Décoder l'immédiat J

L'encodage J distribue les bits du déplacement dans plusieurs champs :

| Bits du déplacement signé | Provenance dans l'instruction |
|---|---|
| 20 (signe) | 31 |
| 19:12 | 19:12 |
| 11 | 20 |
| 10:1 | 30:21 |
| 0 | Constante zéro |

La concaténation produit 21 bits. Répéter son signe vers les bits supérieurs
permet d'additionner un déplacement négatif au PC 64 bits. Le bit bas nul
vient de l'encodage, pas d'un effacement arbitraire après le calcul.

Exemple réel du programme 36 :

```asm
# Adresse          Mot machine      Lecture assembleur
# 0x80000004       03c000ef         jal x1, 0x80000040
# déplacement = 0x40 - 0x04 = 0x3c
```

Le saut écrit x1=0x80000008. La fonction peut observer ce lien, appeler une
autre fonction et revenir ensuite. Le CPU n'a pas besoin de savoir que x1
s'appelle ra : il applique le champ rd de l'instruction.

## 3. Comprendre JALR et ses cas limites

JALR est une instruction I : l'immédiat signé vaut instr[31:20]. Contrairement
à l'immédiat J, il peut être impair. La règle est une addition puis un masque :

```text
somme = ancienne_valeur_rs1 + sext(imm12)
cible = somme & 0xffffffffffff_fffe
lien = PC_du_JALR + 4
```

Exemples :

| rs1 | immédiat | Somme | Cible | Résultat avec IALIGN=32 |
|---|---:|---|---|---|
| 0x2001 | 12 | 0x200d | 0x200c | Alignée |
| 0x2000 | 3 | 0x2003 | 0x2002 | Trap cause 0 |
| 0x2008 | -8 | 0x2000 | 0x2000 | Alignée |

Le masque enlève le bit 0, pas le bit 1. Un cœur avec uniquement des
instructions de 32 bits exige ici un multiple de quatre. L'extension C
modifierait cette hypothèse ; elle n'est pas activée dans le cœur actuel.

Si `rd=rs1`, l'ordre conceptuel est « lire l'ancien registre, calculer, puis
écrire ». L'implémentation pipeline réalise cela grâce à la donnée source
capturée/forwardée en EX et au lien écrit plus tard en WB. Elle ne doit pas
substituer PC+4 comme base de sa propre cible.

## 4. RET et conventions d'appel

RET est un alias assembleur de `jalr x0,0(x1)` : mot `0x00008067`.
Le registre x0 supprime seulement le nouveau lien ; la redirection est normale.
Un appel imbriqué écraserait ra si le logiciel ne le sauvegardait pas.
Le programme 36 utilise une adresse de laboratoire 128 pour cette sauvegarde.
Ce n'est pas une preuve de startup C ou de pile ABI complète.

```asm
# Extrait représentatif : x20 a été initialisé à 128.
sd   x1, 0(x20)       # sauvegarder le lien de l'appelant
jal  x5, sous_fonction
ld   x1, 0(x20)       # restaurer le lien original
jalr x0, 0(x1)        # retourner, après interlock load-use si nécessaire
```

L'ABI appelle x1 ra, x2 sp, x10–x17 les registres a0–a7. Le processeur ne
sauvegarde pas automatiquement ces registres lors d'un appel ordinaire.
La vérification complète des registres préservés, de la pile alignée et des
arguments C appartient à CF-05. Les pseudo-instructions `call` peuvent se
traduire en AUIPC/JALR : leur présence dans du code assembleur ne garantit pas
que le sous-ensemble matériel actuel peut les exécuter.

## 5. Forwarding et bypass du banc : deux chemins différents

Imaginez qu'une addition produise une adresse et que l'instruction suivante
soit JALR. Sans forwarding, ID a pu lire une ancienne valeur du registre.
EX doit sélectionner le résultat récent en EX/MEM. Une instruction plus
ancienne en MEM/WB doit perdre face à ce producteur plus récent.

Pour un load immédiatement suivi d'un JALR, le résultat n'est pas encore
celui d'EX/MEM : ce champ contient l'adresse du load, pas la donnée chargée.
Le hazard detector insère une bulle puis le mux prend la donnée WB finale.

Le premier consommateur à la cible d'un JAL arrive plus tard, car deux slots
jeunes ont été purgés. Il peut lire le lien au cycle où le saut est en WB grâce
au bypass interne du banc vers ID. Il serait trompeur d'appeler cela une
preuve que le bypass EX/MEM d'un lien a été exercé en intégration. Les tests
unitaires et les compteurs de sélection servent à distinguer ces cas.

## 6. Flush, stall et valid

Un registre de pipeline contient des données et leur autorisation d'exister
comme instruction (valid). Mettre des données à zéro ne suffit pas à annuler
une instruction si ses commandes d'écriture restent actives.

- **Stall** : conserver les champs, ne pas répéter les effets, reprendre ensuite.
- **Flush** : insérer une bulle, supprimer les effets même si des données restent.
- **Reset** : remettre le contrôle et les CSR à leur état défini ; cela ne signifie
  pas que toute RAM ou tout GPR est effacé.

Une redirection EX ne doit pas flusher son propre EX/MEM : le saut doit encore
écrire le lien. Une redirection plus ancienne, elle, doit annuler ce saut jeune.
Les qualifiers valid, illegal, stall, flush et faute ont des responsabilités
distinctes ; les fusionner en un signal vague masque souvent des erreurs d'âge.

## 7. Pourquoi attendre MEM pour prendre le trap ?

Au moment où EX découvre une cible désalignée, une autre instruction peut
être en MEM et une troisième en WB. Ces instructions sont plus anciennes.
Le cœur transporte le défaut jusqu'en MEM afin de réutiliser l'arbitrage de
traps et de laisser le WB ancien terminer. Le saut fautif ne fournit jamais
son lien comme donnée de forwarding.

Les CSR de trap répondent à trois questions :
- **mepc** : quelle instruction a causé l'exception ? Le PC du saut, pas la cible.
- **mcause** : quelle classe de faute ? Ici 0 pour adresse d'instruction désalignée.
- **mtval** : quelle donnée aide au diagnostic ? Ici la cible finale.

Un MRET en WB est ancien par rapport à une faute MEM jeune. Le pipeline doit
supprimer cette faute. À l'intérieur de csr_file, le trap reste prioritaire
si le bloc reçoit artificiellement trap et MRET simultanément. Il n'y a pas
contradiction : le top évite précisément cette combinaison pour le cas d'âge
qui impose de retenir le MRET.

## 8. Expériences à reproduire

Depuis la racine du dépôt, avec une version installée :

```bash
VERILATOR=/chemin/verilator bash verification/scripts/run_jump_unit.sh
VERILATOR=/chemin/verilator-5.040 bash scripts/run_clean_regression.sh
```

Pour suivre les expériences intégrées :
1. Programme 36 : vérifier liens 0x80000008 et 0x8000004c, sauvegarde et RET.
2. Programme 37 : distinguer ALU, CSR MEPC et load comme producteurs de cible.
3. Programme 39 : vérifier cible 0x80000022 après masque et ancien ra conservé.
4. Programme 45 : observer l'absence de load-use malgré l'alias de champs JAL.
5. Programme 47 : vérifier que la faute LD ancienne gagne sur le JALR jeune.

Lire les résultats et les chemins de logs dans le dossier de vérification.
Ne déduire aucune fréquence FPGA ni conformité ISA complète de ces expériences.

## 9. Ce que je dois maîtriser

**Concepts essentiels :** immédiats signés, PC associé à l'instruction, lien,
ancienneté, valid, sélection du producteur récent, load-use, annulation précise.

**Fichiers à relire :** decoder.sv, branch_target.sv, execute_stage.sv,
fetch_decode_execute_path.sv, pipeline_ex_mem.sv, rv64_pipeline.sv,
writeback_stage.sv et tb_jump_pipeline.cpp.

**Signaux à suivre :** id_ex_pc/instr/valid, ex_forwarded_rs1, forward_a,
ex_branch_target/redirect, ex_target_misaligned, ex_mem_reg_write,
ex_mem_target_misaligned, redirect_valid, mret_retire, trap_take et wb_we/data.

**Cinq questions techniques — essayer avant de lire la suite :**

1. Pourquoi JALR avec rd=rs1 doit-il utiliser l'ancienne valeur du registre ?
2. Pourquoi une somme JALR impaire n'est-elle pas nécessairement fautive ?
3. Quelle instruction peut encore écrire au cycle du trap d'un saut en MEM ?
4. Pourquoi le premier consommateur du lien à la cible n'exerce-t-il pas
   nécessairement le forwarding EX/MEM ?
5. Pourquoi un succès local ne prouve-t-il ni la reproductibilité sur GitHub,
   ni la conformité RV64I complète ?

## 10. Réponses expliquées

**1.** La source de l'instruction est évaluée avant son résultat. Si le nouveau
lien remplaçait la base, le saut utiliserait sa propre adresse de retour et
perdrait la destination demandée. Le calcul EX et l'écriture WB séparent ces
rôles ; un forwarding doit sélectionner un producteur antérieur, pas le saut
lui-même. Le test rd=rs1 protège cette propriété.

**2.** La spécification JALR enlève le bit 0 après l'addition. Par exemple
0x200d devient 0x200c, aligné sur quatre. En revanche 0x2003 devient 0x2002,
qui conserve son bit 1 et doit provoquer le trap avec IALIGN=32. Arrondir
systématiquement sur quatre serait incorrect : cela masquerait cette faute.

**3.** L'instruction valide, non fautive et non annulée en WB est plus ancienne
et peut terminer. Si c'est un CSR MTVEC, sa nouvelle valeur doit déterminer
la destination du trap. Si c'est MRET, le top retient au contraire le retour
ancien et supprime la faute jeune. Ce sont des règles d'âge, pas des priorités
arbitraires attribuées aux noms des instructions.

**4.** La redirection purge IF/ID et ID/EX. Le premier consommateur à la cible
n'arrive en ID qu'au cycle où le saut est en WB. Le bypass du banc peut donc
lui fournir le lien avant son entrée en EX. Les chemins EX/MEM/MEM/WB restent
correctement capables de transporter ce résultat, mais leur exercice doit
être mesuré séparément. Les compteurs de sélection et les tests unitaires
éviteront une conclusion de couverture abusive.

**5.** Un fichier HEX ignoré ou une installation /opt implicite peut manquer sur
un clone neuf. Le snapshot sans fichiers ignorés et le manifest rendent cette
dépendance visible. Même un tel test réussi ne couvre que des stimuli finis :
les instructions absentes, les comportements privilégiés incomplets et les
combinaisons non exercées interdisent de revendiquer toute l'ISA. Il faut aussi
distinguer simulation RTL, comparaison architecturale et validation physique.
