local tJson2Lua = {
    ["true"] = { value = true },
    ["null"] = { value = nil },
    ["false"] = { value = false },
}

local tStr2Esc = {
    ["\\\""] = '\"', ["\\f"] = '\f', ["\\b"] = '\b', ["\\/"] = '/',
    ["\\\\"] = '\\', ["\\n"] = '\n', ["\\r"] = '\r', ["\\t"] = '\t',
}

local tEsc2Str = {
    ['\"'] = "\\\"", ['\f'] = "\\f", ['\b'] = "\\b", ['/'] = "\\/",
    ['\n'] = "\\n", ['\r'] = "\\r", ['\t'] = "\\t"
}


function escDecode(s)
    s = string.gsub( s, '\\', "\\\\")
    for esc, str in pairs(tEsc2Str) do
        s = string.gsub(s, esc, str)
    end
    return s
end


function luaTableToJsonStr(tbl)
    local jsonStr = ""

    assert(type(tbl) == "table", "tbl is not a table.")

    local keyType = nil
    local l = 0
    local i = 1
    for key, value in pairs(tbl) do
        l = l + 1
    end
    for key, value in pairs(tbl) do
        if keyType == nil then
            keyType = type(key)
            if keyType ~= "string" and keyType ~= "number" then
                -- 处理不了其他类型的key
                return nil
            end
        end

        -- 处理key，key类型不一致，转换失败
        if type(key) ~= keyType then
            return nil
        end

        if keyType == "string" then
            jsonStr = jsonStr .. string.format("\"%s\":", escDecode(key))
        end

        -- 处理value
        if type(value) == "table" then
            jsonStr = jsonStr .. luaTableToJsonStr(value)
            if i < l then jsonStr = jsonStr .. "," end
        else
            if type(value) == 'string' then
                value = '"' .. escDecode(value) .. '"'
            end
            jsonStr = jsonStr .. string.format("%s", value)
            if i < l then jsonStr = jsonStr .. "," end
        end

        i = i + 1
    end

    if keyType == "string" then
        return "{" .. jsonStr .. '}'
    else
        return "[" .. jsonStr .. ']'
    end
end

local t = { -- 水浒传
		[1] = {
			bonusControl = {probability = 5,},
			fullScreenControl = {probability = 5,},	
		},
		[2] = {
			bonusControl = {probability = 5,},
			fullScreenControl = {probability = 5,},	
		},
		[3] ={
			bonusControl = {probability = 5,},
			fullScreenControl = {probability = 5,},	
		},
		[4] ={
			bonusControl = {probability = 0,},
			fullScreenControl = {probability = 0,},	
		},
		[5] ={
			bonusControl = {probability = 0,},
			fullScreenControl = {probability = 0,},	
		},
	}
	
print(luaTableToJsonStr(t))
