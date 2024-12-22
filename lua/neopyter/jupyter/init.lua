--[[
-- For global instance
--]]

-- TODO: take log config from plugin config
require('neopyter.logger').new({}, true)

---@class neopyter.JupyterModule
---@field jupyterlab neopyter.JupyterLab|nil
---@field notebook neopyter.Notebook|nil
local M = {
    jupyterlab = nil,
    notebook = nil,
}

return M
