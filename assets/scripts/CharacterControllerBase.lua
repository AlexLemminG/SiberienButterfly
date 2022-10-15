local Utils                   = require "Utils"
local Game                   = require "Game"
local GameConsts                   = require "GameConsts"
local Actions                   = require "Actions"
local WorldQuery = require("WorldQuery")
local CellType = require("CellType")
local World = require("World")
local BehaviourTree = require("BehaviourTree")

--TODO use mini fsm instead if command
--save them to state with current desired action

---@class CharacterControllerBase
---@field command CharacterCommand|nil
---@field character Character|nil
---@field behaviourTree BehaviourTree|nil
local CharacterControllerBase = {
    character = nil,
    immediateTargetPos = nil,
    desiredAction = nil,
    command = nil,
    currentPath = nil,
    isRunning = false,
    currentPathPointIndex = 0,
    commandState = {},
    behaviourTree = nil
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
    local state = {}
    if self.command then
        state.command = {
            rules = self.command.rules
        }
    end
    return state
end

function CharacterControllerBase:LoadState(savedState)
    if not savedState then
        return
    end
    --TODO ensure loaded rules are still valid
    if savedState.command then
        local rules = {}
        for index, rule in ipairs(savedState.command.rules) do
            local realRule = Actions:GetCombineRuleFromSavable(rule)
            if realRule then
                table.insert(rules, realRule)
            else
                --TODO error
            end
        end
        self:SetCommandFromRules(rules)
    end
end

---@param rules : CombineRule[]
function CharacterControllerBase:SetCommandFromRules(rules) 
    self.commandAdded = false --TODO more accurate (this is CharacterController variable actualy)
    
    self.command = {
        rules = rules
    }
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

function CharacterControllerBase:CreateBehaviourTree() : BehaviourTree|nil
    return nil
end

function CharacterControllerBase:Think()
    self.immediateTargetPos = nil
    self.desiredAction = nil


    --TODO do not check on every Think
    if not self.behaviourTree then
        self.behaviourTree = self:CreateBehaviourTree()
    end
    if self.behaviourTree then
        self.behaviourTree:Update()
        return
    end
end

function CharacterControllerBase:UpdatePathFollowing()
    if not self.currentPath then
        return
    end
    local characterIntPos = self.character:GetIntPos()

    if characterIntPos == self.currentPath.points[self.currentPathPointIndex] then
        if self.currentPath.points:size() > self.currentPathPointIndex then
            self.currentPathPointIndex = self.currentPathPointIndex + 1
        else
            --TODO some event?
            self.currentPath = nil
            return
        end
    end

    if not World.navigation:PathExists(self.currentPath.points[self.currentPathPointIndex], self.currentPath.to) then
        --TODO some event?
        self.currentPath = nil
        return
    end

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
    end
end

function CharacterControllerBase:Act()
    self:UpdatePathFollowing()
    -- Game.DbgDrawPath(self.currentPath)
    if self.desiredAction and self.character:CanExecuteAction(self.desiredAction) then
        if self.character:GetIntPos() == self.desiredAction.intPos or self.desiredAction.intPos == nil then
            self.character:ExecuteAction(self.desiredAction)
        end
    end
    if self.immediateTargetPos then
        local velocity = self.immediateTargetPos - self.character.transform:GetPosition()
        velocity = velocity * 30.0
        local l = length(velocity)
        local maxSpeed = self.character.maxSpeed
        if not self.isRunning then
            maxSpeed = maxSpeed * self.character.walkingMaxSpeedMultiplier
        end
        if l > maxSpeed then
            velocity = velocity * maxSpeed / l
        end
        
        self.character:SetVelocity(velocity)
    else
        self.character:SetVelocity(vector(0, 0, 0))
    end
end

return CharacterControllerBase
