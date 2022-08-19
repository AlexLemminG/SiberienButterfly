local World = {
    items = nil,
	ground = nil,
    characters = {}
}

function World:Init()
    World.items = GridSystem():GetGrid("ItemsGrid")
    World.ground = GridSystem():GetGrid("GroundGrid")
    assert(World.items)
    assert(World.ground)
end

return World