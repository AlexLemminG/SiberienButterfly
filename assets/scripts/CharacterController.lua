local CharacterCommandFactory = require "CharacterCommandFactory"
local Utils                   = require "Utils"
local Game                    = require "Game"
local GameConsts              = require "GameConsts"
local Actions                 = require "Actions"
local CharacterControllerBase = require "CharacterControllerBase"
local Component               = require("Component")
local DayTime                = require("DayTime")

--TODO use mini fsm instead if command
--save them to state with current desired action

---@class CharacterController: CharacterControllerBase
local CharacterController = {
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

function CharacterController:GetCommandsPriorityList()
    local commandsPriorityList = {}

    if DayTime.IsBetween(Game.dayTime, GameConsts.goToSleepImmediatelyDayTime, GameConsts.wakeUpDayTime) then
        table.insert(commandsPriorityList, CharacterCommandFactory.GoToSleepImmediately())
    elseif DayTime.IsBetween(Game.dayTime, GameConsts.goToSleepDayTime, GameConsts.goToSleepImmediatelyDayTime) then
        table.insert(commandsPriorityList, CharacterCommandFactory.GoToSleep())
    elseif self.character.isSleeping then
        table.insert(commandsPriorityList, CharacterCommandFactory.WakeUp())
        table.insert(commandsPriorityList, CharacterCommandFactory.WakeUpImmediately())
    end

    if self.character.hunger > 0.7 then
        --TODO eat until really full if possible
        table.insert(commandsPriorityList, CharacterCommandFactory.EatSomething())
    end

    if Game.dayTime >= GameConsts.goToCampfireDayTimePercent then
        table.insert(commandsPriorityList, CharacterCommandFactory.GoToCampfire())
    end
    --table.insert(commandsPriorityList, CharacterCommandFactory.GoToPoint(1,13))

    if self.command then
        table.insert(commandsPriorityList, self.command)
    end

    table.insert(commandsPriorityList, CharacterCommandFactory.DropItem())

    table.insert(commandsPriorityList, CharacterCommandFactory.Wander())

    return commandsPriorityList
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

return CharacterController
