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
print("SDFSDF")
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

local CellType = enum {
	"NONE",
	"GROUND"
}

type GridCell = {
	type : number,
	pos : Vector2Int
}
-- print(CellType.NONE)
-- print(CellType.GROUND)

local g : GridCell = { type = 0, pos = Vector2Int.new(1,2) }
g.type = CellType.GROUND

local v : Vector2Int = Vector2Int.Zero()

print("GGGGGGGGGGGg = ", typeof(v))

local function vec2(x, y)
    local t = {}
    t.x = x
    t.y = y
    return t
end

local v1 = Vector2Int.new(1, 2)
local v2 = Vector2Int.new(1, 2)
print(v1:add(v2).z)
print(g.type)