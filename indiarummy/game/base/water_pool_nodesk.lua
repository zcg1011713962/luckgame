
local cluster   = require "cluster"
local cjson     = require "cjson"
local api_service = require "api_service"
local slot_water_pool = require "base.slot_water_pool"
local player_tool = require "base.player_tool"
local water_pool_nodesk = {}

--扣库存接口
--@param user
--@param win_coin
--@param uniid
--@return 扣库存结果(true/false),loanid(扣库存成功是true), result{pooljp poolnormal}
function water_pool_nodesk.delStock(gameid, uniid, uid, win_coin, poolround_id)
    local paramlog = concatStr(gameid,uniid,uid,win_coin)
    assert(win_coin > 0, "win_coin<=0 "..paramlog)
    assert(uid, "uidnil "..paramlog)
    assert(gameid, "gameidnil "..paramlog)
    assert(uniid, "uniidnil "..paramlog)

    local gameinfo_para = {
        gameid = gameid, --游戏id
        deskid = 0, --桌子id
        subgameid = 0, --子游戏id
    }
    local poolround_para = {
        uniid = uniid,
        poolround_id = poolround_id
    }

    local ok, result = api_service.callAPIMod( "delStock", uid, win_coin, gameinfo_para, poolround_para)
    if ok == PDEFINE.RET.SUCCESS then
        return true, result.loanid, result
    end
    return false, nil
end

--借款
--@param gameid.gameid
--@param loan_coin
--@param uniid
--@return 借款结果(true/false),loanid(借款成功是true)
function water_pool_nodesk.loanpoolnormal(gameid, uniid, loan_coin, poolround_id)
    local paramlog = concatStr(gameid,uniid,loan_coin)
    assert(loan_coin > 0, "loan_coin<=0 "..paramlog)
    assert(gameid, "gameidnil "..paramlog)
    assert(uniid, "uniidnil "..paramlog)

    local gameinfo_para = {
        gameid = gameid, --游戏id
        deskid = 0, --桌子id
        subgameid = 0, --子游戏id
        uid = 0, --玩家id, 桌游，街机，捕鱼接口不做金额限制
    }

    local poolround_para = {
        uniid = uniid, --唯一id
        poolround_id = poolround_id
    }
    local ok, result = api_service.callAPIMod("loanpoolnormal", loan_coin, gameinfo_para, poolround_para)
    if ok == PDEFINE.RET.SUCCESS then
        return true, tonumber(result.loanid)
    end
    return false, nil
end

--还款
function water_pool_nodesk.revertpoolnormal(gameid, uniid, loan_coin, loanid, poolround_id)
    local paramlog = concatStr(gameid, uniid, loan_coin, loanid)
    assert(gameid, "gameidnil "..paramlog)
    assert(uniid, "uniidnil "..paramlog)
    assert(loanid, "loanidnil "..paramlog)
    assert(loan_coin > 0, "loan_coin<=0 "..paramlog)

    local gameinfo_para = {
        gameid = gameid, --游戏id
        deskid = 0, --桌子id
        subgameid = 0, --子游戏id
    }

    local poolround_para = {
        uniid = uniid, --唯一id
        poolround_id = poolround_id,
    }
    local ok, result = api_service.callAPIMod( "revertpoolnormal", loan_coin, loanid, gameinfo_para, poolround_para)
    assert(ok == PDEFINE.RET.SUCCESS, concatStr("revertpoolnormalcode", ok, result, paramlog))
    if ok == PDEFINE.RET.SUCCESS then
        return true, result
    end
end

-- 上报结果
-- user
-- {
--  send_api_result_userlist = { --名字取长一点防止重复 win_coin是净胜负
--      [1]={uid=xx,bet_coin=xx,win_coin=xx,winjp_coin=xx,prize_result=xx},
--      [1]={uid=xx,bet_coin=xx,win_coin=xx,winjp_coin=xx,prize_result=xx},
--  }
-- }
function water_pool_nodesk.sendGameLog(gameid, uniid, user, prize_result, deskid, ex1, ex2, poolround_id)
    local paramlog = concatStr(gameid, uniid, user, prize_result, ex1, ex2)
    -- LOG_DEBUG("sendGameLog user:",user,"uniid",uniid,"prize_result:",prize_result,"ex1:",ex1,"ex2:",ex2)
    assert(gameid, "gameidnil "..paramlog)
    assert(uniid, "uniidnil "..paramlog)
    -- assert(prize_result, "prize_resultnil "..paramlog)
    assert(user, "usernil "..paramlog)
    if prize_result == nil then
        prize_result = {}
    end
    if deskid == nil then
        deskid = 0
    end
    local userList = user
    if user.send_api_result_userlist == nil then
        userList = {}
        userList.send_api_result_userlist = {}
        table.insert(userList.send_api_result_userlist,user)
    end

    local prize_result_json = cjson.encode(prize_result)
    for k,v in pairs(userList.send_api_result_userlist) do
        local sendprize = prize_result_json
        local win_coin = tonumber(v.win_coin) + v.bet_coin
        local after_coin = 0
        local before_coin = 0
        if v.uid > 0 then
            after_coin = player_tool.getPlayerInfo(v.uid).coin
            before_coin = after_coin - (win_coin - v.bet_coin)
        end
        if v.prize_result ~= nil then
            sendprize = cjson.encode(v.prize_result)
        end
        local gameinfo_para = {
            gameid = gameid, --游戏id
            deskid = deskid, --桌子id
            subgameid = 0, --子游戏id
            deskuuid = uniid, --桌子唯一id
            roundinfo = {
                bet = v.bet_coin, --下注
                win = win_coin, --赢钱
                result = prize_result_json, --游戏结果
            }
        }

        local poolround_para = {
            uniid = uniid, --唯一id
            poolround_id = poolround_id,
        }

        api_service.callAPIMod( "sendGameLog", v.uid, before_coin, after_coin, gameinfo_para, poolround_para)
    end

    return true
end

--新开始一轮借款或者扣库存
--@param deskInfo
--@param uid
--@param pooltype PDEFINE.POOL_TYPE
function water_pool_nodesk.startPoolRound( gameid, uniid, uid, pooltype )
    local paramlog = concatStr(gameid, uniid, uid, pooltype)
    assert(gameid, "gameidnil "..paramlog)
    assert(uniid, "uniidnil "..paramlog)
    assert(pooltype, "pooltypenil "..paramlog)
    return insertPoolRoundInfo()
end

--结束一轮借款或者扣库存并自动发送彩池事件 需要在给玩家发了钱以后执行
--@param gameid
--@param pooltype PDEFINE.POOL_TYPE
--@param coin
--@param uid
--@param loanid 如果不为空就会发送彩池事件
function water_pool_nodesk.endPoolRoundAndEvent(gameid, uniid, pooltype, uid, loanid, coin, poolround_id)
    local paramlog = concatStr(gameid, uniid, pooltype, uid, loanid, coin)
    assert(gameid, "gameidnil "..paramlog)
    assert(uniid, "uniidnil "..paramlog)
    assert(pooltype, "pooltypenil "..paramlog)

    if loanid ~= nil and tonumber(loanid) > 0 then
        assert(coin, "coinnil "..paramlog)

        local evtype
        if pooltype == PDEFINE.POOL_TYPE.delstock then
            evtype = PDEFINE.POOLEVENT_TYPE.delstock
        else
            evtype = PDEFINE.POOLEVENT_TYPE.loan
        end
        
        water_pool_nodesk.poolEvent(gameid, uniid, uid, evtype, loanid, coin, poolround_id)
    end

    water_pool_nodesk.endPoolRound(uid, gameid, uniid, pooltype, poolround_id)
end

--结束一轮借款或者扣库存
--@param deskInfo
--@param pooltype PDEFINE.POOL_TYPE
function water_pool_nodesk.endPoolRound(uid, gameid, uniid, pooltype, poolround_id)

end

--彩池入水
--@param gameid
--@param uid
--@param coin
function water_pool_nodesk.pushPool(gameid, uniid, uid, coin, poolround_id)
    local paramlog = concatStr(gameid, uniid, uid, coin)
    assert(gameid, "gameidnil "..paramlog)
    assert(uniid, "uniidnil "..paramlog)
    assert(coin > 0, "coin<=0 "..paramlog)

    local gameinfo_para = {
        gameid = gameid, --游戏id
        subgameid = 0, --子游戏id
    }

    local poolround_para = {
        uniid = uniid, --唯一id
        poolround_id = poolround_id,
    }
    local code = api_service.callAPIMod("pushPool", uid, coin, gameinfo_para, poolround_para)
    LOG_DEBUG("pushPool code:", code)
    assert(code == PDEFINE.RET.SUCCESS, concatStr("pushPoolcode", code, paramlog))
end

--彩池事件
--@param gameid
--@param uid
--@param evtype PDEFINE.POOLEVENT_TYPE
--@param event_id
--@param coin
function water_pool_nodesk.poolEvent(gameid, uniid, uid, evtype, event_id, coin, poolround_id)
    local paramlog = concatStr(gameid, uniid, uid, evtype, event_id, coin)
    assert(gameid, "gameidnil "..paramlog)
    assert(uniid, "uniidnil "..paramlog)
    assert(evtype, "evtypenil "..paramlog)
    assert(event_id, "event_idnil "..paramlog)

    local gameinfo_para = {
        gameid = gameid, --游戏id
        subgameid = 0, --子游戏id
        roundinfo = {
            event_type = evtype,
            event_id = event_id, --eventid api端传过来的参数
        }
    }

    local poolround_para = {
        uniid = uniid, --唯一id
        poolround_id = poolround_id,
    }

    local code = api_service.callAPIMod("poolEvent", uid, coin, gameinfo_para, poolround_para)
    LOG_DEBUG("pushPool code:", code)
    assert(code == PDEFINE.RET.SUCCESS, concatStr("poolEventcode", code, paramlog))
end

return water_pool_nodesk