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

function CharacterController:OnEnable()
    self.character = self:gameObject():GetComponent("LuaComponent") --TODO GetLuaComponent
    self.character.characterController = self
end

function CharacterController:Update()
    self:Think()
    self:Act()
end

function CharacterController:Think()
    self.immediateTargetPos = nil
    self.desiredAction = nil

    -- local closestWheat = WorldQuery:FindNearestItem(CellType.Bread_1, self.character:GetIntPos())
    -- if closestWheat then
    --     self.immediateTargetPos = closestWheat
    --     self.desiredAction = self.character:GetActionOnCellPos(closestWheat)
    -- end

    if self.command then
        -- print("A", self.playerAssignedRule)
        -- print(WorldQuery:FindNearestItem(self.playerAssignedRule.itemType, self.character:GetIntPos()))
        self.desiredAction = self.command:CalcNextAction(self.character)
        -- print(self.desiredAction)
    end

    if self.desiredAction then
        if self.desiredAction.intPos then
            self.immediateTargetPos = self.desiredAction.intPos
        end
    end
end

function CharacterController:Act()
    if self.desiredAction then
        if self.character:GetIntPos() == self.desiredAction.intPos then
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
