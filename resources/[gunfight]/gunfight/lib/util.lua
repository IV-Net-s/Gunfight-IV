local util = {}

local clock = 0 -- ms, avance avec "tick" (le serveur n'a pas d'horloge en ms pour les scripts)

function util.advance(delta)
	clock = clock + delta * 1000
end

function util.now()
	return clock
end

function util.distance(a, x, y, z)
	local dx, dy, dz = a.x - x, a.y - y, (a.z or z) - z
	return math.sqrt(dx * dx + dy * dy + dz * dz)
end

function util.shuffle(list)
	for i = #list, 2, -1 do
		local j = math.random(i)
		list[i], list[j] = list[j], list[i]
	end
	return list
end

function util.copy(value)
	if type(value) ~= "table" then return value end
	local out = {}
	for k, v in pairs(value) do out[k] = util.copy(v) end
	return out
end

-- Dossier de la resource, depuis package.path ("<dossier>/?.lua;...").
function util.resource_dir()
	return (package.path:match("^(.-)/%?%.lua")) or "."
end

function util.read_json(path)
	local file = io.open(path, "rb")
	if not file then return nil end
	local text = file:read("a")
	file:close()
	local ok, value = pcall(axora.json.decode, text)
	return ok and value or nil
end

function util.write_json(path, value)
	local temp = path .. ".tmp"
	local file, err = io.open(temp, "wb")
	if not file then return false, err end
	file:write(axora.json.encode(value))
	file:close()
	os.remove(path)
	return os.rename(temp, path)
end

function util.valid(player)
	return player ~= nil and player:valid()
end

return util
