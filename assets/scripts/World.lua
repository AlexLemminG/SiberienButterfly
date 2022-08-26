---@class World
local World = {
    items = nil,
    ground = nil,
    ---@type Character[]
    characters = {}
}

function World:Init()
    World.items = GridSystem():GetGrid("ItemsGrid")
    World.ground = GridSystem():GetGrid("GroundGrid")
    assert(World.items)
    assert(World.ground)
end

return World
