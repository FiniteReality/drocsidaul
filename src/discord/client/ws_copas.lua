-- A modified version of lua-websockets client_copas.lua
-- Only calls socket:shutdown if supported

local socket = require'socket'
local sync = require'websocket.sync'
local tools = require'websocket.tools'

local new = function(ws)
  ws = ws or {}
  local copas = require'copas'
  
  local self = {}
  
  self.sock_connect = function(self,host,port)
    self.sock = copas.wrap(socket.tcp())
    self.sock:settimeout(ws and ws.timeout or 0)
    function self.sock:getfd(...) return self.socket:getfd(...) end
    function self.sock:setfd(...) return self.socket:setfd(...) end
    local _,err = self.sock:connect(host,port)
    if err and err ~= 'already connected' then
      self.sock:close()
      return nil,err
    end
  end
  
  self.sock_send = function(self,...)
    return self.sock:send(...)
  end
  
  self.sock_receive = function(self,...)
    return self.sock:receive(...)
  end
  
  self.sock_close = function(self)
    if self.sock.shutdown then
      self.sock:shutdown()
    end
    self.sock:close()
  end
  
  self = sync.extend(self)
  return self
end

return new
