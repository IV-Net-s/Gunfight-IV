-- Armes de GTA IV (eWeaponType), celles que le serveur recoit dans player.weapon et "weapon_damage".
local weapons = {
	[0]  = { name = "Poings", key = "unarmed" },
	[1]  = { name = "Batte", key = "bat" },
	[2]  = { name = "Queue de billard", key = "poolcue" },
	[3]  = { name = "Couteau", key = "knife" },
	[4]  = { name = "Grenade", key = "grenade" },
	[5]  = { name = "Cocktail Molotov", key = "molotov" },
	[7]  = { name = "Pistolet", key = "pistol" },
	[9]  = { name = "Desert Eagle", key = "deagle" },
	[10] = { name = "Fusil a pompe", key = "shotgun" },
	[11] = { name = "Fusil de combat", key = "combat_shotgun" },
	[12] = { name = "Micro-Uzi", key = "uzi" },
	[13] = { name = "MP5", key = "mp5" },
	[14] = { name = "AK-47", key = "ak47" },
	[15] = { name = "M4", key = "m4" },
	[16] = { name = "Sniper de combat", key = "combat_sniper" },
	[17] = { name = "M40A1", key = "sniper" },
	[18] = { name = "Lance-roquettes", key = "rpg" },
}

local by_key = {}
for id, weapon in pairs(weapons) do
	weapon.id = id
	by_key[weapon.key] = weapon
end

local M = {}

function M.name(id)
	local weapon = weapons[id]
	return weapon and weapon.name or ("arme " .. tostring(id))
end

function M.id(value)
	if type(value) == "number" then return value end
	local weapon = by_key[value]
	return weapon and weapon.id
end

function M.melee(id)
	return id ~= nil and id <= 3
end

return M
