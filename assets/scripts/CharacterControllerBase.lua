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

--TODO use strings instead of ints for cellTypes in saves (or use something like blender dna)

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
    currentPathPointIndex = 0,
    commandState = {},
    behaviourTree = nil,
    updateOrderIndex = 0
}
local Component = require("Component")
setmetatable(CharacterControllerBase, Component)
CharacterControllerBase.__index = CharacterControllerBase


function CharacterControllerBase:new(o)
    o = Component:new(o)
    setmetatable(o, self)
    return o
end

function SaveCommand(command) 
    local savedCommand = {}
    
    savedCommand.type = command.type
    savedCommand.rules = command.rules
    savedCommand.bringTarget = command.bringTarget
    savedCommand.marking = command.marking

    return savedCommand
end

function LoadCommand(savedCommand) 
    local command = {}
    
    command.type = savedCommand.type
    local rules = {}
    for index, rule in ipairs(savedCommand.rules) do
        local realRule = Actions:GetCombineRuleFromSavable(rule)
        if realRule then
            table.insert(rules, realRule)
        else
            --TODO error
        end
    end
    command.rules = rules
    command.bringTarget = savedCommand.bringTarget
    command.marking = savedCommand.marking

    return command
end

function CharacterControllerBase:SaveState() : any
    local state = {}
    if self.command then
        state.command = SaveCommand(self.command)
    end
    return state
end

function CharacterControllerBase:LoadState(savedState)
    if not savedState then
        return
    end
    --TODO ensure loaded rules are still valid
    if savedState.command then
        self.commandAdded = false --TODO more accurate (this is CharacterController variable actualy)
        self.command = LoadCommand(savedState.command)
    end
end

--TODO Create... functions to different file
---@param rules : CombineRule[]
function CharacterControllerBase.CreateCommandFromRules(rules)
    local command = {
        --TODO named const
        type = "Combine",
        rules = rules,
    }
    return command
end

function CharacterControllerBase.AddMarkingToCommand(command, marking)
    command.marking = marking
end

function CharacterControllerBase.CreateBringCommand(bringWhatCellType, bringToCellType)
    local types = Actions:GetAllIsSubtype(bringWhatCellType)
    local rules = {}
    for index, cellType in ipairs(types) do
        local dropRule = Actions:GetDropRule(cellType)
        if dropRule then
            table.insert(rules, dropRule)
        end
    end
    local command = {
        --TODO named const
        type = "Bring",
        bringTarget = bringToCellType,
        rules = rules
    }
    return command
end

function CharacterControllerBase:GetCommand()
    return self.command
end

function CharacterControllerBase:SetCommand(command)
    self.commandAdded = false --TODO more accurate (this is CharacterController variable actualy)
    self.command = command
end

---@param rules : CombineRule[]
function CharacterControllerBase:SetCommandFromRules(rules) 
    self.commandAdded = false --TODO more accurate (this is CharacterController variable actualy)
    self.command = CharacterControllerBase.CreateCommandFromRules(rules)
end

---@param rules : CombineRule[]
function CharacterControllerBase:SetBringCommand(bringWhatCellType, bringToCellType) 
    self.commandAdded = false --TODO more accurate (this is CharacterController variable actualy)
    self.command = CharacterControllerBase.CreateBringCommand(bringWhatCellType, bringToCellType)
end

function CharacterControllerBase:OnEnable()
    self.character = self:gameObject():GetComponent("LuaComponent") --TODO GetLuaComponent
    self.character.characterController = self
    self.commandState = {}
end

function CharacterControllerBase:GetActionOnCharacter(character : Character)
    return nil
end

function CharacterControllerBase:FixedUpdate()
    local thinkEveryNFrames = 10
    local needToThink = (self.updateOrderIndex + Time.fixedFrameCount()) % thinkEveryNFrames == 0
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
            intPos = Grid.GetClosestIntPos(pos)
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
    local targetPoint = self.currentPath.points[self.currentPathPointIndex]

    if characterIntPos == targetPoint then
        if self.currentPath.points:size() > self.currentPathPointIndex then
            self.currentPathPointIndex = self.currentPathPointIndex + 1
            targetPoint = self.currentPath.points[self.currentPathPointIndex]
        else
            --TODO some event?
            self.currentPath = nil
            return
        end
    end

    if not World.navigation:PathExists(targetPoint, self.currentPath.to) then
        --TODO some event?
        self.currentPath = nil
        return
    end

    self.immediateTargetPos = World.items:GetCellWorldCenter(targetPoint)
    if World.items:GetCell(targetPoint).type ~= CellType.None or World.items:GetCell(characterIntPos).type ~= CellType.None then
        if self.currentPath.points:size() > self.currentPathPointIndex then
            --assuming not walkable through center
            local nextIntPos = self.currentPath.points[self.currentPathPointIndex+1]
            local delta = nextIntPos - targetPoint
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
        local trans = self.character.rigidBody:GetTransform()
        local pos = Mathf.GetPos(trans)
        local velocity = self.immediateTargetPos - pos
        velocity = velocity * 30.0
        local l = length(velocity)
        local maxSpeed = self.character.maxSpeed
        
        if l > maxSpeed then
            velocity = velocity * maxSpeed / l
        end
        
        self.character:SetVelocity(velocity)
    else
        self.character:SetVelocity(vector(0, 0, 0))
    end
end

return CharacterControllerBase
