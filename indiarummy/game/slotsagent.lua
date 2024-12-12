local skynet = require "skynet"
local cluster = require "cluster"
local cjson   = require "cjson"
local queue = require "skynet.queue"
local date = require "date"
-- 游戏业务逻辑
local baseFunc = require "cashslots.common.base"
local baseTool = require "cashslots.common.baseTool"
local confDefine = require"cashslots.common.config"
local player_tool = require "base.player_tool"
local gameRecord = require "cashslots.common.gameRecord"
local gameControl = require "cashslots.common.gameControl"		--419游戏后配置路径不一致
local freeTool = require "cashslots.common.gameFree"
local Strategy = require "cashslots.control.strategy"
local config = require"cashslots.common.config"
local def = require "cashslots.control.def"
local sysmarquee = require "sysmarquee"

local isFreeState = freeTool.isFreeState

local ADD_RP_VALUE = def.ADD_RP_VALUE
local ADD_RP_PROBABILITY = def.ADD_RP_PROBABILITY

local BET_MB_PROBABILITY = def.BET_MB_PROBABILITY  --押注转化为金猪存量的概率
local BET_MB_PROPORTION = def.BET_MB_PROPORTION --押注转化为金猪存量的比例

local WINCOIN_LEAGUESCORE_PROPORTION = def.WINCOIN_LEAGUESCORE_PROPORTION --赢分转化为联赛积分的比例

cjson.encode_sparse_array(true) 
cjson.encode_empty_table_as_object(false) --降空table{}打包成[]
local cs = queue()
skynet.register_protocol {
    name = "client",
    id = skynet.PTYPE_CLIENT,
    unpack = skynet.tostring,
}

local GAME_NAME = skynet.getenv("gamename") or "game"
local IS_DEBUG = skynet.getenv("debug") or 0
local TOTAL_SPIN_CNT_KET = "slot:spin:count:"  -- 存放用户spin的次数
local DEBUG = os.getenv("DEBUG")

local leagueInfo = nil   --联赛信息

local closeServer = nil
-- game节点的全局服务

local gameCfg = {}
-- 桌子用户信息
--- @class SlotDeskInfo
local deskInfo = {
    user = {},
    state = confDefine.GAME_STATE["NORMAL"]
}
local timeout = {24*60*60} --24小时不操作
local strategy = nil        --控制策略
local herocarddroppolicy = nil    --英雄卡牌策略

--设置随机数种子
math.randomseed(tostring(os.time()):reverse():sub(1, 7))

-- 接口函数组
local CMD = {}
local usersAutoFuc --玩家定时器

function CMD.resetDesk()
    if not deskInfo.gameid then
        return
    end

    if gameCfg.resetDeskInfo then
        gameCfg.resetDeskInfo(deskInfo)
    end

    local tmpDeskid = deskInfo.deskid
    local tmpGameid = deskInfo.gameid
    local tmpUser = deskInfo.user
    deskInfo = {}
    deskInfo.user = {}
    deskInfo.state = confDefine.GAME_STATE["NORMAL"]
    leagueInfo = nil
    if tmpUser.cluster_info then
        pcall(cluster.send, "game", ".dsmgr", "recycleAgent", skynet.self(), tmpDeskid, tmpGameid)
        pcall(cluster.send, tmpUser.cluster_info.server, tmpUser.cluster_info.address, "deskBack", tmpGameid) --释放桌子对象
    end
end

-- 广播给房间里的所有人
local function broadcastDesk(retobj)
    if deskInfo.user and deskInfo.user.cluster_info then
        pcall(cluster.send, deskInfo.user.cluster_info.server, deskInfo.user.cluster_info.address, "sendToClient", retobj)
    end
end

--广播给所有玩家
local function broadcastWorld(retobj)
    pcall(cluster.send, "master", ".userCenter", "broadcastWorld", retobj)
end

local function sysCloseServer()
    --释放该用户的桌子对象
    local user = deskInfo.user
    if user then
        if usersAutoFuc then
            usersAutoFuc()
        end
        if user.cluster_info then
            local retobj    = {}
            retobj.code     = PDEFINE.RET.SUCCESS
            retobj.c        = PDEFINE.NOTIFY.NOTIFY_SYS_KICK
            retobj.uid      = user.uid
            pcall(cluster.send, user.cluster_info.server, user.cluster_info.address, "sendToClient", cjson.encode(retobj))
        end
    end
    CMD.resetDesk()
end

local function sysKickUser()
    --释放该用户的桌子对象
    local user = deskInfo.user
    if user then
        if usersAutoFuc then
            usersAutoFuc()
        end
        local retobj    = {}
        retobj.code     = PDEFINE.RET.SUCCESS
        retobj.c        = PDEFINE.NOTIFY.ALL_GET_OUT
        retobj.uid      = user.uid
        if user.cluster_info then
            pcall(cluster.send, user.cluster_info.server, user.cluster_info.address, "sendToClient", cjson.encode(retobj))
        end
    end
    
    CMD.resetDesk()
    return PDEFINE.RET.SUCCESS
end

local function user_set_timeout(ti, f)
    local function t()
        if f then 
            f()
        end
    end
    skynet.timeout(ti, t)
    return function() f=nil end
end

local function autoT()
    local retobj    = {}
    retobj.code     = PDEFINE.RET.SUCCESS
    retobj.c        = PDEFINE.NOTIFY.NOTIFY_KICK
    retobj.uid      = deskInfo.user.uid
    broadcastDesk(cjson.encode(retobj))
    CMD.resetDesk()
end

local function exitGFunc(uid)
    -- 玩家主动退出游戏，保存游戏中需要的数据，需要把欠款都
    
    local user  = deskInfo.user
    if user then --旁观者退出直接退掉
        if usersAutoFuc then
            usersAutoFuc()
        end
        baseTool.statistics(deskInfo, {2})
        CMD.resetDesk()
        return PDEFINE.RET.SUCCESS
    end
end

--玩家定时器
function CMD.userSetAutoState(type,autoTime)
    if usersAutoFuc then
        usersAutoFuc()
    end
    if type == "autoT" then
        usersAutoFuc = user_set_timeout(autoTime, autoT)
    elseif type == "exitG" then
        usersAutoFuc = user_set_timeout(autoTime, exitGFunc)
    end
end

-- 退出房间
function CMD.exitG(source,msg)
    local gameid  = deskInfo.gameid
    if nil ~= gameid then
        do_redis({"hincrby", PDEFINE.REDISKEY.GAME.exitgame, 'gameid:'..gameid, 1})
    end
    if usersAutoFuc then
        usersAutoFuc()
    end
    local recvobj = msg
    local uid     = math.floor(recvobj.uid)
    exitGFunc(uid)
    return PDEFINE.RET.SUCCESS
end

-- 时间到自动解散
local function autoDelte()
    -- if delteDesk then
    -- 	all_over("DELTE_ALL_GAME")
    -- end
end

local function set_timeout(ti, f)
      local function t()
        if f then 
          f()
        end
      end
     skynet.timeout(ti, t)
     return function() f=nil end
end

function CMD.setAutoState(autoTime)
    if autoFuc then 
        autoFuc() 
    end
    autoFuc = set_timeout(autoTime,autoDelte)
end

function CMD.exit()
    collectgarbage("collect")
    skynet.exit()
end

--用户在线离线
function CMD.offline(source,offline,uid)
    -- local user = deskInfo.user
    -- if user then
    -- 	local retobj = {}
    -- 	retobj.c = PDEFINE.NOTIFY.NOTIFY_ONLINE
    -- 	retobj.code = PDEFINE.RET.SUCCESS
    -- 	retobj.offline = offline
    -- 	--broadcastDesk(cjson.encode(retobj))
    -- end
end

local function calcBetRange(deskInfo)
    local size = 6
    for i, bet in ipairs(deskInfo.mults) do
        if bet <= deskInfo.maxbet then
            size = math.max(size, i)
        end
    end
    return {1, size}
end

local function getSimpleDeskData(deskInfo, uid)
    if deskInfo.freeGameData then
        if deskInfo.freeGameData.restFreeCount >= 0 and deskInfo.freeGameData.allFreeCount > 0 then
            deskInfo.state = confDefine.GAME_STATE["FREE"]
        end
    else
        deskInfo.freeGameData = {
            freeWinCoin = 0,	-- 免费赢得的金币
            allFreeCount = 0, 	-- 总次数
            restFreeCount = 0,   -- 剩余次数
            addMult = 1, 		-- 免费游戏的倍数
            triFreeData = {freeInfo = {}, triFreeCnt = 0},
        }
    end
    local simpleDeskData =  {
        basecoin = deskInfo.basecoin,
        deskid = deskInfo.deskid,
        uuid  = deskInfo.uuid,
        gameid = deskInfo.gameid,
        mults = deskInfo.mults,
        line = deskInfo.line,
        currmult = deskInfo.currmult,
        curround  = deskInfo.curround,
        singleBet = deskInfo.singleBet,
        totalBet = deskInfo.totalBet,
        subGame = {subGameId = -1, isMustJoin = -1},
        state = deskInfo.state,
        needbet = deskInfo.needbet,
        -- 免费游戏相关数据
        freeWinCoin = deskInfo.freeGameData.freeWinCoin + (deskInfo.freeGameData.bigGameWinCoin or 0),
        allFreeCount = deskInfo.freeGameData.allFreeCount,
        restFreeCount = deskInfo.freeGameData.restFreeCount,
        addMult = deskInfo.freeGameData.addMult or 0,
        freeBanceInfo = deskInfo.freeGameData.freeBanceInfo,
        freeResult = deskInfo.freeGameData.triFreeData,
        mysteryCard = deskInfo.freeGameData.mysteryCard,
        specialData = deskInfo.specialData,
        user = table.copy(deskInfo.user),
        modeType = deskInfo.modeType,
        betRange = calcBetRange(deskInfo),
        leagueexp = 0,--player_tool.getPlayerLeagueScore(uid, deskInfo.gameid),
    }
    simpleDeskData.user.cluster_info = nil
    if gameCfg.addSpecicalDeskInfo then
        local tmp_deskInfo = table.copy(simpleDeskData)
        simpleDeskData = gameCfg.addSpecicalDeskInfo(deskInfo, tmp_deskInfo)
    end

    return simpleDeskData
end

-- 用户离线获取牌桌信息
function CMD.getDeskInfo(source, msg)
    local recvobj = msg
    local uid = math.floor(recvobj.uid)

    if not deskInfo.gameid then
        return
    end

    if deskInfo.state ~= 0 and deskInfo.user.gameBonus == 0 then
        if deskInfo.user.gameType == 2 then
            deskInfo.user.gameType = 0
        end
    end
    deskInfo.subGame = {subGameId = -1, isMustJoin = -1}
    local simpleDeskData = getSimpleDeskData(deskInfo, uid)

    if gameCfg.getDeskInfo then
        local tmp_deskInfo = table.copy(deskInfo)
        return gameCfg.getDeskInfo(tmp_deskInfo, recvobj)
    elseif gameCfg.addSpecicalDeskInfo then
        local tmp_deskInfo = table.copy(simpleDeskData)
        return gameCfg.addSpecicalDeskInfo(deskInfo, tmp_deskInfo, recvobj)
    end

    return simpleDeskData
end

--更新玩家的桌子信息
function CMD.updateUserClusterInfo(source, uid, agent)
    LOG_DEBUG("[拉霸]玩家", uid, " agent:", agent, "gameid:",deskInfo.gameid)
    if nil ~= deskInfo.user and deskInfo.user.cluster_info then
        deskInfo.user.cluster_info.address = agent
    end
end

--后台API 停服清房
function CMD.apiCloseServer(source,csflag)
    closeServer = csflag
    if deskInfo.state == 0 and closeServer == true then
           sysCloseServer()
    end
end

function CMD.apiKickDesk( source )
    --释放该用户的桌子对象
    sysKickUser()
end


-- 计算 totalBet 和 signlBet
local function calTotalBet(c_bet_grade, deskInfo)
    local totalBet  = deskInfo.mults[c_bet_grade] --总押注为当前档位直接选中的那个
    local singleBet = totalBet / 10000 --paytable里10000相当于1倍
    deskInfo.totalBet = totalBet
    deskInfo.singleBet = singleBet

    if c_bet_grade == #deskInfo.mults then
        deskInfo.isbetfull = PDEFINE.BET_TYPE.FULL --押满
    end
end

-- 线是不可调节的
local function getBetInfo(deskInfo)
    if deskInfo.state ~= confDefine.GAME_STATE.NORMAL then
        return {spcode = 200}
    end
    local c_bet_grade = 3 --默认选择的押注额档位
    local mults = def.BET_COIN

    local total_mults = {} --直接显示总押注额
    for _, v in ipairs(mults) do
        table.insert(total_mults, v)
    end

    if nil == deskInfo.currmult then
        deskInfo.currmult = c_bet_grade
    end
    if deskInfo.currmult <= 1 then
        deskInfo.currmult = 1
    end
    if deskInfo.currmult > #mults then
        deskInfo.currmult = #mults
    end

    deskInfo.mults = total_mults
    deskInfo.needbet = math.min(6, math.floor(#total_mults/2))
    calTotalBet(deskInfo.currmult, deskInfo)
    deskInfo.defaultBetGrade = total_mults[deskInfo.currmult]
end


local function getOptimum_init_Mult_Line(deskInfo, gameCfg)
    if gameCfg.getLine then
        deskInfo.line = gameCfg.getLine(deskInfo)
    else
        deskInfo.line = gameCfg.line or gameCfg.gameConf.line
    end
end

local function getRedisDeskInfo(deskInfo)
    --从redis中拿出缓存的数据
    if deskInfo.gameid >= 419 then
        local redis_records = gameRecord.gameData.get(deskInfo)
        if redis_records then
            for k, v in pairs(redis_records)do
                -- print("k:", k, ", v:", v)
                if deskInfo[k] == nil or k == "freeGameData" then
                    deskInfo[k] = v
                end
            end
        end
    end
end

---生成投注期号
local issue_no = 0
local function newIssue()
    local shortname = PDEFINE.GAME_SHORT_NAME[deskInfo.gameid] or 'XX'
    local osdate = os.date("%y%m%d")
    issue_no = issue_no + 1
    local number = string.format("%04d", issue_no%10000)
    deskInfo.issue = shortname..osdate..(deskInfo.deskid)..number
end

-- 游戏业务逻辑协议
-- 创建桌子
function CMD.create(source, cluster_info, msg, ip, deskid)
    local recvobj = msg
    local uid = math.floor(recvobj.uid)
    local gameid = math.floor(recvobj.gameid)
    local gameTask = recvobj.gameTask
    local ssid = 0
    local reqbetidx = recvobj.betidx

    gameCfg =  table.copy(require ("cashslots.slots.slot_"..gameid))
    LOG_INFO("加载游戏文件--------> cashslots.slots.slot_"..gameid)
    LOG_INFO("yrp -------------- text")
    --计算够不够进房间门槛
    local playerInfo = player_tool.getPlayerInfo(uid)
     if not playerInfo then
        return PDEFINE.RET.ERROR.SEATID_EXIST
    end
    local now = os.time()
    deskInfo.deskid = deskid
    deskInfo.uuid   = deskid .. now
    deskInfo.leftcoin = 1
    deskInfo.isbetfull = PDEFINE.BET_TYPE.NOTFULL --初始为 未押满, 只考虑金额
    deskInfo.reqbetidx = reqbetidx

    deskInfo.maxbet = 5000
    local ok, maxbet = pcall(cluster.call, "master", ".configmgr", 'getSlotsMaxBet', playerInfo.svip or 0)
    if ok and maxbet then
        deskInfo.maxbet = maxbet
    end

    local userInfo = {}
    userInfo.uid = uid
    userInfo.playername = playerInfo.playername
    userInfo.sex = playerInfo.sex
    userInfo.usericon = playerInfo.usericon
    userInfo.memo = playerInfo.memo
    userInfo.coin = playerInfo.coin
    userInfo.cluster_info = cluster_info
    userInfo.level = playerInfo.level or 1
    userInfo.svip =  playerInfo.svip or 0
    userInfo.istest = playerInfo.istest
    deskInfo.user = userInfo

    deskInfo.basecoin = 1
    deskInfo.gameid = gameid
    deskInfo.curround = 1
    getOptimum_init_Mult_Line(deskInfo, gameCfg)

    deskInfo.subGame = {subGameId = -1, isMustJoin = -1}
    getRedisDeskInfo(deskInfo)
    getBetInfo(deskInfo)
    deskInfo.maxMult = 20  -- 可能会有的最大压注档位，用于子游戏初始化压注相关的数据
    deskInfo.currMaxMult = #deskInfo.mults  -- 当前最大值
    deskInfo.ssid = ssid

    deskInfo.tbet = deskInfo.tbet or 0
    deskInfo.bettime = deskInfo.bettime or now
    gameCfg.create(deskInfo, uid)

    local sql = string.format("insert into d_desk(uuid,deskid,gameid,sessionid,owner,typeid,status,seat,curseat,maxround,waittime,stuffy,joinmiddle,rubcard,opengps,betbase,mincoin,leftcoin,round_num_no_pk,pot_current,bet_call_current,curround,watchnum,create_time) values('%s','%s',%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d)", deskInfo.uuid, deskid, deskInfo.gameid, 0, uid, 0, 1, 0, 0, 1000, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, os.time())
    skynet.send(".mysqlpool", "lua", "execute", sql)

    local simpleDeskData = getSimpleDeskData(deskInfo, uid)
    if gameTask then
        simpleDeskData.gameTask = gameTask
    end
    CMD.userSetAutoState("autoT",timeout[1]*100)

    baseTool.statistics(deskInfo,{1})

    strategy = Strategy.new()
    local tagid = playerInfo.tagid or 0
    strategy:init(deskInfo, {uid=uid, svip=userInfo.svip, tagid=tagid})

    return PDEFINE.RET.SUCCESS, simpleDeskData
end

local function erroe_ret(recvobj, spcode)
    local retobj = {}
    retobj.c = math.floor(recvobj.c)
    retobj.code = PDEFINE.RET.SUCCESS
    retobj.resultCards = {}
    retobj.spLuXian = 0
    retobj.zjLuXian = {}
    retobj.spcode = spcode
    retobj.wincion = 0
    retobj.coin = deskInfo.user.coin
    return retobj
end

local function getLeagueInfo()
    local info = player_tool.getLeagueInfo(PDEFINE.BAL_ROOM_TYPE.MATCH, deskInfo.user.uid)
    --超时时间
    info.nextTime = 0
    if info.stopTime then
        info.nextTime = info.stopTime + os.time()
    end
    return info
end

local function addLeagueScore(winCoin)
    local score = math.floor(winCoin * WINCOIN_LEAGUESCORE_PROPORTION)
    if score <= 0 then return end
    local cluster_info = deskInfo.user.cluster_info
    if not cluster then return end
    local now = os.time()
    if not player_tool.isLeagueTime(now) then return end

    --如果超时，再重新获取一次
    if not leagueInfo or now > leagueInfo.nextTime then
        leagueInfo = getLeagueInfo()
    end

    if leagueInfo.isSign == 1 then
        pcall(cluster.send, cluster_info.server, cluster_info.address, "clusterModuleCall", "upgrade", "bet", deskInfo.gameid, score, 'league')
    end
end

--开始游戏
function CMD.start(source, msg)
    local recvobj = msg
    local uid = math.floor(recvobj.uid)
    local spcode = 200
    if usersAutoFuc then
        usersAutoFuc()
    end

    if table.empty(deskInfo.user) then
        local retobj = erroe_ret(recvobj, PDEFINE.RET.ERROR.BAD_REQUEST)
        return PDEFINE.RET.SUCCESS, retobj
    end
    
    local betIndex = math.floor(recvobj.betIndex)
    if betIndex > #deskInfo.mults then
        local retobj = erroe_ret(recvobj, PDEFINE.RET.ERROR.SURPASS_MAX_MULT)
        return PDEFINE.RET.SUCCESS, retobj
    end
    local allin = 0 --recvobj.allin
    -- 是否是自动spin
    -- {all=总次数, rmd=剩余次数}
    if recvobj.bAuto then
        deskInfo.bAuto = cjson.decode(recvobj.bAuto)
    else
        deskInfo.bAuto = nil
    end

    local now = os.time()
    local playerInfo = player_tool.getPlayerInfo(uid)
    deskInfo.user.coin = playerInfo.coin
    deskInfo.user.level = playerInfo.level

    local startDeskState = deskInfo.state
    local startCoin = deskInfo.user.coin

    if deskInfo.state == confDefine.GAME_STATE.NORMAL then
        calTotalBet(betIndex, deskInfo)
        if allin == 1 then  --全押
            deskInfo.totalBet = playerInfo.coin
            deskInfo.singleBet = deskInfo.totalBet / 10000
            for i, mult in ipairs(deskInfo.mults) do
                if deskInfo.totalBet >= mult then  --全押时，如果下注额大于某个挡位数值且不超过下一挡位数值，则认为他在这一挡位下注，控制和发放参考此挡位
                    betIndex = i
                end
            end
        end
        deskInfo.currmult = betIndex
    else
        betIndex = deskInfo.currmult        -- 免费游戏和其他状态不能更改下注额
    end

    if deskInfo.state == confDefine.GAME_STATE.NORMAL then
        if deskInfo.totalBet < deskInfo.mults[1] then   --金币低于最小押注
            spcode = PDEFINE.RET.ERROR.BET_COIN_NOT_ENOUGH
        end
        if deskInfo.totalBet > deskInfo.user.coin then  --超过自身已有金币
            spcode = PDEFINE.RET.ERROR.SURPASS_MAX_SCORE
        end
    end
    if spcode ~= 200 then
        local retobj = erroe_ret(recvobj, spcode)
        return PDEFINE.RET.SUCCESS, retobj
    end

    --生成序列号
    newIssue()

    --根据数值要求，把单线押注额修改
    local userInfo = {
        uid = uid,
        level = playerInfo.level,
        coin = playerInfo.coin,
        betIndex = betIndex,
        betCoin = deskInfo.totalBet,
        svip = playerInfo.svip or 0,
        tagid = playerInfo.tagid or 0,
    }
    local isInBaseGame = deskInfo.state == confDefine.GAME_STATE["NORMAL"]
    -- 特殊处理一些老款游戏，bonus respin 走的是44协议，但是不能算是正常spin
    if isInBaseGame then
        if deskInfo.gameid == 419 or deskInfo.gameid == 621 then
            if deskInfo.bonusGame then
                isInBaseGame = false
            end
        elseif deskInfo.gameid == 420 or deskInfo.gameid == 611 then
            --火神的小游戏,firegame不能算经验值
            if deskInfo.fireGame and deskInfo.fireGame.state == 1 then
                isInBaseGame = false
            end
        elseif deskInfo.gameid == 476 or deskInfo.gameid == 605 then
            if deskInfo.bonusGame and deskInfo.bonusGame.state then
                isInBaseGame = false
            end
        end
    end
    deskInfo.control = strategy:get(deskInfo, userInfo)
    deskInfo.strategy = strategy
    strategy:onSpinStart(deskInfo, userInfo)

    local retobj = gameCfg.start(deskInfo, recvobj)
    userInfo.coin = deskInfo.user.coin
    strategy:onSpinEnd(deskInfo, userInfo)
    --游戏内部非法请求44
    if retobj.spcode and retobj.spcode ~= PDEFINE.RET.SUCCESS then
        local retobj = erroe_ret(recvobj, retobj.spcode)
        return PDEFINE.RET.SUCCESS, retobj
    end
    retobj.gameid = deskInfo.gameid
    retobj.loanCoinSuccess = nil
    retobj.spEffect = baseFunc.getBigWinHugeWin(deskInfo, retobj.wincoin)
    if retobj.spEffect.kind > 0 then
        strategy:onBigwin(deskInfo)
    end

    if isInBaseGame then
        local cluster_info = deskInfo.user.cluster_info
        if cluster_info then
            -- if math.random() < ADD_RP_PROBABILITY then
            --     local rp = ADD_RP_VALUE[betIndex]
            --     if rp and rp > 0 then
            --         local addrp = math.random(math.floor(rp*0.8), math.floor(rp*1.2))
            --         if addrp > 0 then
            --             retobj.rp = {
            --                 add = addrp,
            --                 cur = (playerInfo.rp or 0)+addrp
            --             }
            --             pcall(cluster.send, cluster_info.server, cluster_info.address, "addRp", addrp)
            --         end
            --     end
            -- end

            -- if math.random() < BET_MB_PROBABILITY then
            --     local addmb = math.floor(deskInfo.totalBet * BET_MB_PROPORTION)
            --     if addmb > 0 then
            --         local update_data = {
            --             addbag = addmb,
            --         }
            --         pcall(cluster.send, cluster_info.server, cluster_info.address, "clusterModuleCall", "player", "setPersonalExp", uid, update_data)
            --     end
            -- end
            -- 更新主线任务
            -- local updateMainObjs = {
            --     -- 游戏次数
            --     {kind=PDEFINE.MAIN_TASK.KIND.SlotsGame, count=1},
            -- }
            -- pcall(cluster.send, cluster_info.server, cluster_info.address, "clusterModuleCall", "maintask", "updateTask", uid, updateMainObjs)
        end
    end

    local winCoin = deskInfo.user.coin - startCoin
    -- 计算金币差额需要加上下注额
    if not isFreeState(deskInfo) then
        winCoin = winCoin + deskInfo.totalBet
    end
    -- 是否是免费最后一把
    local isEndFree = false
    if startDeskState == confDefine.GAME_STATE.FREE and deskInfo.state == confDefine.GAME_STATE.NORMAL then
        isEndFree = true
    end
    -- wincoin为0，则说明没中线，且不是免费游戏最后一把，说明玩家身上的钱有可能是其他地方奖励的
    if winCoin < 0 or (retobj.wincoin == 0 and not isEndFree)then
        winCoin = 0
    end
    --联赛
    if winCoin > 0 then
        addLeagueScore(winCoin)
    end
    --公告
    if winCoin >= 1000 then
        local bet = retobj.avgBet or deskInfo.totalBet
        if bet and bet > 0 and winCoin/bet >= 10 then
            sysmarquee.onGameWin(deskInfo.user.playername, deskInfo.gameid, winCoin, 0)
        end
    end

    retobj.c = math.floor(recvobj.c)
    CMD.userSetAutoState("autoT",timeout[1]*100)

    retobj.issue = deskInfo.issue
    retobj.x = nil
    retobj.y = nil
    strategy:saveData(deskInfo)
    return PDEFINE.RET.SUCCESS, retobj
end

function CMD.joinSubGame(source, msg)
    local recvobj = msg
    local uid = math.floor(recvobj.uid)
    local subGameId = math.floor(recvobj.subGameId)
    local joincoin = deskInfo.user.coin
    local retobj = gameCfg.joinSubGame(deskInfo, recvobj)
    local coin = deskInfo.user.coin
    if deskInfo.subGame.subAddCoin then
        coin = coin - deskInfo.subGame.subAddCoin
    end
    retobj.coin = coin
    deskInfo.subGame.joinCoin = joincoin
    deskInfo.subGame.state = PDEFINE.SUBGAME_STATE.START
    CMD.userSetAutoState("autoT",timeout[1]*100)
    return PDEFINE.RET.SUCCESS, retobj
end

function CMD.actionSubGame(source, msg)
    if not deskInfo.subGame or deskInfo.subGame.subGameId == -1 or deskInfo.subGame.state and deskInfo.subGame.state == PDEFINE.SUBGAME_STATE.PEXIT then
        return PDEFINE.RET.SUCCESS, {spcode = 201} --未计入或者退出子游戏
    end
    local recvobj = msg
    local beforecoin = deskInfo.user.coin
    deskInfo.subGame.isAction = true
    local retobj, sendResult, noSend = gameCfg.actionSubGame(deskInfo, recvobj)
    if retobj == nil then
        LOG_ERROR("ActionSubGame Error, deskInfo.gameid:", deskInfo.gameid)
        return PDEFINE.RET.SUCCESS, cjson.encode({spcode = 201}) --未计入或者退出子游戏
    end
    local aftercoin = deskInfo.user.coin
    if not sendResult then sendResult = {bet_coin = 0, win_coin = retobj.wincoin or retobj.winCoin} end
    CMD.userSetAutoState("autoT",timeout[1]*100)
    return PDEFINE.RET.SUCCESS, retobj
end

function CMD.exitSubGame(source, msg)

    if deskInfo.subGame.subGameId == -1 then
        return PDEFINE.RET.SUCCESS, {spcode = 201} -- 已退出游戏
    end
    local recvobj = msg
    local retobj,sendResult = gameCfg.exitSubGame(deskInfo, recvobj)
    local winCoin = retobj.winCoin or retobj.wincoin

    retobj.spEffect = baseFunc.getBigWinHugeWin(deskInfo, winCoin)
    local beforecoin = deskInfo.subGame.joinCoin
    local aftercoin = deskInfo.user.coin

    if sendResult == nil then
        sendResult = {bet_coin = deskInfo.subGame.admissionCoin or 0, win_coin = deskInfo.subGame.twinCoin or 0}
    end
    deskInfo.subGame.state = PDEFINE.SUBGAME_STATE.NORMAL

    if deskInfo.subGame then
        deskInfo.subGame.subGameId = -1
        deskInfo.subGame.isMustJoin = -1
        deskInfo.subGame.state = PDEFINE.SUBGAME_STATE.NORMAL
    end
    CMD.userSetAutoState("autoT",timeout[1]*100)
    -- baseTool.updateQuest(deskInfo, retobj)
    return PDEFINE.RET.SUCCESS, retobj
end

function CMD.selectFreeParam(source, msg)
    local retobj = gameCfg.selectFreeParam(deskInfo, msg)
    return PDEFINE.RET.SUCCESS, retobj
end

function CMD.gameLogicCmd(source, msg)
    local recvobj = msg
    local retobj = {}
    retobj.c = math.floor(recvobj.c)
    retobj.uid = math.floor(recvobj.uid)
    local startDeskState = deskInfo.state
    local startCoin = deskInfo.user.coin

    deskInfo.strategy = strategy
    retobj.data = gameCfg.gameLogicCmd(deskInfo, recvobj.data)

    local winCoin = 0
    if deskInfo.user.coin > startCoin then
        winCoin = deskInfo.user.coin - startCoin
    end
    local bet = retobj.avgBet or deskInfo.totalBet
    -- 发送全服中奖信息
    if bet and bet > 0 then
        local mult = winCoin // bet
        if mult >= 10 then
            -- 如果绑定了fb, 则只要高于10倍的，都会发送跑马灯
            -- 如果没有绑定fb, 则高于20倍会给自己发送跑马灯
            -- local noty_retobj  = {}
            -- noty_retobj.c      = PDEFINE.NOTIFY.USER_HAVE_SPEFFECT
            -- noty_retobj.code   = PDEFINE.RET.SUCCESS
            -- noty_retobj.info = {
            --     uid = deskInfo.user.uid,
            --     nick = deskInfo.user.playername,
            --     icon = deskInfo.user.usericon or "",
            --     coin = winCoin,
            -- }
            -- if deskInfo.user.isbindfb == 1 then
            --     broadcastWorld(noty_retobj)
            -- elseif mult >= 20 then
            --     if deskInfo.user and deskInfo.user.cluster_info then
            --         pcall(cluster.send, deskInfo.user.cluster_info.server, deskInfo.user.cluster_info.address, "sendToClient", cjson.encode(noty_retobj))
            --     end
            -- end

            strategy:onBigwin(deskInfo)

            if winCoin >= 1000 then
                sysmarquee.onGameWin(deskInfo.user.playername, deskInfo.gameid, winCoin, 0)
            end
        end
    end
    --联赛
    if winCoin > 0 then
        addLeagueScore(winCoin)
    end

    strategy:saveData(deskInfo)
    return PDEFINE.RET.SUCCESS, retobj
end


function CMD.reload()
end

--*********************某些游戏特殊增加的接口***************
-- 水果slots设置最大的倍率
function CMD.setMaxBet(source,msg)
    local retobj = gameCfg.setMaxBet(deskInfo, msg)
    return PDEFINE.RET.SUCCESS, retobj
end
--********************************************************

--API更新桌子里玩家的金币
function CMD.addCoinInGame(source, uid, coin, diamond)
    if deskInfo.user.uid == uid then
        if coin then
            deskInfo.user.coin = deskInfo.user.coin + coin
        end
        if diamond and deskInfo.user.diamond then
            deskInfo.user.diamond = deskInfo.user.diamond + diamond
        end
    end

    LOG_DEBUG("addCoinInGame uid:", uid, "coin:", coin, "deskInfo.user.coin:", deskInfo.user.coin)
end

--获取最近一次赢得的金币
function CMD.getLastWinCoin(source, uid)
    return deskInfo.lastWinCoin or 0
end

-- 更新某个用户信息,并且广播
function CMD.updateUserInfo(uid)
    LOG_DEBUG("updateUserInfo", "uid:", uid)
    local user = deskInfo.user
    if user.uid == uid then
        local ok, playerInfo = pcall(cluster.call, user.cluster_info.server, user.cluster_info.address, "clusterModuleCall", "player", "getPlayerInfo", uid)
        if ok and playerInfo then
            user.playername = playerInfo.playername
            user.sex = playerInfo.sex
            user.usericon = playerInfo.usericon
            user.memo = playerInfo.memo
            user.coin = playerInfo.coin
            user.level = playerInfo.level or 1
            user.svip =  playerInfo.svip or 0
        end
    end
end

skynet.start(function()
    skynet.dispatch("lua", 
        function(session, source, command, ...)
            if not CMD[command] then
                print(command)
            end
            local f = assert(CMD[command])
            local param = {...}
            local ret 
            cs(
                function()
                    ret = {f(source, table.unpack(param))}
                end
            )
            skynet.retpack(table.unpack(ret))
        end
    )
    collectgarbage("collect")
end)
