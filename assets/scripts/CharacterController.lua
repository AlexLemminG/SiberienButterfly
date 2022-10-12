local CharacterCommandFactory = require "CharacterCommandFactory"
local Utils                   = require "Utils"
local Game                    = require "Game"
local GameConsts              = require "GameConsts"
local Actions                 = require "Actions"
local CharacterControllerBase = require "CharacterControllerBase"
local Component               = require("Component")

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

function CharacterController:Think()
    self.immediateTargetPos = nil
    self.desiredAction = nil

    --TODO
    local commandsPriorityList = {}

    if Game.dayTimePercent >= GameConsts.goToSleepImmediatelyTimePercent then
        table.insert(commandsPriorityList, CharacterCommandFactory.GoToSleepImmediately())
    elseif Game.dayTimePercent >= GameConsts.goToSleepDayTimePercent or
        Game.dayTimePercent <= GameConsts.wakeUpDayTimePercent then
        table.insert(commandsPriorityList, CharacterCommandFactory.GoToSleep())
    elseif self.character.isSleeping then
        table.insert(commandsPriorityList, CharacterCommandFactory.WakeUp())
        table.insert(commandsPriorityList, CharacterCommandFactory.WakeUpImmediately())
    end

    if self.character.hunger > 0.7 then
        --TODO eat until really full if possible
        table.insert(commandsPriorityList, CharacterCommandFactory.EatSomething())
    end

    if Game.dayTimePercent >= GameConsts.goToCampfireDayTimePercent then
        table.insert(commandsPriorityList, CharacterCommandFactory.GoToCampfire())
    end
    --table.insert(commandsPriorityList, CharacterCommandFactory.GoToPoint(1,13))

    if self.command then
        table.insert(commandsPriorityList, self.command)
    end

    table.insert(commandsPriorityList, CharacterCommandFactory.DropItem())

    table.insert(commandsPriorityList, CharacterCommandFactory.Wander())

    local currentCommand = nil
    for index, command in ipairs(commandsPriorityList) do
        -- print("A", self.playerAssignedRule)
        -- print(WorldQuery:FindNearestItem(self.playerAssignedRule.itemType, self.character:GetIntPos()))
        if command.OnEnable then
            command:OnEnable(self.character)
        end
        self.desiredAction = command:CalcNextAction(self.character)
        if self.desiredAction then
            currentCommand = command
            break
        end
    end

    --TODO drop current item if not needed

    if self.desiredAction then
        if self.desiredAction.intPos and (not self.currentPath or self.currentPath.to ~= self.desiredAction.intPos) then
            local intPos = self:GetNearestWalkableIntPos()
            self.currentPath = World.navigation:CalcPath(intPos, self.desiredAction.intPos)
            if not self.currentPath.isComplete then
                self.currentPath = nil
                if currentCommand.OnFailed then
                    currentCommand:OnFailed(self.character)
                else
                    LogWarning("Failed to find path (not handled)")
                    --TODO no path, so need to abandon this action
                end
            else
                self.currentPathPointIndex = 1
            end
        end
    end
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
