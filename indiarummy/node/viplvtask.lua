local skynet = require "skynet"
local cjson = require "cjson"
local cluster = require "cluster"
local player_tool = require "base.player_tool"

cjson.encode_sparse_array(true)
cjson.encode_empty_table_as_object(false)

local cmd = {}
local handle
local UID
local tranjobTime = 0 --上次转移时间

local STATE = {
    DOING = 0, --进行中，未完成
    WAITGET = 1, --已完成待领取
    GET = 2, --已经领取
}
function cmd.init(uid)
    UID = uid
end

--初始化1条数据
local function initTask(uid, svip)
    local svip = svip or 0
    local sql = string.format("select * from d_svip_task where uid=%d and svip=%d order by id desc limit 1", uid, svip)
    local rs = skynet.call(".mysqlpool", "lua", "execute", sql)
    if #rs == 0 and svip > 0 then
        local initType = PDEFINE.TYPE.TASK.UPGRADE
        local initState = STATE.WAITGET
        local sql = string.format("insert into d_svip_task(uid,svip,type,state,create_time) values (%d, %d, %d, %d, %d)", uid, svip, initType, initState, os.time())
        skynet.call(".mysqlpool", "lua", "execute", sql)
    end
end

function cmd.bind(agent_handle)
	handle = agent_handle
    if nil ~= UID then
        initTask(UID)
    end
end

--成功返回
local function resp(retobj)
    return PDEFINE.RET.SUCCESS, cjson.encode(retobj)
end

local function getUserTasks(uid)
    local items = {}
    local sql = string.format("select * from d_svip_task where uid=%d order by id desc", uid)
    local rs = skynet.call(".mysqlpool", "lua", "execute", sql)
    local defaultItem = {
        ['sign'] = 0, --签到
        ['level'] = 0, --升级
        ['weekly'] = 0, --周奖励
        ['monthly'] = 0, --月奖励
    }
    if #rs > 0 then
        for _, row in pairs(rs) do
            if nil == items[row['svip']] then
                items[row['svip']] = table.copy(defaultItem)
            end
            local t = tonumber(row['type'])
            if t == PDEFINE.TYPE.TASK.SIGN then
                items[row['svip']]['sign'] = tonumber(row['state'])
            elseif t == PDEFINE.TYPE.TASK.UPGRADE then
                items[row['svip']]['level'] = tonumber(row['state'])
            elseif t == PDEFINE.TYPE.TASK.WEEK then
                items[row['svip']]['weekly'] = tonumber(row['state'])
            elseif t == PDEFINE.TYPE.TASK.MONTH then
                items[row['svip']]['monthly'] = tonumber(row['state'])
            end
        end
    else
        initTask(uid)
        items[1] = defaultItem
    end
    return items
end

-- 获取等级列表数据
local function getVipUpCfg()
    local vipCfg = {}
    local ok, res = pcall(cluster.call, "master", ".configmgr", "getVipUpCfg")
    if ok then
        vipCfg = res
    end
    return vipCfg
end

function cmd.addNewTask(uid, svip)
    initTask(uid, svip)
end

local function updateDbTask(id)
    local nowtime = os.time()
    local sql = string.format("update d_svip_task set update_time=%d,state=%d where id=%d", nowtime, STATE.GET, id)
    LOG_DEBUG("updateTaskFromDb task:", sql)
    skynet.call(".mysqlpool", "lua", "execute", sql, true)
end

--获取vip周期奖励（周月）
local function getVipPeriodBonusData(uid, actType)
    local rediskey = (PDEFINE.REDISKEY.VIP.periodbonus)..actType..':'..uid
    local data = do_redis({"get", rediskey})
    if data then
        return cjson.decode(data)
    end
end

local function updateVipPeriodBonusData(uid, data)
    local rediskey = (PDEFINE.REDISKEY.VIP.periodbonus)..data.actType..':'..uid
    data.status = STATE.GET
    do_redis({"set", rediskey, cjson.encode(data), 86400*30})
end

--获取vip周期奖励（周月）的状态
local function getVipPeriodBonusStatus(uid, actType)
    local data = getVipPeriodBonusData(uid, actType)
    if data then
        return data.status
    end
    return 0
end

--获取可领取的个数
function cmd.getBonusCnt(uid)
    local cnt = 0
    local sql = string.format("select count(*) as t from d_svip_task where uid=%d and state=1", uid)
    local rs = skynet.call(".mysqlpool", "lua", "execute", sql)
    if nil ~= rs[1] and rs[1].t > 0 then
        cnt = cnt + rs[1].t
    end
    if getVipPeriodBonusStatus(uid, PDEFINE.TYPE.SOURCE.VIP_WEEK) == 1 then
        cnt = cnt + 1
    end
    if getVipPeriodBonusStatus(uid, PDEFINE.TYPE.SOURCE.VIP_MONTH) == 1 then
        cnt = cnt + 1
    end
    return cnt
end

local function calEndTime(rtype)
    local stoptime = 0
    local nowD = os.date("*t")
    local zeroTime = os.time({year=nowD.year, month=nowD.month, day=nowD.day, hour=0, min =0, sec = 00}) --今日开始时间戳
    if rtype == 1 then --计算周
        local wday = os.date("%w")
        wday = tonumber(wday)
        local tmp = wday - 1
        local begintime = zeroTime - (tmp * 86400) --本周一0点
        if wday >= 2 then
            stoptime = begintime + 8*86400 --下周二零点
        else
            stoptime = begintime + 86400 --本周二时间点
        end
    elseif rtype == 2 then
        local day = os.date('%d')
        day = tonumber(day)
        if day < 2 then --当月2号凌晨
            stoptime = zeroTime + 86400 --当天零点再加1天
        else
            local year,month = os.date("%Y", os.time()), os.date("%m", os.time())+1
            local dayAmount = os.date("%d", os.time({year=year, month=month, day=0}))
            local leftDays = (dayAmount - day)
            stoptime = zeroTime + (leftDays * 86400) + 86400 --下月2号凌晨
        end
    end
    return stoptime
end

--获取可转移金额
function cmd.getTransableCoin(uid, playerInfo)
    if not playerInfo then
        playerInfo = handle.dcCall("user_dc", "get", uid)
    end
    if not playerInfo then
        return 0
    end
    local bonus_coin = tonumber(playerInfo.cashbonus or 0)
    local tranedBonus = tonumber(playerInfo.dcashbonus or 0) --已提现到现金余额的金额
    local transable_coin = 0
    if bonus_coin < 0 then
        bonus_coin = 0
    end
    local win_coin = playerInfo.gamebonus or 0 --用户赢钱
    local svip = math.floor(playerInfo.svip or 0)
    if svip > 0 and win_coin > 0 then --只有当用户输钱的时候，触发可转比例
        local vipCfgList = getVipUpCfg()
        if vipCfgList[svip] and vipCfgList[svip].tranrate > 0 then
            local tranrate = vipCfgList[svip].tranrate
            transable_coin = math.round_coin((tranrate * math.abs(win_coin)) - tranedBonus)
            if transable_coin < 0 then
                transable_coin = 0
            end
        end
    end
    if transable_coin > bonus_coin then
        transable_coin = bonus_coin
    end
    return transable_coin
end

--! 获取个人的等级塔任务进度
function cmd.getInfo(msg) 
    local recvobj   = cjson.decode(msg)
    local uid       = math.floor(recvobj.uid)

    local retobj = {
        c = math.floor(recvobj.c),
        code = PDEFINE.RET.SUCCESS,
        spcode = 0,
        data = {},
        wend = calEndTime(1), --下次周bonus领取截止时间
        wstatus = getVipPeriodBonusStatus(uid, PDEFINE.TYPE.SOURCE.VIP_WEEK),
        mend = calEndTime(2), --下次月bonus领取截止时间
        mstatus = getVipPeriodBonusStatus(uid, PDEFINE.TYPE.SOURCE.VIP_MONTH)
    }

    local playerInfo = handle.dcCall("user_dc", "get", uid)
    local svip = math.floor(playerInfo.svip or 0)
    local nextvipexp = handle.getNextVipInfoExp(svip)
    retobj.user = {
        uid = uid,
        svip = svip,
        svipexp = playerInfo.svipexp,
        nextvipexp = nextvipexp
    }

    local mytasks = getUserTasks(uid)
    local taskList = getVipUpCfg()
    for _, row in pairs(taskList) do
        local item = {
            id = row.id, 
            lv = row.level, --等级
            exp = row.diamond, --经验值
            bonusl = row.rewards, --达到的奖励
            bonusw = row.weeklybonus, --周奖励
            bonusm = row.monthlybonus, --月奖励
            status_bonusl =0 , --达到的奖励是否可领取 0:no ,1:待领取, 2:已领取
        }
        if mytasks[row.level] then
            item.status_bonusl = mytasks[row.level].level
        end
        retobj.data[row.id] = item
    end
    return resp(retobj)
end

-- 获取vip可领取奖励(类型 => 金币)
function cmd.getVipRewards(uid)
    local playerInfo = handle.dcCall("user_dc", "get", uid)
    local svip = math.floor(playerInfo.svip or 0)
    local result = {['upgrade'] = 0, ['week']=0, ['month']=0}
    if svip >= 1 then
        --升级可领取的奖励
        local taskList = getVipUpCfg();
        local sql = string.format("select * from d_svip_task where uid=%d and svip<=%d and type=%d and state=1 order by id desc", uid, svip, PDEFINE.TYPE.TASK.UPGRADE )
        local rs = skynet.call(".mysqlpool", "lua", "execute", sql)
        if #rs > 0 and taskList then
            for _, task in pairs(rs) do
                local currItem = taskList[task.svip]
                if currItem then
                    local rewards = currItem.rewards
                    if rewards and rewards.count then
                        result["upgrade"] = result["upgrade"] + rewards.count --升级奖励的金币数
                    end
                end
            end
        end
        --周
        local perioddata = getVipPeriodBonusData(uid, PDEFINE.TYPE.SOURCE.VIP_WEEK)
        if perioddata and perioddata.status == 1 then
            result["week"] = result["week"] + perioddata.coin
        end
        -- 月
        perioddata = getVipPeriodBonusData(uid, PDEFINE.TYPE.SOURCE.VIP_MONTH)
        if perioddata and perioddata.status == 1 then
            result["month"] = result["month"] + perioddata.coin
        end

    end
    return result
end

--! 获取奖励
function cmd.getRewards(msg)
    local recvobj   = cjson.decode(msg)
    local uid       = math.floor(recvobj.uid)
    local vip_level = math.floor(recvobj.vip) --获取对应vip等级的奖励
    local cat       = math.floor(recvobj.type) --领取的类型

    local retobj = {c = math.floor(recvobj.c), code = PDEFINE.RET.SUCCESS, spcode=0}
    
    local playerInfo = handle.dcCall("user_dc", "get", uid)
    local svip = math.floor(playerInfo.svip or 0)
    if svip < vip_level then
        retobj.spcode = PDEFINE_ERRCODE.ERROR.USER_NOT_VIP
        return resp(retobj)
    end
    local taskList = getVipUpCfg();
    if nil == taskList[vip_level] then 
        retobj.spcode = PDEFINE_ERRCODE.ERROR.USER_NOT_VIP
        return resp(retobj)
    end

    local task
    local perioddata
    local rewards = {}
    local rateStr = ""
    local remark = ""
    local bonusRemark = "VIP"..svip
    local addType = PDEFINE.TYPE.SOURCE.VIP

    if cat == PDEFINE.TYPE.TASK.UPGRADE then
        local sql = string.format("select * from d_svip_task where uid=%d and svip=%d and type=%d order by id desc", uid, vip_level, cat)
        local rs = skynet.call(".mysqlpool", "lua", "execute", sql)
        if #rs== 0 or rs[1].state ~= 1 then
            retobj.spcode = PDEFINE_ERRCODE.ERROR.VIP_TASK_CANNOT_GET
            return resp(retobj)
        end
        task = rs[1]
        local currItem = taskList[task.svip]
        LOG_DEBUG('currItem:' , currItem)
        rewards = currItem.rewards
        rateStr = currItem.rewards_rate
        remark = "升级到VIP".. task.svip
        bonusRemark = remark
        --先更新状态
        updateDbTask(task.id)
    else
        if cat == PDEFINE.TYPE.TASK.WEEK then
            perioddata = getVipPeriodBonusData(uid, PDEFINE.TYPE.SOURCE.VIP_WEEK)
        elseif cat == PDEFINE.TYPE.TASK.MONTH then
            perioddata = getVipPeriodBonusData(uid, PDEFINE.TYPE.SOURCE.VIP_MONTH)
        end
        if not perioddata or perioddata.status ~= 1 then
            retobj.spcode = PDEFINE_ERRCODE.ERROR.VIP_TASK_CANNOT_GET
            return resp(retobj)
        end
        rewards = {{type=PDEFINE.PROP_ID.COIN, count=perioddata.coin}}
        rateStr = perioddata.rate
        remark = 'VIP'..(perioddata.vip) ..',彩金:'..(perioddata.coin)
        bonusRemark = remark
        addType = perioddata.actType
        --先更新状态
        updateVipPeriodBonusData(uid, perioddata)
    end

    LOG_DEBUG('cat:', cat, 'rateStr:', rateStr, 'rewards:', rewards)
    local addCoin = 0
    retobj.rewards = {}
    if not table.empty(rewards) then
        for _, reward in pairs(rewards) do
            if reward.type == PDEFINE.PROP_ID.COIN then
                addCoin = addCoin + reward.count
            else
                table.insert(retobj.rewards, reward)

                if reward.type == PDEFINE.PROP_ID.SKIN_CHARM then
                    for i=1, reward.count do
                        add_send_charm_times(uid, reward.img)
                    end
                elseif reward.type == PDEFINE.PROP_ID.SKIN_EXP then
                    add_send_charm_times(uid, reward.img, true, reward.count)
                elseif reward.type == PDEFINE.PROP_ID.SKIN_FRAME then
                    local endtime = reward.days * 86400
                    handle.moduleCall("upgrade","sendSkins", reward.img, endtime)
                end
            end
        end
        LOG_DEBUG('rateStr:' , rateStr , ' addCoin:', addCoin)
        if addCoin > 0 then
            local coins = handle.moduleCall('player', 'addCoinByRate', uid, addCoin, rateStr, addType, 0, nil, nil, remark, bonusRemark)
            if coins[1] > 0 then table.insert(retobj.rewards, {type=PDEFINE.PROP_ID.COIN, count=coins[1]}) end
            if coins[2] > 0 then table.insert(retobj.rewards, {type=PDEFINE.PROP_ID.COIN_CAN_DRAW, count=coins[2]}) end
            if coins[3] > 0 then table.insert(retobj.rewards, {type=PDEFINE.PROP_ID.COIN_BONUS, count=coins[3]}) end
        end
    end

    handle.moduleCall("player",'syncLobbyInfo', uid)
    handle.addStatistics(uid, 'shop_viprewards', 0, 0, 1, vip_level)
    return resp(retobj)
end

-- bonus可转可用余额的信息
function cmd.traninfo(msg)
    local recvobj   = cjson.decode(msg)
    local uid       = math.floor(recvobj.uid)
    local retobj = {c = math.floor(recvobj.c), code = PDEFINE.RET.SUCCESS, spcode=0, bonus_coin=0, collect_coin=0}

    local playerInfo = handle.dcCall("user_dc", "get", uid)
    retobj.bonus_coin = playerInfo.cashbonus or 0 --总的cashbonus
    if retobj.bonus_coin < 0 then
        retobj.bonus_coin = 0
    end
    retobj.collect_coin = cmd.getTransableCoin(uid, playerInfo) --可以转移到现金钱包的bonus coin
    retobj.bonus_coin = math.round_coin(retobj.bonus_coin - retobj.collect_coin) --把总的bonuscoin分成 不可转移和可转移的。 并且把不可转移用bonus_coin字段返回
    return resp(retobj)
end

function cmd.tranjob(msg)
    local recvobj   = cjson.decode(msg)
    local uid       = math.floor(recvobj.uid)
    local retobj = {c = math.floor(recvobj.c), code = PDEFINE.RET.SUCCESS, spcode=0, bonus_coin=0, collect_coin=0, add_coin=0}
    
    local playerInfo = handle.dcCall("user_dc", "get", uid)
    retobj.bonus_coin = playerInfo.cashbonus or 0
    local tranedBonus = playerInfo.dcashbonus or 0 --已提现到现金余额的金额
    if retobj.bonus_coin < 0 then
        retobj.bonus_coin = 0
    end
    if os.time() < tranjobTime + 3 then
        retobj.spcode = PDEFINE.RET.ERROR.BONUS_COLLECT_FREQUENTLY
        return resp(retobj)
    end
    tranjobTime = os.time()
    local svip = math.floor(playerInfo.svip or 0)
    local win_coin = playerInfo.gamebonus or 0 --用户输钱
    if svip > 0 and win_coin > 0 then
        local vipCfgList = getVipUpCfg()
        if vipCfgList[svip] and vipCfgList[svip].tranrate > 0 then
            local tranrate = vipCfgList[svip].tranrate
            local add_coin = math.round_coin((tranrate * math.abs(win_coin)) - tranedBonus)
            if add_coin > 0 then
                if add_coin > retobj.bonus_coin then
                    add_coin = retobj.bonus_coin
                end
                handle.addProp(PDEFINE.PROP_ID.COIN, add_coin, 'transfer', 'bonustranfer:'.. add_coin)
                handle.dcCall("user_dc", "user_addvalue", uid, "dcashbonus", add_coin)
                handle.dcCall("user_dc", "user_addvalue", uid, "cashbonus", -add_coin)
                retobj.bonus_coin = retobj.bonus_coin - add_coin
                local orderid = os.date("%Y%m%d%H%M%S", os.time()) .. payId()
                local sql = string.format("insert into d_log_cashbonus(orderid,title,coin,create_time,category,uid,useruid) values ('%s','%s', %.2f, %d, %d, %d,%d)", 
                orderid,'out', -add_coin, os.time(), PDEFINE.TYPE.SOURCE.Transfer, uid, 0)
                do_mysql_queue(sql)
                retobj.add_coin = add_coin
                if retobj.bonus_coin < 0 then
                    retobj.bonus_coin = 0
                end
                handle.syncUserInfo({uid=uid, cashbonus=retobj.bonus_coin})
            end
        end
    end
    return resp(retobj)
end

-- 获取vip配置的转移比例
function cmd.getTransferCfg(msg) 
    local recvobj   = cjson.decode(msg)
    local retobj = {c = math.floor(recvobj.c), code = PDEFINE.RET.SUCCESS, spcode=0, data = {}}
    local cfglist = getVipUpCfg()
    for _, row in pairs(cfglist) do
        if row.level > 0 then
            table.insert(retobj.data, {
                level = row.level,
                rate = row.tranrate
            })
        end
    end
    return resp(retobj)
end
return cmd