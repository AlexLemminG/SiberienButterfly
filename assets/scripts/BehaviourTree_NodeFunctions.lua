local BehaviourTree_Node = require "BehaviourTree_Node"
local World              = require "World"

local BehaviourTree_NodeFunctions = {}

function BehaviourTree_NodeFunctions.MoveToIntPos(character : Character, intPos : Vector2Int)
    local currentNavigationPos = character.characterController:GetNearestWalkableIntPos()

    if currentNavigationPos == intPos then
        return BehaviourTree_Node.SUCCESS
    end

    if not World.navigation:PathExists(intPos, currentNavigationPos) then
        return BehaviourTree_Node.FAILED
    end

    local currentPath = character.characterController.currentPath
    if not currentPath or currentPath.to ~= intPos then
        currentPath = World.navigation:CalcPath(currentNavigationPos, intPos)
        if not currentPath.isComplete then
            LogWarning("Failed to find path after navigation:PathExists returned true")
            return BehaviourTree_Node.FAILED
        end
        character.characterController.currentPath = currentPath
        character.characterController.currentPathPointIndex = 1
    end
    return BehaviourTree_Node.RUNNING
end

function BehaviourTree_NodeFunctions.MoveTo3dPosWithoutNavigation(character : Character, pos : Vector3, stopRadius : number)
    if length(character:GetPosition() - pos) <= stopRadius then
        return BehaviourTree_Node.SUCCESS
    end
    character.characterController.currentPath = nil
    character.characterController.immediateTargetPos = pos
    return BehaviourTree_Node.RUNNING
end

function BehaviourTree_NodeFunctions.ExecAction(action : CharacterAction)
    local character = action.character
    if not action then
        return BehaviourTree_Node.FAILED
    end
    if action.intPos ~= nil then
        local moveResult = BehaviourTree_NodeFunctions.MoveToIntPos(character, action.intPos)
        if moveResult ~= BehaviourTree_Node.SUCCESS then
            return moveResult
        end
    end
    if action:Execute() then
        return BehaviourTree_Node.SUCCESS
    else
        return BehaviourTree_Node.FAILED
    end
end

return BehaviourTree_NodeFunctions
