local CellTypeDesc = {}
local CellType = require("CellType")
local CellTypeInv = require("CellTypeInv")
local CellTypeUtils = require("CellTypeUtils")

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
    if CellTypeDesc[CellTypeInv[cellType]] then
        print("Desc for", CellTypeInv[cellType], "already set")
    end
    CellTypeDesc[CellTypeInv[cellType]] = {}
    UpdateCellInfo(cellType, info)
end

local nilValue = {}
function UpdateCellInfo(cellType, info)
    if not CellTypeDesc[CellTypeInv[cellType]] then
        SetCellInfo(cellType, info)
    else
        for key, value in info do
            if value == nilValue then
                CellTypeDesc[CellTypeInv[cellType]][key] = nil
            else
            CellTypeDesc[CellTypeInv[cellType]][key] = value
            end
        end
    end
end

function SetCellInfoForAllBase(cellTypeBase, info)
    for index, cellType in ipairs(CellTypeUtils.GetAllIsSubtype(cellTypeBase)) do
        SetCellInfo(cellType, info)
    end
end

local smallObjectCollision = SphereCollision(0.1, vector(0,0.1,0))
local bigObjectCollision = SphereCollision(0.2, vector(0,0.2,0))

SetCellInfoForAllBase(CellType.WheatCollected_Any, { humanReadableName = "CollectedWheat", isPickable = true } )

SetCellInfo(CellType.None, { isUtil = true } )
SetCellInfo(CellType.Any, { isUtil = true } )
UpdateCellInfo(CellType.WheatCollected_Any, { isUtil = true } )
SetCellInfo(CellType.WheatCollected_AnyNotFull, { isUtil = true } )
SetCellInfo(CellType.Eatable_Any, { isUtil = true } )


SetCellInfoForAllBase(CellType.Stove_Any, { isPickable = true, collision = SphereCollision(0.2, vector(0,0.2,0)) } )
SetCellInfo(CellType.Stove_Any, { isUtil = true } )

SetCellInfo(CellType.Tree, { collision = CapsuleCollision(0.15, 1.0, vector(0,0.5,0)) } )
SetCellInfo(CellType.Bush, { collision = CapsuleCollision(0.15, 1.0, vector(0,0.5,0)) } )
SetCellInfo(CellType.BushWithBerries, { collision = CapsuleCollision(0.15, 1.0, vector(0,0.5,0)) } )
SetCellInfo(CellType.Stone, { collision = smallObjectCollision, isPickable = true } )
SetCellInfo(CellType.Wood, { collision = bigObjectCollision, isPickable = true } )
SetCellInfo(CellType.FlintStone, { collision = smallObjectCollision, isPickable = true } )
SetCellInfo(CellType.Flour, { isPickable = true } )
SetCellInfo(CellType.Wool, { isPickable = true } )
SetCellInfo(CellType.Scissors, { isPickable = true } )
UpdateCellInfo(CellType.WheatCollected_6, { collision = smallObjectCollision } )

SetCellInfo(CellType.CampfireWithWoodFired, { collision = bigObjectCollision, prefabName = "prefabs/CampfireWithWoodFired.asset" } )
SetCellInfo(CellType.Campfire_Any, { isUtil = true } )

SetCellInfo(CellType.StoveWithWoodFired, { isPickable = false, collision = bigObjectCollision, prefabName = "prefabs/StoveWithWoodFired.asset" } )

local fenceHeight = 1.0
local fenceLength = 1.0
local fenceRadius = 0.1
SetCellInfoForAllBase(CellType.Fence, { isWalkable = false, isPickable = true, collision = CapsuleCollision(fenceRadius, fenceHeight, vector(0,fenceHeight / 2 ,0)) } )
local fenceColliderX = BoxCollision(vector(fenceLength,fenceHeight,fenceRadius*2), vector(fenceLength/2,fenceHeight/2,0))
local fenceColliderZ = BoxCollision(vector(fenceRadius*2,fenceHeight,fenceLength), vector(0,fenceHeight/2,fenceLength/2))
SetCellInfo(CellType.FenceX, { isWalkable = false, collision = fenceColliderX } )
SetCellInfo(CellType.FenceZ, { isWalkable = false, collision = fenceColliderZ } )
SetCellInfo(CellType.FenceXZ, { isWalkable = false, collision = fenceColliderX, extraCollisions = {fenceColliderZ} } )
SetCellInfo(CellType.Fence_Any, { isUtil = true } )

SetCellInfoForAllBase(CellType.Bread_Any, { collision = CapsuleCollision(0.15, 1.0, vector(0,0.5,0)), humanReadableName="Bread", isPickable = true } )
UpdateCellInfo(CellType.Bread_1, { collision = nilValue } )
UpdateCellInfo(CellType.Bread_2, { collision = smallObjectCollision } )
UpdateCellInfo(CellType.Bread_Any, { isUtil = true } )

local waterSphereRadius = 0.175
local waterSphereOffset = 0.3
local waterSphereOffsetY = 0.3
SetCellInfo(CellType.Water, { 
    isWalkable = false,
extraCollisions = {
    SphereCollision(waterSphereRadius, vector(waterSphereOffset,waterSphereOffsetY,-waterSphereOffset)),
    SphereCollision(waterSphereRadius, vector(-waterSphereOffset,waterSphereOffsetY,-waterSphereOffset)),
    SphereCollision(waterSphereRadius, vector(-waterSphereOffset,waterSphereOffsetY,waterSphereOffset)),
    SphereCollision(waterSphereRadius, vector(waterSphereOffset,waterSphereOffsetY,waterSphereOffset)),
} } )

local bedCollider = BoxCollision(vector(0.4,0.5,0.8))
SetCellInfo(CellType.Bed, { isPickable = true, collision = bedCollider, isWalkable = false } )
SetCellInfo(CellType.BedOccupied, { collision = bedCollider, meshName = "Bed", isWalkable = false } )

for flag = CellTypeUtils.FlagFirst(), CellTypeUtils.FlagLast(), 1 do
    UpdateCellInfo(flag, {isPickable = true})
end

for name, cellType in pairs(CellType) do
    if not CellTypeDesc[name] then
        SetCellInfo(cellType, { } )
    end
end

function CellTypeDesc:Get(cellType : integer)
    return self[CellTypeInv[cellType]]
end

return CellTypeDesc