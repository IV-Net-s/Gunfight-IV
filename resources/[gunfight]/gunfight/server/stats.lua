-- Stats par compte Axora (player.account_id : le meme sur tous les serveurs), dans data/stats.json.
local config = require("config")
local util = require("lib.util")

local stats = {}

local path = util.resource_dir() .. "/data/stats.json"
local records = util.read_json(path) or {}
local dirty = false

local function blank(name)
	return { name = name, elo = config.elo_start, kills = 0, deaths = 0, headshots = 0, damage = 0,
		wins = 0, losses = 0, rounds = 0, matches = 0, best_streak = 0 }
end

function stats.get(player)
	local key = tostring(player.account_id)
	local record = records[key]
	if not record then
		record = blank(player.name)
		records[key] = record
	end
	record.name = player.name
	return record
end

function stats.find(name)
	name = name:lower()
	for _, record in pairs(records) do
		if record.name:lower() == name then return record end
	end
end

function stats.add(player, field, amount)
	local record = stats.get(player)
	record[field] = (record[field] or 0) + (amount or 1)
	dirty = true
	return record
end

function stats.set(player, field, value)
	stats.get(player)[field] = value
	dirty = true
end

function stats.kd(record)
	return record.deaths > 0 and record.kills / record.deaths or record.kills
end

function stats.top(count, field)
	field = field or "elo"
	local list = {}
	for _, record in pairs(records) do list[#list + 1] = record end
	table.sort(list, function(a, b) return (a[field] or 0) > (b[field] or 0) end)
	local out = {}
	for i = 1, math.min(count, #list) do
		local r = list[i]
		out[i] = { rank = i, name = r.name, elo = r.elo, kills = r.kills, deaths = r.deaths, wins = r.wins,
			matches = r.matches, kd = string.format("%.2f", stats.kd(r)) }
	end
	return out
end

-- Elo par equipe : chaque joueur gagne / perd selon la moyenne des deux equipes.
function stats.elo(winners, losers)
	local function average(team)
		local sum = 0
		for _, player in ipairs(team) do sum = sum + stats.get(player).elo end
		return #team > 0 and sum / #team or config.elo_start
	end
	local a, b = average(winners), average(losers)
	local expected = 1 / (1 + 10 ^ ((b - a) / 400))
	local change = math.max(1, math.floor(config.elo_k * (1 - expected) + 0.5))
	for _, player in ipairs(winners) do stats.add(player, "elo", change) end
	for _, player in ipairs(losers) do stats.add(player, "elo", -change) end
	return change
end

function stats.save()
	if not dirty then return end
	local ok, err = util.write_json(path, records)
	if ok then
		dirty = false
	else
		axora.log("stats non enregistrees (" .. tostring(err) .. ") : le dossier data/ existe ?")
	end
end

return stats
