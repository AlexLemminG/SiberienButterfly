local WorldQuery = require("WorldQuery")
local CellType   = require("CellType")
local Actions = require("Actions")
local Utils   = require("Utils")
local World   = require("World")

local CharacterCommandFactory = {}

---@class CharacterCommand
local CharacterCommand = {
    savedState = {}
}

function CharacterCommand:CalcNextAction(character : Character) : CharacterAction|nil
    return nil
end

function CharacterCommandFactory:SaveToState(command : CharacterCommand) : any
    if not command then
        return nil
    end
    if not command.savedState then
        LogError("command without saveState")
    end
    return command.savedState
end

function CharacterCommandFactory:LoadFromState(savedState : any) : CharacterCommand|nil
    if not savedState or not savedState.factoryFunctionName then
        return nil
    end
    local command = CharacterCommandFactory[savedState.factoryFunctionName](table.unpack(savedState.args))
    if not command then
        LogError("failed to create command from savedState "..Utils.TableToString(savedState))
    end
    return command
    --TODO check for validity
end

function CharacterCommandFactory.CollectWheatToStacks() : CharacterCommand
    local collectRules = Actions:GetAllCombineRules(CellType.WheatCollected_Any, CellType.WheatCollected_Any, CellType.Any)
    local command = CharacterCommandFactory.CreateFromMultipleRules(collectRules)
    command.savedState = {
        factoryFunctionName = "CollectWheatToStacks"
    }
    return command
end

function CharacterCommandFactory.EatSomething() : CharacterCommand
    local eatRules = {}
    for key, value in pairs(Actions:GetAllCombineRules(CellType.None, CellType.Eatable_Any, CellType.Any)) do
        if value.newCharType == CellType.None then
            table.insert(eatRules, value)
        end
    end
    local command = CharacterCommandFactory.CreateFromMultipleRules(eatRules)
    command.savedState = {
        factoryFunctionName = "EatSomething"
    }
    return command
end

function CharacterCommandFactory.EatGrass() : CharacterCommand
    local eatRules = {}
    for key, value in pairs(Actions:GetAllCombineRules(CellType.None, CellType.None, CellType.GroundWithGrass)) do
        if value.newGroundType == CellType.GroundWithEatenGrass then
            table.insert(eatRules, value)
        end
    end
    local command = CharacterCommandFactory.CreateFromMultipleRules(eatRules)
    command.savedState = {
        factoryFunctionName = "EatGrass"
    }
    return command
end

function CharacterCommandFactory.GoToPoint(pointX, pointY) : CharacterCommand
    local command = {}
    function command:CalcNextAction(character : Character) : CharacterAction|nil
        local point = Vector2Int.new()
        point.x = pointX
        point.y = pointY
        local action = Actions.CreateDoNothingAtPosAction(character, point)
        return action
    end
    command.savedState = {
        factoryFunctionName = "GoToPoint",
        args = { pointX, pointY }
    }
    return command
end

function CharacterCommandFactory.DropItem() : CharacterCommand
    local command = {}
    
    function command:CalcNextAction(character : Character) : CharacterAction|nil
        if character.item == CellType.None or not Actions:IsPickable(character.item) then
            return nil
        end
        local characterIntPos = character:GetIntPos()
        local rule = Actions:GetDropRule(character.item)
        if not rule then
            --TODO error
           return nil 
        end
        return WorldQuery:FindNearestActionFromRule(character, rule)
    end
    command.savedState = {
        factoryFunctionName = "DropItem",
    }
    return command
end

function CharacterCommandFactory.Wander() : CharacterCommand
    local command = {}
    
    function command:OnEnable(character : Character)
        if not character.characterController.commandState.wander then
            character.characterController.commandState.wander = {}
        end
    end

    function command:OnFailed(character : Character)
        character.characterController.commandState.wander = {}
    end

    function command:CalcNextAction(character : Character) : CharacterAction|nil
        local pos = character:GetIntPos()

        local radius = 3
        local state = character.characterController.commandState.wander
        --TODO clamp to radius
        if not state.pos or state.pos == pos or not World.navigation:PathExists(pos, state.pos) then
           state.pos = Vector2Int.new() 
           state.pos.x = math.random(pos.x - radius, pos.x + radius)
           state.pos.y = math.random(pos.y - radius, pos.y + radius)

           state.pos.x = math.max(state.pos.x, 0)
           state.pos.y = math.max(state.pos.y, 0)

           state.pos.x = math.min(state.pos.x, World.items.sizeX-1)
           state.pos.y = math.min(state.pos.y, World.items.sizeY-1)
        end
        local action = Actions.CreateDoNothingAtPosAction(character, state.pos)
        return action
    end
    command.savedState = {
        factoryFunctionName = "Wander",
    }
    return command
end

function CharacterCommandFactory.FollowCharacter(character : Character) : CharacterCommand
    local command = {}
    command.characterToFollow = character
    function command:CalcNextAction(character : Character) : CharacterAction|nil
        if not self.characterToFollow then return nil end
        local maxDistance = 0.5
        local deltaDistance = (character:GetPosition() - self.characterToFollow:GetPosition())
        
        local maxDistanceSqr = maxDistance * maxDistance
        local distanceSqr = deltaDistance.x * deltaDistance.x + deltaDistance.z * deltaDistance.z
        if distanceSqr < maxDistanceSqr then return nil end

        --TODO not exactly, but should work for now
        local action = Actions.CreateDoNothingAtPosAction(character, self.characterToFollow:GetIntPos())
        return action
    end
    command.savedState = {
        factoryFunctionName = "FollowCharacter"
        --TODO save character
    }
    return command
end

function CharacterCommandFactory.GoToCampfire() : CharacterCommand
    local command = {}
    function command:CalcNextAction(character : Character) : CharacterAction|nil
        local campfirePos = WorldQuery:FindNearestItem(CellType.CampfireWithWoodFired, character:GetIntPos())
        if campfirePos == nil then
            return nil
        end
        --TODO account for current character position
        local nearestEmpty = WorldQuery:FindNearestWalkable(campfirePos, 3)
        if nearestEmpty == nil then
            return nil
        end 
        
        local action = Actions.CreateDoNothingAtPosAction(character, nearestEmpty)
        return action
    end
    command.savedState = {
        factoryFunctionName = "GoToCampfire"
    }
    return command
end

function CharacterCommandFactory.GoToSleepImmediately() : CharacterCommand
    local command = {}
    function command:CalcNextAction(character : Character) : CharacterAction|nil
        return Actions.CreateSleepImmediatelyAction(character)
    end
    command.savedState = {
        factoryFunctionName = "GoToSleepImmediately"
    }
    return command
end

function CharacterCommandFactory.WakeUpImmediately() : CharacterCommand
    local command = {}
    function command:CalcNextAction(character : Character) : CharacterAction|nil
        return Actions.CreateWakeUpImmediatelyAction(character)
    end
    command.savedState = {
        factoryFunctionName = "WakeUpImmediately"
    }
    return command
end

function CharacterCommandFactory.GoToSleep() : CharacterCommand
    local sleepRules = {}

    for key, value in pairs(Actions:GetAllCombineRules(CellType.None, CellType.Bed, CellType.Any)) do
        if value.newCharType == CellType.None then
            table.insert(sleepRules, value)
        end
    end
    local command = CharacterCommandFactory.CreateFromMultipleRules(sleepRules)
    command.savedState = {
        factoryFunctionName = "GoToSleep"
    }
    return command
end

function CharacterCommandFactory.WakeUp() : CharacterCommand
    --TODO there should be betterWay
    local wakeUpRules = {}

    for key, value in pairs(Actions:GetAllCombineRules(CellType.None, CellType.BedOccupied, CellType.Any)) do
        if value.newCharType == CellType.None then
            table.insert(wakeUpRules, value)
        end
    end
    local command = CharacterCommandFactory.CreateFromMultipleRules(wakeUpRules)
    command.savedState = {
        factoryFunctionName = "WakeUp"
    }
    return command
end

---@param combineRules CombineRule[]
function CharacterCommandFactory.CreateFromMultipleRules(combineRules) : CharacterCommand
    local command = {}
    command.savedState = {
        factoryFunctionName = "CreateFromMultipleRules",
        args = { combineRules }
    }
    --To make sure after loading they are valid objects
    for index, value in ipairs(combineRules) do
        --TODO get one specific rule from Actions
        local allRules = Actions:GetAllCombineRules_NoAnyChecks(nil, value.charType, value.itemType, value.groundType)
        if not allRules then
            error("Failed to find specified rule")
            continue
        end
        for index2, rule in ipairs(allRules) do
            if rule.newCharType == value.newCharType and rule.newItemType == value.newItemType and rule.newGroundType == value.newGroundType then
                combineRules[index] = rule
                break
            end
        end
    end
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
                    continue
                end
                local actionPos = WorldQuery:FindNearestActionPosFromRule(rule, characterIntPos)
                if actionPos then
                    local actionPosNext = WorldQuery:FindNearestActionPosFromRule(combineRule, actionPos)
                    if not actionPosNext then
                        continue
                    end

                    local distance1 = math.sqrt(math.pow(characterIntPos.x - actionPos.x, 2.0) + math.pow(characterIntPos.y - actionPos.y, 2.0))
                    local distance2 = math.sqrt(math.pow(actionPosNext.x - actionPos.x, 2.0) + math.pow(actionPosNext.y - actionPos.y, 2.0))
                    local distance = distance1 + distance2
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
    return CharacterCommandFactory.CreateFromMultipleRules({combineRule})
end

return CharacterCommandFactory
