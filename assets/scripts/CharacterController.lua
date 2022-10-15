local Utils                   = require "Utils"
local Game                    = require "Game"
local GameConsts              = require "GameConsts"
local Actions                 = require "Actions"
local CharacterControllerBase = require "CharacterControllerBase"
local Component               = require("Component")
local DayTime                = require("DayTime")
local BehaviourTree          = require("BehaviourTree")
local BehaviourTree_Builder  = require("BehaviourTree_Builder")
local BehaviourTree_NodesFactory = require("BehaviourTree_NodesFactory")
local BehaviourTree_Node         = require("BehaviourTree_Node")
local BehaviourTree_NodeFunctions= require("BehaviourTree_NodeFunctions")
local CharacterControllerBehaviourTree = require("CharacterControllerBehaviourTree")


--TODO use mini fsm instead if command
--save them to state with current desired action

---@class CharacterController: CharacterControllerBase
local CharacterController = {
    commandNode = nil,
    commandAdded = false
}
setmetatable(CharacterController, CharacterControllerBase)
CharacterController.__index = CharacterController

local WorldQuery = require("WorldQuery")
local CellType = require("CellType")
local World = require("World")

function CharacterController:new(o)
    o = Component:new(o)
    setmetatable(o, self)
    return o
end

function CharacterController:CreateBehaviourTree() : BehaviourTree|nil
    local tree = CharacterControllerBehaviourTree.Create(self)
    return tree
end

function CharacterController:GetActionOnCharacter(character : Character)
	--TODO only for player
	local action = {}
	action.isCharacter = true
	action.selfCharacter = character
	action.otherCharacter = self.character
	function action:Execute()
			if Game.currentDialog then
				Game:EndDialog()
			else
				Game:BeginDialog(self.selfCharacter, self.otherCharacter)
			end
		end
	return action
end

function CharacterController:Think()
    if self.behaviourTree then
        if self.commandNode and (not self.command or not self.commandAdded) then
            self.behaviourTree:RemoveNode(self.commandNode)
            self.commandNode = nil
            self.commandAdded = false
        end
        if self.command and not self.commandAdded then
            self.commandAdded = true

            self.commandNode = BehaviourTree_NodesFactory.Func(
                function (character, blackboard) 
                    local nearestAction = nil
                    local nearestActionDistance = math.huge
                    local characterIntPos = character:GetIntPos()
                    for index, rule in ipairs(character.characterController.command.rules) do
                        local action = WorldQuery:FindNearestActionFromRule(character, rule)
                        if action then
                            if not action.intPos then
                                nearestAction = action
                                nearestActionDistance = 0.0
                                break
                            end
                            local distance = length(vector(action.intPos.x - characterIntPos.x, 0, action.intPos.y - characterIntPos.y))
                            if distance < nearestActionDistance then
                                nearestActionDistance = distance
                                nearestAction = action
                            end
                        end
                    end
                    if nearestAction then
                        local res = BehaviourTree_NodeFunctions.ExecAction(nearestAction)
                        if res ~= BehaviourTree_Node.FAILED then
                            return res
                        end
                    end
                    --TODO not always ?
                    if character.item ~= CellType.None then
                        local dropRule = Actions:GetDropRule(character.item)
                        if not dropRule then
                            return BehaviourTree_Node.FAILED
                        end
                        local action = WorldQuery:FindNearestActionFromRule(character, dropRule)
                        if not action then
                            return BehaviourTree_Node.FAILED
                        end
                        local dropResult = BehaviourTree_NodeFunctions.ExecAction(action)
                        if dropResult ~= BehaviourTree_Node.SUCCESS then
                            return dropResult
                        end
                    end

                    for index, rule in ipairs(character.characterController.command.rules) do
                        if rule.charType ~= character.item then
                            local pickRule = Actions:GetPickupRule(rule.charType)
                            if not pickRule then
                                continue
                            end
                            local pickActionPos = WorldQuery:FindNearestActionPosFromRule(pickRule, characterIntPos)
                            if not pickActionPos then
                                continue
                            end
                            local nextActionPos = WorldQuery:FindNearestActionPosFromRule(rule, pickActionPos)
                            if not nextActionPos then
                                continue
                            end
                            local pickAction = WorldQuery:FindNearestActionFromRule(character, pickRule)
                            if not pickAction then
                                --TODO error
                                continue
                            end
                            local distance = length(vector(pickAction.intPos.x - characterIntPos.x, 0, pickAction.intPos.y - characterIntPos.y))
                            distance = distance + length(vector(pickAction.intPos.x - nextActionPos.x, 0, pickAction.intPos.y - nextActionPos.y))
                            if distance < nearestActionDistance then
                                nearestAction = pickAction
                                nearestActionDistance = distance
                            end
                        end
                    end
                    if not nearestAction then
                        return BehaviourTree_Node.FAILED
                    end
                    return BehaviourTree_NodeFunctions.ExecAction(nearestAction)
                end
            , "CommandFromPlayer")
            self.behaviourTree:AddNode(self.commandNode, "Command_")
        end
    end
    
    CharacterControllerBase.Think(self)
end

return CharacterController
