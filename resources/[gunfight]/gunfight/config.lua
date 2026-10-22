-- Reglages du gunfight. Les arenes modifiees en jeu (/gf_arena) sont gardees dans data/arenas.json
-- et passent avant celles d'ici.
local config = {}

config.lobby = { x = -110.0, y = 830.0, z = 15.0, heading = 0.0 } -- Middle Park
config.lobby_bucket = 0
config.first_bucket = 100 -- un routing bucket par match : 100, 101...

config.modes = {
	["1v1"] = { size = 1, label = "1v1" },
	["2v2"] = { size = 2, label = "2v2" },
	["3v3"] = { size = 3, label = "3v3" },
	["4v4"] = { size = 4, label = "4v4" },
}
config.default_mode = "2v2"

config.rounds_to_win = 6
config.loadout_rounds = 2   -- meme loadout pendant 2 manches, comme dans CoD
config.first_countdown = 8  -- s, premiere manche
config.countdown = 5        -- s
config.round_time = 40      -- s
config.overtime = 15        -- s : le drapeau apparait au centre
config.capture_time = 3     -- s sur le drapeau, sans adversaire
config.capture_radius = 3.0 -- m
config.round_end = 4        -- s
config.results_time = 10    -- s
config.out_of_bounds_grace = 3 -- s hors de l'arene avant de perdre de la vie
config.out_of_bounds_damage = 20 -- par seconde ensuite

-- Sante d'un joueur GTA IV pour les jauges du HUD : 200 au maximum, la jauge du jeu se vide a 100.
-- Si les barres paraissent fausses, mets health_dead a 0.
config.health_max = 200
config.health_dead = 100

config.friendly_fire = false
config.weapon_switching = true -- molette / touches 1..0 en match ; false : le joueur garde l'arme principale du loadout
config.damage_scale = 1.0 -- multiplie toutes les touches validees

config.teams = {
	{ name = "Alpha", color = "#3fa7ff", model = "m_y_swat" },
	{ name = "Bravo", color = "#ff8a3d", model = "m_m_fbi" },
}

-- Loadouts tires au hasard, les memes pour les deux equipes (armes : lib/weapons.lua).
config.loadouts = {
	{ name = "Pistoleros",    weapons = { { "pistol", 68 } }, armour = 0 },
	{ name = "Desert Eagle",  weapons = { { "deagle", 35 } }, armour = 25 },
	{ name = "Pompe",         weapons = { { "shotgun", 16 }, { "pistol", 34 } }, armour = 0 },
	{ name = "Combat",        weapons = { { "combat_shotgun", 24 } }, armour = 25 },
	{ name = "Uzi",           weapons = { { "uzi", 150 } }, armour = 0 },
	{ name = "MP5",           weapons = { { "mp5", 150 }, { "pistol", 34 } }, armour = 25 },
	{ name = "AK-47",         weapons = { { "ak47", 120 } }, armour = 50 },
	{ name = "M4",            weapons = { { "m4", 120 }, { "deagle", 14 } }, armour = 25 },
	{ name = "Tireur d'elite", weapons = { { "sniper", 20 }, { "pistol", 34 } }, armour = 0 },
	{ name = "Sniper de combat", weapons = { { "combat_sniper", 30 } }, armour = 25 },
}

-- Arenes. a / b : apparition des equipes (une position par joueur, la premiere est reprise si besoin),
-- flag : drapeau de prolongation, spectate : ou attendent les joueurs elimines, radius : limite.
-- Positions approximatives : place-toi en jeu et tape /gf_arena <nom> <a|b|flag|spectate|center>.
config.arenas = {
	{
		name = "Middle Park",
		center = { x = -110.0, y = 830.0, z = 15.0 },
		radius = 60.0,
		a = { { x = -135.0, y = 830.0, z = 15.0, heading = 270.0 }, { x = -135.0, y = 834.0, z = 15.0, heading = 270.0 }, { x = -135.0, y = 826.0, z = 15.0, heading = 270.0 }, { x = -137.0, y = 830.0, z = 15.0, heading = 270.0 } },
		b = { { x = -85.0, y = 830.0, z = 15.0, heading = 90.0 }, { x = -85.0, y = 834.0, z = 15.0, heading = 90.0 }, { x = -85.0, y = 826.0, z = 15.0, heading = 90.0 }, { x = -83.0, y = 830.0, z = 15.0, heading = 90.0 } },
		flag = { x = -110.0, y = 830.0, z = 15.0 },
		spectate = { x = -110.0, y = 870.0, z = 15.0, heading = 180.0 },
		cover = { { model = "stockade", x = -118.0, y = 836.0, z = 15.0, heading = 0.0 }, { model = "mule", x = -102.0, y = 824.0, z = 15.0, heading = 0.0 } },
		time = 20, weather = 0,
	},
	{
		name = "Aeroport",
		center = { x = 2393.0, y = 455.0, z = 6.0 },
		radius = 70.0,
		a = { { x = 2368.0, y = 455.0, z = 6.0, heading = 270.0 }, { x = 2368.0, y = 459.0, z = 6.0, heading = 270.0 }, { x = 2368.0, y = 451.0, z = 6.0, heading = 270.0 }, { x = 2366.0, y = 455.0, z = 6.0, heading = 270.0 } },
		b = { { x = 2418.0, y = 455.0, z = 6.0, heading = 90.0 }, { x = 2418.0, y = 459.0, z = 6.0, heading = 90.0 }, { x = 2418.0, y = 451.0, z = 6.0, heading = 90.0 }, { x = 2420.0, y = 455.0, z = 6.0, heading = 90.0 } },
		flag = { x = 2393.0, y = 455.0, z = 6.0 },
		spectate = { x = 2393.0, y = 500.0, z = 6.0, heading = 180.0 },
		cover = { { model = "flatbed", x = 2385.0, y = 462.0, z = 6.0, heading = 0.0 }, { model = "stockade", x = 2401.0, y = 448.0, z = 6.0, heading = 0.0 }, { model = "sultan", x = 2393.0, y = 440.0, z = 6.0, heading = 90.0 } },
		time = 12, weather = 0,
	},
	{
		name = "Star Junction",
		center = { x = -165.0, y = 345.0, z = 15.0 },
		radius = 55.0,
		a = { { x = -165.0, y = 320.0, z = 15.0, heading = 0.0 }, { x = -161.0, y = 320.0, z = 15.0, heading = 0.0 }, { x = -169.0, y = 320.0, z = 15.0, heading = 0.0 }, { x = -165.0, y = 318.0, z = 15.0, heading = 0.0 } },
		b = { { x = -165.0, y = 370.0, z = 15.0, heading = 180.0 }, { x = -161.0, y = 370.0, z = 15.0, heading = 180.0 }, { x = -169.0, y = 370.0, z = 15.0, heading = 180.0 }, { x = -165.0, y = 372.0, z = 15.0, heading = 180.0 } },
		flag = { x = -165.0, y = 345.0, z = 15.0 },
		spectate = { x = -140.0, y = 345.0, z = 15.0, heading = 90.0 },
		cover = { { model = "bus", x = -160.0, y = 338.0, z = 15.0, heading = 90.0 }, { model = "mule", x = -170.0, y = 352.0, z = 15.0, heading = 90.0 } },
		time = 23, weather = 0,
	},
	{
		name = "Hove Beach",
		center = { x = 894.0, y = -500.0, z = 15.0 },
		radius = 55.0,
		a = { { x = 869.0, y = -500.0, z = 15.0, heading = 270.0 }, { x = 869.0, y = -496.0, z = 15.0, heading = 270.0 }, { x = 869.0, y = -504.0, z = 15.0, heading = 270.0 }, { x = 867.0, y = -500.0, z = 15.0, heading = 270.0 } },
		b = { { x = 919.0, y = -500.0, z = 15.0, heading = 90.0 }, { x = 919.0, y = -496.0, z = 15.0, heading = 90.0 }, { x = 919.0, y = -504.0, z = 15.0, heading = 90.0 }, { x = 921.0, y = -500.0, z = 15.0, heading = 90.0 } },
		flag = { x = 894.0, y = -500.0, z = 15.0 },
		spectate = { x = 894.0, y = -460.0, z = 15.0, heading = 180.0 },
		cover = { { model = "stockade", x = 888.0, y = -494.0, z = 15.0, heading = 0.0 }, { model = "flatbed", x = 900.0, y = -506.0, z = 15.0, heading = 0.0 } },
		time = 6, weather = 3,
	},
}

-- Entrainement : seul dans son routing bucket, contre des cibles creees par le serveur.
config.training = {
	first_bucket = 500,     -- 500 + id du joueur
	challenge_time = 60,    -- s : mode defi, le record personnel compte les eliminations
	respawn_delay = 1.5,    -- s avant qu'une cible abattue reapparaisse
	refill_every = 10,      -- s : munitions rechargees
	models = { "m_y_cop", "m_y_swat", "m_m_fbi" }, -- tires au hasard pour chaque cible
	levels = {
		{ key = "facile",    label = "Cibles fixes",  description = "Immobiles, pour regler sa visee", count = 6, behaviour = "static" },
		{ key = "normal",    label = "Cibles mobiles", description = "Courent d'un point a l'autre de l'arene", count = 6, behaviour = "moving" },
		{ key = "difficile", label = "Cibles armees", description = "Ripostent au pistolet", count = 4, behaviour = "armed", weapon = "pistol", accuracy = 25 },
		{ key = "extreme",   label = "Extreme",       description = "Plus nombreuses, au fusil d'assaut, precises", count = 6, behaviour = "armed", weapon = "ak47", accuracy = 60 },
	},
}

-- Elo
config.elo_start = 1000
config.elo_k = 32

-- Anti-triche : touches refusees par les verifications du serveur (portee, perimetre, cadence)
config.max_rejected_hits = 40 -- en 10 s : expulse
config.admins = {
	-- [42] = true, -- player.account_id
}

return config
