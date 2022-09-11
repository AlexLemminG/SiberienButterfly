local Game = require("Game")

local GameHandler = {
}
local Component = require("Component")

setmetatable(GameHandler, Component)
GameHandler.__index = GameHandler

function GameHandler:new(o)
    o = Component:new(o)
    setmetatable(o, self)
    return o
end

function GameHandler:Update()
    Game:Update()
end

function GameHandler:OnEnable()
    Game.scene = self:gameObject():GetScene()
    Game:OnEnable()
end

function GameHandler:OnDisable()
    Game:OnDisable()
    Game.scene = nil
end

return GameHandler
