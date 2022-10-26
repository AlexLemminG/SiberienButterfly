---@class World
local World = {
    items = nil,
    ground = nil,
    markings = nil,
    navigation = nil,
    ---@type Character | nil
    playerCharacter = nil,
    ---@type Character[]
    characters = {},
    ---@type Character[]
    charactersIncludingDead = {}
}

function World:Init()
    World.items = GridSystem:GetGrid("ItemsGrid")
    World.ground = GridSystem:GetGrid("GroundGrid")
    World.markings = GridSystem:GetGrid("MarkingsGrid")
    World.navigation = GridSystem:GetNavigation()
    assert(World.items)
    assert(World.ground)
    assert(World.navigation)
    assert(World.markings)
end

return World
