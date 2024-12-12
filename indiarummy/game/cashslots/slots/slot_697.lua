--[[
绚丽的埃及艳后  Gorgeous Cleopatra

免费游戏中：
    7PRIZE: 7次，每次如果出现狮身人面兽则获取奖池(1~2个)
]]

local skynet  = require "skynet"
local config = require"cashslots.common.config"
local cardProcessor = require "cashslots.common.cardProcessor"
local cashBaseTool = require "cashslots.common.base"
local settleTool = require "cashslots.common.gameSettle"
local player_tool = require "base.player_tool"
local recordTool = require "cashslots.common.gameRecord"
local utils = require "cashslots.common.utils"
local baseRecord = require "base.record"
local gameData = recordTool.gameData
local record = recordTool.pushLog
local freeTool = require "cashslots.common.gameFree"
local isFreeState = freeTool.isFreeState
local updateFreeData = freeTool.updateFreeData
local DEBUG = os.getenv("DEBUG")

local GAME_CFG = {
	gameid = 697,
	line = 40,
	winTrace = config.LINECONF[40][2], 
    mults = config.MULTSCONF[888][1],
	RESULT_CFG = config.CARDCONF[697],
	wilds = {1}, 
	scatter = 2, 
	freeGameConf = {card = 2, min = 3, freeCnt = 0, addMult = 1},  -- 免费游戏配置
	COL_NUM = 5,
	ROW_NUM = 4,
}

local LIONPRIZE = 14
local RANDOMCARDS = {4, 5, 6, 7, 8, 9, 10, 11, 12, 13}
local FREETYPE = {
	NONE = 0,
	COMMONFREE = 1,
	COLLECTFREE = 2
}

local baseFree = {}
local poolGame = {}
local collectFree = {}
--================通用方法=====================
local JACKPOT = config.JACKPOTCONF[GAME_CFG.gameid]
local function getJackPot(deskInfo, type)
    if TEST_RTP then
        return JACKPOT.MULT[type] * deskInfo.totalBet
    else
        return math.floor(JACKPOT.MULT[type] * deskInfo.totalBet * (0.95 + math.random()*0.1))
    end
end

local function getJackpotList(deskInfo)
    local poolList = {}
	for i = 1, #JACKPOT.MULT do
		table.insert(poolList, getJackPot(deskInfo, i))
    end
    return poolList
end

-- 获取pos个中的随机几个位置
local function getSomeRandomPos(pos, random)
    local ret = {}
    for i = 1, random do
        local idx = math.random(1, #pos)
        table.insert(ret, pos[idx])
        table.remove(pos, idx)
    end
    return ret
  end

--==================清除选择信息===============
local function clearSelect(deskInfo)
	deskInfo.select = {state = false}
end

--================正常免费游戏=====================


local BASEFREECFG = {
    NUM = 7,
    DEF = {
        T1 = 1, --7spine
        T2 = 2, --7PRIZES
        T3 = 3, --7WIN      
        T4 = 4, --7wilds
    },
    TYPES = {   --4个奖励出现的权重
        {info = 1, weight = 10},
        {info = 2, weight = 10},
        {info = 3, weight = 10},
        {info = 4, weight = 10},
    },
    SPINE7= {                 --7spine的找出最大倍数
        MULTS = {      
            {num = 6, weight = 10,},  
            {num = 8, weight = 5,}, 
            {num = 10, weight = 2,},   
        }, 
    },
    PRIZES7 = {
        LION ={
            MIN = 0,
            MAX = 100,
            PROBABILTY = {10, 8, 7, 6, 4, 2, 1}
        } ,    --7局，每局出现狮身人面兽的可能性，%的单位，个数一般是1~2个随机
        NUM = {1, 2, 3, 4, 5, 6, 7},
    },
    WINS7 = {
        MULTS = {           
            {num = 6, weight = 10,},  
            {num = 8, weight = 5,}, 
            {num = 10, weight = 2,},  
        },
        OTHER = {1, 1, 1, 2, 4, 5}
    },
    WILDS = {
        NUM = {7, 7, 7, 7, 7, 7, 7}     --7次，每次最多随机7个wild
    }
}
--获取免费类型
baseFree.getType = function(deskInfo)
    local _, rs = utils.randByWeight(BASEFREECFG.TYPES)
    local type = rs.info

    deskInfo.freeGameData.rtype = type
    local ret = {
        type = type,
        freeCnt = BASEFREECFG.NUM,
    }
    if type == BASEFREECFG.DEF.T1 then
        deskInfo.select = {state = true, rtype = 2}
    elseif  type == BASEFREECFG.DEF.T3 then
        deskInfo.select = {state = true, rtype = 3}
    else
        clearSelect(deskInfo)
    end
    return ret
end

--赢取7spine需要点击选择一个倍数(需要交互51)
baseFree.spin7Pick = function(deskInfo, idx)
    local conf = {}
    for _, v in ipairs(BASEFREECFG.SPINE7.MULTS)do
        table.insert(conf, v.num)
    end
    local _, rs = utils.randByWeight(BASEFREECFG.SPINE7.MULTS)
    local mult = rs.num
    local boxs = {}
    for i = 1, BASEFREECFG.NUM do
        if i <= 3 then
            table.insert(boxs, 2)
        else
            table.insert(boxs, mult)
        end
    end 
    deskInfo.freeGameData.boxs = boxs
    local ret = {
        type = BASEFREECFG.DEF.T1,
        idx = idx,      --玩家上行的idx
        mult = mult,    --中奖的倍数
        conf = conf,    --所有的配置
        boxs = boxs,    --玩家需要展示在客户端的7个格子信息
    }
    return ret
end

--赢取7spine需要点击选择一个倍数(需要交互51)
baseFree.spin7Wins = function(deskInfo, idx)
    local conf = {}
    for _, v in ipairs(BASEFREECFG.WINS7.MULTS)do
        table.insert(conf, v.num)
    end
    local _, rs = utils.randByWeight(BASEFREECFG.WINS7.MULTS)
    local mult = rs.num

    local boxs = table.copy(BASEFREECFG.WINS7.OTHER)
    table.insert(boxs, mult)
    deskInfo.freeGameData.boxs = boxs
    local ret = {
        type = BASEFREECFG.DEF.T3,
        idx = idx,      --玩家上行的idx
        mult = mult,    --中奖的倍数
        conf = conf,    --所有的配置
        boxs = boxs,    --玩家需要展示在客户端的7个格子信息
    }
    return ret
end

--赢取7prize需要点击选择一个倍数
baseFree.setSevenBoxs = function(deskInfo)
    local boxs = {}
    if deskInfo.freeGameData.rtype == BASEFREECFG.DEF.T1 then
        --7spin类型，需要交互一次51获取最终结果
    elseif deskInfo.freeGameData.rtype == BASEFREECFG.DEF.T2 then
        for i = 1, BASEFREECFG.NUM do
            local mult = BASEFREECFG.PRIZES7.NUM[i]
            local coin = math.round_coin(mult*deskInfo.totalBet)
            table.insert(boxs, coin)
        end
    elseif deskInfo.freeGameData.rtype == BASEFREECFG.DEF.T3 then
        --7wins类型，需要交互一次51获取最终结果
    elseif deskInfo.freeGameData.rtype == BASEFREECFG.DEF.T4 then
        boxs = table.copy(BASEFREECFG.WILDS.NUM)
    end
    deskInfo.freeGameData.boxs = boxs
    return boxs
end

--发牌进行处理
baseFree.setCards = function(deskInfo, cards)
    local copy = table.copy(cards)
    local num = deskInfo.freeGameData.allFreeCount - deskInfo.freeGameData.restFreeCount + 1
    if deskInfo.freeGameData.rtype == BASEFREECFG.DEF.T1 then
        --不需要对发牌进行处理
    elseif deskInfo.freeGameData.rtype == BASEFREECFG.DEF.T2 then       --添加狮身人面兽
        local show = false
        if math.random(BASEFREECFG.PRIZES7.LION.MIN, BASEFREECFG.PRIZES7.LION.MAX) <= BASEFREECFG.PRIZES7.LION.PROBABILTY[num] then
            show = true
        end
        if show then
            local pos = {}
            local idxs = {}
            for i = 1, GAME_CFG.COL_NUM*GAME_CFG.ROW_NUM do
                table.insert(pos, i)
            end
            local random = getSomeRandomPos(pos, math.random(1, 2))
            for _, idx in ipairs(random) do
                copy[idx] = LIONPRIZE
                table.insert(idxs, idx)
            end
        end
    elseif deskInfo.freeGameData.rtype == BASEFREECFG.DEF.T3 then
        --不需要对发牌进行处理
    elseif deskInfo.freeGameData.rtype == BASEFREECFG.DEF.T4 then
        
        local pos = {}
        local idxs = {}
        for i = 1, GAME_CFG.COL_NUM*GAME_CFG.ROW_NUM do
            table.insert(pos, i)
        end
        local random = getSomeRandomPos(pos, math.random(1, 2))
        for _, idx in ipairs(random) do
            copy[idx] = GAME_CFG.wilds[1]
            table.insert(idxs, idx)
        end
        local free7Wilds = {}
        free7Wilds.card = GAME_CFG.wilds[1]
        free7Wilds.idxs = idxs
        deskInfo.freeGameData.free7Wilds = free7Wilds       --这局随机的卡牌的idx
    end
    return copy
end

baseFree.start = function(deskInfo, retobj)
    if isFreeState(deskInfo) and not collectFree.state(deskInfo)  then
        local num = deskInfo.freeGameData.allFreeCount - deskInfo.freeGameData.restFreeCount + 1
        if deskInfo.freeGameData.rtype == BASEFREECFG.DEF.T1 then
            retobj.wincoin = retobj.wincoin * deskInfo.freeGameData.boxs[num]
        elseif deskInfo.freeGameData.rtype == BASEFREECFG.DEF.T2 then
            for i = 1, GAME_CFG.COL_NUM*GAME_CFG.ROW_NUM do
                if retobj.resultCards[i] == LIONPRIZE then
                    retobj.wincoin = retobj.wincoin + deskInfo.freeGameData.boxs[num]
                end
            end
        elseif deskInfo.freeGameData.rtype == BASEFREECFG.DEF.T3 then
            retobj.wincoin = retobj.wincoin*deskInfo.freeGameData.boxs[num]
        elseif deskInfo.freeGameData.rtype == BASEFREECFG.DEF.T4 then
            --不需要重新结算
        end
    end
end

--{10,20,200,1000,5000}
--=================奖金游戏===========================
local POOLCFG = {
    DEF = {
        T1 = 1, --MINI 10
        T2 = 2, --MINOR 20
        T3 = 3, --MAJOR 200
        T4 = 4, --MEGA 1000
        T5 = 5, --GRAND 5000
    },
    TYPES = {
        {num = 1, weight = 1500},     --t1
        {num = 2, weight = 1000},     --t1
        {num = 3, weight = 600},      --t2
        {num = 4, weight = 500},      --t2
        {num = 5, weight = 50},      --t3
        {num = 6, weight = 0},      --t4
        {num = 7, weight = 0},      --t5
    },
}

local function getBonusProbabilty(deskInfo)
    if deskInfo.control.bonusControl then
        return deskInfo.control.bonusControl.probability
    end
    return 5
end

poolGame.tri = function(deskInfo, cards)
    if not isFreeState(deskInfo) then
        if math.random()*1000 <= getBonusProbabilty(deskInfo) then
            -- 这里需要有wild才能触发
            if not table.contain(cards, GAME_CFG.wilds[1]) then
                cards[math.random(#cards)] = GAME_CFG.wilds[1]
            end
            local wheel = poolGame.genWheel(deskInfo)
            deskInfo.select = {state = true, rtype = 4}
            return true, wheel
        end
    end
    return false
end

poolGame.genWheel = function(deskInfo)
    local wheel = {
        {type = POOLCFG.DEF.T1, coin = 0},
        {type = POOLCFG.DEF.T1, coin = deskInfo.totalBet*math.random(2, 3)},
        {type = POOLCFG.DEF.T2, coin = 0},
        {type = POOLCFG.DEF.T2, coin = deskInfo.totalBet*math.random(4, 5)},
        {type = POOLCFG.DEF.T3, coin = 0},
        {type = POOLCFG.DEF.T4, coin = 0},
        {type = POOLCFG.DEF.T5, coin = 0},
    }
    deskInfo.poolGame = {}
    deskInfo.poolGame.wheel = wheel
    deskInfo.poolGame.poolList = getJackpotList(deskInfo)
    return wheel
end

--获取旋转结果
poolGame.get = function(deskInfo)
    local _, rs = utils.randByWeight(POOLCFG.TYPES) --7种结果的中第几种， 1/2/3/4/5/6/7
    local idx = rs.num
    local result = deskInfo.poolGame.wheel[idx]
    local win = result.coin or 0
    local jackPot = deskInfo.poolGame.poolList[result.type]
    win = win + jackPot
    cashBaseTool.caulCoin(deskInfo, win, PDEFINE.ALTERCOINTAG.WIN)
    return {
        idx = idx,
        result = result,
        coin = win
    }
end
--=================收集游戏===========================

local COLLECTCFG = {
    RANDOMPROBABILITY = DEBUG and 300 or 200, --每局随机添加金字塔的可能性 千分之几的概率
    MINBETIDX = 2,      --最小要*级才能解开
    MAX = 300,
    RANDOMPYRAMID_CNT = {
        {num = 1, weight = 125,},
        {num = 2, weight = 50,},
        {num = 3, weight = 20,},
        {num = 4, weight = 10,},
        {num = 5, weight = 5,},
    },
    RANDOMPYRAMID_POINT = {   --随机金字塔
        {num = 5, weight = 150,},
        {num = 10, weight = 25,},
        {num = 15, weight = 15,},
        {num = 20, weight = 5,},
        {num = 25, weight = 1,},
    },
    BASENUM = 3,        --组合算分基础免费次数3次
    DEF = {
        --
        S1 = 1,     --sticky wilds
        S2 = 2,     --multipler wilds
        S3 = 3,     --random wilds
        S4 = 4,    --remove symbols
        S5 = 5,    --expanding wild
        SPINE = { --免费游戏次数
            pyramid = {init = 120, add = 40},   --初始3次是120, 每增加一次叠加40
            num = {min = 1, max = 47, },        --1表示3次,发送1~48, 表示3~50次
            comment = "free game spins"
        },
        SINGLE = {
            S1 = {
                pyramid = {105, 255, 480, 855, 1380},
                num = {min = 1, max = 5, },
                comment = "sticky wilds"
            },  --sticky wilds:使收集游戏X个WILD随机固定出现在卷轴上，X为1-5，X玩家选择
            S2 = {
                pyramid = {855, 2130, 4380},
                num = {min = 1, max = 3, }, 
                mults = {{2, 5}, {3, 7}, {4, 10}}, 
                comment = "multipler wilds"
            }, --multipler wilds：使收集游戏中出现的wild都携带一个范围内的随机倍数，wild参与的连线奖励会乘以倍数，多个wild在一条连线上奖励相乘
            S3 = {
                pyramid = {105, 255, 480, 855, 1320},
                num = {min = 1, max = 5, }, 
                comment = "random wilds"
            }, --random wilds:每次旋转会随机出现X个wild在卷轴上，X玩家选择，X选择范围1-5
            S4 = {
                pyramid = {105, 150, 195, 240, 420},
                num = {min = 1, max = 5, }, 
                remove = {{13}, {13, 12}, {13, 12, 11}, {13, 12, 11, 10}, {13, 12, 11, 10, 9}, },
                comment = "remove symbols"
            }, --remove symbols:删除卷轴中的X个普通图标，X玩家选择，X选择范围1-5
            S5 = {
                pyramid = {15, 60, 225},
                num = {min = 1, max = 3, }, 
                expand = {{5}, {5, 4}, {5, 4, 3}},
                reel = {3, 4, 5}, comment = "expanding wild"
            }, --expanding wild:使列X上出现的wild会扩张到整列
        },
        GROUP = {
            G1 = {
                {data = {{type = 2, idx = 1}, {type = 4, idx = 1}}, pyramid = 1155},
                {data = {{type = 2, idx = 1}, {type = 4, idx = 2}}, pyramid = 1380},
                {data = {{type = 2, idx = 1}, {type = 4, idx = 3}}, pyramid = 1710},
                {data = {{type = 2, idx = 1}, {type = 4, idx = 4}}, pyramid = 2130},
                {data = {{type = 2, idx = 1}, {type = 4, idx = 5}}, pyramid = 2730},

                {data = {{type = 2, idx = 2}, {type = 4, idx = 1}}, pyramid = 2430},
                {data = {{type = 2, idx = 2}, {type = 4, idx = 2}}, pyramid = 2880},
                {data = {{type = 2, idx = 2}, {type = 4, idx = 3}}, pyramid = 3630},
                {data = {{type = 2, idx = 2}, {type = 4, idx = 4}}, pyramid = 4080},
                {data = {{type = 2, idx = 2}, {type = 4, idx = 5}}, pyramid = 5055},

                {data = {{type = 2, idx = 3}, {type = 4, idx = 1}}, pyramid = 6330},
                {data = {{type = 2, idx = 3}, {type = 4, idx = 2}}, pyramid = 6630},
                {data = {{type = 2, idx = 3}, {type = 4, idx = 3}}, pyramid = 8130},
                {data = {{type = 2, idx = 3}, {type = 4, idx = 4}}, pyramid = 9105},
                {data = {{type = 2, idx = 3}, {type = 4, idx = 5}}, pyramid = 10680},
            },  --multipler wilds T2 和 remove symbols T4
            G2 = {
                {data = {{type = 2, idx = 1}, {type = 3, idx = 1}}, pyramid = 3150},
                {data = {{type = 2, idx = 1}, {type = 3, idx = 2}}, pyramid = 7650},
                {data = {{type = 2, idx = 1}, {type = 3, idx = 3}}, pyramid = 19875},
                {data = {{type = 2, idx = 1}, {type = 3, idx = 4}}, pyramid = 46050},
                {data = {{type = 2, idx = 1}, {type = 3, idx = 5}}, pyramid = 103500},

                {data = {{type = 2, idx = 2}, {type = 3, idx = 1}}, pyramid = 6900},
                {data = {{type = 2, idx = 2}, {type = 3, idx = 2}}, pyramid = 22950},
                {data = {{type = 2, idx = 2}, {type = 3, idx = 3}}, pyramid = 61500},
                {data = {{type = 2, idx = 2}, {type = 3, idx = 4}}, pyramid = 157500},
                {data = {{type = 2, idx = 2}, {type = 3, idx = 5}}, pyramid = 345000},

                {data = {{type = 2, idx = 3}, {type = 3, idx = 1}}, pyramid = 21225},
                {data = {{type = 2, idx = 3}, {type = 3, idx = 2}}, pyramid = 83250},
                {data = {{type = 2, idx = 3}, {type = 3, idx = 3}}, pyramid = 186750},
                {data = {{type = 2, idx = 3}, {type = 3, idx = 4}}, pyramid = 655500},
                {data = {{type = 2, idx = 3}, {type = 3, idx = 5}}, pyramid = 1552000},
            },  --multipler wilds T2 和 random wilds T3
            G3 = {  --
                {data = {{type = 5, idx = 1}, {type = 1, idx = 1}}, pyramid = 120},
                {data = {{type = 5, idx = 1}, {type = 1, idx = 2}}, pyramid = 300},
                {data = {{type = 5, idx = 1}, {type = 1, idx = 3}}, pyramid = 555},
                {data = {{type = 5, idx = 1}, {type = 1, idx = 4}}, pyramid = 945},
                {data = {{type = 5, idx = 1}, {type = 1, idx = 5}}, pyramid = 1635},

                {data = {{type = 5, idx = 2}, {type = 1, idx = 1}}, pyramid = 210},
                {data = {{type = 5, idx = 2}, {type = 1, idx = 2}}, pyramid = 420},
                {data = {{type = 5, idx = 2}, {type = 1, idx = 3}}, pyramid = 765},
                {data = {{type = 5, idx = 2}, {type = 1, idx = 4}}, pyramid = 1185},
                {data = {{type = 5, idx = 2}, {type = 1, idx = 5}}, pyramid = 1800},

                {data = {{type = 5, idx = 3}, {type = 1, idx = 1}}, pyramid = 435},
                {data = {{type = 5, idx = 3}, {type = 1, idx = 2}}, pyramid = 735},
                {data = {{type = 5, idx = 3}, {type = 1, idx = 3}}, pyramid = 1110},
                {data = {{type = 5, idx = 3}, {type = 1, idx = 4}}, pyramid = 1620},
                {data = {{type = 5, idx = 3}, {type = 1, idx = 5}}, pyramid = 2325},
            },  --sticky wilds T1 和expanding wildT5
        }
    }
    --[[
    客户端发送过来的数据格式
     -sticky wilds
    {type = 1, idx = 1}      --1~5, 表示固定个数,  其中 1表示1个
    -multipler wilds
    {type = 2, idx = 1}        --1-3, 表示倍率类型, 其中1: [2, 5], 2: [3,7], 3: [4,10]
    random wilds
    {type = 3, idx = 1}      --1~5, 表示随机的个数, 其中 1表示1个
    remove symbols
    {type = 4, idx = 1}    --1~5, 表示选择的类型, 其中 1：{13}; 2：{13, 12}; 3:{13, 12, 11}; 4:{13, 12, 11, 10}; 5:{13, 12, 11, 10, 9},
    expanding wild
    {type = 5, idx = 1}      -- 1~3, 表示扩展列的类型, 其中1：{5}; 2：{5, 4}; 3: {5, 4, 3}
    ]]
}
collectFree.addPyramid = function(deskInfo, num)
    local prevTotalPrize = deskInfo.collectFree.pyramid * deskInfo.collectFree.startPrize
    deskInfo.collectFree.pyramid = deskInfo.collectFree.pyramid + num
    deskInfo.collectFree.startPrize = math.floor((prevTotalPrize + deskInfo.totalBet * num) / deskInfo.collectFree.pyramid)
end

--牌局中增加随机金字塔
collectFree.randomPyramid = function(deskInfo)
    local ret = {}
    ret.before = deskInfo.collectFree.pyramid
    ret.info = {} 
    if deskInfo.currmult >= deskInfo.needbet then
        if math.random(0, 1000) <= COLLECTCFG.RANDOMPROBABILITY then
            local pos = {}
            for i = 1, GAME_CFG.COL_NUM*GAME_CFG.ROW_NUM do
                table.insert(pos, i)
            end
            local _, rs_cnt = utils.randByWeight(COLLECTCFG.RANDOMPYRAMID_CNT)
            local cnt = rs_cnt.num
            local randomPos = getSomeRandomPos(pos, cnt)
            for _, v in ipairs(randomPos) do
                local __, rs_point = utils.randByWeight(COLLECTCFG.RANDOMPYRAMID_POINT)
                ret.info["idx_"..v] = rs_point.num
                collectFree.addPyramid(deskInfo, rs_point.num)
            end
        end
    end
    ret.after = deskInfo.collectFree.pyramid
    return ret
end

collectFree.init = function(deskInfo, isClear)
    local pyramid = 0
    local startPrize = deskInfo.totalBet
    if isClear then     --清除数据时，金字塔合计数据不需要清除
        pyramid = deskInfo.collectFree.pyramid
        startPrize = deskInfo.collectFree.startPrize
    end
    COLLECTCFG.MINBETIDX = deskInfo.needbet or COLLECTCFG.MINBETIDX
    deskInfo.collectFree = {
        min = COLLECTCFG.MINBETIDX,
        state = false,
        startPrize = startPrize,
        recv = {},                                  --保存客户端51发过来的数据, 断线重连时需要
        types = {},                                 --免费游戏选择的其他附加类型
        pyramid = pyramid or 0,                                --自有的金字塔个数
        stickyWilds = {num = 0, pos = {}},          --固定的wild个数
        multiplerWilds = 0,                         --wild的倍率
        randomWilds = {num = 0, pos = {}},          --随机wild的个数
        removeSymbols = {},                         --需要移除的symbols符号（每一局发牌，看有没这组合内牌，有就需要替换掉）
        expandingWild = {},                         --需要扩展wild的几列，如果这一列有wild，则整列都需要变成wild
    }
end

collectFree.state = function(deskInfo)
    return deskInfo.collectFree.state
end

collectFree.updateState = function(deskInfo, flag)
    deskInfo.collectFree.state = flag
end

collectFree.set = function(deskInfo, type, idx)
    if type == COLLECTCFG.DEF.S1 and idx >= COLLECTCFG.DEF.SINGLE.S1.num.min and idx <=  COLLECTCFG.DEF.SINGLE.S1.num.max then
        deskInfo.collectFree.stickyWilds.num = idx
        table.insert(deskInfo.collectFree.types, type)
    elseif type == COLLECTCFG.DEF.S2 and idx >= COLLECTCFG.DEF.SINGLE.S2.num.min and idx <=  COLLECTCFG.DEF.SINGLE.S2.num.max then
        local mults = COLLECTCFG.DEF.SINGLE.S2.mults[idx]
        deskInfo.collectFree.multiplerWilds = math.random(mults[1], mults[2])
        table.insert(deskInfo.collectFree.types, type)
    elseif type == COLLECTCFG.DEF.S3 and idx >= COLLECTCFG.DEF.SINGLE.S3.num.min and idx <=  COLLECTCFG.DEF.SINGLE.S3.num.max then
        deskInfo.collectFree.randomWilds.num = idx
        table.insert(deskInfo.collectFree.types, type)
    elseif type == COLLECTCFG.DEF.S4 and idx >= COLLECTCFG.DEF.SINGLE.S4.num.min and idx <=  COLLECTCFG.DEF.SINGLE.S4.num.max then
        deskInfo.collectFree.removeSymbols = COLLECTCFG.DEF.SINGLE.S4.remove[idx]
        table.insert(deskInfo.collectFree.types, type)
    elseif type == COLLECTCFG.DEF.S5 and idx >= COLLECTCFG.DEF.SINGLE.S5.num.min and idx <=  COLLECTCFG.DEF.SINGLE.S5.num.max then
        deskInfo.collectFree.expandingWild = table.copy(COLLECTCFG.DEF.SINGLE.S5.expand[idx])
        table.insert(deskInfo.collectFree.types, type)
    end
end

--[[
    解析客户端传送的数据格式，转换成服务器数据
    数据格式{spin ={}, other ={{}}}
    ]]
collectFree.analyse = function(deskInfo, info)
    --获取免费旋转次数其他
    local num = info.spin.num 
    local spinPyramid = COLLECTCFG.DEF.SPINE.pyramid.init + (num - 1)*COLLECTCFG.DEF.SPINE.pyramid.add
    local freeCnt = num + 2 
    --获取其他组合的数据
    local data = info.other
    local otherPyramid = 0
    local conf      --conf为nil表示没有传对应的数据在游戏中
    if not table.empty(info.other) then
        local list
        if #data == 2 and data[1].type~= data[2].type then
            local types = {data[1].type, data[2].type}
            if table.contain(types, COLLECTCFG.DEF.S2) and table.contain(types, COLLECTCFG.DEF.S4) then
                list = COLLECTCFG.DEF.GROUP.G1
            elseif table.contain(types, COLLECTCFG.DEF.S2) and table.contain(types, COLLECTCFG.DEF.S3) then
                list = COLLECTCFG.DEF.GROUP.G2
            elseif table.contain(types, COLLECTCFG.DEF.S1) and table.contain(types,  COLLECTCFG.DEF.S5) then
                list = COLLECTCFG.DEF.GROUP.G3       
            end
            if list then
                for k, v in ipairs(list) do
                    local sameType1Idx = false  --= data[1].type
                    local haveType2Idx = false
                    for _, info in ipairs(v.data) do
                        if info.type == data[1].type and info.idx == data[1].idx then
                            sameType1Idx = true
                        end

                        if info.type == data[2].type and  info.idx == data[2].idx then
                            haveType2Idx = true
                        end
                    end
                    if sameType1Idx and haveType2Idx then
                        conf = v
                        break
                    end
                
                end
            end
            if conf then
                otherPyramid = conf.pyramid
               
            end
        end
        if #data == 1  then
            local type, idx = data[1].type, data[1].idx
            conf = COLLECTCFG.DEF.SINGLE["S"..type]
            if conf then
                otherPyramid = conf.pyramid[idx]
            end
        end
    end

    --realOtherPyramid(组合实际使用金币) = freeCnt(实际选择免费总次数) +  BASENUM (算分基础免费次数3次) + otherPyramid(组合算分基础免费次数为3次时组合的初始金币)
    local realOtherPyramid = math.floor(otherPyramid * freeCnt / COLLECTCFG.BASENUM)
    --pyramid (整体组合需要消耗的金字塔) = spinPyramid：免费次数需要消耗的金币 + realOtherPyramid组合实际需要消耗的金币
    local pyramid = spinPyramid + realOtherPyramid

    if deskInfo.collectFree.pyramid >= pyramid  then
        collectFree.updateState(deskInfo, true)
        if conf then
            if #data == 2 then
                collectFree.set(deskInfo, conf.data[1].type, conf.data[1].idx)
                collectFree.set(deskInfo, conf.data[2].type, conf.data[2].idx)
               
            else
                collectFree.set(deskInfo, data[1].type, data[1].idx)
            end
        end
        deskInfo.collectFree.pyramid = deskInfo.collectFree.pyramid - pyramid
        return {
            freeCnt = freeCnt, 
            pyramid = deskInfo.collectFree.pyramid,
            startPrize = deskInfo.collectFree.startPrize,
            types = table.copy(deskInfo.collectFree.types),   
        }
    else
        return {spcode = PDEFINE_ERRCODE.ERROR.SLOT_ERROR}
    end
end

--不需要每一局生成，只需要第一次生成就行
collectFree.stickyWilds = function(deskInfo, cards)
    local pos = {}
    for idx = 1, GAME_CFG.COL_NUM*GAME_CFG.ROW_NUM do
        table.insert(pos, idx)
    end
    if table.empty(deskInfo.collectFree.stickyWilds.pos) then
        local stickyPos = getSomeRandomPos(pos, deskInfo.collectFree.stickyWilds.num)
        deskInfo.collectFree.stickyWilds.pos = table.copy(stickyPos)
    end
    local copypos = table.copy(deskInfo.collectFree.stickyWilds.pos)
    local copy = table.copy(cards)
    for _, idx in ipairs(copypos) do
        copy[idx] = GAME_CFG.wilds[1]
    end
    return copy
end
--每一局都重新生成pos
collectFree.randomWilds = function(deskInfo, cards)
    local pos = {}
    for idx = 1, GAME_CFG.COL_NUM*GAME_CFG.ROW_NUM do
        table.insert(pos, idx)
    end
    local randomPos = getSomeRandomPos(pos, deskInfo.collectFree.randomWilds.num)
    deskInfo.collectFree.randomWilds.pos = randomPos
    local copy = table.copy(cards)
    for _, idx in ipairs(randomPos) do
        copy[idx] = GAME_CFG.wilds[1]
    end
    return copy
end

collectFree.expandingWild = function(deskInfo, cards)
    local copy = table.copy(cards)
    local wildCnt = 0
    local spcols = table.copy(deskInfo.collectFree.expandingWild)
    local spidxs = {}
    for _, col in ipairs(spcols)do
        local rowWildCnt = 0    --每列中wild的个数
        for row = 1, GAME_CFG.ROW_NUM do
            local idx = col + (row -1)*GAME_CFG.COL_NUM
            table.insert(spidxs, idx)
            if copy[idx] == GAME_CFG.wilds[1] then
                if rowWildCnt > 1 then
                    copy[idx] = RANDOMCARDS[math.random(1, #RANDOMCARDS)]
                else
                    rowWildCnt = rowWildCnt + 1
                end
            end
        end
        if rowWildCnt > 0 then
            wildCnt = wildCnt + 1
        end
    end

    if wildCnt == 0 then
        local pos = getSomeRandomPos(spidxs, 1)
        for _, idx in ipairs(pos)do
            copy[idx] = GAME_CFG.wilds[1]
        end
    end

    local retCards = table.copy(copy)
    for col = 1, GAME_CFG.COL_NUM do
        if table.contain(deskInfo.collectFree.expandingWild, col) then
            local haveWild = false
            for row = 1, GAME_CFG.ROW_NUM do
                local idx = col + (row -1)*GAME_CFG.COL_NUM
                if copy[idx] == GAME_CFG.wilds[1] then
                    haveWild = true
                end
            end
            if haveWild then
                for row = 1, GAME_CFG.ROW_NUM do
                    local idx = col + (row -1)*GAME_CFG.COL_NUM
                    copy[idx] = GAME_CFG.wilds[1]
                end
            end
        end
    end
    return retCards, copy
end

collectFree.getCards = function(deskInfo)
    local cardmap = cardProcessor.getCardMap(deskInfo, "collectfreemap")
    local cards = cardProcessor.get_cards_1(cardmap, GAME_CFG.COL_NUM, GAME_CFG.ROW_NUM)
    local retCards      --返回给客户端的牌
    if not table.empty(deskInfo.collectFree.types) then
        for _, type in ipairs(deskInfo.collectFree.types) do
            if type == COLLECTCFG.DEF.S1 then
                cards = collectFree.stickyWilds(deskInfo, cards)
            elseif type == COLLECTCFG.DEF.S3 then
                cards = collectFree.randomWilds(deskInfo, cards)
            elseif type == COLLECTCFG.DEF.S4 then
                local randomCards = table.copy(RANDOMCARDS)
                for _, v in ipairs(deskInfo.collectFree.removeSymbols) do
                    local idx = findIdx(randomCards, v)
                    table.remove(randomCards, idx)
                end
                for k, v in ipairs(cards) do
                    if table.contain(deskInfo.collectFree.removeSymbols, v) then
                        cards[k] = randomCards[math.random(1, #randomCards)]
                    end
                end
            elseif type == COLLECTCFG.DEF.S5 then
                retCards, cards = collectFree.expandingWild(deskInfo, cards)
            end
        end
    end
    if retCards == nil then
        retCards = table.copy(cards)
    end
    return retCards, cards
end

-- ================正常游戏逻辑=======================

local function getLine()
	return GAME_CFG.line
end

local function getInitMult()
	return GAME_CFG.defaultInitMult
end

local function create(deskInfo, uid)
    if deskInfo.select == nil then
        deskInfo.select = {state = false}
    end
    if deskInfo.collectFree == nil then
        collectFree.init(deskInfo)
    else
        deskInfo.collectFree.min = deskInfo.needbet         --设置收集游戏的开启档位
        if not deskInfo.collectFree.startPrize then
            deskInfo.collectFree.startPrize = deskInfo.totalBet
        end
    end
end

--计算玩家押注额以及减去押注后的金币 lastBetCoin
local function caulBet(deskInfo)
    --扣押注额
    local betCoin = -deskInfo.totalBet
    deskInfo.lastBetCoin = deskInfo.user.coin
    if isFreeState(deskInfo) or collectFree.state(deskInfo) then
        betCoin = 0
    else
        cashBaseTool.caulCoin(deskInfo, betCoin, PDEFINE.ALTERCOINTAG.BET)
    end
    deskInfo.lastBetCoin = Double_Add(deskInfo.lastBetCoin, betCoin)
    return betCoin
end

local function start_697(deskInfo)
    local result = {}
    --发牌
    if collectFree.state(deskInfo) then --收集免费发牌，遵循规则
        local caulCards
        result.resultCards, caulCards = collectFree.getCards(deskInfo)
        --计算结果
        result.winCoin, result.zjLuXian, result.scatterResult = settleTool.getBigGameResult(deskInfo, caulCards, GAME_CFG)
        -- 这里需要使用平均下注额
        local ratio = deskInfo.collectFree.startPrize / deskInfo.totalBet
    
        for _, rs in pairs(result.zjLuXian) do
            rs.coin = math.round_coin(rs.coin * ratio)
        end
        result.winCoin = math.round_coin(result.winCoin * ratio)
    else   --免费游戏发牌
        
        --发牌
        result.resultCards = cardProcessor.get_cards_3(deskInfo, GAME_CFG)
        
        --===============测试配牌代码===============
        local design = cashBaseTool.addDesignatedCards(deskInfo)
        if design ~= nil then
            result.resultCards = table.copy(design)
        end
        --===============测试配牌代码===============
        if isFreeState(deskInfo) and not collectFree.state(deskInfo) then
            result.resultCards = baseFree.setCards(deskInfo, result.resultCards)
        end

        --计算结果
        result.winCoin, result.zjLuXian, result.scatterResult = settleTool.getBigGameResult(deskInfo, result.resultCards, GAME_CFG)

    end
    --如果是收集游戏中wild，需要把wild的倍数算上
    if collectFree.state(deskInfo) and deskInfo.collectFree.multiplerWilds > 0 then
        result.winCoin = 0
        for _, info in pairs(result.zjLuXian) do
            local mult = 1
            for _, idx in pairs(info.indexs)do
                if result.resultCards[idx] == GAME_CFG.wilds[1] then
                    mult = mult * deskInfo.collectFree.multiplerWilds
                end
            end
            info.coin = info.coin*mult
            result.winCoin = result.winCoin + info.coin
        end
    end
	--检车是否触发免费
    result.freeResult = freeTool.checkFreeGame(result.resultCards, GAME_CFG.freeGameConf)
    return cashBaseTool.genRetobjProto(deskInfo, result)
end


local function settle_697(deskInfo, betCoin, retobj)
    local isFreeState = isFreeState(deskInfo)
    if isFreeState then
        updateFreeData(deskInfo, 2, nil, nil, retobj.wincoin)
    else
        if table.empty(retobj.freeResult.freeInfo) then
            cashBaseTool.caulCoin(deskInfo, retobj.wincoin, PDEFINE.ALTERCOINTAG.WIN)
        end
    end

    if not table.empty(retobj.freeResult.freeInfo) then
        deskInfo.select = {state = true, rtype = 1, wincoin = retobj.wincoin}
    end
    cashBaseTool.genFreeProto(deskInfo, retobj)  --产生免费游戏数据结果
    local result = {
        kind = betCoin==0 and "free" or "base",
        cards = retobj.resultCards
    }
    baseRecord.slotsGameLog(deskInfo, betCoin, retobj.wincoin, result, 0)
    if isFreeState and deskInfo.freeGameData.restFreeCount <= 0 then
        if collectFree.state(deskInfo) then
            collectFree.init(deskInfo, true)
        end
        updateFreeData(deskInfo, 3)
    end

	retobj.coin = deskInfo.user.coin  --最新的玩家金币
end

local function start(deskInfo)
    --判断是否需要选择,如果需要选择，强制客户端选择
    if deskInfo.select and deskInfo.select.state then
        return {
			spcode = PDEFINE_ERRCODE.ERROR.SLOT_ERROR
		}
    end
    if isFreeState(deskInfo) then
		deskInfo.control.freeControl.probability = 0
    end
    local betCoin = caulBet(deskInfo)
    local freeType = FREETYPE.NONE
    if collectFree.state(deskInfo) then
        freeType = FREETYPE.COLLECTFREE
    elseif isFreeState(deskInfo) then
        freeType = FREETYPE.COMMONFREE
    else
        freeType = FREETYPE.NONE
    end
    local retobj = start_697(deskInfo)
    baseFree.start(deskInfo, retobj)
    --判断是否触发奖池游戏
    if table.empty(retobj.freeResult.freeInfo) then
        local triPoolGame, wheel = poolGame.tri(deskInfo, retobj.resultCards)
        if triPoolGame then
            retobj.wheel = wheel
            retobj.poolList = deskInfo.poolGame.poolList
        end
    end
    --随机添加金字塔数据
    if not collectFree.state(deskInfo) then
        retobj.pyramid = collectFree.randomPyramid(deskInfo)
    end
    --收集免费中返回收集对应的数据
    if collectFree.state(deskInfo) then
        retobj.collectFree = deskInfo.collectFree
    end
    --正常免费游戏返回对应的游戏类型
    if isFreeState(deskInfo) and not collectFree.state(deskInfo) then
        retobj.baseFree = {
            type = deskInfo.freeGameData.rtype,             --正常免费游戏类型
            free7Wilds = deskInfo.freeGameData.free7Wilds,  --正常免费游戏7wilds中返回数据(随机wild的位置)
            boxs = deskInfo.freeGameData.boxs
        }
    end
    retobj.freeType = freeType
    if freeType == FREETYPE.COLLECTFREE then
        -- 将平均下注额暴露出来
        retobj.avgBet = deskInfo.collectFree.startPrize
    end
    --结算游戏
    settle_697(deskInfo, betCoin, retobj)
    retobj.select = deskInfo.select
    gameData.set(deskInfo)
	return retobj
end

--[[
	断线重连
]]
local function addSpecicalDeskInfo(deskInfo, simpleDeskData)
    simpleDeskData.freeGameData = deskInfo.freeGameData
    simpleDeskData.select = deskInfo.select
    simpleDeskData.poolGame = deskInfo.poolGame
    simpleDeskData.collectFree = deskInfo.collectFree
	return simpleDeskData
end

local function resetDeskInfo(deskInfo)
	gameData.set(deskInfo)
end

local function gameLogicCmd(deskInfo, recvobj)
	local retobj = {}
    local rtype = math.floor(recvobj.rtype)
    local isFree = isFreeState(deskInfo)
    if deskInfo.select.state then
        if rtype == 1 and deskInfo.select.rtype == 1  and not isFree then 
            retobj = baseFree.getType(deskInfo)             --触发免费游戏
            updateFreeData(deskInfo, 1, retobj.freeCnt, 1, deskInfo.select.wincoin, retobj)
            retobj.boxs = baseFree.setSevenBoxs(deskInfo)       --只有2.3类型才会有返回
            retobj.select = deskInfo.select
        elseif rtype == 2 and deskInfo.select.rtype == 2  and isFree then 
            local idx = math.floor(recvobj.idx)
            retobj = baseFree.spin7Pick(deskInfo, idx)
            clearSelect(deskInfo)
        elseif rtype == 3 and deskInfo.select.rtype == 3  and isFree then 
            local idx = math.floor(recvobj.idx)
            retobj = baseFree.spin7Wins(deskInfo, idx)
            clearSelect(deskInfo)
        elseif rtype == 4 and deskInfo.select.rtype == 4 and not isFree then     --奖金游戏
            retobj = poolGame.get(deskInfo) 
            local result = {
                kind = "bonus",
                desc = "pool game wheel",
            }
            baseRecord.slotsGameLog(deskInfo, 0, retobj.coin, result, 0)
            clearSelect(deskInfo)
        end
    end
    if rtype == 5 and  deskInfo.collectFree.pyramid > 0 and not isFree then --(需要客户端做处理，免费状态不可点击)
        retobj = collectFree.analyse(deskInfo, recvobj)  --触发收集类免费游戏
        if retobj.freeCnt then
            updateFreeData(deskInfo, 1, retobj.freeCnt, 1, 0, deskInfo.collectFree)
        end
        deskInfo.collectFree.recv = recvobj
        retobj.recv = recvobj
    end
	retobj.rtype = rtype
	gameData.set(deskInfo)
	return retobj
end

return {
	cardsConf = GAME_CFG.RESULT_CFG,
	mults = GAME_CFG.mults,
	line = GAME_CFG.line,
	create = create,
	start = start,
	resetDeskInfo = resetDeskInfo,
	getInitMult = getInitMult,
    getLine = getLine,
    gameLogicCmd = gameLogicCmd,
	addSpecicalDeskInfo = addSpecicalDeskInfo,
}



--[[
1.44中新增返回
1.1.触发免费游戏，旋转结果
    ["select"] = {["state"] = true,["rtype"] = 1,},

1.2.金字塔数据
    ["pyramid"] = {
            ["after"] = 51,   --叠加后的数据
            ["info"] = {
                    ["idx_9"] = 18, --对应idx上显示的数据
                    ["idx_13"] = 16,
                    ["idx_5"] = 8,
                    ["idx_17"] = 6,
                    ["idx_1"] = 3,
            },
            ["before"] = 0,     --左上角展示的总数据
    },

1.3.触发奖金游戏（需要上行协议，以及对应的将进游戏配置）
    ["select"] = {["state"] = true,["rtype"] = 3,},
     ["wheel"] = {
                [1] = {["type"] = 1,["coin"] = 0,},
                [2] = {["type"] = 5,["coin"] = 0, },
                [3] = {["type"] = 4,["coin"] = 0,},
                [4] = {["type"] = 3,["coin"] = 40000,},
                [5] = {["type"] = 1,["coin"] = 30000,},
                [6] = {["type"] = 3, ["coin"] = 0,},
                [7] = {["type"] = 2,["coin"] = 0,},
        },
    其中： 
        {
        type = 1, --MINI
        type = 3, --MINOR
        type = 5, --MAJOR
        type = 2, --MEGA
        type = 4, --GRAND
        }
    {["type"] = 3,["coin"] = 40000,}, 表示  MINOR奖池+400000金币

1.4 正常免费游戏返回数据（客户端需要做判空处理, 收集免费不下发该字段）
retobj.baseFree = {
            rtype = 1-4,             --正常免费游戏类型1, --7spine   2, --7PRIZES  3, --7WIN       4, --7wilds
            free7Wilds = {1,5,9},  --正常免费游戏7wilds中返回数据(随机wild的位置)
            boxs ={4, 6, 7, 8, 9, 10, 10}
        }
    
1.5.新增错误码返回
spcode = 967, 	--流程错误, 有需要选择时没有选择


--2：51 
2.1 触发免费游戏，旋转结果
	传入数据格式
	c : {c: 51, uid:*, gameid:*, data:{rtype:1}} 
    返回数据格式：
    {"data":{
        "select" = {"state" = true,"rtype" = 2,},   --type= 1才会下发该字段, 需要上行cmd51，rtype= 2 --type= 3才会下发该字段, 需要上行cmd51，rtype= 3
        "rtype" = 1,    
        "freeCnt" = 7,      --免费次数
        "type" = 1,       --旋转结果，解释在下行
        "boxs" = {4, 6, 7, 8, 6, 8, 10},    --玩家需要展示在客户端的7个格子信息(只有result = 2/3类型才会有返回，4是固定的，1需要再次上行51的rtype=2返回)
	},
    "uid":102596,"c":51,"code":200}
    其中： result  1--7spine， 2--7PRIZES, 3--7WIN  4--7wilds

2.2 触发7Spin免费游戏，需要(7spins：在三个图案选择一个，会随机出现一个乘数，所选乘数将运用到最后4次旋转中)
    传入数据格式
        c : {c: 51, uid:*, gameid:*, data:{rtype:2, idx = 1}}  idx：1~3
    返回数据格式：
    {"data":{
            ["type"] = 1,       --免费子游戏类型
            ["idx"] = 1,
            ["mult"] = 6,       --中奖的倍数
            ["rtype"] = 2,
            ["conf"] = {        --倍数配置
                    [1] = 6,
                    [2] = 8,
                    [3] = 10,
            },
            boxs = {4, 6, 7, 8, 6, 8, 10},    --玩家需要展示在客户端的7个格子信息
        }
    "uid":102596,"c":51,"code":200}
2.3 触发7wins免费游戏，
    传入数据格式
        c : {c: 51, uid:*, gameid:*, data:{rtype:2, idx = 1}}  idx：1~3
    返回数据格式：
    {"data":{
            ["type"] = 3,       --免费子游戏类型
            ["idx"] = 1,
            ["mult"] = 6,       --中奖的倍数
            ["rtype"] = 2,
            ["conf"] = {        --倍数配置
                    [1] = 6,
                    [2] = 8,
                    [3] = 10,
            },
            boxs = {4, 6, 7, 8, 6, 8, 10},    --玩家需要展示在客户端的7个格子信息
        }
    "uid":102596,"c":51,"code":200}


2.4 触发奖金游戏
    传入数据格式
    c : {c: 51, uid:*, gameid:*, data:{rtype:4}} 
    返回数据格式：
    {"data":{
            ["result"] = {      --获取的中奖结果类型
                ["type"] = 3,
                ["coin"] = 50000,   
            },
            ["coin"] = 150000,      --获取的金币
            ["idx"] = 4,            --中奖结果对应的wheel中的idx
            ["rtype"] = 4,
        }
    "uid":102596,"c":51,"code":200}

    其中： 
        {
        type = 1, --MINI
        type = 2, --MINOR
        type = 3, --MAJOR
        type = 4, --MEGA
        type = 5, --GRAND
        }
    {["type"] = 3,["coin"] = 40000,}, 表示  MINOR奖池+400000金币

2.5 金字塔免费游戏(组合种类详细列表如下)
    前提: 
        客户端发送过来的数据格式
        -sticky wilds
        {type = 1, idx = 1}      --1~5, 表示固定个数,  其中 1表示1个
        -multipler wilds
        {type = 2, idx = 1}        --1-3, 表示倍率类型, 其中1: [2, 5], 2: [3,7], 3: [4,10]
        random wilds
        {type = 3, idx = 1}      --1~5, 表示随机的个数, 其中 1表示1个
        remove symbols
        {type = 4, idx = 1}    --1~5, 表示选择的类型, 其中 1：{13}; 2：{13, 12}; 3:{13, 12, 11}; 4:{13, 12, 11, 10}; 5:{13, 12, 11, 10, 9},
        expanding wild
        {type = 5, idx = 1}      -- 1~3, 表示扩展列的类型, 其中1：{5}; 2：{5, 4}; 3: {5, 4, 3}

    上行 ：
        1. 次数+类型1-5单独
            {  data = {rtype=5, spin={num=3}, other = {{type = 1, idx = 1}}}}  --other详见上述表示
        2. 次数+组合类型
            data.other = {{type = 2, idx = 1-3}, {type = 4, idx = 1}}; 
            data.other = {{type = 2, idx = 1}, {type = 3, idx = 1}}; 
            data.other = {{type = 1, idx = 1}, {type = 5, idx = 1}}

    下行：
        {"data":{
                ["pyramid"] = 99745,        --剩余金字塔数
                ["rtype"] = 5,
                ["types"] = {               --选择的免费游戏中奖使用到的类型
                        [1] = 1,
                },
                ["freeCnt"] = 6,            --免费次数
            }
        "uid":102596,"c":51,"code":200}
]]

