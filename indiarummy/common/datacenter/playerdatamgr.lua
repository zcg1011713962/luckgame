local skynet = require "skynet"
local cluster = require "cluster"
local date = require "date"
local cjson = require "cjson"
local md5 = require "md5"

local api_service = require "api_service"
cjson.encode_sparse_array(true)

local user_dc = require "user_dc" --玩家相关的dc列表

local player = {}
local handle
local UID
local SEND_COIN = 0 --初始账号赠送金币

local function getip(clientIP)
    if nil == clientIP or #clientIP==0 then
        return ""
    end
    local tmp = string.split(clientIP, ":")
    return tmp[1]
end

-- 请求玩家全部信息
local function getDataDetail(uid)
    if not user_dc.check_player_exists(uid) then
        LOG_ERROR("uid %d no player", uid)
        return PDEFINE.RET.ERROR.PLAYER_NOT_FOUND
    end
    local userInfo = player.getPlayerInfo(uid)
    local playerInfo = {}
    playerInfo.status = userInfo.status
    playerInfo.coin   = math.floor(userInfo.coin)
    playerInfo.uid    = userInfo.uid 
    playerInfo.playername = userInfo.playername
    playerInfo.usericon   = userInfo.usericon
    return playerInfo
end

-- 创建角色
function player.create(uid, clientIP)
    LOG_INFO("-----player.create---", uid)
    if user_dc.check_player_exists(uid) then
        LOG_ERROR("uid %d has player, create failed", uid)
        return PDEFINE.RET.ERROR.PLAYER_EXISTS
    end
    local ret, account = pcall(cluster.call, "login", ".accountdata", "get_account_dc", uid)
    if not ret then
        return PDEFINE.RET.ERROR.PLAYER_EXISTS
    end
    local name     = account.playername
    local usericon = account.usericon
    local sex      = account.sex
    local platform = account.platform
    local oid = account.oid or 0
    local invituser = nil
    local invituid = account.invit_uid or 0
    if invituid > 0 and 10000~=invituid then
        -- invituser = handle.dcCall("user_dc", "get", invituid)
        invituser = user_dc.get(invituid)
        if invituser == nil then
            invituid = 0
        end
    end

     -- 初始化角色基本数据
    local ip = getip(clientIP)
    local user_data = {}
    if oid > 0 then
        -- local oldplayerData = handle.dcCall("user_dc", "get", oid)
        local oldplayerData = user_dc.get(oid)
        local oldcoin = oldplayerData.coin
        -- player.setPlayerCoin(oid, 0)
        user_data = {
            uid = uid,
            sex = oldplayerData.sex,
            playername  = oldplayerData.playername,
            usericon    = oldplayerData.usericon,
            agent       = oldplayerData.agent, --普通玩家
            coin        = oldcoin, --金币
            code        = oldplayerData.code, --邀请码 就是uid
            login_time  = oldplayerData.login_time,
            create_time = oldplayerData.create_time,
            create_platform = oldplayerData.create_platform,
            status      = oldplayerData.status, --玩家状态 
            sharetime = oldplayerData.sharetime,
            login_ip  = oldplayerData.login_ip,
            invit_uid = oldplayerData.invit_uid, --fb注册登录的 很有可能有值
            memo      = oldplayerData.memo,
            reservecoin = oldplayerData.reservecoin,
            limitcoin = oldplayerData.limitcoin,
            ispayer = oldplayerData.ispayer,
            wintimes = oldplayerData.wintimes,
            alltimes = oldplayerData.alltimes,
            isrobot = oldplayerData.isrobot,
            iswhite = oldplayerData.iswhite,
            isblack = oldplayerData.isblack,
            login_days = oldplayerData.login_days,
            isbindfb = oldplayerData.isbindfb,
            daytime = oldplayerData.daytime,--每日登录累计时间
            curonlinejd = oldplayerData.curonlinejd,--当前执行阶段
            onlinestate = oldplayerData.onlinestate,--当前执行状态
            lrwardstate = oldplayerData.lrwardstate,--登录奖励状态
            praisetime = oldplayerData.praisetime, --5星好评时间
            invitednum = oldplayerData.invitednum, --邀请的下线人数
            invitedfb = oldplayerData.invitedfb,  --邀请的fb下线
            spread = oldplayerData.spread or 0,  --推广级别
            integral = oldplayerData.integral or 0, --人气积分
            headframe = oldplayerData.headframe or 0, --头像框
            fgamelist = table.concat(PDEFINE_GAME.F_GAME_LIST,','), -- 好友房喜爱列表
        }
    else
        user_data = {
            uid = uid,
            sex = sex,
            playername  = name,
            usericon    = usericon,
            agent       = 0, --普通玩家
            coin        = 0, --金币
            code        = uid, --邀请码 就是uid
            login_time  = os.time(),
            create_time = os.time(),
            create_platform = platform,
            status      = 1, --玩家状态 
            sharetime = 0,
            login_ip  = ip,
            invit_uid = invituid, --fb注册登录的 很有可能有值
            memo      = "这家伙很懒，什么都没有留下哦",
            reservecoin = 0, --新手赠送金币标记
            limitcoin = 10000,
            contact = '',
            contact_type = 0,
            ispayer = 0,
            wintimes = 0,
            alltimes = 0,
            isrobot = 0,
            iswhite = 0,
            isblack = 0,
            login_days = 0,
            isbindfb = 0,
            daytime = 0,--每日登录累计时间
            curonlinejd = 1,--当前执行阶段
            onlinestate = 0,--当前执行状态
            lrwardstate = 1,--登录奖励状态
            praisetime = 0, --5星好评时间
            invitednum = 0, --邀请的下线人数
            invitedfb = 0,  --邀请的fb下线
            spread = 0,  --推广级别
            integral = 0, --人气积分
            headframe = 0, --头像框
            fgamelist = table.concat(PDEFINE_GAME.F_GAME_LIST,','), -- 好友房喜爱列表
        }
    end

    local ret = user_dc.add(user_data)
    if not ret then
        return PDEFINE.RET.ERROR.DB_FAIL
    end
    if oid > 0 then
        player.setPlayerCoin(uid, user_data.coin)
    end
    
    return true, getDataDetail(uid)
end

--协议接口获取玩家信息
function player.getUserInfo(recvobj)
    -- local recvobj = cjson.decode(msg)
    local uid = math.floor(recvobj.otheruid)

    -- local retobj = {}
    -- retobj.c     = math.floor(recvobj.c)
    -- retobj.code  = PDEFINE.RET.SUCCESS

    local userInfo = player.getPlayerInfo(uid)
    local playerInfo = table.copy(userInfo)
    playerInfo.auth = 0
    if nil ~= playerInfo.realname and #playerInfo.realname > 0 then
        playerInfo.auth = 1
    end
    playerInfo.status      = nil
    -- playerInfo.create_time = nil
    playerInfo.login_time  = nil
    playerInfo.bindcode = playerInfo.invit_uid or ""
    playerInfo.invit_uid = nil
    playerInfo.ip = getip(playerInfo.login_ip)
    playerInfo.login_ip = nil
    playerInfo.coin = math.floor(playerInfo.coin)
    if nil ~= playerInfo.memo then
        playerInfo.memo = string.gsub(playerInfo.memo, "\n\r", "")
        playerInfo.memo = string.gsub(playerInfo.memo, "\n", "")
        playerInfo.memo = string.gsub(playerInfo.memo, "\r", "")
    end
    -- retobj.playerInfo = playerInfo
    return playerInfo
    -- return resp(retobj)
end

-- 内部接口获取玩家信息
function player.getPlayerInfo(uid)
    local playerData = user_dc.get(uid)
    return playerData
end


-- 直接redis中获取 coin
function player.getPlayerCoin(uid)
    return user_dc.getvalue(uid, "coin")
end

-------- 计算玩家金币(累加累减) --------
function player.calUserCoin(uid_p, altercoin, log, type, isSync)
    assert("error calling player.calUserCoin ", altercoin )
    -- if altercoin == 0 then
    --     return PDEFINE.RET.SUCCESS 
    -- end
    -- local uid = math.floor(tonumber(uid_p))
    -- local playerInfo = player.getPlayerInfo(uid)
    -- if nil ~= playerInfo then
    --     LOG_INFO(uid, " 玩家结算前, 玩家金币：", playerInfo.coin, " 操作金币：", altercoin, " log:", log)
    --     local coin = Double_Add( playerInfo.coin, altercoin )
    --     if coin < 0 then
    --         LOG_ERROR("玩家".. uid .. "结算金币错误:" .. coin)
    --         return PDEFINE.RET.COIN_NOT_ENOUGH
    --     end
    --     local code, before, after = player.setPlayerCoin(uid, coin, log, type, isSync)
    --     return code, before, after
    -- else
    --     return PDEFINE.RET.PLAYER_NOT_FOUND
    -- end
end

--type: settle, 结算 (settleCoin: 结算金币, taxCoin: 税收金币)
function player.setPlayerCoin(uid_p, coin, log)
    assert("error calling player.setPlayerCoin ", coin )

    -- coin = coin or 0
    -- --coin限制为4位小数
    -- coin = math.floor(coin*10000+0.0000001)/10000

    -- local uid = math.floor(tonumber(uid_p))
    -- local playerInfo = player.getPlayerInfo(uid)
    -- LOG_INFO(uid, " 玩家结算前, 玩家金币：", playerInfo.coin, " 设置金币：", coin, " log:", log)
    -- if not playerInfo then
    --     return PDEFINE.RET.PLAYER_NOT_FOUND
    -- end
    -- local beforecoin = playerInfo.coin
    -- local altercoin = coin - playerInfo.coin
    -- local ok = user_dc.setvalue(uid, "coin", coin)
    -- if not ok then
    --     return PDEFINE.RET.DB_FAIL
    -- end
    -- LOG_INFO(uid, " 玩家结算后, 玩家最终金币为:", coin)
    -- return PDEFINE.RET.SUCCESS, beforecoin, coin
end

function player.reloadPlayerInfo(uid, reloadsvip)
    local sql = string.format("select * from d_user where uid = %d ",uid)
    local rs = skynet.call(".mysqlpool", "lua", "execute", sql)
    if #rs > 0 then
        if rs[1].playername then
            user_dc.setvalue(uid, "playername", rs[1].playername)
        end
        if rs[1].usericon then
            user_dc.setvalue(uid, "usericon", rs[1].usericon)
        end
        if rs[1].invit_uid then
            user_dc.setvalue(uid, "invit_uid", rs[1].invit_uid)
        end
        if rs[1].memo then
            user_dc.setvalue(uid, "memo", rs[1].memo)
        end
        if rs[1].status then
            user_dc.setvalue(uid, "status", rs[1].status)
        end
        if rs[1].isbindphone then
            user_dc.setvalue(uid, "isbindphone", rs[1].isbindphone)
        end
        if rs[1].kyc then
            user_dc.setvalue(uid, "kyc", rs[1].kyc)
        end
        if reloadsvip == nil then
            if rs[1].svip then
                user_dc.setvalue(uid, "svip", rs[1].svip)
            end
        end
        if rs[1].tagid then
            user_dc.setvalue(uid, "tagid", rs[1].tagid)
        end
        if rs[1].nodislabelid then
            user_dc.setvalue(uid, "nodislabelid", rs[1].nodislabelid)
        end
        if rs[1].svipexp then
            user_dc.setvalue(uid, "svipexp", rs[1].svipexp)
        end
        if rs[1].stopregrebat then --禁止返佣
            user_dc.setvalue(uid, "stopregrebat", rs[1].stopregrebat)
        end
        if rs[1].forbidnick then --禁止修改昵称
            user_dc.setvalue(uid, "forbidnick", rs[1].forbidnick)
        end
        if rs[1].forbidchat then --禁止聊天
            user_dc.setvalue(uid, "forbidchat", rs[1].forbidchat)
        end
        if rs[1].suspendagent then --禁止俸禄
            user_dc.setvalue(uid, "suspendagent", rs[1].suspendagent)
        end
        if rs[1].istest then
            user_dc.setvalue(uid, "istest", rs[1].istest)
        end
        local playerInfo = {
            uid = uid, 
            invit_uid=rs[1].invit_uid,
            usericon=rs[1].usericon,
            playername=rs[1].playername, 
            memo=rs[1].memo, 
            status=rs[1].status, 
            svip= rs[1].svip, 
            svipexp=rs[1].svipexp, 
            isbindphone=rs[1].isbindphone, 
            kyc=rs[1].kyc,
            tagid=rs[1].tagid,
            istest = rs[1].istest,
        }
        return playerInfo
    end
end

return player