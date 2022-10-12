local Utils = require "Utils"
local RandomNamesGenerator = {
    randomNamesLeft = {}
}

local allRandomNames = {
    "Margaux"         ,
    "Noël"            ,
    "Margot"          ,
    "Jérôme"          ,
    "Gilles"          ,
    "Margaret"        ,
    "Renée"           ,
    "Émilie"          ,
    "Danielle"        ,
    "Thierry"         ,
    "Guy Morel"       ,
    "Isaac"           ,
    "Luc"             ,
    "Françoise"       ,
    "Odette Lombard"  ,
    "Claire Fernandes",
    "Roland"          ,
    "Zoé"             ,
    "Jacques Lecoq"   ,
    "Valérie"         ,
    "Alain"           ,
    "Benoît"          ,
    "Anouk"           ,
    "Joseph"          ,
    "Nathalie"        ,
    "Lucas Vidal"     ,
    "Christiane"      ,
    "Astrid"          ,
    
}

function RandomNamesGenerator:GetNext() : string
    --TODO not zero for better result
    if #self.randomNamesLeft == 0 then
        for index, value in ipairs(allRandomNames) do
            table.insert(self.randomNamesLeft, value)
        end
    end

    local index = math.random(1, #self.randomNamesLeft)
    local result = self.randomNamesLeft[index]
    table.remove(self.randomNamesLeft, index)
    return result
end

return RandomNamesGenerator