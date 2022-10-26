local Component               = require("Component")
local CharacterControllerBase = require("CharacterControllerBase")
local Utils                   = require "Utils"
local Game                    = require "Game"
local GameConsts              = require "GameConsts"
local Actions                 = require "Actions"
local CharacterControllerBase = require "CharacterControllerBase"
local Component               = require("Component")
local WorldQuery              = require("WorldQuery")
local CellType                = require("CellType")
local World                   = require("World")
local DayTime                = require("DayTime")
local BehaviourTree_Builder = require("BehaviourTree_Builder")
local CharacterControllerBehaviourTree = require("CharacterControllerBehaviourTree")

---@class SheepCharacterController: CharacterControllerBase
local SheepCharacterController = {
    isFollowingPlayer = false, --TODO not only player --TODO save state
    defaultMaxSpeed = 2.0
}

setmetatable(SheepCharacterController, CharacterControllerBase)
SheepCharacterController.__index = SheepCharacterController

function SheepCharacterController:new(o)
    o = Component:new(o)
    setmetatable(o, self)
    return o
end

function SheepCharacterController:OnEnable()
    CharacterControllerBase.OnEnable(self)

    self.defaultMaxSpeed = self.character.maxSpeed
end

function SheepCharacterController:CreateBehaviourTree()
    local tree = CharacterControllerBehaviourTree.Create(self)
    tree.blackboard.canEatGrass = true
    return tree
end

function SheepCharacterController:DrawRope()
    local from = self.character:GetPosition() + vector(0,0.5,0)
    local to = World.playerCharacter:GetPosition() + vector(0,0.3,0)

    for i = 0, 20, 1 do
        local pos = from + (to-from) * i / 20.0
        Dbg.DrawPoint(pos, 0.02)
    end
end

function SheepCharacterController:FixedUpdate()
    --TODO not here
    CharacterControllerBase.FixedUpdate(self)

    if self.isFollowingPlayer then
        --self.character.maxSpeed = (World.playerCharacter.maxSpeed + self.defaultMaxSpeed) / 2.0 --TODO not like that
        self:DrawRope()
        if self.behaviourTree then
            self.behaviourTree.blackboard.leashedToPos = World.playerCharacter:GetPosition()
            self.behaviourTree.blackboard.isLeashed = true
            self.behaviourTree.blackboard.leashLength = 0.5

        end
    else
        self.character.maxSpeed = self.defaultMaxSpeed
        if self.behaviourTree then
            self.behaviourTree.blackboard.leashedToPos = nil
            self.behaviourTree.blackboard.isLeashed = false
        end
    end
end

function SheepCharacterController:GetActionOnCharacter(character : Character)
	--TODO only for player
	local action = {}
	action.isCharacter = true
	action.selfCharacter = character
	action.otherCharacter = self.character
	function action:Execute()
        action.otherCharacter.characterController.isFollowingPlayer = not action.otherCharacter.characterController.isFollowingPlayer
    end
	return action
end

return SheepCharacterController
