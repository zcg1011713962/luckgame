
local cluster   = require "cluster"
local cjson     = require "cjson"
local api_service = require "api_service"
local player_tool = require "base.player_tool"
local slot_water_pool = {}

-- 上报结果
-- user
-- {
--  send_api_result_userlist = { --名字取长一点防止重复  win_coin是净胜负
--      [1]={uid=xx,bet_coin=xx,win_coin=xx,winjp_coin=xx,bigbang_coin=xx,beforecoin=xx,aftercoin=xx},
--      [1]={uid=xx,bet_coin=xx,win_coin=xx,winjp_coin=xx,bigbang_coin=xx,bigbang_logtoken=xx},
--  }
-- }
function slot_water_pool.sendGameLog(user, deskInfo, prize_result, ex1, ex2, poolround_id)
    local paramlog = concatStr(user, deskInfo, prize_result, ex1, ex2, poolround_id)
    -- LOG_DEBUG("sendGameLog user:",user,"deskInfo:",deskInfo,"prize_result:",prize_result,"ex1:",ex1,"ex2:",ex2,"poolround_id:",poolround_id)
    assert(deskInfo, "deskInfonil "..paramlog)
    assert(prize_result, "prize_resultnil "..paramlog)
    assert(user, "usernil "..paramlog)

    local gameid = deskInfo.gameid
    local subgameid = 0
    if deskInfo.subGame ~= nil then
        if deskInfo.subGame.subGameId ~= nil and deskInfo.subGame.subGameId > 0 then
            subgameid = deskInfo.subGame.subGameId
        end
    end

    local userList = user
    if user.send_api_result_userlist == nil then
        userList = {}
        userList.send_api_result_userlist = {}
        table.insert(userList.send_api_result_userlist,user)
    end

    local prize_result_json = cjson.encode(prize_result)
    for k,v in pairs(userList.send_api_result_userlist) do
        local win_coin = tonumber(v.win_coin) + v.bet_coin
        local after_coin = 0
        local before_coin = 0
        if v.beforecoin ~= nil then
            before_coin = v.beforecoin
            after_coin =  v.aftercoin
        else
            if v.uid > 0 then
                -- after_coin = player_tool.getPlayerInfo(v.uid).coin
                after_coin = deskInfo.user.coin
                before_coin = after_coin - (win_coin - v.bet_coin)
            end
        end
        local gameinfo_para = {
            gameid = gameid, --游戏id
            deskid = deskInfo.deskid, --桌子id
            subgameid = subgameid, --子游戏id
            deskuuid = deskInfo.uuid, --桌子唯一id
            roundinfo = {
                bet = v.bet_coin, --下注
                win = win_coin, --赢钱
                result = prize_result_json, --游戏结果
            },
            extend1 = ex1 and cjson.encode(ex1) or nil,  -- 自动spin的信息{auto: {total: 100, rest: 10}}
            level = deskInfo.user.level or 0,
        }

        local poolround_para = {
            uniid = deskInfo.uuid, --唯一id
            poolround_id = poolround_id, --pr的唯一id
        }

        api_service.callAPIMod("sendGameLog", v.uid, before_coin, after_coin, gameinfo_para, poolround_para)
    end

    return true
end

--新开始一轮借款或者扣库存
--@param deskInfo
--@param uid
--@param pooltype PDEFINE.POOL_TYPE
--@return poolround_id
function slot_water_pool.startPoolRound(deskInfo, uid)
    local paramlog = concatStr(deskInfo, uid)
    assert(deskInfo, "deskInfonil "..paramlog)

    return insertPoolRoundInfo()
end

--结束一轮借款或者扣库存
--@param deskInfo
--@param pooltype PDEFINE.POOL_TYPE
function slot_water_pool.endPoolRound(uid, deskInfo, poolround_id)

end

--本地水池数值
function slot_water_pool.getpool_local(gameid)
    local rediskey = PDEFINE.REDISKEY.GAME.waterpool..":"..gameid
    local water_pool_l = do_redis({"get", rediskey})
    if water_pool_l then
        return tonumber(water_pool_l)
    end
    return 0
end

--本地水池拿钱
function slot_water_pool.loanpool_local( gameid,coin )
    if coin < 0 then
        LOG_ERROR("loanpool_local err coin<0 gameid:", gameid " coin:", coin)
        return false
    end
    if coin == 0 then
        return true
    end

    local rediskey = PDEFINE.REDISKEY.GAME.waterpool..":"..gameid
    local water_pool_l = do_redis({"get", rediskey})
    if water_pool_l == nil or tonumber(water_pool_l) < coin then
        return false
    end

    do_redis({"incrbyfloat", rediskey, -coin})
    LOG_DEBUG("loanpool_local gameid:", gameid, " coin:", coin)
    return true
end

--本地水池加钱
function slot_water_pool.revertpool_local( loan_coin,gameid_p, is_bet)
    if loan_coin < 0 then
        LOG_ERROR("revertpool_local err coin<0 gameid:", gameid_p " coin:", loan_coin)
        return
    end
    if loan_coin == 0 then
        return
    end
    local local_coin = 0
    if is_bet then
        local rediskey_rate = PDEFINE.REDISKEY.GAME.waterpool_rate..":"..gameid_p
        local rediskey_local = PDEFINE.REDISKEY.GAME.waterpool_local..":"..gameid_p

        --抽水率
        local water_pool_rate = do_redis({"get", rediskey_rate})
        if water_pool_rate == nil then
            water_pool_rate = 100  --默认1%
            do_redis({"set", rediskey_rate, tonumber(water_pool_rate)})
        end

        local_coin =  loan_coin * water_pool_rate / 10000
        do_redis({"incrbyfloat", rediskey_local, local_coin})  --抽水统计
    end

    local rediskey = PDEFINE.REDISKEY.GAME.waterpool..":"..gameid_p
    do_redis({"incrbyfloat", rediskey, loan_coin - local_coin})
    LOG_DEBUG("revertpool_local gameid:", gameid_p, " coin:", loan_coin, "  local:",local_coin)
end

return slot_water_pool