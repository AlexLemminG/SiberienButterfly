--!strict

function enum(tbl : any) : any
    local length = #tbl
    for i = 1, length do
        local v = tbl[i]
        tbl[v] = i
    end

    return tbl
end

local Vector2Int = {}
Vector2Int.__index = Vector2Int
function Vector2Int.new(_x, _y)
	local self = {x = _x, y = _y}
    
    return setmetatable(self, Vector2Int)
end
type Vector2Int = typeof(Vector2Int.new(0,0))
function Vector2Int.add(self : Vector2Int, b : Vector2Int) : Vector2Int
	return Vector2Int.new(self.x + b.x, self.y + b.y)
end

function Vector2Int.Zero() : Vector2Int
	return Vector2Int.new(0,0)
end

type GridCell = {
	type : number,
	pos : Vector2Int
}

local Grid = {}

return Grid