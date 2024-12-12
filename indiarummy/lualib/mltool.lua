local mltool = {}

local function dump(obj)
    local getIndent, quoteStr, wrapKey, wrapVal, dumpObj
    getIndent = function(level)
        return string.rep("\t", level)
    end
    quoteStr = function(str)
        return '"' .. string.gsub(str, '"', '\\"') .. '"'
    end
    wrapKey = function(val)
        if type(val) == "number" then
            return "[" .. val .. "]"
        elseif type(val) == "string" then
            return "[" .. quoteStr(val) .. "]"
        else
            return "[" .. tostring(val) .. "]"
        end
    end
    wrapVal = function(val, level)
        if type(val) == "table" then
            return dumpObj(val, level)
        elseif type(val) == "number" then
            return val
        elseif type(val) == "string" then
            return quoteStr(val)
        else
            return tostring(val)
        end
    end
    dumpObj = function(obj, level)
        if type(obj) ~= "table" then
            return wrapVal(obj)
        end
        level = level + 1
        local tokens = {}
        tokens[#tokens + 1] = "{"
        for k, v in pairs(obj) do
            tokens[#tokens + 1] = getIndent(level) .. wrapKey(k) .. " = " .. wrapVal(v, level) .. ","
        end
        tokens[#tokens + 1] = getIndent(level - 1) .. "}"
        return table.concat(tokens, "\n")
    end
    return dumpObj(obj, 0)
end

local function getCardValue(card)
    return card & 0x0F
end

local function getCardColor(card)
    return card & 0xF0
end

local function getShowCplorCard(oldOutCards)
    for index,card in pairs(oldOutCards) do
        if getCardValue(card) < 15 then
            return getCardColor(card)
        end
    end
end

table.empty = function(t)
    return not next(t)
end

-- 深拷贝
table.copy = function(t, nometa)
    local result = {}

    if not nometa then
        setmetatable(result, getmetatable(t))
    end

    for k, v in pairs(t) do
        if type(v) == "table" then
            result[k] = table.copy(v, nometa)
        else
            result[k] = v
        end
    end
    return result
end

-- 统计相同牌的值
function getXtCardVluse(cards)
    local valurNum = {}
    for _,card in pairs(cards) do
        local value = getCardValue(card)
        if not valurNum[value] then
            valurNum[value] = 0
        end
    end
    --可能不是有序的重新排序
    local tmp_cards1 = {}
    local tmpCards = table.copy(cards)
    for _,card in pairs(tmpCards) do
        local value = getCardValue(card)
        table.insert(tmp_cards1,card)
    end
    local tmp_cards = table.copy(tmp_cards1)
    for i = 1,#tmp_cards do         
         for j = 1,#tmp_cards1 do
            if getCardValue(tmp_cards[i]) == getCardValue(tmp_cards1[j]) then
                tmp_cards[i] = 0
                local value = getCardValue(tmp_cards1[i])          
                valurNum[value] = valurNum[value] + 1
            end
         end
    end
    return valurNum
end

--判断该牌是佛存在A
local function isAcard(cards)
    for i,card in pairs(cards) do
        if getCardValue(card) == 1 then
            return true
        end
    end
    return false
end

local function unique(t, bArray)  
    local check = {}  
    local n = {}  
    local idx = 1
    for k, v in pairs(t) do  
        if not check[v] then  
            if bArray then  
                n[idx] = v
                idx = idx + 1  
            else  
                table.insert(n,v)
            end  
            check[v] = true  
        end  
    end  
    return n  
end


local function seprate_gui_card(out_cards)
    local tmp_out_cards = table.copy(out_cards)
    gui_cards = {}
    normal_cards = {}
    for _, card in pairs(tmp_out_cards) do
        if card == 0x4F then
            table.insert(gui_cards,card)
        else
            table.insert(normal_cards,card)
        end
    end
    return gui_cards,normal_cards
end

local function singeColorCard(outCards,clo)
    local cloCards = {}
    local tmpOutCards = table.copy(outCards)
    local laizi,t = seprate_gui_card(tmpOutCards)   
    local shunzi= unique(t, bArray)
    for _,card in pairs(shunzi) do
        if getCardColor(card) == clo then
            table.insert(cloCards,card)
        end
    end

    table.sort(cloCards)
    local tmp_c = table.copy(cloCards)
    local len = #cloCards
    local laizi_n = 0
    if #laizi > 0 then
        local bcIndex = 0 
        for i = 1, len do
            if i > 1 then
                xc_len = cloCards[i] - cloCards[i-1]
                if xc_len > 1 then
                    for j = 1,xc_len - 1 do
                        table.insert(tmp_c,i-1+j+bcIndex,laizi[1])
                        laizi_n = laizi_n + 1
                    end
                    bcIndex = bcIndex + xc_len -1
                end
            end
        end
    end
    --算方块
    if laizi_n <= #laizi and #tmp_c > 2 then
        return tmp_c
    else
        local laizi_index = {}
        --获取癞子分别对应下标数
        for i,card in pairs(tmp_c) do
            if getCardValue(card) == 15 then
                table.insert(laizi_index,i)
            end
        end
        table.insert(laizi_index,#tmp_c+1)
        table.insert(laizi_index,#tmp_c+2)
        table.insert(tmp_c,0x4F)
        table.insert(tmp_c,0x4F)
        local result_m = {}
        for k = 1,#laizi_index do
            local indexInfo = {}
            indexInfo.s = 0
            indexInfo.e = 0
            if k == 1 then
                indexInfo.s = 1
                if laizi_index[k+#laizi] then
                    indexInfo.e = laizi_index[k+#laizi] - 1
                end
            else
                indexInfo.s = laizi_index[k-1]+1
                if laizi_index[k+#laizi] then
                    indexInfo.e = laizi_index[k+#laizi]-1
                end
            end
            if indexInfo.e - indexInfo.s > 1 then
                table.insert(result_m,indexInfo)
            end
        end
        if not table.empty(result_m) then
            table.sort(result_m,function(a,b) return a.e-a.s > b.e-b.s end)
            local tmp_t = {}
            if result_m[1].e - result_m[1].s > 1 then

                for i ,card in pairs(tmp_c) do
                    if i >= result_m[1].s and i <= result_m[1].e then
                        table.insert(tmp_t,card)
                    end
                end
                if #tmp_t > 3 and tmp_t[1] == 0x4F then
                    table.remove(tmp_t,1)
                end
                if #tmp_t > 3 and tmp_t[#tmp_t] == 0x4F then
                    table.remove(tmp_t,#tmp_t)
                end
                return tmp_t
            end
        end
    end
end



function mltool.getShunZi(cards)
    local outCards = table.copy(cards)
    local laizi,t = seprate_gui_card(outCards)
    local shunzi= unique(t, bArray)
    local thsCard = {}
    for c = 0 ,3 do
        local cloCards = {}
        for _,card in pairs(shunzi) do

            if getCardColor(card) == 16*c then
                table.insert(cloCards,card)
            end
        end
        local index_c = 0
        local index = 0
       
        table.sort(cloCards,function(a,b) return a > b end)
        for i = 1 ,#cloCards do
            if i ~= #cloCards then
                if cloCards[i] - cloCards[i+1] == 1 then
                    index_c = index_c + 1
                    if index == 0 then index = i end
                else
                    if index_c >= 2 then
                        break
                    end
                    index_c = 0
                    index = 0
                end
            end
        end

        
        if index_c < 2 then
            local ret = isAcard(cloCards)
            if ret then
                index_c = 0
                index = 0
                cloCards[#cloCards] = cloCards[#cloCards] + 13
                table.sort(cloCards,function(a,b) return a > b end)
                for i = 1,#cloCards do
                    if i ~= #cloCards then 
                        if cloCards[i] - cloCards[i+1] == 1 then
                        index_c = index_c + 1
                        if index == 0 then index = i end
                            if index_c >= 2 then
                                break
                            end
                        else
                            if index_c >= 2 then
                                break
                            end
                            index_c = 0
                            index = 0
                        end
                    end
                end
                if index_c >= 2 then
                    
                    for i = index,index + index_c do
                        table.insert(thsCard,cloCards[i])
                    end
                    return thsCard
                end
            end
        elseif index_c >= 2 then
            for i = index,index + index_c do
                table.insert(thsCard,cloCards[i])
            end
            return thsCard
        end
    end
    
    if table.empty(thsCard) then
        local gui_cards, normal_cards = seprate_gui_card(cards)
        if #gui_cards > 0 then
            for i = 0 ,3 do
               local thsCard = singeColorCard(outCards,16*i)
               if thsCard then
                    local sgui_cards, snormal_cards = seprate_gui_card(thsCard)
                    if #thsCard > 2 then
                        if #thsCard - #sgui_cards ~= 1 then
                            return thsCard
                        end
                    end
               end 
            end
        end
    end
end

function mltool.getkanpai(cards)
    local kanpai = {}
    local valurNum = getXtCardVluse(cards)
    local kvalue = 0 
    for value,count in pairs(valurNum) do
        if count > 2 and value ~= 15 then
            kvalue = value
            break
        end
    end
    if kvalue > 0 then
        for _,card in pairs(cards) do
            if getCardValue(card) == kvalue then
                table.insert(kanpai,card)
            end
        end
    end
    if table.empty(kanpai) then

        local laizi,t = seprate_gui_card(cards)
        local needLaizi = 0
        for value,count in pairs(valurNum) do
            if value ~= 15 then
                for i = 1 ,#laizi do
                    if count + i > 2 then
                        kvalue = value
                        needLaizi = i
                        break
                    end
                end
            end
        end
        if kvalue > 0 and needLaizi > 0 then
            for _,card in pairs(cards) do
                if getCardValue(card) == kvalue then
                    table.insert(kanpai,card)
                end
            end
            for k = 1,needLaizi do
                table.insert(kanpai,laizi[k])
            end
        end
    end
    if #kanpai > 2 then
        return kanpai
    end
    return {}
end

function mltool.getGuiPai(cards)
    local guiPai = {}
    for _,card in pairs(cards) do
        if getCardValue(card) == 15 then
           table.insert(guiPai,card)
	       break
        end
    end
    
    return guiPai
end

--dire 0前 1后
local function getzhidShunZi(cards,value,dire,c)
    local laizi,t = seprate_gui_card(cards)
    local laiziLen = #laizi
    local outCards = {}
    local fanList = {}
    if dire == 0 then
        for _, card in pairs(t) do
            if getCardValue(card) < value and getCardColor(card) == c and (value ~= 14 or value ~= 1) then
                local isin = false
                for _,fcard in pairs(fanList) do
                    if fcard == card then
                        isin = true
                    end
                end
                if not isin then
                    table.insert(fanList,card)
                end
            end
        end
        table.sort(fanList,function(a,b)return (a > b) end)
        for i = 1 ,#fanList do
            if getCardValue(fanList[i]) + i == value then
                table.insert(outCards,fanList[i])
            else
                local needLaizi = value - getCardValue(fanList[i]) - 1
                local shiLaizi = needLaizi
                if laiziLen >= needLaizi then
                    laiziLen = laiziLen - needLaizi
                    for k = 1,shiLaizi do
                        table.insert(outCards,0x4F)
                    end
                    table.insert(outCards,fanList[i])
                else
                    laiziLen = laiziLen - needLaizi
                    shiLaizi = laiziLen
                    for k = 1,shiLaizi do
                        table.insert(outCards,0x4F)
                    end
                end 
               
            end
        end
    else
        for _, card in pairs(cards) do
            if getCardValue(card) > value and getCardColor(card) == c  and (value ~= 14 or value ~= 1) then
                local isin = false
                for _,fcard in pairs(fanList) do
                    if fcard == card then
                        isin = true
                    end
                end
                if not isin then
                    table.insert(fanList,card)
                end
            end
        end
        table.sort(fanList,function(a,b)return (a < b) end)
        for i = 1 ,#fanList do
            if getCardValue(fanList[i]) - i == value then
                table.insert(outCards,fanList[i])
            else
                local needLaizi = getCardValue(fanList[i]) - value - 1
                local shiLaizi = needLaizi
                if laiziLen >= needLaizi then
                    laiziLen = laiziLen - needLaizi
                    for k = 1,shiLaizi do
                        table.insert(outCards,0x4F)
                    end
                    table.insert(outCards,fanList[i])
                else
                    laiziLen = laiziLen - needLaizi
                    shiLaizi = laiziLen
                    for k = 1,shiLaizi do
                        table.insert(outCards,0x4F)
                    end
                end 
               
            end
        end
    end
    return outCards
end


local function getzhidKanpai(cards,value)
     local outCards = {}
    local laizi,t = seprate_gui_card(cards)
    for _, card in pairs(t) do
        if getCardValue(card) == getCardValue(value) then
            table.insert(outCards,card)
        end
    end
    for k = 1,#laizi do
        table.insert(outCards,0x4F)
    end
    return outCards
end

function mltool.getAllzhidShunZi(incards,appendCards)
    local cards = table.copy(incards)
    local outCardsList = {}
    for boxId,boxidInfo in pairs(appendCards) do
        if boxidInfo.cardType == 2 then
            local outcards = getzhidShunZi(cards,boxidInfo.s,0,boxidInfo.c)
            if not table.empty(outcards) then
                local outcardsInfo = {}
                outcardsInfo.dire = 0
                outcardsInfo.outcards = outcards
                outcardsInfo.boxId = boxId
                table.insert(outCardsList,outcardsInfo)
            end

            local outcards = getzhidShunZi(cards,boxidInfo.e,1,boxidInfo.c)
            if not table.empty(outcards) then
                local outcardsInfo = {}
                outcardsInfo.dire = 1
                outcardsInfo.outcards = outcards
                outcardsInfo.boxId = boxId
                table.insert(outCardsList,outcardsInfo)
            end
        elseif boxidInfo.cardType == 1 then
            local outcards =  getzhidKanpai(cards,boxidInfo.s)
            if not table.empty(outcards) then
                local outcardsInfo = {}
                outcardsInfo.dire = 1
                outcardsInfo.outcards = outcards
                outcardsInfo.boxId = boxId
                table.insert(outCardsList,outcardsInfo)
            end
        end
    end
    return outCardsList
end

----*******处理天胡的检测****************

local function unique_tianhu(t, bArray)  
    local check = {}  
    local n = {}  
    local y = {} 
    local idx = 1
    for k, v in pairs(t) do  
        if not check[v] then  
            if bArray then  
                n[idx] = v
                idx = idx + 1  
            else  
                table.insert(n,v)
            end  
            check[v] = true
        else
            table.insert(y,v)
        end  
    end  
    return n,y 
end

--处理含癞子的顺子
local function getShunZi_laizi(handCard)
    local data = {}
    local data_index = 1
    local index_c = 0
    local index = 0
    local len = #handCard
    for j=1, len do
        if j < len then
            if handCard[j] + 1 == handCard[j+1] then
                index_c = index_c + 1
                if index == 0 then index = j end
            else
                if index_c >= 2 then
                    if not data[data_index] then
                        data[data_index] = {}
                    end
                    for k = index, index + index_c do
                        table.insert(data[data_index],handCard[k])
                        handCard[k] = nil
                    end
                    data_index = data_index + 1
                end
                index_c = 0
                index = 0
            end
        else
            if index_c >= 2 then
                if not data[data_index] then
                    data[data_index] = {}
                end
                for k = index, index + index_c do
                    table.insert(data[data_index],handCard[k])
                    handCard[k] = nil
                end
                data_index = data_index + 1
                break
            end
            index_c = 0
            index = 0
        end                               
    end
    return data,handCard
end


--获取半顺
local function getBanShunzi(handCard)
    local data = {}
    local data_index = 1
    local index_c = 0
    local index = 0
    local len = #handCard
    for j=1, len do
        if j < len then
            if (handCard[j] + 1 == handCard[j+1]) or (handCard[j] + 2 == handCard[j+1]) then
                index_c = index_c + 1
                if index == 0 then index = j end
            else
                if index_c >= 1 then
                    if not data[data_index] then
                        data[data_index] = {}
                    end
                    for k = index, index + index_c do
                        table.insert(data[data_index],handCard[k])
                        handCard[k] = nil
                    end
                    data_index = data_index + 1
                end
                index_c = 0
                index = 0
            end
        else
            if index_c >= 1 then
                if not data[data_index] then
                    data[data_index] = {}
                end
                for k = index, index + index_c do
                    table.insert(data[data_index],handCard[k])
                    handCard[k] = nil
                end
                data_index = data_index + 1
                break
            end
            index_c = 0
            index = 0
        end                               
    end
    return data,handCard
end

--重构table
local function setTabelSyCard(sy)
    local data = {}
    for _,card in pairs(sy) do
        table.insert(data,card)
    end
    return data
end

--获取天胡的砍牌
function get_tianhu_kanpai(cards)
    local kanpai = {}
    local valurNum = getXtCardVluse(cards)
    local kvalue = {} 
    for value,count in pairs(valurNum) do
        if count > 2 and value ~= 15 then
            table.insert(kvalue,value)
        end
    end
    local kanpaiList = {}
    if #kvalue > 0 then
        for _, value in pairs(kvalue) do
            for i,card in pairs(cards) do
                if getCardValue(card) == value then
                    if not kanpaiList[value] then kanpaiList[value] = {} end
                    table.insert(kanpaiList[value],card)
                    cards[i] = nil
                end
            end
        end
    end
    local tmp_cards = {}
    for _, card in pairs(cards) do
        table.insert(tmp_cards,card)
    end
    return kanpaiList,tmp_cards
end

--过滤鬼牌砍牌
local function seprate_gui_kan_sy(out_cards)
    local tmp_out_cards = table.copy(out_cards)
    local gui_cards = {}
    for i, card in pairs(tmp_out_cards) do
        if card == 0x4F then
            table.insert(gui_cards,card)
            tmp_out_cards[i] = nil
        end
    end
    local knapaiList,sy_cards = get_tianhu_kanpai(tmp_out_cards)
    return gui_cards,knapaiList,sy_cards
end

function putStartCard(handCard)
    local data = {}
    local sy = {}
    handCard,y = unique_tianhu(handCard)
    table.sort(y,function(a,b)return (a < b) end)

    data[1],sy1 = getShunZi_laizi(handCard)
    local sy1 = setTabelSyCard(sy1)

    data[2],sy2 = getShunZi_laizi(y)
    local sy2 = setTabelSyCard(sy2)
    
    local dai_ban = {}
    for _, card in pairs(sy1) do
        table.insert(dai_ban,card)
    end
    for _, card in pairs(sy2) do
        table.insert(dai_ban,card)
    end

    data[3],sy3 = getBanShunzi(dai_ban)
    local sy3 = setTabelSyCard(sy3)
    
    for _, card in pairs(sy3) do
        table.insert(sy,card)
    end
    return data,sy
end

function mltool.checTianHu(handCard)
    local tmp_handCard = table.copy(handCard)
    local guiList,knaList,syCards = seprate_gui_kan_sy(tmp_handCard)
    ---开始计算各种颜色分类
    local cloCards = {}
    for _, card in pairs(syCards) do
        for i = 0, 3 do
            if getCardColor(card) == 16*i then
                if not cloCards[tostring(i)] then
                    cloCards[tostring(i)] = {}
                end
                table.insert(cloCards[tostring(i)],card)
            end
        end
    end
    local zuhe_shunziList = {}
    local need_gui_count = 0
    for _,syCards in pairs(cloCards) do
        local aa,sy = putStartCard(syCards)
        local shunziList = {}
        for _, shunzi in pairs(aa[1]) do
            table.insert(shunziList,shunzi)
        end
        for _, card in pairs(aa[2]) do
            table.insert(shunziList,shunzi)
        end

        local banshunziList = {}
        for _, banshun in pairs(aa[3]) do
            table.insert(banshunziList,banshun)
        end

        
        --清算半顺
        if #banshunziList > 0 then
            for b, banshunziInfo in pairs(banshunziList) do
                for i = 1, #banshunziInfo do
                    if i ~= #banshunziInfo then
                        if banshunziInfo[i] + 2 ==  banshunziInfo[i+1] then
                            if knaList[getCardValue(banshunziInfo[i]+1)] and #knaList[getCardValue(banshunziInfo[i]+1)] > 3 then
                                for j,card in pairs(knaList[getCardValue(banshunziInfo[i]+1)]) do
                                    if banshunziInfo[i]+1 == card then
                                        knaList[getCardValue(banshunziInfo[i]+1)][j] = nil
                                        table.insert(banshunziList[b],i+1,card)
                                        break
                                    end
                                end
                            else
                                need_gui_count = need_gui_count + 1
                                table.insert(banshunziList[b],i+1,0x4F)
                            end
                        end
                    end
                end
                if #banshunziList[b] == 2 then
                    need_gui_count = need_gui_count + 1
                    table.insert(banshunziList[b],0x4F)
                end
                table.insert(zuhe_shunziList,banshunziList[b])
                banshunziList[b] = nil
            end
        end

        --清算散牌 因为散牌必定是跟之前算出来的顺子相差必定是 大于等于2,跟半顺也是 
        if need_gui_count > #guiList then
            return nil
        end
        local dai_ban_sanpai = {}
        if #sy > 0 then
            --清算散牌
            for _,sanpai in pairs(sy) do
                if not dai_ban_sanpai[getCardValue(sanpai)] then dai_ban_sanpai[getCardValue(sanpai)] = {} end
                table.insert(dai_ban_sanpai[getCardValue(sanpai)],sanpai)
                for value,kanInfo in pairs(knaList) do
                    if #kanInfo > 3 then
                        for k,card in pairs(kanInfo) do
                            if (sanpai - 1 == card) or (sanpai - 2 == card) or (sanpai + 1 == card) or (sanpai + 2 == card) then            
                                table.insert(dai_ban_sanpai[getCardValue(sanpai)],card)
                                knaList[value][k] = nil
                                break
                            end
                        end
                    end
                end
            end
            sy = {}
        end
        for _,daibanInfo in pairs(dai_ban_sanpai) do
            table.sort(daibanInfo,function(a,b)return (a < b) end)
        end
        local singePai = {}
        for b,daibanInfo in pairs(dai_ban_sanpai) do

            if #daibanInfo >= 3 then --多张待定的中奖相差1的补一张鬼牌就可以了
                local data,sy = getShunZi_laizi(daibanInfo)
                local isShunzi = nil
                for i = 1, #data do
                    isShunzi = true
                    table.insert(zuhe_shunziList,data[i])
                    dai_ban_sanpai[b] = nil
                end
                if not isShunzi then --不为顺子 补充一个鬼牌就完事 TODO处理3,4直接可以拼顺子的
                    need_gui_count = need_gui_count + 1
                end
            end
            if #daibanInfo == 2 then --多张待定的中奖相差1的补一张鬼牌就可以了
                if daibanInfo[1] + 2 ==  daibanInfo[2] then
                    need_gui_count = need_gui_count + 1
                    dai_ban_sanpai[b] = nil
                else
                    local isShunzi = nil
                    --相差一个的 查找顺子中是能前后接起来
                    for _,shunziInfo in pairs(shunziList) do
                        if shunziInfo[#shunziInfo]+1 == daibanInfo[1] then
                            isShunzi = true
                            dai_ban_sanpai[b] = nil
                        elseif shunziInfo[1]+1 == daibanInfo[2]+1 then
                            isShunzi = true
                            dai_ban_sanpai[b] = nil
                        end
                    end
                    if not isShunzi then
                        need_gui_count = need_gui_count + 1
                        dai_ban_sanpai[b] = nil
                    end
                end
            end

            if #daibanInfo == 1 then --多张待定的中奖相差1的补一张鬼牌就可以了
                table.insert(singePai,daibanInfo[1])
            end
            --等于
        end
        if #singePai == 1 then
            need_gui_count = need_gui_count + 2
        elseif #singePai > 1 then
            table.sort(singePai,function(a,b)return (a > b) end)
            for i = 1, #singePai do
                if i ~= #singePai then
                    if singePai[i] - singePai[i+1] == 3 then
                        need_gui_count = need_gui_count + 2
                    else
                        need_gui_count = need_gui_count + 2
                    end
                end
            end
        end
        if need_gui_count > #guiList then
            return nil
        end
    end
    return true
end
--getzhidShunZi(cards,boxidInfo.s,0,boxidInfo.c)


--[[local aa = getShunZi(test)
--print("----111--",dump(aa))


if aa then
    --删除手牌
    for _,ocard in pairs(aa) do
        for i,card in pairs(test) do
            if card == ocard then
                table.remove(test,i)
                break
            end
        end
    end
end


print("----test--",dump(test))
local aa = getShunZi(test)

local kk = getkanpai(test)

print("----2222--",dump(kk))]]
return mltool

--print(dump(singeColorCard(test,0)))
---print(dump(getShunZi(test)))
--print(dump(getkanpai(test)))
--return mltool
--[[local function uniquea(t, bArray)
    local itemList = {}
    local check = {}
    for k, v in pairs(t) do  
        if not check[v.itemID] then  
           check[v.itemID] = v
        else
            if check[v.itemID].count < v.count then
                check[v.itemID].count = v.count
            end
        end  
    end
    
    for _, info in pairs(check) do
        table.insert(itemList,info)
    end
    return itemList  
end


local kk = {
        [1] = {
                ["itemID"] = 1020,
                ["count"] = 14,
        },
        [2] = {
                ["itemID"] = 1004,
                ["count"] = 100000090,
        },
        [3] = {
                ["itemID"] = 1020,
                ["count"] = 15,
        },
        [4] = {
                ["itemID"] = 10025,
                ["count"] = 1000002,
        },
    }


print(dump(uniquea(kk)))]]