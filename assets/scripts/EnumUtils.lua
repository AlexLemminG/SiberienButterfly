
local EnumUtils = {}

function EnumUtils.Enum(tbl : any) : any
    local res = {}
    local length = #tbl
    for i = 1, length do
        local v = tbl[i]
        res[v] = i
    end

    return res
end

return EnumUtils