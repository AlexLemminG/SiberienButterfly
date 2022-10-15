local Utils = require "Utils"

---@class BehaviourTree
---@field character Character
---@field characterController CharacterControllerBase
local BehaviourTree = {
    rootNode = nil,
    character = nil,
    characterController = nil,
    blackboard = nil,
    namedNodes = nil
}

function BehaviourTree.new(characterController : CharacterControllerBase)
    local tree = {}
    tree.characterController = characterController
    tree.character = characterController.character
    tree.blackboard = {}
    tree.namedNodes = {}

    setmetatable(tree, BehaviourTree)

    return tree
end
BehaviourTree.__index = BehaviourTree

function BehaviourTree:Update()
    self.rootNode:Update(self.character, self.blackboard)
end

function BehaviourTree:AddNode(node, parentNodeName)
    if not parentNodeName then
        --TODO error
        return
    end
    local parentNode = self.namedNodes[parentNodeName]
    if not parentNode then
        --TODO error
        return
    end
    --TODO less duplication with Builder.PushNode
    node.character = self.character
    node.blackboard = self.blackboard

    function FillCharacterAndBlackboard(node)
        node.character = self.character
        node.blackboard = self.blackboard
        if node.children then
            for index, childNode in ipairs(node.children) do
                FillCharacterAndBlackboard(childNode)
            end
        end
    end

    self:FillNamedNodes(node)
    FillCharacterAndBlackboard(node)

    node.parentNode = parentNode

    table.insert(parentNode.children, node)
end

function BehaviourTree:RemoveNode(node)
    local parentNode = node.parentNode
    if not parentNode then
        --TODO error
        return
    end

    if node.name then
        self.namedNodes[node.name] = nil
    end
    
    Utils.ArrayRemove(parentNode.children, node)

end

function BehaviourTree:FillNamedNodes(fromNode)
    if fromNode.name then
        self.namedNodes[fromNode.name] = fromNode
    end
    if fromNode.children then
        for index, childNode in ipairs(fromNode.children) do
            self:FillNamedNodes(childNode)
        end
    end
end

return BehaviourTree
