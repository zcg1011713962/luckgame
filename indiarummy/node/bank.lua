local skynet  = require "skynet"
local cjson   = require "cjson"
cjson.encode_sparse_array(true)
cjson.encode_empty_table_as_object(false)
local crypt   = require "crypt"
local md5     = require "md5"
local cluster = require "cluster"
local snax    = require "snax"
local player_tool = require "base.player_tool"

--[[
--- 保险箱功能
--- 1、进入银行
--- 2、刷新银行大厅
--- 3、存款
--- 4、取款（包括游戏内取款）
--- 5、银行记录
--- 6、修改密码
--- 7、退出银行
--- 8、游戏内快速取款（带密码和取款金额）
]]

local handle
local bank = {}
function bank.bind(agent_handle)
    handle = agent_handle
end



-------- 成功返回函数 --------
local function resp(retobj)
    return PDEFINE.RET.SUCCESS, cjson.encode(retobj)
end

-------- 生成此次token --------
local function genToken(uid, secret)
    local token = crypt.hashkey(uid .. ":" .. skynet.now() .. ":" .. secret)
    return crypt.hexencode(token)
end

-------- 生成密码 ------
local function genPasswd(str)
    return md5.sumhexa(str)
end

-------- 玩家银行密码错误的缓存key --------
local function getPasswdErrCacheKey(uid)
    return "bankerrortimes_".. uid
end

-------- 玩家银行被锁的缓存key --------
local function getLockCacheKey(uid)
    return "banklocked_" ..uid
end

-------- 玩家银行是否被锁定10分钟 --------
local function isLocked(uid)
    local ret = false
    local keyLock = getLockCacheKey(uid)
    local locked = do_redis({ "get", keyLock}, uid)
    if nil ~= locked then
        ret = true
    end
    return ret
end

------ 初始化玩家银行 --------
function bank.init(uid)
    local bankCache = handle.dcCall("bank_dc","get", uid)
    if nil == bankCache or table.empty(bankCache) then
        local now = os.time()
        local bankinfo = {}
        bankinfo.uid  = uid
        bankinfo.coin = 0
        bankinfo.passwd = genPasswd("888888") --默认密码6个8
        bankinfo.create_time = now
        bankinfo.update_time = now
        handle.dcCall("bank_dc","add", bankinfo)
    end
end

-------- 进入银行 --------
function bank.enter(msg)
    local recvobj = cjson.decode(msg)

    local uid    = math.floor(recvobj.uid)
    local passwd = recvobj.passwd or '888888'
    assert(passwd, uid .. "进入银行缺少密码 " .. os.time())
    --校验密码
    passwd = genPasswd(passwd)
    local bankinfo = handle.dcCall("bank_dc","get", uid)
    local retobj = {c = math.floor(recvobj.c), code = PDEFINE.RET.SUCCESS, spcode=0,uid=uid}
    if not bankinfo or bankinfo.passwd ~= passwd then
        retobj.spcode = PDEFINE.RET.ERROR.BANK_PASSWD_ERROR
        return resp(retobj)
    end

    local token = genToken(uid, passwd)
    local up    = {}
    up["update_time"] = os.time()
    up["token"] = token
    handle.dcCall("bank_dc","setvalue", uid, up)

    local playerInfo = handle.moduleCall("player","getPlayerInfo", uid)
    retobj.bankcoin  = bankinfo.coin
    retobj.coin      = playerInfo.coin
    retobj.token     = token
    return resp(retobj)
end

-------- 玩家的银行信息 --------
---- 在游戏内也调用
function bank.info(msg)
    local recvobj = cjson.decode(msg)
    local uid     = math.floor(recvobj.uid)
    local retobj = {c = math.floor(recvobj.c), code = PDEFINE.RET.SUCCESS, spcode=0,uid=uid}
    local bankinfo = handle.dcCall("bank_dc","get", uid)
    if not bankinfo then
        retobj.spcode = PDEFINE.RET.ERROR.BANK_TOKEN_ERROR
        return resp(retobj)
    end
    local token = genToken(uid, bankinfo.passwd)
    local playerInfo = handle.moduleCall("player","getPlayerInfo", uid)
    retobj.bankcoin = bankinfo.coin
    retobj.coin     = playerInfo.coin
    retobj.token    = token
    return resp(retobj)
end

-------- 玩家存钱 --------
function bank.save(msg)
    LOG_INFO(os.date("%Y-%m-%d %H:%M:%S", os.time()), " bank_save :", msg)
    local recvobj = cjson.decode(msg)
    local uid     = math.floor(recvobj.uid)
    local coin    = tonumber(recvobj.coin)
    local gameid  = recvobj.gameid or 0
    local deskid  = recvobj.deskid or 0
    local token   = recvobj.token --玩家此次登录的token
    assert(token, uid .. "获取玩家的银行信息 缺少token " .. os.time())
    local retobj = {c = math.floor(recvobj.c), code = PDEFINE.RET.SUCCESS, spcode=0, uid=uid}
    local bankinfo = handle.dcCall("bank_dc","get", uid)
    if not bankinfo or bankinfo.token ~= token then
        retobj.spcode = PDEFINE.RET.ERROR.BANK_TOKEN_ERROR
        return resp(retobj)
    end

    local playerInfo = handle.moduleCall("player","getPlayerInfo", uid)
    if playerInfo.coin < coin then
        retobj.spcode = PDEFINE.RET.ERROR.BANK_USER_COIN_NOT_ENOUGH
        return resp(retobj)
    end
    local beforecoin = playerInfo.coin
    local logStr = "玩家[".. uid .."]现有金币".. playerInfo.coin  .."，银行金币".. bankinfo.coin .." 存钱"..coin

    local cointype = PDEFINE.ALTERCOINTAG.BANKDOWN
    local code, before_coin, after_coin = player_tool.funcAddCoin(uid, -coin, "银行存款", cointype, 0, PDEFINE.POOL_TYPE.none, nil, nil)
                
    bankinfo.coin = bankinfo.coin + coin
    handle.dcCall("bank_dc","setvalue", uid,  'coin', bankinfo.coin)

    logStr = logStr .. " 存完后身上金币:" .. playerInfo.coin .. " 银行金币" .. bankinfo.coin .. ' aftercoin:' .. after_coin

    LOG_INFO(os.date("%Y-%m-%d %H:%M:%S", os.time()), " bank_record_log:", logStr)

    local orderid = os.date("%Y%m%d%H%M%S", os.time()) .. payId()
    local sql = string.format("insert into d_bank_record (uid,orderid,coin,before_coin, after_coin,type,gameid,deskid,create_time) values(%d,'%s', %.2f,%.2f,%.2f,%d, %d, %d, %d)", 
    uid,orderid,coin,beforecoin,after_coin, 1, gameid, deskid, os.time())
    LOG_INFO(os.date("%Y-%m-%d %H:%M:%S", os.time()), " sql:", sql)
    skynet.call(".mysqlpool", "lua", "execute", sql)

    handle.notifyCoinChanged(after_coin, playerInfo.diamond, -coin, 0, bankinfo.coin)

    retobj.bankcoin = bankinfo.coin
    retobj.coin     = after_coin
    retobj.token    = token
    return resp(retobj)
end

-------- 玩家游戏内携带密码取钱 --------
function bank.drawInGame(msg)
    LOG_INFO(os.date("%Y-%m-%d %H:%M:%S", os.time()), " bank_draw :", msg)
    local recvobj = cjson.decode(msg)
    local uid     = math.floor(recvobj.uid)
    local coin    = tonumber(recvobj.coin)
    local gameid  = recvobj.gameid or 0
    local deskid  = recvobj.deskid or 0 
    local passwd  = recvobj.passwd
    assert(passwd, uid .. "获取玩家的银行信息 缺少密码passwd " .. os.time())
    gameid = math.floor( gameid )
    deskid = math.floor(deskid)
    passwd = genPasswd(passwd)
    local retobj = {c = math.floor(recvobj.c), code = PDEFINE.RET.SUCCESS, spcode=0, uid=uid}
    local bankinfo = handle.dcCall("bank_dc","get", uid)
    if not bankinfo or bankinfo.passwd ~= passwd then
        retobj.spcode = PDEFINE.RET.ERROR.BANK_PASSWD_ERROR
        return resp(retobj)
    end

    if bankinfo.coin < coin then
        retobj.spcode = PDEFINE.RET.ERROR.BANK_COIN_NOT_ENOUGH
        return resp(retobj)
    end

    local playerInfo = handle.moduleCall("player","getPlayerInfo", uid)
    local logStr = "玩家游戏内取款[".. uid .."]现有金币".. playerInfo.coin  .."，银行金币".. bankinfo.coin .." 取钱"..coin
    local beforecoin = playerInfo.coin
    bankinfo.coin    = bankinfo.coin - coin

    local cointype = PDEFINE.ALTERCOINTAG.BANKUP
    local code, before_coin, after_coin = player_tool.funcAddCoin(uid, coin, "银行取款", cointype, 0, PDEFINE.POOL_TYPE.none, nil, nil)

    local token = genToken(uid, passwd)
    local up    = {}
    up["update_time"] = os.time()
    up["token"] = token
    up["coin"]  = bankinfo.coin
    handle.dcCall("bank_dc","setvalue", uid, up)

    logStr = logStr .. " 取钱后身上金币:" .. playerInfo.coin .. " 银行金币" .. bankinfo.coin
    LOG_INFO(os.date("%Y-%m-%d %H:%M:%S", os.time()), " bank_record_log:", logStr)
    local sql = string.format("insert into d_bank_record (uid,coin,before_coin, after_coin,type,gameid,deskid,create_time) values(%d, %.2f, %.2f, %.2f, %d, %d, %d, %d)", 
    uid, coin,beforecoin, after_coin, 2, gameid, deskid, os.time())
    skynet.call(".mysqlpool", "lua", "execute", sql)

    handle.addCoinInGame(coin)

    handle.notifyCoinChanged(after_coin, playerInfo.diamond, coin, 0)

    retobj.bankcoin = bankinfo.coin
    retobj.coin     = after_coin
    retobj.token    = token
    return resp(retobj)
end

-------- 玩家取钱 --------
function bank.draw(msg)
    LOG_INFO(os.date("%Y-%m-%d %H:%M:%S", os.time()), " bank_draw :", msg)
    local recvobj = cjson.decode(msg)
    local uid     = math.floor(recvobj.uid)
    local coin    = tonumber(recvobj.coin)
    local token   = recvobj.token --玩家此次登录的token
    assert(token, uid .. "获取玩家的银行信息 缺少token " .. os.time())
    local retobj = {c = math.floor(recvobj.c), code = PDEFINE.RET.SUCCESS, spcode=0, uid=uid}
    local bankinfo = handle.dcCall("bank_dc","get", uid)
    if not bankinfo or bankinfo.token ~= token then
        retobj.spcode = PDEFINE.RET.ERROR.BANK_TOKEN_ERROR
        return resp(retobj)
    end

    if bankinfo.coin < coin then
        retobj.spcode = PDEFINE.RET.ERROR.BANK_COIN_NOT_ENOUGH
        return resp(retobj)
    end

    local playerInfo = handle.moduleCall("player","getPlayerInfo", uid)

    local logStr = "玩家[".. uid .."]现有金币".. playerInfo.coin  .."，银行金币".. bankinfo.coin .." 取钱"..coin
    local beforecoin = playerInfo.coin
    bankinfo.coin    = bankinfo.coin - coin

    local cointype = PDEFINE.ALTERCOINTAG.BANKUP
    local code, before_coin, after_coin = player_tool.funcAddCoin(uid, coin, "银行取款", cointype, 0, PDEFINE.POOL_TYPE.none, nil, nil)

    handle.dcCall("bank_dc","setvalue", uid,  'coin', bankinfo.coin)

    logStr = logStr .. " 取钱后身上金币:" .. after_coin .. " 银行金币" .. bankinfo.coin
    LOG_INFO(os.date("%Y-%m-%d %H:%M:%S", os.time()), " bank_record_log:", logStr)
    local orderid = os.date("%Y%m%d%H%M%S", os.time()) .. payId()
    local sql = string.format("insert into d_bank_record (uid,orderid,coin,before_coin, after_coin,type,gameid,deskid,create_time) values(%d, '%s', %.2f, %.2f, %.2f, %d, %d, %d, %d)", 
                            uid, orderid,coin,beforecoin, after_coin, 2, 0, 0, os.time())
    skynet.call(".mysqlpool", "lua", "execute", sql)

    handle.notifyCoinChanged(after_coin, playerInfo.diamond, coin, 0)

    retobj.bankcoin = bankinfo.coin
    retobj.coin     = after_coin
    retobj.token    = token
    return resp(retobj)
end

-------- 玩家的银行记录 --------
function bank.record(msg)
    LOG_INFO(os.date("%Y-%m-%d %H:%M:%S", os.time()), " bank_record :", msg)
    local recvobj = cjson.decode(msg)
    local uid     = math.floor(recvobj.uid)
    local token   = recvobj.token --玩家此次登录的token
    assert(token, uid .. "获取玩家的银行信息 缺少token " .. os.time())

    local retobj = {c = math.floor(recvobj.c), code = PDEFINE.RET.SUCCESS, spcode=0, uid=uid, data={}}
    local bankinfo = handle.dcCall("bank_dc","get", uid)
    if not bankinfo or bankinfo.token ~= token then
        retobj.spcode = PDEFINE.RET.ERROR.BANK_TOKEN_ERROR
        return resp(retobj)
    end

    local sql = string.format("select * from d_bank_record where uid= %d order by id desc limit 30", uid)
    local rs = skynet.call(".mysqlpool", "lua", "execute", sql)
    if #rs > 0 then
        for _, row in pairs(rs) do
            local t = {}
            t["id"]   = row.id
            t["coin"] = row.coin
            t["type"] = row.type
            t["time"] = os.date("%Y-%m-%d %H:%M:%S", row.create_time) 
            table.insert(retobj.data, t)
        end
    end
    return resp(retobj)
end

-------- 玩家修改密码 --------
function bank.changepasswd(msg)
    LOG_INFO(os.date("%Y-%m-%d %H:%M:%S", os.time()), " bank_record :", msg)
    local recvobj = cjson.decode(msg)
    local uid     = math.floor(recvobj.uid)
    local passwd  = recvobj.passwd      --老密码
    local newpasswd = recvobj.newpasswd --新密码
    local token   = recvobj.token --玩家此次登录的token
    assert(token, uid .. "获取玩家的银行信息 缺少token " .. os.time())
    local retobj = {c = math.floor(recvobj.c), code = PDEFINE.RET.SUCCESS, spcode=0, uid=uid}
    local bankinfo = handle.dcCall("bank_dc","get", uid)
    if not bankinfo or bankinfo.token ~= token then
        retobj.spcode = PDEFINE.RET.ERROR.BANK_TOKEN_ERROR
        return resp(retobj)
    end

    --校验密码
    passwd = genPasswd(passwd)
    if bankinfo.passwd ~= passwd then
        retobj.spcode = PDEFINE.RET.ERROR.BANK_PASSWD_ERROR
        return resp(retobj)
    end

    local ret = bank.resetBankPasswd(uid, newpasswd)
    -- local newPassWd = genPasswd(newpasswd)
    -- local up = {}
    -- up["update_time"] = os.time()
    -- up["passwd"] = newPassWd
    -- handle.dcCall("bank_dc","setvalue", uid, up)
    return resp(retobj)
end


-------- 退出银行 --------
function bank.exit(msg)
    LOG_INFO(os.date("%Y-%m-%d %H:%M:%S", os.time()), " bank_record :", msg)
    local recvobj = cjson.decode(msg)
    local uid     = math.floor(recvobj.uid)
    local token   = recvobj.token --玩家此次登录的token
    assert(token, uid .. "获取玩家的银行信息 缺少token " .. os.time())
    local retobj = {c = math.floor(recvobj.c), code = PDEFINE.RET.SUCCESS, spcode=0, uid=uid}
    local bankinfo = handle.dcCall("bank_dc","get", uid)
    if not bankinfo or bankinfo.token ~= token then
        retobj.spcode = PDEFINE.RET.ERROR.BANK_TOKEN_ERROR
        return resp(retobj)
    end

    local up = {}
    up["update_time"] = os.time()
    up["token"] = ""
    handle.dcCall("bank_dc","setvalue", uid, up)
    return resp(retobj)
end

-------- 后台修改玩家的银行密码 --------
function bank.resetBankPasswd(uid, passwd)
    local newPassWd = genPasswd(passwd)
    local up = {}
    up["update_time"] = os.time()
    up["passwd"] = newPassWd
    handle.dcCall("bank_dc","setvalue", uid, up)
    return true
end

return bank