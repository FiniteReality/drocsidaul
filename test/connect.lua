package.path = package.path..";../src/?.lua"

local gettime = require("socket").gettime

local oldprint = print
function _G.print(...)
	local message, thread, socket = ...
	if type(message) == "string" and type(thread) == "thread" then
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
local start

client:on("connect", function(client, servers)
	print("Connected to discord in", gettime() - start, "seconds")
	print("Connected to", table.concat(servers, ", "))
end)

client:on("message_receive", function(client, message)
	print("Message:", message.content)
	if message.content:match("^!ping") then
		local firstFailed = false
		--for i = 1, 100 do
			local succ, err = api.uploadFile(client.priv.token, message.channel_id, {
				--content = ("%s - %s"):format(discord._VERSION, client.latency),
				file = {
					name = "test.txt",
					contents = "Hello, world!"
				}
			})
			if not succ then
				if not firstFailed then
					firstFailed = true
					print("failed to send message:", err)
				end
			else
				for i, v in pairs(succ) do
					print(i, v)
				end
			end
		--end
	end
end)

client:on("message_update", function(client, before, after)
	print("Message update:", before.content, after.content)
end)

client:on("message_delete", function(client, message)
	print("Message delete:", message.content)
end)

start = gettime()
client:run()