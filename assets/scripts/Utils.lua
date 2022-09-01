local Utils = {}

function Utils.TableToString(o)
    return Utils._TableToString(o, {})
end

function Utils._TableToString(o, traversedTables) : string
    if o == nil then
        return 'nil'
    end
    if traversedTables[o] then
        return '-'
    end
    traversedTables[o] = true
    if type(o) == 'table' then
        local s = '{ '
        for k, v in pairs(o) do
            if type(k) ~= 'number' then
                k = '"' .. k .. '"'
            end
            s = s .. '[' .. k .. '] = ' .. Utils._TableToString(v, traversedTables) .. ','
        end
        return s .. '} '
    else
        return tostring(o)
    end
end

function Utils.ArrayIndexOf(array, value) : integer
    for i, v in ipairs(array) do
        if v == value then
            return i
        end
    end
    return -1
end

-- returns true if element found
function Utils.ArrayRemove(array, value) : boolean
    local index = Utils.ArrayIndexOf(array, value)
    if index ~= -1 then
        table.remove(array, index)
        return true
    end
    return false
end

getmetatable(Vector2Int:new()).__eq = function(a, b) return a.x == b.x and a.y == b.y end

---@class vector
---@field x number
---@field y number
---@field z number
local Vector = { x = 0.0, y = 0.0, z = 0.0 }

---@class Vector2Int
---@field x number
---@field y number
local Vector2Int = { x = 0.0, y = 0.0 }

---@class Vector3
---@field x number
---@field y number
---@field z number
local Vector3 = { x = 0.0, y = 0.0, z = 0.0 }

---@class Vector2
---@field x number
---@field y number
local Vector2 = { x = 0.0, y = 0.0 }


return Utils
