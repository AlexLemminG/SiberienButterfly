--!strict

function enum(tbl : any) : any
    local length = #tbl
    for i = 1, length do
        local v = tbl[i]
        tbl[v] = i - 1
    end

    return tbl
end

local CellType = enum {
	"NONE",
	"GROUND"
}

return CellType