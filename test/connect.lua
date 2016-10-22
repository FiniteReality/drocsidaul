package.path = package.path..";../src/?.lua"

local oldprint = print
function print(...)
	local message, thread, socket = ...
	if type(message) == "string" and type(thread) == "thread" and type(socket) == "userdata" then
		local trace = debug.traceback(thread, ("Error in socket %s: %s"):format(tostring(socket), message))
		print(trace)
	else
		oldprint(...)
	end
end

local copas = require("copas")

local discord = require("discord")
local api = require("discord.api")

local f = io.open("token.data.txt", "r")
local token = f:read("*a")
f:close()

local client = discord.client.new(token)

client:on("message_receive", function(client, message)
	print("Message:", message.content)
	if message.content:match("^!ping") then
		api.createMessage(client.priv.token, message.channel_id, {
			content = ("Hello, world! This is %s. My gateway latency is %0.2fms"):format(discord._VERSION, client.latency * 1000)
		})
	end
end)

client:on("message_update", function(client, before, after)
	print("Message update:", before.content, after.content)
end)

client:on("message_delete", function(client, message)
	print("Message delete:", message.content)
end)

client:run()