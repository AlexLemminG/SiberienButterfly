local BehaviourTree = require "BehaviourTree"
local BehaviourTree_Node = require "BehaviourTree_Node"
local BehaviourTree_NodesFactory = require "BehaviourTree_NodesFactory"
local Builder = {
    currentTree = nil,
    currentNode = nil,

    currentNodeStack = {}
}

function Builder.Begin(characterController : CharacterController)
    --TODO assert currentTree is nil

    Builder.currentTree = BehaviourTree.new(characterController)
    Builder.currentTree.rootNode = BehaviourTree_NodesFactory.Root()
    Builder.currentNode = Builder.currentTree.rootNode 
end

function Builder.PushNode(node : BehaviourTree_Node)
    node.character = Builder.currentTree.character
    node.blackboard = Builder.currentTree.blackboard

    if node.name then
        Builder.currentTree.namedNodes[node.name] = node
    end
    table.insert(Builder.currentNode.children, node)
end

function Builder.PushSelectorNode(node : BehaviourTree_Node)
    Builder.PushNode(node)
    Builder.currentNode = node
    table.insert(Builder.currentNodeStack, node)
end

function Builder.PopSelectorNode()
    table.remove(Builder.currentNodeStack, #Builder.currentNodeStack)
    Builder.currentNode = Builder.currentNodeStack[#Builder.currentNodeStack]
end

function Builder.End() : BehaviourTree
    --TODO check for errors
    --node stack size == 1
    --root node has 1 child max
    
    local tree = Builder.currentTree

    Builder.currentTree = nil
    Builder.currentNode = nil

    return tree
end

return Builder