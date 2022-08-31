local CellTypeDesc = {}
local CellType = require("CellType")
local CellTypeInv = require("CellTypeInv")
local Actions     = require("Actions")

local CollisionType = {
    None = 1,
    SphereCollider = 2,
    CapsuleCollider = 3,
    BoxCollider = 4,
}

function BoxCollision(size : vector, center : vector|nil) : any
    if not center then
        center = vector(0,0,0)
    end
    return {type=CollisionType.BoxCollider, size = size, center = center }
end

function SphereCollision(radius : number, center : vector|nil) : any
    if not center then
        center = vector(0,0,0)
    end
    return {type=CollisionType.SphereCollider, radius = radius, center = center }
end

function CapsuleCollision(radius : number, height : number, center : vector|nil) : any
    if not center then
        center = vector(0,0,0)
    end
    return {type=CollisionType.CapsuleCollider, radius = radius, height = height, center = center}
end

function SetCellInfo(cellType, info)
    CellTypeDesc[CellTypeInv[cellType]] = info
end

function SetCellInfoForAllBase(cellTypeBase, info)
    for index, cellType in ipairs(Actions:GetAllIsSubtype(cellTypeBase)) do
        SetCellInfo(cellType, info)
    end
end

local smallObjectCollision = SphereCollision(0.1, vector(0,0.1,0))
local bigObjectCollision = SphereCollision(0.2, vector(0,0.2,0))

SetCellInfo(CellType.None, { isUtil = true } )
SetCellInfo(CellType.Any, { isUtil = true } )
SetCellInfo(CellType.WheatCollected_Any, { isUtil = true } )
SetCellInfo(CellType.WheatCollected_AnyNotFull, { isUtil = true } )


SetCellInfoForAllBase(CellType.Stove_Any, { collision = SphereCollision(0.2, vector(0,0.2,0)) } )
SetCellInfo(CellType.Stove_Any, { isUtil = true } )

SetCellInfo(CellType.Tree, { collision = CapsuleCollision(0.15, 1.0, vector(0,0.5,0)) } )
SetCellInfo(CellType.Stone, { collision = smallObjectCollision } )
SetCellInfo(CellType.Wood, { collision = bigObjectCollision } )
SetCellInfo(CellType.FlintStone, { collision = smallObjectCollision } )
SetCellInfo(CellType.WheatCollected_6, { collision = smallObjectCollision } )

SetCellInfoForAllBase(CellType.CampfireWithWoodFired, { collision = bigObjectCollision } )
SetCellInfo(CellType.Campfire_Any, { isUtil = true } )

local fenceHeight = 1.0
local fenceLength = 1.0
local fenceRadius = 0.1
SetCellInfoForAllBase(CellType.Fence, { collision = CapsuleCollision(fenceRadius, fenceHeight, vector(0,fenceHeight / 2 ,0)) } )
local fenceColliderX = BoxCollision(vector(fenceLength,fenceHeight,fenceRadius*2), vector(fenceLength/2,fenceHeight/2,0))
local fenceColliderZ = BoxCollision(vector(fenceRadius*2,fenceHeight,fenceLength), vector(0,fenceHeight/2,fenceLength/2))
SetCellInfoForAllBase(CellType.FenceX, { collision = fenceColliderX } )
SetCellInfoForAllBase(CellType.FenceZ, { collision = fenceColliderZ } )
SetCellInfoForAllBase(CellType.FenceXZ, { collision = fenceColliderX, extraCollisions = {fenceColliderZ} } )
SetCellInfo(CellType.Fence_Any, { isUtil = true } )

SetCellInfoForAllBase(CellType.Bread_Any, { collision = CapsuleCollision(0.15, 1.0, vector(0,0.5,0)) } )
SetCellInfoForAllBase(CellType.Bread_1, {  } )
SetCellInfoForAllBase(CellType.Bread_2, { collision = smallObjectCollision } )
SetCellInfo(CellType.Bread_Any, { isUtil = true } )

local waterSphereRadius = 0.175
local waterSphereOffset = 0.3
local waterSphereOffsetY = 0.3
SetCellInfoForAllBase(CellType.Water, { extraCollisions = {
    SphereCollision(waterSphereRadius, vector(waterSphereOffset,waterSphereOffsetY,-waterSphereOffset)),
    SphereCollision(waterSphereRadius, vector(-waterSphereOffset,waterSphereOffsetY,-waterSphereOffset)),
    SphereCollision(waterSphereRadius, vector(-waterSphereOffset,waterSphereOffsetY,waterSphereOffset)),
    SphereCollision(waterSphereRadius, vector(waterSphereOffset,waterSphereOffsetY,waterSphereOffset)),
} } )

return CellTypeDesc