
local table_tool = {}

function table_tool.binarySearch(t, func)
    local left = 1
    local right = #t
    while left <= right do
        local mid = math.floor((left + right) / 2)
        local ret = func(t[mid])
        if ret > 0 then
            right = mid -1
        elseif ret < 0 then
            left = mid + 1
        else
            return mid
        end
    end
    return -1
end

function table_tool.binaryLowerBound(t, func)
    local left = 1
    local right = #t + 1
    while left < right do
        local mid = math.floor((left + right) / 2)
        local ret = func(t[mid])
        if ret > 0 then
            right = mid
        elseif ret < 0 then
            left = mid + 1
        else
            right = mid
        end
    end
    return left
end

function table_tool.find(t, func)
    local left = 1
    local right = #t
    while left <= right do
        local mid = math.floor((left + right) / 2)
        local ret = func(t[mid])
        if ret > 0 then
            right = mid -1
        elseif ret < 0 then
            left = mid + 1
        else
            return true
        end
    end
    return false
end

-- local t = {0,1,2};
-- local ret
-- ret = table_tool.find(t, function(ele)
--     if ele < 1 then
--         return -1
--     elseif ele > 1 then
--         return 1
--     else
--         return 0
--     end
-- end)
-- print(ret)

-- local t = {2,4,6,6,6,8,10};
-- local i
-- i = table_tool.binarySearch(t, 3)
-- print(i)
-- i = table_tool.binarySearch(t, 6)
-- print(i)
-- i = table_tool.binaryLowerBound(t, 3)
-- print(i)
-- i = table_tool.binaryLowerBound(t, 6)
-- print(i)

return table_tool