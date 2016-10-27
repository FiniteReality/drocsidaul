local discord = require("discord.module")

local websocket = require("websocket")
local zlib = require("zlib")
local json = require("cjson")

local OPCODES = require("discord.client.opcodes")

local _M = {}

function _M:send(payload)
	payload = json.encode(payload)

	return self.priv.websocket:send(payload, websocket.TEXT)
end

function _M:identify(new_session, compress, shard_info)
	if new_session or self.priv.conn_attempts == 0 then
		-- identify
		self:send{
			op = OPCODES.IDENTIFY,
			d = {
				token = self.priv.token,
				properties = {
					["$browser"] = discord._VERSION
				},
				compress = compress,
				large_threshold = 250,
				shard = shard_info
			}
		}
	else
		-- try and resume
	end
end

return _M