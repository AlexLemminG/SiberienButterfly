local WorldQuery = {}
local World = require("World")
local Actions = require("Actions")


function WorldQuery:FindNearestActionFromRule(character : Character, combineRule)
    if not combineRule or not character then 
        return nil
    end
    local closestPos = WorldQuery:FindNearestItem(combineRule.itemType, character:GetIntPos())
    if not closestPos then
        return nil
    end 
    return Actions:RuleToAction(character, closestPos, combineRule)
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