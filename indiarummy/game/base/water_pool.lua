local cluster   = require "cluster"
local cjson     = require "cjson"
local api_service = require "api_service"
local slot_water_pool = require "base.slot_water_pool"
local water_pool_nodesk = require "base.water_pool_nodesk"
local player_tool = require "base.player_tool"
local JIANGRONG = false
local water_pool = {}

--扣库存接口
--@param deskInfo（deskInfo.gameid 如果有子游戏那么是 deskInfo.subGame.subGameId）
--@param user
--@param win_coin
--@param log
--@return 扣库存结果(true/false),loanid(扣库存成功是true), result{pooljp poolnormal}
function water_pool.delStock(user, win_coin, deskInfo, log, poolround_id)
	local paramlog = concatStr(user,win_coin,deskInfo,log)
	assert(deskInfo, "deskInfonil "..paramlog)
    assert(win_coin > 0, "win_coin<=0 "..paramlog)
    assert(user, "usernil "..paramlog)

	local gameid = deskInfo.gameid
	local subgameid = 0
	-- if deskInfo.subGame ~= nil then
	-- 	if deskInfo.subGame.subGameId ~= nil and deskInfo.subGame.subGameId > 0 then
	-- 		subgameid = deskInfo.subGame.subGameId
	-- 	end
	-- end
	-- local ok, gameInfo = pcall(cluster.call, "master", ".gamemgr", "getRow", gameid)
	-- local gamename =  gameInfo.title

	local gameinfo_para = {
	    gameid = gameid, --游戏id
	    deskid = deskInfo.deskid, --桌子id
	    subgameid = subgameid, --子游戏id
	    deskuuid = deskInfo.uuid, --桌子唯一id
	}
	local poolround_para = {
		uniid = deskInfo.uuid,
		poolround_id = poolround_id, --pr的唯一id
	}
	local ok, result = api_service.callAPIMod( "delStock", user.uid, win_coin, gameinfo_para, poolround_para)
	if ok == PDEFINE.RET.SUCCESS then	
		return true, result.loanid, result
	end
	return false, nil
end

--借款
--@param deskInfo（deskInfo.gameid 如果有子游戏那么是 deskInfo.subGame.subGameId）
--@param loan_coin
--@return 借款结果(true/false),loanid(借款成功是true)
function water_pool.loanpoolnormal(deskInfo, loan_coin, poolround_id)
	return true, 10000
	-- local paramlog = concatStr(deskInfo,loan_coin)
	-- if JIANGRONG then
	-- 	if type(deskInfo)=="number" then
	-- 		--老接口 第一个参数是gameid
	-- 		return true,{loanid=1}
	-- 	end
	-- end
	-- assert(loan_coin > 0, "loan_coin<=0 "..paramlog)
	-- local gameid = deskInfo.gameid
	-- local subgameid = 0
	-- -- if deskInfo.subGame ~= nil then
	-- -- 	if deskInfo.subGame.subGameId ~= nil and deskInfo.subGame.subGameId > 0 then
	-- -- 		subgameid = deskInfo.subGame.subGameId
	-- -- 	end
	-- -- end

	-- local gameinfo_para = {
	--     gameid = gameid, --游戏id
	--     deskid = deskInfo.deskid, --桌子id
	--     subgameid = subgameid, --子游戏id
	-- 	uid = 0, --玩家id，桌游捕鱼借款不限制玩家
	-- }

	-- local poolround_para = {
	-- 	uniid = deskInfo.uuid, --唯一id
	-- 	poolround_id = poolround_id, --pr的唯一id
	-- }

	-- local ok, result = api_service.callAPIMod("loanpoolnormal", loan_coin, gameinfo_para, poolround_para)
	-- if ok == PDEFINE.RET.SUCCESS then
	-- 	return true, tonumber(result.loanid)
	-- end
	-- return false, nil
end

--还款
function water_pool.revertpoolnormal( loan_coin, loanid, deskInfo, poolround_id)
	return true, nil
	-- local paramlog = concatStr(loan_coin,loanid,deskInfo)
	-- if JIANGRONG then
	-- 	if type(deskInfo)=="number" or deskInfo == nil then
	-- 		--老接口 第3个参数是loanid
	-- 		return true,1
	-- 	end
	-- end
	-- assert(loan_coin > 0, "loan_coin<=0 "..paramlog)
	-- if loanid == nil then
	-- 	return false
	-- end
	-- local gameid = deskInfo.gameid
	-- local subgameid = 0
	-- -- if deskInfo.subGame ~= nil then
	-- -- 	if deskInfo.subGame.subGameId ~= nil and deskInfo.subGame.subGameId > 0 then
	-- -- 		subgameid = deskInfo.subGame.subGameId
	-- -- 	end
	-- -- end

	-- local gameinfo_para = {
	--     gameid = gameid, --游戏id
	--     deskid = deskInfo.deskid, --桌子id
	--     subgameid = subgameid, --子游戏id
	-- }

	-- local poolround_para = {
	-- 	uniid = deskInfo.uuid, --唯一id
	-- 	poolround_id = poolround_id, --pr的唯一id
	-- }

	-- local ok, result = api_service.callAPIMod( "revertpoolnormal", loan_coin, loanid, gameinfo_para, poolround_para)
	-- assert(ok == PDEFINE.RET.SUCCESS, concatStr("revertpoolnormalcode", ok, result, gameid, subgameid, paramlog))
	-- if ok == PDEFINE.RET.SUCCESS then
	-- 	return true, result
	-- end
end

-- 上报结果
-- user
-- {
-- 	send_api_result_userlist = { --名字取长一点防止重复 win_coin是净胜负
-- 		[1]={uid=xx,bet_coin=xx,win_coin=xx,winjp_coin=xx,prize_result,before_coin=xx,after_coin=xx},
-- 		[1]={uid=xx,bet_coin=xx,win_coin=xx,winjp_coin=xx,prize_result,before_coin=xx,after_coin=xx},
-- 	}
-- }
function water_pool.sendGameLog(user, deskInfo, prize_result, ex1, ex2, poolround_id)
	local paramlog = concatStr(user,deskInfo,prize_result,ex1,ex2)
	-- LOG_DEBUG("sendGameLog user:",user,"deskInfo:",deskInfo,"prize_result:",prize_result,"ex1:",ex1,"ex2:",ex2)
	assert(deskInfo, "deskInfonil "..paramlog)
	-- assert(prize_result, "prize_resultnil "..paramlog)
	assert(user, "usernil "..paramlog)
	if prize_result == nil then
		prize_result = {}
	end
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
		local sendprize = prize_result_json
		local win_coin = tonumber(v.win_coin) + v.bet_coin
		local after_coin = 0
		local before_coin = 0
		if v.uid > 0 then
			if v.before_coin ~= nil then
	            before_coin = v.before_coin
	            after_coin =  v.after_coin
	        else
	            local player = player_tool.getPlayerInfo(math.floor(v.uid))

				LOG_ERROR("water_pool player.coin: " .. player.coin , ' uid:', v.uid );
				if player == nil then
					LOG_ERROR("player is nil, uid = ", v.uid, paramlog)
				else
					after_coin = player.coin
					before_coin = after_coin - (win_coin - v.bet_coin)
				end
				LOG_ERROR("water_pool player after_coin: " .. player.coin , ' uid:', v.uid );

				LOG_ERROR("water_pool player win_coin: " .. win_coin , ' uid:', v.uid );
				LOG_ERROR("water_pool player bet_coin: " .. v.bet_coin , ' uid:', v.uid );
				LOG_ERROR("water_pool player before_coin: " .. before_coin , ' uid:', v.uid );
	        end
		end
		if v.prize_result ~= nil then
			sendprize = cjson.encode(v.prize_result)
		end

		local gameinfo_para = {
            gameid = gameid, --游戏id
            deskid = deskInfo.deskid, --桌子id
            subgameid = subgameid, --子游戏id
            deskuuid = deskInfo.uuid, --桌子唯一id
            roundinfo = {
                bet = v.bet_coin, --下注
                win = win_coin, --赢钱
                result = sendprize, --游戏结果
            }
        }

        local poolround_para = {
			uniid = deskInfo.uuid, --唯一id
			poolround_id = poolround_id, --pr的唯一id
        }

        api_service.callAPIMod("sendGameLog", v.uid, before_coin, after_coin, gameinfo_para, poolround_para)
	end

	return true
end

function water_pool.sendLog(users, deskInfo, prize_result, poolround_id)
	local gameid = deskInfo.gameid
	local prize_result_json = cjson.encode(prize_result)

	for k,v in pairs(users) do
		local win_coin = tonumber(v.win_coin)
		local after_coin = 0
		local before_coin = 0

		if v.uid and v.uid > 0 then
			if v.before_coin ~= nil then
	            before_coin = v.before_coin
	            after_coin =  v.after_coin
	        else
	            local player = player_tool.getPlayerInfo(math.floor(v.uid))
				if player then
					after_coin = player.coin
					before_coin = after_coin - (win_coin)
				end
	        end
			
			local gameinfo_para = {
				gameid = gameid, --游戏id
				deskid = deskInfo.deskid, --桌子id
				roundinfo = {
					win = win_coin, --赢钱
					bet = 0,
					result = prize_result_json, --游戏结果
				}
			}
			
			local poolround_para = {
				uniid = deskInfo.uuid, --唯一id
				poolround_id = poolround_id, --pr的唯一id
			}
			--print(before_coin, after_coin, gameinfo_para, poolround_para)
			
			api_service.callAPIMod("sendGameLog", v.uid, before_coin, after_coin, gameinfo_para, poolround_para)
		end
	end
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
function water_pool.loanpool_local(gameid,coin)
	if coin < 0 then
		LOG_ERROR("loanpool_local err coin<0 gameid:", gameid ," coin:", coin)
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
function water_pool.revertpool_local(loan_coin,gameid_p, is_bet)
	if loan_coin < 0 then
		LOG_ERROR("revertpool_local err coin<0 gameid:", gameid_p, " coin:", loan_coin)
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
			water_pool_rate = 200  --默认2%
			do_redis({"set", rediskey_rate, tonumber(water_pool_rate)})
		end

		local_coin =  loan_coin * water_pool_rate / 10000
		do_redis({"incrbyfloat", rediskey_local, local_coin})  --抽水统计
	end

	local rediskey = PDEFINE.REDISKEY.GAME.waterpool..":"..gameid_p
	do_redis({"incrbyfloat", rediskey, loan_coin - local_coin})
	LOG_DEBUG("revertpool_local gameid:", gameid_p, " coin:", loan_coin, "  local:",local_coin)
end

function water_pool.getrewardrate( uid )
	local ok,control = api_service.callAPIMod( "getrewardrate", uid )
	if ok ~= PDEFINE.RET.SUCCESS then
		return PDEFINE.DEFAULTREWARDRATE
	end
	return control
end

--新开始一轮借款或者扣库存
--@param deskInfo
--@param uid
--@param pooltype PDEFINE.POOL_TYPE
function water_pool.startPoolRound( deskInfo, uid, pooltype )
	local paramlog = concatStr(deskInfo,uid,pooltype)
	assert(deskInfo, "deskInfonil "..paramlog)
	assert(pooltype, "pooltypenil "..paramlog)

	return insertPoolRoundInfo()
end

--结束一轮借款或者扣库存并自动发送彩池事件 需要在给玩家发了钱以后执行
--@param deskInfo
--@param pooltype PDEFINE.POOL_TYPE
--@param coin
--@param user
--@param loanid 如果不为空就会发送彩池事件
function water_pool.endPoolRoundAndEvent(deskInfo, pooltype, user, loanid, coin, poolround_id)
	local paramlog = concatStr(deskInfo,pooltype,user,loanid,coin)
	assert(deskInfo, "deskInfonil "..paramlog)
	assert(pooltype, "pooltypenil "..paramlog)
	if loanid ~= nil and tonumber(loanid) > 0 then
		assert(coin, "coinnil "..paramlog)

		local evtype
		if pooltype == PDEFINE.POOL_TYPE.delstock then
			evtype = PDEFINE.POOLEVENT_TYPE.delstock
		else
			evtype = PDEFINE.POOLEVENT_TYPE.loan
		end
		water_pool.poolEvent(deskInfo, user, evtype, loanid, coin, poolround_id)
	end

	water_pool.endPoolRound(user.uid, deskInfo, pooltype, poolround_id)
end

--结束一轮借款或者扣库存
--@param deskInfo
--@param pooltype PDEFINE.POOL_TYPE
function water_pool.endPoolRound(uid, deskInfo, pooltype, poolround_id)

end

--彩池入水
--@param deskInfo
--@param user
--@param coin
function water_pool.pushPool(user, deskInfo, coin, poolround_id)
	local paramlog = concatStr(user, deskInfo, coin)
	assert(deskInfo, "deskInfonil "..paramlog)
	assert(coin > 0, "coin<=0 "..paramlog)

	local gameid = deskInfo.gameid
	local subgameid = 0
	-- if deskInfo.subGame ~= nil then
	-- 	if deskInfo.subGame.subGameId ~= nil and deskInfo.subGame.subGameId > 0 then
	-- 		subgameid = deskInfo.subGame.subGameId
	-- 	end
	-- end
	local uid
	if user ~= nil then
		uid = user.uid
	end

	local gameinfo_para = {
        gameid = gameid, --游戏id
        subgameid = subgameid, --子游戏id
    }

    local poolround_para = {
		uniid = deskInfo.uuid, --唯一id
		poolround_id = poolround_id,
    }
    local code = api_service.callAPIMod("pushPool", uid, coin, gameinfo_para, poolround_para)
	LOG_DEBUG("pushPool code:", code)
	assert(code == PDEFINE.RET.SUCCESS, concatStr("pushPoolcode", code, gameid, paramlog))
end

--彩池事件
--@param deskInfo
--@param user
--@param evtype PDEFINE.POOLEVENT_TYPE
--@param event_id
--@param coin
function water_pool.poolEvent(deskInfo, user, evtype, event_id, coin, poolround_id)
	local paramlog = concatStr(deskInfo, user, evtype, event_id, coin)
	assert(deskInfo, "deskInfonil "..paramlog)
	assert(evtype, "evtypenil "..paramlog)
	assert(event_id, "event_idnil "..paramlog)

	local gameid = deskInfo.gameid
	local subgameid = 0
	-- if deskInfo.subGame ~= nil then
	-- 	if deskInfo.subGame.subGameId ~= nil and deskInfo.subGame.subGameId > 0 then
	-- 		subgameid = deskInfo.subGame.subGameId
	-- 	end
	-- end
	local uid
	if user ~= nil then
		uid = user.uid
	end

	local gameinfo_para = {
        gameid = gameid, --游戏id
        subgameid = subgameid, --子游戏id
        deskuuid = deskInfo.uuid, --桌子唯一id
        roundinfo = {
            event_type = evtype,
            event_id = event_id, --eventid api端传过来的参数
        }
    }

    local poolround_para = {
		uniid = deskInfo.uuid, --唯一id
		poolround_id = poolround_id,
    }

    local code = api_service.callAPIMod("poolEvent", uid, coin, gameinfo_para, poolround_para)
	LOG_DEBUG("poolEvent code:", code)
	assert(code == PDEFINE.RET.SUCCESS, concatStr("poolEventcode", code, gameid, paramlog))
end

local function betpush_water(user, deskInfo, water_coin, gameid, log)
end
local function sendbetresult(user, win_coin, deskInfo, gameid, log, isloan, expiretime)
	return true, {pooljp = 0,poolnormal = win_coin}
end
local function send_result(user, deskInfo, prize_result, loanid, ex1, ex2)
end
local function send_result0(user, deskInfo, bet_coin, addcoin, prize_result, winjp_coin, loanid, ex1, ex2)
end

if JIANGRONG then
	water_pool.betpush_water = betpush_water
	water_pool.sendbetresult = sendbetresult
	water_pool.send_result = send_result
	water_pool.send_result0 = send_result0
end

water_pool.slot = slot_water_pool--专为拉霸使用的
water_pool.nodesk = water_pool_nodesk--没有桌子那类

return water_pool