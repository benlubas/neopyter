local utils = require("neopyter.utils")
local RpcClient = require("neopyter.rpc.baseclient")
local logger = require("neopyter.logger")
local WebsocketServer = require("neopyter.rpc.websocketserver")
local a = require("plenary.async")

---@class neopyter.WSServerClient:neopyter.RpcClient
---@field server neopyter.WebsocketServer
---@field connection neopyter.WebsocketClient
---@field private msg_count number
---@field private request_pool table<number, fun(...):any>
local WSServerClient = RpcClient:new({}) --[[@as neopyter.WSServerClient]]

---create RpcClient and connect
---@param opt neopyter.NewRpcClientOption
---@return neopyter.WSServerClient
function WSServerClient:new(opt)
    local o = setmetatable(opt or {}, self) --[[@as neopyter.WSServerClient]]
    self.__index = self
    o.msg_count = 0
    o.request_pool = {}
    return o
end

function WSServerClient:connect(address)
    self.address = address or self.address
    local host, port = utils.parse_address(self.address)
    self.server = WebsocketServer:new({
        host = host,
        port = port,
    })
    self.server:listen({
        on_connect = function(client)
            self.connection = client
            print(" client connection")
            client:attach({
                on_text = function(text)
                    local msg = vim.mpack.decode(text)

                    if #msg == 4 and msg[1] == 1 then
                        local msgid, error, result = msg[2], msg[3], msg[4]
                        local callback = self.request_pool[msgid]
                        self.request_pool[msgid] = nil
                        logger.log(string.format("msgid [%s] response acceptd", msgid))
                        assert(
                            callback,
                            string.format(
                                "msg %s can't find callback: request_pool=%s",
                                msgid,
                                vim.inspect(self.request_pool)
                            )
                        )
                        if error == vim.NIL then
                            callback(true, result)
                        else
                            callback(false, error)
                        end
                    else
                        assert(false, "msgpack rpc response spec error, msg=" .. text)
                    end
                end,
                on_disconnect = function()
                    print(" client disconnect")
                    self.connection = nil
                end,
            })
        end,
    })
end

function WSServerClient:disconnect()
    self.server:close()
end

---check client is connecting
---@return boolean
function WSServerClient:is_connecting()
    return self.connection ~= nil
end

function WSServerClient:gen_id()
    self.msg_count = self.msg_count + 1
    return self.msg_count
end

---send request to server
---@param method string
---@param ... unknown # name
---@return unknown|nil
function WSServerClient:request(method, ...)
    if not self:is_connecting() then
        utils.notify_error(string.format("RPC websocketserver client is disconnected, can't request [%s]", method))
        return
    end
    local msgid = self:gen_id()
    local content = vim.mpack.encode({ 0, msgid, method, { ... } })
    assert(content, string.format("request [%s] error: encode failed", method))
    local status, res = a.wrap(function(callback)
        self.request_pool[msgid] = callback
        self.connection:send_text(content)
        logger.log(string.format("msgid [%s] request [%s] sended", msgid, method))
    end, 1)()
    logger.log(string.format("msgid [%s] finished", msgid))

    if status then
        return res
    else
        utils.notify_error(string.format("RPC request [%s] failed, with error: %s", method, res))
    end
end

function WSServerClient:checkhealth()
    vim.health.info(string.format("websocket server listening: %s", self.server ~= nil))
    vim.health.info(string.format("websocket client exists: %s", self.connection ~= nil))
end

return WSServerClient
