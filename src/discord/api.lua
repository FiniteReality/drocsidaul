local discord = require("discord.module")
local json = require("discord.json")
local util = require("discord.util")

local socket = require("socket")
local http = require("copas.http")
local ltn12 = require("ltn12")

local _M = { }
_M.BASE_URL = "https://discordapp.com/api%s"
_M.API_VERSION = 6

http.TIMEOUT = 30
http.USERAGENT = ("DiscordBot (%s, %s)"):format(discord._URL, discord._VERSION)

local function createEndpoint(endpoint, ...)
	util.typecheck(1, endpoint, "string")

	if _M.API_VERSION <= 4 then
		return _M.BASE_URL:format(("%s?v=%d"):format(endpoint:format(...), _M.API_VERSION))
	else
		return _M.BASE_URL:format(("/v%s%s"):format(_M.API_VERSION, endpoint:format(...)))
	end
end

local function request(token, url, method, body, contentType)
	local resp = {}
	local reqt = {
		url = url,
		method = method or "GET",
		sink = ltn12.sink.table(resp),
		headers = {
			["content-type"] = contentType or "application/json",
			authorization = token
		}
	}

	if body then
		reqt.headers["content-length"] = #body
		reqt.source = ltn12.source.string(body)
	end

	local succ, code, headers = http.request(reqt)

	return table.concat(resp, ""), code, headers
end


function _M.getGatewayUri(token, encoding)
	util.typecheck(1, token, "string")
	util.typecheck(2, encoding, "string")

	-- https://discordapp.com/api/v6/gateway
	local payload = request(token, createEndpoint("/gateway"))
	-- https://gateway.discord.gg
	local uri = json.decode(payload).url
	-- GET https://gateway.discord.gg/?v=6&encoding=json
	return ("%s/?v=%s&encoding=%s"):format(uri, _M.API_VERSION, encoding)
end

function _M.getChannel(token, channel_id)
	util.typecheck(1, token, "string")
	util.typecheck(2, channel_id, "string")

	-- GET https://discordapp.com/api/v6/channels/1234567890
	local response = request(token, createEndpoint("/channels/%s", channel_id))
	return json.decode(response)
end

function _M.modifyChannel(token, channel_id, payload)
	util.typecheck(1, token, "string")
	util.typecheck(2, channel_id, "string")
	util.typecheck(3, payload, "table")

	-- PUT/PATCH https://discordapp.com/api/v6/channels/1234567890
	local response = request(token, createEndpoint("/channels/%s", channel_id), "PATCH", json.encode(payload))
	return json.decode(response)
end

function _M.deleteChannel(token, channel_id)
	util.typecheck(1, token, "string")
	util.typecheck(2, channel_id, "string")

	-- PUT/PATCH https://discordapp.com/api/v6/channels/1234567890
	local response = request(token, createEndpoint("/channels/%s", channel_id), "DELETE")
	return json.decode(response)
end

function _M.getChannelMessages(token, channel_id, around, before, after, limit)
	util.typecheck(1, token, "string")
	util.typecheck(2, channel_id, "string")
	util.typecheck(3, around, {"nil", "number"})
	util.typecheck(4, before, {"nil", "number"})
	util.typecheck(5, after, {"nil", "number"})
	util.typecheck(6, limit, {"nil", "number"})

	if around and (before or after) or
	   before and (around or after) or
	   after and (around or before) then

		error("before, after and around are mutually exclusive", 2)
	end

	if not (around or before or after) then
		error("one of before, after and around must be provided", 2)
	end

	local query = (around and "around") or
				  (before and "before") or
				  "after"
	local value = around or before or after

	limit = limit or 50

	-- GET https://discordapp.com/api/v6/channels/1234567890/messages?(around|before|after)=1234567890&limit=50
	local response = request(token, createEndpoint("/channels/%s/messages?%s=%s&limit=", channel_id, query, value, limit))
	return json.decode(response)
end

function _M.getChannelMessage(token, channel_id, message_id)
	util.typecheck(1, token, "string")
	util.typecheck(2, channel_id, "string")
	util.typecheck(3, message_id, "number")

	-- GET https://discordapp.com/api/v6/channels/1234567890/messages/1234567890
	local response = request(token, createEndpoint("/channels/%s/messages/%s", channel_id, message_id))
	return json.decode(response)
end

function _M.createMessage(token, channel_id, payload)
	util.typecheck(1, token, "string")
	util.typecheck(2, channel_id, "string")
	util.typecheck(3, payload, "table")

	if not payload.content then
		error("message content must be provided", 2)
	end

	-- POST https://discordapp.com/api/v6/channels/1234567890/messages
	local response = request(token, createEndpoint("/channels/%s/messages", channel_id), "POST", json.encode(payload))
	return json.decode(response)
end

function _M.uploadFile(token, channel_id, payload)
	util.typecheck(1, token, "string")
	util.typecheck(2, channel_id, "string")
	util.typecheck(3, payload, "table")

	if not payload.file then
		error("file contents must be provided", 2)
	end

	-- TODO: this boundary should be randomly generated based on the payload
	local boundary = ("---------------------------%s"):format(socket.gettime())
	local contentType = ("multipart/form-data; boundary=%s"):format(boundary)

	local data = {
		{
			("Content-Disposition: form-data; name=%q"):format("content"),
			"",
			payload.content
		}
	}
	if payload.nonce then
		data[#data+1] = {
			("Content-Disposition: form-data; name=%q"):format("nonce"),
			"",
			payload.nonce,
		}
	end

	if payload.tts then
		data[#data+1] = {
			("Content-Disposition: form-data; name=%q"):format("tts"),
			"",
			payload.tts,
		}
	end

	data[#data+1] = {
		("Content-Disposition: form-data; name=%q; filename=%q"):format("file", payload.file.name),
		("Content-Type: application/octet-stream")
		"",
		payload.file.contents
	}

	local data2 = { }
	for _, sect in ipairs(data) do
		data2[#data2+1] = table.concat(sect, "\r\n")
	end

	local encoded = table.concat(data2, ("\r\n%s\r\n"):format(boundary))

	-- POST https://discordapp.com/api/v6/channels/1234567890/messages
	local response = request(token, createEndpoint("/channels/%s/messages", channel_id), "POST", encoded, contentType)
	return json.decode(response)
end

function _M.editMessage(token, channel_id, message_id, new_content)
	util.typecheck(1, token, "string")
	util.typecheck(2, channel_id, "string")
	util.typecheck(3, message_id, "number")
	util.typecheck(4, new_content, "string")

	local payload = json.encode{content = new_content}

	local response = request(token, createEndpoint("/channels/%s/messages/%s", channel_id, message_id), "PATCH", payload)
	return json.decode(response)
end

function _M.bulkDeleteMessages(token, channel_id, message_ids)
	util.typecheck(1, token, "string")
	util.typecheck(2, channel_id, "string")
	util.typecheck(3, message_ids, "table")

	local payload = json.encode(message_ids)

	if not payload:sub(1,1) == "[" then
		error("message_ids must be an array", 2)
	end

	local response, code = request(token, createEndpoint("channels/%s/messages/bulk_delete", channel_id), "POST", payload)
	return code == 204 or json.decode(response)
end

function _M.editChannelPermissions(token, channel_id, overwrite_id, payload)
	util.typecheck(1, token, "string")
	util.typecheck(2, channel_id, "string")
	util.typecheck(3, message_id, "number")
	util.typecheck(4, payload, "table")
	util.typecheck(4, payload.allow, {"nil", "number"})
	util.typecheck(4, payload.deny, {"nil", "number"})
	util.typecheck(4, payload.type, "string")

	if payload.type ~= "member" and payload.type ~= "role" then
		error("overwrite type must be 'member' or 'role'", 2)
	end

	local response, code = request(token, createEndpoint("channels/%s/permissions/%s", channel_id, overwrite_id), "PUT", json.encode(payload))
	return code == 204 or json.decode(response)
end

return _M