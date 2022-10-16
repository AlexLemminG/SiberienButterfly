local WorldQuery = {}
local World = require("World")
local Actions = require("Actions")
local CellType = require("CellType")
local CellTypeInv = require("CellTypeInv")

--TODO use navigation PathExists everywhere

function WorldQuery:FindNearestActionFromRule(character : Character, combineRule : CombineRule, intPosRelative)
    local intPos = intPosRelative or character:GetIntPos()
    if not combineRule or not character or not Actions:IsSubtype(character.item, combineRule.charType) or (character and combineRule.preCondition and not combineRule.preCondition(character)) then 
        return nil
    end
    local closestPos = self:FindNearestItemWithGround(combineRule.itemType, combineRule.groundType, intPos)
    if not closestPos then
        return nil
    end 
    return Actions:RuleToAction(character, closestPos, combineRule)
end

function WorldQuery:FindNearestActionPosFromRule(combineRule : CombineRule, originPos : Vector2Int, searchExcludeRadius : integer|nil) : Vector2Int|nil
    return self:FindNearestItemWithGround(combineRule.itemType, combineRule.groundType, originPos, searchExcludeRadius)
end

function WorldQuery:FindNearestCharacterToInterract(originPos : Vector2, predicate) : Character
    local minDistance = math.huge
    local result = nil
    for index, character in ipairs(World.characters) do
        if not (predicate(character) and character:CanInteract()) then
            continue
        end
        local distance = Vector2.Distance(character:GetPosition2D(), originPos)
        if distance < minDistance and predicate(character) then
            minDistance = distance
            result = character
        end
    end
    return result
end

function WorldQuery:FindNearestItemWithGround(cellTypeItem : integer, cellTypeGround : integer, originPos : Vector2Int, searchExcludeRadius : integer|nil) : Vector2Int|nil
    if cellTypeGround == CellType.Any then
        return self:FindNearestItem(cellTypeItem, originPos, nil, searchExcludeRadius)
    end
    
    local radius = 10
    local _searchExcludeRadius = searchExcludeRadius or 0
    local closestPos = Vector2Int:new()
    if GridSystem:FindNearestPosWithTypes(closestPos, originPos, _searchExcludeRadius, radius, cellTypeItem, cellTypeGround) then
        return closestPos
    end
    return nil
end

function WorldQuery:FindNearestItem(cellType : integer, originPos : Vector2Int, radius, searchExcludeRadius : integer|nil) : Vector2Int|nil
    local queryRadius = radius or 20
    local queryExcludeRadius = searchExcludeRadius or 0
    local closestPos = Vector2Int:new()
    local grid = World.items
    if grid:FindNearestPosWithType(closestPos, originPos, queryExcludeRadius, queryRadius, cellType) then
        return closestPos
    end
    return nil
end

function WorldQuery:FindNearestWalkable(originPos : Vector2Int, radius) : Vector2Int|nil
    local queryRadius = radius or 10
    local closestPos = Vector2Int:new()
    if GridSystem:FindNearestWalkable(closestPos, originPos, queryRadius) then
        return closestPos
    end
    return nil
end

return WorldQuery