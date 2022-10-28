local BehaviourTree_Builder = require "BehaviourTree_Builder"
local DayTime                = require("DayTime")
local BehaviourTree          = require("BehaviourTree")
local BehaviourTree_Builder  = require("BehaviourTree_Builder")
local BehaviourTree_NodesFactory = require("BehaviourTree_NodesFactory")
local BehaviourTree_Node         = require("BehaviourTree_Node")
local BehaviourTree_NodeFunctions= require("BehaviourTree_NodeFunctions")
local CellType                   = require("CellType")
local GameConsts              = require "GameConsts"
local Actions                 = require "Actions"
local Game                    = require "Game"
local WorldQuery              = require "WorldQuery"
local World                   = require "World"
local CellTypeUtils           = require "CellTypeUtils"

local CharacterControllerBehaviourTree = {}

function CharacterControllerBehaviourTree.Create(characterController : CharacterControllerBase)
    local builder = BehaviourTree_Builder
    local factory = BehaviourTree_NodesFactory
    
    local sleepInBedRule = nil
    for key, value in pairs(Actions:GetAllCombineRules(CellType.None, CellType.Bed, CellType.Any)) do
        if value.newCharType == CellType.None then
            sleepInBedRule = value
            break
        end
    end
    local wakeUpInBedRule = nil
    for key, value in pairs(Actions:GetAllCombineRules(CellType.None, CellType.BedOccupied, CellType.Any)) do
        if value.newCharType == CellType.None then
            wakeUpInBedRule = value
            break
        end
    end
    local eatGrassRule = nil
    for key, value in pairs(Actions:GetAllCombineRules(CellType.None, CellType.None, CellType.GroundWithGrass)) do
        if value.newGroundType == CellType.GroundWithEatenGrass then
            eatGrassRule = value
            break
        end
    end

    --TODO get rid of lots of factory.Func
    
    builder.BeginTree(characterController)
    builder.PushSelectorNode(factory.Fallback("root"))
        builder.PushSelectorNode(factory.Sequence("SleepImmediately?"))
            builder.PushNode(factory.Condition(function () return DayTime.IsBetween(Game.dayTime, GameConsts.goToSleepImmediatelyDayTime, GameConsts.wakeUpDayTime) end))
            builder.PushNode(factory.Action(Actions.CreateSleepImmediatelyAction(characterController.character), "SleepImmediately"))
        builder.PopSelectorNode()
        
        builder.PushSelectorNode(factory.Sequence("SleepInBed?"))
            builder.PushNode(factory.Condition(function () return DayTime.IsBetween(Game.dayTime, GameConsts.goToSleepDayTime, GameConsts.goToSleepImmediatelyDayTime) end))
            builder.PushNode(factory.Rule(sleepInBedRule, "Sleep"))
        builder.PopSelectorNode()
        
        builder.PushSelectorNode(factory.Sequence("WakeUpInBed"))
            builder.PushNode(factory.Condition(function (character) return character.isSleeping end))
            builder.PushNode(factory.Rule(wakeUpInBedRule, "WakeUp"))
        builder.PopSelectorNode()
        
        builder.PushSelectorNode(factory.Sequence("WakeUp"))
            builder.PushNode(factory.Condition(function (character) return character.isSleeping end))
            builder.PushNode(factory.Action(Actions.CreateWakeUpImmediatelyAction(characterController.character), "WakeUp"))
        builder.PopSelectorNode()
        
        builder.PushSelectorNode(factory.Sequence("Leashed"))
            builder.PushNode(factory.IsBlackboardBoolTrue("isLeashed"))
            --TODO less discrete
            builder.PushNode(factory.MoveTo3dPosWithoutNavigation("leashedToPos", "leashLength"))
            builder.PushNode(factory.AlwaysFailed()) --moving freely after leash condition is satisfied
        builder.PopSelectorNode()
        
        builder.PushSelectorNode(factory.Sequence("EatSomething"))
        --TODO eat until really full if possible
            builder.PushSelectorNode(factory.Fallback("ShouldLookForFood"))
                builder.PushNode(factory.Condition(function (character) return character.hunger > 0.7 end))
                builder.PushNode(factory.IsBlackboardBoolTrue("LookingForFood"))
            builder.PopSelectorNode()
            builder.PushNode(factory.SetVariable("LookingForFood", true))
            builder.PushSelectorNode(factory.Fallback("EatSomething"))
                builder.PushNode(factory.Condition(function (character) return character.hunger < 0.4 end, "Is fed enough"))

                builder.PushSelectorNode(factory.Sequence("EatGrass"))
                    builder.PushNode(factory.IsBlackboardBoolTrue("canEatGrass"))
                    builder.PushNode(factory.Rule(eatGrassRule, "EatGrass"))
                builder.PopSelectorNode()

                for key, value in pairs(Actions:GetAllCombineRules(CellType.None, CellType.Eatable_Any, CellType.Any)) do
                    if value.newCharType == CellType.None then
                        builder.PushNode(factory.Rule(value, "Eat"))
                    end
                end
            builder.PopSelectorNode()
            builder.PushNode(factory.SetVariable("LookingForFood", false))
            builder.PushNode(factory.AlwaysFailed("Stopped looking for food"))
        builder.PopSelectorNode()

        builder.PushSelectorNode(factory.Sequence("Go to campfire"))
        --TODO less hardcode for temperature
        builder.PushNode(factory.Condition(function (character) return Game.dayTime >= GameConsts.goToCampfireDayTimePercent or Game:GetAmbientTemperature() < 0.5 end))
            builder.PushNode(factory.Func(
                --TODO sepate factory method for this 
                function (character, blackboard) 
                    local campfirePos = WorldQuery:FindNearestItem(CellType.CampfireWithWoodFired, character:GetIntPos())
                    if campfirePos == nil then
                        return BehaviourTree_Node.FAILED
                    end
                    --TODO account for current character position
                    local nearestEmpty = WorldQuery:FindNearestWalkable(campfirePos, 3)
                    if nearestEmpty == nil then
                        return BehaviourTree_Node.FAILED
                    end
                    blackboard.campfirePos = nearestEmpty
                    return BehaviourTree_Node.SUCCESS
                end
            ))
            builder.PushNode(factory.MoveToIntPos("campfirePos"))
            builder.PushNode(factory.AlwaysRunning("Standing near campfire"))
        builder.PopSelectorNode()

        builder.PushSelectorNode(factory.Fallback("Command_"))
            --added dynamicaly
        builder.PopSelectorNode()

        builder.PushSelectorNode(factory.Sequence("DropItem"))
            builder.PushNode(factory.Condition(function (character) return character.item ~= CellType.None and CellTypeUtils.IsPickable(character.item) end))
            builder.PushNode(factory.Func(
                function (character, blackboard) 
                    local rule = Actions:GetDropRule(character.item)
                    if not rule then
                        --TODO error
                       return BehaviourTree_Node.FAILED 
                    end
                    local action = WorldQuery:FindNearestActionFromRule(character, rule)
                    if not action then
                        return BehaviourTree_Node.FAILED 
                    end
                    return BehaviourTree_NodeFunctions.ExecAction(action)
                end
            ))
        builder.PopSelectorNode()
        
        builder.PushSelectorNode(factory.Sequence("Wander"))
        builder.PushNode(factory.Func(
            function (character, blackboard) 
                local pos = character.characterController:GetNearestWalkableIntPos()
                if not pos then
                    return BehaviourTree_Node.FAILED
                end
        
                local radius = 3
                local wanderPos = blackboard.wanderPos
                --TODO clamp to radius
                --TODO make separate function
                if not wanderPos or wanderPos == pos or not World.navigation:PathExists(pos, wanderPos) then
                    if not wanderPos then
                        wanderPos = Vector2Int.new()
                        blackboard.wanderPos = wanderPos
                    end
                    wanderPos.x = math.random(pos.x - radius, pos.x + radius)
                    wanderPos.y = math.random(pos.y - radius, pos.y + radius)
        
                    wanderPos.x = math.max(wanderPos.x, 0)
                    wanderPos.y = math.max(wanderPos.y, 0)
        
                    wanderPos.x = math.min(wanderPos.x, World.items.sizeX-1)
                    wanderPos.y = math.min(wanderPos.y, World.items.sizeY-1)
                end
                if not World.navigation:PathExists(pos, wanderPos) then
                    return BehaviourTree_Node.FAILED
                end
                return BehaviourTree_NodeFunctions.MoveToIntPos(character, wanderPos)
            end
        ))
        builder.PopSelectorNode()

    builder.PopSelectorNode()

    local tree = builder.EndTree()

    return tree
end

return CharacterControllerBehaviourTree