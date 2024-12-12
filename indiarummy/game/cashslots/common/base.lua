local skynet  = require "skynet"
local cjson = require "cjson"
local cluster = require "cluster"
local game_tool = require "game_tool"
local player_tool = require "base.player_tool"
local config = require"cashslots.common.config"
local freeTool = require "cashslots.common.gameFree"
local baseRecord = require "base.record"
local updateFreeData = freeTool.updateFreeData
local isFreeState = freeTool.isFreeState
local gameRecord = require "cashslots.common.gameRecord"
local casetesting = require "casetesting.casetesting"
local gameData = gameRecord.gameData
local record = gameRecord.pushLog

--大奖特效配置
local SpEffectConf = {
    bigwin = 10,
    hugewin = 20,
    outwin = 40,
    megawin = 60,
    outmegabigwin = 80,
}
--==================特效处理
local function getBigWinHugeWin(deskInfo, wincoin, bet)
    local effectMultCOnf = {
        [1] = SpEffectConf.bigwin,
        [2] = SpEffectConf.hugewin,
        [3] = SpEffectConf.outwin,
        [4] = SpEffectConf.megawin,
        [5] = SpEffectConf.outmegabigwin,
    }

    local spEffect = {kind = 0, wincoin = 0}
    spEffect.wincoin = wincoin or 0
    for i = #effectMultCOnf, 1, -1 do
        if spEffect.wincoin / (bet or deskInfo.totalBet) >= effectMultCOnf[i] then
            spEffect.kind = i
            break
        end
    end
    return spEffect
end

--玩家金币操作处理
local function caulCoin(deskInfo, coin, type)
    local poolround_id = 0
    coin = Double_Add(coin, 0)
    player_tool.calUserCoinSlot(
        deskInfo.user.uid, 
        coin, 
        deskInfo.issue, 
        type, 
        deskInfo,
        poolround_id
    )
    deskInfo.user.coin = Double_Add(deskInfo.user.coin, coin)
    if type == PDEFINE.ALTERCOINTAG.WIN then
        deskInfo.lastWinCoin = coin
    end
end

--计算玩家押注额以及减去押注后的金币 lastBetCoin
local function caulBetandLastBetCoin(deskInfo)
    --扣押注额
    local betCoin = -deskInfo.totalBet
    deskInfo.lastBetCoin = deskInfo.user.coin
    if isFreeState(deskInfo) then
        betCoin = 0
    else
        caulCoin(deskInfo, betCoin, PDEFINE.ALTERCOINTAG.BET)
    end
    deskInfo.lastBetCoin = Double_Add(deskInfo.lastBetCoin, betCoin)
    return betCoin
end

local function genFreeProto(deskInfo, retobj)
    --1. 免费游戏相关数据
    local freeGameData = table.copy(deskInfo.freeGameData)
    retobj.addMult = freeGameData.addMult or 0       --       
    retobj.allFreeCnt = freeGameData.allFreeCount
    retobj.freeCnt = freeGameData.restFreeCount
    retobj.freeWinCoin = freeGameData.freeWinCoin
    retobj.freeResult.triFreeCnt = deskInfo.freeGameData.triFreeData.triFreeCnt       -- 触发免费的次数
    -- retobj.doubleAward = freeGameData.doubleAward --TODO: 应该是可以去除的
end
--[[
  固定返回客户单数据格式
  ****返回字段缺一不可****

  其中： spEffectCoin  --免费游戏期间只有结束一局才有特效，deskInfo.freeGameData.freeWinCoin
]]
local function genRetobjProto(deskInfo, result)
  local retobj = {}
  -- 1.正常格子相关数据
  retobj.spcode = 200
  retobj.code = PDEFINE.RET.SUCCESS
  retobj.betcoin = deskInfo.totalBet    
  retobj.coin = result.coin                       --必须传入字段(玩家最终金币)
  retobj.wincoin = result.winCoin                 --必须传入字段( winCoin > 0)          
  retobj.resultCards = result.resultCards         --必须传入字段(牌型 {1,2,3,4,5,6,..15})
  retobj.zjLuXian = result.zjLuXian or {}         --必须传入字段(中奖线路 zjLuXian = {{indexs = {1,2,3} //表示线路, coin = 0 //此线路赢的钱 }, ...})
  retobj.scatterZJLuXian = result.scatterResult    --必须传入字段(散列图标中奖线路 --> scatterResult = {{index = {}, coin = 0}})
  retobj.bonusResult = result.bonusResult         
  retobj.pooljp = result.pooljp or 0               --jp奖励金钱
  retobj.lastBetCoin = deskInfo.lastBetCoin        --必须传入字段
  retobj.spLuXian =  result.spLuXian or 0          --全屏奖励的卡牌
  if not result.pooljp and not TEST_RTP then       -- 必须返回字段，客户端特效展示 spEffectCoin>0
      retobj.spEffect = getBigWinHugeWin(deskInfo, result.spEffectCoin)
  end
  retobj.nextBetLine = {spcode= 500 }              --客户端已经去掉这个功能
  retobj.x = result.COL_NUM or 5                   -- 游戏的列数(后台需要)
  retobj.y = result.ROW_NUM or 3                   -- 游戏的行数(后台需要)

  --1.触发免费的信息
  retobj.freeResult = {
        freeInfo = result.freeResult or {},               --checkFreeGame返回的数据{触发免费的卡牌scatter：*, 触发的次数：freeCnt:*，触发的翻倍：addMult:*, 可选参数：卡牌所在的位置，客户端展示动画需要indexs:{6,8,9}}
    }
  
  --2. 子游戏数据(暂时的游戏并没有，为客户端数据统一)
  retobj.subGameInfo = {
      subGamid = deskInfo.subGame.subGameId, 
      isMustJoin = deskInfo.subGame.isMustJoin
  }

  return retobj
end

--[[
    *********会修改传入的retobj**********
    普通游戏给玩家加金币，
    免费游戏把金币叠加在freeWinCoin上, 
    更新玩家返回金币,
    记录玩家返回最终数据
]]
local function settle(deskInfo, betCoin, retobj)
    local isFreeState = isFreeState(deskInfo)
    if isFreeState then
        --正常免费数据递减次数
        updateFreeData(deskInfo, 2, nil, nil, retobj.wincoin)
        --免费中触发免费
        if not table.empty(retobj.freeResult.freeInfo) then
            local freeInfo = table.copy(retobj.freeResult.freeInfo)
            updateFreeData(deskInfo, 1, freeInfo.freeCnt, freeInfo.addMult, 0, freeInfo)
        end
    else
        --普通中触发免费游戏，金币需要叠加在freeWinCoin上
        if not table.empty(retobj.freeResult.freeInfo) then
            local freeInfo = table.copy(retobj.freeResult.freeInfo)
            updateFreeData(deskInfo, 1, freeInfo.freeCnt, freeInfo.addMult, retobj.wincoin, freeInfo)
        else
            caulCoin(deskInfo, retobj.wincoin, PDEFINE.ALTERCOINTAG.WIN)
        end
    end

    genFreeProto(deskInfo, retobj)  --产生免费游戏数据结果
    local result = {
        kind = betCoin==0 and "free" or "base",
        cards = retobj.resultCards
    }
    baseRecord.slotsGameLog(deskInfo, betCoin, retobj.wincoin, result, 0)
    if isFreeState and deskInfo.freeGameData.restFreeCount <= 0 then
        updateFreeData(deskInfo, 3)
    end

	gameData.set(deskInfo)
	retobj.coin = deskInfo.user.coin  --最新的玩家金币
end

--[[
    触发每种游戏，取牌的可能性
    freeControl：免费游戏
    bonusControl：特殊游戏，需要卡牌规则触发的游戏，比如3个5好卡牌触发**游戏
]]
local function probability(deskInfo, rtype)
    local deskFree = isFreeState(deskInfo)
    if rtype == "free" then
        local random_free = math.random(0, 1000)
        local free_probability = deskInfo.control.freeControl.probability
        if deskFree then
            if free_probability > 5 then
                free_probability = math.floor(free_probability/4)
            else
                free_probability = math.floor(free_probability/2)
            end
        end
        if random_free < free_probability then
            return 1
        else
            return 0
        end
    elseif rtype == "bonus" then
        local random_sub = math.random(0, 1000)
        local bonus_probability = deskInfo.control.bonusControl.probability
        if deskFree then
            bonus_probability = bonus_probability * 0.1
            local allCount = 1
            if nil ~= deskInfo.freeGameData and nil ~= deskInfo.freeGameData.allFreeCount then
                allCount = deskInfo.freeGameData.allFreeCount
            end
            bonus_probability = keepTwoDecimalPlaces(bonus_probability/allCount)
        end
        if random_sub < bonus_probability then
            return 1
        else
            return 0
        end
    end
end

--[[
    获取奖池金额
    gameid: 游戏ID
    jpIdx: 奖池索引
    totalBet: 总押注
]]--
local function getJackpotValueByBet(gameid, jpIdx, totalBet)
    return skynet.call(".jackpotmgr", "lua", "getJackpotValueByBet", gameid, jpIdx, totalBet)
end

-- 测试从客户端设计的代码
local function addDesignatedCards(deskInfo)
    local caseCards = casetesting.getCaseCards(deskInfo.gameid, deskInfo.user.uid)
    if caseCards and type(caseCards) == "table" and #caseCards >= 15 then
      LOG_DEBUG("addDesignatedCards-caseCards:", table.concat(caseCards, ","))
      return caseCards
    end
  end

--[[
功能: 根据档位保存不同的信息数据
参数解释: 
    state:      使用情形 init 初始化  set：更新保存某一个档位的数据 get：根据档位数获取信息
    betIndex:   客户端选择的押注档位
    key:        保存的数据键
    value:      保存的数据
]]
local function history(deskInfo, act, data)
    local key = data.key
    local value = data.value
    local betIndex
    if data.betIndex then
        betIndex =  math.floor(data.betIndex) 
    end
    --初始化数据
    if act == "init" then --上行格式data = {key =, value = ,}
        deskInfo.history = deskInfo.history or {}
        deskInfo.history[key] = deskInfo.history[key] or {}
        local maxMult = deskInfo.maxMult or 25
        for i = 1, maxMult do
            deskInfo.history[key][i] = table.copy(value)
        end
    elseif act == "update" then  --上行格式data = {key =, value = ,}
        deskInfo.history[key][betIndex] = table.copy(value)
    elseif act == "get" then     --上行格式data = {key =, betIndex = ,}
        return deskInfo.history[key][betIndex]
    end
end

return {
    settle = settle,                                --44协议游戏结束相关功能模块
    probability = probability,                      --取牌的概率
    caulCoin = caulCoin,                            --计算金币
    genFreeProto = genFreeProto,                    --44免费游戏返回格式(不可变)
    genRetobjProto = genRetobjProto,                --44固定返回协议数据格式(不可变)
    caulBetandLastBetCoin = caulBetandLastBetCoin,  --计算玩家押注额以及押注后的金币(已包含免费不扣押注额，如果有其他功能模块，游戏重写)
    getJackpotValueByBet = getJackpotValueByBet,    --获取奖池金额
    addDesignatedCards = addDesignatedCards,
    history = history,
    getBigWinHugeWin = getBigWinHugeWin,
}

--[[
etc/config.master 中 lua_path新增       
    "./game/cashslots/config/?.lua;"


--一个slot的组成
    1.global/language中配置中英文
    2.数据库中s_sess, s_game, s_game_type中配置
    3.game/cashslots/config中每项配置中配置好对应的数据
    4.新建一个slot_游戏id的lua文件，必要返回
        {
            	mults = GAME_CFG.mults,
                line = GAME_CFG.line,
                create = create,                --创建房间
                start = start,                  --44协议逻辑处理
                gameLogicCmd = gameLogicCmd,    --51协议逻辑处理
	            addSpecicalDeskInfo = addSpecicalDeskInfo,  --断线重连需要新增返回的数据(通用返回在slotsagent中的getSimpleDeskData方法)
        }

---业务逻辑处理
1.检测是否扣押注额
        1.1 调用caulBetandLastBetCoin
        1.2 游戏根据自己逻辑重写该方法
2. 取牌
    根据卷轴取牌方法：
    local cardProcessor = require "cashslots.common.cardProcessor"
    方法1:(包含概率模式)
    local funList = {
                getResultCards = getResultCards,    
                checkFreeGame = checkFreeGame,
                checkSubGame = checkTriFireGame,
            }
    local cards =  cardProcessor.get_catds_3(deskInfo, GAME_CFG, funList)
    其中： funList 可选参数
    方法2:(不包含概率，通用卷轴数据，正常使用cardmap, 免费使用freemap)
    local cards = cardProcessor.get_catds_2(deskInfo)
    方法3:(不包含概率，自定义卷轴数据)
    local cards = cardProcessor.get_catds_1(cardmap, COL_NUM, ROW_NUM)

3.检测是否触发免费游戏
    3.1 调用通用检测规则（有3个对应图标触发，游戏中GAME_CFG中需配置freeGameConf，格式参考任意游戏）
        local freeTool = require "cashslots.common.gameFree"
        local freeInfo = freeTool.checkFreeGame(resultCards, GAME_CFG.freeGameConf)
    3.2 重写checkFreeGame方法，返回数据参考freeTool.checkFreeGame

4.格子连线算分
    4.1 调用通用方法，根据线路以及配置赔率计算分数
        local settleTool = require "cashslots.common.gameSettle"
        local  winCoin, traceResult, scatterResult = settleTool.getBigGameResult(deskInfo, cards, GAME_CFG)
    4.2 重写，返回数据格式参考上述

5. 游戏单独业务逻辑处理
    ***********

6. 结算返回44通用数据格式以及处理免费游戏的增加减以及金币结算
    6.1 调用settle方法，处理免费游戏的增加减
    6.2 重写，游戏内单独处理逻辑

7. 游戏单独返回数据增加
    tip：游戏单独有数据新增时，谨记调用gameData.set() 以及 record() 方法，保存最新的deskInfo数据以及上报最新游戏数据
]]