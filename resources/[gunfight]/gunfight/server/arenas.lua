-- Arenes de config.lua, modifiees en jeu par /gf_arena (data/arenas.json).
local config = require("config")
local util = require("lib.util")

local arenas = {}

local path = util.resource_dir() .. "/data/arenas.json"
local list = {}

local function key(name)
	return (name:lower():gsub("[^%w]", ""))
end

function arenas.load()
	list = util.copy(config.arenas)
	local saved = util.read_json(path) or {}
	for _, edited in pairs(saved) do
		local found
		for i, arena in ipairs(list) do
			if key(arena.name) == key(edited.name or "") then found = i end
		end
		if found then list[found] = edited else list[#list + 1] = edited end
	end
	return #list
end

function arenas.all()
	return list
end

function arenas.find(name)
	local wanted = key(name or "")
	for _, arena in ipairs(list) do
		if key(arena.name) == wanted or (#wanted > 0 and key(arena.name):sub(1, #wanted) == wanted) then return arena end
	end
end

function arenas.random(exclude)
	local pool = {}
	for _, arena in ipairs(list) do
		if arena ~= exclude then pool[#pool + 1] = arena end
	end
	if #pool == 0 then pool = list end
	return pool[math.random(#pool)]
end

-- Position du joueur pour un point de l'arene : a / b ajoutent une apparition (reset : recommence la liste).
function arenas.record(arena_name, point, x, y, z, heading, reset)
	local arena = arenas.find(arena_name)
	if not arena then
		arena = { name = arena_name, center = { x = x, y = y, z = z }, radius = 50.0, a = {}, b = {},
			flag = { x = x, y = y, z = z }, spectate = { x = x, y = y, z = z + 10, heading = 0 }, cover = {}, time = 12, weather = 0 }
		list[#list + 1] = arena
	end
	local spot = { x = x, y = y, z = z, heading = heading }
	if point == "a" or point == "b" then
		if reset or type(arena[point]) ~= "table" then arena[point] = {} end
		table.insert(arena[point], spot)
	elseif point == "flag" or point == "spectate" or point == "center" then
		arena[point] = spot
	elseif point == "radius" then
		arena.radius = util.distance(arena.center, x, y, z)
	elseif point:sub(1, 6) == "cover:" then
		arena.cover = arena.cover or {}
		spot.model = point:sub(7)
		table.insert(arena.cover, spot)
	else
		return nil, "point inconnu : a, b, flag, spectate, center, radius, cover:<modele>"
	end

	local saved = util.read_json(path) or {}
	saved[key(arena.name)] = arena
	local ok, err = util.write_json(path, saved)
	if not ok then return arena, "pas enregistree (" .. tostring(err) .. ")" end
	return arena
end

function arenas.spawn(arena, side, index)
	local spots = arena[side]
	return spots[index] or spots[((index - 1) % #spots) + 1]
end

return arenas
