
local EnumUtils = {}

function EnumUtils.ArrayToEnum(tbl : any)
    local res = {}
    local length = #tbl
    for i = 1, length do
        local v = tbl[i]
        res[v] = i
    end

    return res
end
function EnumUtils.EnumToArray(tbl : any)
    local res = {}
    for key, value in pairs(tbl) do
        res[value] = key
    end
    return res
end

return EnumUtils