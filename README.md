# drocsidaul - yet another Lua library for Discord #

## Why? ##

- Litcord is synchronous.
- Discordia requires Luvit.
- I dislike both Luvit and synchronous code.
- I think I can do better than both Litcord and Discordia. Sorry-not-sorry.

## Dependencies ##

- Lua > 5.1
- luarocks
- lua-websockets (scm-1)
- copas

These dependencies can be downloaded using luarocks:

- lua-cjson
- luasec
- lzlib
- date
- multipart

To install lua-websockets *correctly*, you need to install libev and run this command:

```shell
$luarocks install https://raw.githubusercontent.com/lipp/lua-websockets/master/rockspecs/lua-websockets-scm-1.rockspec
```

The version of copas used has been modified - to install it you should use:

```shell
$luarocks install https://raw.githubusercontent.com/FiniteReality/copas/master/rockspec/copas-cvs-4.rockspec
```


## Usage ##

For basic usage as a bot, this should be all you need to do:

```lua
local copas = require("copas")
local discord = require("discord")

local myClient = discord.client.new("your.bot.token.here")

myClient:on("message_update", function(client, before, after)
	print(("Message updated\nBefore: %s\nAfter: %s\n"):format(before.contents, after.contents))
end)

myClient:on("message_receive", function(client, message)
	print(("Message received: %s %s"):format(message.author.name, message.contents))

	if message.contents:match("^!ping") then
		client:sendMessage(message.channel, ("Pong! Gateway latency: %0.5ds"):format(client.latency))
	end
end)

copas.addthread(function()
	myClient:connect()
	myClient:listen()
end)
copas.loop()
```

Also look at the `test` directory for more examples of usage.

## Contributing ##

Feel free to open PRs and whatever. I'll get to them whenever.