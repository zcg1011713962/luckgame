--约定数据结构
--[[
gameinfo_para = {
    gameid = xx, --游戏id
    deskid = xx, --桌子id
    subgameid = xx, --子游戏id
    isjp = 0/1, --是否需要开JP奖 0表示不需要开jp，1表示需要jp
    deskuuid = xx, --桌子唯一id
    platforminfo = {
        platform = xx, --平台id
        platform_name = xx, --平台名称
        gamelog_tp = xx, --第三方平台的日志数据
    },
    roundinfo = {
        bet = xx, --下注
        win = xx, --赢钱
        result = xx, --游戏结果
        event_type = xx, PDEFINE.POOLEVENT_TYPE
        event_id = xx, --eventid api端传过来的参数
    }
}

poolround_para = {
    uniid = xx, --唯一id
    pooltype = xx, --pooltype  PDEFINE.POOL_TYPE
    poolround_id = xx, --pr的唯一id
}

altercoin_para = {
    altercoin_id = xx, --修改金币的唯一id
    before_coin = xx, --修改之前的金币
    alter_coin = xx, --修改量
    after_acoin = xx, --修改之后的金币数量
    type = xx, --修改金币的类型 PDEFINE.ALTERCOINTAG
    desc = xx, --修改日志
}

]]

local skynet = require "skynet"
require "skynet.manager"
local httpc = require "http.httpc"
local cjson = require "cjson"
local jsondecode = cjson.decode

local cluster = require "cluster"
local md5     = require "md5"
local CMD = {}
local webclient

local url_head = "http://192.168.50.124/game/"

local queuedata = 
{
    ["coins_player"] = {tablename="q_coins_log", rediskey="{bigbang}:logs:coins:player", initstate = 1},--玩家coin流水
    ["game_pool"] = {tablename="q_pool_log", rediskey="{bigbang}:logs:gpool", initstate = 0},--彩池变化
    ["game_log"] = {tablename="q_gplay_log", rediskey="{bigbang}:logs:gplay", initstate = 1},--游戏日志
    ["poolevent_log"] = {tablename="q_poolevent_log", rediskey="{bigbang}:logs:gevent", initstate = 0},--彩池事件日志
}

local gamesetting_rediskey = "{bigbang}:bet_min_max"

local worker_index = ...
local TIME_OUT  = 3000
--local REDISKEY_NotMapTable = {PDEFINE.REDISKEY.YOU9API.bigbangreward}
local REDISKEY_NotMapTable = {"bigbangreward"}
local LOGIC = {}
local DAYSECOND = 24*3600

-- 错误码
local APIRET =
{
    [200] = PDEFINE.RET.SUCCESS,              -- 成功
    [300] = PDEFINE.RET.UNDEFINE,             -- 未定义错误
    --缺少必要参数
    [2001] = PDEFINE.RET.ERROR.PARAM_NIL,
    --参数不能为空值
    [2002] = PDEFINE.RET.ERROR.PARAM_NIL,
    --非法参数值
    [2003] = PDEFINE.RET.ERROR.PARAM_ILLEGAL,
    --token无效
    [1001] = PDEFINE.RET.ERROR.TOKEN_ERR,
    --没有权限
    [1002] = PDEFINE.RET.ERROR.BAD_REQUEST,
    --账号密码不匹配
    [3001] = PDEFINE.RET.ERROR.LOGIN_FAIL,
    --COIN余额不足
    [3002] = PDEFINE.RET.ERROR.BET_COIN_NOT_ENOUGH,
    --子账号禁止登陆
    [3003] = PDEFINE.RET.ERROR.FORBIDDEN_LOGIN,
    --用户名已经存在
    [3004] = PDEFINE.RET.ERROR.NAME_ALREADY,
    --账号被短暂锁定
    [30050001] = PDEFINE.RET.ERROR.ACCOUNT_ERROR,
    --账号被短暂锁定2S
    [30050021] = PDEFINE.RET.ERROR.ACCOUNT_ERROR,
    --账号被短暂锁定5S
    [30050051] = PDEFINE.RET.ERROR.ACCOUNT_ERROR_5,
    --账号被短暂锁定 10S
    [30050101] = PDEFINE.RET.ERROR.ACCOUNT_ERROR_10,
    --账号被短暂锁定 20S
    [30050201] = PDEFINE.RET.ERROR.ACCOUNT_ERROR_20,
    --账号被短暂锁定10fenz
    [30056001] = PDEFINE.RET.ERROR.ACCOUNT_ERROR_600,
    --账号禁止在该区域登录
    [3006] = PDEFINE.RET.ERROR.FORBIDDEN_AREA_LOGIN,
    --违反业务规定
    [4001] = PDEFINE.RET.ERROR.PARAM_ILLEGAL,
    --业务游戏结算失败
    [4002] = PDEFINE.RET.ERROR.FINISHGAME_ERR,
    --系统错误-数据库-更新
    [9010] = PDEFINE.RET.ERROR.LOGIN_FAIL,
    --redis系统参数未初始化
    [9021] = PDEFINE.RET.ERROR.CALL_FAIL,
    --redis池子未初始化
    [9022] = PDEFINE.RET.ERROR.CALL_FAIL,
    --redispoolnormal普通池余额不足
    [9023] = PDEFINE.RET.ERROR.POOL_NOMAL_NOT_ENOUGH,

    --注册，账号已经存在
    [160001] = PDEFINE.RET.ERROR.ACCOUNT_HAD_EXIST,
    --注册，邮箱已存在
    [160002] = PDEFINE.RET.ERROR.EMAIL_HAD_EXIST,
    --注册，验证码不存在
    [160003] = PDEFINE.RET.ERROR.INVAlID_CODE,
    --注册，验证码过期或不存在
    [160005] = PDEFINE.RET.ERROR.INVAlID_CODE_FAIL,
    --当前没有可提现收益
    [160012] = PDEFINE.RET.ERROR.BALANCE_NOT_ENOUG,
    --支付密码不正确
    [160011] = PDEFINE.RET.ERROR.PASSWD_ERROR 
}

local function callDbSync(sql)
    skynet.call(".dbsync" .. worker_index, "lua", "sync", sql)
end

local function genQueueLogId(queuedata)
    local uniqueid
    if queuedata == nil or queuedata.tablename == nil then
        LOG_ERROR("genQueueLogId queuedata err.", queuedata)
        return false
    end
    uniqueid = do_redis({'incr', PDEFINE.CACHE_LOG_KEY[queuedata.tablename]})
    return uniqueid
end

--刷新版本号(从配置表中获取版本号的url地址，解析出最新版本号，保存到配置表中)
--@param prefixkey 缓存key的前缀
function CMD.reflush(prefixkey)
    local ok, res = pcall(cluster.call, "master", ".configmgr", "get", prefixkey .. "_version_url")
    if not ok then 
        return true
    end
    local url = res.v or nil
    if not url then 
        return true
    end
    local ok, body, resp
    ok, body = skynet.call(webclient, "lua", "request", url, nil, nil, false, TIME_OUT) --get 请求
    if not ok then
        LOG_ERROR("flush version error1!" , url)
        return PDEFINE.RET.ERROR.REGISTER_FAIL
    end
    ok, resp = pcall(jsondecode,body)
    if not ok then
        LOG_ERROR("flush version error2!" , url)
        return PDEFINE.RET.ERROR.REGISTER_FAIL
    end

    --更新db
    local sql = string.format("update s_config set v='%s' where k='%s'", resp.version, 'version')
    skynet.call(".mysqlpool", "lua", "execute", sql)

    --更新内存
    pcall(cluster.call, "master", ".configmgr", "reload", "version")
    return PDEFINE.RET.SUCCESS
end

--[[
    传参
    para={
        login_token=xxx,
        client_uuid=xxx,
        ip=xxx,
        account=xxx,
        passwd=xxx,
        logintype=xxx
    }
    返回值
    errorCode, auth_info = {
        uid=xxx,
        unionid=xxx,
        playercoin=xxx,
        access_token=xxx,
        account=xxx
    }
]]
function CMD.auth(para, tmp_logintype)
    local tmploginType
    if tmp_logintype ~= nil then
        tmploginType = tmp_logintype
    else
        tmploginType = tonumber(para.logintype)
    end
    LOG_DEBUG("tmploginType:", tmploginType)
    if tmploginType == 1 and para.otherpara.LoginExData == 1 then  --游客登录
        return LOGIC.auth_yk(para)
    elseif tmploginType == 5 then --游客注册
        return LOGIC.registeryk(para)
    elseif tmploginType == 6 or tmploginType == 1 then
        return LOGIC.auth_oldtoken(para)
    elseif tmploginType == 4 then --账号登录
        return LOGIC.auth_normal(para)
    elseif tmploginType == 7 then
        return LOGIC.auth_token(para)
    elseif tmploginType == 9 then --google注册  apple注册  fb注册 huawei注册
        return LOGIC.register_otherApp(para)
    elseif tmploginType == 10 or tmploginType == 11 or tmploginType == 12 or tmploginType == 13 then --google登录 apple登录  fb登录 huawei登录
        return LOGIC.auth_yk(para)
    end

    return PDEFINE.RET.ERROR.PARAM_ILLEGAL, nil
end

--账号注册(推广系统)
--[[
   bb推广员账号注册，先注册账号，注册完毕后直接获取登录信息再返回
   传参
    para={
        login_token=xxx,
        client_uuid=xxx,
        ip=xxx,
        account=xxx, --账号
        passwd=xxx,  --密码
        email = xxxx, --邮箱
        invitecode = xxx, --邀请码
        logintype=xxx
    }
    返回值
    errorCode, auth_info = {
        uid=xxx,
        unionid=xxx,
        playercoin=xxx,
        access_token=xxx,
        account=xxx
    }
]]
function LOGIC.register(para)
    local account = para.account
    if account ~= nil then
        account = string.gsub(account, " ", "")
    end

    local email  = para.otherpara.email or "" --邮箱
    local pcode  = para.otherpara.invitecode or "" --邀请码
    local passwd = para.passwd or ""

    if account == nil or #tostring(account) < 6 then 
        LOG_ERROR("you9apisdk register failed,check u para! account: ", account)
        return PDEFINE.RET.ERROR.ACCOUNT_TOO_SHORT
    end
    if  passwd == nil or #tostring(passwd) == 0 then 
        LOG_ERROR("you9apisdk register failed,check u para! passwd: ", passwd)
        return PDEFINE.RET.ERROR.PASSWD_IS_EMPTY
    end
    if  email == nil or #tostring(email) == 0 then 
        LOG_ERROR("you9apisdk register failed,check u para! email: ", email)
        return PDEFINE.RET.ERROR.EMAIL_IS_EMPTY
    end
    if  pcode == nil or #tostring(pcode) ~= 8 then
        LOG_ERROR("you9apisdk register failed,check u para! pcode:", pcode)
        return PDEFINE.RET.ERROR.PCODE_IS_ERROR
    end

    local ip = para.ip 
    local client_uuid = para.client_uuid or ""

    local reg_param = {
        username = account,
        pwdmd5 = md5.sumhexa(passwd),
        email = email,
        pcode = pcode
    }
    local ok, rs = LOGIC.register2Api(reg_param)
    if ok ~= PDEFINE.RET.SUCCESS then
        LOG_ERROR("you9apisdk getAccessToken failed.ret:",ok)
        return ok, nil
    end
    local ret, rs = LOGIC.getaccesstoken(account, passwd, para.ip, client_uuid)
    if ret ~= PDEFINE.RET.SUCCESS then
        LOG_ERROR("you9apisdk getAccessToken failed.ret:",ret)
        return ret, nil
    end

    local ret, userinfo = LOGIC.getuserinfo(user, rs.token)
    if ret ~= PDEFINE.RET.SUCCESS then
        LOG_ERROR("you9apisdk getUserInfo failed.ret:",ret)
        return ret, nil
    end

    local auth_info = {
        uid = math.floor(userinfo.account_id),
        unionid = nil,
        playercoin = userinfo.player_coin,
        access_token = rs.token,
        account = account,
        vip = userinfo.vip
    }
    return PDEFINE.RET.SUCCESS, auth_info
end

--[[
检测ip属于哪个范围
]]
function LOGIC.checkIP(ip)
    if nil == webclient then
        LOG_ERROR("webclient not ready!")
        return PDEFINE.RET.ERROR.REGISTER_FAIL
    end

    local url = url_head.."/ipCheck?ip=" .. ip
    local ok, body = skynet.call(webclient, "lua", "request", url, nil, nil, false, TIME_OUT) --post请求
    if not ok then
        LOG_ERROR("checkout ip from you9apisdk error!", url)
        return PDEFINE.RET.ERROR.REGISTER_FAIL
    end
    LOG_DEBUG("checkout ip post qequest url:", url, " body:", body)
    local ok,resp = pcall(jsondecode,body)
    if not ok then
        LOG_ERROR("checkout ip url:", url," Verify token from you9apisdk body error!")
        return PDEFINE.RET.ERROR.REGISTER_FAIL
    end

    local rs = {}
    rs.apirs = resp
    if resp.errcode > 0 then
        LOG_ERROR("checkout ip url:", url, "you9apisdk err. ip:", ip)
        local myerrcode = APIRET[math.floor(resp.errcode)]
        if myerrcode == nil then
            myerrcode = PDEFINE.RET.UNDEFINE
        end
        return myerrcode,rs
    end

    return PDEFINE.RET.SUCCESS, rs
end

--[[
去api服注册账号
]]
function LOGIC.register2Api(param)
    if nil == webclient then
        LOG_ERROR("webclient not ready!")
        return PDEFINE.RET.ERROR.REGISTER_FAIL
    end

    local url = url_head.."/game/account/register"
    local ok, body = skynet.call(webclient, "lua", "request", url, nil, param, false, TIME_OUT) --post请求
    if not ok then
        LOG_ERROR("register2API user from you9apisdk error!", url)
        return PDEFINE.RET.ERROR.REGISTER_FAIL
    end
    LOG_DEBUG("register2API post qequest url:", url, "param:", param, "body:", body)
    local ok,resp = pcall(jsondecode,body)
    if not ok then
        LOG_ERROR("register2API url:", url," Verify token from you9apisdk body error!")
        return PDEFINE.RET.ERROR.REGISTER_FAIL
    end

    local rs = {}
    rs.apirs = resp
    if resp.errcode > 0 then
        LOG_ERROR("register2API url:", url, "you9apisdk getAccessToken err. account:", account, " pass:", pass, "resp:",resp)
        local myerrcode = APIRET[math.floor(resp.errcode)]
        if myerrcode == nil then
            myerrcode = PDEFINE.RET.UNDEFINE
        end
        return myerrcode,rs
    end

    return PDEFINE.RET.SUCCESS, rs
end

function LOGIC.auth_token(para)
    local ret, rs = LOGIC.getaccesstokenbytoken(para.login_token, para.client_uuid, para.ip, para.otherpara)
    if ret ~= PDEFINE.RET.SUCCESS then
        LOG_ERROR("you9apisdk getAccessToken failed.ret:",ret)
        return ret, nil
    end
    local user = rs.account
    local access_token_p = rs.token
    local ret, rs = LOGIC.getuserinfo(user, access_token_p)
    if ret ~= PDEFINE.RET.SUCCESS then
        LOG_ERROR("you9apisdk getUserInfo failed.ret:",ret)
        return ret, nil
    end
    
    local auth_info = {
        uid = math.floor(rs.account_id),
        unionid = nil,
        playercoin = rs.player_coin,
        access_token = access_token_p,
        account = rs.account_pid,
        vip = rs.vip
    }

    return PDEFINE.RET.SUCCESS, auth_info
end

function LOGIC.auth_oldtoken(para)
    local ret, rs = LOGIC.getaccesstokenbyoldtoken(para.login_token, para.client_uuid, para.ip)
    if ret ~= PDEFINE.RET.SUCCESS then
        LOG_ERROR("you9apisdk getAccessToken failed.ret:",ret)
        return ret, nil
    end
    local user = rs.account
    local access_token_p = rs.token
    local ret, rs = LOGIC.getuserinfo(user, access_token_p)
    if ret ~= PDEFINE.RET.SUCCESS then
        LOG_ERROR("you9apisdk getUserInfo failed.ret:",ret)
        return ret, nil
    end
    
    local auth_info = {
        uid = math.floor(rs.account_id),
        unionid = nil,
        playercoin = rs.player_coin,
        access_token = access_token_p,
        account = user,
        vip = rs.vip
    }

    return PDEFINE.RET.SUCCESS, auth_info
end

-- 设置token 时间
local function bindTokenAccount(account, token, pass)
    --获取成功后 redis下面缓存 token对应的 账号，密码 以及 账号对应token 设置过期时间为1天 
    local rediskey_account = PDEFINE.REDISKEY.YOU9API["account2token"]..":"..account
    local rediskey_token = PDEFINE.REDISKEY.YOU9API["token2account"]..":"..token
    local redistoken = do_redis({"get", rediskey_account})
    if redistoken ~= nil then
        do_redis({"del", PDEFINE.REDISKEY.YOU9API["token2account"]..":"..redistoken})
    end
    do_redis( { "setex", rediskey_account, token, DAYSECOND*7 } )
    do_redis( { "setex", rediskey_token, cjson.encode({account=account,password=pass}), DAYSECOND*7 } )
end

--注册游客账号
function LOGIC.registeryk(para)
    if nil == webclient then
        LOG_ERROR("webclient not ready!")
        return PDEFINE.RET.ERROR.REGISTER_FAIL
    end

    local pass = '111111'
    local pwdmd5_para = md5.sumhexa(pass)
    local param = {
        username = para.user or string.sub(md5.sumhexa(para.client_uuid), 1, 10) .. math.random(1000000,9999999),
        pwdmd5=pwdmd5_para,
        clientuuid=para.client_uuid,
        ip=para.ip
    }

    local url = url_head.."/game/account/registeryk"
    local ok, body = skynet.call(webclient, "lua", "request", url, nil, param, false, TIME_OUT) --post请求
    if not ok then
        LOG_ERROR("registeryk2API user from you9apisdk error!", url)
        return PDEFINE.RET.ERROR.REGISTER_FAIL
    end
    LOG_DEBUG("registeryk2API post qequest url:", url, "param:", param, "body:", body)
    local ok,resp = pcall(jsondecode,body)
    if (not ok) or (not resp) or (resp.errcode ~= 0) then
        LOG_ERROR("register2API url:", url," Verify token from you9apisdk body error!", resp)
        return PDEFINE.RET.ERROR.REGISTER_FAIL
    end

    local account = resp.data.account.account  
    local token = resp.data.token

    --获取成功后 redis下面缓存 token对应的 账号，密码 以及 账号对应token 设置过期时间为1天 
    bindTokenAccount(account, token, pass)

    local auth_info = {
        uid = math.floor(resp.data.account.id),
        unionid = nil,
        playercoin = resp.data.account.coin,
        access_token = resp.data.token,
        account = account,
        vip = 0 --刚注册的账号，不可能是VIP
    }
    return PDEFINE.RET.SUCCESS, auth_info
end

--游客登录
function LOGIC.auth_yk(para)
    if nil == webclient then
        LOG_ERROR("webclient not ready!")
        return PDEFINE.RET.ERROR.REGISTER_FAIL, nil
    end

    if para.client_uuid == nil or #tostring(para.client_uuid) == 0 then
        LOG_ERROR("you9apisdk getykaccesstoken failed,check u para!")
        return PDEFINE.RET.ERROR.PARAM_NIL, nil
    end

    local pass = "111111"
    local url  = url_head .. "/game/account/loginyk"

    local uid             = para.uid
    local clientuuid_para = para.client_uuid
    local pwdmd5_para     = md5.sumhexa(pass)
    local post_param = {
        account=uid,
        pwdmd5=pwdmd5_para,
        clientuuid=clientuuid_para,
        ip=para.ip,
        uid = uid,
    }

    if para.logintype == 10 or para.logintype == 11 or para.logintype == 12 or para.logintype == 13 then 
        if para.logintype == 10 then
            url  = url_head .. "/game/account/logingoogle"
        elseif  para.logintype == 11 then
            url  = url_head .. "/game/account/loginapple"
        elseif  para.logintype == 12 then
            url  = url_head .. "/game/account/loginfb"
        elseif  para.logintype == 13 then
            url  = url_head .. "/game/account/loginhuawei"
        end
        post_param["id_token"] = para.login_token
        post_param["account"] = para.account
        post_param["ignoreauth"] = para.ignoreauth
    end

    LOG_DEBUG( "getykaccesstoken url:", url, " clientuuid:", clientuuid_para, " pwdmd5:", pwdmd5_para )

    local ok, body = skynet.call(webclient, "lua", "request", url, post_param, nil, false, TIME_OUT)
    if not ok then
        LOG_ERROR("getykaccesstoken url:", url, "Verify token from you9apisdk error!getykaccesstoken")
        return PDEFINE.RET.ERROR.REGISTER_FAIL, nil
    end
    LOG_DEBUG("getykaccesstoken url:", url, " body:", body)
    local ok,resp = pcall(jsondecode, body)
    if not ok then
        LOG_ERROR("getykaccesstoken url:", url,"Verify token from you9apisdk body error!")
        return PDEFINE.RET.ERROR.REGISTER_FAIL, nil
    end
    local rs = {}
    rs.apirs = resp
    if resp.errcode > 0 then
        LOG_ERROR("getykaccesstoken url:", url , "resp:",resp)
        local myerrcode = APIRET[math.floor(resp.errcode)]
        if myerrcode == nil then
            myerrcode = PDEFINE.RET.UNDEFINE
        end
        return myerrcode, nil
    end

    --获取成功后 redis下面缓存 token对应的 账号，密码 以及 账号对应token 设置过期时间为1天 
    bindTokenAccount(clientuuid_para, resp.data.token, pass)

    local auth_info = {
        uid = math.floor(resp.data.account.id),
        unionid = nil,
        playercoin = resp.data.account.coin,
        access_token = resp.data.token,
        account = resp.data.account.account,
        vip = resp.data.account.svip
    }
    return PDEFINE.RET.SUCCESS, auth_info
end

--注册google或者apple或者fb账号
function LOGIC.register_otherApp(para)
    if nil == webclient then
        LOG_ERROR("webclient not ready!")
        return PDEFINE.RET.ERROR.REGISTER_FAIL
    end

    local pass = '111111'
    local pwdmd5_para = md5.sumhexa(pass)
    local param = {
        username = para.account,
        pwdmd5=pwdmd5_para,
        clientuuid=para.client_uuid,
        ip=para.ip,
        id_token = para.login_token,
        nickname = para.otherpara.LoginExData.nick
    }

    local url 
    if para.logintype == 10 then
        url = url_head.."/game/account/registergoogle"
    elseif para.logintype == 11 then
        url = url_head.."/game/account/registerapple"
    elseif para.logintype == 12 then
        url = url_head.."/game/account/registerfb"
    elseif para.logintype == 13 then
        url = url_head.."/game/account/registerhuawei"
    end
    LOG_DEBUG("register_google post qequest url:", url, "param:", param)
    local ok, body = skynet.call(webclient, "lua", "request", url, nil, param, false, TIME_OUT) --post请求
    if not ok then
        LOG_ERROR("register_google user from you9apisdk error!", url)
        return PDEFINE.RET.ERROR.REGISTER_FAIL
    end
    LOG_DEBUG("register_google post qequest url:", url, "param:", param, "body:", body)
    local ok,resp = pcall(jsondecode,body)
    if not ok then
        LOG_ERROR("register_google url:", url," Verify token from you9apisdk body error!")
        return PDEFINE.RET.ERROR.REGISTER_FAIL
    end

    local account = resp.data.account.account  
    local token = resp.data.token

    --获取成功后 redis下面缓存 token对应的 账号，密码 以及 账号对应token 设置过期时间为1天 
    bindTokenAccount(account, token, pass)

    local auth_info = {
        uid = math.floor(resp.data.account.id),
        unionid = nil,
        playercoin = resp.data.account.coin,
        access_token = resp.data.token,
        account = account,
        vip = 0 --刚注册的账号，不可能是VIP
    }
    return PDEFINE.RET.SUCCESS, auth_info
end

function LOGIC.auth_normal(para)
    local account = para.account
    if account ~= nil then
        account = string.gsub(account, " ", "")
    end
    local passwd = para.passwd or ""
    local client_uuid = para.client_uuid or ""
    local ret, rs = LOGIC.getaccesstoken(account, passwd, para.ip, client_uuid)
    if ret ~= PDEFINE.RET.SUCCESS then
        LOG_ERROR("you9apisdk getAccessToken failed.ret:",ret)
        return ret, nil
    end

    local ret, userinfo = LOGIC.getuserinfo(user, rs.token)
    if ret ~= PDEFINE.RET.SUCCESS then
        LOG_ERROR("you9apisdk getUserInfo failed.ret:",ret)
        return ret, nil
    end

    local auth_info = {
        uid = math.floor(userinfo.account_id),
        unionid = nil,
        playercoin = userinfo.player_coin,
        access_token = rs.token,
        account = user,
        vip = userinfo.vip
    }
    return PDEFINE.RET.SUCCESS, auth_info
end

--[[
通过account pass 获取access_token的接口
e.g: "675cd575476eba9577b42be01efe01e3"
api返回示例
{
    "errcode": 0,
    "error": "",
    "data": {
        "token": "675cd575476eba9577b42be01efe01e3",            token值
        "expires_in": -1,
        "account": {
            "id": "1109518",                                    账号id，同uid
            "account": "6874-4721-7149",                        账号pid
            "coin": "99999.00",                                 当前余额
            "lastlogintime": 1544261463                         最后登录时间
        }
    }
}
]]
function LOGIC.getaccesstoken( account, pass, ip_p, clientuuid)
    if account == nil or pass == nil or #tostring(account)==0 or #tostring(pass) == 0 or clientuuid == nil or #tostring(clientuuid) == 0 then
        LOG_ERROR("you9apisdk getAccessToken failed,check u para!")
        return PDEFINE.RET.ERROR.LOGIN_FAIL
    end

    -- if #tostring(account) ~= 12 and #tostring(account) ~= 14 then 
    --     --账号长度只有可能是 12或者14
    --     LOG_ERROR("you9apisdk getAccessToken length account:",account)
    --     return PDEFINE.RET.ERROR.LOGIN_FAIL
    -- end
    local checkaccount = account
    if #tostring(account) == 14 then
        checkaccount = string.gsub(account, "-", "");
    end
    account = checkaccount

    if nil == webclient then
        LOG_ERROR("webclient not ready!")
        return PDEFINE.RET.ERROR.REGISTER_FAIL
    end

    local url = url_head.."/game/account/login"
    local account_para = account
    local pwdmd5_para = md5.sumhexa(pass)
    local clientuuid_para = clientuuid
    LOG_DEBUG( "getAccessToken url:", url, " account:", account_para, " pwdmd5:", pwdmd5_para, "ip_p:", ip_p, " clientuuid:", clientuuid_para)
    local ok, body = skynet.call(webclient, "lua", "request", url,{account=account_para,pwdmd5=pwdmd5_para,ip=ip_p,clientuuid=clientuuid_para}, nil, false, TIME_OUT)
    if not ok then
        LOG_ERROR("Verify token from you9apisdk error!")
        return PDEFINE.RET.ERROR.REGISTER_FAIL
    end
    LOG_DEBUG("getaccesstoken url:", url, " body:", body)
    local ok,resp = pcall(jsondecode,body)
    if not ok then
        LOG_ERROR("getAccessToken url:", url," Verify token from you9apisdk body error!")
        return PDEFINE.RET.ERROR.REGISTER_FAIL
    end

    local rs = {}
    rs.apirs = resp
    if resp.errcode > 0 then
        LOG_ERROR("getAccessToken url:", url, "you9apisdk getAccessToken err. account:", account, " pass:", pass, "resp:",resp)
        if resp.errcode == 2003 then
            return PDEFINE.RET.ERROR.LOGIN_FAIL, rs
        end
        local myerrcode = APIRET[math.floor(resp.errcode)]
        if myerrcode == nil then
            myerrcode = PDEFINE.RET.UNDEFINE
        end
        return myerrcode,rs
    end

    --获取成功后 redis下面缓存 token对应的 账号，密码 以及 账号对应token 设置过期时间为1天 
    local rediskey_account = PDEFINE.REDISKEY.YOU9API["account2token"]..":"..account
    local rediskey_token = PDEFINE.REDISKEY.YOU9API["token2account"]..":"..resp.data.token

    local redistoken = do_redis({"get", rediskey_account})
    if redistoken ~= nil then
        do_redis({"del", PDEFINE.REDISKEY.YOU9API["token2account"]..":"..redistoken})
    end

    do_redis( { "setex", rediskey_account, resp.data.token, DAYSECOND*7 } )
    do_redis( { "setex", rediskey_token, cjson.encode({account=account_para,password=pass}), DAYSECOND*7 } )

    rs.token = resp.data.token
    rs.account = account_para

    return PDEFINE.RET.SUCCESS, rs
end

--根据老的token来尝试拿新的token
function LOGIC.getaccesstokenbyoldtoken( oldtoken, clientuuid, ip_p )
    if oldtoken == nil or #tostring(oldtoken) == 0 then
        LOG_ERROR("you9apisdk getaccesstokenbyoldtoken failed,check u para!")
        return PDEFINE.RET.ERROR.TOKEN_ERR
    end

    if nil == webclient then
        LOG_ERROR("webclient not ready!")
        return PDEFINE.RET.ERROR.REGISTER_FAIL
    end

    local rediskey_token = PDEFINE.REDISKEY.YOU9API["token2account"]..":"..oldtoken
    local rs = do_redis( { "get", rediskey_token } )
    if rs == nil then
        LOG_DEBUG("rs is nil:")
        return PDEFINE.RET.ERROR.TOKEN_ERR
    end

    local jsonrs = cjson.decode(rs)
    local account = jsonrs.account
    local pass = jsonrs.password

    --有缓存 就刷新缓存更新时间 并且直接返回token
    --获取成功后 redis下面缓存 token对应的 账号，密码 以及 账号对应token 设置过期时间为7天 
    local rediskey_account = PDEFINE.REDISKEY.YOU9API["account2token"]..":"..account

    do_redis( { "setex", rediskey_account, oldtoken, DAYSECOND*7 } )
    do_redis( { "setex", rediskey_token, rs, DAYSECOND*7 } )

    local result = {}
    result.token = oldtoken
    result.account = account

    local url = url_head.."/game/account/loginbytoken"
    LOG_DEBUG( "loginbytoken url:", url, " oldtoken:", oldtoken )
    local ok, body = skynet.call(webclient, "lua", "request", url,{token=oldtoken,ip=ip_p}, nil, false, TIME_OUT)
    if not ok then
        LOG_ERROR("loginbytoken from you9apisdk error!")
        return PDEFINE.RET.ERROR.REGISTER_FAIL
    end
    LOG_DEBUG("loginbytoken url:", url, " body:", body)
    local ok,resp = pcall(jsondecode,body)
    if not ok then
        LOG_ERROR("loginbytoken url:", url," Verify token from you9apisdk body error!")
        return PDEFINE.RET.ERROR.REGISTER_FAIL
    end

    result.apirs = resp
    if resp.errcode > 0 then
        LOG_ERROR("loginbytoken url:", url, "you9apisdk loginbytoken err. account:", account, " pass:", pass, "resp:",resp)
        local myerrcode = APIRET[math.floor(resp.errcode)]
        if myerrcode == nil then
            myerrcode = PDEFINE.RET.UNDEFINE
        end
        return myerrcode,result
    end

    return PDEFINE.RET.SUCCESS, result
end


function LOGIC.getaccesstokenbytoken( oldtoken, clientuuid, ip_p, otherpara )
    if oldtoken == nil or #tostring(oldtoken) == 0 then
        LOG_ERROR("you9apisdk getaccesstokenbyoldtoken failed,check u para!")
        return PDEFINE.RET.ERROR.TOKEN_ERR
    end
    if otherpara == nil then
        otherpara = {}
    end
    if nil == webclient then
        LOG_ERROR("webclient not ready!")
        return PDEFINE.RET.ERROR.REGISTER_FAIL
    end

    local sendpara = {}
    sendpara.token = oldtoken
    sendpara.ip = ip_p
    sendpara.gameid = otherpara.gameid
    sendpara.signstr = otherpara.signstr

    local url = url_head.."/game/account/loginbytoken"
    LOG_DEBUG( "loginbytoken url:", url, " sendpara:", sendpara, "oldtoken:",oldtoken )
    local ok, body = skynet.call(webclient, "lua", "request", url,sendpara, nil, false, TIME_OUT)
    if not ok then
        LOG_ERROR("loginbytoken from you9apisdk error!")
        return PDEFINE.RET.ERROR.REGISTER_FAIL
    end
    LOG_DEBUG("loginbytoken url:", url, " body:", body)
    local ok,resp = pcall(jsondecode,body)
    if not ok then
        LOG_ERROR("loginbytoken url:", url," Verify token from you9apisdk body error!")
        return PDEFINE.RET.ERROR.REGISTER_FAIL
    end

    local result = {}
    result.token = oldtoken
    result.account = oldtoken
    result.apirs = resp
    if resp.errcode > 0 then
        LOG_ERROR("loginbytoken url:", url, "you9apisdk loginbytoken err. account:", account, " pass:", pass, "resp:",resp)
        local myerrcode = APIRET[math.floor(resp.errcode)]
        if myerrcode == nil then
            myerrcode = PDEFINE.RET.UNDEFINE
        end
        return myerrcode,result
    end

    return PDEFINE.RET.SUCCESS, result
end

--[[
通过access_token 获取user信息的接口
e.g:
{
    "errcode":0,
    "error":"xx",
    "data":
    {
        "account_id":"xx",
        "account_pid":"xx",
        "account_isvip":"0",0表示没有vip  非0表示vip等级
        "account_createtime":"xxx",
        "account_lastlogintime":"xx",
        "account_coin":"4.0000",
        "pprofit_balance":"232432", --当前可提现的收益余额
        "pprofit_total":"5000000",  --收益总额
        "pcode":"22342342" --玩家账号邀请码
    }
}
]]
function LOGIC.getuserinfo( account, access_token )
    
    if access_token == nil or #tostring(access_token)==0 then
        LOG_ERROR("you9apisdk getUserInfo failed,check u para!")
        return PDEFINE.RET.ERROR.TOKEN_ERR
    end
    
    local url = url_head.."/game/account/current"
    local ok, body = skynet.call(webclient, "lua", "request", url,{token=access_token}, nil, false, TIME_OUT)
    if not ok then
        LOG_ERROR("getUserInfo from you9apisdk error! account:",account)
        return PDEFINE.RET.ERROR.REGISTER_FAIL
    end
    LOG_DEBUG("getuserinfo body:", body)
    local ok,resp = pcall(jsondecode,body)
    if not ok then
        LOG_ERROR("getUserInfo from you9apisdk error!")
        return PDEFINE.RET.ERROR.REGISTER_FAIL
    end

    local rs = {}
    rs.apirs = resp
    if resp.errcode > 0 then
        LOG_ERROR("you9apisdk getUserInfo err. account:", account, " pass:", pass, "resp:",resp)
        local myerrcode = APIRET[math.floor(resp.errcode)]
        if myerrcode == nil then
            myerrcode = PDEFINE.RET.UNDEFINE
        end
        return myerrcode,rs
    end
    rs.account_id = resp.data.account_id
    rs.player_coin = resp.data.account_coin
    rs.vip = tonumber(resp.data.account_isvip)
    return PDEFINE.RET.SUCCESS, rs
end

--[[
通过access_token 登出操作 暂时没用 原因是这个地方游戏端不好做
e.g:
{
    "errcode": 0,
    "error": "",
    "data": {
        "token": null,
        "expires_in": 0
    }
}
]]
function CMD.logout( uid,access_token,onlinetime )
    if access_token == nil or #tostring(access_token)==0 then
        LOG_ERROR("you9apisdk logout failed,check u para!")
        --不关心错误
        return PDEFINE.RET.UNDEFINE
    end

    local url = url_head.."/game/account/logout"
    LOG_DEBUG("logout url:", url, "token:", access_token, "online:", onlinetime)
    local ok, body = skynet.call(webclient, "lua", "request", url,{token=access_token,online=onlinetime}, nil, false, TIME_OUT)
    if not ok then
        LOG_ERROR("logout from you9apisdk error! uid:",uid)
        return PDEFINE.RET.ERROR.REGISTER_FAIL
    end

    LOG_DEBUG("logout body:", body)
    local ok,resp = pcall(jsondecode,body)
    if not ok then
        LOG_ERROR("logout from you9apisdk error!")
        return PDEFINE.RET.ERROR.REGISTER_FAIL
    end

    return PDEFINE.RET.SUCCESS,resp
end

-- google注册校验
function CMD.googleCheck(email, access_token)
    if access_token == nil or #tostring(access_token)==0 then
        LOG_ERROR("you9apisdk googleCheck failed,check u para!")
        --不关心错误
        return PDEFINE.RET.UNDEFINE
    end

    local url = url_head.."/game/account/GoogleCheckCode"
    LOG_DEBUG("google url:", url, "token:", access_token)
    local ok, body = skynet.call(webclient, "lua", "request", url,{token=access_token, email=email}, nil, false, TIME_OUT)
    if not ok then
        LOG_ERROR("googleCheck from you9apisdk error!")
        return PDEFINE.RET.ERROR.REGISTER_FAIL
    end

    LOG_DEBUG("google body:", body)
    local ok,resp = pcall(jsondecode,body)
    if not ok then
        LOG_ERROR("google from you9apisdk error!")
        return PDEFINE.RET.ERROR.REGISTER_FAIL
    end
    return PDEFINE.RET.SUCCESS, resp
end

-- 华为支付验证
function CMD.validateHuaweiOrder(purchaseToken, productId)
    if purchaseToken == nil or #tostring(purchaseToken)==0 then
        LOG_ERROR("you9apisdk validateHuaweiOrder failed,check u para!")
        --不关心错误
        return PDEFINE.RET.UNDEFINE
    end
    if productId == nil or #tostring(productId)==0 then
        LOG_ERROR("you9apisdk validateHuaweiOrder failed,check u para!")
        --不关心错误
        return PDEFINE.RET.UNDEFINE
    end

    local url = url_head.."/game/system/huawei"
    LOG_DEBUG("huawei url:", url, ' purchaseToken:', purchaseToken , ' productId:', productId)
    local ok, body = skynet.call(webclient, "lua", "request", url,{purchaseToken=purchaseToken, productId=productId}, nil, false, TIME_OUT * 60)
    if not ok then
        LOG_ERROR("validateHuaweiOrder from you9apisdk error!")
        return PDEFINE.RET.ERROR.REGISTER_FAIL
    end

    LOG_DEBUG("validateHuaweiOrder body:", body)
    local ok,resp = pcall(jsondecode, body)
    LOG_DEBUG("validateHuaweiOrder resp:", resp)
    if not ok then
        LOG_ERROR("validateHuaweiOrder from you9apisdk error!")
        return PDEFINE.RET.ERROR.REGISTER_FAIL
    end
    return PDEFINE.RET.SUCCESS, resp
end

--[[
通过access_token oldpass newpass 修改密码
e.g:
{
    "errcode": 0,
    "error": "",
    "data": {
        "username": null,
        "msg": "设置密码成功"
    }
}
]]
function CMD.alterpassword( account, access_token, oldpass, newpass )
    if access_token == nil or #tostring(access_token)==0 then
        LOG_ERROR("you9apisdk alterpassword failed,check u para!account:", account)
        return PDEFINE.RET.ERROR.PARAM_NIL
    end
    if oldpass == nil or #tostring(oldpass)==0 then
        LOG_ERROR("you9apisdk alterpassword failed,check u para!oldpass:", oldpass)
        return PDEFINE.RET.ERROR.PARAM_NIL
    end
    if newpass == nil or #tostring(newpass)==0 then
        LOG_ERROR("you9apisdk alterpassword failed,check u para!newpass:", newpass)
        return PDEFINE.RET.ERROR.PARAM_NIL
    end

    local newpwdmd5_para = md5.sumhexa(newpass)
    local oldpwdmd5_para = md5.sumhexa(oldpass)

    local url = url_head.."/game/account/password"
    LOG_DEBUG("alterpassword url:", url, "token:", access_token, "oldpass:", oldpass, "newpass:", newpass, "account:", account)
    local ok, body = skynet.call(webclient, "lua", "request", url, {token=access_token}, {oldpassword=oldpwdmd5_para,newpassword=newpwdmd5_para},false,TIME_OUT)
    if not ok then
        LOG_ERROR("alterpassword from you9apisdk error! account:", account)
        return PDEFINE.RET.ERROR.CALL_FAIL
    end

    LOG_DEBUG("alterpassword body:", body)
    local ok,resp = pcall(jsondecode,body)
    if not ok then
        LOG_ERROR("lterpassword from you9apisdk error!")
        return PDEFINE.RET.ERROR.CALL_FAIL
    end
    local rs = {}
    rs.apirs = resp
    if tonumber(resp.errcode) ~= 0 then
        --返回错误码
        local myerrcode = APIRET[math.floor(resp.errcode)]
        if myerrcode == nil then
            myerrcode = PDEFINE.RET.UNDEFINE
        end
        return myerrcode, rs
    end
    return PDEFINE.RET.SUCCESS,rs
end

--[[
通过access_token 获取公告
e.g:
{
    "errcode": 0,
    "error": "",
    "data": {
        "clinotice": "这是一条客户端公告"
    }
}
]]
function CMD.getnotice( account, access_token )
     if access_token == nil or #tostring(access_token)==0 then
        LOG_ERROR("you9apisdk getnotice failed,check u para!account:", account)
        return PDEFINE.RET.ERROR.PARAM_NIL
    end

    local url = url_head.."/game/account/clinotice"
    local ok, body = skynet.call(webclient, "lua", "request", url, {token=access_token}, nil, false,TIME_OUT)
    if not ok then
        LOG_ERROR("getnotice from you9apisdk error! account:", account)
        return PDEFINE.RET.ERROR.CALL_FAIL
    end
    LOG_DEBUG("getnotice body:", body)
    local ok,resp = pcall(jsondecode,body)
    if not ok then
        LOG_ERROR("lterpassword from you9apisdk error!")
        return PDEFINE.RET.ERROR.CALL_FAIL
    end
    local rs = {}
    rs.apirs = resp
    if tonumber(resp.errcode) ~= 0 then
        --返回错误码
        local myerrcode = APIRET[math.floor(resp.errcode)]
        if myerrcode == nil then
            myerrcode = PDEFINE.RET.UNDEFINE
        end
        return myerrcode, rs
    end
    rs.clinotice = resp.data.clinotice
    return PDEFINE.RET.SUCCESS,rs
end

--获取数据 needdelafterget=true表示取完数据要删掉
function CMD.getdata( uid_p, access_token, mod, key, needdelafterget )
    -- print("------------mod----------",mod)
    -- bigbang disbigbang
    -- bigbang reward
    local rediskey = PDEFINE.REDISKEY.YOU9API[mod]
    if key ~= nil then
        rediskey = rediskey..":"..key
    end
    local result  = ""
    local data
    local ismap = true
    for k,v in pairs(REDISKEY_NotMapTable) do
        if v == mod then
            ismap = false
            break
        end
    end
    if ismap then
        result = do_redis({"hgetall", rediskey})
        data = make_pairs_table_int(result)
    else
        result = do_redis({"get", rediskey})
        if result then
            data = cjson.decode(result)
        else
            data = {}
        end
    end
    
    if needdelafterget == true then
        do_redis( { "del", rediskey } )
    end
    return PDEFINE.RET.SUCCESS,data
end

--上报游戏日志
--coin_p下注金额 win_p中奖金额 winjp_pJP中奖金额 pai_p牌型 result_p出奖结果 ex1扩展字段 ex2扩展字段
function CMD.sendGameLog(uid, before_coin, after_coin, gameinfo_para, poolround_para) 
    return PDEFINE.RET.SUCCESS, result
end

--获取redis的key
--@param gameid
--@param uid
--@return 字符串
local function getGameSettingRedisKey(uid)
    local uid = math.floor(uid)
    return string.format("%s:%d", gamesetting_rediskey, math.floor(uid))
end

--获取针对玩家的某个游戏设置
--@param gameid
--@param uid
--@return 如果没有设置会返回一个空table，有返回{gameid=xx,state=xx,chips=xx}
function CMD.getGameSetting(gameid, uid)
    gameid = math.floor(tonumber(gameid))
    uid = math.floor(tonumber(uid))
    local ok,rsdata = pcall(do_redis_withprename, "api_", {"hgetall", getGameSettingRedisKey(uid)})
    if ok then
        rsdata = make_pairs_table(rsdata)--key gameid  value {"chips":[{"min":"2","max":"100"}],"state":"1"}
        LOG_DEBUG("rsdata:", rsdata, gameid)
        if not table.empty(rsdata) and rsdata[tostring(gameid)] ~= nil then
            rsdata = cjson.decode(rsdata[tostring(gameid)])
            if rsdata.state == nil then
                rsdata.state = 0
            end
            local chips  = rsdata.chips or {}
            rsdata.chips = chips
            rsdata.state = math.floor(tonumber(rsdata.state))
            rsdata.gameid = gameid
            return rsdata
        end
    end

    rsdata = {}
    rsdata.gameid = gameid
    rsdata.state = 0
    rsdata.chips = {}
    return rsdata
end

--获取针对玩家的所有游戏设置
--@param uid
--@return {gameid={state=xx,chips=xx},gameid2={state=xx,chips=xx}}
function CMD.getAllGameSetting(uid)
    uid = math.floor(tonumber(uid))
    local ok,rsdata = pcall(do_redis_withprename, "api_", {"hgetall", getGameSettingRedisKey(uid)})
    if ok then
        rsdata = make_pairs_table(rsdata)--key gameid  value {"chips":[{"min":"2","max":"100"}],"state":"1"}
        return rsdata
    end
    return {}
end

skynet.start(function()
    local apiurl = cluster.call( "master", ".configmgr", "get", "apiurl" )
    if apiurl == nil then
        LOG_ERROR("you9apisdk apiurl isnil.")
    end
    --url_head = apiurl.v
    url_head = "http://47.238.169.232:9638"
    skynet.dispatch("lua", function(session, address, cmd, ...)
        -- LOG_DEBUG("you9apisdk", worker_index, " receive cmd:", cmd, ...)
        local f = CMD[cmd]
        skynet.retpack(f(...))
    end)
    webclient = skynet.newservice("webreq")
    skynet.register(".you9api_worker"..worker_index)
end)
