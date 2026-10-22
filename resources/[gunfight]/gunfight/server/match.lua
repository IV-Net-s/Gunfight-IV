-- Un match de gunfight : deux equipes dans leur propre routing bucket, manches courtes sans reapparition.
-- Phases : countdown (figes) -> live -> overtime (drapeau) -> round_end -> ... -> results.
local config = require("config")
local util = require("lib.util")
local weapons = require("lib.weapons")
local arenas = require("server.arenas")
local stats = require("server.stats")

local Match = {}
Match.__index = Match

local function health_ratio(player)
	local ok, health = pcall(function() return player.health end)
	if not ok then return 0 end
	local span = config.health_max - config.health_dead
	return math.max(0, math.min(1, (health - config.health_dead) / span))
end

function Match.new(id, mode, sides, arena)
	local self = setmetatable({}, Match)
	self.id = id
	self.mode = mode
	self.bucket = config.first_bucket + id
	self.arena = arena
	self.teams = {}
	self.members = {}
	self.round = 0
	self.phase = "starting"
	self.ends = 0
	self.started = util.now()
	self.loadout = nil
	self.flag = { active = false, team = nil, progress = 0 }
	self.covers = {}
	self.feed = {}
	self.closed = false
	for t = 1, 2 do
		self.teams[t] = { index = t, name = config.teams[t].name, color = config.teams[t].color, score = 0, ids = {} }
		for slot, player in ipairs(sides[t]) do
			self.teams[t].ids[#self.teams[t].ids + 1] = player.id
			self.members[player.id] = { player = player, team = t, slot = slot, alive = false, kills = 0, deaths = 0,
				damage = 0, headshots = 0, streak = 0, model = player.model, out_since = nil, out_damage = 0 }
		end
	end
	return self
end

function Match:each(fn)
	for id, member in pairs(self.members) do
		if util.valid(member.player) then fn(member, id) end
	end
end

function Match:member(player)
	local member = player and self.members[player.id]
	if member and member.player == player then return member end
end

function Match:send(data, team)
	self:each(function(member)
		if not team or member.team == team then axora.ui.send(member.player, data) end
	end)
end

function Match:banner(title, subtitle, color, ms)
	self:send({ type = "banner", title = title, subtitle = subtitle or "", color = color or "#ffffff", ms = ms or 2500 })
end

function Match:emit(event, ...)
	local args = { ... }
	self:each(function(member) axora.emit_client(member.player, event, table.unpack(args)) end)
end

function Match:remaining()
	return math.max(0, math.ceil((self.ends - util.now()) / 1000))
end

-- Vue du HUD pour un membre.
function Match:snapshot(viewer)
	local teams = {}
	for t, team in ipairs(self.teams) do
		local players = {}
		for _, id in ipairs(team.ids) do
			local member = self.members[id]
			if member and util.valid(member.player) then
				players[#players + 1] = { id = id, name = member.player.name, hp = member.alive and health_ratio(member.player) or 0,
					alive = member.alive, kills = member.kills }
			end
		end
		teams[t] = { name = team.name, color = team.color, score = team.score, players = players }
	end
	return { type = "match", show = true, id = self.id, mode = self.mode, arena = self.arena.name, round = self.round,
		rounds_to_win = config.rounds_to_win, phase = self.phase, remaining = self:remaining(),
		loadout = self.loadout and self.loadout.name or "", flag = self.flag.active and self.flag or nil,
		teams = teams, you = viewer and { id = viewer.player.id, team = viewer.team } or nil }
end

function Match:push()
	self:each(function(member) axora.ui.send(member.player, self:snapshot(member)) end)
end

function Match:board(member)
	local rows = {}
	self:each(function(m)
		rows[#rows + 1] = { team = m.team, name = m.player.name, kills = m.kills, deaths = m.deaths, damage = math.floor(m.damage),
			headshots = m.headshots, ping = m.player.ping, alive = m.alive, elo = stats.get(m.player).elo }
	end)
	table.sort(rows, function(a, b) return a.team == b.team and a.kills > b.kills or a.team < b.team end)
	return { type = "board", show = true, rows = rows, teams = { self.teams[1].name, self.teams[2].name },
		colors = { self.teams[1].color, self.teams[2].color } }
end

function Match:start()
	axora.set_bucket_lockdown(self.bucket, "strict")
	axora.set_bucket_population(self.bucket, false)
	for _, cover in ipairs(self.arena.cover or {}) do
		local entity = axora.create_vehicle(cover.model, cover.x, cover.y, cover.z, cover.heading or 0)
		if entity then
			axora.set_entity_bucket(entity, self.bucket)
			axora.freeze_entity(entity, true)
			axora.set_entity_state(entity, "gf_cover", self.id)
			self.covers[#self.covers + 1] = entity
		end
	end
	self:each(function(member)
		local player = member.player
		player:set_bucket(self.bucket)
		player:set_model(config.teams[member.team].model)
		player:set_state("gunfight", { match = self.id, team = member.team, color = config.teams[member.team].color })
		axora.emit_client(player, "gf_arena", { name = self.arena.name, center = self.arena.center, radius = self.arena.radius,
			time = self.arena.time or 12, weather = self.arena.weather or 0 })
		axora.ui.show(player)
	end)
	local names = {}
	for t = 1, 2 do
		local list = {}
		for _, id in ipairs(self.teams[t].ids) do list[#list + 1] = self.members[id].player.name end
		names[t] = table.concat(list, ", ")
	end
	axora.log(string.format("match %d (%s, %s) : %s contre %s", self.id, self.mode, self.arena.name, names[1], names[2]))
	self:start_round()
end

function Match:give_loadout(member)
	local player = member.player
	player:remove_weapons()
	for i, entry in ipairs(self.loadout.weapons) do
		player:give_weapon(weapons.id(entry[1]), entry[2], i == 1)
	end
	player:set_health(config.health_max)
	player:set_armour(self.loadout.armour or 0)
	player:set_weapon_switching(config.weapon_switching)
end

function Match:place(member)
	local side = member.team == 1 and "a" or "b"
	local spot = arenas.spawn(self.arena, side, member.slot)
	member.player:teleport(spot.x, spot.y, spot.z, spot.heading)
end

function Match:prepare(member)
	member.alive = true
	member.out_since = nil
	member.streak = 0
	self:place(member)
	self:give_loadout(member)
	axora.emit_client(member.player, "gf_freeze", self.phase == "countdown")
	axora.emit_client(member.player, "gf_spectate", false)
end

function Match:start_round()
	self.round = self.round + 1
	if not self.loadout or (self.round - 1) % config.loadout_rounds == 0 then
		self.loadout = config.loadouts[math.random(#config.loadouts)]
	end
	self.phase = "countdown"
	self.ends = util.now() + (self.round == 1 and config.first_countdown or config.countdown) * 1000
	self.flag = { active = false, team = nil, progress = 0 }
	self:emit("gf_flag", nil)
	self:each(function(member) self:prepare(member) end)
	self:banner("Manche " .. self.round, self.loadout.name, "#ffffff", 3000)
	self:push()
end

function Match:go_live()
	self.phase = "live"
	self.live_at = util.now()
	self.ends = util.now() + config.round_time * 1000
	self:emit("gf_freeze", false)
	self:banner("GO", nil, "#6ed278", 1200)
	self:push()
end

function Match:go_overtime()
	self.phase = "overtime"
	self.ends = util.now() + config.overtime * 1000
	self.flag = { active = true, team = nil, progress = 0, x = self.arena.flag.x, y = self.arena.flag.y, z = self.arena.flag.z }
	self:emit("gf_flag", { x = self.flag.x, y = self.flag.y, z = self.flag.z, radius = config.capture_radius })
	self:banner("Prolongation", "Prends le drapeau au centre", "#ffd23f", 2500)
	self:push()
end

function Match:alive_count(team)
	local count = 0
	for _, id in ipairs(self.teams[team].ids) do
		local member = self.members[id]
		if member and member.alive and util.valid(member.player) then count = count + 1 end
	end
	return count
end

function Match:team_health(team)
	local sum = 0
	for _, id in ipairs(self.teams[team].ids) do
		local member = self.members[id]
		if member and member.alive and util.valid(member.player) then sum = sum + health_ratio(member.player) end
	end
	return sum
end

function Match:end_round(winner, reason)
	if self.phase == "round_end" or self.phase == "results" then return end
	self.phase = "round_end"
	self.ends = util.now() + config.round_end * 1000
	self.flag.active = false
	self:emit("gf_flag", nil)
	self:each(function(member) stats.add(member.player, "rounds") end)
	if winner then
		self.teams[winner].score = self.teams[winner].score + 1
		self:banner(self.teams[winner].name .. " gagne la manche", reason, self.teams[winner].color, 3000)
	else
		self:banner("Egalite", reason, "#cccccc", 3000)
	end
	self:push()
end

function Match:check_wipe()
	local a, b = self:alive_count(1), self:alive_count(2)
	if a == 0 and b == 0 then
		self:end_round(nil, "tout le monde est tombe")
	elseif a == 0 then
		self:end_round(2, "equipe adverse eliminee")
	elseif b == 0 then
		self:end_round(1, "equipe adverse eliminee")
	end
end

function Match:update_flag(delta)
	local present = { 0, 0 }
	for _, member in pairs(self.members) do
		if member.alive and util.valid(member.player) then
			local x, y, z = member.player:position()
			if util.distance(self.flag, x, y, z) <= config.capture_radius then
				present[member.team] = present[member.team] + 1
			end
		end
	end
	local team = present[1] > 0 and present[2] == 0 and 1 or present[2] > 0 and present[1] == 0 and 2 or nil
	if team then
		if self.flag.team ~= team then
			self.flag.team = team
			self.flag.progress = 0
		end
		self.flag.progress = self.flag.progress + delta
		if self.flag.progress >= config.capture_time then
			self:end_round(team, "drapeau capture")
		end
	elseif present[1] == 0 and present[2] == 0 then
		self.flag.progress = math.max(0, self.flag.progress - delta)
	end
	self.flag.ratio = math.min(1, self.flag.progress / config.capture_time)
	self.flag.contested = present[1] > 0 and present[2] > 0
end

function Match:update_bounds(delta)
	local center, radius = self.arena.center, self.arena.radius
	for _, member in pairs(self.members) do
		if member.alive and util.valid(member.player) then
			local x, y = member.player:position()
			local dx, dy = x - center.x, y - center.y
			if dx * dx + dy * dy > radius * radius then
				if not member.out_since then
					member.out_since = util.now()
					member.out_damage = 0
					axora.ui.send(member.player, { type = "warning", text = "Retourne dans l'arene !", ms = config.out_of_bounds_grace * 1000 })
				elseif util.now() - member.out_since >= config.out_of_bounds_grace * 1000 then
					member.out_damage = member.out_damage + config.out_of_bounds_damage * delta
					if member.out_damage >= 5 then
						member.player:damage(member.out_damage)
						member.out_damage = 0
					end
				end
			elseif member.out_since then
				member.out_since = nil
				axora.ui.send(member.player, { type = "warning", text = "", ms = 0 })
			end
		end
	end
end

function Match:tick(delta)
	if self.closed then return end
	local now = util.now()
	if self.wipe_check then
		self.wipe_check = false
		if self.phase == "live" or self.phase == "overtime" then self:check_wipe() end
	end
	if self.phase == "countdown" then
		if now >= self.ends then self:go_live() end
	elseif self.phase == "live" then
		self:update_bounds(delta)
		if now >= self.ends then self:go_overtime() end
	elseif self.phase == "overtime" then
		self:update_bounds(delta)
		self:update_flag(delta)
		if self.phase == "overtime" and now >= self.ends then
			local a, b = self:team_health(1), self:team_health(2)
			if math.abs(a - b) < 0.01 then
				self:end_round(nil, "temps ecoule, meme sante")
			else
				self:end_round(a > b and 1 or 2, "temps ecoule : plus de sante")
			end
		end
	elseif self.phase == "round_end" then
		if now >= self.ends then
			local done = self.teams[1].score >= config.rounds_to_win or self.teams[2].score >= config.rounds_to_win
			if done then self:finish() else self:start_round() end
		end
	elseif self.phase == "results" then
		if now >= self.ends then self:close() end
	end
	self.push_timer = (self.push_timer or 0) + delta
	if self.push_timer >= 0.5 then
		self.push_timer = 0
		self:push()
	end
end

-- "weapon_damage" : false annule la touche, un nombre la remplace.
function Match:on_damage(attacker, victim, damage, weapon, bone)
	local a, v = self:member(attacker), self:member(victim)
	if not v then return false end
	if self.phase ~= "live" and self.phase ~= "overtime" then return false end
	if not v.alive then return false end
	if a and a ~= v and a.team == v.team and not config.friendly_fire then return false end
	damage = damage * config.damage_scale
	if a and a ~= v then
		a.damage = a.damage + damage
		stats.add(a.player, "damage", math.floor(damage))
		axora.ui.send(a.player, { type = "hit", headshot = bone == 1205 })
	end
	axora.ui.send(v.player, { type = "hurt", amount = damage })
	return damage
end

function Match:on_death(player)
	local member = self:member(player)
	if not member or not member.alive then return end
	member.alive = false
	member.deaths = member.deaths + 1
	member.out_since = nil
	stats.add(player, "deaths")
	self.wipe_check = true
	self:push()
end

function Match:on_killed(victim, killer, weapon, headshot)
	local v = self:member(victim)
	if not v then return end
	local k = self:member(killer)
	local entry = { type = "kill", victim = victim.name, victim_color = config.teams[v.team].color,
		weapon = weapon >= 0 and weapons.name(weapon) or "", headshot = headshot }
	if k and k ~= v then
		k.kills = k.kills + 1
		k.streak = k.streak + 1
		if headshot then k.headshots = k.headshots + 1 end
		stats.add(k.player, "kills")
		if headshot then stats.add(k.player, "headshots") end
		local record = stats.get(k.player)
		if k.streak > (record.best_streak or 0) then stats.set(k.player, "best_streak", k.streak) end
		entry.killer = killer.name
		entry.killer_color = config.teams[k.team].color
		axora.ui.send(k.player, { type = "hit", headshot = headshot, kill = true })
	end
	self:send(entry)
end

function Match:on_spawn(player)
	local member = self:member(player)
	if not member then return end
	local late = self.phase == "live" and self.live_at and util.now() - self.live_at < 5000 and member.alive
	if self.phase == "countdown" or late then
		self:prepare(member)
	else
		local spot = self.arena.spectate
		member.alive = false
		player:remove_weapons()
		player:teleport(spot.x, spot.y, spot.z, spot.heading or 0)
		axora.emit_client(player, "gf_spectate", true)
	end
end

function Match:on_leave(player)
	local member = self.members[player.id]
	if not member or member.player ~= player then return end
	self.members[player.id] = nil
	for _, team in ipairs(self.teams) do
		for i, id in ipairs(team.ids) do
			if id == player.id then table.remove(team.ids, i) break end
		end
	end
	stats.add(player, "losses")
	stats.add(player, "elo", -config.elo_k)
	self:send({ type = "feed", text = player.name .. " a quitte le match" })
	for t = 1, 2 do
		if #self.teams[t].ids == 0 and self.phase ~= "results" then
			self.teams[3 - t].score = config.rounds_to_win
			self:finish("forfait de " .. self.teams[t].name)
			return
		end
	end
	self.wipe_check = true
end

function Match:finish(reason)
	if self.phase == "results" then return end
	self.phase = "results"
	self.ends = util.now() + config.results_time * 1000
	self:emit("gf_flag", nil)
	self:emit("gf_freeze", true)
	local winner = self.teams[1].score > self.teams[2].score and 1 or self.teams[2].score > self.teams[1].score and 2 or nil
	local sides = { {}, {} }
	self:each(function(member) table.insert(sides[member.team], member.player) end)
	local change = 0
	if winner then
		change = stats.elo(sides[winner], sides[3 - winner])
		for _, player in ipairs(sides[winner]) do stats.add(player, "wins") end
		for _, player in ipairs(sides[3 - winner]) do stats.add(player, "losses") end
	end
	local mvp, best = nil, -1
	local rows = {}
	self:each(function(member)
		stats.add(member.player, "matches")
		local score = member.kills * 100 + member.damage
		if score > best then best, mvp = score, member end
		local delta = winner and (member.team == winner and change or -change) or 0
		rows[#rows + 1] = { name = member.player.name, team = member.team, kills = member.kills, deaths = member.deaths,
			damage = math.floor(member.damage), headshots = member.headshots, elo = stats.get(member.player).elo, elo_change = delta }
	end)
	stats.save()
	self:send({ type = "results", winner = winner and self.teams[winner].name or nil, color = winner and self.teams[winner].color or "#cccccc",
		score = { self.teams[1].score, self.teams[2].score }, teams = { self.teams[1].name, self.teams[2].name },
		mvp = mvp and mvp.player.name or nil, reason = reason or "", rows = rows, ms = config.results_time * 1000 })
	axora.log(string.format("match %d termine : %d - %d", self.id, self.teams[1].score, self.teams[2].score))
end

function Match:release(member)
	local player = member.player
	if not util.valid(player) then return end
	player:set_state("gunfight", nil)
	player:set_weapon_switching(true)
	player:remove_weapons()
	player:set_armour(0)
	player:set_health(config.health_max)
	if member.model then player:set_model(member.model) end
	player:set_bucket(config.lobby_bucket)
	player:teleport(config.lobby.x, config.lobby.y, config.lobby.z, config.lobby.heading)
	axora.emit_client(player, "gf_arena", nil)
	axora.emit_client(player, "gf_freeze", false)
	axora.emit_client(player, "gf_spectate", false)
	axora.ui.send(player, { type = "match", show = false })
end

function Match:close()
	if self.closed then return end
	self.closed = true
	self:each(function(member) self:release(member) end)
	for _, entity in ipairs(self.covers) do axora.delete_entity(entity) end
	self.covers = {}
end

return Match
