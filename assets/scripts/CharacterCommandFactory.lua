local WorldQuery = require("WorldQuery")
local CellType   = require("CellType")
local Actions = require("Actions")
local Utils   = require("Utils")

local CharacterCommandFactory = {}

---@class CharacterCommand
local CharacterCommand = {}

function CharacterCommand:CalcNextAction(character : Character) : CharacterAction|nil
    return nil
end

---@param combineRules CombineRule[]
function CharacterCommandFactory.CreateFromMultipleRules(combineRules) : CharacterCommand
    local command = {}
    command.combineRules = combineRules
    if not combineRules then
        error("combineRules is nil")
        combineRules = {}
    end
    if #combineRules == 0 then
        error("combineRules is empty")
    end
    function command:CalcNextAction(character : Character)
        local bestCombineRule : CombineRule = nil
        local minDistance = math.huge
        local hasNoDropCombineRule = false
        for index, combineRule in ipairs(self.combineRules) do
            if character.item == combineRule.charType or combineRule.charType == CellType.Any then
                hasNoDropCombineRule = true
            end
        end
        --TODO checks that other required for picked/dropped one exists 
        local characterIntPos = character:GetIntPos()
        if not hasNoDropCombineRule then
            for index, combineRule in ipairs(self.combineRules) do
                local rule : CombineRule|nil = nil
                if character.item ~= CellType.None then
                    rule = Actions:GetDropRule(character.item)
                else
                    rule = Actions:GetPickupRule(combineRule.charType)
                end
                if not rule then
                    return nil
                end
                local actionPos = WorldQuery:FindNearestActionPosFromRule(rule, characterIntPos)
                if actionPos then
                    local distance = math.pow(characterIntPos.x - actionPos.x, 2.0) + math.pow(characterIntPos.y - actionPos.y, 2.0)
                    if distance < minDistance then
                        minDistance = distance
                        bestCombineRule = rule
                    end
                end
            end
        else
            for index, combineRule in ipairs(self.combineRules) do
                if character.item == combineRule.charType or combineRule.charType == CellType.Any then
                    local actionPos = WorldQuery:FindNearestActionPosFromRule(combineRule, characterIntPos)
                    if actionPos then
                        local distance = math.pow(characterIntPos.x - actionPos.x, 2.0) + math.pow(characterIntPos.y - actionPos.y, 2.0)
                        if distance < minDistance then
                            minDistance = distance
                            bestCombineRule = combineRule
                        end
                    end
                end
            end
        end
        -- print("best=", Utils.TableToString(bestCombineRule))
        return WorldQuery:FindNearestActionFromRule(character, bestCombineRule)
    end
    return command
end

function CharacterCommandFactory.CreateFromSingleRule(combineRule : CombineRule) : CharacterCommand
    local command = {}
    command.combineRule = combineRule
    if not combineRule then
        error("combineRule is nil")
    end
    function command:CalcNextAction(character : Character)
        if not self.combineRule then
            return nil
        end
        if character.item ~= self.combineRule.charType and self.combineRule.charType ~= CellType.Any then
            local rule : CombineRule|nil = nil
            if character.item ~= CellType.None then
                rule = Actions:GetDropRule(character.item)
            else
                rule = Actions:GetPickupRule(combineRule.charType)
            end
            if not rule then
                return nil
            end
            return WorldQuery:FindNearestActionFromRule(character, rule)
        end
        return WorldQuery:FindNearestActionFromRule(character, self.combineRule)
    end
    return command
end

return CharacterCommandFactory
