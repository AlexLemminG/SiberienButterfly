local World = {
    items = nil
}

function World:Init()
    World.items = GridSystem():GetGrid("ItemsGrid")
end

return World