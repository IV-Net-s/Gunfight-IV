-- Gunfight : lobby, files d'attente, matchs paralleles (un routing bucket chacun), stats persistantes.
-- Les degats entre joueurs passent par le serveur (evenement "weapon_damage") : equipe, phase de la manche,
-- marqueurs de touche et tueur ("player_killed") sont decides ici.
math.randomseed(os.time())

local config = require("config")
local util = require("lib.util")
local weapons = require("lib.weapons")
local arenas = require("server.arenas")
local stats = require("server.stats")
local queue = require("server.queue")
local Match = require("server.match")
local Training = require("server.training")

axora.set_game_mode("gunfight")
axora.world.set_spawn(config.lobby.x, config.lobby.y, config.lobby.z, config.lobby.heading)
for _, key in ipairs({ "peds", "scenario", "traffic", "parked", "wanted", "cops", "planes", "boats", "mad_drivers" }) do
	axora.world.set(key, 0)
end
axora.log(arenas.load() .. " arene(s), " .. #config.loadouts .. " loadouts")

local matches = {}     -- id -> Match
local playing = {}     -- player id -> Match
local next_match = 1
local rejected = {}    -- player id -> { count, since } (anti-triche)
local trainings = {}   -- player id -> Training

local function training_of(player)
	local session = player and trainings[player.id]
	if session and session.player == player then return session end
end

local function stop_training(player)
	local session = training_of(player)
	if not session then return false end
	session:close()
	trainings[player.id] = nil
	return true
end

local function match_of(player)
	local match = player and playing[player.id]
	if match and match:member(player) then return match end
end

local function publish()
	local list = {}
	for id, match in pairs(matches) do
		list[#list + 1] = { id = id, mode = match.mode, arena = match.arena.name, round = match.round, phase = match.phase,
			score = { match.teams[1].score, match.teams[2].score } }
	end
	axora.set_global_state("gunfight", { matches = list, queues = queue.counts() })
end

local function start_match(ready)
	local id = next_match
	next_match = next_match + 1
	local match = Match.new(id, ready.mode, ready.sides, arenas.random())
	matches[id] = match
	for _, side in ipairs(ready.sides) do
		for _, player in ipairs(side) do
			stop_training(player) -- on peut s'entrainer en attendant son match
			playing[player.id] = match
			player:set_state("gf_menu", nil)
			axora.ui.hide(player)
		end
	end
	match:start()
	publish()
end

local function close_match(match)
	match:close()
	for id, m in pairs(playing) do
		if m == match then playing[id] = nil end
	end
	matches[match.id] = nil
	publish()
end

-- Menu du lobby (NUI) ---------------------------------------------------------------------------

local function training_view(player)
	local loadouts = {}
	for i, loadout in ipairs(config.loadouts) do loadouts[#loadouts + 1] = { index = i, name = loadout.name } end
	local names = {}
	for _, arena in ipairs(arenas.all()) do names[#names + 1] = arena.name end
	local session = training_of(player)
	return { levels = Training.levels(), loadouts = loadouts, arenas = names, records = stats.get(player).training or {},
		active = session ~= nil, challenge_time = config.training.challenge_time }
end

local function lobby_view(player)
	local record = stats.get(player)
	local live = {}
	for id, match in pairs(matches) do
		live[#live + 1] = { id = id, mode = match.mode, arena = match.arena.name, round = match.round,
			score = { match.teams[1].score, match.teams[2].score }, teams = { match.teams[1].name, match.teams[2].name } }
	end
	return { type = "lobby", open = true, player = player.name, queued = queue.mode_of(player), queues = queue.counts(),
		matches = live, stats = { elo = record.elo, kills = record.kills, deaths = record.deaths, wins = record.wins,
			losses = record.losses, headshots = record.headshots, kd = string.format("%.2f", stats.kd(record)),
			best_streak = record.best_streak or 0 }, top = stats.top(10), training = training_view(player) }
end

local function open_lobby(player)
	if match_of(player) then return axora.reply(player, "Tu es en match.") end
	player:set_state("gf_menu", true)
	axora.ui.focus(player)
	axora.ui.send(player, lobby_view(player))
end

local function refresh_lobbies()
	for _, player in ipairs(axora.players()) do
		if not match_of(player) and player:state("gf_menu") then axora.ui.send(player, lobby_view(player)) end
	end
end

local function start_training(player, options)
	if match_of(player) then return false, "Pas pendant un match." end
	stop_training(player)
	local arena = arenas.find(options.arena or "") or arenas.random()
	local session = Training.new(player, options, arena)
	trainings[player.id] = session
	player:set_state("gf_menu", nil)
	axora.ui.hide(player)
	session:start()
	return true, "Entrainement : " .. session.level.label .. " sur " .. arena.name
end

local function join_queue(player, mode)
	mode = mode or config.default_mode
	if match_of(player) then return false, "Tu es deja en match." end
	if not config.modes[mode] then return false, "Mode inconnu : 1v1, 2v2, 3v3 ou 4v4." end
	queue.join(player, mode)
	local count = queue.counts()[mode]
	publish()
	refresh_lobbies()
	return true, string.format("File %s : %d/%d", mode, count.queued, count.needed)
end

axora.ui.on("open", function(player)
	player:set_state("gf_menu", true)
	return lobby_view(player)
end)

axora.ui.on("queue", function(player, data)
	local ok, message = join_queue(player, data and data.mode)
	return { ok = ok, message = message, view = lobby_view(player) }
end)

axora.ui.on("leave_queue", function(player)
	queue.leave(player)
	publish()
	refresh_lobbies()
	return { ok = true, message = "Tu as quitte la file.", view = lobby_view(player) }
end)

axora.ui.on("train", function(player, data)
	data = type(data) == "table" and data or {}
	local ok, message = start_training(player, { level = data.level, challenge = data.challenge == true,
		loadout = tonumber(data.loadout), arena = data.arena })
	return { ok = ok, message = message, view = not ok and lobby_view(player) or nil }
end)

axora.ui.on("train_stop", function(player)
	stop_training(player)
	return { ok = true, message = "Entrainement termine.", view = lobby_view(player) }
end)

axora.ui.on("close", function(player)
	player:set_state("gf_menu", nil)
	if match_of(player) or training_of(player) then
		axora.ui.focus(player, false)
		axora.ui.show(player)
	else
		axora.ui.hide(player)
	end
	return true
end)

-- Evenements des joueurs ------------------------------------------------------------------------

axora.on("player_join", function(player)
	local record = stats.get(player)
	player:send_message(string.format("Gunfight : /gf (menu), /queue <1v1|2v2|3v3|4v4>, /train (entrainement), /leave, /stats, /top. Ton Elo : %d", record.elo))
	player:set_bucket(config.lobby_bucket)
	publish()
end)

axora.on("player_leave", function(player)
	queue.leave(player)
	rejected[player.id] = nil
	stop_training(player)
	local match = match_of(player)
	if match then
		match:on_leave(player)
		playing[player.id] = nil
	end
	stats.save()
	publish()
end)

axora.on("weapon_damage", function(attacker, victim, damage, weapon, bone)
	local match = match_of(victim)
	if not match then return false end -- pas de degats dans le lobby
	if match_of(attacker) ~= match then return false end
	return match:on_damage(attacker, victim, damage, weapon, bone)
end)

axora.on("player_death", function(player)
	local match = match_of(player)
	if match then match:on_death(player) end
	local session = training_of(player)
	if session then session:on_death() end
end)

axora.on("player_killed", function(victim, killer, weapon, headshot)
	local match = match_of(victim)
	if match then match:on_killed(victim, killer, weapon, headshot) end
end)

axora.on("player_spawn", function(player)
	local match = match_of(player)
	if match then
		match:on_spawn(player)
	elseif training_of(player) then
		training_of(player):on_spawn()
	else
		player:remove_weapons()
	end
end)

axora.on("tick", function(delta)
	util.advance(delta)
	for _, match in pairs(matches) do
		match:tick(delta)
		if match.closed then close_match(match) end
	end
	for id, session in pairs(trainings) do
		if session.closed or not util.valid(session.player) then
			trainings[id] = nil
		else
			session:tick(delta)
		end
	end
	local ready = queue.take()
	if ready then start_match(ready) end
end)

-- Entrainement : le jeu du joueur simule ses cibles et signale les eliminations (client/main.lua).
axora.add_event("gf_train_kill")
axora.on_event("gf_train_kill", function(player, id, headshot)
	local session = training_of(player)
	if session and type(id) == "number" then session:on_kill(id, headshot == true) end
end)

axora.add_event("gf_train_stats")
axora.on_event("gf_train_stats", function(player, shots, hits)
	local session = training_of(player)
	if session then session:on_stats(shots, hits) end
end)

-- Tableau des scores : Tab dans le jeu (client/main.lua).
axora.add_event("gf_board")
axora.on_event("gf_board", function(player, show)
	local match = match_of(player)
	if not match then return end
	if show == true then
		axora.ui.send(player, match:board(match:member(player)))
	else
		axora.ui.send(player, { type = "board", show = false })
	end
end)

-- Anti-triche : les touches refusees par le serveur (portee, hors perimetre, cadence) s'accumulent.
axora.set_interval(10000, function()
	for _, player in ipairs(axora.players()) do
		local now = player.rejected_hits
		local last = rejected[player.id] or now
		rejected[player.id] = now
		if now - last > config.max_rejected_hits then
			axora.log(string.format("%s expulse : %d touches refusees en 10 s", player.name, now - last))
			player:kick("Touches invalides (anti-triche gunfight)")
		end
	end
	stats.save()
end)

-- Commandes -------------------------------------------------------------------------------------

axora.command("gf", function(player)
	if not player then return axora.reply(nil, "joueurs seulement") end
	open_lobby(player)
end)

axora.command("queue", function(player, args)
	if not player then return axora.reply(nil, "joueurs seulement") end
	local _, message = join_queue(player, args[1])
	axora.reply(player, message)
end)

-- /train [facile|normal|difficile|extreme] [defi] ; /train stop
axora.command("train", function(player, args)
	if not player then return axora.reply(nil, "joueurs seulement") end
	if args[1] == "stop" then
		return axora.reply(player, stop_training(player) and "Entrainement termine." or "Tu ne t'entraines pas.")
	end
	local _, message = start_training(player, { level = args[1] or "facile", challenge = args[2] == "defi" })
	axora.reply(player, message)
end)

axora.command("leave", function(player)
	if not player then return end
	if match_of(player) then return axora.reply(player, "Pas pendant un match.") end
	queue.leave(player)
	publish()
	axora.reply(player, "Tu as quitte la file.")
end)

axora.command("stats", function(player, args)
	local record
	if args[1] then
		local target = axora.find_player(args[1])
		record = target and stats.get(target) or stats.find(args[1])
	elseif player then
		record = stats.get(player)
	end
	if not record then return axora.reply(player, "Joueur inconnu.") end
	axora.reply(player, string.format("%s : Elo %d, %d kills / %d morts (K/D %.2f), %d headshots, %d victoires / %d defaites, serie max %d",
		record.name, record.elo, record.kills, record.deaths, stats.kd(record), record.headshots, record.wins, record.losses, record.best_streak or 0))
end)

axora.command("top", function(player)
	for _, row in ipairs(stats.top(10)) do
		axora.reply(player, string.format("%2d. %-20s Elo %d  K/D %s  %d victoires", row.rank, row.name, row.elo, row.kd, row.wins))
	end
end)

axora.command("matches", function(player)
	local any = false
	for id, match in pairs(matches) do
		any = true
		axora.reply(player, string.format("#%d %s sur %s, manche %d, %d - %d (%s)", id, match.mode, match.arena.name, match.round,
			match.teams[1].score, match.teams[2].score, match.phase))
	end
	if not any then axora.reply(player, "Aucun match en cours.") end
end)

-- Admins (ACE) : group.gunfight.admin a les commandes gf_*, la console du serveur aussi.
axora.add_ace("group.gunfight.admin", "command.gf_force", true)
axora.add_ace("group.gunfight.admin", "command.gf_end", true)
axora.add_ace("group.gunfight.admin", "command.gf_arena", true)
axora.add_ace("group.gunfight.admin", "command.gf_give", true)
for account in pairs(config.admins) do
	axora.add_principal("identifier.account:" .. account, "group.gunfight.admin")
end

axora.command("gf_force", function(player, args)
	local ready = queue.force(args[1] or config.default_mode)
	if not ready then return axora.reply(player, "Il faut au moins 2 joueurs dans cette file.") end
	start_match(ready)
	axora.reply(player, "Match lance.")
end, true)

axora.command("gf_end", function(player, args)
	local match = matches[tonumber(args[1] or "")]
	if not match then return axora.reply(player, "Usage : gf_end <id> (voir /matches)") end
	match:finish("arrete par un admin")
	axora.reply(player, "Match " .. match.id .. " termine.")
end, true)

-- /gf_arena <nom> <a|b|flag|spectate|center|radius|cover:<modele>> [reset] : enregistre ta position.
axora.command("gf_arena", function(player, args)
	if not player then return axora.reply(nil, "joueurs seulement") end
	if not args[1] then
		local names = {}
		for _, arena in ipairs(arenas.all()) do names[#names + 1] = arena.name end
		return axora.reply(player, "Arenes : " .. table.concat(names, ", ") .. ". Usage : /gf_arena <nom> <point> [reset]")
	end
	local x, y, z = player:position()
	local arena, problem = arenas.record(args[1], args[2] or "center", x, y, z, player.heading, args[3] == "reset")
	if not arena then return axora.reply(player, problem) end
	axora.reply(player, string.format("%s : %s = %.2f %.2f %.2f%s", arena.name, args[2] or "center", x, y, z, problem and (" (" .. problem .. ")") or ""))
end, true)

axora.command("gf_give", function(player, args)
	local target = player
	if args[2] then target = axora.find_player(args[2]) end
	local weapon = weapons.id(args[1] or "")
	if not target or not weapon then return axora.reply(player, "Usage : gf_give <arme> [joueur]") end
	target:give_weapon(weapon, 500, true)
end, true)

axora.on("stop", function()
	for _, match in pairs(matches) do match:close() end
	for _, session in pairs(trainings) do session:close() end
	stats.save()
end)

publish()
