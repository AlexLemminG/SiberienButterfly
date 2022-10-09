local CharacterCommandFactory = require "CharacterCommandFactory"
local Utils                   = require "Utils"
local Game                   = require "Game"
local GameConsts                   = require "GameConsts"
local Actions                   = require "Actions"

---@class CharacterController
---@field command CharacterCommand|nil
---@field character Character|nil
local CharacterController = {
    character = nil,
    immediateTargetPos = nil,
    desiredAction = nil,
    command = nil
}
local Component = require("Component")
setmetatable(CharacterController, Component)
CharacterController.__index = CharacterController

local WorldQuery = require("WorldQuery")
local CellType = require("CellType")
local World = require("World")

function CharacterController:new(o)
    o = Component:new(o)
    setmetatable(o, self)
    return o
end

function CharacterController:SaveState() : any
    local state = {
        command = CharacterCommandFactory:SaveToState(self.command)
    }
    return state
end

function CharacterController:LoadState(savedState)
    if not savedState then
        return
    end
    self.command = CharacterCommandFactory:LoadFromState(savedState.command)
end

function CharacterController:OnEnable()
    self.character = self:gameObject():GetComponent("LuaComponent") --TODO GetLuaComponent
    self.character.characterController = self
end

function CharacterController:Update()
    local needToThink = Utils.ArrayIndexOf(World.characters, self.character) == (Time.frameCount() % #World.characters) + 1
    if needToThink then
        self:Think()
    end
    self:Act()
end

function CharacterController:Think()
    self.immediateTargetPos = nil
    self.desiredAction = nil

    --TODO 
    local commandsPriorityList = {}

    if Game.dayTimePercent >= GameConsts.goToSleepImmediatelyTimePercent then
        table.insert(commandsPriorityList, CharacterCommandFactory.GoToSleepImmediately())
    elseif Game.dayTimePercent >= GameConsts.goToSleepDayTimePercent or Game.dayTimePercent <= GameConsts.wakeUpDayTimePercent then
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

    if self.command then
        table.insert(commandsPriorityList, self.command)
    end 
    
    
    for index, command in ipairs(commandsPriorityList) do
        -- print("A", self.playerAssignedRule)
        -- print(WorldQuery:FindNearestItem(self.playerAssignedRule.itemType, self.character:GetIntPos()))
        self.desiredAction = command:CalcNextAction(self.character)
        if self.desiredAction then
            break
        end
    end

    if self.desiredAction then
         if self.desiredAction.intPos then
            self.immediateTargetPos = self.desiredAction.intPos
        end
    end
end

function CharacterController:Act()
    if self.desiredAction and self.character:CanExecuteAction(self.desiredAction) then
        if self.character:GetIntPos() == self.desiredAction.intPos or self.desiredAction.intPos == nil then
            self.character:ExecuteAction(self.desiredAction)
        end
    end
    if self.immediateTargetPos then
        local dir = vector(self.immediateTargetPos.x, 0, self.immediateTargetPos.y) -
            self.character.transform:GetPosition()
        dir = dir * 3.0
        self.character:SetVelocity(dir)
    else
        self.character:SetVelocity(vector(0, 0, 0))
    end
end

return CharacterController
