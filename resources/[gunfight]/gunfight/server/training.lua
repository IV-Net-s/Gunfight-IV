-- Entrainement : un joueur seul dans son routing bucket, contre des cibles (peds crees par le serveur,
-- simules par le jeu du joueur). Mode libre (sans fin) ou defi (60 s, record personnel).
local config = require("config")
local util = require("lib.util")
local weapons = require("lib.weapons")
local stats = require("server.stats")

local Training = {}
Training.__index = Training

local function find_level(key)
	for _, level in ipairs(config.training.levels) do
		if level.key == key then return level end
	end
	return config.training.levels[1]
end

function Training.levels()
	local list = {}
	for _, level in ipairs(config.training.levels) do
		list[#list + 1] = { key = level.key, label = level.label, description = level.description }
	end
	return list
end

-- options : { level, challenge, loadout (index, 0 = toutes les armes), arena }
function Training.new(player, options, arena)
	local self = setmetatable({}, Training)
	self.player = player
	self.bucket = config.training.first_bucket + player.id
	self.arena = arena
	self.level = find_level(options.level)
	self.challenge = options.challenge == true
	self.loadout = config.loadouts[tonumber(options.loadout) or -1]
	self.targets = {}   -- id d'entite -> true
	self.respawns = {}  -- { at }
	self.kills, self.headshots, self.deaths = 0, 0, 0
	self.shots, self.hits = 0, 0
	self.started = util.now()
	self.ends = self.challenge and util.now() + config.training.challenge_time * 1000 or nil
	self.refill = 0
	self.push_timer = 0
	self.closed = false
	self.finished = false
	return self
end

function Training:weapons()
	if self.loadout then return self.loadout.weapons end
	local all = {}
	for _, loadout in ipairs(config.loadouts) do
		for _, entry in ipairs(loadout.weapons) do all[#all + 1] = { entry[1], 500 } end
	end
	return all
end

function Training:arm(equip)
	local player = self.player
	for i, entry in ipairs(self:weapons()) do
		player:give_weapon(weapons.id(entry[1]), math.max(entry[2], 200), equip and i == 1) -- recharge : l'arme choisie reste en main
	end
end

function Training:spot()
	local arena = self.arena
	local pool = {}
	for _, spot in ipairs(arena.b or {}) do pool[#pool + 1] = spot end
	if arena.flag then pool[#pool + 1] = arena.flag end
	if #pool == 0 then pool[1] = arena.center end
	local base = pool[math.random(#pool)]
	return base.x + (math.random() - 0.5) * 6, base.y + (math.random() - 0.5) * 6, base.z, math.random() * 360
end

function Training:spawn_target()
	local x, y, z, heading = self:spot()
	local models = config.training.models
	local id = axora.create_ped(models[math.random(#models)], x, y, z, heading)
	if not id then
		axora.log("entrainement : limite d'entites atteinte")
		return
	end
	axora.set_entity_bucket(id, self.bucket)
	axora.set_entity_orphan_mode(id, "keep")
	axora.set_entity_state(id, "gf_target", self.player.id)
	self.targets[id] = true
	return id
end

function Training:client_view()
	local ids = {}
	for id in pairs(self.targets) do ids[#ids + 1] = id end
	local level = self.level
	return { targets = ids, behaviour = level.behaviour, weapon = level.weapon and weapons.id(level.weapon) or 0,
		accuracy = level.accuracy or 0, center = self.arena.center, radius = self.arena.radius }
end

function Training:sync_client()
	axora.emit_client(self.player, "gf_train", self:client_view())
end

function Training:start()
	local player = self.player
	axora.set_bucket_lockdown(self.bucket, "strict")
	axora.set_bucket_population(self.bucket, false)
	player:set_bucket(self.bucket)
	player:set_state("gunfight", { training = true })
	local spot = self.arena.a and self.arena.a[1] or self.arena.center
	player:teleport(spot.x, spot.y, spot.z, spot.heading or 0)
	player:remove_weapons()
	player:set_health(config.health_max)
	player:set_armour(self.loadout and self.loadout.armour or 50)
	player:set_weapon_switching(true)
	self:arm(true)
	for _ = 1, self.level.count do self:spawn_target() end
	axora.emit_client(player, "gf_arena", { name = self.arena.name, center = self.arena.center, radius = self.arena.radius,
		time = self.arena.time or 12, weather = self.arena.weather or 0 })
	self:sync_client()
	axora.ui.show(player)
	axora.ui.send(player, { type = "banner", title = "Entrainement", subtitle = self.level.label .. (self.challenge and " · defi 60 s" or " · libre"),
		color = "#6ed278", ms = 2500 })
	self:push()
end

function Training:accuracy()
	return self.shots > 0 and math.min(1, self.hits / self.shots) or 0
end

function Training:best()
	local record = stats.get(self.player).training or {}
	return record[self.level.key] or 0
end

function Training:push()
	local elapsed = math.floor((util.now() - self.started) / 1000)
	axora.ui.send(self.player, { type = "training", show = true, level = self.level.label, challenge = self.challenge,
		remaining = self.ends and math.max(0, math.ceil((self.ends - util.now()) / 1000)) or nil, elapsed = elapsed,
		kills = self.kills, headshots = self.headshots, deaths = self.deaths, shots = self.shots, hits = self.hits,
		accuracy = math.floor(self:accuracy() * 100 + 0.5), best = self:best(), finished = self.finished,
		loadout = self.loadout and self.loadout.name or "Toutes les armes", arena = self.arena.name })
end

function Training:on_kill(id, headshot)
	if self.finished or not self.targets[id] then return end
	self.targets[id] = nil
	self.kills = self.kills + 1
	if headshot then self.headshots = self.headshots + 1 end
	axora.ui.send(self.player, { type = "hit", headshot = headshot, kill = true })
	self.respawns[#self.respawns + 1] = { at = util.now() + config.training.respawn_delay * 1000, old = id }
	self:push()
end

function Training:on_stats(shots, hits)
	if type(shots) ~= "number" or type(hits) ~= "number" or shots < 0 or hits < 0 or shots > 200 or hits > 200 then return end
	self.shots = self.shots + math.floor(shots)
	self.hits = self.hits + math.floor(hits)
end

function Training:on_spawn()
	local spot = self.arena.a and self.arena.a[1] or self.arena.center
	self.player:teleport(spot.x, spot.y, spot.z, spot.heading or 0)
	self.player:set_health(config.health_max)
	self:arm(true)
	self:sync_client()
end

function Training:on_death()
	self.deaths = self.deaths + 1
	self:push()
end

function Training:finish()
	self.finished = true
	local record = stats.get(self.player).training or {}
	local best = record[self.level.key] or 0
	local improved = self.kills > best
	if improved then
		record[self.level.key] = self.kills
		stats.set(self.player, "training", record)
		stats.save()
	end
	for id in pairs(self.targets) do axora.delete_entity(id) end
	self.targets = {}
	self:sync_client()
	axora.ui.send(self.player, { type = "banner", title = self.kills .. " eliminations",
		subtitle = (improved and "Nouveau record !" or ("Record : " .. best)) .. string.format(" · precision %d %%", math.floor(self:accuracy() * 100 + 0.5)),
		color = improved and "#ffd23f" or "#ffffff", ms = 5000 })
	self:push()
end

function Training:tick(delta)
	if self.closed or not util.valid(self.player) then return end
	local now = util.now()
	if self.ends and not self.finished and now >= self.ends then self:finish() end
	if not self.finished then
		for i = #self.respawns, 1, -1 do
			local entry = self.respawns[i]
			if now >= entry.at then
				table.remove(self.respawns, i)
				axora.delete_entity(entry.old)
				self:spawn_target()
				self:sync_client()
			end
		end
		self.refill = self.refill + delta
		if self.refill >= config.training.refill_every then
			self.refill = 0
			self:arm()
		end
	end
	self.push_timer = self.push_timer + delta
	if self.push_timer >= 1 then
		self.push_timer = 0
		self:push()
	end
end

function Training:close()
	if self.closed then return end
	self.closed = true
	for id in pairs(self.targets) do axora.delete_entity(id) end
	for _, entry in ipairs(self.respawns) do axora.delete_entity(entry.old) end
	self.targets, self.respawns = {}, {}
	local player = self.player
	if not util.valid(player) then return end
	axora.emit_client(player, "gf_train", nil)
	axora.emit_client(player, "gf_arena", nil)
	axora.ui.send(player, { type = "training", show = false })
	player:set_state("gunfight", nil)
	player:remove_weapons()
	player:set_armour(0)
	player:set_health(config.health_max)
	player:set_bucket(config.lobby_bucket)
	player:teleport(config.lobby.x, config.lobby.y, config.lobby.z, config.lobby.heading)
end

return Training
