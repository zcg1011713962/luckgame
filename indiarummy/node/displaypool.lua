local skynet = require "skynet"
local cluster = require "cluster"
local api_service = require "api_service"

local displaypool = {}

local baseDisplaypool = {} --获取基准值
local basetable = {}--计算后的基准值
local gameList = {}

local usersAutoFuc = {}
local timeout = {10*100} --1定时更新奖金池

local getdata_list = {
    ["disbigbang"] = 1,
    ["disslc"] = 2,   -- mini
    ["diszbc"] = 3,   -- 原意：minor  现在当做 mini
    ["pooljp"] = 4,   -- 原意：normal 现在当做 minor
    ["poolmega"] = 5, --大奖池 major
    ["poolgrand"] = 6,--超大奖池 grand
} --需要去拿的数据 对应是PDEFINE_REDISKEY里面的key

math.randomseed(tostring(os.time()):reverse():sub(1, 7))

--获取奖池信息
--@return {[key1] = conf1,[key2] = conf2} 其中 key是getdata_list配置的数据 conf是从api获取到的配置信息
local function getApiDisplaypool()
    local ret = {}
    for v,index in pairs(getdata_list) do
        local ok, data = api_service.callAPIMod( "getdata", 0, nil, v )
        local tmp = {base=math.random(1000, 12000),time=math.random(10, 30),volatility=math.random(10,50) ,downRandom=math.random(10, 50)}
        if ok == PDEFINE.RET.SUCCESS and nil ~= data and not table.empty(data) then
            tmp.base = data.disbaseline
            tmp.time = data.valdown_time*60 --下降时间
            tmp.volatility  = data.wave_val --波动率
            tmp.downRandom  = data.valdown_parl --下降率
        end
        ret[index] = tmp
    end

    return ret
end

--计算奖池波动,根据配置计算各个奖池的波动情况
local function setBaseTable()
    if table.empty(baseDisplaypool) then
        baseDisplaypool = getApiDisplaypool()
        for key,v in pairs(baseDisplaypool) do
            local hallbasetmp = math.random(math.floor(v.base-math.floor(v.base*v.volatility/100)),math.floor(v.base+math.floor(v.base*v.volatility/100)))
            basetable[key] = hallbasetmp
        end
    end
end

--计算奖池波动,根据配置计算指定奖池的波动情况，并且返回一个给客户端用来计算逻辑的配置
--@param pooltype 奖池类型(参考getdata_list)
--@return data data是用于客户端计算的数据
function displaypool.getClientDisByPoolType(pooltype)
    local key = pooltype
    local v = baseDisplaypool[key]
    local temp = math.random((basetable[key]-math.floor(basetable[key]*v.volatility/100)),(basetable[key]+math.floor(basetable[key]*v.volatility/100)))
    temp = math.random((temp-math.floor(temp*v.downRandom/100)),(temp+math.floor(temp*v.downRandom/100)))
    return temp
end

--计算奖池波动,根据配置计算各个奖池的波动情况，并且返回一个给客户端用来计算逻辑的配置
--@return {[key1] = data1,[key2] = data2} 其中 kay是getdata_list配置的数据 data是用于客户端计算的数据
function displaypool.getClientDisplay()
    local clientdisplaypool = {}
    for key,v in pairs(baseDisplaypool) do
        clientdisplaypool[key] = displaypool.getClientDisByPoolType(key)
    end
    return clientdisplaypool
end

--更新大厅奖金池
local function updateDisplaypool()
    local newbase = getApiDisplaypool()
    for key,newconf in pairs(newbase) do
        local oldconf = baseDisplaypool[key]
        if oldconf == nil
            or newconf.base ~= oldconf.base
            or newconf.time ~= oldconf.time
            or newconf.volatility ~= oldconf.volatility
            or newconf.downRandom ~= oldconf.downRandom
        then
            baseDisplaypool[key] = newconf
            local hallbasetmp = math.random((newconf.base-math.floor(newconf.base*newconf.volatility/100)),(newconf.base+math.floor(newconf.base*newconf.volatility/100)))
            basetable[key] = hallbasetmp
        end
    end
    displaypool.autoAction("updateDisplaypool", timeout[1])
end

--启动相对应的定时器
--@param type
--@pram autoTime
function displaypool.startTimer(type, autoTime)
    if not usersAutoFuc[type] then
        displaypool.autoAction(type,autoTime)
    end
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

function displaypool.autoAction(type,autoTime)
    if type == "updateDisplaypool" then --更新大厅奖池
        usersAutoFuc[type] = user_set_timeout(autoTime, updateDisplaypool)
    end
end

--存放gameidList
function displaypool.setGameIdList()
    gameList = {}
    local ok, result = pcall(cluster.call, "master", ".gamemgr", "getGameList")
    if ok then
        gameList = result
    else
        local function t()
            displaypool.setGameIdList()
        end
        --5秒之后再请求一次
        skynet.timeout(500, t)
    end
end

--获取大厅奖池 登录的时候就会启动 更新大厅定时器以及衰弱时间的定时器
function displaypool.getHallDisplaypool()
    local displaypooltable = getClientDisplay()
    return displaypooltable
end

--启动指令
function displaypool.startRun()
    displaypool.setGameIdList()
    setBaseTable()
    displaypool.startTimer("updateDisplaypool", timeout[1])
end

--获取所有游戏类型的指定分页的指定奖池数据
--@param pooltype 奖池类型(参考getdata_list)
--@return list
function displaypool.getAllDisplaypool( pooltype )
    local rs = {}
    for gametype,v in pairs(gameList) do
        local tmp = displaypool.getDisplaypool( gametype, pooltype )
        table.merge(rs, tmp)
    end
    return rs
end

--获取指定游戏类型的指定分页的指定奖池数据
--@param gametype 游戏分类
--@param pooltype 奖池类型(参考getdata_list)
--@return list
function displaypool.getDisplaypool( gametype, pooltype )
    local rs = {}
    local search_list = gameList[gametype]
    if search_list ~= nil then
        local allnum = #search_list
        for i=1,allnum do
            local game = search_list[i]
            if game ~= nil then
                rs[game.id] = displaypool.getClientDisByPoolType(pooltype)
            end
        end
    end
    return rs
end


------------------------------------------------------------
---------------------- 服务接口部分 -------------------------
------------------------------------------------------------

local CMD = {}

function CMD.start()
    displaypool.startRun()
end

--获取彩池基准值
function CMD.getBaseDisplaypool()
    return baseDisplaypool
end

--获取bigbang和所有jp彩池数据(玩家登陆)
function CMD.getPoolData()
    local rs = {}
    rs.bigbang  = displaypool.getClientDisByPoolType(getdata_list.disbigbang)
    rs.disslc   = displaypool.getClientDisByPoolType(getdata_list.disslc)
    rs.diszbc   = displaypool.getClientDisByPoolType(getdata_list.diszbc)
    rs.pooljp   = displaypool.getAllDisplaypool(getdata_list.pooljp)
    rs.poolmega = displaypool.getClientDisByPoolType(getdata_list.poolmega)
    rs.poolgrand= displaypool.getClientDisByPoolType(getdata_list.poolgrand)
    return rs
end

--获取jp彩池数据
function CMD.getJpPoolData()
    local rs     = {}
    rs.diszbc   = displaypool.getAllDisplaypool(getdata_list.diszbc)
    rs.pooljp    = displaypool.getAllDisplaypool(getdata_list.pooljp)
    rs.poolmega  = displaypool.getAllDisplaypool(getdata_list.poolmega)
    rs.poolgrand = displaypool.getAllDisplaypool(getdata_list.poolgrand)
    rs.base      = baseDisplaypool[getdata_list.pooljp]
    return rs
end

--- 根据gameId取所有的彩池数据
function CMD.getSuperRewardByGameId(gameId)
    local miniList = displaypool.getAllDisplaypool(getdata_list.diszbc)
    local minorList = displaypool.getAllDisplaypool(getdata_list.pooljp)
    local majorList = displaypool.getAllDisplaypool(getdata_list.poolmega)
    local grandList = displaypool.getAllDisplaypool(getdata_list.poolgrand)
    local res = {}
    res.mini = miniList[gameId] and miniList[gameId] or 0
    res.minor = minorList[gameId] and minorList[gameId] or 0
    res.major = majorList[gameId] and majorList[gameId] or 0
    res.grand = grandList[gameId] and grandList[gameId] or 0
    return res
end

--获取某个分类的jp彩池数据
function CMD.getJpPoolDataByGameType(gametype)
    local rs = {}
    rs.pooljp = displaypool.getDisplaypool(gametype, getdata_list.pooljp)
    return rs
end

--获取某个游戏的jp彩池数据
function CMD.getJpPoolDataByGameId(gameid)
    local rs = {}
    rs.pooljp = displaypool.getClientDisByPoolType(getdata_list.pooljp)
    return rs
end

--获取双龙和争霸彩池数据(玩家进入游戏)
function CMD.getHallPoolData()
    local rs = {}
    rs.bigbang = displaypool.getClientDisByPoolType(getdata_list.disbigbang)
    rs.disslc = displaypool.getClientDisByPoolType(getdata_list.disslc)
    rs.diszbc = displaypool.getClientDisByPoolType(getdata_list.diszbc)
    rs.dismega = displaypool.getClientDisByPoolType(getdata_list.poolmega)
    rs.disgrand= displaypool.getClientDisByPoolType(getdata_list.poolgrand)
    rs.base = baseDisplaypool[getdata_list.disbigbang]
    return rs
end

skynet.start(function()
    skynet.dispatch("lua", function(session, address, cmd, ...)
        local f = CMD[cmd]
        skynet.retpack(f(...))
    end)
    skynet.register(".displaypool")
end)