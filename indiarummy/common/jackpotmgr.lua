--node服和game服各起一个jackpotmgr服务
--node服用于向前端提供奖池数值显示
--game服用于发奖

local skynet = require "skynet"
require "skynet.manager"
local cluster = require "cluster"
local cjson = require "cjson"
cjson.encode_sparse_array(true)
cjson.encode_empty_table_as_object(false)

math.randomseed(tostring(os.time()):reverse():sub(1, 7))

local configJackpot = require "jackpotConfig"

local BET_COIN = {
    1,
    5,
    10,
    20,
    30,
    50,
    100,
    200,
    300,
    500,
    1000,
    1500,
    2000,
    3000,
    5000,
}

local gamejackpots = {}

local CMD = {}

local function loadFromConfig()
    local lst = {}
    for id, row in pairs(configJackpot) do
        local info = {}
        info.id = id
        info.jp = row.MULT
        info.unlockindex = row.UNLOCK
        info.unlock = {}
        for i, v in ipairs(info.unlockindex) do
            info.unlock[i] = BET_COIN[v] or 0
        end
        lst[info.id] = info
    end

    gamejackpots = lst
end

local function randomlize(jpinfo)
    local info = {}
    info.id = jpinfo.id
    info.jp = {}
    info.unlock = {}
    info.unlockindex = {}
    for i = 1, #jpinfo.jp do
        info.jp[i] = math.floor(jpinfo.jp[i] * (0.9 + math.random()*0.2) + 0.5)
        info.unlock[i] = jpinfo.unlock[i]
        info.unlockindex[i] =  jpinfo.unlockindex[i]
    end
    return info
end

function CMD.start()
    loadFromConfig()
end

function CMD.getGameJackpot()
    local lst = {}
    for _, jpinfo in pairs(gamejackpots) do
        lst[jpinfo.id] = randomlize(jpinfo)
    end
    return lst
end

function CMD.getGameJackpotByGameId(gameid)
    local jpinfo = gamejackpots[gameid]
    if not jpinfo then
        jpinfo = {id=gameid, jp={10,50,100,500}, unlock={0,0,0,0}, unlockindex={1,1,1,1},}
    end
    return randomlize(jpinfo)
end

--@func 获取解锁的奖池列表
--@param gameid: 游戏ID
--@param totalbet: 玩家总下注

--@return 解锁的奖池序号列表
function CMD.getUnlockJackpot(gameid, totalbet)
    local unlockjps = {}
    local jpinfo = gamejackpots[gameid]
    if jpinfo then
        for jpidx, unlock_bet in ipairs(jpinfo.unlock) do
            if totalbet>=unlock_bet then
                table.insert(unlockjps, jpidx)
            end
        end
    end
    return unlockjps
end

--@func 获得奖池中奖金额
--@param gameid: 游戏ID
--@param jpidx：奖池序号
    -- 1:mini
    -- 2:minor
    -- 3:major:
    -- 4:grand(mega)
    -- 5:...游戏自定义奖池
--@param totalbet: 玩家总下注

--@return 玩家中奖值
function CMD.getJackpotValueByBet(gameid, jpidx, totalbet)
    local info = CMD.getGameJackpotByGameId(gameid)
    local jpvalue = info.jp[jpidx] or 10
    --随机化 1.0~1.1倍之间随机
    jpvalue = jpvalue * (1.0 + math.random()*0.1)
    local award = jpvalue*totalbet
    -- 取整
    award = math.floor(award/100)*100
    return award
end

skynet.start(function()
    skynet.dispatch("lua", function(session, address, cmd, ...)
        local f = CMD[cmd]
        skynet.retpack(f(...))
    end)
    skynet.register(".jackpotmgr")
end)
