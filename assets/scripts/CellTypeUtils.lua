local CellTypeInv  = require "CellTypeInv"
local CellType     = require "CellType"
local GameConsts   = require "GameConsts"
local CellTypeDesc = nil

local CellTypeUtils = {}

function CellTypeUtils.GetHumanReadableName(cellType : integer) : string
    CellTypeDesc = CellTypeDesc or require "CellTypeDesc"
    local desc = CellTypeDesc:Get(cellType)
    return desc.humanReadableName or CellTypeInv[cellType]
end

function CellTypeUtils.IsPickable(cellType : integer) : boolean
    CellTypeDesc = CellTypeDesc or require "CellTypeDesc"
    local desc = CellTypeDesc:Get(cellType)
    return desc.isPickable or false
end

function CellTypeUtils.IsSubtype(childType : integer, parentType : integer) : boolean
	if parentType == CellType.Any then
		return true
	end
	if childType == parentType then
		return true
	end
	if CellType.WheatCollected_Any == parentType then
		if childType >= CellType.WheatCollected_1 and childType <= CellType.WheatCollected_1 + GameConsts.maxWheatStackSize - 1 then
			return true
		end
	end
	if CellType.WheatCollected_AnyNotFull == parentType then
		if childType >= CellType.WheatCollected_1 and childType < CellType.WheatCollected_1 + GameConsts.maxWheatStackSize - 1 then
			return true
		end
	end
	if CellType.Bread_Any == parentType then
		if childType >= CellType.Bread_1 and childType <= CellType.Bread_1 + GameConsts.maxBreadStackSize - 1 then
			return true
		end
	end
	if CellType.Eatable_Any == parentType then
		if childType >= CellType.Bread_1 and childType <= CellType.Bread_1 + GameConsts.maxBreadStackSize - 1 or childType == CellType.BushWithBerries then
			return true
		end
	end
	if CellType.Stove_Any == parentType then
		if childType == CellType.Stove or childType == CellType.StoveWithWood or childType == CellType.StoveWithWoodFired then
			return true
		end
	end
	if CellType.Campfire_Any == parentType then
		if childType == CellType.Campfire or childType == CellType.CampfireWithWood or childType == CellType.CampfireWithWoodFired then
			return true
		end
	end
	if CellType.Fence_Any == parentType then
		if childType == CellType.Fence or childType == CellType.FenceX or childType == CellType.FenceZ or childType == CellType.FenceXZ then
			return true
		end
	end
	return false
end

function CellTypeUtils.GetAllIsSubtype(cellTypeParent : integer)
	local result = {}
	for _, cellType in pairs(CellType) do
		if CellTypeUtils.IsSubtype(cellType, cellTypeParent) then
			table.insert(result, cellType)
		end
	end
	return result
end

function CellTypeUtils.IsFlag(cellType : integer) : boolean
	return cellType >= CellType.FlagRed and cellType <= CellType.FlagGreen
end

function CellTypeUtils.FlagFirst() : integer
	return CellType.FlagRed
end

function CellTypeUtils.FlagLast() : integer
	return CellType.FlagGreen
end

return CellTypeUtils