local WorldQuery = {}
local World = require("World")
local Actions = require("Actions")
local CellType = require("CellType")


function WorldQuery:FindNearestActionFromRule(character : Character, combineRule : CombineRule)
    if not combineRule or not character or not Actions:IsSubtype(character.item, combineRule.charType) or (character and combineRule.preCondition and not combineRule.preCondition(character)) then 
        return nil
    end
    local closestPos = self:FindNearestItemWithGround(combineRule.itemType, combineRule.groundType, character:GetIntPos())
    if not closestPos then
        return nil
    end 
    return Actions:RuleToAction(character, closestPos, combineRule)
end

function WorldQuery:FindNearestActionPosFromRule(combineRule : CombineRule, originPos : Vector2Int) : Vector2Int|nil
    return self:FindNearestItemWithGround(combineRule.itemType, combineRule.groundType, originPos)
end

function WorldQuery:FindNearestCharacter(originPos : Vector2, predicate) : Character
    local minDistance = math.huge
    local result = nil
    for index, character in ipairs(World.characters) do
        local distance = Vector2.Distance(character:GetPosition2D(), originPos)
        if distance < minDistance and predicate(character) then
            minDistance = distance
            result = character
        end
    end
    return result
end

function WorldQuery:FindNearestItemWithGround(cellTypeItem : integer, cellTypeGround : integer, originPos : Vector2Int) : Vector2Int|nil
    if cellTypeGround == CellType.Any then
        return self:FindNearestItem(cellTypeItem, originPos)
    end
    local radius = 10
    local pos = Vector2Int:new()
    local closestPos = nil
    local closestDistance = radius * 2.0
    local gridItems = World.items
    local gridGround = World.ground
    for dx = -radius, radius, 1 do
        for dy = -radius, radius, 1 do
            pos.x = dx + originPos.x;
            pos.y = dy + originPos.y
            
            if gridItems:GetCell(pos).type == cellTypeItem and gridGround:GetCell(pos).type == cellTypeGround then
                local distance = math.abs(dx) + math.abs(dy)
                if not closestPos then
                    closestPos = Vector2Int:new()
                    closestPos.x = pos.x
                    closestPos.y = pos.y
                elseif closestDistance > distance then
                    closestDistance = distance
                    closestPos.x = pos.x
                    closestPos.y = pos.y
                end
            end
        end    
    end    
    return closestPos
end

function WorldQuery:FindNearestItem(cellType : integer, originPos : Vector2Int) : Vector2Int
    local radius = 10
    local pos = Vector2Int:new()
    local closestPos = nil
    local closestDistance = radius * 2.0
    local grid = World.items
    for dx = -radius, radius, 1 do
        for dy = -radius, radius, 1 do
            pos.x = dx + originPos.x;
            pos.y = dy + originPos.y
            
            if grid:GetCell(pos).type == cellType then
                local distance = math.abs(dx) + math.abs(dy)
                if not closestPos then
                    closestPos = Vector2Int:new()
                    closestPos.x = pos.x
                    closestPos.y = pos.y
                elseif closestDistance > distance then
                    closestDistance = distance
                    closestPos.x = pos.x
                    closestPos.y = pos.y
                end
            end
        end    
    end    
    return closestPos
end

return WorldQuery