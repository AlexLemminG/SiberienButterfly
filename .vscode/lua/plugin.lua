--###
function OnSetText(uri, text)
    -- if text:sub(1, 5) ~= '--###' then
    --     return nil
    -- end
    local diffs = {}
    -- diffs[#diffs + 1] = {
    --     start  = 1,
    --     finish = 4,
    --     text   = '',
    -- }

    --print("------------------")

    for localPos, colonPos, typeName, finish in text:gmatch '()local%s+[%w_]+()%s*%:%s*([%w_|]+)()' do
        diffs[#diffs + 1] = {
            start  = localPos,
            finish = localPos - 1,
            text   = ('---@type %s\n'):format(typeName),
        }
        diffs[#diffs + 1] = {
            start  = colonPos,
            finish = finish - 1,
            text   = '',
        }
    end

    function ProcessParams(functionPos, paramsPos, params)
        for varLocalPos, varName, varColonPos, varTypeName, varFinish in params:gmatch '()%s*([%w_]+)()%s*%:%s*([%w_|]+)()' do
            diffs[#diffs + 1] = {
                start  = functionPos,
                finish = functionPos - 1,
                text   = ('---@param %s %s\n'):format(varName, varTypeName),
            }
            diffs[#diffs + 1] = {
                start  = paramsPos + varColonPos,
                finish = paramsPos + varFinish - 1,
                text   = '',
            }
        end
        return {}
    end

    -- print("hifff")
    local matched = {}
    for localPos, paramsPos, params, beforeType, t, returnType, finish in text:gmatch '()function%s+[%w_:%.]*()%(([^%)]*)%)()(%s*:%s*([%w_|]+))()' do
        -- print("Params=", localPos, paramsPos, params, finish)
        -- print("ReturnType=", returnType)
        --print(params)
        ProcessParams(localPos, paramsPos, params)
        diffs[#diffs + 1] = {
            start  = localPos,
            finish = localPos - 1,
            text   = ('---@return %s\n'):format(returnType),
        }
        diffs[#diffs + 1] = {
            start  = beforeType,
            finish = finish - 1,
            text   = ''
        }
        matched[localPos] = true
    end
    for localPos, paramsPos, params, finish in text:gmatch '()function%s+[%w_:%.]*()%(([^%)]*)%)()' do
        if not matched[localPos] then
            --print(params)
            --print("Params=", localPos, paramsPos, params, finish)
            --print("NO ReturnType")
            ProcessParams(localPos, paramsPos, params)
        end
    end

    return diffs
end

-- function Gdfg(f : number) : number
--     print("G")
--     return 1.0
-- end
