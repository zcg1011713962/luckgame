local skynet  = require "skynet"
local cluster = require "cluster"
local cjson   = require "cjson"
local queue = require "skynet.queue"
local snax = require "snax"
local api_service = require "api_service"
local player_tool = require "base.player_tool"
local game_tool = require "game_tool"
local fishtrace = require "fish.fishtrace"
local fishvpool = require "fish.fishvpool"
local stgy = require "stgy"
require "fish.fishai"
require "fish.fishfeature"
require "fish.jackpotfishfeature"
require "fish.megafishfeature"

local GAME_ID = require "fish.fishgameid"

local cs = queue()
local cspool = queue()

local fishconfig = nil
local fishfeature = nil
cjson.encode_sparse_array(true)
-- 捕鱼
skynet.register_protocol {
    name = "client",
    id = skynet.PTYPE_CLIENT,
    unpack = skynet.tostring,
}

local GAME_NAME = skynet.getenv("gamename") or "game"
local APP = skynet.getenv("app") or 0
APP = tonumber(APP)

local game_id = GAME_ID.HWBY    -- 游戏ID
local game_running = false      -- 游戏是否进行中
local game_counter = 0          -- 计数器
local kick_out_time = 0         -- 计时器
local check_ai_time = 0         -- 计时器

local RESOLUTION_WIDTH = 1280       -- 设计宽度
local RESOLUTION_HEIGHT = 720       -- 设计高度

--桌子状态
local DESK_STATE = {
    NORMAL = 0,     --正常
    TIDE = 1,       --鱼潮
    BOSS = 2,       --Boss
}

-- 桌子用户信息
local deskInfo = {
    gameid = GAME_ID.HWBY,
    sceneid = 1,    -- 场景ID
    users = {},     -- 玩家列表
    state = DESK_STATE.NORMAL,      -- 0:正常 1:鱼潮 2:boss
    seat = 4,       -- 房间座位数
    curseat = 0,    -- 当前玩家数
}

local control_ratio = {1.2, 1.1, 1.0, 0.9, 0.8}   -- 控制概率系数(5套概率表) 1大赢 5大输

local game_stock = 0      -- 游戏库存

local timer_list = {}     -- 定时器列表

local fish_id = 0         -- 鱼ID
local fishes = {}         -- 鱼列表

local bullet_id = 0       -- 子弹ID
local bullets = {}        -- 子弹列表

local booms = {}          -- 炸弹列表

local ai_id = math.random(1000, 9000)   -- 机器人ID

local cur_boss = {id=0, tid=0}     -- 当前boss

local gamelog = {
    loan = 0,           -- 总借款
    revert = 0,         -- 总还款
    userbet = 0,        -- 总下注
    userwin = 0,        -- 总赢分
    useradd = 0,        -- 总加分
}

-- 接口函数组
local CMD = {}

-- 时钟间隔
local TICK_INTERVAL = 40

-- 机器人
local AI = {
    ais = {}
}

-- 游戏库存
local STOCK = {
    current = 0,      -- 当前库存
    loanid = nil,     -- 借款id
    loanamount = 0,   -- 借款数量
    loantime = 0,     -- 借款时间
}

---------------------- 定时器 ----------------------------
-- 设置重复触发定时器
local function setTimer(name, tmin, tmax, func, params)
    local function repeat_func()
        timer_list[name] = nil
        func(params)
        setTimer(name, tmin, tmax, func, params)
    end
    local ti = math.random(tmin, tmax)
    timer_list[name] = skynet.timeout(ti, repeat_func)
end

-- 清理定时器
local function clearTimer(name)
    if timer_list[name] then
        skynet.remove_timeout(timer_list[name])
        timer_list[name] = nil
    end
end

-- 清理定时器
local function clearAllTimer()
    for _, t in pairs(timer_list) do
        skynet.remove_timeout(t)
    end
    timer_list = {}
end

-- 重置桌子
local function restDeskInfo()
    if nil == deskInfo.deskid then
        return
    end

    local deskid = deskInfo.deskid
    deskInfo.deskid = nil

    fishfeature:onDeskReset()

    deskInfo.endtime = os.time()

    -- 清除定时器
    clearAllTimer()
    -- 库存还款
    STOCK.finish()
    -- 回收AI
    AI.reset()

    fishvpool.save_data(game_id)
  
    deskInfo.state = DESK_STATE.NORMAL
    deskInfo.users = {} 
    deskInfo.curseat = 0

    LOG_INFO("解散房间" , deskid, cjson.encode(gamelog))
    gamelog.loan = 0
    gamelog.revert = 0
    gamelog.userbet = 0
    gamelog.userwin = 0
    gamelog.useradd = 0

    game_running = false
    fishes = {}
    bullets = {}
    booms = {}
    skynet.call(".dsmgr", "lua", "recycleAgent", skynet.self(), deskid, deskInfo.gameid)
end

-- 桌子信息
local function getDeskBaseInfo()
    local tmp = table.copy(deskInfo)
    tmp.uuid = nil
    tmp.revenue = nil
    tmp.mincoin = nil
    tmp.virtualCoin = nil

    for _, user in pairs(tmp.users) do
        user.cluster_info = nil
        user.ip           = nil
        user.winCoin      = nil
        user.consumeCoin  = nil
        user.betCoin      = nil
        user.ctrl         = nil
        user.vipRate      = nil
        user.real         = nil
        user.tick         = nil
        user.settleTime   = nil
    end
    return tmp
end

local function sendMsg(user, retobj)
    if user and user.cluster_info then
        pcall(cluster.send, user.cluster_info.server, user.cluster_info.address, "sendToClient", retobj)
    end
end

-- 广播给房间里的所有人
local function broadcastDesk(retobj, exuid)
    for _, user in pairs(deskInfo.users) do
        if user.cluster_info and exuid~=user.uid then
            pcall(cluster.send, user.cluster_info.server, user.cluster_info.address, "sendToClient", retobj)
        end
    end
end

---生成投注期号
local function getIssue(user)
    local shortname = PDEFINE.GAME_SHORT_NAME[deskInfo.gameid] or 'XX'
    local osdate = os.date("%y%m%d")
    user.isn = user.isn + 1
    if user.isn > 10000 then user.isn = 1 end
    local number = string.format("%04d", user.isn)
    return shortname..osdate..(deskInfo.deskid)..number
end

local function getMultsFromChips(chips)
    local mults = fishconfig.getMults(game_id, deskInfo.ssid)
    return mults
end

local function userSendLog(user, winCoin, result)
    local betCoin = user.betCoin
    if winCoin <= 0 and betCoin <= 0 then return end

    user.betCoin = 0

    -- local aftercoin = beforecoin - betCoin + winCoin
    -- local gamedata = {bet=betCoin, result=result}
    -- local userdata = {    
    --     mb = 2,
    --     send_api_result_userlist = {
    --         [1]={uid=user.uid,bet_coin=betCoin,win_coin=winCoin-betCoin,winjp_coin=0,before_coin=beforecoin,after_coin=aftercoin},
    --     }
    -- }

    -- cspool(function()
    --     if betCoin > 0 then       --下注先入水池
    --         water_pool.pushPool(user, deskInfo, betCoin, deskInfo.poolround_id)
    --     end 
    --     --上报结果
    --     water_pool.sendGameLog(userdata, deskInfo, cjson.encode(gamedata), nil, nil, deskInfo.poolround_id)
    -- end)
end


-- 玩家结算
local function userSettle(user)
    -- local sql = string.format("insert into d_user_combat(uuid,deskid,round,uid,gameid,playername,usericon,cards,cardtype,betbase,addcoin,endtime,isrobot,tax,free,bet) values('%s', '%s', %d, %d, %d, '%s', '%s', '%s', '%s', %d, %f, %d, %d, %f, %d, '%s')",
    --     deskInfo.uuid, deskInfo.deskid, 0, user.uid, deskInfo.gameid, user.playername, user.usericon, "", "", 0, user.winCoin, os.time(), 0, 0, 0, user.consumeCoin)
    -- skynet.call(".mysqlpool", "lua", "execute", sql)
    user.settleTime = skynet.now()

    local winCoin = user.winCoin
    local consumeCoin = user.consumeCoin
    local issue = getIssue(user)

    user.winCoin = 0
    user.consumeCoin = 0

    if consumeCoin > 0 or winCoin > 0 then
        cspool(function()
            local ok = true
            local code = 0
            if winCoin > 0 then
                ok,code = player_tool.calUserCoin(user.uid, winCoin, issue, PDEFINE.ALTERCOINTAG.WIN, deskInfo)
            end
            if ok then
                if consumeCoin > 0 then
                    ok,code = player_tool.calUserCoin(user.uid, -consumeCoin, issue, PDEFINE.ALTERCOINTAG.BET, deskInfo)
                    if not ok then
                        LOG_ERROR("捕鱼修改金币失败2.code:",code,"coin:",-consumeCoin)
                    end

                    -- 增加等级经验
                    --pcall(cluster.send, "master", ".vipCenter", "bet", user.uid, consumeCoin, deskInfo.gameid)
                end
            else
                LOG_ERROR("捕鱼修改金币失败1.code:",code,"coin:",winCoin,"consumeCoin:",-consumeCoin)
            end
            LOG_DEBUG("玩家结算", -consumeCoin, winCoin)
            if winCoin ~= consumeCoin then
                --pcall(cluster.call, "master", ".vipCenter", "finish", user.uid, -winCoin + consumeCoin, winCoin)
            end
            gamelog.useradd = gamelog.useradd + winCoin - consumeCoin
        end)
    end
end

-- 玩家加金币
local function userWinCoin(user, coin)
    if coin <= 0 then return end
    user.coin = user.coin + coin
    user.winCoin = user.winCoin + coin
    if user.real and skynet.now() > user.settleTime + 10*100 then  -- 每10秒结算一次
        userSettle(user)
    end
end

local function userConsumeCoin(user, coin)
    if coin <= 0 then return end
    user.coin = user.coin - coin
    user.consumeCoin = user.consumeCoin + coin
    if user.real and skynet.now() > user.settleTime + 10*100 then  -- 每10秒结算一次
        userSettle(user)
    end
end

local function loadAiInfo()
    --local ok, playerInfo = pcall(cluster.call, "ai", ".aiuser", "getAiInfo", deskInfo.ssid, coin, deskInfo.gameid)
    ai_id = ai_id + math.random(1, 5)
    if ai_id >= 10000 then ai_id = ai_id - 10000 + 1000 end

    local basecoin =  math.max(deskInfo.mincoin, 1000)  --准入门槛
    local maxcoin = 10 * basecoin                       --允许携带的最大金币
    local coin = math.random(basecoin, maxcoin)         --携带金币

    local userInfo      = {}
    userInfo.uid        = ai_id  --playerInfo.uid
    userInfo.playername = string.format("%08d", ai_id)  --playerInfo.playername
    userInfo.usericon   = string.format("img_%03d.jpg", math.random(1, 400))  --playerInfo.usericon
    userInfo.coin       = coin
    userInfo.seat       = 0
    userInfo.winCoin    = 0     --用于结算
    userInfo.consumeCoin= 0     --用于结算
    userInfo.betCoin    = 0     --用于水池
    userInfo.ctrl       = 3     --玩家控制
    userInfo.vipRate    = 1
    userInfo.real       = false
    userInfo.sex        = math.random(1, 2)
    userInfo.ip         = ""
    userInfo.memo       = ""
    userInfo.offline    = 0 --是否掉线 1是 0否
    userInfo.tick       = skynet.now()
    userInfo.settleTime = skynet.now()
    userInfo.isn        = 0

    return userInfo

end

local function loadUserInfo(cluster_info, uid)
    local playerInfo
    if cluster_info then
        playerInfo = cluster.call(cluster_info.server, cluster_info.address, "clusterModuleCall", "player", "getPlayerInfo", uid) --去node服找对应的player
    else
        playerInfo = player_tool.getPlayerInfo(uid)
    end
    if not playerInfo then
        LOG_ERROR("getPlayerInfo fail", uid)
        return
    end

    local userInfo      = {}
    userInfo.uid        = uid
    userInfo.playername = playerInfo.playername
    userInfo.usericon   = playerInfo.usericon
    userInfo.coin       = playerInfo.coin
    userInfo.svip       = playerInfo.svip
    userInfo.seat       = 0
    userInfo.winCoin    = 0
    userInfo.consumeCoin= 0
    userInfo.betCoin    = 0
    userInfo.ctrl       = 3
    userInfo.vipRate    = 1
    userInfo.real       = true
    userInfo.sex        = playerInfo.sex
    userInfo.cluster_info= cluster_info
    userInfo.memo       = playerInfo.memo or ""--备注描述
    userInfo.offline    = 0
    userInfo.tick       = skynet.now()
    userInfo.settleTime = skynet.now()
    userInfo.isn        = 0

    return userInfo
end

-- 玩家进入桌子
local function userEnterDesk(user, notify)
    table.insert(deskInfo.users, user)
    fishfeature:onUserEnter(deskInfo, user)
    deskInfo.curseat = deskInfo.curseat + 1
    pcall(cluster.call, "master", ".mgrdesk", "changMatchCurUsers", GAME_NAME, deskInfo.gameid, deskInfo.deskid, 1)

    if notify then
        local retobj  = {}
        retobj.c      = PDEFINE.NOTIFY.join
        retobj.code   = PDEFINE.RET.SUCCESS
        retobj.gameid = deskInfo.gameid
        retobj.ssid   = deskInfo.ssid
        retobj.deskid = deskInfo.deskid
        
        retobj.user = table.copy(user)
        retobj.user.cluster_info = nil
        retobj.user.ip           = nil
        retobj.user.winCoin      = nil
        retobj.user.consumeCoin  = nil
        retobj.user.betCoin      = nil
        retobj.user.ctrl         = nil
        retobj.user.vipRate      = nil
        retobj.user.real         = nil
        retobj.user.tick         = nil
        retobj.user.settleTime   = nil

        broadcastDesk(cjson.encode(retobj))
    end
end

-- 玩家离开桌子
local function userLeaveDesk(user, notify)
    fishfeature:onUserLeave(deskInfo, user)
    for i, muser in pairs(deskInfo.users) do
        if muser.uid == user.uid then
            table.remove(deskInfo.users, i)
            deskInfo.curseat = deskInfo.curseat - 1
            break
        end
    end
    pcall(cluster.send, "master", ".mgrdesk", "changMatchCurUsers", GAME_NAME, deskInfo.gameid, deskInfo.deskid, -1)
    if notify then
        local retobj = {c = PDEFINE.NOTIFY.exit,code = PDEFINE.RET.SUCCESS, uid = user.uid, seat = user.seat, gameid = deskInfo.gameid}
        broadcastDesk(cjson.encode(retobj))
    end
end

-- 查找用户信息
local function selectUserInfo(value, tag)
    if tag == "uid" then
        for _, user in pairs(deskInfo.users) do
            if user.uid == value then
                return user
            end
        end
    elseif tag == "seat" then
        for _, user in pairs(deskInfo.users) do
            if user.seat == value then
                return user
            end
        end
    end
    return nil
end

-------- 给玩家挑选空位置 --------
local function selectEmptySeat()
    for i=1, deskInfo.seat do
        local user = selectUserInfo(i, "seat")
        if nil == user then
            return i
        end
    end
    return 0
end

------------------------- 概率控制 -------------------------
local function getUserRateCtrlIndex(uid)
    return 3
end

------------------------- 库存控制 -------------------------

function STOCK.start(num)
    STOCK.initamount = num or 5000
    STOCK.current = STOCK.initamount
    LOG_INFO("stock start", STOCK.initamount)
end

function STOCK.finish( ... )
    LOG_INFO("stock finish", STOCK.current, STOCK.current-STOCK.initamount)
end

-- 库存扣款
function STOCK.deduct(amount)
    if STOCK.current >= amount then
        STOCK.current = STOCK.current - amount              -- 花费
        return true
    end
    return false
end

-- 确保库存足够(用于判断特殊玩法的触发条件)
function STOCK.ensure(amount)
    return (STOCK.current >= amount)
end


-------------------------- 机器人  ----------------------------
-- 增加机器人
function AI.increase()
    local newSeatId = selectEmptySeat()
    if newSeatId == 0 then
        return
    end

    local userInfo = loadAiInfo()
    if userInfo then
        userInfo.seat = newSeatId --坐下
        userEnterDesk(userInfo, true)
        LOG_DEBUG("AI坐下 ", "deskInfo.curseat:", deskInfo.curseat)

        local ai = FishAi.new()
        local aiInfo = fishconfig.getAiInfo(game_id, deskInfo.ssid)
        ai:init(deskInfo, userInfo, aiInfo, CMD._fire)

        table.insert(AI.ais, ai)
    end
end
-- 减少机器人
function AI.decrease()
    if #AI.ais == 0 then return end
    local ai = table.remove(AI.ais, 1)
    local userInfo = ai.userInfo
    userLeaveDesk(userInfo, true)
    -- pcall(cluster.call, "ai", ".aiuser", "recycleAi", userInfo.uid, userInfo.coin, 0, deskInfo.deskid)

    if deskInfo.curseat == 0 and #deskInfo.users == 0 then
        restDeskInfo()
    end
end

function AI.update(dt)
    for _, ai in ipairs(AI.ais) do
        ai:update(dt)
    end
end

function AI.check()
    local userCnt = 0
    local realUserCnt = 0
    for _, user in pairs(deskInfo.users) do
        if user.real then
            realUserCnt = realUserCnt + 1
        end
        userCnt = userCnt + 1
    end
    if realUserCnt <= 0 then
        AI.decrease()
    else
        if userCnt < 3 then
            AI.increase()
        elseif userCnt >= 4 then
            AI.decrease()
        end
    end
end

function AI.reset()
    -- for _, ai in ipairs(AI.ais) do
    --     pcall(cluster.call, "ai", ".aiuser", "recycleAi", ai.userInfo.uid, ai.userInfo.coin, 0, deskInfo.deskid)
    -- end
    AI.ais = {}
end

function AI.isAi(uid)
    for _, ai in ipairs(AI.ais) do
        if ai.userInfo.uid == uid then
            return true
        end
    end
    return false
end

-- 提出玩家
local function kickUser(uid, reason)
    local user = selectUserInfo(uid, "uid")
    if user then
        user.exiting = true
        --结算
        userSettle(user)
        --记录
        userSendLog(user, 0, {fish={}, blt=0})

        if user.cluster_info then
            local retobj = {c = reason, code = PDEFINE.RET.SUCCESS, uid = user.uid}
            sendMsg(user, cjson.encode(retobj))
            pcall(cluster.send, user.cluster_info.server, user.cluster_info.address, "deskBack", deskInfo.gameid)
        end

        userLeaveDesk(user, true)
    end
end

--长时间无操作 自动T人
local function autoDeskT()
    local tick = skynet.now()
    local waittime = 120*100
    for _, user in pairs(deskInfo.users) do
        if (user.cluster_info and tick > user.tick + waittime) then
            kickUser(user.uid, PDEFINE.NOTIFY.NOTIFY_KICK)
            LOG_DEBUG("自动T掉:", user.uid)
            break
        end
    end
end

local function gameUpdate()
    fishfeature:onUpdate(deskInfo)  -- 特定玩法时钟驱动

    kick_out_time = kick_out_time + 1
    if kick_out_time >= 3 then
        kick_out_time = 0
        autoDeskT()         -- 每隔6秒检查无操作玩家
    end
    check_ai_time = check_ai_time + 1
    if check_ai_time >= 5 then
        check_ai_time = 0
        AI.check()          -- 每隔10秒检查AI进出
    end
end

local function newFishId()
    fish_id = fish_id + 1
    if fish_id >= 100000 then
        fish_id = 1
    end
    return fish_id
end

local function buildFishTrace(fish_count, fish_type_list)
    local tick = skynet.now()
    game_counter = game_counter + 1
    math.randomseed(tick+fish_count*997+game_counter)
    local fishid = 0
    local retobj = {}
    retobj.code = PDEFINE.RET.SUCCESS
    retobj.c = PDEFINE.NOTIFY.NOTIFY_FISH_ADD_FISH
    retobj.fishes = {}

    local type_count = #fish_type_list
    for i = 1, fish_count do
        fishid = newFishId()
        local fishInfo = {}
        fishInfo.ft = fish_type_list[math.random(1, type_count)]
        fishInfo.id = fishid
        fishInfo.tick = skynet.now()
        local cfg = fishconfig.fish[fishInfo.ft]
        fishInfo.ratio = cfg.ratio * 100 / math.random(95, 105)
        if #(cfg.multiple) == 1 then
            fishInfo.multiple = cfg.multiple[1]
        else
            fishInfo.multiple = math.random(cfg.multiple[1], cfg.multiple[2])
        end
        fishInfo.boom = cfg.boom
        if cfg.boom == 3 or cfg.boom == 4 then   --同类炸弹/随机炸弹
            fishInfo.rt = math.random(1,8)  --关联的鱼
        end
        fishes[fishid] = fishInfo

        local fish = {}
        fish.fid = fishInfo.id
        fish.ft = fishInfo.ft
        fish.rt = fishInfo.rt

        if GAME_ID.isHWBY(game_id) and fish.ft == 23 then  -- static
            fish.tt = 0         -- 章鱼boss
            fish.trace = fishtrace.buildPosition(0, 0)
        elseif GAME_ID.isHWBY(game_id) and fish.ft == 21 then  -- cardinal spline
            fish.tt = 3         -- 狂鳌
            fish.trace = fishtrace.buildCardinalSpline(i)
        elseif GAME_ID.isHWBY(game_id) and (fish.ft>=25 and fish.ft<=27) then  -- multi linear
            fish.tt = 5
            fish.trace = fishtrace.buildMultiLine(RESOLUTION_WIDTH, RESOLUTION_HEIGHT, cfg.w, cfg.h)
        elseif GAME_ID.isHWBY(game_id) and fish.ft == 24 then  -- 海王鳄鱼
            fish.tt = 1
            fish.trace = fishtrace.buildUpDownLine(RESOLUTION_WIDTH, RESOLUTION_HEIGHT, cfg.w, cfg.h)
        elseif GAME_ID.isHWBY(game_id) and fish.ft == 20 then  -- 海王火龙
            fish.tt = 1
            fish.trace = fishtrace.buildAxisLine(RESOLUTION_WIDTH, RESOLUTION_WIDTH, cfg.w, cfg.h)
        elseif GAME_ID.isHWBY(game_id) and fish.ft == 22 then  -- 海王魔兽
            fish.tt = 1
            fish.trace = fishtrace.buildUpDownLeftRightLine(RESOLUTION_WIDTH, RESOLUTION_HEIGHT, cfg.w, cfg.h)
        else
            local linearPercent = 8
            if cfg.group then linearPercent = 24 end
            if fish.ft < 12 and math.random(1, 100) < linearPercent then
                fish.tt = 1     -- linear
                fish.trace = fishtrace.buildRandomLine(RESOLUTION_WIDTH, RESOLUTION_HEIGHT, cfg.w, cfg.h)
            else
                fish.tt = 2     -- bezier
                fish.trace = fishtrace.buildRandomBezier(RESOLUTION_WIDTH, RESOLUTION_HEIGHT, cfg.w, cfg.h)
            end
        end

        table.insert(retobj.fishes, fish)

        --鱼群
        if cfg.group then
            local r = math.random(1, 100)
            if r <= cfg.group.chance and (fish.tt == 1 or fish.tt == 2) then
                local cnt = math.random(cfg.group.count-2, cfg.group.count-1)
                for k = 1, cnt do
                    -- 复制第一条鱼的fishInfo
                    local fishInfoCopy = table.copy(fishInfo)
                    fishInfoCopy.id = newFishId()
                    fishes[fishInfoCopy.id] = fishInfoCopy
                    -- 复制第一条鱼的fish
                    local fishCopy = table.copy(fish)
                    fishCopy.fid = fishInfoCopy.id
                    fishCopy.gid = k
                    table.insert(retobj.fishes, fishCopy)
                end
            end
        end
    end

    broadcastDesk(cjson.encode(retobj))

    return fishid
end

-- 创建
local function buildFishTraceList(fishes)
    for i, v in ipairs(fishes) do
        if v.count > 0 then
            buildFishTrace(v.count, v.ids)
        end
    end
end

-- 创建小型鱼
local function buildSmallFishTrace()
    if deskInfo.state ~= DESK_STATE.TIDE then
        buildFishTraceList(fishconfig.getSmallFishes(game_id))
    end
end

-- 创建中型鱼
local function buildMediumFishTrace()
    if deskInfo.state ~= DESK_STATE.TIDE then
        buildFishTraceList(fishconfig.getMediumFishes(game_id))
    end
end

-- 创建次大型鱼
local function buildSubBigFishTrace()
    if deskInfo.state ~= DESK_STATE.TIDE then
        buildFishTraceList(fishconfig.getSubBigFishes(game_id, deskInfo.state))
    end
end

-- 创建大型鱼
local function buildBigFishTrace()
    if deskInfo.state ~= DESK_STATE.TIDE then
        buildFishTraceList(fishconfig.getBigFishes(game_id, deskInfo.state))
    end
end

-- 创建魔法鱼
local function buildMagicFishTrace()
    buildFishTraceList(fishconfig.getMagicFishes(game_id))
end

-- 创建阵法鱼
local function buildArrayFishTrace()
    if deskInfo.state ~= DESK_STATE.TIDE then
        buildFishTraceList(fishconfig.getArrayFishes(game_id))
    end
end

-- 创建Boss鱼
local function buildBossFishTrace()
    timer_list["buildBossFishTraceTimer"] = nil

    if GAME_ID.isHWBY(game_id) then
        local bossInfo = fishconfig.getBossFishes(deskInfo.sceneid, game_id, APP)
        cur_boss.id = buildFishTrace(bossInfo[1].count, bossInfo[1].ids)
        cur_boss.tid = bossInfo[1].ids[1]
    else
        buildFishTraceList(fishconfig.getBossFishes(deskInfo.sceneid, game_id))
    end
end

-- 更新boss鱼
local function updateBossTrace()
    if deskInfo.state ~= DESK_STATE.BOSS then return end
    if cur_boss.id == 0 then return end
    if cur_boss.tid ~=22 and cur_boss.tid ~=24 then return end  --暗夜魔兽/史前巨鳄

    --销毁旧的
    fishes[cur_boss.id] = nil
    --重新创建
    cur_boss.id = buildFishTrace(1, {cur_boss.tid})
end

-- 补充boss鱼
local function replenishBossTrace()
    timer_list["replenishBossTraceTimer"] = nil

    if deskInfo.state ~= DESK_STATE.BOSS then return end
    if cur_boss.id == 0 then return end
    if cur_boss.tid ~=21 then return end  --深海狂鳌
    --重新创建
    cur_boss.id = buildFishTrace(1, {cur_boss.tid})
end

-- 创建鱼潮
local function buildFishTide()
    timer_list["buildFishTideTimer"] = nil
    deskInfo.state = DESK_STATE.TIDE
    --清空当前场景的鱼和子弹
    fishes = {}
    bullets = {}
    --booms = {}

    --构建鱼潮
    local fids = {} 
    local style, fts = fishconfig.buildfishtide(deskInfo.sceneid)
    for i, ft in ipairs(fts) do
        local fishid = newFishId()
        local fishInfo = {}
        fishInfo.ft = ft
        fishInfo.id = fishid
        fishInfo.tick = skynet.now()
        local cfg = fishconfig.fish[fishInfo.ft]
        fishInfo.ratio = cfg.ratio * 100 / math.random(95, 105)
        if #(cfg.multiple) == 1 then
            fishInfo.multiple = cfg.multiple[1]
        else
            fishInfo.multiple = math.random(cfg.multiple[1], cfg.multiple[2])
        end
        fishInfo.boom = cfg.boom
        fishes[fishid] = fishInfo

        table.insert(fids, fishid)
    end

    --广播玩家
    local retobj = {}
    retobj.code = PDEFINE.RET.SUCCESS
    retobj.c = PDEFINE.NOTIFY.NOTIFY_FISH_TIDE
    retobj.style = style
    retobj.fids = fids
    retobj.fts = fts

    broadcastDesk(cjson.encode(retobj))
end

local function broadcastDeskState()
    local retobj = {}
    retobj.code = PDEFINE.RET.SUCCESS
    retobj.c = PDEFINE.NOTIFY.NOTIFY_FISH_STATE
    retobj.state = deskInfo.state
    broadcastDesk(cjson.encode(retobj))
end

local function enterTideState()
    timer_list["enterTideStateTimer"] = nil
    deskInfo.state = DESK_STATE.TIDE
    broadcastDeskState()
    timer_list["buildFishTideTimer"] = skynet.timeout(5*100, buildFishTide)               -- 5秒后出现鱼潮
end

local function enterBossState()
    timer_list["enterBossStateTimer"] = nil
    deskInfo.state = DESK_STATE.BOSS
    broadcastDeskState()
    if GAME_ID.isHWBY(game_id) then
        buildBossFishTrace()
        setTimer("updateBossTraceTimer", 20*100, 20*100, updateBossTrace)   --定时更新boss路径
    else
        buildBossFishTrace()
        timer_list["buildBossFishTraceTimer"] = skynet.timeout(20*100, buildBossFishTrace)       -- 20秒后再刷一波
    end
end

-- 切换场景
local function switchScene(slient)
    deskInfo.sceneid = deskInfo.sceneid % fishconfig.scene_count + 1
    deskInfo.state = DESK_STATE.NORMAL

    -- 清除boss
    fishes[cur_boss.id] = nil
    cur_boss.id = 0
    clearTimer("updateBossTraceTimer")

    -- 场景事件
    timer_list["enterTideStateTimer"] = skynet.timeout(150*100, enterTideState)          -- 新场景开始150秒后进入鱼潮阶段
    timer_list["enterBossStateTimer"] = skynet.timeout(185*100, enterBossState)          -- 新场景开始185秒后出现boss      

    if not slient then
        local retobj = {}
        retobj.code = PDEFINE.RET.SUCCESS
        retobj.c = PDEFINE.NOTIFY.NOTIFY_FISH_SWITCH_SNENE
        retobj.sceneid = deskInfo.sceneid

        broadcastDesk(cjson.encode(retobj))
    end 
end

local function threadfunc(interval)
    local dt = interval/100.0
    while game_running do
        pcall(AI.update, dt)
        skynet.sleep(interval)
    end
end

--开始游戏
local function startGame()
    if nil == deskInfo.deskid then
        return
    end
    if game_running then
        return
    end

    LOG_DEBUG("开始游戏", deskInfo.deskid)
    math.randomseed(os.time())

    setTimer("buildSmallFishTraceTimer", 400, 420, buildSmallFishTrace)     -- 每隔4秒刷一次小鱼
    setTimer("buildMediumFishTraceTimer", 900, 950, buildMediumFishTrace)   -- 每隔9秒刷一次中鱼
    setTimer("buildSubBigFishTraceTimer", 1900, 2100, buildSubBigFishTrace) -- 每隔20秒刷一次次级大鱼
    setTimer("buildBigFishTraceTimer", 2800, 3200, buildBigFishTrace)        -- 每隔30秒刷一次大鱼
    if GAME_ID.isHWBY(game_id) then
        setTimer("buildMagicFishTraceTimer", 2000, 2200, buildMagicFishTrace)   -- 每隔22秒刷一次技能鱼
    else
        setTimer("buildArrayFishTraceTimer", 5400, 5800, buildArrayFishTrace)    -- 每隔56秒刷一次阵法鱼
    end
    setTimer("switchSceneTimer", 30000, 30000, switchScene)          -- 每隔5分钟切换一次场景
    setTimer("gameUpdateTimer", 200, 200, gameUpdate)               -- 每2秒

    deskInfo.sceneid = math.random(1, fishconfig.scene_count)

    game_running = true

    switchScene(true)

    skynet.fork(threadfunc, math.max(20, fishconfig.tick_interval))

    return true
end

local function tryCatchFish(fishInfo, bulletMul, rate, ctrl_ratio)
    rate = rate or 1
    ctrl_ratio = ctrl_ratio or 1
    local fishratio = fishInfo.ratio * rate
    --(gameid, fishBaseRatio, fishMult, bulletMult, ctrlRatio)
    local res = stgy.catch_fish(game_id, fishratio, fishInfo.multiple, bulletMul, ctrl_ratio)
    if res > 0 then
        return fishInfo.multiple * bulletMul
    end
    return 0
end

local function checkPool(user, score, fish_, blt_)
    stgy.vp_draw(game_id, score)
    --水池是否够赔付
    if STOCK.deduct(score) then       
        -- 发送记录
        userSendLog(user, score, {fish=fish_, blt=blt_})

        gamelog.userwin = gamelog.userwin + score

        return score
    end

    return 0
end

-- 玩家开火
function CMD._fire(recvobj, aid)
    local consume = recvobj.mul or 1
    if consume <= 0 then
        return PDEFINE.RET.ERROR.BET_NOT_ENOUGH
    end

    local user = selectUserInfo(recvobj.uid, "uid")
    if not user then
        return PDEFINE.RET.ERROR.INVAlID_ERROR
    end
    if user.exiting then
        return PDEFINE.RET.ERROR.INVAlID_ERROR
    end
    if user.coin < consume then
        return PDEFINE.RET.ERROR.BET_COIN_NOT_ENOUGH
    end
    local bulletid = recvobj.bid or 0
    bulletid = math.floor(bulletid)
    if bulletid%10 ~= user.seat then
        return PDEFINE.RET.ERROR.INVAlID_ERROR
    end
    
    --- 扣费
    user.tick = skynet.now()
    if user.freeTime then       -- 判断免费游戏
        consume = user.freeMul
    else
        userConsumeCoin(user, consume)
        user.betCoin = user.betCoin + consume
        if user.real then
            gamelog.userbet = gamelog.userbet + consume
            stgy.vp_deposit(game_id, consume)
        end
    end

    --子弹
    local bulletInfo = {}
    bulletInfo.id = bulletid
    bulletInfo.bt = recvobj.bt
    bulletInfo.mul = consume
    bulletInfo.uid = user.uid
    bullets[bulletid] = bulletInfo

    fishfeature:onUserFire(deskInfo, user, bulletInfo)

    -- 广播给其他玩家
    local retobj = {c=recvobj.c, bt=recvobj.bt, bid=bulletid, ang=recvobj.ang, mul=consume, fid=recvobj.fid}
    retobj.code = PDEFINE.RET.SUCCESS
    retobj.seat= user.seat
    retobj.coin = user.coin
    retobj.aid = aid

    for _, muser in pairs(deskInfo.users) do
        if muser.cluster_info and recvobj.uid~=muser.uid then
            sendMsg(muser, cjson.encode(retobj))
            if muser.offline == 0 then
                retobj.aid = nil
            end
        end
    end

    -- 激光没有子弹，需要特殊处理
    if GAME_ID.isHWBY(game_id) and recvobj.bt == 3 then   --激光
        local catchInfo = {c=2403}
        catchInfo.uid = user.uid
        catchInfo.bid = bulletid
        catchInfo.fids = {recvobj.fid}
        CMD._catch(catchInfo)
    end

    return PDEFINE.RET.ERROR.INVAlID_ERROR      --表示客户端不处理
end

-- 玩家发射,接口
function CMD.fire(source, msg)
    return CMD._fire(msg)
end

-- 玩家捕获
function CMD.catch(source, msg)
    return CMD._catch(msg)
end

function CMD._catch(recvobj)
    local uid = recvobj.uid
    if recvobj.aid ~= nil and recvobj.aid > 0 then  --AI ID
        uid = recvobj.aid
        if not AI.isAi(uid) then
            return PDEFINE.RET.ERROR.INVAlID_ERROR
        end
    end

    local user = selectUserInfo(uid, "uid")
    if not user then
        return PDEFINE.RET.ERROR.INVAlID_ERROR
    end
    if user.exiting then
        return PDEFINE.RET.ERROR.INVAlID_ERROR
    end

    local bulletid = recvobj.bid or 0
    bulletid = math.floor(bulletid)
    local bulletInfo = bullets[bulletid]
    bullets[bulletid] = nil

    if not bulletInfo then
        return PDEFINE.RET.ERROR.INVAlID_ERROR
    end
    if bulletInfo.uid ~= user.uid then
        return PDEFINE.RET.ERROR.INVAlID_ERROR
    end
    local num = #(recvobj.fids)
    if num > 3 then
        return PDEFINE.RET.ERROR.INVAlID_ERROR
    end

    local fts = {}
    local catchids = {}
    local catchinfos = {}
    local total = 0
    local maxft = 0
    for _, _fid in ipairs(recvobj.fids) do
        local fid = math.floor(_fid)
        local fishInfo = fishes[fid]
        if fishInfo then
            local ctrl_ratio = control_ratio[user.ctrl] * user.vipRate
            local score = fishfeature:onUserTryCatch(deskInfo, user, fishInfo, bulletInfo, 1/num)
            if score < 0 then
                score = tryCatchFish(fishInfo, bulletInfo.mul, 1/num, ctrl_ratio)
            end
            
            if score > 0 then
                if fishInfo.boom and fishInfo.boom > 0 then     --炸弹鱼
                    if STOCK.ensure(score) then
                        local boomInfo = {uid=user.uid, mul=bulletInfo.mul, bm=fishInfo.boom, ft=fishInfo.ft, rt=fishInfo.rt, max=fishInfo.multiple*bulletInfo.mul*1.2}  --记录炸弹信息
                        booms[fishInfo.id] = boomInfo

                        local retobj = {c=recvobj.c}
                        retobj.code = PDEFINE.RET.SUCCESS
                        retobj.seat= user.seat
                        retobj.fids = {fid}
                        retobj.coin = 0
                        retobj.mul = bulletInfo.mul
                        retobj.x = recvobj.x
                        retobj.y = recvobj.y
                        retobj.ft = fishInfo.ft
                        retobj.boom = fishInfo.boom
                        retobj.rt = fishInfo.rt
                        retobj.aid = recvobj.aid

                        -- 广播消息
                        for _, muser in pairs(deskInfo.users) do
                            if muser.cluster_info then
                                sendMsg(muser, cjson.encode(retobj))
                                if muser.offline == 0 then
                                    retobj.aid = nil
                                end
                            end
                        end

                        fishes[fid] = nil   -- 清除鱼
                        total = 0   
                        break  --炸弹鱼不与其他鱼一起捕获
                    end
                else
                    --去重
                    local dup = false
                    for _, catchid in ipairs(catchids) do
                        if catchid == fid then
                            dup = true
                            break
                        end
                    end
                    if not dup then
                        table.insert(fts, fishInfo.ft)
                        table.insert(catchids, fid)
                        table.insert(catchinfos, fishInfo)
                        total = total + score
                        if maxft < fishInfo.ft then
                            maxft = fishInfo.ft
                        end
                    end
                end
            end
        end
    end
    if total > 0 then
        if user.real then   --真实玩家要检查库存
            total = checkPool(user, total, fts, bulletInfo.mul)
        end

        if total > 0 then
            local ext = nil
            for idx, fid in ipairs(catchids) do   -- 清除鱼
                ext = fishfeature:onUserCatched(deskInfo, user, catchinfos[idx], bulletInfo)
                fishes[fid] = nil
            end

            userWinCoin(user, total)

            local retobj = {c=recvobj.c}
            retobj.code = PDEFINE.RET.SUCCESS
            retobj.seat= user.seat
            retobj.fids = catchids
            retobj.coin = total
            retobj.mul = bulletInfo.mul
            retobj.x = recvobj.x
            retobj.y = recvobj.y
            retobj.ft = maxft
            retobj.ext = ext
            broadcastDesk(cjson.encode(retobj))
        end
    end

    -- 补充深海狂鳌
    if GAME_ID.isHWBY(game_id) and maxft == 21 and timer_list["replenishBossTraceTimer"] == nil then
        timer_list["replenishBossTraceTimer"] = skynet.timeout(150, replenishBossTrace)
    end
    
    return PDEFINE.RET.ERROR.INVAlID_ERROR      --表示客户端不处理
end

-- 离子炮结束
function CMD.ionEnd(source, msg)
    return PDEFINE.RET.ERROR.INVAlID_ERROR
end

-- 炸弹鱼爆炸
function CMD.bomb(source, msg)
    local recvobj = msg
    local uid = recvobj.uid
    if recvobj.aid ~= nil and recvobj.aid > 0 then  --AI ID
        uid = recvobj.aid
        if not AI.isAi(uid) then
            return PDEFINE.RET.ERROR.INVAlID_ERROR
        end
    end
    local user = selectUserInfo(uid, "uid")
    if not user then
        return PDEFINE.RET.ERROR.INVAlID_ERROR
    end
    if user.exiting then
        return PDEFINE.RET.ERROR.INVAlID_ERROR
    end
    local boomid = recvobj.boomid or 0
    boomid = math.floor(boomid)
    local boomInfo = booms[boomid]
    if not boomInfo or boomInfo.uid ~= user.uid then
        return PDEFINE.RET.ERROR.INVAlID_ERROR
    end
    booms[boomid] = nil

    --计算总分
    local boom = boomInfo.bm
    local score = 0
    local fids = {}
    local fts = {}
    local fss = {}

    local cnt = 10  -- 炸鱼数量
    if boom == 2 then  -- 1:局部 2:全屏 3:同类 4:随机
        cnt = 20
    elseif boom == 4 then
        cnt = 5
    end
 
    for _, _fid in ipairs(recvobj.fids) do
        local fid = math.floor(_fid)
        local fishInfo = fishes[fid]
        if fishInfo and fishInfo.multiple <= 30 then
            local fishscore = fishInfo.multiple * boomInfo.mul
            if score + fishscore > boomInfo.max then  -- 最大获得分数
                break
            end
            score = score + fishscore
            table.insert(fts, fishInfo.ft)
            table.insert(fids, fid)
            table.insert(fss, fishscore)

            cnt = cnt - 1
            if cnt <= 0 then
                break
            end
        end
    end

    score = math.max(score, boomInfo.mul*10)  -- 保底分数

    if user.real then   --真实玩家要检查库存
        score = checkPool(user, score, fts, boomInfo.mul)
    end

    if score <= 0 then  -- 库存不足
        fids = {}
        fss = {}
    end

    for _, fid in ipairs(fids) do   -- 清除鱼
        fishes[fid] = nil
    end

    userWinCoin(user, score)

    local retobj = {c=recvobj.c}
    retobj.code = PDEFINE.RET.SUCCESS
    retobj.seat= user.seat
    retobj.fids = fids
    retobj.fss = fss
    retobj.coin = score
    retobj.mul = boomInfo.mul
    retobj.x = recvobj.x
    retobj.y = recvobj.y
    retobj.ang = recvobj.ang
    retobj.boom = boom
    retobj.ft = boomInfo.ft
    retobj.rt = boomInfo.rt
    broadcastDesk(cjson.encode(retobj))

    fishfeature:onUserBomb(deskInfo, user, boomInfo, score)

    return PDEFINE.RET.ERROR.INVAlID_ERROR      --表示客户端不处理
end

--玩家抽奖
function CMD.luckdraw(source, msg)
    local recvobj = msg
    local user = selectUserInfo(recvobj.uid, "uid")
    if not user then
        return PDEFINE.RET.ERROR.INVAlID_ERROR
    end
    if user.exiting then
        return PDEFINE.RET.ERROR.INVAlID_ERROR
    end

    local score, multiple = fishfeature:onUserLuckDraw(deskInfo, user, recvobj)
    if score < 0 then
        return PDEFINE.RET.ERROR.INVAlID_ERROR
    end

    if user.real and score > 0 then   --真实玩家要检查库存
        score = checkPool(user, score, {"luckdraw"}, multiple)
    end

    userWinCoin(user, score)

    local retobj = {c=recvobj.c, idx = recvobj.idx}
    retobj.code = PDEFINE.RET.SUCCESS
    retobj.seat= user.seat
    retobj.coin = score
    retobj.mul = multiple
    broadcastDesk(cjson.encode(retobj))

    return PDEFINE.RET.ERROR.INVAlID_ERROR
end

function CMD.exit()
    collectgarbage("collect")
    skynet.exit()
end

--更新玩家的桌子信息
function CMD.updateUserClusterInfo(source, uid, agent)
    local user = selectUserInfo(uid, "uid")
    if nil ~= user and user.cluster_info then
        user.cluster_info.address = agent
    end
end

local function getFish(fishid)
    return fishes[fishid]
end

local function getBullet(bulletid)
    return bullets[bulletid]
end

local function getBoom(boomid)
    return booms[boomid]
end

local function addBoom(boomid, boomInfo)
    booms[boomid] = boomInfo
end

local function getAi(uid)
    for _, ai in ipairs(AI.ais) do
        if ai.userInfo.uid == uid then
            return ai
        end
    end
end

local function deductStock(score)
    if STOCK.deduct(score) then
        gamelog.userwin = gamelog.userwin + score
        return score
    end
    return 0
end

local function ensureStock(score)
    return STOCK.ensure(score)
end

local function queryStock()
    return STOCK.current
end

--代理
local delegate = {
    _deskInfo = deskInfo,
    _getFish = getFish,
    _getBullet = getBullet,
    _getBoom = getBoom,
    _addBoom = addBoom,
    _getAi = getAi,
    _newFishId = newFishId,
    _buildFishTrace = buildFishTrace,
    _setTimer = setTimer,
    _clearTimer = clearTimer,
    _tryCatchFish = tryCatchFish,
    _deductStock = deductStock,
    _ensureStock = ensureStock,
    _queryStock = queryStock,
    _CMD = CMD,
}

-- 创建桌子
function CMD.create(source, cluster_info, msg, ip, deskid)
    local recvobj = msg

    LOG_INFO("创建房间 ", msg)

    local uid       = math.floor(recvobj.uid)
    local gameid    = math.floor(recvobj.gameid)
    local sessionid = recvobj.ssid or 0
    local level     = recvobj.level or 1
    local free      = recvobj.free or 0
    local virtualCoin = recvobj.virtualCoin or 0 --体验金
    local typeid  = recvobj.typeid or 1 -- 玩法 1海王 2悟空闹海 3金蟾捕鱼 4摇钱树捕鱼 5李逵捕鱼
    local mincoin   = recvobj.min or 0
    local leftcoin  = recvobj.left or 0
    local revenue   = recvobj.revenue or 0

    local now = os.time()
    deskInfo.free      = math.floor(free) --体验场房间 free =1
    deskInfo.deskid    = deskid
    deskInfo.uuid      = deskid .. now
    deskInfo.gameid    = gameid
    deskInfo.owner     = uid
    deskInfo.level     = math.floor(level)
    deskInfo.revenue   = math.floor(revenue) --茶水费比例
    deskInfo.ssid      = math.floor(sessionid)
    deskInfo.seat      = 4 --最多人数
    deskInfo.curseat   = 0 --当前坐下的人数
    deskInfo.state     = DESK_STATE.NORMAL  --桌子状态
    deskInfo.mincoin   = math.floor(mincoin) --最小入场
    deskInfo.virtualCoin = math.floor(virtualCoin)
    deskInfo.users       = {}

    local userInfo = loadUserInfo(cluster_info, uid)
    if not userInfo then
        return PDEFINE.RET.ERROR.PLAYER_NOT_FOUND
    end

    if userInfo.coin < math.floor(mincoin) then
        return PDEFINE.RET.ERROR.COIN_NOT_ENOUGH
    end

    userInfo.seat = math.random(1, 2)
    userInfo.ctrl = getUserRateCtrlIndex(uid)

    table.insert(deskInfo.users, userInfo)
    deskInfo.curseat = deskInfo.curseat + 1

    if gameid == GAME_ID.JACKPOT_FISH then
        SERVICE_NAME = SERVICE_NAME .. "_jp"
        fishconfig = require "fish.jackpotfishconfig"
        fishfeature = JackpotFishFeature.new(delegate)
    elseif gameid == GAME_ID.MEGA_FISH then
        SERVICE_NAME = SERVICE_NAME .. "_mega"
        fishconfig = require "fish.megafishconfig"
        fishfeature = MegaFishFeature.new(delegate)
    end

    assert(fishconfig)
    game_id = gameid
    deskInfo.seat = fishconfig.seat_count
    userInfo.mults = getMultsFromChips()

    if fishconfig.resolution_width and fishconfig.resolution_height then
        RESOLUTION_WIDTH = fishconfig.resolution_width
        RESOLUTION_HEIGHT = fishconfig.resolution_height
    end

    if not fishfeature then
        fishfeature = FishFeature.new(delegate)
    end
    fishfeature:init(fishconfig)
    fishfeature:onUserEnter(deskInfo, userInfo)

    --桌子落地到数据库
    local sql = string.format("insert into d_desk(uuid, deskid,gameid,sessionid,owner,typeid,status,seat,curseat,mincoin,leftcoin,create_time) values('%s',%d,%d,%d,%d,%d,%d,%d,%d,%d,%d)", 
        deskInfo.uuid, deskid, gameid, sessionid, uid, typeid, 0, deskInfo.seat, 1, mincoin, leftcoin, os.time())
    skynet.send(".mysqlpool", "lua", "execute", sql)
    
    startGame()

    STOCK.start()    -- 库存初始化

    AI.check()      -- AI初始化

    CMD.reload()    -- 控制初始化

    local tmp = getDeskBaseInfo();
    return PDEFINE.RET.SUCCESS, tmp
end


-- 加入桌子
function CMD.join(source, cluster_info, msg, ip)
    local recvobj   = msg
    local uid       = math.floor(recvobj.uid)
    local deskid = recvobj.deskid
    local ouser = selectUserInfo(uid, "uid")
    if ouser then
        return PDEFINE.RET.ERROR.PLAYER_EXISTS_DESK
    end
    --判断房间是否满员
    local seat = selectEmptySeat()
    if not seat then
        return PDEFINE.RET.ERROR.SEATID_EXIST
    end
    local userInfo = loadUserInfo(cluster_info, uid)
    if not userInfo then
        return PDEFINE.RET.ERROR.PLAYER_NOT_FOUND
    end
    if deskid ~= deskInfo.deskid then
        return PDEFINE.RET.ERROR.DESKID_FAIL
    end
    --判断房费
    if userInfo.coin < deskInfo.mincoin then
        return PDEFINE.RET.ERROR.COIN_NOT_ENOUGH
    end

    userInfo.seat = seat
    userInfo.ctrl = getUserRateCtrlIndex(uid)
    userInfo.mults = getMultsFromChips()
    userEnterDesk(userInfo, true)

    if deskInfo.curseat == 1 then
        startGame()
    end
    
    local retobj  = {}
    retobj.code = PDEFINE.RET.SUCCESS
    retobj.c = math.floor(recvobj.c)
    retobj.gameid = deskInfo.gameid
    retobj.deskinfo = getDeskBaseInfo()

    return PDEFINE.RET.SUCCESS, cjson.encode(retobj) --返回
end

-- 退出房间
function CMD.exitG(source, msg)
    LOG_DEBUG("玩家退出", msg)
    local recvobj = msg
    local uid     = math.floor(recvobj.uid)
    local user  = selectUserInfo(uid, "uid")

    if user ~= nil then  --玩家离开 必须存在房间中
        user.exiting = true
        -- 结算
        userSettle(user)
        --记录
        userSendLog(user, 0, {fish={}, blt=0})

        userLeaveDesk(user, true)

        pcall(cluster.send, user.cluster_info.server, user.cluster_info.address, "deskBack", deskInfo.gameid)
    end

    if deskInfo.curseat == 0 and #deskInfo.users == 0 then
        restDeskInfo()
    end

    return PDEFINE.RET.SUCCESS
end

--用户在线离线 掉线了 1上线  2掉线
function CMD.offline(source, offline, uid)
    local user = selectUserInfo(uid, "uid")
    if user then
        if offline == 1 then --上线
            user.offline = 0
            user.tick = skynet.now() -- 重新计时
        else
            user.offline = 1  --掉线
        end
        LOG_DEBUG("玩家掉线", uid, offline)

        local retobj = {}
        retobj.c = PDEFINE.NOTIFY.NOTIFY_ONLINE
        retobj.code = PDEFINE.RET.SUCCESS
        retobj.offline = user.offline
        retobj.seat = user.seat
        broadcastDesk(cjson.encode(retobj), user.uid)
        -- 结算
        userSettle(user)
        --记录
        userSendLog(user, 0, {fish={}, blt=0})
    end
end

-- 用户离线获取牌桌信息
function CMD.getDeskInfo(source,msg)
    local recvobj = msg
    if recvobj.uid then
        local uid = math.floor(recvobj.uid)
        if not selectUserInfo(uid, "uid") then
            return {}
        end
    end
    local tmp = getDeskBaseInfo()
    return tmp
end

-- 后台取牌桌信息
function CMD.apiGetDeskInfo(source,msg)
    return deskInfo
end

--后台API 停服清房
function CMD.apiCloseServer(source,csflag)
    --踢掉
    if csflag == true then
        --释放该用户的桌子对象
        LOG_INFO("停服清房 apiCloseServer")
        for i, user in pairs(deskInfo.users) do
            local retobj    = {}
            retobj.code     = PDEFINE.RET.SUCCESS
            retobj.c        = PDEFINE.NOTIFY.NOTIFY_SYS_KICK
            retobj.uid      = user.uid
            if user.cluster_info then
                --结算
                userSettle(user)   
                --记录
                userSendLog(user, 0, {fish={}, blt=0})

                sendMsg(user, cjson.encode(retobj))
                pcall(cluster.send, user.cluster_info.server, user.cluster_info.address, "deskBack", deskInfo.gameid) --释放桌子对象
            end
        end

        restDeskInfo()
    end
end

--后台API 解散房间
function CMD.apiKickDesk(source)
    --踢掉
    LOG_INFO("系统解散房间 apiKickDesk")
    for _, user in pairs(deskInfo.users) do
        if user.cluster_info then
            user.exiting = true
            --玩家结算
            userSettle(user)
            --记录
            userSendLog(user, 0, {fish={}, blt=0})

            pcall(cluster.send, user.cluster_info.server, user.cluster_info.address, "deskBack", deskInfo.gameid) --释放桌子对象
            pcall(cluster.send, "master", ".mgrdesk", "changMatchCurUsers", GAME_NAME, deskInfo.gameid, deskInfo.deskid, -1)
        end
    end

    local retobj = {c = PDEFINE.NOTIFY.ALL_GET_OUT, code = PDEFINE.RET.SUCCESS}
    broadcastDesk(cjson.encode(retobj))

    restDeskInfo()
end

function CMD.apiKickUser(source, uid)
    kickUser(uid, PDEFINE.NOTIFY.NOTIFY_SYS_KICK)
end

--广播跑马灯
function CMD.apiSendDeskNotice(source, msg)
    broadcastDesk(msg)

    return PDEFINE.RET.SUCCESS
end

-------- API更新桌子里玩家的金币 --------
function CMD.addCoinInGame(source, uid, coin)
    uid = math.floor(uid)
    local user = selectUserInfo(uid, "uid")
    if nil ~= user then
        user.coin = user.coin + coin
    end
end

--重新加载控制参数
function CMD.reload()
    local ok, game = pcall(cluster.call, "master", ".gamemgr", "getRow", deskInfo.gameid)
    if game and game.control ~= nil and game.control~="" then
        local control = cjson.decode(game.control)
        for i = 1, 5 do
            if control[i] and control[i].ratio then
                local ratio = tonumber(control[i].ratio)
                if ratio and ratio >= 0 then
                    control_ratio[i] = ratio
                end
            end
        end
        LOG_DEBUG("加载控制参数", game.control, control_ratio)
    end
end

function CMD.init()
end

skynet.start(function()
    skynet.dispatch("lua", function(session, source, command, ...)
        local f = assert(CMD[command])
        skynet.retpack(f(source, ...))
    end)

    collectgarbage("collect")
end)
