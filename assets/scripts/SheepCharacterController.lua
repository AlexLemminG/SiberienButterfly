local Component               = require("Component")
local CharacterControllerBase = require("CharacterControllerBase")
local CharacterCommandFactory = require "CharacterCommandFactory"
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

function SheepCharacterController:GetCommandsPriorityList()
    local commandsPriorityList = {}


    if DayTime.IsBetween(Game.dayTime, GameConsts.goToSleepImmediatelyDayTime, GameConsts.wakeUpDayTime) then
        table.insert(commandsPriorityList, CharacterCommandFactory.GoToSleepImmediately())
    elseif DayTime.IsBetween(Game.dayTime, GameConsts.goToSleepDayTime, GameConsts.goToSleepImmediatelyDayTime) then
        table.insert(commandsPriorityList, CharacterCommandFactory.GoToSleep())
    elseif self.character.isSleeping then
        table.insert(commandsPriorityList, CharacterCommandFactory.WakeUp())
        table.insert(commandsPriorityList, CharacterCommandFactory.WakeUpImmediately())
    end
    
    if self.isFollowingPlayer then
        table.insert(commandsPriorityList, CharacterCommandFactory.FollowCharacter(World.playerCharacter))
    end

    if self.character.hunger > 0.1 then
        --TODO eat until really full if possible
        table.insert(commandsPriorityList, CharacterCommandFactory.EatGrass())
    end

    if Game.dayTime >= GameConsts.goToCampfireDayTimePercent then
        table.insert(commandsPriorityList, CharacterCommandFactory.GoToCampfire())
    end

    table.insert(commandsPriorityList, CharacterCommandFactory.Wander())

    return commandsPriorityList
end

function SheepCharacterController:DrawRope()
    local from = self.character:GetPosition() + vector(0,0.5,0)
    local to = World.playerCharacter:GetPosition() + vector(0,0.3,0)

    for i = 0, 20, 1 do
        local pos = from + (to-from) * i / 20.0
        Dbg.DrawPoint(pos, 0.02)
    end
end

function SheepCharacterController:Update()
    --TODO not here
    CharacterControllerBase.Update(self)

    if self.isFollowingPlayer then
        --self.character.maxSpeed = (World.playerCharacter.maxSpeed + self.defaultMaxSpeed) / 2.0 --TODO not like that
        self:DrawRope()
    else
        self.character.maxSpeed = self.defaultMaxSpeed
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
