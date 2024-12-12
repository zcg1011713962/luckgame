--[[
local skynet = require "skynet"
local cjson   = require "cjson"
local handle
--展示jp
local jackpot = {}

local usersAutoFuc = {}
local timeout = {5*60,10*60} --1定时更新大厅奖金池  2定时更新游戏奖池
local timerType = {"pushHallJackpot", "pushGameJackpot"}
local uid = 0

--成功返回
local function resp(retobj)
    return PDEFINE.RET.SUCCESS, cjson.encode(retobj)
end

function jackpot.bind(agent_handle)
    handle = agent_handle
end

--获取大厅奖池 登录的时候就会启动 更新大厅定时器以及衰弱时间的定时器
function jackpot.initJackpot(userid)
	uid = userid

    local base = skynet.call(".displaypool", "lua", "getBaseDisplaypool")
	--未启动过大厅推送的定时器则启动
	jackpot.startTimer("pushHallJackpot", base[1].time*100)
    jackpot.startTimer("pushGameJackpot", base[4].time*100)
end

function jackpot.getJackpot()
    return skynet.call(".displaypool", "lua", "getPoolData")
end

function jackpot.getHallJackpot()
    return skynet.call(".displaypool", "lua", "getHallPoolData")
end

--进入游戏获取游戏奖金池
function jackpot.getGameJackpot()
    return skynet.call(".displaypool", "lua", "getJpPoolData")
end

--- 通过gameId来获取superReward
function jackpot.getSuperRewardByGameId(gameId)
    return skynet.call(".displaypool", "lua", "getSuperRewardByGameId", gameId)
end

function jackpot.getGameJackpotByGameId(gameid)
    local rs = skynet.call(".displaypool", "lua", "getJpPoolDataByGameId", gameid)
    return rs.pooljp
end

--启动相对应的定时器
function jackpot.startTimer(type,autoTime)
	if not usersAutoFuc[type] then
		jackpot.autoAction(type,autoTime)
	end
end

--关闭相对应的定时器
function jackpot.closeTimer(type)
	if usersAutoFuc[type] then
		usersAutoFuc[type]()
	end
end

--关闭所有的定时器
function jackpot.closeAllTimer()
	for _,v in pairs(timerType) do
		if usersAutoFuc[v] then
			usersAutoFuc[v]()
		end
	end
end


--推送给在大厅的用户
local function pushHallJackpot()
	--通知用户
	local notyInfo    = {}
	notyInfo.code     = PDEFINE.RET.SUCCESS
	notyInfo.c        = PDEFINE.NOTIFY.JACKPOT_HALL_GOLD
	notyInfo.uid      = uid
    local rs = skynet.call(".displaypool", "lua", "getHallPoolData")
	notyInfo.jackpot  = rs.bigbang
    notyInfo.disslc   = rs.disslc
    notyInfo.diszbc   = rs.diszbc
    notyInfo.dismega  = rs.dismega
    notyInfo.disgrand = rs.disgrand
	handle.sendToClient(cjson.encode(notyInfo))

    jackpot.autoAction("pushHallJackpot",rs.base.time*100)
end


--推送给在游戏的用户
local function pushGameJackpot()
	--通知用户
	local notyInfo    = {}
	notyInfo.code     = PDEFINE.RET.SUCCESS
	notyInfo.c        = PDEFINE.NOTIFY.JACKPOT_GAME_GOLD
	notyInfo.uid      = uid
    local rs = jackpot.getGameJackpot()
	local gameJackpotList = {}
	for i,v in pairs(rs.pooljp) do
        local gameJackpotInfo = {}
        gameJackpotInfo.gameid = i
        gameJackpotInfo.grand  = rs.poolgrand[i]
        gameJackpotInfo.major  = rs.poolmega[i]
        gameJackpotInfo.gameJackpot = v
        gameJackpotInfo.mini   = rs.diszbc[i]
        table.insert(gameJackpotList,gameJackpotInfo)
    end
    -- print("--------gameJackpotList-----------",gameJackpotList)
	notyInfo.gameJackpotList = gameJackpotList
	-- print("--------notyInfo-----------",notyInfo)
	handle.sendToClient(cjson.encode(notyInfo))

	jackpot.autoAction("pushGameJackpot", rs.base.time*100)
end


--返回大厅获取bigbang跟jp奖池
function jackpot.getHallAndJp(msg)
	local recvobj = cjson.decode(msg)
    local uid = math.floor(recvobj.uid)
	local rs = skynet.call(".displaypool", "lua", "getPoolData")
	local gameJackpotList = {}
    for i, v in pairs(rs.pooljp) do
        local gameJackpotInfo = {}
        gameJackpotInfo.gameid = i
        gameJackpotInfo.gameJackpot = v
        table.insert(gameJackpotList,gameJackpotInfo)
    end
    local retobj = {}
    retobj.c     = math.floor(recvobj.c)
    retobj.code  = PDEFINE.RET.SUCCESS
    retobj.uid      = uid
    retobj.gameJackpotList = gameJackpotList
    retobj.hallJackpot = rs.bigbang
    retobj.disslc = rs.disslc
    retobj.diszbc = rs.diszbc
    return resp(retobj)
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


function jackpot.autoAction(type,autoTime)
    --print("autoAction", type, autoTime)
    if type == "pushHallJackpot" then --推送给大厅玩家
        usersAutoFuc[type] = user_set_timeout(autoTime, pushHallJackpot)
    end

    if type == "pushGameJackpot" then --推送给游戏玩家
        usersAutoFuc[type] = user_set_timeout(autoTime, pushGameJackpot)
    end
end


return jackpot
]]--



-- ##############################################################
-- ##############################################################
-- #                      LamiSlots新奖池                       #
-- ##############################################################
-- ##############################################################

local skynet = require "skynet"
local cjson   = require "cjson"
local cluster = require "cluster"
local handle
--展示jp
local jackpot = {}

local usersAutoFuc = {}
local timeout = 3*60*100
local timerType = {"pushGameJackpot"}
local uid = 0
local level = 0
local maxbet = 10000

--成功返回
local function resp(retobj)
    return PDEFINE.RET.SUCCESS, cjson.encode(retobj)
end

function jackpot.bind(agent_handle)
    handle = agent_handle
end

--获取大厅奖池 登录的时候就会启动 更新大厅定时器以及衰弱时间的定时器
function jackpot.initJackpot(userid)
	uid = userid
    jackpot.startTimer("pushGameJackpot", timeout)
end

--进入游戏获取游戏奖金池
function jackpot.getGameJackpot()
    return skynet.call(".jackpotmgr", "lua", "getGameJackpot")
end

function jackpot.getGameJackpotByGameId(gameid)
    return skynet.call(".jackpotmgr", "lua", "getGameJackpotByGameId")
end

--启动相对应的定时器
function jackpot.startTimer(type,autoTime)
	if not usersAutoFuc[type] then
		jackpot.autoAction(type,autoTime)
	end
end

--关闭相对应的定时器
function jackpot.closeTimer(type)
	if usersAutoFuc[type] then
		usersAutoFuc[type]()
	end
end

--关闭所有的定时器
function jackpot.closeAllTimer()
	for _,v in pairs(timerType) do
		if usersAutoFuc[v] then
			usersAutoFuc[v]()
		end
	end
end

--推送给在游戏的用户
local function pushGameJackpot()
    --通知用户
    local playerData = handle.dcCall("user_dc", "get", uid)
    if level ~= playerData.level then  -- 等级改变
        level = playerData.level
        local ok, val = pcall(cluster.call, "master", ".vipCenter", "getMaxBet", level)
        if ok then
            maxbet = val
        end
    end
	local notyInfo    = {}
	notyInfo.code     = PDEFINE.RET.SUCCESS
	notyInfo.c        = PDEFINE.NOTIFY.JACKPOT_GAME_GOLD
    notyInfo.uid      = uid
    notyInfo.maxbet   = maxbet
    local rs = jackpot.getGameJackpot()
    local isTiShen = handle.isTiShen()
    local show_ids = handle.getTishenGameIDs()
    local gameJackpotList = {}
	for i,v in pairs(rs) do
        if isTiShen then
            if table.contain(show_ids, v.id) then
                local gameJackpotInfo = {}
                gameJackpotInfo.gameid = v.id
                gameJackpotInfo.jp = v.jp
                table.insert(gameJackpotList,gameJackpotInfo)
            end
        else
            local gameJackpotInfo = {}
            gameJackpotInfo.gameid = v.id
            gameJackpotInfo.jp = v.jp
            table.insert(gameJackpotList,gameJackpotInfo)
        end
    end
    notyInfo.gameJackpotList = gameJackpotList

	-- handle.sendToClient(cjson.encode(notyInfo))
	-- jackpot.autoAction("pushGameJackpot", timeout)
end


--返回大厅获取bigbang跟jp奖池
function jackpot.getHallAndJp(msg)
	local recvobj = cjson.decode(msg)
    local uid = math.floor(recvobj.uid)
    local retobj = {}
    retobj.c     = math.floor(recvobj.c)
    retobj.code  = PDEFINE.RET.SUCCESS
    retobj.uid      = uid
    retobj.maxbet   = maxbet
    local rs = jackpot.getGameJackpot()
    local gameJackpotList = {}
	for i,v in pairs(rs) do
        local gameJackpotInfo = {}
        gameJackpotInfo.gameid = v.id
        gameJackpotInfo.jp = v.jp
        table.insert(gameJackpotList,gameJackpotInfo)
    end
    retobj.gameJackpotList = gameJackpotList
    return resp(retobj)

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

function jackpot.autoAction(type,autoTime)
    if type == "pushGameJackpot" then --推送给游戏玩家
        usersAutoFuc[type] = user_set_timeout(autoTime, pushGameJackpot)
    end
end

return jackpot