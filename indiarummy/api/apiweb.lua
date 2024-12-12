local skynet = require "skynet"
local socket = require "skynet.socket"
local httpd = require "http.httpd"
local sockethelper = require "http.sockethelper"
local urllib = require "http.url"
local cluster = require "cluster"
local table = table
local string = string
local cjson = require "cjson"
local player_tool = require "base.player_tool"

local mode = ...

local respheader = {}
respheader["Content-Type"] = "text/html;Charset=utf-8"

if mode == "agent" then

    local function response(id, ...)
        local ok, err = httpd.write_response(sockethelper.writefunc(id), ...)
        if not ok then
            -- if err == sockethelper.socket_error , that means socket closed.
            skynet.error(string.format("fd = %d, %s", id, err))
        end
    end

    --请求房间相关
    local function processRequest(id, query)
        LOG_DEBUG("query：", query)
        if nil == query.mod or (query.mod ~= 'sess' and query.mod ~= 'room') then
            return nil
        end

        local ok, retok, result
        local gameid = query.gameid --游戏id
        local act = query.act
        if act == 'list' then
            --指定游戏id的房间列表
            ok, retok, result = pcall(cluster.call, "master", ".mgrdesk", "apiDeskList", gameid, query.mod)
        elseif act == 'info' then
            --指定房间的信息
            local deskid = query.deskid
            ok, retok, result = pcall(cluster.call, "master", ".mgrdesk", "apiDeskInfo", gameid, query.mod, deskid)
        elseif act =='del' then
            --解散指定房间
            local deskid = query.deskid
            ok, retok, result = pcall(cluster.call, "master", ".mgrdesk", "apiKickDesk", gameid, query.mod, deskid)
        end

        if not ok then
            skynet.error("what ?")
        end

        if 200 == tonumber(retok) then
            LOG_DEBUG(" output result: ",result)
            response(id, retok, result, respheader)
        end
        return PDEFINE.RET.ERROR.ERRCODE, 'succ'
    end

    local function processRequestAccount(id, query)
        if nil == query.mod or query.mod ~= 'account' or query.act~="reload" then
            return nil
        end

        local ok, retok, result
        local uid  = query.uid
        ok, retok, result = pcall(cluster.call, "login", ".accountdata", "reload", uid)
        if not ok then
            skynet.error("what ?")
        end

        return PDEFINE.RET.SUCCESS, 'succ'
    end

    local function processRequestNickName(id, query)
        if nil == query.mod or query.mod ~= 'nickname' or query.act~="reload" then
            return nil
        end

        local ok, retok, result = pcall(cluster.call, "login", ".nickmgr", "reload")
        if not ok then
            skynet.error("what ?")
        end

        return PDEFINE.RET.SUCCESS, 'succ'
    end

    local function checknumber(value, base)
        return tonumber(value, base) or 0
    end
    
    local function urldecode(input)
        input = string.gsub (input, "+", " ")
        input = string.gsub (input, "%%(%x%x)", function(h) return string.char(checknumber(h,16)) end)
        input = string.gsub (input, "\r\n", "\n")
        return input
    end

    --api跑马灯
    -- mode=notice&act=send&gameid=2&msgid=2332
    local function processRequestapinotice( id, query, body )
        if nil == query.mod or query.mod ~= 'apinotice' then
            return nil
        end

        local ok, retok, result
        local msg = urldecode(body)
        LOG_DEBUG("processRequestapinotice msg:", msg)
        if #msg < 5 then
            LOG_ERROR("processRequestapinotice length error")
            return PDEFINE.RET.ERROR.PARAM_ILLEGAL
        end
        msg = string.sub(msg, 5,#msg) --去掉 msg=
        local msg  = cjson.decode(msg)
        local type = msg.type or 3
        ok, retok, result = pcall(cluster.call, "master", ".userCenter", "sendAllServerNotice", msg.data, type, 1, 0, nil, 0)
        if not ok then
            skynet.error("what ?")
        end

        return PDEFINE.RET.SUCCESS, 'succ'
    end

    --全服公告
    local function processPushNotice( id, query, body )
        if nil == query.mod or query.mod ~= 'pushnotice' then
            return nil
        end

        local ok, retok, result
        local msg = urldecode(body)
        LOG_DEBUG("processPushNotice msg:", msg)
        if #msg < 5 then
            LOG_ERROR("processPushNotice length error")
            return PDEFINE.RET.ERROR.PARAM_ILLEGAL
        end
        msg = string.sub(msg, 5,#msg) --去掉 msg=
        local svip = query.svip or '' --收到此通知的支付vip等级
        local message = {
            title = query.title or "", --标题
            msg = msg, -- 内容
            type = query.type or 1, --1:不可关闭 2：玩家点击界面关闭 3：展示Xs后自动关闭 4：展示Xs后自动关闭且玩家可以点击关闭
            close = query.close or 2, --展示2s后关闭
            count = query.count or 1, -- 通告次数
            interval = query.interval or 3, -- 间隔秒数
        }
        local type = msg.type or 3
        local svipArr= {}
        if svip ~= "" then
            svipArr = string.split_to_number(svip, ',')
        end
        ok, retok, result = pcall(cluster.call, "master", ".userCenter", "pushAllNotice", message, svipArr)
        if not ok then
            skynet.error("what ?")
        end

        return PDEFINE.RET.SUCCESS, 'succ'
    end

    --通过接口注册fb账户
    local function processRequestbindFace( id, query)
        if nil == query.mod or query.mod ~= 'bindfb' then
            return nil
        end

        local uid = query.uid or 0
        local unionid = query.unionid or 0
        local nickname = query.nickname or ''
        local client_uuid = query.client_uuid or ''
        local invit_uid = query.invit_uid or 0
        if uid == 0 then
            skynet.error("what ?")
        end

        local sql = string.format("INSERT INTO `d_user_bind`(uid,unionid,nickname,sex,platform,create_time) VALUE(%d, '%s', '%s', %d, %d, %d);", 
            uid,
            client_uuid,
            nickname,
            0,
            3,
            os.time())
        skynet.call(".dbsync", "lua", "sync", sql)

        local jsondata = {
            pid = uid,
            uid = uid,
            red_envelope = 0,
            coin = 0,
            nickname = nickname,
            usericon = '',
            invit_uid = invit_uid,
        }
        local ok = pcall(cluster.call, "master", ".userCenter", "registeruser", jsondata)
        if not ok then
            skynet.error("what ?")
        end
        return PDEFINE.RET.SUCCESS, 'succ'
    end

    --在线玩家信息
    local function processRequestUser(id, query, body)
        if nil == query.mod or query.mod ~= 'user' then
            return nil
        end

        local ok, retok, result
        if query.act == 'info' then
            --在线人数
            ok, retok, result = pcall(cluster.call, "master", ".userCenter", "ApiUserNum")
        elseif query.act == 'addInviteCount' then
            local uid = query.uid or 0
            uid = math.floor(uid)
            ok, retok, result = pcall(cluster.call, "master", ".userCenter", "addInviteCount", uid)
            if retok == PDEFINE.RET.SUCCESS then
                result = 'succ'
            end
        elseif query.act == 'update' then
            --更新玩家信息
            local uid = query.uid or 0
            uid = math.floor(uid)
            ok, retok, result = pcall(cluster.call, "master", ".userCenter", "ApiUserInfo", uid)
        elseif query.act == 'updatevip' then
            local uid = query.uid or 0
            uid = math.floor(uid)
            ok, retok, result = pcall(cluster.call, "master", ".userCenter", "ApiReloadVipInfo", uid)
        elseif query.act == 'vipbonus' then
            local uid = query.uid or 0
            local coin = tonumber(query.coin or 0)
            local rate = query.rate or '1:0:0'
            local actType = tonumber(query.t or 9) --vip周奖励 或月奖励
            uid = math.floor(uid)
            result = 'fail'
            ok, retok = pcall(cluster.call, "master", ".userCenter", "vipBonus", uid, coin, rate, actType)
            if retok == PDEFINE.RET.SUCCESS then
                result = 'succ'
            end
        elseif query.act == 'chat' then
            --把玩家掉线
            local uid = query.uid or 0
            local msg = body or "" --多个人用,分割 这里传过来的是个json
            if body ~= nil then
                msg = body.msg
            end
            LOG_DEBUG("user.chat uid:",uid, " msg:", msg)
            ok, retok, result = pcall(cluster.call, "master", ".userCenter", "sendChat2Global", uid, msg)
        elseif query.act == 'offline' then
            --把玩家掉线
            local uid = body or "" --多个人用,分割 这里传过来的是个json
            if body ~= nil then
                uid = body.uid
            end
            LOG_DEBUG("offline uid:",uid)
            ok, retok, result = pcall(cluster.call, "master", ".userCenter", "ApiOfflineUser", uid)
        elseif query.act == 'suspendagent' then --暂停返佣
            local uid = body or "" --多个人用,分割 这里传过来的是个json
            if body ~= nil then
                uid = body.uid
            end
            LOG_DEBUG("suspendagent uid:",uid)
            ok, retok, result = pcall(cluster.call, "master", ".userCenter", "ApiSuspendagent", uid)
        elseif query.act == 'switch' then
            local uid = query.uid or 0 --uid
            local rtype = query.rtype or 0 --类型
            local switch = query.switch or 0 --开关
            LOG_DEBUG("switch uid:",uid, 'rtype:', rtype, ' switch:', switch)
            ok, retok, result = pcall(cluster.call, "master", ".userCenter", "ApiSetUserSwitch", uid, rtype, switch)
        elseif query.act == 'hiderank' then
            --把玩家从排行版隐藏(uid用英文逗号隔开)
            local uid = query.uid or ""
            ok, retok, result = pcall(cluster.call, "master", ".userCenter", "ApiHideUser", uid)
        elseif query.act == 'del' then
            --删除玩家信息
            local uid = query.uid or 0
            uid = math.floor(uid)
            ok, retok, result = pcall(cluster.call, "master", ".userCenter", "ApiDelAccount", uid)
        elseif query.act == 'list' then
            --在线玩家列表
            local gameid = query.gameid or 0
            gameid = math.floor(gameid)
            ok, retok, result = pcall(cluster.call, "master", ".userCenter", "apiGetUserList", gameid)
        elseif query.act == 'online' then
            --指定多个uid是否在线
            local uid = urldecode(query.uid or "")
            ok, retok, result = pcall(cluster.call, "master", ".userCenter", "apiUserOnline", uid)
        elseif query.act == 'ingame' then
            --指定多个uid是否在线
            local uid = urldecode(query.uid or "")
            ok, retok, result = pcall(cluster.call, "master", ".userCenter", "apiUserInGame", uid)
        elseif query.act == 'turntable' then
            local uid = query.uid or 0
            local type = query.type or 1
            type = math.floor(type)
            uid = math.floor(uid)
            if uid > 0 then
                ok, retok, result = pcall(cluster.call, "master", ".userCenter", "setTurnTableData", uid, type)
            end
        elseif query.act == 'quest' then
            local uid = query.uid or 0
            local num = query.num or 0
            local questIds = {27,28,29}
            local reqQuestIds = query.ids or ""
            if #reqQuestIds > 0 then
                local tmpids = string.split(reqQuestIds, ',')
                if #tmpids > 0 then
                    questIds = {}
                    for _, id in pairs(tmpids) do
                        table.insert(questIds, tonumber(id))
                    end
                end
                
            end
            uid = math.floor(uid)
            num = math.floor(num)
            pcall(cluster.call, "master", ".userCenter", "updateBatchQuest", uid, questIds, num)
            result = 'succ'
        elseif query.act == 'addprop' then
            local uid = query.uid or 0
            local stype = query.type or 'points'
            local num = query.num or 10
            local STYPE_DICT = {'points','diamond','rp'}
            uid = math.floor(uid)
            num = math.floor(num)
            LOG_DEBUG("act = :", query.act, ' stype:', stype, ' UID:', uid, ' num:', num)
            if table.contain(STYPE_DICT, stype) then
                LOG_DEBUG("pcall ==== >>> ")
                -- if stype == 'levelexp' then
                --     pcall(cluster.call, "master", ".upgrademgr", "bet", uid, num, 256, 'level')
                --     result = 'succ'
                -- else
                    ok, retok, result = pcall(cluster.call, "master", ".userCenter", "apiAddUserProperty", uid, stype, num)
                    LOG_DEBUG("pcall ==== >>> ok: ", ok, retok, result)
                    if ok then
                        result = 'succ'
                    end
                -- end
            end
        elseif query.act == 'bindinfo' then
            local uid = query.uid or 0
            local field = query.field or 'bindbank'
            uid = math.floor(uid)
            field = string.lower(field)
            local field_type = {'bindbank','bindusdt','bindupi','isbindphone','kyc'}
            if table.contain(field_type, field) then
                ok, retok, result = pcall(cluster.call, "master", ".userCenter", "apiUpdateBindInfo", uid, field)
                LOG_DEBUG("pcall ==== >>> ok: ", ok, retok, result)
                if ok then
                    result = 'succ'
                end
            end
        elseif query.act =='getsigninfo' then
            local uidstr = body.uid --多个人用,分割
            local uids = string.split_to_number(uidstr, ',')
            local signedUids = {}
            local unsigned = {}
            local beginTime = calRoundBeginTime()
            for _, uid in pairs(uids) do
                local signInfo = do_redis({ "hgetall", "uid_sign_info" .. uid},uid)
                signInfo = make_pairs_table_int(signInfo)
                if nil ~= signInfo and nil ~= signInfo.signTimeStamp and tonumber(signInfo.signTimeStamp) >= beginTime then
                    table.insert(signedUids, uid)
                else
                    table.insert(unsigned, uid)
                end
            end
            result = {["code"]=PDEFINE.RET.SUCCESS, ['signed']= signedUids, ['unsigned']=unsigned}
            result = cjson.encode(result)
        elseif query.act == 'testwealth' then
            --测试榜首邮件
            local uid = query.uid or 0
            ok, retok, result = pcall(cluster.call, "master", ".winrankmgr", "testWealthRank", uid)
            if ok then
                result = 'succ'
            end
        elseif query.act == 'refreshfbtoken' then
            ok, retok, result = pcall(cluster.call, "master", ".userCenter", "ApiRefreshfbtoken", query.uid, query.token, query.expire)
            if ok then
                result = 'succ'
            end
        elseif query.act == 'draw' then --提交提现
            local uid = math.floor(query.uid or 0)
            local bankid = math.floor(query.bankid or 0)
            local chanid = math.floor(query.chanid or 0)
            local coin = math.floor(query.coin or 0)
            if uid > 0 then
                LOG_DEBUG(string.format("user %d drawcoin: %s from bank: %s", uid, coin, bankid))
                ok, retok = pcall(cluster.call, "master", ".userCenter", "draw", uid, bankid, coin, chanid)
                LOG_DEBUG(string.format("user %d drawcoin: %s back: %s", uid, coin, retok))
                result = 'fail'
                if ok and retok == PDEFINE.RET.SUCCESS then
                    result = 'succ'
                end
            end
        elseif query.act == 'drawverify' then --通过审核
            local uid = math.floor(query.uid or 0)
            local id = math.floor(query.id or 0)
            local status = math.floor(query.status or 0)
            if uid > 0 then
                LOG_DEBUG(string.format("user %d drawverify: %d ", uid, id))
                ok, retok = pcall(cluster.call, "master", ".userCenter", "drawverify", uid, id, status)
                LOG_DEBUG(string.format("user %d drawverify: %d ", uid, id), ' retok:', retok)
                result = 'fail'
                if ok and retok == PDEFINE.RET.SUCCESS then
                    result = 'succ'
                end
            end
        elseif query.act == 'rechargeverify' then --通过审核
            local uid = math.floor(query.uid or 0)
            local id = math.floor(query.id or 0)
            local rtype = math.floor(query.rtype or 0) --1:恢复 2:拒绝
            if uid > 0 then
                LOG_DEBUG(string.format("user %d rechargefail: %d ", uid, id))
                ok, retok = pcall(cluster.call, "master", ".userCenter", "rechargeVerify", uid, id, rtype)
                LOG_DEBUG(string.format("user %d rechargefail: %d ", uid, id), ' retok:', retok)
                result = 'fail'
                if ok and retok == PDEFINE.RET.SUCCESS then
                    result = 'succ'
                end
            end
        elseif query.act == 'kycverify' then --通过审核
            local uid = math.floor(query.uid or 0)
            local cat = math.floor(query.cat or 0)
            local id = math.floor(query.id or 0 )
            local status = math.floor(query.status or 0)
            if uid > 0 then
                LOG_DEBUG(string.format("user %d kycverify: %d ", uid, id))
                ok, retok = pcall(cluster.call, "master", ".userCenter", "kycverify", uid, cat, status, id)
                result = 'fail'
                if ok and retok == PDEFINE.RET.SUCCESS then
                    result = 'succ'
                end
            end
        elseif query.act == 'cashbonus' then --加减cashbonus
            local uid = math.floor(query.uid or 0)
            local coin = math.floor(query.coin or 0)
            local remark = query.remark or ''
            if uid > 0 then
                LOG_DEBUG(string.format("user %d cashbonus: %d remark:%s", uid, coin, remark))
                ok, retok = pcall(cluster.call, "master", ".userCenter", "apiActCashBonus", uid, coin, remark)
                result = 'fail'
                if ok and retok == PDEFINE.RET.SUCCESS then
                    result = 'succ'
                end
            end
        end

        if not ok then
            skynet.error("what ?")
        end

        return PDEFINE.RET.SUCCESS, result
    end

    --请求强制所有玩家重启
    local function processRequestSys(id, query)
        if nil == query.mod or query.mod ~= 'sys' then
            return nil, 'fail'
        end

        local ok, retok, result
        local gameid = query.gameid  or 0--游戏id
        gameid = math.floor(gameid)
        if query.act == 'restart' then
            --给所有接口设置返回接口code为801
            ok, retok, result = pcall(cluster.call, "master", ".userCenter", "ApiPushRestart")
        end

        if not ok then
            skynet.error("what ?")
        end
        return PDEFINE.RET.SUCCESS, 'succ'
    end

    --重置maintask
    local function processRequestMaintask(id, query)
        if nil == query.mod or query.mod ~= 'maintask' then
            return 500, 'fail'
        end

        local ok, retok
        if query.act == 'reset' then
            ok, retok = pcall(cluster.call, "master", ".userCenter", "apiResetMainTask")
            if not ok or retok ~= PDEFINE.RET.SUCCESS then
                return 500, 'fail'
            end
        end
        return PDEFINE.RET.SUCCESS, 'succ'
    end

    --重置配置表s_config
    local function processRequestConfig(id, query)
        if nil == query.mod or query.mod ~= 'config' then
            return 500, 'fail'
        end

        local ok, retok, result
        if query.act == 'reload' then
            ok, retok, result = pcall(cluster.call, "master", ".configmgr", "reload")
        elseif query.act == 'changechatad' then
            pcall(cluster.call, "master", ".configmgr", "reload")
            local notifyMsg = {c=PDEFINE.NOTIFY.NOITFY_CHAT_ADS, code=PDEFINE.RET.SUCCESS, spcode=0}
            local ok, pinmsg = pcall(cluster.call, "master", ".configmgr", "get", "worldchat")
            if ok and pinmsg.v ~= "" then
                notifyMsg.pinmsg = {}
                if string.find(pinmsg.v, 'http') then
                    notifyMsg.pinmsg.url = pinmsg.v
                else
                    notifyMsg.pinmsg.text = pinmsg.v
                end
            end
            ok, result = pcall(cluster.call, "master", ".userCenter", "pushAll2Client", notifyMsg)
            if ok then
                local resp = {
                    ['code'] = PDEFINE.RET.SUCCESS,
                    ['data'] = result
                }
                return PDEFINE.RET.SUCCESS, cjson.encode(resp)
            end
        elseif query.act == 'maintainlist' then
            ok, result = pcall(cluster.call, "master", ".configmgr", "get", "maintainlist")
            if ok then
                local resp = {
                    ['code'] = PDEFINE.RET.SUCCESS,
                    ['data'] = result
                }
                return PDEFINE.RET.SUCCESS, cjson.encode(resp)
            end
        end

        if not ok then
            return 500, 'fail'
        end
        return PDEFINE.RET.SUCCESS, 'succ'
    end

    --重载场次列表
    local function processRequestSess(id, query)
        if nil == query.mod or query.mod ~= 'sess' then
            return 500, 'fail'
        end

        local ok, retok, result
        if query.act == 'reload' then
            ok, retok, result = pcall(cluster.call, "master", ".sessmgr", "reload")
        end

        if not ok then
            return 500, 'fail'
        end
        return PDEFINE.RET.SUCCESS, 'succ'
    end

    local function processRequestShop(id, query)
        if nil == query.mod or query.mod ~= 'shop' then
            return 500, 'fail'
        end

        local ok, retok, result
        if query.act == 'reload' then
            ok, retok, result = pcall(cluster.call, "master", ".shopmgr", "reload")
        end

        if not ok then
            return 500, 'fail'
        end
        return PDEFINE.RET.SUCCESS, 'succ'
    end

    local function processRequestChat(id, query)
        if nil == query.mod or query.mod ~= 'chat' then
            return 500, 'fail'
        end

        local msgid = query.msgid  or 0 --可以是单个，也可以是多个 例如 1 或者 1,2
        local ok, retok
        if query.act == 'del' then
            ok, retok = pcall(cluster.call, "node", ".chat", "delItems", msgid)
        elseif query.act == 'cleardata' then
            ok, retok = pcall(cluster.call, "node", ".chat", "cleardata")
        end
        if not ok then
            return 500, 'fail'
        end
        return PDEFINE.RET.SUCCESS, 'succ'
    end

    --用户后台充值
    local function processRequestCoin(id, query)
        if nil == query.mod or query.mod ~= 'coin' then
            return nil, 'fail'
        end
        
        local ok, retok, result
        local uid = query.uid  or 0--游戏id
        local coin = query.coin or 0
        local logtoken = query.logtoken
        local ipaddr = query.ipaddr
        local remark = query.remark or ""
        local isdraw = tonumber(query.draw or 0) --是否提现返回
        local addType
        if isdraw > 0 then
            addType = 'WITHDRAW_REFUND'
        end
        uid = math.floor(uid)
        coin = tonumber(coin)
        LOG_DEBUG("玩家id：", uid, " 金币：", coin, " logtoken:",logtoken, ' remark:', remark)
        if query.act == 'add' then
            ok, retok = pcall(skynet.call, ".you9apisdk", "lua", "addCoin", uid, coin, ipaddr, addType, remark)
            if not ok then
                LOG_ERROR("processRequestCoin callyou9apisdk addCoin CALL_FAIL")
                return PDEFINE.RET.ERROR.CALL_FAIL, 'fail'
            end
            if retok == PDEFINE.RET.SUCCESS then
                return PDEFINE.RET.SUCCESS, 'succ'
            else
                LOG_ERROR("processRequestCoin callyou9apisdk fail", retok)
                return retok, 'fail'
            end
        end
        return PDEFINE.RET.SUCCESS, 'fail'
    end

    --支付回调
    local function processRequestPay(id, query)
        if nil == query.mod or query.mod ~= 'pay' then
            return nil, 'fail'
        end
        if nil == query.act or query.act ~= 'callback' then
            return nil, 'fail'
        end
        
        local ok, retok
        local orderid = query.orderid  or '' --订单id
        local agentno = query.agentno or '' --第3房订单号
        local actor = query.actor or '' --订单操作人
        LOG_DEBUG("订单回调 orderid:", orderid,  " agentno:", agentno)
        ok, retok = pcall(cluster.call, "master", ".userCenter", "orderAsynCallback", orderid, agentno,actor)
        if not ok then
            LOG_ERROR("processRequestPay  addCoin CALL_FAIL")
            return PDEFINE.RET.ERROR.CALL_FAIL, 'fail'
        end
        if retok ~= PDEFINE.RET.SUCCESS then
            LOG_ERROR("processRequestPay  fail", retok)
            return retok, 'fail'
        end
        return PDEFINE.RET.SUCCESS, 'succ'
    end

    --游戏概率控制重载 或 游戏点控
    local function processRequestControl(id, query)
        if nil == query.mod or query.mod ~= 'control' then
            return nil
        end

        local ok, retok, result
        local act = query.act or "set"
        local uid = query.uid  or 0--uid
        local coin = query.coin or 0
        uid = math.floor(uid)
        coin = math.floor(coin)

        --游戏重新加载配置
        if act == 'reload' then
            local gameid = tonumber(query.gameid) or 0
            if gameid > 0 then
                ok, retok, result = pcall(cluster.call, "master", ".gamemgr", "reload", gameid)
                if ok then
                    return 200, "succ"
                end
            end
        end
        return 500, "fail"
    end


    --bigbang 展示
    local function processRequestDisbigbang( id, query )
        local bb_disbaseline = query.bb_disbaseline --显示基准值，自设定起，大厅界面中的BBJP奖池金额将从这个值开始浮动
        local bb_valdown_parl = query.bb_valdown_parl --下降率，左值
        local bb_valdown_time = query.bb_valdown_time --下降间隔时间，单位分钟
        local bb_wave_val = query.bb_wave_val --BBJP奖池金额显示值以所有拉霸游戏实际的下注为时机进行波动。每次下注行为将会向BBJP奖池增加以下设定金额
        local update_time = os.time()

        local data = {}
        data.disbaseline = bb_disbaseline
        data.valdown_parl = bb_valdown_parl
        data.valdown_time = bb_valdown_time
        data.wave_val = bb_wave_val
        data.update_time = update_time

        local result = do_redis({"hmset", PDEFINE.REDISKEY.YOU9API.disbigbang, data})
        LOG_DEBUG("processRequestDisbigbang do_redis data:", data, " result:", result)

        local returndata = {}
        returndata.code=200
        returndata.error = "SUCCESS"
        return PDEFINE.RET.SUCCESS, cjson.encode(returndata)
    end

    --bigbang 开奖
    local function processRequestBigbangreward( id, query )
        if nil == query.mod or query.mod ~= 'bigbangreward' then
            return nil, 'fail'
        end
        local logtoken = query.logtoken -- 记录唯一标识，32位字符
        local uid = query.uid --中奖玩家uid
        local coin = query.coin --中奖金额
        local expiretime = query.expiretime --记录过期时间

        local data = {}
        data.logtoken = logtoken
        data.uid = uid
        data.coin = coin
        data.expiretime = expiretime

        local returndata = {}
        returndata.code=200
        returndata.error = "SUCCESS"

        local resttime = expiretime
        if math.floor(resttime) <= 0 then
            LOG_DEBUG("resttime<= 0 data:", data)
            return PDEFINE.RET.SUCCESS, cjson.encode(returndata)
        end
        local result = do_redis( {"setex", PDEFINE.REDISKEY.YOU9API.bigbangreward..":"..math.floor(tonumber(uid)), cjson.encode(data),math.floor(resttime)} )
        LOG_DEBUG("processRequestBigbangreward:", query, result)
        return PDEFINE.RET.SUCCESS, cjson.encode(returndata)
    end

    --红包数据设置
    local function processRequestredbagsetting( id, query )
        if nil == query.mod or query.mod ~= 'redbagsetting' then
            return nil, 'fail'
        end

        local pool_rb_isopen = query.pool_rb_isopen -- 是否开启救济红包
        local pool_rb_limitup = query.pool_rb_limitup --发放红包上限 下限超过上限时红包不会发放
        local pool_rb_limitdown = query.pool_rb_limitdown --发放红包下限 下限超过上限时红包不会发放
        local pool_rb_coinless = query.pool_rb_coinless --玩家当前余额小于
        local pool_rb_7daycoindiff = query.pool_rb_7daycoindiff --7日分差 >=

        local data = {}
        data.pool_rb_isopen = pool_rb_isopen
        data.pool_rb_limitup = pool_rb_limitup
        data.pool_rb_limitdown = pool_rb_limitdown
        data.pool_rb_coinless = pool_rb_coinless
        data.pool_rb_7daycoindiff = pool_rb_7daycoindiff

        local result = do_redis({"hmset", PDEFINE.REDISKEY.YOU9API.redbagsetting, data})
        LOG_DEBUG("processRequestredbagsetting do_redis data:", data, " result:", result)

        local returndata = {}
        returndata.code=200
        returndata.error = "SUCCESS"

        return PDEFINE.RET.SUCCESS, cjson.encode(returndata)
    end

    --jp池设置
    local function processRequestdispooljp( id, query )
        if nil == query.mod or query.mod ~= 'dispooljp' then
            return nil, 'fail'
        end

        local pool_jp_disbaseline = query.pool_jp_disbaseline -- DIS 显示基准值
        local pool_jp_diswave = query.pool_jp_diswave --DIS 波动额
        local pool_jp_disinterval = query.pool_jp_disinterval --DIS 下降间隔时间
        local pool_jp_disdownpar = query.pool_jp_disdownpar --DIS 下降率
        local update_time = os.time()

        local data = {}
        data.disbaseline = pool_jp_disbaseline
        data.valdown_parl = pool_jp_disdownpar
        data.valdown_time = pool_jp_disinterval
        data.wave_val = pool_jp_diswave
        data.update_time = update_time

        local result = do_redis({"hmset", PDEFINE.REDISKEY.YOU9API.pooljp, data})
        LOG_DEBUG("processRequestdispooljp do_redis data:", data, " result:", result)

        local returndata = {}
        returndata.code=200
        returndata.error = "SUCCESS"

        return PDEFINE.RET.SUCCESS, cjson.encode(returndata)
    end

    --双龙彩设置
    local function processRequestdisslc( id, query )
        if nil == query.mod or query.mod ~= 'disslc' then
            return nil, 'fail'
        end

        local pool_slc_disbaseline = query.pool_slc_disbaseline -- DIS 显示基准值
        local pool_slc_diswave = query.pool_slc_diswave --DIS 波动额
        local pool_slc_disinterval = query.pool_slc_disinterval --DIS 下降间隔时间
        local pool_slc_disdownpar = query.pool_slc_disdownpar --DIS 下降率
        local update_time = os.time()

        local data = {}
        data.disbaseline = pool_slc_disbaseline
        data.valdown_parl = pool_slc_disdownpar
        data.valdown_time = pool_slc_disinterval
        data.wave_val = pool_slc_diswave
        data.update_time = update_time

        local result = do_redis({"hmset", PDEFINE.REDISKEY.YOU9API.disslc, data})
        LOG_DEBUG("processRequestdisslc do_redis data:", data, " result:", result)

        local returndata = {}
        returndata.code=200
        returndata.error = "SUCCESS"

        return PDEFINE.RET.SUCCESS, cjson.encode(returndata)
    end

    --争霸彩设置
    local function processRequestdiszbc( id, query )
        if nil == query.mod or query.mod ~= 'diszbc' then
            return nil, 'fail'
        end

        local pool_zbc_disbaseline = query.pool_zbc_disbaseline -- DIS 显示基准值
        local pool_zbc_diswave = query.pool_zbc_diswave --DIS 波动额
        local pool_zbc_disinterval = query.pool_zbc_disinterval --DIS 下降间隔时间
        local pool_zbc_disdownpar = query.pool_zbc_disdownpar --DIS 下降率
        local update_time = os.time()

        local data = {}
        data.disbaseline = pool_zbc_disbaseline
        data.valdown_parl = pool_zbc_disdownpar
        data.valdown_time = pool_zbc_disinterval
        data.wave_val = pool_zbc_diswave
        data.update_time = update_time

        local result = do_redis({"hmset", PDEFINE.REDISKEY.YOU9API.diszbc, data})
        LOG_DEBUG("processRequestdiszbc do_redis data:", data, " result:", result)

        local returndata = {}
        returndata.code=200
        returndata.error = "SUCCESS"

        return PDEFINE.RET.SUCCESS, cjson.encode(returndata)
    end

    --玩家中奖控制
    local function processRequestrewardrate( id, query, body )
        if nil == query.mod or query.mod ~= 'rewardrate' then
            return nil, 'fail'
        end
        --[[
             GET参数：
                t:type 1是玩家  2是代理
                st:开始时间 时间戳 秒
                vt:有效时间  秒
                v:控制数据
        ]]
        local starttime = tonumber(query.st_p)
        local validtime = tonumber(query.vt_p)
        local value_data = tonumber(query.v_p)
        local endtime = starttime + validtime
        local now = os.time()

        if endtime > now then
            local resttime = endtime - now
            local redisrewardkey = ""
            
            if tonumber(query.t_p) == 1 then
                redisrewardkey = PDEFINE.REDISKEY.YOU9API.rewardrate_user
            else
                redisrewardkey = PDEFINE.REDISKEY.YOU9API.rewardrate_agent
            end
            local msg = urldecode(body)
            LOG_DEBUG("processRequestrewardrate data:", msg)
            --[[
                POST参数:                 
                {
                    "users":[123,456,789]
                }
            ]]
            
            local jsondata = cjson.decode(msg)
            local size = #jsondata.users
            if size > 0 then
                for i=1,size do
                    local uid = math.floor(jsondata.users[i])
                    do_redis( {"setex", redisrewardkey..":"..uid, value_data, math.floor(resttime)}, uid )
                end
            end
        end

        return PDEFINE.RET.SUCCESS, 'succ'
    end

    local function processRequestgetgameidlist(id, query)
        return PDEFINE.RET.SUCCESS, cjson.encode(PDEFINE_GAME.OPEN)
    end

    --! 获取配置文件
    local function processConf(id, query)
        local cfg = {}
        if query.cat == 'gamelist' then
            cfg = PDEFINE_GAME.OPEN
        end
        return PDEFINE.RET.SUCCESS, cjson.encode(cfg)
    end
    --获取游戏列表
    local function processRequestgetgamelist( id, query )
        LOG_DEBUG("processRequestgetgamelist query:", query)
        local lang = tonumber(query.lang)
        local uniq = query.uniq or 0 
        uniq = math.floor(tonumber(uniq))  --是否按照gameid 去重, 因为一个gameid 属于多个分类
        local rs = {}
        local ok, all_game_type_list = pcall(cluster.call, "master", ".gamemgr", "getAll")
        if not ok then
            LOG_ERROR("getgamelistfail ok:false")
            return PDEFINE.RET.ERROR.CALL_FAIL, rs
        end

        rs.data = {}
        local repeat_table = {}
        for gametype,gametable in pairs(all_game_type_list) do
            for _,row in pairs(gametable) do
                    if uniq == 1 then 
                        if repeat_table[tonumber(row.id)] == nil then
                            local gameinfo = {}
                            gameinfo.id = tonumber(row.id)
                            gameinfo.name = row.title
                            gameinfo.status = row.status
                            gameinfo.type = row.type
                            gameinfo.tag = row.gametag
                            gameinfo.ord = row.ord --游戏在分类中的排序
                            gameinfo.collector = row.collector or 0 --游戏收藏人数
                            table.insert(rs.data, gameinfo)
                            repeat_table[gameinfo.id] = gameinfo.id
                        end
                    else
                        local gameinfo = {}
                        gameinfo.id = tonumber(row.id)
                        gameinfo.name = row.title
                        gameinfo.status = row.status
                        gameinfo.type = row.type
                        gameinfo.tag = row.gametag
                        gameinfo.ord = row.ord --游戏在分类中的排序
                        gameinfo.collector = row.collector or 0 --游戏收藏人数
                        table.insert(rs.data, gameinfo)
                        repeat_table[gameinfo.id] = gameinfo.id
                    end
            end
        end

        -- LOG_DEBUG("processRequestgetgamelist rs:", cjson.encode(rs))
        return PDEFINE.RET.SUCCESS, cjson.encode(rs)
    end

    --给游戏在分类中设定排序
    local function processRequestsetgameord( id, query, body )
        LOG_DEBUG("processRequestsetgametag query:", query)
        local gameid = query.gameid --游戏id
        local ord = query.ord --排序数字
        local type = query.type --设置分类
        local rs = 'succ'
        local ok,code = pcall(cluster.call, "master", ".gamemgr", "setGameOrd", gameid, ord, type)
        if not ok then
            rs = 'fail'
            return PDEFINE.RET.ERROR.CALL_FAIL
        end
        if PDEFINE.RET.SUCCESS ~= code then
            rs = 'fail'
        end
        return code, rs
    end

    --给游戏设置等级锁
    local function processRequestsetgamelevel( id, query, body )
        LOG_DEBUG("processRequestsetgamelevel query:", query)
        local gameids = query.gameids --游戏列表 用,分隔
        local level = query.level --设置的等级
        local rs = 'succ'
        local ok,code = pcall(cluster.call, "master", ".gamemgr", "setGameLevel", gameids, level)
        if not ok then
            rs = 'fail'
            return PDEFINE.RET.ERROR.CALL_FAIL
        end
        if PDEFINE.RET.SUCCESS ~= code then
            rs = 'fail'
        end
        return code, rs
    end

    --给游戏打tag
    local function processRequestsetgametag( id, query, body )
        LOG_DEBUG("processRequestsetgametag query:", query)
        local gameids = query.gameids --游戏列表 用,分隔
        local tag = query.tag --设置的tag
        local rs = 'succ'
        local ok,code = pcall(cluster.call, "master", ".gamemgr", "setGameTag", gameids, tag)
        if not ok then
            rs = 'fail'
            return PDEFINE.RET.ERROR.CALL_FAIL
        end
        if PDEFINE.RET.SUCCESS ~= code then
            rs = 'fail'
        end
        return code, rs
    end

    --给打tag的游戏设置排序
    local function processRequestsetgametagord( id, query, body )
        LOG_DEBUG("processRequestsetgametagord query:", query)
        local gameids = query.gameids --游戏列表 用,分隔
        local ord = query.ord --为打了tag的游戏排序
        local type = query.type --设置分类
        local rs = 'succ'
        local ok,code = pcall(cluster.call, "master", ".gamemgr", "setGameTagOrd", gameids, ord, type)
        if not ok then
            rs = 'fail'
            return PDEFINE.RET.ERROR.CALL_FAIL
        end
        if PDEFINE.RET.SUCCESS ~= code then
            rs = 'fail'
        end
        return code, rs
    end

    --获取游戏概率配置
    local function processRequestgetgamerateconf( id, query )
        LOG_DEBUG("processRequestgetgamerateconf query:", query)
        local rs = {}
        local gameid = tonumber(query.gameid)
        local t_type = tonumber(query.type)
        if gameid == nil or t_type == nil then
            LOG_ERROR("getgamerateconffail gameid nil:")
            return PDEFINE.RET.ERROR.CALL_FAIL, rs
        end

        local ok, game = pcall(cluster.call, "master", ".gamemgr", "getRow", gameid)
        if not ok or game == nil then
            LOG_ERROR("getgamerateconffail ok:", ok," game:", game)
            return PDEFINE.RET.ERROR.CALL_FAIL, rs
        end
        -- LOG_DEBUG("processRequestgetgamerateconf game:", game)
        local control
        if game.control == nil or game.control == "" then
            control = "{}"
        else
            local controljson = cjson.decode(game.control)
            -- controljson = controljson[t_type]
            if controljson == nil then
                control = "{}"
            else
                control = cjson.encode(controljson)
            end
        end
        
        rs.data = control
        LOG_DEBUG("processRequestgetgamerateconf rs:", rs)
        return PDEFINE.RET.SUCCESS, cjson.encode(rs)
    end

    --设置游戏概率配置
    local function processRequestsetgamerateconf( id, query, body )
        LOG_DEBUG("processRequestsetgamerateconf query:", query, " body:", body)
        local gameid = tonumber(query.gameid)
        local t_type = tonumber(query.type)
        if gameid == nil or t_type == nil then
            LOG_ERROR("setgamerateconffail gameid nil :")
            return PDEFINE.RET.ERROR.PARAM_ILLEGAL
        end
        --简单检查 看看是不是json数据
        local ok,resp = pcall(jsondecode,urldecode(body))
        if not ok then
            LOG_ERROR("setgamerateconffail not json")
            return PDEFINE.RET.ERROR.PARAM_ILLEGAL
        end
        local callok = pcall(cluster.call, "master", ".gamemgr", "setgamerateconf", gameid, t_type, resp)
        if not callok then
            LOG_ERROR("setgamerateconffail callok false")
            return PDEFINE.RET.ERROR.CALL_FAIL
        end

        return PDEFINE.RET.SUCCESS,'succ'
    end

    --游戏状态切换
    local function processRequestsetgameswitch( id, query, body )
        LOG_DEBUG("processRequestsetgameswitch query:", query, " body:", body)
        if #body < 5 then
            LOG_ERROR("gameswitchfail length error")
            return PDEFINE.RET.ERROR.PARAM_ILLEGAL
        end
        body = string.sub(body, 5,#body) --去掉 msg=
        local ok,resp = pcall(jsondecode,urldecode(body))
        if not ok then
            LOG_ERROR("gameswitchfail not json")
            return PDEFINE.RET.ERROR.PARAM_ILLEGAL
        end
        -- #1=正常，0=游戏维护中
        local game_switch = tonumber(resp.game_switch)
        if game_switch == nil then
            LOG_ERROR("game_switch not number")
            return PDEFINE.RET.ERROR.PARAM_ILLEGAL
        end
        if game_switch ~= 0 and game_switch ~= 1 then
            LOG_ERROR("game_switch not 0 or 1")
            return PDEFINE.RET.ERROR.PARAM_ILLEGAL
        end
        local game_swl = resp.game_swl --白名单uid
        local game_swl_ip = resp.game_swl_ip --白名单ip

        local ok,retok,result
        if game_switch == 0 then
            pcall(cluster.call, "master", ".servermgr", "apiCloseServer", game_swl, game_swl_ip)
        elseif game_switch == 1 then
            --开启
            pcall(cluster.call, "master", ".servermgr", "apiStartServer", game_swl, game_swl_ip)
        end

        skynet.call(".you9apisdk", "lua", "setgameswitch", game_switch, game_swl)

        return PDEFINE.RET.SUCCESS,'succ'
    end

    --获取服务器信息
    local function processRequestserverinfo( id, query )
        -- LOG_DEBUG("processRequestserverinfo")
        --TODO之后改成servermgr
        local serverinfo = {}
        serverinfo.onlinenum = 0
        serverinfo.uids= {}

        local ok,num, uids = pcall(cluster.call, "master", ".userCenter", "getonlinenum")
        if ok then
            serverinfo.onlinenum = tonumber(num)
            serverinfo.uids = uids
        end
        serverinfo.gameinfo={}

        local gameidstr = query.gameid
        if gameidstr ~= nil then
            local gameidarr = string.split(gameidstr, ',')
            local numok,gameinfo = pcall(cluster.call, "master", ".agentdesk", "getCurSeatByGameid", gameidarr)
            serverinfo.gameinfo = gameinfo
        end

        -- LOG_DEBUG("processRequestserverinfo return:", serverinfo)
        return PDEFINE.RET.SUCCESS,cjson.encode(serverinfo)
    end

    --设置游戏开放状态
    local function processRequestsetgamestatus( id, query )
        local gameid = query.gameid
        if gameid == nil then
            LOG_DEBUG("processRequestsetgamestatus PARAM_ILLEGAL err:")
            return PDEFINE.RET.ERROR.PARAM_ILLEGAL
        end
        local callok,retcode = pcall(cluster.call, "master", ".gamemgr", "changegamestatus", tonumber(gameid))
        if not callok then
            LOG_DEBUG("processRequestsetgamestatus gamemgr changegamestatus err:")
            return PDEFINE.RET.ERROR.CALL_FAIL
        end

        -- local ok, result = pcall(cluster.call, "master", ".gamemgr", "getRow",tonumber(gameid))
        -- if not ok then
            -- LOG_DEBUG("processRequestsetgamestatus gamemgr getRow err:")
            -- return PDEFINE.RET.ERROR.CALL_FAIL
        -- end

        local gamenode = {}
        gamenode.id=gameid
        LOG_DEBUG("processRequestsetgamestatus result:", gamenode)
        
        -- gamenode.name = result.title
        -- gamenode.status = result.status
        return retcode, cjson.encode(gamenode)
    end

    local function processRequestGame( id, query, body)
        local gameid = query.gameid
        if gameid == nil then
            LOG_DEBUG("processRequestGame PARAM_ILLEGAL err:")
            return PDEFINE.RET.ERROR.PARAM_ILLEGAL
        end
        local retcode, callok
        if query.act == 'reload' then
            callok,retcode = pcall(cluster.call, "master", ".gamemgr", "reload", tonumber(gameid))
            if not callok then
                LOG_DEBUG("processRequestGame gamemgr reload err:")
                return PDEFINE.RET.ERROR.CALL_FAIL
            end
        end

        local ok, result = pcall(cluster.call, "master", ".gamemgr", "getRow",tonumber(gameid))
        if not ok then
            LOG_DEBUG("processRequestGame gamemgr getRow err:")
            return PDEFINE.RET.ERROR.CALL_FAIL
        end
        LOG_DEBUG("processRequestGame result:", result)

        local gamenode = {}
        gamenode.id=gameid
        gamenode.name = result.title
        gamenode.status = result.status
        return retcode,cjson.encode(gamenode)
    end

    --获取平台的订单详情
    local function  processRequestgetplatformdetail( id, query )
        LOG_DEBUG("processRequestgetplatformdetail: query:", query)
        local uid = query.uid
        local platform = query.platform
        local starttime = query.starttime
        local endtime = query.endtime
        if uid == nil or starttime == nil or endtime == nil then
            LOG_DEBUG("processRequestgetplatformdetailerr: PARAM_ILLEGAL")
            return PDEFINE.RET.ERROR.PARAM_ILLEGAL
        end
        local playerInfo = player_tool.getPlayerInfo( uid )
        if playerInfo == nil then
            LOG_DEBUG("processRequestgetplatformdetailerr: playerInfo NIL")
            return PDEFINE.RET.ERROR.PLAYER_NOT_FOUND
        end

        LOG_DEBUG("processRequestgetplatformdetailerr: platform err")
        return PDEFINE.RET.ERROR.CALL_FAIL
    end

    --后台请求现在的服务器列表
    --@id 
    --@query 请求内容
    --@return
    --[[
        servers:
        {
            "node": //服务器的类型 login/game/node/master/api
            {
                "node1"://服务器的名称
                {
                    "name":"node1", 
                    "status":0, //0表示正常 1维护中
                },
                "node2":
                {
                    "name":"node2",
                    "status":1, //0表示正常 1维护中
                }
            },
            "api":
            {
                "api1":
                {
                    "name":"api1", 
                    "status":0, //0表示正常 1维护中
                },
                "api2":
                {
                    "name":"api2",
                    "status":1, //0表示正常 1维护中
                }
            }
        }
    ]]
    local function processRequestgetserverlist( id, query )
        local callok,serverlist = pcall(cluster.call, "master", ".servermgr", "getServerList")
        if not callok then
            LOG_DEBUG("processRequestgetserverlist CALL_FAIL")
            return PDEFINE.RET.ERROR.CALL_FAIL
        end

        local rs = {}
        rs.servers={}
        --[[
            serverlist = 
            {
                "node1"={
                    "name" = serverinfo.servername
                    "status" = SERVER_STATUS.start
                    "tag" = serverinfo.tag
                    "freshtime" = os.time()
                    "serverinfo" = serverinfo
                }
            }
        ]]
        for servername,serverinfo in pairs(serverlist) do
            local tag = serverinfo.tag
            local status = serverinfo.status
            if rs.servers[tag] == nil then
                rs.servers[tag] = {}
            end
            rs.servers[tag][servername] = {name=servername,status=status}
        end

        LOG_DEBUG("processRequestgetserverlist return:", cjson.encode(rs))
        return PDEFINE.RET.SUCCESS,cjson.encode(rs)
    end

    --关闭server
    --@id
    --@query 请求参数
    --@body servername=api1,api2,api3
    --@return 执行结果 succ表示成功 fail表示失败
    local function processRequestcloseserver( id, query, body )
        LOG_DEBUG("processRequestcloseserver query:", query, "body:", body)
        if #body < 5 then
            LOG_ERROR("gameswitchfail length error")
            return PDEFINE.RET.ERROR.PARAM_ILLEGAL
        end
        body = string.sub(body, string.len("servername=") + 1, #body)
        local servername = body --多个name用英文逗号分隔
        -- local servername = query.servername --多个name用英文逗号分隔
        local servers = string.split(servername,',')
        local callok,code = pcall(cluster.call, "master", ".servermgr", "apiChangeStatus", servers, PDEFINE.SERVER_STATUS.weihu)
        if not callok then
            LOG_DEBUG("processRequestcloseserver CALL_FAIL")
            return PDEFINE.RET.ERROR.CALL_FAIL
        end

        if code ~= PDEFINE.RET.SUCCESS then
            LOG_ERROR("processRequestcloseserver code:", code)
            return PDEFINE.RET.SUCCESS,"fail"
        else
            return PDEFINE.RET.SUCCESS,"succ"
        end
    end

    -- 后台处理举报： 1.给被举报人发邮件；2：给举报人发邮件；3：直接屏蔽发言(不在此处理)
    local function processRequestReport(id, query)
        if nil == query.mod or query.mod ~= 'report' then
            return nil, 'fail'
        end
        local ok, retok
        local uid = tonumber(query.uid or 0) --游戏id
        local mailid = genMailId()
        local mailInfo = {}
        mailInfo.sendtime = os.time()
        mailInfo.attach = '[]'
        mailInfo.fromuid = 0
        mailInfo.uid = uid
        mailInfo.mailid = mailid
        mailInfo.type = PDEFINE.MAIL_TYPE.SYSTEM
        mailInfo.received = 1
        mailInfo.hasread = 0
        mailInfo.sysMailID = 0

        if query.act == 'send2Reporter' then --发给举报人
            mailInfo.title = "False Report"
            mailInfo.msg = 'You have submitted a false report. Please be sure to go through our chat guidelines before reporting again. Thanks for you help with keeping the chat safe.'
            mailInfo.msg_al = "لقد قمت بإبلاغ خاطئ. يرجى التأكد من اتباع إرشادات الدردشة الخاصة بنا قبل الإبلاغ مرة أخرى. شكرا لمساعدتك في الحفاظ على دردشة آمنة.";
            mailInfo.title_al = "تقرير خاطئ";
        elseif query.act == 'send2Other' then --发给被举报人
            mailInfo.title = "Player Warning"
            mailInfo.msg  = "A message you sent has been reported. Please be careful when chatting with others. And be sure to go through the chat guidelines. A second offense could result in a temporary chat ban."
            mailInfo.title_al = "تحذير اللاعب"
            mailInfo.msg_al = "تم الإبلاغ عن الرسالة التي أرسلتها. من فضلك كن حذرا عند الدردشة مع الاخرين. وتأكد من متابعة إرشادات الدردشة. قد تؤدي المخالفة الثانية إلى حظر مؤقت للدردشة."
        end
        ok, retok = pcall(cluster.call, "master", ".userCenter", "addUsersMail", math.floor(uid), mailInfo)
        if retok and ok then
            return PDEFINE.RET.SUCCESS, 'succ'
        end
        return PDEFINE.RET.SUCCESS, 'fail'
    end

    -- 控制策略修改
    local function processRequestStrategy(id, query)
        if nil == query.mod or query.mod ~= 'strategy' then
            return nil, 'fail'
        end
        local ok, retok, result
        local id = query.id or ""--策略id
        local act = query.act --操作类型: add:新增 update:更新 del:删除
        local gameid = query.gameid --游戏id
        ok, retok = pcall(cluster.call, "master", ".strategymgr", "reloadStrategy", act, id, gameid)
        if retok and ok then
            return PDEFINE.RET.SUCCESS, 'succ'
        end
        return PDEFINE.RET.SUCCESS, 'fail'
    end

        --后台邮件发放接口
    local function processRequestMail(id, query)
        if nil == query.mod or query.mod ~= 'mail' then
            return nil, 'fail'
        end
        local ok, retok, result
        local uids = query.uids or ""--游戏id
        local title = query.title
        local msg = query.msg
        local title_al = query.title_al
        local msg_al = query.msg_al
        local stype = query.type
        local attachjson = query.attach
        local svip = query.svip or ""
        local rate = query.rate or ""
        local remark = query.remark or ""
        local creator = query.creator or ""
        local ok, attach = pcall(jsondecode, attachjson)
        local mailInfo = {}
        mailInfo.uids = uids
        mailInfo.fromuid = 0
        mailInfo.type = stype
        mailInfo.msg = msg
        mailInfo.title = title
        mailInfo.msg_al = msg_al
        mailInfo.title_al = title_al
        mailInfo.svip = svip
        mailInfo.rate = rate
        mailInfo.remark = remark
        mailInfo.creator = creator
        mailInfo.attach = {}
        if ok and type(attach) == 'table' then
            for typeid, count in pairs(attach) do
                table.insert(mailInfo.attach, {type = math.floor(typeid), count= math.floor(count)})
            end
        end
        -- if attach_id ~= nil and attach_count ~= nil and attach_count>0 then
            -- table.insert(mailInfo.attach, {type = math.floor(attach_id), count = math.floor(attach_count)})
        -- end
        if query.act == 'sendMail' then
            ok, retok, result = pcall(cluster.call, "master", ".userCenter", "systemMail",mailInfo)
            if retok == PDEFINE.RET.SUCCESS and ok then
                return PDEFINE.RET.SUCCESS, 'succ'
            else
                return retok, 'fail'
            end
        end
        return PDEFINE.RET.SUCCESS, 'fail'
    end

    skynet.start(function()
        skynet.dispatch("lua", function (_, _, id)
            socket.start(id)
            -- limit request body size to 64k (you can pass nil to unlimit)
            local code, url, method, header, body = httpd.read_request(sockethelper.readfunc(id), 65536)
            if code then
                if code ~= 200 then
                    response(id, code)
                else
                    local code, resp

                    --if header.host then
                    --    table.insert(tmp, string.format("host: %s", header.host))
                    --end
                    local path, query = urllib.parse(url)
                    --table.insert(tmp, string.format("path: %s", path))
                    LOG_DEBUG("query is:", query)
                    if query then
                        local q = urllib.parse_query(query)
                        if q.mod == "config" then
                            code, resp = processRequestConfig(id, q)
                        elseif q.mod == "sess" then
                            code, resp = processRequestSess(id, q)
                        elseif q.mod == "maintask" then 
                            code, resp = processRequestMaintask(id, q)
                        elseif q.mod == "shop" then 
                            code, resp = processRequestShop(id, q)
                        elseif q.mod == 'chat' then
                            code, resp = processRequestChat(id, q)
                        elseif q.mod == "bindfb" then 
                                code, resp = processRequestbindFace(id, q)
                        elseif q.mod == "sys" then
                            code, resp = processRequestSys(id, q)
                        elseif q.mod == "coin" then
                            code, resp = processRequestCoin(id, q)
                        elseif q.mod == "control" then
                            code, resp = processRequestControl(id, q)
                        elseif q.mod == 'user' then
                            local body_data = urllib.parse_query(body)
                            code, resp = processRequestUser(id, q, body_data)
                        elseif q.mod == 'pay' then
                            local body_data = urllib.parse_query(body)
                            code, resp = processRequestPay(id, q, body_data)
                        elseif q.mod == 'account' then
                            code, resp = processRequestAccount(id, q)
                        elseif q.mod == 'nickname' then
                            code, resp = processRequestNickName(id, q)
                        elseif q.mod == "disbigbang" then
                             code, resp = processRequestDisbigbang(id, q)       
                        elseif q.mod == "bigbangreward" then
                            code, resp = processRequestBigbangreward(id, q)
                        elseif q.mod == "redbagsetting" then
                            code, resp = processRequestredbagsetting(id, q)
                        elseif q.mod == "dispooljp" then
                            code, resp = processRequestdispooljp(id, q)
                        elseif q.mod == "disslc" then
                            code, resp = processRequestdisslc(id, q)
                        elseif q.mod == "diszbc" then
                            code, resp = processRequestdiszbc(id, q)
                        elseif q.mod == "apinotice" then
                            code, resp = processRequestapinotice(id, q, body)
                        elseif q.mod == "pushnotice" then
                            code, resp = processPushNotice(id, q, body)
                        elseif q.mod == "rewardrate" then
                            code, resp = processRequestrewardrate(id, q, body)
                        elseif q.mod == "getgamelist" then
                            code, resp = processRequestgetgamelist(id, q)
                        elseif q.mod == "getgameidlist" then
                            code, resp = processRequestgetgameidlist(id, q)
                        elseif q.mod == "config" then
                            code, resp = processConf(id, q)
                        elseif q.mod == "getgamerateconf" then
                            code, resp = processRequestgetgamerateconf(id, q)
                        elseif q.mod == "setgamerateconf" then
                            code, resp = processRequestsetgamerateconf(id, q, body)
                        elseif q.mod == "gameswitch" then
                            code, resp = processRequestsetgameswitch(id, q, body)
                        elseif q.mod == "serverinfo" then
                            code, resp = processRequestserverinfo(id, q)
                        elseif q.mod == "setgamestatus" then
                            code, resp = processRequestsetgamestatus(id, q)
                        elseif q.mod == "getplatformdetail" then
                            code, resp = processRequestgetplatformdetail(id, q)
                        elseif q.mod == "getserverlist" then
                            code, resp = processRequestgetserverlist(id, q)
                        elseif q.mod == "closeserver" then
                            code, resp = processRequestcloseserver(id, q, body)
                        elseif q.mod == "setgameord" then
                            code, resp = processRequestsetgameord(id, q, body)
                        elseif q.mod == "setgamelevel" then
                            code, resp = processRequestsetgamelevel(id, q, body)
                        elseif q.mod == "setgametag" then
                            code, resp = processRequestsetgametag(id, q, body)
                        elseif q.mod == "setgametagord" then
                            code, resp = processRequestsetgametagord(id, q, body)
                        elseif q.mod == "mail" then
                            code, resp = processRequestMail(id, q)
                        elseif q.mod == "report" then
                            code, resp = processRequestReport(id, q)
                        elseif q.mod == "strategy" then
                            code, resp = processRequestStrategy(id, q)
                        elseif q.mod == "gameswitch" then
                            code, resp = processRequestGame(id, q, body)
                        else
                            processRequest(id, q)
                        end
                    end
                    LOG_DEBUG("code:", code)
                    -- LOG_DEBUG("code:", code, "tmp:", resp)
                    response(id, code, resp, respheader)
                end
            else
                if url == sockethelper.socket_error then
                    skynet.error("socket closed")
                else
                    skynet.error(url)
                end
            end
            socket.close(id)
        end)
    end)

else

    skynet.start(function()
        local agent = {}
        for i= 1, 20 do
            agent[i] = skynet.newservice(SERVICE_NAME, "agent")
        end
        local balance = 1
        local port = skynet.getenv("web_port")
        local id = socket.listen("0.0.0.0", port)
        skynet.error("Listen web port " .. port)
        socket.start(id , function(id, addr)
            -- skynet.error(string.format("%s connected, pass it to agent :%08x", addr, agent[balance]))
            skynet.send(agent[balance], "lua", id)
            balance = balance + 1
            if balance > #agent then
                balance = 1
            end
        end)
    end)

end