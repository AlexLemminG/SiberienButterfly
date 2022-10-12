local CharacterCommandFactory = require "CharacterCommandFactory"
local Utils                   = require "Utils"
local Game                   = require "Game"
local GameConsts                   = require "GameConsts"
local Actions                   = require "Actions"
local WorldQuery = require("WorldQuery")
local CellType = require("CellType")
local World = require("World")

--TODO use mini fsm instead if command
--save them to state with current desired action

---@class CharacterControllerBase
---@field command CharacterCommand|nil
---@field character Character|nil
local CharacterControllerBase = {
    character = nil,
    immediateTargetPos = nil,
    desiredAction = nil,
    command = nil,
    currentPath = nil,
    currentPathPointIndex = 0,
    commandState = {}
}
local Component = require("Component")
setmetatable(CharacterControllerBase, Component)
CharacterControllerBase.__index = CharacterControllerBase


function CharacterControllerBase:new(o)
    o = Component:new(o)
    setmetatable(o, self)
    return o
end

function CharacterControllerBase:SaveState() : any
    local state = {
        command = CharacterCommandFactory:SaveToState(self.command)
    }
    return state
end

function CharacterControllerBase:LoadState(savedState)
    if not savedState then
        return
    end
    self.command = CharacterCommandFactory:LoadFromState(savedState.command)
end

function CharacterControllerBase:OnEnable()
    self.character = self:gameObject():GetComponent("LuaComponent") --TODO GetLuaComponent
    self.character.characterController = self
    self.commandState = {}
end

function CharacterControllerBase:GetActionOnCharacter(character : Character)
    return nil
end

function CharacterControllerBase:Update()
    local needToThink = Utils.ArrayIndexOf(World.characters, self.character) == (Time.frameCount() % #World.characters) + 1
    if needToThink then
        self:Think()
    end
    self:Act()
end

function CharacterControllerBase:GetNearestWalkableIntPos()
    local originalPos = self.character:GetPosition()
    local intPos = nil
    local pos = nil
    local navigation = World.navigation

    local minDistance = 20
    local minIntPos = nil

    for dx = -1, 1, 1 do
        for dy = -1, 1, 1 do
            pos = originalPos + vector(dx * 0.5, 0, dy*0.5)
            intPos = World.items:GetClosestIntPos(pos)
            if navigation:IsWalkable(intPos.x, intPos.y) then
                local distance = dx * dx + dy*dy
                if distance < minDistance then
                    minDistance = distance
                    minIntPos = intPos
                end
            end
        end
    end

    return minIntPos
end

function CharacterControllerBase:Think()

end

function CharacterControllerBase:UpdatePathFollowing()
    if self.currentPath == nil then
        return
    end
    local characterIntPos = self.character:GetIntPos()

    if characterIntPos == self.currentPath.points[self.currentPathPointIndex] then
        if self.currentPath.points:size() > self.currentPathPointIndex then
            self.currentPathPointIndex = self.currentPathPointIndex + 1
        else
            --TODO some event?
            self.currentPath = nil
        end
    end

    if self.currentPath then
        local intPos = self.currentPath.points[self.currentPathPointIndex]
        self.immediateTargetPos = World.items:GetCellWorldCenter(intPos)
        if World.items:GetCell(intPos).type ~= CellType.None or World.items:GetCell(characterIntPos).type ~= CellType.None then
            if self.currentPath.points:size() > self.currentPathPointIndex then
                --assuming not walkable through center
                local nextIntPos = self.currentPath.points[self.currentPathPointIndex+1]
                local delta = nextIntPos - intPos
                local offset = vector(-delta.y * 0.3, 0.0, delta.x * 0.3)
                self.immediateTargetPos = self.immediateTargetPos + offset
            end
        else
            
        end
    end
end

function CharacterControllerBase:Act()
    self:UpdatePathFollowing()
    --Game.DbgDrawPath(self.currentPath)
    if self.desiredAction and self.character:CanExecuteAction(self.desiredAction) then
        if self.character:GetIntPos() == self.desiredAction.intPos or self.desiredAction.intPos == nil then
            self.character:ExecuteAction(self.desiredAction)
        end
    end
    if self.immediateTargetPos then
        local dir = self.immediateTargetPos - self.character.transform:GetPosition()
        dir = dir * 30.0
        self.character:SetVelocity(dir)
    else
        self.character:SetVelocity(vector(0, 0, 0))
    end
end

return CharacterControllerBase
