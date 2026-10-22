-- Files d'attente par mode. Des qu'une file a deux equipes completes, un match part, equilibre a l'Elo.
local config = require("config")
local util = require("lib.util")
local stats = require("server.stats")

local queue = {}
local lines = {}
for mode in pairs(config.modes) do lines[mode] = {} end

local function remove(list, player)
	for i = #list, 1, -1 do
		if not util.valid(list[i]) or list[i] == player then table.remove(list, i) end
	end
end

function queue.leave(player)
	for _, list in pairs(lines) do remove(list, player) end
end

function queue.join(player, mode)
	if not lines[mode] then return false end
	queue.leave(player)
	table.insert(lines[mode], player)
	return true
end

function queue.mode_of(player)
	for mode, list in pairs(lines) do
		for _, queued in ipairs(list) do
			if queued == player then return mode end
		end
	end
end

function queue.counts()
	local out = {}
	for mode, list in pairs(lines) do
		remove(list, nil)
		out[mode] = { queued = #list, needed = config.modes[mode].size * 2, label = config.modes[mode].label }
	end
	return out
end

-- Equipes en serpent (1-2-2-1...) sur l'Elo, du plus fort au plus faible.
local function balance(players)
	table.sort(players, function(a, b) return stats.get(a).elo > stats.get(b).elo end)
	local sides = { {}, {} }
	for i, player in ipairs(players) do
		local round = math.floor((i - 1) / 2)
		local first = (i - 1) % 2 == 0
		local side = (round % 2 == 0) == first and 1 or 2
		table.insert(sides[side], player)
	end
	return sides
end

-- Retire les joueurs d'un match pret : { mode, sides } ou nil.
function queue.take()
	for mode, list in pairs(lines) do
		remove(list, nil)
		local needed = config.modes[mode].size * 2
		if #list >= needed then
			local players = {}
			for i = 1, needed do players[i] = table.remove(list, 1) end
			return { mode = mode, sides = balance(players) }
		end
	end
end

-- Admin : lance le mode avec ceux qui attendent, meme incomplet (au moins 2).
function queue.force(mode)
	local list = lines[mode]
	if not list then return nil end
	remove(list, nil)
	if #list < 2 then return nil end
	local players = {}
	while #list > 0 and #players < config.modes[mode].size * 2 do players[#players + 1] = table.remove(list, 1) end
	return { mode = mode, sides = balance(players) }
end

return queue
