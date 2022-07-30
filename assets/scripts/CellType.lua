--!strict

local CellTypeInv = require("CellTypeInv")

function enum(tbl : any) : any
    local length = #tbl
    for i = 1, length do
        local v = tbl[i]
        tbl[v] = i
    end

    return tbl
end

local CellType = enum(CellTypeInv)

return CellType