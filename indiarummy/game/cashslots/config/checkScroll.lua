local GameReplace = require("GameReplace")

local function checkTable(gameid1, gameid2)
    local s1 = require("scroll.scroll_"..gameid1)
    local s2 = require("scroll.scroll_"..gameid2)
    for mapidx, map in pairs(s1) do
        for reelidx, reel in ipairs(map) do
            for cidx, c in ipairs(reel) do
                if s2[mapidx][reelidx][cidx] ~= c then
                    print("Diffent scroll", gameid1, gameid2, "at:",mapidx, reelidx, cidx)
                    return false
                end
            end
        end
    end
    return true
end

for gameid, replaceid in pairs(GameReplace) do
    if gameid ~= 439 then
        if not checkTable(gameid, replaceid) then
            print("check"..gameid.."scroll failed")
            break
        end
    end
end
