local login = require "snax.wslogin_server"
local crypt = require "crypt"
local skynet = require "skynet"
local cluster = require "cluster"
local api_service = require "api_service"
local cjson = require "cjson"
local DEBUG = skynet.getenv("DEBUG")  -- 是否是调试阶段
local BACKIP = skynet.getenv("backip")

cjson.encode_empty_table_as_object(false)
local MIN_RES_VERSION = 102030400 --res version
local MIN_APP_VERSION= 102090000 --apk version
local APP = tonumber(skynet.getenv("app")) or 1
local server = {
    host = "0.0.0.0",
    port = tonumber(skynet.getenv("port")),
    multilogin = false, -- disallow multilogin
    name = "login_master", --内部服务名.login_master
    instance = 8
}
local user_online = {} -- 记录玩家所登录的服务器
local webclient
local user_bind_key = 'd_user_bind:' --用户账号关系绑定的key前缀

local function getCountryByIp(ip, uid)
    if DEBUG then
        -- return 'eg'
        return nil
    end
    if nil == webclient then
        webclient = skynet.newservice("webreq")
    end
    local ok, body = skynet.call(webclient, "lua", "request", "http://127.0.0.1:8186/",{ip=ip,node="country"}, nil,false)
    if not ok then
        LOG_ERROR("req countryinfo err.", ip , uid)
        return nil
    end
    local resp
    ok, resp = pcall(jsondecode, body)
    if ok and resp.country ~= nil then
        return string.lower(resp.country.iso_code)
    end
    return nil
end

local function checkIP(ip)
    local ok, ret = pcall(api_service.callAPIMod, "checkIP", ip)
    if not ok then
        return false
    end

    local localReg = skynet.getenv("areacode")
    if localReg ~= ret.apirs.areacode then
        return false
    end
    return true
end
--只支持用.隔开的4位版本号，例如 1.0.0.4
local function getVersionNum(version)
    if nil == version then
        return 0
    end
    local resultStrList = {}
    string.gsub(
        version,
        "[^.]+",
        function(w)
            table.insert(resultStrList, w)
        end
    )

    local vernum = 0
    for k, item in pairs(resultStrList) do
        if k == 1 then
            vernum = vernum + item * 100000000
        elseif k == 2 then
            vernum = vernum + item * 1000000
        elseif k == 3 then
            vernum = vernum + item * 10000
        elseif k == 4 then
            vernum = vernum + item * 100
        end
    end

    return vernum
end

local function checkVersion(clientVer)
    LOG_DEBUG("checkVersion(clientVer)")
    local serverVer = skynet.call(".versionfile", "lua", "getVersion")
    LOG_DEBUG("serverVer:",serverVer)
    if nil == serverVer then --服务器没拿到版本，放过
	LOG_DEBUG("if nil == serverVer then")
        return true
    end

    local server_version = getVersionNum(serverVer) 
    local version      = string.gsub(clientVer, "v", "")
    local clientvernum = getVersionNum(version)
    LOG_DEBUG("server_version:",server_version)
    LOG_DEBUG("clientvernum:",clientvernum)
    if server_version < clientvernum then
        --服务端必须去更新
        local function t()
            skynet.call(".versionfile", "lua", "reload")
        end
        skynet.timeout(100, t)
    end
    LOG_DEBUG("function checkVersion(clientVer)")
    if server_version > clientvernum then
        return false
    end
    return true
end

--查看第3方绑定表中是否有
local function findUid(pid, pwd, reset)
    if not pid then
        return 0
    end
    local fields = {  -- 需要获取的字段
        'uid',
        'passwd',
    }
    local cacheData = do_redis({ "hmget", user_bind_key.. pid, table.unpack(fields)})
          cacheData = make_pairs_table(cacheData, fields)
    if table.empty(cacheData) then
        local sql = string.format("select * from d_user_bind where unionid='%s'", pid)
        local rs  = skynet.call(".mysqlpool", "lua", "execute", sql)
        if #rs <= 0 then
            return 0
        end
        addBindCache(rs[1].uid, rs[1].unionid, rs[1].nickname, rs[1].platform, rs[1].create_time, rs[1].passwd)
        cacheData = {
            uid = rs[1].uid,
            passwd = rs[1].passwd
        }
    end
    cacheData.uid = tonumber(cacheData.uid)
    if nil ~= pwd then
        local pwdmd5 = genPwd(cacheData.uid, pwd)
        if nil ~= reset then
            local sql2 = string.format("update d_user_bind set passwd='%s' where uid=%d and unionid='%s'", pwdmd5, cacheData.uid, pid)
            skynet.call(".dbsync", "lua", "sync", sql2)
            do_redis({"hset", user_bind_key .. pid, "passwd", pwdmd5})
            return cacheData.uid
        else
            if cacheData.passwd == pwdmd5 then
                return cacheData.uid
            else
                return PDEFINE_ERRCODE.ERROR.LOGIN_PASSWD_ERR --固定错误码
            end
        end
    end
    return cacheData.uid


    -- local sql = string.format("select * from d_user_bind where unionid='%s'", pid)
    -- local rs  = skynet.call(".mysqlpool", "lua", "execute", sql)
    -- if #rs > 0 then
    --     if nil ~= pwd then
    --         if nil ~= reset then
    --             local pwdmd5 = genPwd(rs[1].uid, pwd)
    --             local sql2 = string.format("update d_user_bind set passwd='%s' where uid=%d and unionid='%s'", pwdmd5, rs[1].uid, pid)
    --             skynet.call(".dbsync", "lua", "sync", sql2)
    --             return rs[1].uid
    --         else
    --             if rs[1].passwd == genPwd(rs[1].uid, pwd) then
    --                 return rs[1].uid
    --             else
    --                 return PDEFINE_ERRCODE.ERROR.LOGIN_PASSWD_ERR --固定错误码
    --             end
    --         end
    --     end
    --     return rs[1].uid
    -- end
    -- return 0
end

--记录登陆日志
local function addLoginLog(data, fcmToken, fbtoken)
    local now = os.time()
    local coin = 0
    if data.reg == 0 then --老用户才查询登录时的金币数
        local sql = string.format("select uid, coin from d_user where uid=%d", data.uid)
        local rs  = skynet.call(".mysqlpool", "lua", "execute", sql)
        if #rs == 1 then
            coin = tonumber(rs[1].coin or 0)
        end
    end

    local sql = string.format("INSERT INTO `d_user_login_log`(uid,login_type,create_time,channel,apkversion,resversion,extr,login_level,appid,ip,login_coin,ddid,device) VALUE(%d, %d, %d, '%s', '%s', '%s', '%s', %d, %d, '%s',%.2f,'%s','%s');", 
                data.uid, data.login_type, now, data.platform, data.av, data.v, data.extr, data.level, data.appid, data.ip, coin, data.client_uuid, data.device)
    skynet.send(".dbsync", "lua", "sync", sql)

    -- do_redis({"setex", "fcmtoken_" .. data.uid, fcmToken, 3600}) --记录1小时
    do_redis({"setex", "login_time" .. data.uid, now, 604800}) --记录登录时间
    if fbtoken ~= "" then
        do_redis({"setex", "fbtoken_" .. data.uid, fbtoken, 3600})
    end

    skynet.timeout(150, function ()
        local sql1 = string.format("select count(distinct uid) as t from d_user_login_log where ip='%s'", data.ip)
        local ret  = skynet.call(".mysqlpool", "lua", "execute", sql1)
        if #ret > 0 and nil ~= ret[1] then
            do_redis({"set", "login_ip:".. data.ip, ret[1].t})
        end

        local sql2 = string.format("select count(distinct uid) as t from d_user_login_log where ddid='%s'", data.client_uuid)
        local rs  = skynet.call(".mysqlpool", "lua", "execute", sql2)
        if #rs > 0 and nil ~= rs[1] then
            do_redis({"set", "login_ddid:".. data.client_uuid, rs[1].t})
        end
    end)
end

-- 是不是第3方登录
local function isLoginByOtherApp(logintype)
    local result = false
    --9 手机号 10 谷歌  11 苹果 12 FB 13 华为 
    if logintype==PDEFINE.LOGIN_TYPE.MOBILE or logintype == PDEFINE.LOGIN_TYPE.GOOGLE or logintype == PDEFINE.LOGIN_TYPE.APPLE or logintype == PDEFINE.LOGIN_TYPE.FB or logintype == PDEFINE.LOGIN_TYPE.HUAWEI then
        result = true
    end
    return result
end

local function addStatisLog(uid, act, ext)
    if ext == nil then
        ext = ""
    end
    local time = os.time()
    local tbname = getStatisticsTbName()
    local sql = string.format("insert into `%s`(uid,act,ts,ext) value(%d,'%s',%d,'%s')", tbname, uid, act, time, ext)
    do_mysql_queue(sql)
end

local function initUserTree(uid)
    local sql = string.format("insert into d_user_tree (ancestor_id, descendant_id, descendant_agent, ancestor_h) value(%d, %d, 0, 0)", uid, uid)
    do_mysql_queue(sql)
end

--检查设备信息
local function checkDevice(uid, para)
    if (para.otherpara.reset == nil or math.floor(para.otherpara.reset) == 0) and (para.otherpara.otp == nil) then
        local resver = getVersionNum(para.otherpara.v)
        local apkver = getVersionNum(para.otherpara.av)
        if resver > MIN_RES_VERSION and apkver > MIN_APP_VERSION then --客户端版本大于1.2.3.4才生效
            local sql = string.format("select * from d_user_bind where uid=%d and logintype in (%d,%d)", uid, PDEFINE.LOGIN_TYPE.GUEST, PDEFINE.LOGIN_TYPE.MOBILE)
            local rs  = skynet.call(".mysqlpool", "lua", "execute", sql)
            if #rs > 0 then
                for _, item in pairs(rs) do
                    if item.logintype == PDEFINE.LOGIN_TYPE.GUEST and item.unionid ~= para.client_uuid then --手机号登录的ddid和手机号注册时的ddid不一致
                        return PDEFINE_ERRCODE.ERROR.OTP_IS_EMPTY
                    end
                    if item.unionid == para.account and item.logintype == PDEFINE.LOGIN_TYPE.MOBILE and nil ~= para.otherpara.dinfo then --手机号登录的gsfid和simcardid 跟注册时不一致
                        local ok, data = pcall(jsondecode, para.otherpara.dinfo)
                        if ok and ((data.gid~=nil and item.gid~='' and data.gid~=item.gid) or (data.sid~=nil and item.sid~='' and data.sid~=item.sid)) then
                            return PDEFINE_ERRCODE.ERROR.OTP_IS_EMPTY
                        end
                        if item.email ~=nil and item.email ~='' and para.otherpara.client_uuid~=nil and item.email ~= para.otherpara.client_uuid then --新老设备号不为空
                            return PDEFINE_ERRCODE.ERROR.OTP_IS_EMPTY
                        end
                    end
                end
            end
        end
    end
end

-- 手机号登录，有验证码(不是重置密码)的情况下，更新设备信息
local function updateDeviceSimid(uid, logintype, para)
    if logintype == PDEFINE.LOGIN_TYPE.MOBILE and (para.otherpara.reset==nil or para.otherpara.reset==0) and para.otherpara.otp and para.otherpara.dinfo then
        local ok, dinfo = pcall(jsondecode, para.otherpara.dinfo)
        if ok and (dinfo.gid and dinfo.gid~='') and (dinfo.sid and dinfo.sid~='') then
            local sql = string.format("update d_user_bind set gid='%s',sid='%s',email='%s' where uid=%d and unionid='%s' and logintype=%d", dinfo.gid, dinfo.sid, para.client_uuid, uid,para.account,PDEFINE.LOGIN_TYPE.MOBILE)
            skynet.call(".dbsync", "lua", "sync", sql)
        end
    end 
end

local function genInvitCode(uid, parentCode)
    --TODO ：等待放开
    if APP ~= PDEFINE.APPID.RUMMYVIP then
        return ''
    end
    local prefix = 'GK1'
    if APP == PDEFINE.APPID.RUMMYVIP then
        prefix = 'VIP'
    end
    if not isempty(parentCode) then
        prefix = SubStringUTF8(parentCode, 1, 3)
    end

    local code = ''
    for i=1,1000 do
        local code = prefix .. randomInviteCode()
        local inPool = do_redis({"sismember", PDEFINE_REDISKEY.LOBBY.ALL_INVITE_CODES, code})
        if not inPool then
            do_redis({"sadd", PDEFINE_REDISKEY.LOBBY.ALL_INVITE_CODES, code})
            return code
        end
    end
    if isempty(code) then
        code = prefix .. uid
        do_redis({"sadd", PDEFINE_REDISKEY.LOBBY.ALL_INVITE_CODES, code})
    end
    return code
end

-- 登录认证
local function auth(para, logintype)
    LOG_DEBUG("para: ", para,"logintype: ", logintype)
    local ok, errorCode, auth_info
    local loginByOtherApp = isLoginByOtherApp(logintype)
    local client_uuid = para.client_uuid --客户端启动app打点的ddid
    local h5_uuid = para.h5_uuid --h5先生成的ddid
    if logintype == PDEFINE.LOGIN_TYPE.GUEST or loginByOtherApp then
        local uid
        if loginByOtherApp then
            uid = findUid(para.account, para.passwd, para.otherpara.reset)
            if logintype == PDEFINE.LOGIN_TYPE.MOBILE then --手机号登录
                if uid == 0 then
                    ok = true
                    errorCode = PDEFINE_ERRCODE.ERROR.ACCOUNT_NOT_FOUND
                elseif uid == PDEFINE_ERRCODE.ERROR.LOGIN_PASSWD_ERR then
                    --密码错误
                    ok = true
                    errorCode = PDEFINE_ERRCODE.ERROR.LOGIN_PASSWD_ERR
                end
                if errorCode then
                    return ok, errorCode, nil
                end
                errorCode = checkDevice(uid, para) --手机号登录(不是重置密码，没有带验证码的)
                if errorCode then
                    ok = true
                    return ok, errorCode, nil
                end
            end
        else
            if #h5_uuid > 1  then
                uid = findUid(h5_uuid)
            else
		LOG_DEBUG("#h5_uuid > 1: ")
                uid = findUid(client_uuid)
            end
        end
	LOG_DEBUG("uid: ",uid)
        para.ignoreauth = 0 --需要去第3方验证
        local system_token = para.otherpara.accessToken --上次登录，系统下发的token, 客户端以accessToken字段上传
        if system_token then
            local cache_uid = do_redis({"get", "t_"..system_token})
	    LOG_DEBUG("cache_uid: ", cache_uid)
            if cache_uid == uid then
                para.ignoreauth = 1 --不需要去第3方验证了
            end
        end
        local nickname = ""
        if uid > 0 then
            --登录
            para.uid = uid
            local tmp_logintype = para.logintype
             --google登录  -- 苹果登录 -- FB登录
            if loginByOtherApp then
                tmp_logintype = 10
            end
            local status = do_redis({"hget", "d_user:"..uid, "status"})
            status = tonumber(status or 0)
	    LOG_DEBUG("status: ", status)
            if status ~= 1 then
		LOG_DEBUG("yrp status ~= 1")
                return true, PDEFINE.RET.ERROR.PLAYER_NOT_FOUND
            end

            local ttl = do_redis({"ttl", PDEFINE_REDISKEY.YOU9API.KICK_USER..uid})
            if ttl > 0 then
                addStatisLog(uid, 'Login_login_fail3', client_uuid)
                return true, PDEFINE_ERRCODE.ERROR.USER_KICKED, {timeout=ttl}
            end

            local maxcnt = do_redis({"get", PDEFINE_REDISKEY.LOGIN.DDID_LOGIN_MAX_NUM})
            maxcnt = tonumber(maxcnt or 0)
            if maxcnt > 0 then --开启了同设备号最大登录数限制
                local inPool = do_redis({"sismember", PDEFINE_REDISKEY.LOGIN.DDID_LOGIN_POOL..client_uuid, uid})
                if not inPool then
                    local cnt = do_redis({"scard", PDEFINE_REDISKEY.LOGIN.DDID_LOGIN_POOL..client_uuid})
                    cnt = tonumber(cnt or 0)
                    if cnt >= maxcnt then
                        
                        addStatisLog(uid, 'Login_login_fail4', client_uuid)
                        return true, PDEFINE_ERRCODE.ERROR.DDI_ADDR_LIMIT
                    end
                end
            end
            do_redis({"sadd", PDEFINE_REDISKEY.LOGIN.DDID_LOGIN_POOL..client_uuid, uid})

            ok, errorCode, auth_info = pcall(api_service.callAPIMod, "auth", para, tmp_logintype)
            if errorCode == PDEFINE.RET.SUCCESS then
                addStatisLog(uid, 'Login_login_succ', client_uuid)
            else
                addStatisLog(uid, 'Login_login_fail', client_uuid)
            end
            local level = do_redis({"hget", "d_user:"..uid, 'level'}, uid)
            auth_info.level = tonumber(level)
            auth_info.reg = 0

            updateDeviceSimid(uid, logintype, para)
        else
            --是否关闭注册
            local register_off = do_redis({"get", PDEFINE_REDISKEY.LOGIN.REGISTER_OFF})
            if register_off then
                return true, PDEFINE_ERRCODE.ERROR.REGISTER_NOT_OPEN
            end

            local ip = para.ip or ''
            local maxcnt = do_redis({"get", PDEFINE_REDISKEY.LOGIN.SAME_IP_REGISTER_MAX_NUM})
            maxcnt = tonumber(maxcnt or 0)
            if maxcnt > 0 then
                if isempty(ip) then
                    addStatisLog(uid, 'IP_ADDR_EMPTY', client_uuid)
                    return true, PDEFINE_ERRCODE.ERROR.IP_ADDR_LIMIT
                end

                local ipPoolSize = do_redis({ "scard", PDEFINE_REDISKEY.LOGIN.SAME_IP_REGISTER_POOL})
                ipPoolSize = tonumber(ipPoolSize or 0)
                if ipPoolSize > 0 then
                    local inPool = do_redis({"sismember", PDEFINE_REDISKEY.LOGIN.SAME_IP_REGISTER_POOL, ip})
                    if inPool then --只有在ip池里的ip才判断
                        local cnt = do_redis({"zscore", PDEFINE_REDISKEY.LOGIN.IP_REGISTER_NUM, ip})
                        cnt = tonumber(cnt or 0)
                        if cnt > maxcnt then
                            addStatisLog(uid, 'IP_ADDR_POOL_LIMIT', client_uuid)
                            return true, PDEFINE_ERRCODE.ERROR.IP_ADDR_LIMIT
                        end
                    end
                else --没有设置IP池子，所有的ip都判断
                    local cnt = do_redis({"zscore", PDEFINE_REDISKEY.LOGIN.IP_REGISTER_NUM, ip})
                    cnt = tonumber(cnt or 0)
                    if cnt > maxcnt then
                        addStatisLog(uid, 'IP_ADDR_POOL_LIMIT2', client_uuid)
                        return true, PDEFINE_ERRCODE.ERROR.IP_ADDR_LIMIT
                    end
                end
            end

            --注册
            local tmp_logintype = 5 -- 游客注册
             --google注册  -- 苹果注册 -- FB注册
            if loginByOtherApp then
                tmp_logintype = 9
            end
            ok, errorCode, auth_info = pcall(api_service.callAPIMod, "auth", para, tmp_logintype)
            
            local pid = auth_info.pid
            auth_info.picid = 0
            auth_info.nickname = ""
            auth_info.reg = 1
            local picid = math.random(1,11)
            -- local usericon = "https://jp.inter.rummyslot.com/head/sys/" .. picid .. '.png'
            local usericon = picid
            local clientNick = client_uuid
            -- 游客登录 LoginExData为 1
            -- 其他登录方式固定格式: LoginExData为{nick:xxx, img:xxxx}
            local userOtherImg = nil
            if logintype ~= 1 then
                if nil ~= para.otherpara.LoginExData and nil ~=para.otherpara.LoginExData.nick and "" ~= para.otherpara.LoginExData.nick then
                    nickname = para.otherpara.LoginExData.nick
                    clientNick = para.account
                    pid = nickname
                end
                if nil ~= para.otherpara.LoginExData and nil ~=para.otherpara.LoginExData.img and "" ~= para.otherpara.LoginExData.img then
                    usericon = para.otherpara.LoginExData.img
                    userOtherImg = para.otherpara.LoginExData.img
                end
                if nickname == '' then
                    local ok , title = pcall(skynet.call, ".nickmgr", "lua", "getOne")
                    if ok then
                        nickname = title
                        pid = nickname
                    end
                end
            else
                local ok , title = pcall(skynet.call, ".nickmgr", "lua", "getOne")
                if ok then
                    nickname = title
                    if nickname == 'Player' then
                        nickname = 'Player' .. auth_info.uid
                    end
                else
                    nickname = 'Player' .. auth_info.uid
                end
                pid = nickname
                auth_info.picid = picid
                auth_info.nickname = nickname
            end
            if errorCode == PDEFINE.RET.SUCCESS then
                local kouuid = para.otherpara.kouuid or "" --kochava 打点uuid
                local isbindfb = (logintype == PDEFINE.LOGIN_TYPE.FB) and 1 or 0 --是否绑定fb
                local isbindgg = logintype == PDEFINE.LOGIN_TYPE.GOOGLE and 1 or 0 --是否绑定google

                do_redis({"zincrby", PDEFINE_REDISKEY.LOGIN.IP_REGISTER_NUM, 1, para.ip})
                do_redis({"sadd", PDEFINE_REDISKEY.LOGIN.DDID_LOGIN_POOL..client_uuid, auth_info.uid})
                --注册成功
                addStatisLog(auth_info.uid, 'Reg_succ', client_uuid)
                local nowtime = os.time()
                local key = PDEFINE_REDISKEY.LOBBY.REG_ONE_TIME .. auth_info.uid
                do_redis( {"setex", key, nowtime, 300}) --新用户协议1的时间

                addBindCache(auth_info.uid, clientNick, nickname, para.platform, nowtime)

                local gid, sid = '' , ''
                local ok , dinfo = pcall(jsondecode, para.otherpara.dinfo)
                if ok and dinfo then
                    gid = dinfo.gid
                    sid = dinfo.sid
                end

                local sql = string.format("INSERT INTO `d_user_bind`(uid,unionid,nickname,sex,email,platform,create_time,gid,sid,logintype) VALUE(%d, '%s', '%s', %d, '%s', %d, %d,'%s','%s',%d);", 
                    auth_info.uid,
                    clientNick,
                    nickname,
                    0,
                    client_uuid,
                    para.platform,
                    nowtime,
                    gid,
                    sid,
                    logintype
                )
                skynet.call(".dbsync", "lua", "sync", sql)
                initUserTree(auth_info.uid)
                local inviteCode = genInvitCode(auth_info.uid, para.otherpara.code)
                local jsondata = {
                    pid = pid,
                    uid = auth_info.uid,
                    coin = 0,
                    nickname = nickname,
                    usericon = usericon,
                    appid = 0,
                    kouuid = kouuid,
                    isbindgg = isbindgg,
                    isbindfb = isbindfb,
                    platform = para.platform,
                    from_channel = logintype,
                    fbicon='',
                    device = para.device or '',
                    client_uuid = client_uuid or '',
                    ip = para.ip or '',
                    code = inviteCode, --邀请码
                }
                if isbindfb == 1 then
                    jsondata.fbicon = jsondata.usericon
                end
                -- if DEBUG then
                --     jsondata['coin'] = 2000000000
                -- end
                if logintype == PDEFINE.LOGIN_TYPE.HUAWEI then
                    jsondata.appid = 6
                end
                pcall(cluster.call, "master", ".userCenter", "registeruser", jsondata)
                if userOtherImg ~= nil then --FB
                    do_redis_withprename("", {"lpush", PDEFINE_REDISKEY.QUEUE.USER_BIND, string.format("%s|%s|fb2", auth_info.uid, userOtherImg)})
                end
            else 
                uid = auth_info.uid or 0
                addStatisLog(uid, 'Reg_fail', client_uuid)
            end
            auth_info.level = 1 --新注册用户等级为1
        end
        
        if #h5_uuid > 1 then --从H5生成了uuid后，启动了APP(创建新账号), 绑定H5和APP为同一个uid
            if findUid(client_uuid) == 0 then
                local sql = string.format("INSERT INTO `d_user_bind`(uid,unionid,nickname,platform,create_time) VALUE(%d, '%s', '%s', %d, %d)", 
                    auth_info.uid,
                    client_uuid,
                    nickname,
                    para.platform,
                    os.time())
                skynet.send(".dbsync", "lua", "sync", sql)
            end
        end
    else
        ok, errorCode, auth_info = pcall(api_service.callAPIMod, "auth", para)
        if errorCode == PDEFINE.RET.SUCCESS then
            addStatisLog(auth_info.uid, 'Login_login_succ2', client_uuid)
        else
            addStatisLog(0, 'Login_login_fail2', client_uuid)
        end
    end
    return ok, errorCode, auth_info
end

local CMD = {}

local function getIP(addr)
    local ip = ""
    if addr ~= nil then
        local addrarr = string.split(addr, ":")
        if #addrarr > 0 and #addrarr == 2 then
            ip = addrarr[1]
        else
            ip = addr -- ipv6
        end
    end
    return ip
end
-- 打点,配合启动分析
local function recordLog(token, ip, platform)
    local uid = token.uid or 0
    local act = "msg1"
    local ts = os.time()
    local ddid = token.client_uuid or ""
    local appid = token.appid or 0
    local appver = token.v or ""

    local tbname = getDAppLogTbName()
    local sql = string.format("INSERT INTO `%s`(uid,act,ts,ddid,os,appid,appver,ip,create_time) VALUE(%d, '%s', %d, '%s', %d, %d, '%s', INET_ATON('%s'), %d);", 
               tbname, uid, act, ts, ddid, platform, appid, appver, ip, ts)
    skynet.send(".dbsync", "lua", "sync", sql)
end

local function addErrLog(token, ip, platform, cat, errCode)
    errCode = errCode or 0
    local ddid = token.client_uuid or ""
    local sql = string.format("INSERT INTO `d_log_msgoneerr`(cat,create_time,platform,ip,msg,errcode,ddid) VALUE(%d, %d, %d, INET_ATON('%s'), '%s', %d,'%s')", 
                cat, os.time(), platform, ip, cjson.encode(token), errCode, ddid)
    do_mysql_queue(sql)
end

local function forbidPhone(phone, pattern_list) 
    if table.size(pattern_list) > 0 then
        for _, pattern in pairs(pattern_list) do
            if string.match(phone, pattern) then
                return true            
            end
        end
    end
    return false
end

-- 检测登录协议中的型号和包名信息
local function checkPhoneDevice(phone, bundleid) 
    if isempty(phone) or isempty(bundleid) then
        LOG_DEBUG('phone or bundleid is empty:', phone, bundleid)
        return PDEFINE.LOGIN_ERROR.EMPTY_PHONE_OR_DEVICE
    end
    local ok, row = pcall(cluster.call, "master", ".configmgr", "get", "login_ban_params")
    local params = {}
    if ok and type(row) == 'table' then
        local json_ok
        json_ok, params = pcall(jsondecode, row['v'])
    end
    if params.bundleid_flag and params.bundleid_flag == 1 then
        if not table.contain(params.bundleid , bundleid) then
            LOG_DEBUG('bundleid not in list:', bundleid)
            return PDEFINE.LOGIN_ERROR.DEVICE
        end 
    end
    if params.phone_model_pattern_flag and params.phone_model_pattern_flag == 1 then
        if forbidPhone(phone, params.phone_model_pattern_list) then
            LOG_DEBUG('phone match  banlist:', phone)
            return PDEFINE.LOGIN_ERROR.PHONE
        end
    end
    return 0
end

-- 大于1.2.3.4的资源版本后，必须传dinfo字段，里面是json
local function checkSimcardIdEmpty(token)
    local resver = getVersionNum(token.v)
    local apkver = getVersionNum(token.av)
    LOG_DEBUG('checkSimcardIdEmpty resver:', resver, ' token.v:', token.v, ' apkver:', apkver)
    if resver > MIN_RES_VERSION and apkver > MIN_APP_VERSION then
        if token.dinfo == nil then
            return PDEFINE.RET.ERROR.DINFO_IS_NULL
        end
        local ok, dinfo = pcall(jsondecode, token.dinfo)
        if not ok or not dinfo then
            return PDEFINE.RET.ERROR.DINFO_IS_NULL
        end
        if nil == dinfo.gid or '' == dinfo.gid then
            return PDEFINE.RET.ERROR.DINFO_GID_NULL
        end
        if nil == dinfo.sid or '' == dinfo.sid then
            return PDEFINE.RET.ERROR.DINFO_SID_NULL
        end
    end
    return PDEFINE.RET.SUCCESS
end

function CMD.auth_handler(token, addr)
    local appversion = token.av or "" --app version
    local resversion = token.v or "" --resource version, 客户端版本低于此值会提示更新
    local client_uuid = token.client_uuid or "" --设备id

    local ip = getIP(addr)
    local ok, errcode = pcall(cluster.call, "master", ".loginmaster", "checkServerState", {ip = ip, uid=0, client_uuid=client_uuid})
    if not ok then
        return PDEFINE.RET.ERROR.REGISTER_FAIL
    end
    if errcode ~= PDEFINE.RET.SUCCESS then
        return errcode
    end

    local channel = string.lower(token.platform or "") -- iOS,Android,Windows,Marmalade,Linux,Bada,Blackberry,OS X
    local platform = PDEFINE.PLATFORM.WEB --其他web
    if channel == "ios" then
        platform = PDEFINE.PLATFORM.IOS
    elseif channel == "android" then
        platform = PDEFINE.PLATFORM.Android
    else
        LOG_INFO(token.user .. "玩家登录渠道未知:", channel)
    end
    recordLog(token, ip, platform)
    LOG_DEBUG("CMD.auth_handler(token, addr)1")
    if not checkVersion(resversion) and (channel == "ios" or channel == "android") then
	LOG_DEBUG("CMD.auth_handler(token, addr)1.1")
        addErrLog(token, ip, platform, PDEFINE.LOGIN_ERROR.VERSION)
        return PDEFINE.RET.ERROR.RES_VERSION_ERR
    end
    -- errcode = checkSimcardIdEmpty(token)
    -- if errcode ~= PDEFINE.RET.SUCCESS then
        -- return errcode
    -- end
    LOG_DEBUG("CMD.auth_handler(token, addr)2")
    local phone = token.phone or ""
    local bundleid = token.bundleid or ""
    local flag =  checkPhoneDevice(phone, bundleid)
    if flag ~= 0 then
        addErrLog(token, ip, platform, flag)
        return PDEFINE.RET.ERROR.PHONE_LIMIT
    end
    LOG_DEBUG("CMD.auth_handler(token, addr)3")
    local fcmToken = token.fmcToken or "" --google fcm推送token
    local fbtoken = token.accessToken or "" --fb授权登录token
    local passwd = token.passwd or ""
    local fbid = token.fbid or ""
    local appid = token.app or 0 --同个App下区分不同开发者账号，展示不同的苹果IAP内购商品使用
    appid = math.floor(appid)
    
    local h5_uuid = token.h5_uuid or ""  --H5版本生成的uuid
    
    local login_token = token.token --玩家身上的token app=4使用
    local language = token.language --1: 阿拉伯  2：英文
    local deviceToken = token.deviceToken  --苹果设备id
    local bundleid = token.bundleid  --应用id，用来区分支付的时候下发哪个productid字段
    if nil ~= bundleid and "" ~= bundleid then
        bundleid = string.lower(bundleid)
    end

    local user, version, logintype = token.user, token.v, tonumber(token.t)
    if user ~= nil then
        user = string.gsub(user, " ", "")
    end
    if logintype == PDEFINE.LOGIN_TYPE.MOBILE then
	LOG_DEBUG("CMD.auth_handler(token, addr)4")
        if token.reset ~= nil and math.floor(token.reset) == 1 then
            local cacheKey = string.format("code:%s", user)
            local otpCache = do_redis({"get", cacheKey})
            if otpCache ~= token.otp then
                addErrLog(token, ip, platform, PDEFINE.LOGIN_ERROR.OPTCODE)
                return PDEFINE_ERRCODE.ERROR.OTP_IS_ERR
            end
	    LOG_DEBUG("CMD.auth_handler(token, addr)5")
        elseif token.otp ~= nil then
            local cacheKey = string.format("code:%s", user)
            local otpCache = do_redis({"get", cacheKey})
            if isempty(token.otp) or otpCache ~= token.otp then
                addErrLog(token, ip, platform, PDEFINE.LOGIN_ERROR.OPTCODEFail)
                return PDEFINE_ERRCODE.ERROR.OTP_IS_ERR
            end
	    LOG_DEBUG("CMD.auth_handler(token, addr)6")
        end
    end 
    
    LOG_INFO(
        string.format(
            "Auth_handler user %s version %s logintype %d token.client_uuid %s login_token %s",
            token.user,
            token.v,
            tonumber(token.t),
            token.client_uuid,
            login_token
        )
    )
    token.LoginExData = token.loginExData or token.LoginExData --兼容客户端可能传错的情况
    local para = {
        login_token = login_token,
        client_uuid = client_uuid,
        h5_uuid = h5_uuid,
        ip = ip,
        account = user,
        passwd = passwd,
        logintype = logintype,
        otherpara = token,
        platform = platform,
        device = phone,
    }
    local ok, errorCode, auth_info = auth(para, logintype)
    LOG_DEBUG("errorCode = ", errorCode, " ok = ", ok)
    if not ok then
        addErrLog(token, ip, platform, PDEFINE.LOGIN_ERROR.NOTOK)
        return PDEFINE.RET.ERROR.CALL_FAIL
    end
    if errorCode ~= PDEFINE.RET.SUCCESS then
        addErrLog(token, ip, platform, PDEFINE.LOGIN_ERROR.NOTSUCC, errorCode)
        return errorCode
    end
    local log = {
        uid = auth_info.uid,
        login_type = logintype,
        platform = channel,
        av = appversion,
        v = resversion,
        extr = '',
        ip = ip,
        appid=appid,
        level = auth_info.level or 1, --登录时的等级
        reg = auth_info.reg or 0,
        client_uuid = client_uuid or '',
        device = phone,
    }
    addLoginLog(log, fcmToken, fbtoken)
    local uid = auth_info.uid
    -- if uid ~= nil then
    --     local last = user_online[uid]
    --     LOG_DEBUG('user last login info:', last, uid)
    --     if last then
    --         LOG_ERROR("user %d is already online", uid, " kick kick kick", client_uuid)
    --         local ok = pcall(cluster.call, last.server, last.address, "kick", uid, last.subid, client_uuid.."")
    --         if ok then
    --             user_online[uid] = nil
    --         end
    --     end
    -- end

    local userinfo = {}
    userinfo.uid = uid
    userinfo.version = version
    userinfo.unionid = auth_info.unionid
    userinfo.playercoin = auth_info.playercoin
    userinfo.access_token = auth_info.access_token
    userinfo.language = language
    userinfo.client_uuid = client_uuid
    userinfo.account = auth_info.account
    userinfo.ip = addr
    userinfo.vip = auth_info.vip
    userinfo.platform = platform
    userinfo.deviceToken = deviceToken
    userinfo.logintype = logintype
    
    do_redis({"setex", "utoken_" ..uid, userinfo.access_token, 3*86400})
    do_redis({"setex", "appid_" .. uid, appid, 3*86400})
    -- 新用户才会有昵称
    local tmp = {ip = ip, logintype=logintype, platform=platform, appid=appid, nickname=auth_info.nickname, picid = auth_info.picid, client_uuid = client_uuid, bundleid= bundleid}
    -- local iso_code = getCountryByIp(addr, uid)
    -- if iso_code then
    --     tmp.iso_code = iso_code --根据ip存储国家iso_code
    -- end
    LOG_DEBUG("auth end ", userinfo, ' tmp:', tmp)
    pcall(cluster.send, "master", ".userCenter", "addOnlineData", uid, tmp)
    return errorCode, userinfo
end

--[[
认证token并且返回登录的游戏服务地址和游戏内的玩家id
如果验证不能通过，可以通过 error 抛出异常。如果验证通过，需要返回用户希望进入的登陆点以及用户名。（登陆点可以是包含在token内由用户自行决定,也可以在这里实现一个负载均衡器来选择）
token包含sdk提供的用户标识user

400 Bad Request --握手失败
401 Unauthorized --自定义的 auth_handler 不认可 token
403 Forbidden --自定义的 login_handler 执行失败
406 Not Acceptable --该用户已经在登陆中。（只发生在 multilogin 关闭时）
]]
function server.auth_handler(token, addr)
    return CMD.auth_handler(token, addr)
end

function CMD.login_handler(secret, bwss, userinfo, clientapp)
    local uid = userinfo.uid
    local access_token = userinfo.access_token
    local clientid = userinfo.client_uuid

    --获取server
    --[[
    server={
            name=xx,
            status=xx,
            tag=xx,
            freshtime=xx，
            serverinfo = {
                "address":
                "netinfo":"xxx:xx"
            }
        }
    ]]
    local ok, errcode, server = pcall(cluster.call, "master", ".loginmaster", "balance", userinfo)
    if not ok then
        return PDEFINE.RET.ERROR.REGISTER_FAIL
    end
    if errcode ~= PDEFINE.RET.SUCCESS then
        return errcode
    end

    LOG_INFO(
        string.format(
            "login_handler %s@%s@%s is login, secret is %s",
            uid,
            server.name,
            server.serverinfo.address,
            crypt.hexencode(secret)
        )
    )
    -- if server_list[server] == nil then
    --     return PDEFINE.RET.ERROR.SERVER_NOTREADY
    -- end
    -- local gameserver = assert(server_list[server], "Unknown server")
    -- local clientid = do_redis({"get", "client_uuid_"..uid})

    local last = user_online[uid]
    LOG_DEBUG("login_handler", uid)
    if last and last.clientuuid ~= clientid then
    --如果是一个设备 可以踢号
        LOG_ERROR("user %d is already online", uid, " kick kick kick", clientid)
        local ok = pcall(cluster.call, last.server, last.address, "kick", uid, last.subid, clientid)
        if ok then
           user_online[uid] = nil
        end
        LOG_INFO("kick uuid ", uid, " from cache:", clientid, 'user_online[uid]:', user_online[uid])
    end

    local token = access_token
    do_redis({"set", "t_" .. token, uid}) --保存系统token和uid 对应关系

    local ok, errcode, subid = pcall(cluster.call, server.name, server.serverinfo.address, "login", userinfo, secret)
    LOG_INFO(string.format("node login result %s, subid is %s", ok, subid))
    if not ok then
        LOG_ERROR(string.format("uid:%d login agent faield, %s, token:%s", uid, secret, token))
        return PDEFINE.RET.ERROR.CALL_FAIL
    end

    if errcode ~= PDEFINE.RET.SUCCESS then
        LOG_ERROR(string.format("uid:%d login agent faield, %s, token:%s, err:%s", uid, secret, token, errcode))
        return errcode
    end

    if type(subid) == "string" then
        --肯定执行错误了
        LOG_ERROR(string.format("uid:%d login node faield, %s, token:%s, subid:%s", uid, secret, token, subid))
    else
        user_online[uid] = {
            address = server.serverinfo.address,
            subid = subid,
            server = server.name,
            clientuuid = clientid
        }
        LOG_DEBUG("user is login, useronline data is", uid, user_online[uid])
    end

    --wss处理
    local servernetinfo = server.serverinfo.netinfo
    local tmpserverinfo = servernetinfo
    if bwss == 1 and not BACKIP then
        local tmpserver = string.split(servernetinfo, ":")
        tmpserverinfo = tmpserver[1]
    end
    if clientapp == 10 or clientapp == 100 then
        --内网穿透测试包
        local tmpserver = string.split(servernetinfo, ":")
        tmpserverinfo = '116.62.136.51:'..tmpserver[2]
    end
    servernetinfo = tmpserverinfo

    LOG_INFO("login_handler subid:", subid, "servernetinfo:", servernetinfo, "server.name:", server.name)
    return PDEFINE.RET.SUCCESS, subid, servernetinfo, server.name
end
--[[
 登录操作，通知具体游戏服，登录状态简单管理
 处理当用户已经验证通过后，该如何通知具体的登陆点（server ）。框架会交给你用户名（uid）和已经安全交换到的通讯密钥。你需要把它们交给登陆点，并得到确认（等待登陆点准备好后）才可以返回。
]]
function server.login_handler(secret, bwss, userinfo, clientapp)
    return CMD.login_handler(secret, bwss, userinfo, clientapp)
end

--检测玩家是否在线
function CMD.useronline(uid)
    LOG_INFO("user_online uid:", uid, "v:", user_online[uid])
    local last = user_online[uid]
    if last then
        return true
    end
    return false
end

function CMD.logout(uid, subid)
    LOG_DEBUG("uid:", uid, " node 服 通知 登录服要退出了 uid:", uid)
    local u = user_online[uid]
    if u then
        LOG_INFO(string.format("%s@%s is logout", uid, u.server))
        user_online[uid] = nil
    end
end

function CMD.onserverchange(server)
    LOG_DEBUG("onserverchange server:", server)
    --[[
        server的结构
        server={
            name=xx,
            status=xx,
            tag=xx,
            freshtime=xx，
            serverinfo = {}
        }
    ]]
    if server.tag == "api" then
    --暂时没需求
    end
end

--系统启动完成后的通知
function CMD.start_init(...)
    local callback = {}
    callback.method = "onserverchange"
    callback.address = skynet.self()

    skynet.call(".servernode", "lua", "regEventFun", PDEFINE.SERVER_EVENTS.changestatus, callback)
end

--实现command_handler，必须要实现，用来处理lua消息
function server.command_handler(command, ...)
    LOG_DEBUG("get command %s", command)
    local f = assert(CMD[command])
    return f(...)
end

login(server)
