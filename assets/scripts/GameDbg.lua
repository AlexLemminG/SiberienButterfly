local GameDbg                 = {
    isOn = false,
    commandsToAssign = nil
}


function GameDbg:Update()
    if Input:GetKeyDown("Home") then
        self.isOn = not self.isOn
    end

    if not self.isOn then
        return
    end


    local World                   = require("World")
    local CharacterControllerBase = require("CharacterControllerBase")
    local Actions                 = require("Actions")
    local CellType                = require("CellType")
    local Game                    = require("Game")

    if not self.commandsToAssign then
        self.commandsToAssign = {}
        local commandsToAssign = self.commandsToAssign

        table.insert(commandsToAssign,
            CharacterControllerBase.CreateCommandFromRules(Actions:GetAllCombineRules(CellType.None, CellType.Wheat,
                CellType.Any)))

        table.insert(commandsToAssign,
            CharacterControllerBase.CreateCommandFromRules(Actions:GetAllCombineRules(CellType.None, CellType.None,
                CellType.Ground)))
        CharacterControllerBase.AddMarkingToCommand(commandsToAssign[#commandsToAssign], CellType.MarkingRed)
        
        table.insert(commandsToAssign,
            CharacterControllerBase.CreateCommandFromRules(Actions:GetAllCombineRules(CellType.None, CellType.None, 
            CellType.GroundWithGrass)))
        CharacterControllerBase.AddMarkingToCommand(commandsToAssign[#commandsToAssign], CellType.MarkingRed)
                    
        table.insert(commandsToAssign,
            CharacterControllerBase.CreateCommandFromRules(Actions:GetAllCombineRules(CellType.WheatCollected_Any, CellType.None,
                CellType.GroundPrepared)))
                
        table.insert(commandsToAssign,
            CharacterControllerBase.CreateCommandFromRules(Actions:GetAllCombineRules(CellType.WheatCollected_AnyNotFull, CellType.WheatCollected_AnyNotFull,
                CellType.Any)))
                
        table.insert(commandsToAssign,
            CharacterControllerBase.CreateCommandFromRules(Actions:GetAllCombineRules(CellType.Stone, CellType.WheatCollected_6,
                CellType.Any)))
                
        table.insert(commandsToAssign,
            CharacterControllerBase.CreateCommandFromRules(Actions:GetAllCombineRules(CellType.Flour, CellType.StoveWithWoodFired,
                CellType.Any)))
                

        table.insert(commandsToAssign,
        CharacterControllerBase.CreateCommandFromRules(Actions:GetAllCombineRules(CellType.None, CellType.Tree,
            CellType.Any)))

        table.insert(commandsToAssign,
            CharacterControllerBase.CreateCommandFromRules(Actions:GetAllCombineRules(CellType.Wood, CellType.Stove,
                CellType.Any)))
                
        table.insert(commandsToAssign,
            CharacterControllerBase.CreateCommandFromRules(Actions:GetAllCombineRules(CellType.Wood, CellType.Stove,
                CellType.Any)))
                
        table.insert(commandsToAssign,
        CharacterControllerBase.CreateCommandFromRules(Actions:GetAllCombineRules(CellType.FlintStone, CellType.StoveWithWood,
            CellType.Any)))
        
        table.insert(commandsToAssign,
        CharacterControllerBase.CreateBringCommand(CellType.Stone, CellType.FlagRed))
        CharacterControllerBase.AddMarkingToCommand(commandsToAssign[#commandsToAssign], CellType.MarkingRed)
        
        table.insert(commandsToAssign,
        CharacterControllerBase.CreateBringCommand(CellType.Flour, CellType.FlagGreen))
    end

    --TODO make player immortal

    local iNextCommand = 1
    local commandsToAssign = self.commandsToAssign
    for i, character in ipairs(World.characters) do
        --TODO not "Character" hardcode
        if character == World.playerCharacter or character.type ~= "Character" then
            continue
        end
        if character.characterController:GetCommand() ~= commandsToAssign[iNextCommand] then
            character.characterController:SetCommand(commandsToAssign[iNextCommand])
        end
        if #commandsToAssign == iNextCommand then
            iNextCommand = 1
        else
            iNextCommand += 1
        end
    end

    if Input:GetKeyDown("N") then
        Game.CreateNpcGO()
    end
end

return GameDbg
