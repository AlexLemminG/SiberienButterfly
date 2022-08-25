local WorldQuery = require("WorldQuery")
local CellType   = require("CellType")
local Actions = require("Actions")

local CharacterCommandFactory = {}

---@class CharacterCommand
local CharacterCommand = {}

function CharacterCommand:CalcNextAction(character : Character) : CharacterAction|nil
    return nil
end

function CharacterCommandFactory.CreateFromRule(combineRule : CombineRule) : CharacterCommand
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
