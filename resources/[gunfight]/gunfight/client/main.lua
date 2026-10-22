-- Cote joueur du gunfight : decompte (fige), spectateur, heure et meteo de l'arene, drapeau, Tab.
-- Les degats, la visee et les tirs des autres joueurs sont synchronises par le client Axora lui-meme.
local arena, flag = nil, nil
local frozen, spectating = false, false
local board = false
local time_set = 0

local function my_ped()
	return GET_PLAYER_CHAR(GET_PLAYER_ID())
end

local function protect()
	local ped = my_ped()
	if not DOES_CHAR_EXIST(ped) then return end
	local locked = frozen or spectating
	FREEZE_CHAR_POSITION(ped, locked)
	SET_PLAYER_INVINCIBLE(GET_PLAYER_ID(), locked)
end

axora.add_event("gf_arena")
axora.on_event("gf_arena", function(data)
	arena = data
	flag = nil
	if arena then
		SET_TIME_OF_DAY(arena.time or 12, 0)
		FORCE_WEATHER_NOW(arena.weather or 0)
		DISPLAY_RADAR(false) -- les points des adversaires donneraient leur position
	else
		RELEASE_WEATHER()
		DISPLAY_RADAR(true)
		frozen, spectating = false, false
		protect()
	end
end)

axora.add_event("gf_freeze")
axora.on_event("gf_freeze", function(value)
	frozen = value == true
	protect()
end)

axora.add_event("gf_spectate")
axora.on_event("gf_spectate", function(value)
	spectating = value == true
	protect()
end)

axora.add_event("gf_flag")
axora.on_event("gf_flag", function(data)
	flag = data
end)

axora.on_event("player_spawn", protect)

axora.on_event("stop", function()
	if arena then
		RELEASE_WEATHER()
		DISPLAY_RADAR(true)
	end
	frozen, spectating = false, false
	protect()
end)

-- Entrainement : le jeu du joueur simule ses cibles (il en est le proprietaire) ------------------
local training = nil    -- { targets, behaviour, weapon, accuracy, center, radius }
local targets = {}      -- id reseau -> { ped, health, reported, next_move, armed, blip }
local shots, hits = 0, 0
local last_weapon, last_ammo = 0, 0
local head_bone = 1205

local function release_target(target)
	if target.blip then REMOVE_BLIP(target.blip) end
end

axora.add_event("gf_train")
axora.on_event("gf_train", function(data)
	training = data
	local wanted = {}
	for _, id in ipairs(data and data.targets or {}) do wanted[id] = true end
	for id, target in pairs(targets) do
		if not wanted[id] then
			release_target(target)
			targets[id] = nil
		end
	end
	for id in pairs(wanted) do
		targets[id] = targets[id] or { reported = false, next_move = 0 }
	end
	if not data then shots, hits = 0, 0 end
end)

local function random_point()
	local angle = math.random() * math.pi * 2
	local distance = math.random() * (training.radius or 30) * 0.6
	return training.center.x + math.cos(angle) * distance, training.center.y + math.sin(angle) * distance, training.center.z
end

local function setup_target(target, ped, me)
	target.ped = ped
	target.health = GET_CHAR_HEALTH(ped)
	SET_BLOCKING_OF_NON_TEMPORARY_EVENTS(ped, true) -- ni fuite ni panique
	SET_CHAR_KEEP_TASK(ped, true)
	target.blip = ADD_BLIP_FOR_CHAR(ped)
	if target.blip then CHANGE_BLIP_COLOUR(target.blip, 1) end
	if training.behaviour == "armed" and training.weapon > 0 then
		GIVE_WEAPON_TO_CHAR(ped, training.weapon, 9999, false)
		SET_CHAR_ACCURACY(ped, training.accuracy or 30)
		SET_CHAR_WILL_USE_COVER(ped, true)
		TASK_COMBAT(ped, me)
		target.armed = true
	end
end

local function update_targets(me)
	local now = axora.time()
	for id, target in pairs(targets) do
		local ped = axora.net_to_entity(id)
		if ped and DOES_CHAR_EXIST(ped) and axora.is_entity_owner(id) then
			if target.ped ~= ped then setup_target(target, ped, me) end
			local health = GET_CHAR_HEALTH(ped)
			if health < target.health and HAS_CHAR_BEEN_DAMAGED_BY_CHAR(ped, me, false) then
				hits = hits + 1
				CLEAR_CHAR_LAST_WEAPON_DAMAGE(ped)
			end
			target.health = health
			if IS_CHAR_DEAD(ped) then
				if not target.reported then
					target.reported = true
					local bone = GET_CHAR_LAST_DAMAGE_BONE(ped)
					axora.emit_server("gf_train_kill", id, bone == head_bone)
					release_target(target)
					target.blip = nil
				end
			elseif training.behaviour == "moving" and now >= target.next_move then
				local x, y, z = random_point()
				TASK_GO_STRAIGHT_TO_COORD(ped, x, y, z, 3, 45000) -- 3 : course
				target.next_move = now + 2500 + math.random(2500)
			end
		end
	end
end

local function count_shots(me)
	local weapon = GET_CURRENT_CHAR_WEAPON(me)
	local ammo = weapon ~= 0 and GET_AMMO_IN_CHAR_WEAPON(me, weapon) or 0
	if weapon == last_weapon and ammo < last_ammo and last_ammo - ammo <= 10 then shots = shots + (last_ammo - ammo) end
	last_weapon, last_ammo = weapon, ammo
end

axora.thread(function()
	while true do
		if training then
			local me = my_ped()
			if DOES_CHAR_EXIST(me) then
				update_targets(me)
				count_shots(me)
			end
		end
		axora.wait(0)
	end
end)

axora.set_interval(1000, function()
	if training and (shots > 0 or hits > 0) then
		axora.emit_server("gf_train_stats", shots, hits)
		shots, hits = 0, 0
	end
end)

axora.thread(function()
	while true do
		if arena then
			if flag then
				DRAW_CHECKPOINT(flag.x, flag.y, flag.z - 1.0, flag.radius or 3.0, 255, 210, 63)
			end
			local now = axora.time()
			if now - time_set > 5000 then
				time_set = now
				SET_TIME_OF_DAY(arena.time or 12, 0) -- l'heure reste celle de l'arene
			end
			local tab = IS_GAME_KEYBOARD_KEY_PRESSED(15) -- DIK_TAB
			if tab ~= board then
				board = tab
				axora.emit_server("gf_board", tab)
			end
		end
		axora.wait(0)
	end
end)
