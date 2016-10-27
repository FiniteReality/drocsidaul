local util = require("discord.util")
local rest = require("discord.rest")
local gateway = require("discord.gateway")

local websocket = require("websocket")
local copas = require("copas")
local zlib = require("zlib")
local client = { }

client.SSLPARAMS = {
	protocol = "tlsv1_2",
	options = "all",
	verify = "none",
	mode = "client"
}

local client_methd = require("discord.client.api")
local client_mt = {__index = client_methd}

function client.new(token, tokenType)
	util.typecheck(1, token, "string")
	util.typecheck(2, tokenType, {"string","nil"})

	tokenType = tokenType or "bot"

	local prefix
	if tokenType == "bot" then
		prefix = "Bot %s"
	elseif tokenType == "user" then
		prefix = "User %s"
	elseif tokenType == "bearer" then
		prefix = "Bearer %s"
	else
		error(2, ("unknown token type %q"):format(tokenType))
	end

	local o = setmetatable(
		{
			caches={
				users={},
				messages={},
				channels={},
				guilds={},
				presences={},
				emojis={},
				gateway_uri=nil,
			},
			priv={
				token=prefix:format(token),
				session="",
				heartbeat_interval=0,
				conn_attempts=0,
				sequence=0,
				sending_heartbeat=false,
				heartbeat_start=0,
				websocket=require("discord.client.ws_copas")(),
				compress=true,
				servers=nil
			},
			events = {
				connect={},
				message_receive={},
				message_update={},
				message_delete={}
			},
			latency=0,
			connected=false,
			connecting=false,
			current_user=nil
		},
		client_mt)

	return o
end

function client_methd:on(eventName, callback)
	local evt_t = assert(self.events[eventName], ("Unknown event %q"):format(eventName))
	evt_t[#evt_t+1] = callback
end

function client_methd:setShardInfo(shardId, shardCount)
	assert(not (client.connected or client.connecting), "client must be disconnected before setting shard info")
	self.shard_info = {shardId, shardCount}
end

function client_methd:connect(sslparams)
	self.connecting = true
	if not self.caches.gateway_uri then
		local succ, data = rest.getGateway(self.priv.token)
		self.caches.gateway_uri = ("%s/?v=%s&encoding=json"):format(data.url, rest.API_VERSION)
		print(self.caches.gateway_uri)
	end

	local succ, err = self.priv.websocket:connect(self.caches.gateway_uri, nil, sslparams or client.SSLPARAMS)

	if not succ then
		self.connecting = false
		self.priv.conn_attempts = self.priv.conn_attempts + 1

		if self.priv.conn_attempts == 3 then
			-- invalidate our cached gateway uri so we pull a fresh uri
			self.priv.conn_attempts = 0
			self.caches.gateway_uri = nil
		end
	end

	return succ, err
end

function client_methd:disconnect()
	self.priv.conn_attempts = 0
	return self.priv.websocket:close(1000, "disconnected")
end

function client_methd:think()
	local data, opcode, close_clean, close_code, close_reason = self.priv.websocket:receive()

	if data then
		if opcode == websocket.BINARY then
			data = zlib.decompress(data)
		end
		gateway.handleJSON(self, data)
	else
		self.connected = false

		return nil, close_clean, close_code, close_reason
	end

	return true
end

function client_methd:run(timeout)
	--timeout = timeout or 1

	copas.addthread(function()
		assert(self:connect())
		while self.connecting or self.connected do
			local succ, close_clean, close_code, close_reason = self:think()
			if not succ then
				error(string.format("Server sent close %s (%s) (%s)", close_code, (close_reason or "unknown"), (close_clean and "clean" or "unclean")))
			end
			copas.sleep(0)
		end
	end)

	local oldfinish = copas.finished
	copas.finished = function() return (not (self.connecting or self.connected)) or oldfinish() end
	copas.loop(timeout)
end

return client