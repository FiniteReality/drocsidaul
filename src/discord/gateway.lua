local socket = require("socket")
local copas = require("copas")

local json = require("discord.json")
local OPCODES = require("discord.client.opcodes")
local cache = require("discord.client.cache")

local _M = {}

local function invoke_callback(client, name, ...)
	for _, func in ipairs(client.events[name]) do
		func(client, ...)
	end
end

function _M.handleDispatch(client, dispatch, data)
	if dispatch == "READY" then
		copas.addthread(function()
			while client.connected or client.connecting do
				if client.sending_heartbeat then
					client.priv.websocket:close(1000, "server missed last heartbeat")
				end

				client.sending_heartbeat = true

				client.priv.heartbeat_start = socket.gettime()
				
				client:send({
					op = OPCODES.HEARTBEAT,
					d = client.priv.sequence
				})

				copas.sleep(client.priv.heartbeat_interval / 1000, 100)
				client.sending_heartbeat = false
			end
		end)

		client.priv.session = data.session_id
		client.priv.servers = data._trace
		client.current_user = data.user

		cache.addChannels(client, data.private_channels)
		cache.addGuilds(client, data.guilds)

		if data.presences then
			cache.addPresences(client, data.presences)
		end
		-- TODO: what format are these stored in?
		--if data.relationships then
		--	cache.addUsers(client, data.relationships)
		--end
	elseif dispatch == "RESUMED" then
		client.priv.servers = data._trace
	elseif dispatch == "CHANNEL_CREATE" then
		if data.guild_id then
			local guild = client.caches.guilds[data.guild_id]
			if guild then
				guild._channels[data.id] = data
			end
		else
			if client.caches.channels[data.id] then
				cache.updateChannels(client, data)
			else
				cache.addChannels(client, data)
			end
		end
	elseif dispatch == "CHANNEL_UPDATE" then
		if data.guild_id then
			local guild = client.caches.guilds[data.guild_id]
			if guild then
				guild._channels[data.id] = data
			end
		else
			if client.caches.channels[data.id] then
				cache.updateChannels(client, data)
			else
				cache.addChannels(client, data)
			end
		end
	elseif dispatch == "CHANNEL_DELETE" then
		if data.guild_id then
			local guild = client.caches.guilds[data.guild_id]
			if guild then
				guild._channels[data.id] = nil
			end
		else
			if client.caches.channels[data.id] then
				cache.deleteChannels(client, data)
			end
		end
	elseif dispatch == "GUILD_CREATE" then
		data._members = {}
		data._roles = {}
		data._bans = {}
		data._channels = {}
		if client.caches.guilds[data.id] then
			cache.updateGuilds(client, data)
		else
			cache.addGuilds(client, data)
		end
	elseif dispatch == "GUILD_UPDATE" then
		if client.caches.guilds[data.id] then
			cache.updateGuilds(client, data)
		else
			cache.addGuilds(client, data)
		end
	elseif dispatch == "GUILD_DELETE" then
		if not data.unavailable then
			-- user was removed
			if client.caches.guilds[data.id] then
				cache.deleteGuilds(client, data)
			end
		end
	elseif dispatch == "GUILD_BAN_ADD" then
		local guild = client.caches.guilds[data.guild_id]

		if guild then
			guild._bans[data.id] = true
		end
	elseif dispatch == "GUILD_BAN_REMOVE" then
		local guild = client.caches.guilds[data.guild_id]

		if guild then
			guild._bans[data.id] = nil
		end
	elseif dispatch == "GUILD_EMOJI_UPDATE" then
		cache.updateEmojis(client, data.guild_id, data.emojis)
	elseif dispatch == "GUILD_MEMBER_ADD" then
		local guild_id = data.guild_id
		local guild = client.caches.guilds[guild_id]

		local cachedUser = client.caches.users[data.user.id]
		if not cachedUser then
			data.user._guildids = {[guild_id] = true}
			cache.addUsers(client, data.user)
		else
			cachedUser._guildids[guild_id] = true
			cache.updateUsers(client, data.user)
		end

		if guild then
			guild._members[data.user.id] = data
		end
	elseif dispatch == "GUILD_MEMBER_REMOVE" then
		local user = client.caches.users[data.user.id]
		local guild = client.caches.guilds[data.guild_id]

		if not user then
			data.user._guildids = {[data.guild_id] = true}
			cache.addUsers(client, data.user)
		else
			user._guildids[data.guild_id] = nil
			cache.updateUsers(client, data.user)
		end

		if guild then
			guild._members[data.user.id] = nil
		end
	elseif dispatch == "GUILD_MEMBER_UPDATE" then
		if client.caches.users[data.user.id] then
			cache.updateUsers(client, data.user)
		else
			data.user._guildids = {[data.guild_id] = true}
			cache.addUsers(client, data.user)
		end

		local guild = client.caches.guilds[data.guild_id]
		if guild then
			local member = guild._members[data.user.id]
			if not member then
				guild._members[data.user.id] = data.user
				member = data.user
			end
			member.roles = data.roles
		end
	elseif dispatch == "GUILD_MEMBERS_CHUNK" then
		local guild = client.caches.guilds[data.guild_id]
		if guild then
			local cachedMembers = guild._members
			local members = data.members
			for i = 1, #members do
				local member = members[i]
				cachedMembers[member.id] = member
			end
		end
	elseif dispatch == "GUILD_ROLE_CREATE" then
		local guild = client.caches.guilds[data.guild_id]
		if guild then
			guild._roles[data.role.id] = data.role
		end
	elseif dispatch == "GUILD_ROLE_UPDATE" then
		local guild = client.caches.guilds[data.guild_id]
		if guild then
			guild._roles[data.role.id] = data.role
		end
	elseif dispatch == "GUILD_ROLE_DELETE" then
		if client.caches.roles[data.role_id] then
			client.caches.roles[data.role_id] = nil
		end

		local guild = client.caches.guilds[data.guild_id]
		if guild then
			guild._roles[data.role_id] = nil
		end
	elseif dispatch == "MESSAGE_CREATE" then
		if client.caches.messages[data.id] then
			cache.updateMessages(client, data)
		else
			cache.addMessages(client, data)
		end
		invoke_callback(client, "message_receive", data)
	elseif dispatch == "MESSAGE_UPDATE" then
		invoke_callback(client, "message_update", client.caches.messages[data.id], data)
		if client.caches.messages[data.id] then
			cache.updateMessages(client, data)
		else
			cache.addMessages(client, data)
		end
	elseif dispatch == "MESSAGE_DELETE" then
		invoke_callback(client, "message_delete", client.caches.messages[data.id] or data)
		if client.caches.messages[data.id] then
			cache.deleteMessages(client, data)
		end
	elseif dispatch == "MESSAGE_DELETE_BULK" then
		for i = 1, #data.ids do
			local id = data.ids[i]
			if client.caches.messages[data.id] then
				invoke_callback(client, "message_delete", client.caches.messages[data.id])
			else
				invoke_callback(client, "message_delete", {id = id})
			end
			client.caches.messages[id] = nil
		end
	elseif dispatch == "PRESENCE_UPDATE" then
		local guild = client.caches.guilds[data.guild_id]
		if guild then
			local user = guild._members[data.user.id]
			if not user then
				guild._members[data.user.id] = data.user
				user = data.user
			end

			for i, v in pairs(data.user) do
				user[i] = v
			end
			user.roles = data.roles
			user.game = data.game
			user.nick = data.nick
			user.status = data.status
		end
	elseif dispatch == "TYPING_START" then
		-- TODO: this
	elseif dispatch == "USER_SETTINGS_UPDATE" then
		-- ???
	elseif dispatch == "USER_UPDATE" then
		for i, v in pairs(data) do
			client.current_user[i] = v
		end
	elseif dispatch == "VOICE_STATE_UPDATE" then
		-- TODO: voice
	elseif dispatch == "VOICE_SERVER_UPDATE" then
		-- TODO: voice
	else
		print("Unhandled dispatch:", dispatch)
	end
end

local OPCODE_HANDLERS = {
	HELLO = function(client, payload)
		client.connecting = false
		client.connected = true
		local heartbeat_interval = payload.d.heartbeat_interval
		client.priv.heartbeat_interval = heartbeat_interval

		client:identify(false, client.priv.compress, client.shard_info)
	end,
	HEARTBEAT_ACK = function(client, payload)
		client.latency = socket.gettime() - client.priv.heartbeat_start
	end,
	HEARTBEAT = function(client, payload)
		-- echo the packet as it has everything we need
		client:send(payload)
	end,
	DISPATCH = function(client, payload)
		client.priv.sequence = payload.s
		local dispatch = payload.t

		--print("dispatch:", dispatch)

		_M.handleDispatch(client, dispatch, payload.d)
	end,
	RECONNECT = function(client, payload)
		client:disconnect()
		client:connect()
	end
}

function _M.handleJSON(client, payload)
	payload = json.decode(payload)

	local opcode = OPCODES[payload.op]
	local handler = OPCODE_HANDLERS[opcode]

	--print("opcode:", opcode)

	if handler then
		handler(client, payload)
	else
		print("Unhandled opcode:", opcode)
	end

	if payload.s then
		client.priv.sequence = payload.s
	end
end

return _M