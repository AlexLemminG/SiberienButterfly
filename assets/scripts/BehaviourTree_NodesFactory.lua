local BehaviourTree_Node = require "BehaviourTree_Node"
local World              = require "World"
local Actions            = require "Actions"
local WorldQuery         = require "WorldQuery"
local BehaviourTree_NodeFunctions = require "BehaviourTree_NodeFunctions"

local Factory = {}

---@param condition fun(character : Character) : boolean
---@param name? string
function Factory.Condition(condition, name)
    local node = BehaviourTree_Node.new(name or "Condition")
    node.condition = condition
    function node:Update() : integer
        if self.condition(self.character) then
            return BehaviourTree_Node.SUCCESS
        else
            return BehaviourTree_Node.FAILED
        end
    end
    return node
end

function Factory.SetVariable(varName, varValue, name)
    local node = BehaviourTree_Node.new(name or "SetVariable")
    node.varName = varName
    node.varValue = varValue
    function node:Update() : integer
        self.blackboard[self.varName] = self.varValue
        return BehaviourTree_Node.SUCCESS
    end
    return node
end

---@param func fun(character : Character, blackboard) : integer
---@param name? string
function Factory.Func(func, name)
    local node = BehaviourTree_Node.new(name or "Func")
    node.func = func
    function node:Update() : integer
        return self.func(self.character, self.blackboard)
    end
    return node
end

function Factory.IsBlackboardBoolTrue(varName, name)
    local node = BehaviourTree_Node.new(name or "IsBlackboardBoolTrue")
    function node:Update() : integer
        local val = self.blackboard[varName]
        if val then
            return BehaviourTree_Node.SUCCESS
        else
            return BehaviourTree_Node.FAILED
        end
    end
    return node
end

function Factory.AlwaysSuccess(name)
    local node = BehaviourTree_Node.new(name or "AlwaysSuccess")
    function node:Update() : integer
        return BehaviourTree_Node.SUCCESS
    end
    return node
end
function Factory.AlwaysFailed(name)
    local node = BehaviourTree_Node.new(name or "AlwaysFailed")
    function node:Update() : integer
        return BehaviourTree_Node.FAILED
    end
    return node
end
function Factory.AlwaysRunning(name)
    local node = BehaviourTree_Node.new(name or "AlwaysRunning")
    function node:Update() : integer
        return BehaviourTree_Node.RUNNING
    end
    return node
end

function Factory.MoveToIntPos(posName, name)
    local node = BehaviourTree_Node.new(name or "MoveToIntPos")
    function node:Update() : integer
        local pos = self.blackboard[posName]
        if not pos then
            --TODO error
            return BehaviourTree_Node.FAILED
        end
        return BehaviourTree_NodeFunctions.MoveToIntPos(self.character, pos)
    end
    return node
end

function Factory.MoveTo3dPosWithoutNavigation(posName, stopRadius:number|string, name)
    local node = BehaviourTree_Node.new(name or "MoveTo3dPosWithoutNavigation")
    node.stopRadius = stopRadius
    function node:Update() : integer
        local pos = self.blackboard[posName]
        if not pos then
            --TODO error
            return BehaviourTree_Node.FAILED
        end
        local radius = self.stopRadius
        if type(radius) == "string" then
            radius = self.blackboard[stopRadius]
            --TODO error if not number
        end
        if not radius or not type(radius) == "number" then 
            radius = 3.0 
        end
        return BehaviourTree_NodeFunctions.MoveTo3dPosWithoutNavigation(self.character, pos, radius)
    end
    return node
end

---@param name? string
function Factory.Action(action : CharacterAction, name)
    local node = BehaviourTree_Node.new(name or "Action")
    node.action = action
    --TODO move blackboard and character to node class as fields
    function node:Update() : integer
        return BehaviourTree_NodeFunctions.ExecAction(self.action)
    end
    return node
end

---@param name? string
function Factory.Rule(rule : CombineRule, name)
    local node = BehaviourTree_Node.new(name or "Action")
    node.rule = rule
    --TODO move blackboard and character to node class as fields
    function node:Update() : integer
        local action = WorldQuery:FindNearestActionFromRule(self.character, self.rule)
        if action then
            return BehaviourTree_NodeFunctions.ExecAction(action)
        else
            return BehaviourTree_Node.FAILED
        end
    end
    return node
end

function Factory.Root(name)
    return Factory.Sequence(name or "Root")
end

---@param name? string
function Factory.Sequence(name)
    local node = BehaviourTree_Node.new(name or "Sequence")
    ---@type BehaviorTree_Node[]
    node.children = {}
    function node:Update() : integer
        for index, node in ipairs(self.children) do
            local nodeResult = node:Update()
            if nodeResult ~= BehaviourTree_Node.SUCCESS then
                return nodeResult
            end
        end
        return BehaviourTree_Node.SUCCESS
    end
    return node
end

---@param name? string
function Factory.Fallback(name)
    local node = BehaviourTree_Node.new(name or "Fallback")
    ---@type BehaviorTree_Node[]
    node.children = {}
    function node:Update() : integer
        for index, node in ipairs(self.children) do
            local nodeResult = node:Update()
            if nodeResult ~= BehaviourTree_Node.FAILED then
                return nodeResult
            end
        end
        return BehaviourTree_Node.FAILED
    end
    return node
end

return Factory
