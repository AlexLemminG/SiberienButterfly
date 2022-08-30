local CellTypeInfo = {}
local CellType = require("CellType")
local CellTypeInv = require("CellTypeInv")

local CollisionType = {
    None = 1,
    SphereCollider = 2
}

local function SphereCollision(radius : float) : any
    return {type=CollisionType.SphereCollider, radius = radius}
end

function SetCellInfo(cellType, info)
    CellTypeInfo[CellTypeInv[cellType]] = info
end

SetCellInfo(CellType.Tree, { collision = SphereCollision(0.2) } )

return CellTypeInfo