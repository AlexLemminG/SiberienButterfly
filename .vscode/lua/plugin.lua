--### pluging helping with luau integration
function OnSetText(uri, text)
    local diffs = {}

    for localPos, colonPos, typeName, finish in text:gmatch '()local%s+[%w_]+()%s*%:%s*([%w_|%[%]]+)()' do
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
        for varLocalPos, varName, varColonPos, varTypeName, varFinish in params:gmatch '()%s*([%w_]+)()%s*%:%s*([%w_|%[%]]+)()' do
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

    local matched = {}
    for localPos, paramsPos, params, beforeType, t, returnType, finish in text:gmatch '()function%s+[%w_:%.]*()%(([^%)]*)%)()(%s*:%s*([%w_|%[%]]+))()' do
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
            ProcessParams(localPos, paramsPos, params)
        end
    end

    return diffs
end