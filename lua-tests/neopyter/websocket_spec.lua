local WebsocketServer = require("neopyter.rpc.websocketserver")
describe("simple", function()
    it("echo server", function()
        local co = coroutine.running()
        local server = WebsocketServer:new({
            host = "127.0.0.1",
            port = 9003,
        })
        -- server:listen({
        --     on_connect = function(client)
        --         client:attach({
        --             on_text = function(text)
        --                 print("receive:", text, #text)
        --                 client:send_text(text)
        --                 print("send world", #"World")
        --                 client:send_text("World")
        --             end,
        --             on_disconnect = function()
        --                 print("disconnect")
        --                 coroutine.resume(co)
        --             end,
        --         })
        --     end,
        -- })
        -- coroutine.yield()
    end)
end)
