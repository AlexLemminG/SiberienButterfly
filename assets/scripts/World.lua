local World = {
    items = nil
}

function World:Init()
    World.items = GridSystem():GetGrid("ItemsGrid")
    assert(World.items)
end

return World