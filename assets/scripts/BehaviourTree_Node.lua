local Character = require "Character"

---@class BehaviorTree_Node
---@field character Character
local BehaviorTree_Node = {
    SUCCESS = 1,
    RUNNING = 2,
    FAILED = 0,

    character = nil, 
    blackboard = nil,
    name = nil
}


function BehaviorTree_Node.new(name : string)
    local node = {}
    node.name = name
    setmetatable(node, BehaviorTree_Node)
    return node
end

function BehaviorTree_Node:Update() : integer
    --TODO log warning
    return BehaviorTree_Node.FAILED
end

BehaviorTree_Node.__index = BehaviorTree_Node

return BehaviorTree_Node
