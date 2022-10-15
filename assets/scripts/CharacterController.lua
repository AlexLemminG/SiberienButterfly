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
                    if not character.characterController.command then
                        return BehaviourTree_Node.FAILED
                    end
                    for index, rule in ipairs(character.characterController.command.rules) do
                        local action = WorldQuery:FindNearestActionFromRule(character, rule)
                        if action then
                            local res = BehaviourTree_NodeFunctions.ExecAction(action)
                            if res ~= BehaviourTree_Node.FAILED then
                                return res
                            end
                        end
                    end
                    for index, rule in ipairs(character.characterController.command.rules) do
                        if rule.charType ~= character.item then
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

                            local pickRule = Actions:GetPickupRule(rule.charType)
                            if not pickRule then
                                continue
                            end
                            local pickAction = WorldQuery:FindNearestActionFromRule(character, pickRule)
                            if not pickAction then
                                continue
                            end
                            local pickResult = BehaviourTree_NodeFunctions.ExecAction(pickAction)
                            if pickResult == BehaviourTree_Node.FAILED then
                                continue
                            end
                            if pickResult == BehaviourTree_Node.RUNNING then
                                return BehaviourTree_Node.RUNNING
                            end
                        end
                        local action = WorldQuery:FindNearestActionFromRule(character, rule)
                        if action then
                            local res = BehaviourTree_NodeFunctions.ExecAction(action)
                            if res ~= BehaviourTree_Node.FAILED then
                                return res
                            end
                        end
                    end
                    return BehaviourTree_Node.FAILED
                end
            , "CommandFromPlayer")
            self.behaviourTree:AddNode(self.commandNode, "Command_")
        end
    end
    
    CharacterControllerBase.Think(self)
end

return CharacterController
