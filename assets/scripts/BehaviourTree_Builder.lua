local BehaviourTree = require "BehaviourTree"
local BehaviourTree_Node = require "BehaviourTree_Node"
local BehaviourTree_NodesFactory = require "BehaviourTree_NodesFactory"
local Builder = {
    currentTree = nil,
    currentNode = nil,
    currentBlackboard = nil,
    currentCharacter = nil,

    currentNodeStack = {}
}

function Builder.BeginTree(characterController : CharacterController)
    --TODO assert currentTree is nil

    Builder.currentTree = BehaviourTree.new(characterController)
    Builder.currentBlackboard = Builder.currentTree.blackboard
    Builder.currentTree.rootNode = BehaviourTree_NodesFactory.Root()
    Builder.currentNode = Builder.currentTree.rootNode
    Builder.currentCharacter = characterController.character
    table.insert(Builder.currentNodeStack, Builder.currentNode)
end

function Builder.BeginNode(characterController : CharacterController)
    --TODO assert currentTree is nil

    Builder.currentBlackboard = {}
    Builder.currentNode = BehaviourTree_NodesFactory.Root()
    Builder.currentCharacter = characterController.character
    table.insert(Builder.currentNodeStack, Builder.currentNode)
end

function Builder.PushNode(node : BehaviourTree_Node)
    node.character = Builder.currentCharacter
    node.blackboard = Builder.currentBlackboard

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

function Builder.Cleanup() : BehaviourTree
    Builder.currentTree = nil
    Builder.currentNode = nil
    Builder.currentNodeStack = {}
    Builder.currentBlackboard = nil
end

function Builder.EndTree() : BehaviourTree
    --TODO check for errors
    --node stack size == 1
    --root node has 1 child max
    
    local tree = Builder.currentTree
    tree:FillNamedNodes(tree.rootNode)

    Builder.Cleanup()

    return tree
end

function Builder.EndNode() : BehaviourTree_Node
    --TODO check for errors
    --node stack size == 1
    --root node has 1 child max
    
    local node = Builder.currentNode

    Builder.Cleanup()

    return node
end

return Builder