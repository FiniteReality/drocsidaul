local json = require("cjson")

local _M = {}

function _M.addGeneric(cache, entities)
	if entities.id then
		cache[entities.id] = entities
	else
		for i = 1, #entities do
			local entity = entities[i]
			cache[entity.id] = entity
		end
	end
end

function _M.updateGeneric(cache, entities)
	if entities.id then
		local cachedEntity = cache[entities.id]
		for i, v in pairs(entities) do
			if v == json.null then
				cachedEntity[i] = nil
			else
				cachedEntity[i] = v
			end
		end
	else
		for i = 1, #entities do
			local entity = entities[i]
			local cachedEntity = cache[entity.id]
			for i, v in pairs(entity) do
				if v == json.null then
					cachedEntity[i] = nil
				else
					cachedEntity[i] = v
				end
			end
		end
	end
end

function _M.deleteGeneric(cache, entities)
	if entities.id then
		cache[entities.id] = nil
	else
		for i = 1, #entities do
			local entity = entities[i]
			cache[entity.id] = nil
		end
	end
end

local caches = {"users", "guilds", "channels", "messages", "presences"}

for i = 1, #caches do
	local cache = caches[i]
	local funcName = cache:gsub("^(.)", string.upper)
	_M["add"..funcName] = function(client, entities)
		_M.addGeneric(client.caches[cache], entities)
	end
	_M["update"..funcName] = function(client, entities)
		_M.updateGeneric(client.caches[cache], entities)
	end
	_M["delete"..funcName] = function(client, entities)
		_M.deleteGeneric(client.caches[cache], entities)
	end
end

function _M.updateEmojis(client, guild, emojis)
	client.caches.emojis[guild] = emojis
end

return _M