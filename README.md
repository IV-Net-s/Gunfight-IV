# Gunfight (GTA IV)

Un serveur complet, prêt à lancer : le mode Gunfight de Call of Duty sur GTA IV. Manches courtes de 1v1 à 4v4, même loadout pour tout le monde, drapeau en prolongation, stats et Elo enregistrés. Il utilise tout ce que fait Axora : routing buckets, lockdown, state bags, entités du serveur, NUI, ACE, scripts client, et les **dégâts entre joueurs** (nouveau, voir plus bas).

```
sdk\gunfight\
├── server.ini                        ← game=gta4, monde vide (ni piétons, ni trafic, ni flics)
└── resources\[gunfight]\
    ├── gunfight\
    │   ├── config.lua                ← tous les réglages : modes, durées, loadouts, arènes, équipes, Elo
    │   ├── lib\weapons.lua           ← armes de GTA IV (eWeaponType)
    │   ├── lib\util.lua
    │   ├── server\main.lua           ← lobby, files, événements, commandes, anti-triche
    │   ├── server\match.lua          ← un match : phases, manches, drapeau, limites, résultats
    │   ├── server\queue.lua          ← files d'attente, équipes équilibrées à l'Elo
    │   ├── server\arenas.lua         ← arènes de config.lua + celles modifiées en jeu
    │   ├── server\stats.lua          ← stats et Elo par compte Axora (data\stats.json)
    │   ├── client\main.lua           ← figé au décompte, spectateur, météo, drapeau, touche Tab
    │   ├── ui\                       ← HUD, killfeed, hitmarker, tableau des scores, résultats, menu
    │   └── data\                     ← stats.json, arenas.json (écrits par le serveur)
    └── gunfight_loading\             ← écran de chargement
```

## Lancer

```
AXDK.exe --data "C:\chemin\vers\axora\sdk\gunfight"
```

ou, dans le Server Manager, *Add existing folder* sur `sdk\gunfight`. Mieux : copie le dossier ailleurs avant, pour garder `sdk\` propre (les stats sont écrites dans `data\`).

Il faut un client et un serveur construits depuis cette version : le protocole passe en **v17** (nouveau nœud de sync des armes et paquets de dégâts).

## Jouer

| Commande | |
|---|---|
| `/gf` | menu : rejoindre une file, matchs en cours, mes stats, classement |
| `/queue [1v1\|2v2\|3v3\|4v4]` | rejoindre une file (2v2 par défaut) |
| `/leave` | quitter la file |
| `/stats [joueur]`, `/top`, `/matches` | |
| **Tab** (en match) | tableau des scores |

Déroulement d'un match :

1. Dès qu'une file est pleine, un match part dans **son propre routing bucket** (100, 101…), verrouillé (`strict` : seul le serveur crée des entités) et sans population. Plusieurs matchs tournent en même temps sans se voir.
2. Les équipes sont faites en serpent sur l'Elo. Chaque équipe prend son modèle (`config.teams`), l'arène reçoit ses véhicules de couverture (créés par le serveur, figés, supprimés à la fin).
3. Chaque manche : décompte figé (8 s la première, 5 s ensuite), puis **40 s** sans réapparition. Le loadout est tiré au hasard et change toutes les 2 manches.
4. À la fin du temps, **prolongation** : un drapeau apparaît au centre. 3 s dessus sans adversaire pour gagner la manche. Sinon, l'équipe qui a le plus de santé gagne.
5. Sortir de l'arène : 3 s d'avertissement, puis le joueur perd de la vie (`player:damage`).
6. Premier à **6 manches**. Résultats, MVP, Elo mis à jour, retour au lobby avec son modèle d'origine.

## Entraînement

`/gf`, onglet **Entraînement**, ou `/train [facile|normal|difficile|extreme] [defi]` (`/train stop` pour arrêter). Le joueur est seul dans son routing bucket (500 + son id), face à des cibles créées par le serveur et simulées par son jeu :

| Niveau | Cibles |
|---|---|
| Cibles fixes | immobiles |
| Cibles mobiles | courent d'un point à l'autre de l'arène |
| Cibles armées | ripostent au pistolet |
| Extrême | plus nombreuses, au fusil d'assaut, précises |

Mode **libre** (sans fin) ou **défi 60 s** : le nombre d'éliminations devient le record personnel du niveau (enregistré avec les stats). On choisit le loadout (ou toutes les armes) et l'arène. Le HUD affiche éliminations, headshots, précision (tirs comptés par le jeu du joueur) et record. Les munitions sont rechargées toutes les 10 s sans changer l'arme en main. On peut rester dans une file d'attente pendant l'entraînement : il s'arrête quand le match commence. Réglages : `config.training`.

## Changement d'arme

La molette et les touches 1..0 passent par `CPlayerPed::ProcessWeaponSwitch` du jeu. Le jeu ne l'appelle pas toujours (téléphone sorti, mode réseau, blocage d'un script), donc Axora l'appelle lui-même à chaque frame. `config.weapon_switching = false` la coupe pendant les matchs (le joueur garde l'arme principale du loadout). En Lua : `player:set_weapon_switching(bool)`, côté client `SET_WEAPON_SWITCHING(bool)`.

## Les arènes

Les positions de `config.lua` sont **approximatives** (des endroits connus de Liberty City). Pour les corriger ou en créer une, en jeu, avec les droits admin :

```
/gf_arena                                   ← liste
/gf_arena middle center
/gf_arena middle a reset             ← première apparition de l'équipe A (reset : recommence la liste)
/gf_arena middle a                   ← apparitions suivantes
/gf_arena middle b
/gf_arena middle flag
/gf_arena middle spectate
/gf_arena middle radius              ← la limite passe par ta position
/gf_arena middle cover:stockade      ← véhicule de couverture ici
```

Le nom est cherché sans tenir compte de la casse ni des espaces, et le début suffit (`middle` pour *Middle Park*) : un nom en un seul mot, car les arguments sont séparés par les espaces. Une arène inconnue est créée avec ce nom. Tout est écrit dans `data\arenas.json`, qui passe avant `config.lua`.

## Admins

Les commandes `gf_force <mode>` (lance la file même incomplète), `gf_end <id>`, `gf_arena`, `gf_give <arme> [joueur]` sont réservées au groupe `group.gunfight.admin`. Ajoute ton `account_id` dans `config.admins`, ou en console : la console du serveur a toujours tous les droits.

## Anti-triche

Le serveur vérifie chaque touche avant de la donner à la victime : même bucket, victime synchronisée chez le tireur, vivante, distance (8 m au corps à corps, 400 m sinon), dégâts plausibles, cadence (60 touches et 4000 dégâts par seconde au plus). Une touche refusée n'arrive jamais. Le gunfight expulse un joueur qui accumule plus de `config.max_rejected_hits` refus en 10 s (`player.rejected_hits`).

## Les dégâts entre joueurs (moteur)

Jusqu'ici, la sync de GTA IV ne transmettait ni armes ni tirs : les peds des autres joueurs étaient invincibles et rien ne touchait personne. Le client et le serveur le font maintenant, comme le `WEAPON_DAMAGE_EVENT` du multijoueur de GTA IV :

1. **Le jeu du tireur** voit la balle toucher le ped d'un autre joueur (`CPedDamageCalculator::ApplyDamage`, accroché par signature) et envoie `PlayerHit` : victime, arme, composant, os (1205 = tête), dégâts bruts.
2. **Le serveur** vérifie (voir *Anti-triche*), passe l'événement Lua `weapon_damage` à toutes les resources (annuler, ou changer les dégâts), puis envoie `PlayerDamage` à la victime.
3. **Le jeu de la victime** rejoue le même calcul sur son ped : armure, multiplicateur de tête, mort, ragdoll, tueur. Sa nouvelle santé repart dans la sync.
4. À sa mort, le serveur envoie `player_killed(victim, killer, weapon, headshot, bone)` avec le dernier tireur des 10 dernières secondes.

En plus, un nœud de sync « arme » (20 Hz) transmet l'arme en main, l'armure, la visée, le point visé et un compteur de tirs : chez les autres, le ped tient la bonne arme, vise où le joueur vise, et chaque tir est rejoué (balle et flash, sans dégâts : seuls ceux validés par le serveur comptent). La mort d'un joueur est jouée chez tout le monde.

API Lua serveur ajoutée (voir `sdk/types/axora.lua`) : `player.weapon`, `player.armour`, `player.aiming`, `player.rejected_hits`, `player:give_weapon(arme, munitions, en_main)`, `player:remove_weapons()`, `player:set_weapon(arme)`, `player:set_health(n)`, `player:set_armour(n)`, `player:damage(n, [attaquant], [arme])`, événements `weapon_damage`, `player_killed`, et `player_weapon_change` côté serveur. Côté client, `GIVE_WEAPON_TO_CHAR` et `TASK_AIM_GUN_AT_COORD` sont maintenant dans la table des natives.

Les véhicules (commandes, apparence, dégâts) et les projectiles (grenades, roquettes, molotovs) sont aussi synchronisés : voir *Véhicules et projectiles* dans `sdk/README.md`. Limite connue : les coups de corps à corps comptent, mais l'animation du coup n'est pas rejouée chez les autres.
