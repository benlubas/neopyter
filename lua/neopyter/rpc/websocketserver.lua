-- copy from https://github.com/jbyuki/instant.nvim
local sha1 = require("neopyter.rpc.sha1")
local base64 = vim.base64

local conn_id = 100

local max_before_frag = 8192

local nocase

local unmask_text

local convert_bytes_to_string

function nocase(s)
    s = string.gsub(s, "%a", function(c)
        if string.match(c, "[a-zA-Z]") then
            return string.format("[%s%s]", string.lower(c), string.upper(c))
        else
            return c
        end
    end)
    return s
end

function unmask_text(str, mask)
    local unmasked = {}
    for i = 0, #str - 1 do
        local j = bit.band(i, 0x3)
        local trans = bit.bxor(string.byte(string.sub(str, i + 1, i + 1)), mask[j + 1])
        table.insert(unmasked, trans)
    end
    return unmasked
end

function convert_bytes_to_string(tab)
    local s = ""
    for _, el in ipairs(tab) do
        s = s .. string.char(el)
    end
    return s
end

---@alias neopyter.WebsocketClientCallbacks {on_disconnect: fun(), on_text: fun(text:string)}

---@class neopyter.WebsocketClient
---@field sock uv_tcp_t
---@field id number
local WebsocketClient = {}
WebsocketClient.__index = WebsocketClient

---
---@param opt {sock:uv_tcp_t, id:number}
function WebsocketClient:new(opt)
    opt = setmetatable(opt, self)
    return opt
end

---
---@param callbacks neopyter.WebsocketClientCallbacks
function WebsocketClient:attach(callbacks)
    self.callbacks = callbacks
end

function WebsocketClient:send_text(str)
    local remain = #str
    local sent = 0
    while remain > 0 do
        local send = math.min(max_before_frag, remain) -- max size before fragment
        remain = remain - send
        local fin
        if remain == 0 then
            fin = 0x80
        else
            fin = 0
        end

        local opcode
        if sent == 0 then
            opcode = 1
        else
            opcode = 0
        end

        local frame = {
            fin + opcode,
            0x80,
        }

        if send <= 125 then
            frame[2] = frame[2] + send
        elseif send < math.pow(2, 16) then
            frame[2] = frame[2] + 126
            local b1 = bit.rshift(send, 8)
            local b2 = bit.band(send, 0xFF)
            table.insert(frame, b1)
            table.insert(frame, b2)
        else
            frame[2] = frame[2] + 127
            for i = 0, 7 do
                local b = bit.band(bit.rshift(send, (7 - i) * 8), 0xFF)
                table.insert(frame, b)
            end
        end

        local control = convert_bytes_to_string(frame)
        local tosend = control .. string.sub(str, 1, send)
        str = string.sub(str, send + 1)

        self.sock:write(tosend)

        sent = sent + send
    end
end

function WebsocketClient:send_json(obj)
    local encoded = vim.api.nvim_call_function("json_encode", { obj })
    self:send_text(encoded)
end

---@class neopyter.WebsocketServer
local WebsocketServer = {}
WebsocketServer.__index = WebsocketServer

---@class NewWebsocketServerOption
---@field host? string host, default 127.0.0.1
---@field port? number port, default 8080

---
---@param opt? NewWebsocketServerOption
function WebsocketServer:new(opt)
    local o = {}
    o.conns = {}

    opt = vim.tbl_deep_extend("keep", opt or {}, {
        host = "127.0.0.1",
        port = 8080,
    })
    local host = opt.host
    local port = opt.port
    self.server = vim.uv.new_tcp()
    self.server:bind(host, port)

    return setmetatable(o, self)
end

--- start listen
---@param callbacks { on_connect: fun(client:neopyter.WebsocketClient) }
function WebsocketServer:listen(callbacks)
    local ret, err = self.server:listen(128, function(err)
        assert(err == nil, err)
        local sock = vim.uv.new_tcp()
        self.server:accept(sock)
        ---@type neopyter.WebsocketClient
        local conn
        local upgraded = false
        local http_data = ""
        local chunk_buffer = ""

        local function getdata(amount)
            while string.len(chunk_buffer) < amount do
                coroutine.yield()
            end
            local retrieved = string.sub(chunk_buffer, 1, amount)
            chunk_buffer = string.sub(chunk_buffer, amount + 1)
            return retrieved
        end

        local wsread_co = coroutine.create(function()
            while true do
                local wsdata = ""
                local fin

                local rec = getdata(2)
                local b1 = string.byte(string.sub(rec, 1, 1))
                local b2 = string.byte(string.sub(rec, 2, 2))
                local opcode = bit.band(b1, 0xF)
                fin = bit.rshift(b1, 7)

                local paylen = bit.band(b2, 0x7F)
                if paylen == 126 then -- 16 bits length
                    rec = getdata(2)
                    local b3 = string.byte(string.sub(rec, 1, 1))
                    local b4 = string.byte(string.sub(rec, 2, 2))
                    paylen = bit.lshift(b3, 8) + b4
                elseif paylen == 127 then
                    paylen = 0
                    rec = getdata(8)
                    for i = 1, 8 do -- 64 bits length
                        paylen = bit.lshift(paylen, 8)
                        paylen = paylen + string.byte(string.sub(rec, i, i))
                    end
                end

                local mask = {}
                rec = getdata(4)
                for i = 1, 4 do
                    table.insert(mask, string.byte(string.sub(rec, i, i)))
                end

                local data = getdata(paylen)

                local unmasked = unmask_text(data, mask)
                data = convert_bytes_to_string(unmasked)

                wsdata = data

                while fin == 0 do
                    rec = getdata(2)
                    b1 = string.byte(string.sub(rec, 1, 1))
                    b2 = string.byte(string.sub(rec, 2, 2))
                    fin = bit.rshift(b1, 7)

                    paylen = bit.band(b2, 0x7F)
                    if paylen == 126 then -- 16 bits length
                        rec = getdata(2)
                        local b3 = string.byte(string.sub(rec, 1, 1))
                        local b4 = string.byte(string.sub(rec, 2, 2))
                        paylen = bit.lshift(b3, 8) + b4
                    elseif paylen == 127 then
                        paylen = 0
                        rec = getdata(8)
                        for i = 1, 8 do -- 64 bits length
                            paylen = bit.lshift(paylen, 8)
                            paylen = paylen + string.byte(string.sub(rec, i, i))
                        end
                    end

                    mask = {}
                    rec = getdata(4)
                    for i = 1, 4 do
                        table.insert(mask, string.byte(string.sub(rec, i, i)))
                    end

                    data = getdata(paylen)

                    unmasked = unmask_text(data, mask)
                    data = convert_bytes_to_string(unmasked)

                    wsdata = wsdata .. data
                end

                if opcode == 0x1 then -- TEXT
                    if conn and conn.callbacks.on_text then
                        conn.callbacks.on_text(wsdata)
                    end
                end

                if opcode == 0x8 then -- CLOSE
                    if conn and conn.callbacks.on_disconnect then
                        conn.callbacks.on_disconnect()
                    end

                    self.conns[conn.id] = nil

                    conn.sock:close()
                    break
                end
            end
        end)

        if callbacks.on_connect then
            -- conn = setmetatable({ id = conn_id, sock = sock }, { __index = WebsocketClient })
            conn = WebsocketClient:new({ id = conn_id, sock = sock })
            self.conns[conn_id] = conn
            conn_id = conn_id + 1
            callbacks.on_connect(conn)
        end

        sock:read_start(function(err, chunk)
            if chunk then
                if not upgraded then
                    http_data = http_data .. chunk
                    if string.match(http_data, "\r\n\r\n$") then
                        local has_upgrade = false
                        local websocketkey
                        for line in vim.gsplit(http_data, "\r\n") do
                            if string.match(line, "Upgrade: websocket") then
                                has_upgrade = true
                            elseif string.match(line, nocase("Sec%-WebSocket%-Key")) then
                                websocketkey = string.match(line, nocase("Sec%-WebSocket%-Key") .. ": ([=/+%w]+)")
                            end
                        end

                        if has_upgrade then
                            local digest = sha1.sha1_binary(websocketkey .. "258EAFA5-E914-47DA-95CA-C5AB0DC85B11")
                            local hashed = base64.encode(digest)

                            sock:write("HTTP/1.1 101 Switching Protocols\r\n")
                            sock:write("Upgrade: websocket\r\n")
                            sock:write("Connection: Upgrade\r\n")
                            sock:write("Sec-WebSocket-Accept: " .. hashed .. "\r\n")
                            sock:write("Sec-WebSocket-Protocol: chat\r\n")
                            sock:write("\r\n")

                            upgraded = true
                        end

                        http_data = ""
                    end
                else
                    chunk_buffer = chunk_buffer .. chunk
                    coroutine.resume(wsread_co)
                end
            else
                if conn and conn.callbacks.on_disconnect then
                    conn.callbacks.on_disconnect()
                end

                self.conns[conn.id] = nil

                sock:shutdown()
                sock:close()
            end
        end)
    end)

    if not ret then
        error(err)
    end
end

function WebsocketServer:close()
    for _, conn in pairs(self.conns) do
        if conn and conn.callbacks.on_disconnect then
            conn.callbacks.on_disconnect()
        end

        conn.sock:shutdown()
        conn.sock:close()
    end

    self.conns = {}

    if self.server then
        self.server:close()
        self.server = nil
    end
end

return WebsocketServer
