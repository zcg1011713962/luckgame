local quest = {}
local handle
local date = require "date"
local skynet = require "skynet"
local cjson   = require "cjson"
local player_tool = require "base.player_tool"
cjson.encode_sparse_array(true)
cjson.encode_empty_table_as_object(false)
local DEBUG = skynet.getenv("DEBUG")  -- 是否是调试阶段
local cluster = require "cluster"
local s_special_quest = require "conf.s_special_quest"
local fbshareCfg = require "conf.fbshareCfg"
local UID
local CHARM_LIST
local prefixOfBonus="dailyBounus:"
local BONUS_WHEEL_TYPE = 2 --金转盘
-- 任务模块
--[[
    type: 1 每日要重置的任务； 2 单次任务
    cat: 1 每日任务(游戏次数) 2 每日任务(在线时长/玩几局游戏) 3升级任务 4排位赛任务
]]

function quest.bind(agent_handle)
	handle = agent_handle
end

function quest.initUid(uid)
    UID = uid
end

local FBSAHRE_QUEST_ID = 130 --fb分享任务的id固定为7

--成功返回
local function resp(retobj)
    return PDEFINE.RET.SUCCESS, cjson.encode(retobj)
end

local function initCharmList()
    if nil == CHARM_LIST then
        local ok, row = pcall(cluster.call, "master", ".configmgr", "getCharmPropList")
        CHARM_LIST = row
    end
end

-- 任务初始化
function quest.init(uid)
    UID = uid
    local ok, rs = pcall(cluster.call, "master", ".questmgr", "getAll")
	for _,row in pairs(rs) do
        local questCache = handle.dcCall("quest_dc","get_info", uid, row.id)
        if nil == questCache or table.empty(questCache) then
            local questInfo = {}
            questInfo.uid = uid
            questInfo.questid = row.id
            questInfo.state = 0
            questInfo.parm1 = row.parm1
            questInfo.parm2 = row.parm2
            questInfo.doparm1 = 0
            questInfo.doparm2 = 0
            questInfo.descr = row.descr
            questInfo.descr_al = row.descr_al
            questInfo.parmCnt = row.parmCnt
            questInfo.count   = row.count
            questInfo.icon    = row.icon
            questInfo.type    =  row.type
            questInfo.parm1coin = row.parm1coin
            questInfo.parm2coin = row.parm2coin
            questInfo.doparm1coin = 0
            questInfo.doparm2coin = 0
            questInfo.cat = row.cat
            questInfo.tag = row.tag or 0 --分类tag
            handle.dcCall("quest_dc","add", questInfo)
        end
	end
    initCharmList()
end

--是否有已经完成可以领取的任务
function quest.hasDone(uid)
    local has = 0
    local hasDoneQuest = {}
    local questList = handle.dcCall("quest_dc","get_list", uid)
    if nil~=questList and not table.empty(questList) then
        for _, row in pairs(questList) do
            if row.state ==  PDEFINE.QUEST_STATE.DONE then
                has = 1
                hasDoneQuest = row
                break
            end
        end
    end
    return has, hasDoneQuest
end

local dailyBonus = {
    maxtimes = 7,
    coin = 60
}
-- 每日任务完成累积奖励
local function getDailyTaskPercent(uid)
    local ret = {
        times = 0,
        maxtimes = dailyBonus.maxtimes,
        get = 0, --0:未领取；1：待领取；2：已经领取
        rewards = {
            {
                type = PDEFINE.PROP_ID.DIAMOND,
                count = dailyBonus.coin
            },
            {
                type = PDEFINE.PROP_ID.SKIN_CHARM,
                count = 1,
                img = 'gift_kiss',
                times = 1,
            }
        }
    }

    local canget = do_redis({ "get", prefixOfBonus .. uid})
    canget = tonumber(canget or 0)
    if canget==0 or canget==nil then
        local prefix = 'dailytask:'
        local info = do_redis({ "hgetall", prefix .. uid},uid)
        info = make_pairs_table(info)
        local curCnt = 1
        if not info or table.empty(info) then
            curCnt = 0
        else
            curCnt = tonumber(info.count)
        end
        ret.times = curCnt
    else
        if canget == 1 then
            ret.get = 1
        else
            ret.get = 2
        end
        ret.times = dailyBonus.maxtimes
    end
    
    return ret
end

local function dailyPercent(uid, addTimes)
    addTimes = addTimes or 1
    local prefix = 'dailytask:'
    local info = do_redis({ "hgetall", prefix .. uid},uid)
    info = make_pairs_table(info)
    local curSignCount = 1 --当前次数
    local now = os.time()
    LOG_DEBUG("dailyPercent info:", info, ' curSignCount:', curSignCount)
    if not info or table.empty(info) then
        info = {}
        info.count = curSignCount --已经多少次
        if addTimes > curSignCount then
            info.count = addTimes
        end
        info.timestamp = now
        do_redis({ "hmset", prefix..uid, info }, uid)
        if info.count >= dailyBonus.maxtimes then
            do_redis({ "set", prefixOfBonus .. uid, 1})
        end
    else
        curSignCount = tonumber(info.count) + addTimes
        curSignCount = math.floor(curSignCount)
        local tmp = {
            ['count'] = curSignCount,
            ['timestamp'] = now
        }
        if curSignCount >= dailyBonus.maxtimes then
            tmp['count'] = dailyBonus.maxtimes --当前次数循环
            curSignCount = 1
            do_redis({ "set", prefixOfBonus .. uid, 1})
        end
        LOG_DEBUG("dailyPercent info tmp:", tmp)
        do_redis({ "hmset", prefix ..uid, tmp}, uid)
    end
end

function quest.getDailyBonus(msg)
    local recvobj = cjson.decode(msg)
    local uid = math.floor(recvobj.uid)
    local retobj = {c = math.floor(recvobj.c), code= 200 , spcode = 0}
    local taskFlag = do_redis({ "get", prefixOfBonus .. uid})
    taskFlag = tonumber(taskFlag or 0)
    if taskFlag ~= 1 then
        retobj.spcode = PDEFINE.RET.ERROR.DAILYTASK_NOT_DONE
        return resp(retobj)
    end

    handle.addProp(PDEFINE.PROP_ID.COIN, dailyBonus.coin, 'quest')
    retobj.rewards = {
        {
            type = PDEFINE.PROP_ID.COIN,
            count = dailyBonus.coin
        }
    }
    do_redis({ "set", prefixOfBonus .. uid, 2})

    return resp(retobj)
end

function quest.getRewardsById(questid, uid)
    local datalist = {}
    local ok, quest = pcall(cluster.call, "master", ".questmgr", "getRow", questid)
    -- LOG_DEBUG("row quest:", quest)
    -- local rewards = decodeRewards(quest.rewards)
    local rewards = decodePrize(quest.rewards)
    for _, reward in ipairs(rewards) do
        if reward.type == PDEFINE.PROP_ID.SKIN_CHARM then
            -- local charm = CHARM_LIST[reward.count]
            -- if nil == reward.addition then
                -- reward.addition  = 1
            -- end
            table.insert(datalist, {type=PDEFINE.PROP_ID.SKIN_CHARM, count=1, img=reward.img, times=reward.count})
        elseif reward.type == PDEFINE.PROP_ID.COIN then
            table.insert(datalist, {type=PDEFINE.PROP_ID.COIN, count=reward.count})
        elseif reward.type == PDEFINE.PROP_ID.DIAMOND then
            table.insert(datalist, {type=PDEFINE.PROP_ID.DIAMOND, count=reward.count})
        elseif reward.type == PDEFINE.PROP_ID.SKIN_EXP then
            table.insert(datalist, {type=PDEFINE.PROP_ID.SKIN_EXP, count=reward.count, img=reward.img})
        elseif reward.type == PDEFINE.PROP_ID.SKIN_FRAME then
            table.insert(datalist, {type=PDEFINE.PROP_ID.SKIN_FRAME, count=reward.count, img=reward.img, days=reward.days})
        end
    end
    return datalist
end

-- 按分类计算任务完成数(红点提示使用)
function quest.hasDoneByType(uid)
    local dailyCnt = 0
    local questList = handle.dcCall("quest_dc","get_list", uid)
    if nil~=questList and not table.empty(questList) then
        for _, row in pairs(questList) do
            if row.state ==  PDEFINE.QUEST_STATE.DONE then
                if row.cat == 1 then
                    dailyCnt = dailyCnt + 1
                end
            end
        end
    end
    local canget = do_redis({ "get", prefixOfBonus .. uid})
    canget = tonumber(canget or 0)
    if canget ~= 1 then canget = 0 end
    return dailyCnt, canget
end

-- 包装成网络对象 (获取每日任务)
function quest.getInfoObj(uid, cmd, typeArr)
    initCharmList()
	local questList = handle.dcCall("quest_dc","get_list", uid)
    local dataList = {}
    if nil ~= typeArr then
        local isEnglish = handle.isEnglish()
        if questList and not table.empty(questList) then
            for _, row in pairs(questList) do
                local ok, quest = pcall(cluster.call, "master", ".questmgr", "getRow", row.questid)
                if nil ~= quest and not table.empty(quest) then
                    local update = {}
                    if row.descr ~= quest.descr then
                        update["descr"] = quest.descr
                        row.desc = quest.descr
                    end
                    if row.descr_al ~= quest.descr_al then
                        update["descr_al"] = quest.descr_al
                        row.descr_al = quest.descr_al
                    end
                    if row.icon ~= quest.icon then
                        update["icon"] = quest.icon
                        row.icon = quest.icon
                    end
                    if row.parm1 ~= quest.parm1 then
                        update["parm1"] = quest.parm1
                        row.parm1 = quest.parm1
                    end
                    if row.parm2 ~= quest.parm2 then
                        update["parm2"] = quest.parm2
                        row.parm2 = quest.parm2
                    end
                    if row.count ~= quest.count then
                        update["count"] = quest.count
                        row.count = quest.count
                    end
                    if row.parm1coin ~= quest.parm1coin then
                        update["parm1coin"] = quest.count
                        row.parm1coin = quest.parm1coin
                    end
                    if row.parm2coin ~= quest.parm2coin then
                        update["parm2coin"] = quest.count
                        row.parm2coin = quest.parm2coin
                    end
                    if row.missionstar ~= quest.missionstar then
                        update["missionstar"] = quest.missionstar
                        row.missionstar = quest.missionstar
                    end
                    if row.rewards ~= quest.rewards then
                        update["rewards"] = quest.rewards
                        row.rewards = quest.rewards
                    end
                    if row.jumpTo ~= quest.jumpTo then
                        update["jumpTo"] = quest.jumpTo
                        row.jumpTo = quest.jumpTo
                    end
                    if row.tag ~= quest.tag then
                        update["tag"] = quest.tag
                        row.tag = quest.tag
                    end
                    if 0 == quest.status then
                        update["state"] = PDEFINE.QUEST_STATE.STOP
                        row.state = quest.state
                    end
                    if not table.empty(update) then
                        handle.dcCall("quest_dc","setvalue", uid, row.questid, update)
                    end
                    row.jumpTo = quest.jumpTo or 0
                end

                -- LOG_DEBUG("quest cat:", row.cat, " questid:", row.questid, ' type:', type(typeArr))
                if table.contain(typeArr, tonumber(row.cat)) and row.state~=PDEFINE.QUEST_STATE.STOP then
                    if row.type == PDEFINE.QUEST_TYPE.RECHARGE then
                        row.parm1 = row.parm1coin
                        row.parm2 = row.parm2coin

                        row.doparm1 = row.doparm1coin
                        row.doparm2 = row.doparm2coin
                    end
                    -- 将奖励解析成对象
                    local data = table.copy(row)
                    -- 将秒数解析成分格式
                    if data.parm1 % 60 == 0 then
                        data.parm1 = data.parm1 // 60
                        data.doparm1 = data.doparm1 // 60
                    end
                    LOG_DEBUG("data: questid:", data.questid, ' tag:', data.tag, ' row.cat:', data.cat)
                    data.parm1coin = nil
                    -- data.cat = nil
                    data.doparm2coin = nil
                    data.parm2coin = nil
                    -- data.parm2 = nil
                    data.doparm2 = nil
                    data.missionstar = nil
                    data.doparm1coin = nil
                    data.count = nil
                    -- data.state = nil
                    data.icon = nil
                    data.type = nil
                    data.uid = nil
                    data.parmCnt = nil
                    if row.rewards and row.rewards ~= "" then
                        local rewards = decodePrize(row.rewards)
                        data.rewards = {}
                        for _, reward in ipairs(rewards) do
                            if reward.type == PDEFINE.PROP_ID.SKIN_CHARM then
                                -- local charm = CHARM_LIST[reward.count]
                                -- local count = 1
                                -- if reward.addition then
                                --     count = reward.addition
                                -- end
                                table.insert(data.rewards, {type=PDEFINE.PROP_ID.SKIN_CHARM, count=reward.count, img=reward.img})
                            elseif reward.type == PDEFINE.PROP_ID.COIN then
                                table.insert(data.rewards, {type=PDEFINE.PROP_ID.COIN, count=reward.count})
                            elseif reward.type == PDEFINE.PROP_ID.DIAMOND then
                                table.insert(data.rewards, {type=PDEFINE.PROP_ID.DIAMOND, count=reward.count})
                            elseif reward.type == PDEFINE.PROP_ID.SKIN_EXP then
                                table.insert(data.rewards, {type=PDEFINE.PROP_ID.SKIN_EXP, count=reward.count, img=reward.img})
                            elseif reward.type == PDEFINE.PROP_ID.SKIN_FRAME then
                                table.insert(data.rewards, {type=PDEFINE.PROP_ID.SKIN_FRAME, count=reward.count, img=reward.img, days=reward.days})
                            end
                        end
                    end
                    if not isEnglish then
                        data.descr = data.descr_al
                    end
                    table.insert(dataList, data)
                end
            end
        end
    else
        if questList and not table.empty(questList) then
            dataList = questList
        else
            dataList = {}
        end
    end
    local now = os.time()
	local retobj = {}
	retobj.c     = cmd
	retobj.code  = PDEFINE.RET.SUCCESS
    retobj.questList = dataList

    retobj.resetTime = 24*60*60 - (now - date.GetTodayZeroTime(now))

    if type(typeArr) == "table" and table.contain(typeArr, 1) then
        retobj.dailyprogress = getDailyTaskPercent(uid)
    end

	return resp(retobj)
end

-- 升级专用，直接设置最新等级结果
function quest.updateBatchLevel(questidDict, value1)
    local change = false
    for i=1, #questidDict do
        local questid = questidDict[i]
        local questInfo = handle.dcCall("quest_dc","get_info", UID, questid)
        LOG_DEBUG("quest.updateBatchSet uid:", UID, ' type:',type, ' questid:',questid, ' value1：', value1, ' questInfo:', questInfo)
        if questInfo and not table.empty(questInfo) and questInfo.state==PDEFINE.QUEST_STATE.INIT then
            -- local preQuestId = 0
            local ok, quest = pcall(cluster.call, "master", ".questmgr", "getRow", questid)
            if nil ~= quest and not table.empty(quest) then
                if math.floor(quest.status) == 0 then
                    questInfo.state = PDEFINE.QUEST_STATE.STOP
                end
                -- preQuestId = quest.preid
            end
           
            local num= value1
            handle.dcCall("quest_dc","setvalue", UID,questid, "doparm1",num) --完成值
            if num >= tonumber(questInfo.parm1) then
                handle.dcCall("quest_dc","setvalue", UID, questid, 'done_time', os.time()) --任务完成时间
                handle.dcCall("quest_dc","setvalue", UID, questid, "state", PDEFINE.QUEST_STATE.DONE)  --可以领取
                local notify_retobj  = {}
                notify_retobj.c      = PDEFINE.NOTIFY.UQEST_DONE
                notify_retobj.code   = PDEFINE.RET.SUCCESS
                notify_retobj.uid    = UID
                notify_retobj.hasQuest = 1
                notify_retobj.questid= questInfo.questid
                handle.sendToClient(cjson.encode(notify_retobj))
                change = true
            end
            local notify_retobj = {}
            notify_retobj.c = PDEFINE.NOTIFY.QUEST_PROCESS
            notify_retobj.code = PDEFINE.RET.SUCCESS
            notify_retobj.cur_num = tonumber(questInfo.doparm1)
            notify_retobj.end_num =  tonumber(questInfo.parm1)
            notify_retobj.questid = questid
            notify_retobj.hasDone = 0
            notify_retobj.hasGet = 0
            if tonumber(questInfo.doparm1)  >=  tonumber(questInfo.parm1) then
                notify_retobj.hasDone = 1
            end
            if questInfo.state == PDEFINE.QUEST_STATE.GET then
                notify_retobj.hasGet = 1
            end
            handle.sendToClient(cjson.encode(notify_retobj))
        end
    end
    if change then
        handle.moduleCall("player","syncLobbyInfo", UID)
    end
end

-- 完成同类型批量任务
function quest.updateBatchQuest(type, questidDict, value1)
    LOG_DEBUG("updateBatchQuest:", questidDict)
    for i=1, #questidDict do
        quest.updateQuest(UID, type, tonumber(questidDict[i]), value1)
    end
end

function quest.shareVarWhatapp(msg)
    local recvobj = cjson.decode(msg)
	local uid = math.floor(recvobj.uid)

    quest.updateBatchQuest(1, {PDEFINE.QUESTID.NEW.SHAREWHATAPP}, 1)
    local retobj = {c = math.floor(recvobj.c), code= 200 , spcode = 0}
    return resp(recvobj)
end


--更新任务
-- cluster.call(user.cluster_info.server, user.cluster_info.address, "clusterModuleCall", "quest", "updateQuest", user.uid, 1, 1, 1)
-- questid: 对应s_quest中的id, 也即任务id
-- value1: 每次增加的点数
function quest.updateQuest(uid,type,questid,value1)
	local questInfo = handle.dcCall("quest_dc","get_info", uid, questid)
    if questInfo and not table.empty(questInfo) then
        local preQuestId = 0
        local ok, quest = pcall(cluster.call, "master", ".questmgr", "getRow", questid)
        if nil ~= quest and not table.empty(quest) then
            if math.floor(quest.status) == 0 then
                questInfo.state = PDEFINE.QUEST_STATE.STOP
            end
            preQuestId = quest.preid
        end

        LOG_DEBUG("quest.updateQuest uid:", uid, ' type:',type, ' preQuestId:',preQuestId)
    
        --前1次任务未领取,此次任务不会开启
        -- local preQuestId = quest.preid
        if preQuestId > 0 and type == 1 then
            local preQuestInfo = handle.dcCall("quest_dc","get_info", uid, preQuestId)
            if preQuestInfo and preQuestInfo.state ~= PDEFINE.QUEST_STATE.GET then
                --前面的一次任务未领取,此次操作不算完成任务
                LOG_DEBUG("前面的任务".. preQuestId .. "未领取, 这次不算完成" .. questid .. " uid:" .. uid)
                return PDEFINE.RET.ERROR.TASK_NOT_FINISH
            end
        end
        LOG_DEBUG("quest.updateQuest uid:", uid, ' type:',type, ' questid:',questid, ' value1：', value1, ' questInfo:', questInfo)
    
        --TODO rummy次数累计buy
        if questInfo.state == PDEFINE.QUEST_STATE.INIT then
            -- if type == 1 then
                local num 
                if questInfo.type == PDEFINE.QUEST_TYPE.RECHARGE then
                    num  = tonumber(questInfo.doparm1coin) + value1
                    handle.dcCall("quest_dc","setvalue", uid,questid, "doparm1coin",num) --完成值
                    if num >= tonumber(questInfo.parm1coin) then
                        handle.dcCall("quest_dc","setvalue", uid, questid, "state", PDEFINE.QUEST_STATE.DONE)  --可以领取
                        local notify_retobj  = {}
                        notify_retobj.c      = PDEFINE.NOTIFY.UQEST_DONE
                        notify_retobj.code   = PDEFINE.RET.SUCCESS
                        notify_retobj.uid    = uid
                        notify_retobj.hasQuest = 1
                        notify_retobj.questid= questInfo.questid
                        handle.sendToClient(cjson.encode(notify_retobj))
                    end
                else
                    num  = tonumber(questInfo.doparm1) + value1
                    handle.dcCall("quest_dc","setvalue", uid,questid, "doparm1",num) --完成值
                    if num >= tonumber(questInfo.parm1) then
                        
                        handle.dcCall("quest_dc","setvalue", uid, questid, 'done_time', os.time()) --任务完成时间
                        handle.dcCall("quest_dc","setvalue", uid,questid, "state", PDEFINE.QUEST_STATE.DONE)  --可以领取
                        local notify_retobj  = {}
                        notify_retobj.c      = PDEFINE.NOTIFY.UQEST_DONE
                        notify_retobj.code   = PDEFINE.RET.SUCCESS
                        notify_retobj.uid    = uid
                        notify_retobj.hasQuest = 1
                        notify_retobj.questid= questInfo.questid
                        handle.sendToClient(cjson.encode(notify_retobj))

                        -- handle.moduleCall("player","syncLobbyInfo", uid)
                    end
                    local notify_retobj = {}
                    notify_retobj.c = PDEFINE.NOTIFY.QUEST_PROCESS
                    notify_retobj.code = PDEFINE.RET.SUCCESS
                    notify_retobj.cur_num = tonumber(questInfo.doparm1)  
                    notify_retobj.end_num =  tonumber(questInfo.parm1)
                    notify_retobj.questid = questid
                    notify_retobj.hasDone = 0
                    notify_retobj.hasGet = 0
                    if tonumber(questInfo.doparm1)  >=  tonumber(questInfo.parm1) then
                        notify_retobj.hasDone = 1
                    end
                    if questInfo.state == PDEFINE.QUEST_STATE.GET then
                        notify_retobj.hasGet = 1
                    end
                    handle.sendToClient(cjson.encode(notify_retobj)) 

                    if notify_retobj.hasDone == 1 then
                        handle.moduleCall("player","syncLobbyInfo", uid)
                        if questInfo.cat == PDEFINE.QUEST_TYPE.REPEAT or questInfo.cat == PDEFINE.QUEST_TYPE.NEWER then
                            --每日任务和新手任务主动通知
                            local isEnglish = handle.isEnglish()
                            local notify_quest = {}
                            notify_quest.c = PDEFINE.NOTIFY.QUEST_UPDATED
                            notify_quest.code = PDEFINE.RET.SUCCESS
                            notify_quest.cur_num = tonumber(questInfo.doparm1)
                            notify_quest.end_num =  tonumber(questInfo.parm1)
                            notify_quest.questid = questInfo.questid
                            notify_quest.descr = questInfo.descr
                            notify_quest.uid = uid
                            if not isEnglish then
                                notify_quest.descr = questInfo.descr_al
                            end
                            handle.sendToClient(cjson.encode(notify_quest)) 
                        end
                    end
                end
            -- end
        end
    end
end

--只有每日任务才恢复数值
function quest.reset(uid)
    if not uid then return end
	local questList = handle.dcCall("quest_dc","get_list", uid)
    local delPrefixOfBonus = false
    if questList and not table.empty(questList) then
        for _,questInfo in pairs(questList) do
            if questInfo.type == PDEFINE.QUEST_TYPE.REPEAT then
                -- 每日任务TODO: 已经完成的需要发邮件
                local data = {
                    state = 0,
                    doparm1 = 0,
                    doparm2 = 0
                }
                handle.dcCall("quest_dc","setvalue", uid, questInfo.questid, data)

                if not delPrefixOfBonus then
                    do_redis({ "del", prefixOfBonus .. uid})
                    delPrefixOfBonus = true
                end
            end

            if questInfo.type == PDEFINE.QUEST_TYPE.RECHARGE then
                local data = {
                    state = 0,
                    doparm1coin = 0,
                    doparm2coin = 0
                }
                handle.dcCall("quest_dc","setvalue", uid, questInfo.questid, data)
            end
        end

        local prefix = 'dailytask:'
        do_redis({ "del", prefix .. uid},uid)
    end
end

-- 获取FB分享可以拿到的奖励信息， questid 固定为FB分享的ID
function quest.getFBShrareCoin()
    local ok, rs = pcall(cluster.call, "master", ".questmgr", "getRow", PDEFINE.QUESTID.NEW.LINKFB)
    local rewards = {}
    if rs and rs.rewards and rs.rewards ~= "" then
        -- LOG_DEBUG("rs.rewards:", rs.rewards, " rs:", rs)
        local tmp_rewards = decodePrize(rs.rewards)
        for _, row in pairs(tmp_rewards) do
            if row.type == PDEFINE.PROP_ID.SKIN_CHARM then
                -- local charm = CHARM_LIST[row.count]
                table.insert(rewards, {type=PDEFINE.PROP_ID.SKIN_CHARM, count=row.count, img=row.img})
            else
                table.insert(rewards, {type=row.type, count=row.count})
            end
        end
    end
    return rewards
end

--! 获取每日任务信息
function quest.getInfoRequest(msg)
	local recvobj = cjson.decode(msg)
	local uid = math.floor(recvobj.uid)
    local cmd = math.floor(recvobj.c)
    local cat = recvobj.type or 1 
    cat = cat .. ''
    local catArr = {}
    if cat ~= nil then
        catArr = string.split(cat, ",")
    end

    local gameid = math.floor(recvobj.gameid or 0)
    if gameid == PDEFINE.GAME_TYPE.HAND and type(cat)=="number" and cat==4 then --hand 排位赛
        catArr = {6}
    end

    for i=1,#catArr do
        catArr[i] = math.floor(catArr[i])
    end
    return quest.getInfoObj(uid, cmd, catArr)
end

local function getRewardsList(uid)
    local prefix = 'newbie:'
    local rewards = do_redis({ "hgetall", prefix .. uid},uid)
    rewards = make_pairs_table(rewards)
    if not rewards or table.empty(rewards) then
        return PDEFINE.NEWBIE_QUEST
    else
        local hasget = cjson.decode(rewards.hasget)
        local hasdone = cjson.decode(rewards.hasdone)
        for i=1, #hasget do
            hasget[i] = tonumber(hasget[i])
        end
        for i=1, #hasdone do
            hasdone[i] = tonumber(hasdone[i])
        end
        local data = table.copy(PDEFINE.NEWBIE_QUEST)
        for _, row in pairs(data) do
            if table.contain(hasget, row.id) then
                row.state = 2
                row.times = row.max
            else
                if table.contain(hasdone, row.id) then
                    row.state = 1
                    row.times = row.max
                end
            end
            if row.id == tonumber(rewards.id) then
                row.times = rewards.times
            end
        end
        return data
    end
end

--完成任务
local function collectQuest(uid, questIds)
    local isNewerQuest = false
    local addCoin, addDiamond = 0, 0
    local retRewards = {}
    local completeCnt = 0 -- 完成数量
    if #questIds > 0 then
        for i=#questIds, 1, -1 do
            local questid = questIds[i]
            local ok, rs = pcall(cluster.call, "master", ".questmgr", "getRow", questid)
            if rs.status == 0 then
                table.remove(questIds, i)
            else
                local questInfo = handle.dcCall("quest_dc","get_info", uid, questid)
                if questInfo.state == PDEFINE.QUEST_STATE.DONE then
                    if rs.cat and rs.cat == 1 then
                        completeCnt = completeCnt + 1
                    end
                    local itemCoin, itemDiamond = 0, 0
                    if rs.rewards and rs.rewards ~= "" then
                        -- local rewards = decodeRewards(rs.rewards)
                        local rewards = decodePrize(rs.rewards)
                        for _, reward in ipairs(rewards) do
                            if reward.type == PDEFINE.PROP_ID.COIN then
                                addCoin = addCoin + reward.count
                                itemCoin = itemCoin + reward.count
                            elseif reward.type == PDEFINE.PROP_ID.DIAMOND then
                                addDiamond = addDiamond + reward.count
                                itemDiamond = itemDiamond + reward.count
                            elseif reward.type == PDEFINE.PROP_ID.SKIN_CHARM then
                                table.insert(retRewards, {type=PDEFINE.PROP_ID.SKIN_CHARM, count=reward.count, img=reward.img})
                                for i=1, reward.count do
                                    add_send_charm_times(uid, reward.img)
                                end
                            elseif reward.type == PDEFINE.PROP_ID.SKIN_EXP then
                                add_send_charm_times(uid, reward.img, true, reward.count)
                                table.insert(retRewards, {type=PDEFINE.PROP_ID.SKIN_EXP, count=reward.count, img=reward.img})
                            elseif reward.type == PDEFINE.PROP_ID.SKIN_FRAME then
                                local endtime = reward.days * 86400
                                handle.moduleCall("upgrade","sendSkins", reward.img, endtime)
                            end
                        end
                        -- if questid == PDEFINE.QUESTID.NEW.CHANGENICKNAME then --改昵称
                        --     local endtime = PDEFINE.SKIN.CHANGENICK.AVATAR.days * 86400
                        --     handle.moduleCall("upgrade","sendSkins", PDEFINE.SKIN.CHANGENICK.AVATAR.img, endtime)
                        -- end
                    end
                    handle.moduleCall("player", "addSendCoinLog", uid, itemCoin, "quest"..questid, nil, itemDiamond)
                    handle.addStatistics(uid, "do_dailytask", questid)
                    handle.dcCall("quest_dc","setvalue", uid,questid, "state", PDEFINE.QUEST_STATE.GET)
                    LOG_DEBUG("新手任务:", PDEFINE.QUEST_TYPE.NEWER, ' uid:', uid, ' cat:', rs.cat)
                    if rs.cat == PDEFINE.QUEST_TYPE.NEWER then -- 新手任务
                        local prize = quest.updateNewbieRewards(uid)
                        isNewerQuest = true
                        -- if prize > 0 then
                            -- local prize_item = PDEFINE.NEWBIE_QUEST[prize]
                            -- table.insert(retobj.rewards, {type=prize_item.type, count=1, days=prize_item.days})
                            -- handle.moduleCall("upgrade","sendSkins", prize_item.img, prize_item.days*24*60*60)
                        -- end
                    end
                end
            end
        end
    end
    
    local code,beforecoin,aftercoin
    if addCoin > 0 then
        -- player_tool.calUserCoin_nogame(uid, addCoin, "任务奖励"..(addCoin), PDEFINE.ALTERCOINTAG.QUESTAWARD, 0)

        code, beforecoin, aftercoin = player_tool.funcAddCoin(uid, addCoin, "玩家领取任务金币奖励:"..addCoin,
        PDEFINE.ALTERCOINTAG.QUESTAWARD, PDEFINE.GAME_TYPE.SPECIAL.QUEST,  PDEFINE.POOL_TYPE.none, nil)
    end

    local userInfo = handle.moduleCall("player", "getPlayerInfo", uid)
    handle.notifyCoinChanged(userInfo.coin, userInfo.diamond, addCoin, addDiamond)

    if addCoin > 0 then
        table.insert(retRewards, {type=PDEFINE.PROP_ID.COIN, count=addCoin})
    end
    if addDiamond > 0 then
        table.insert(retRewards, {type=PDEFINE.PROP_ID.DIAMOND, count=addDiamond})
    end

    if completeCnt > 0 then
        -- 更新主线任务
        -- local updateMainObjs = {
        --     {kind=PDEFINE.MAIN_TASK.KIND.DailyTask, count=completeCnt},
        -- }
        -- handle.moduleCall("maintask", "updateTask", uid, updateMainObjs)
    end

    return isNewerQuest, addCoin, addDiamond, retRewards
end

--! 领取任务奖励
function quest.getQuestReward(msg)
    local recvobj = cjson.decode(msg)
	local uid = math.floor(recvobj.uid)
	local questid = math.floor(recvobj.questid or 0) --按id 单个领取
    local cat = recvobj.type --按类型批量领取:1,2,4
    -- 清洗
    local isDailyTask = false
    local questIds = {}
    if questid > 0 then
        local questInfo = handle.dcCall("quest_dc","get_info", uid, questid)
        if questInfo.state ~= PDEFINE.QUEST_STATE.DONE then
            local retobj = { c = math.floor(recvobj.c),questid = questid,  code = PDEFINE.RET.ERROR.TASK_NOT_FINISH,coin = 0}
            return resp(retobj)
        end
        if questInfo.cat == 1 then
            isDailyTask = true
        end
        local ok, rs = pcall(cluster.call, "master", ".questmgr", "getRow", questid)
        if rs.status == 0 then
            --任务已关闭
            local retobj = { c = math.floor(recvobj.c),questid = questid,  code = PDEFINE.RET.ERROR.TASK_HAD_CLOSE,coin = 0}
            return resp(retobj)
        end
        table.insert(questIds, questid)
    else
        local catArr = {}
        if cat ~= nil then
            cat = cat .. ''
            catArr = string.split(cat, ",")
            for i=1,#catArr do
                catArr[i] = math.floor(catArr[i])
            end
        end
        if table.contain(catArr, 1) then
            isDailyTask = true
        end
        local questList = handle.dcCall("quest_dc","get_list", uid)
        for _, row in pairs(questList) do
            local questInfo = handle.dcCall("quest_dc","get_info", uid, row.questid)
            LOG_DEBUG("questInfo.state:", questInfo.state, ' cat:', row.cat, ' type:', type(row.cat))
            if table.contain(catArr, math.floor(row.cat)) and questInfo.state == PDEFINE.QUEST_STATE.DONE then
                table.insert(questIds, row.questid) --这里可能包括已经关闭的任务
            end
        end
        LOG_DEBUG("quest.getQuestReward catArr:",catArr, ' questIds:',questIds)
    end
    LOG_DEBUG( ' quest.getQuestReward questIds:',questIds)

    local retobj = { 
        c = math.floor(recvobj.c),
        questid = questIds,
        code = PDEFINE.RET.SUCCESS,
        coin = 0,
        rewards = {},
        type = cat
    }

    --领取
    local isNewerQuest, addCoin, addDiamond, retRewards = collectQuest(uid, questIds)
    retobj.rewards = retRewards

    if addCoin > 0 or addDiamond > 0 then
        local playerInfo = handle.moduleCall("player", "getPlayerInfo", uid)
        handle.notifyCoinChanged(playerInfo.coin, playerInfo.diamond, addCoin, addDiamond)
    end

    -- --如果还有未领取的，客户端继续展示红点
    if #questIds > 0 then
        local notify_retobj  = {}
        notify_retobj.c      = PDEFINE.NOTIFY.UQEST_DONE
        notify_retobj.code   = PDEFINE.RET.SUCCESS
        notify_retobj.uid    = uid
        notify_retobj.hasDone = quest.hasDone(uid)
        notify_retobj.questid  = questIds
        handle.sendToClient(cjson.encode(notify_retobj))

        handle.moduleCall("player","syncLobbyInfo", uid)
    end

    if isDailyTask then --每日任务
        LOG_DEBUG(' dailyPercent questIds:', questIds, ' count:', table.size(questIds))
        dailyPercent(uid, table.size(questIds))
        retobj.dailyprogress = getDailyTaskPercent(uid)
    end
    
    if isNewerQuest then --新手任务才带此字段
        retobj.rewardsList = getRewardsList(uid)
    end

    local charmlist = get_send_charm_list(uid)
    handle.syncUserInfo({uid=uid, charmlist=charmlist})

    return resp(retobj)
end

--完成任务，领取
function quest.getRewards(uid, questIds)
    --领取
    local _, _, _, rewards = collectQuest(uid, questIds)
    local charmlist = get_send_charm_list(uid)
    handle.syncUserInfo({uid=uid, charmlist=charmlist}) --同步211
    return rewards
end

local function getWheelConfig(noWeight, cat)  -- 这里和下面的loginBonus想对应
    local wheelCfg = fbshareCfg
    local redis_key = PDEFINE_REDISKEY.QUEUE.fbshare_wheel_list
    if nil ~= cat and cat == 2 then
        redis_key = PDEFINE_REDISKEY.QUEUE.bonus_wheel_list --奖励次数的转盘配置
    end
    local cacheVal = do_redis({"get", redis_key})
    local ok, cacheData = pcall(jsondecode, cacheVal)
    if ok and type(cacheData) == 'table' then
        wheelCfg = cacheData
    end

    if noWeight then
        local temCfg = {}
        for _, c in ipairs(wheelCfg) do
            table.insert(temCfg, c.rewards)
        end
        return temCfg
    end
    return wheelCfg
end

--! 获取FB分享可以拿到的奖励
function quest.getFBInfo(msg)
    local recvobj = cjson.decode(msg)
    local cmd = math.floor(recvobj.c)
    local uid = math.floor(recvobj.uid)
    local ret_share = quest.getFBShrareCoin()
    local retobj = {}
    retobj.c = cmd
    retobj.code = PDEFINE.RET.SUCCESS
    retobj.rewards = ret_share
    retobj.shared = 0 --今日未分享过
    if quest.todayHadShared(uid) then --今日已分享过，没有
        retobj.shared = 1
        for _, reward in ipairs(retobj.rewards) do
            reward.count = 0
        end
    end
    retobj.lefttime = 0 --剩余时间
    if retobj.shared == 1 then
        retobj.lefttime = getTodayLeftTimeStamp()
    end

    local fbsharewheels = handle.dcCall("user_data_dc","get_common_value", uid, PDEFINE.USERDATA.COMMON.SHARE_TURNTABLE)
    retobj.dftimes = tonumber(fbsharewheels or 0) --免费转盘(免费的)可转次数

    retobj.conf = getWheelConfig(true) --转盘配置
    local shareCnt = handle.dcCall("user_data_dc","get_common_value", uid, PDEFINE.USERDATA.COMMON.SHARE_COUNT)
    retobj.shareCnt = shareCnt or 0 --当前循环里，累计分享次数

    retobj.conf2 = getWheelConfig(true, 2) --奖励次数的转盘配置

    local remainder = do_redis({"get", PDEFINE_REDISKEY.QUEUE.bonus_wheel_step .. uid})
    remainder = tonumber(remainder or 0)
    retobj.sun = remainder
    local times = handle.dcCall("user_data_dc","get_common_value", uid, PDEFINE.USERDATA.COMMON.TIMES_OF_TURNTABLE)
    retobj.times = times or 0 --剩余次数

    return resp(retobj)
end

-- 今日是否已经fb分享(call by player)
function quest.todayHadShared(uid)
    local redisKey = PDEFINE.REDISKEY.LOBBY.fbshare
    local lastShareTime = do_redis({"hget", redisKey, "last:uid:"..uid})
    LOG_DEBUG(" quest.todayHadShared lastShareTime:", lastShareTime)
    if lastShareTime ~= nil then
        local dt = date.DiffDay(os.time(), math.floor(lastShareTime))
        if dt == 0 then -- 是同1天，说明今日分享了
            return true
        end
    end
    return false
end

--! FB每日分享领取金币任务
function quest.shareDaily(msg)
    local recvobj = cjson.decode(msg)
    local iscache = recvobj.cache --是否缓存请求
    local cmd = math.floor(recvobj.c)
    local uid = math.floor(recvobj.uid)
    local redisKey = PDEFINE.REDISKEY.LOBBY.fbshare
    local retobj = {}
    retobj.c = cmd
    retobj.code = PDEFINE.RET.SUCCESS
    retobj.uid = uid
    local daily_max = 1 --每日分享1次给金币
    -- if DEBUG then --TODO:debug
    --     daily_max = 99999
    -- end
    local lastShareTime = do_redis({"hget", redisKey, "last:uid:"..uid})
    local dt = 0
    if lastShareTime ~= nil then
        dt = date.DiffDay(os.time(), math.floor(lastShareTime))
    end
    if dt > 0 then -- 不是同一天，则清空记录
        do_redis({"hdel", redisKey, "daily:uid:"..uid})
        do_redis({"hdel", redisKey, "last:uid:"..uid})
    end
    local daily_share_num =  do_redis({"hget", redisKey, "daily:uid:"..uid}) --每日首次分享给奖励
    daily_share_num = daily_share_num or 0
    daily_share_num =  math.floor(daily_share_num) + 1

    do_redis({"hset", redisKey, "daily:uid:"..uid, daily_share_num})
    do_redis({"hset", redisKey, "last:uid:"..uid, os.time()})

    -- -- 记录分享次数
    local shareCnt = handle.dcCall("user_data_dc","get_common_value", uid, PDEFINE.USERDATA.COMMON.SHARE_COUNT)
    if not shareCnt then
        shareCnt = 0
    end

    if  daily_share_num > daily_max then --超过今日分享次数无奖励
        retobj.rewards = {}
        retobj.shareCnt = shareCnt
        retobj.spcode = 1  --告诉前端今日已分享无奖励
        return resp(retobj)
    end

    shareCnt = shareCnt + 1
    -- shareCnt = 7

    handle.dcCall("user_data_dc","set_common_value", uid, PDEFINE.USERDATA.COMMON.SHARE_TURNTABLE, 1) --可以转轮盘
    retobj.shareCnt = shareCnt
    handle.dcCall("user_data_dc","set_common_value", uid, PDEFINE.USERDATA.COMMON.SHARE_COUNT, shareCnt)
    if not iscache then
        handle.addStatistics(uid, 'open_share', '')
    end
    handle.moduleCall("quest", 'updateQuest', uid, PDEFINE.QUEST_TYPE.NEWER, PDEFINE.QUESTID.NEW.SHAREFB, 1)
    handle.moduleCall("quest", 'updateQuest', uid, PDEFINE.QUEST_TYPE.REPEAT, PDEFINE.QUESTID.DAILY.GAMESHARE, 1)
    pcall(cluster.call, "master", ".userCenter", "syncLobbyInfo", uid)
    LOG_DEBUG("quest.shareDaily retobj:", retobj)

    -- 更新主线任务
    -- local updateMainObjs = {
    --     {kind=PDEFINE.MAIN_TASK.KIND.ShareFb, count=1},
    -- }
    -- handle.moduleCall("maintask", "updateTask", UID, updateMainObjs)
    return resp(retobj)
end

-- 保存最近10条中奖记录
local function addRecord(uid, cat, coin)
    local data = {}
    local cacheKey = string.format("wheel_record:%d", uid)
    local recordsStr = do_redis({ "get", cacheKey})
    local ok, records = pcall(jsondecode, recordsStr)
    if ok then
        data = records
        
    end
    local nowtime = os.time()
    table.insert(data, {
        coin = coin,
        type = cat,
        t = nowtime,
    })
    if #data > 10 then
        table.remove(data, 1)
    end
    do_redis({ "set", cacheKey, cjson.encode(data)})
    return data
end

--! 获取用户的转盘记录
function quest.getWheelRecords(msg)
    local recvobj = cjson.decode(msg)
    local cmd = math.floor(recvobj.c)
    local uid = math.floor(recvobj.uid) 
    
    local retobj = {}
    retobj.c = cmd
    retobj.code = PDEFINE.RET.SUCCESS
    retobj.datalist = {}
    retobj.uid = UID

    local cacheKey = string.format("wheel_record:%d", uid)
    local recordsStr = do_redis({ "get", cacheKey})
    local ok, records = pcall(jsondecode, recordsStr)
    if ok then
        retobj.datalist = records
    end
    return resp(retobj)
end

--! FB分享，轮盘抽奖
function quest.shareTurntable(msg)
    local recvobj = cjson.decode(msg)
    local cmd = math.floor(recvobj.c)
    local cat = tonumber(recvobj.cat or 0) --转盘类型 2:金转盘 0:默认分享一次的转盘
    local uid = math.floor(recvobj.uid)
    local retobj = {}
    retobj.c = cmd
    retobj.spcode = 0
    retobj.code = PDEFINE.RET.SUCCESS
    retobj.diamond = 0
    retobj.uid = uid
    retobj.idx = 0
    retobj.rewards = {}
    if cat == BONUS_WHEEL_TYPE then 
        -- 扣奖励次数
        local times = handle.dcCall("user_data_dc","get_common_value", uid, PDEFINE.USERDATA.COMMON.TIMES_OF_TURNTABLE)
        times = tonumber(times or 0)
        if times <=0 then
            retobj.spcode = 1
            return resp(retobj)
        end
        times = times - 1
        handle.dcCall("user_data_dc","set_common_value", uid, PDEFINE.USERDATA.COMMON.TIMES_OF_TURNTABLE, times)
        retobj.times = times
        do_redis({"set", PDEFINE_REDISKEY.QUEUE.bonus_wheel_step..uid, 0}) --清理掉此轮人数
    else
        local flag = handle.dcCall("user_data_dc","get_common_value", uid, PDEFINE.USERDATA.COMMON.SHARE_TURNTABLE)
        if not flag or flag ~= 1 then
            retobj.spcode = 1
            return resp(retobj)
        end
        handle.dcCall("user_data_dc","set_common_value", uid, PDEFINE.USERDATA.COMMON.SHARE_TURNTABLE, 0)
    end

    local typeStr = 'questfb'
    local config = getWheelConfig()
    if cat == BONUS_WHEEL_TYPE then
        config = getWheelConfig(nil, 2)
        typeStr = "questwheel"
    end
    local idx , rs = randByWeight(config)
    retobj.idx = idx
    retobj.rewards = table.copy(rs.rewards)
    local addCoin = 0
    for _, reward in ipairs(retobj.rewards) do
        if reward.type == PDEFINE.PROP_ID.COIN then
            addCoin = addCoin + reward.count
            handle.addProp(reward.type, reward.count, typeStr)
        end
    end

    if addCoin > 0 then
        local playerInfo = handle.moduleCall("player", "getPlayerInfo", uid)
        handle.notifyCoinChanged(playerInfo.coin, playerInfo.diamond, addCoin, 0)
        local orderid = os.date("%Y%m%d%H%M%S", os.time()) .. payId()
        handle.moduleCall("player","addBonusLog", orderid, '每日分享彩金', addCoin, os.time(), PDEFINE.TYPE.SOURCE.Share, uid, 0)
        addRecord(uid, cat, addCoin)
        handle.moduleCall("player","syncLobbyInfo", uid)
    end
    return resp(retobj)
end

--! login bonus
function quest.loginBonus(msg)
    local recvobj = cjson.decode(msg)
    local uid = math.floor(recvobj.uid)
    local retobj = {
        c = math.floor(recvobj.c),
        code = PDEFINE.RET.SUCCESS,
        spcode = 0,
        data = {}
    }
    local item = {}
    --invite
    item['invite'] =  {
        {
            type = PDEFINE.PROP_ID.COIN,
            count=1,
            min = 1500,
            max = 91500
        },
        {
            type = PDEFINE.PROP_ID.DIAMOND,
            min = 30,
            max = 600,
            count=1,
        }
    }
    --sharefb
    item['sharefb'] = {  -- 这里和上面的getWheelConfig想对应
        {
            type = PDEFINE.PROP_ID.DIAMOND,
            min = 20,
            max = 40,
            count=1,
        },
        {type=PDEFINE.PROP_ID.SKIN_FRAME, count=3, days=3, img=PDEFINE.SKIN.FBSHARE.AVATAR.img},
        {type=PDEFINE.PROP_ID.SKIN_CHAT, count=10, days=3, img=PDEFINE.SKIN.FBSHARE.CHAT.img},
        {type=PDEFINE.PROP_ID.SKIN_TABLE, img='desk_002',count=1, days=3},
        {type=PDEFINE.PROP_ID.SKIN_CHARM, img='gift_cake', count=1},
    }
    --weekly sign
    item['sign'] = {
        {
            type = PDEFINE.PROP_ID.COIN,
            min = 50000,
            max = 750000,
            count=1,
        },
        {
            type = PDEFINE.PROP_ID.DIAMOND,
            min = 0,
            max = 100,
            count=1,
        }
    }
    --online
    local ok, configmgr = pcall(cluster.call, "master", ".configmgr", 'get', "turntable")
    local conf  = cjson.decode(configmgr.v)
    item['online'] = {
        {
            type = PDEFINE.PROP_ID.COIN,
            count=conf['coins'][1],
        },
        {
            type = PDEFINE.PROP_ID.COIN,
            count=conf['coins'][2],
        }
    }
    retobj.data = item

    return resp(retobj)
end

--! 新手任务列表
function quest.newbie(msg)
    local recvobj = cjson.decode(msg)
    local uid = math.floor(recvobj.uid)
    local cmd = math.floor(recvobj.c)
    local retobj = {
        c = cmd,
        code = PDEFINE.RET.SUCCESS,
        spcode = 0,
        rewardsList = {},
        questList = {}
    }
    local retcode, retStr = quest.getInfoObj(uid, cmd, {PDEFINE.QUEST_TYPE.NEWER})
    local ok, ret = pcall(jsondecode, retStr)
    if ok then
        retobj.questList = ret.questList
    end
    
    retobj.rewardsList = getRewardsList(uid)
    return resp(retobj)
end

--! 新手任务是否已完成
function quest.noviceTaskDone(uid)
    local cnt = 0
    local questList = handle.dcCall("quest_dc","get_list", uid)
    if questList and not table.empty(questList) then
        for _, row in pairs(questList) do
            if tonumber(row.cat) == PDEFINE.QUEST_TYPE.NEWER and row.state == PDEFINE.QUEST_STATE.DONE then
                cnt = cnt + 1  
            end
        end
    end
    local rewardsList = getRewardsList(uid)
    for _, row in pairs(rewardsList) do
        if row.state == 1 then --新手任务 上面的3个也可以领取
            cnt = cnt + 1
        end
    end
    return cnt
end

-- 更新点数
function quest.updateNewbieRewards(uid)
    local prefix = 'newbie:'
    local rewards = do_redis({ "hgetall", prefix .. uid},uid)
    rewards = make_pairs_table(rewards)
    LOG_DEBUG("updateNewbieRewards rewards:",rewards)
    local prize = 0
    if not rewards or table.empty(rewards) then
        rewards = {}
        rewards.id = 1 --当前id
        rewards.hasdone = cjson.encode({})
        rewards.hasget = cjson.encode({})
        rewards.times = 1 
        rewards.max = PDEFINE.NEWBIE_QUEST[1].max
        do_redis({ "hmset", prefix..uid, rewards }, uid)
    else
        local idx = rewards.id
        rewards.times = tonumber(rewards.times) + 1
        if tonumber(rewards.times) >= tonumber(rewards.max) then
            prize = tonumber(rewards.id)
            local hadone = cjson.decode(rewards.hasdone)
            rewards.hasdone = hadone
            table.insert(rewards.hasdone, idx)
            rewards.id = tonumber(rewards.id) + 1
            if PDEFINE.NEWBIE_QUEST[rewards.id] then
                rewards.max = PDEFINE.NEWBIE_QUEST[rewards.id].max
            else
                rewards.max = PDEFINE.NEWBIE_QUEST[1].max
            end
            
            rewards.times = 0
            rewards.hasdone = cjson.encode(rewards.hasdone)
            local hasget = cjson.decode(rewards.hasget)
            rewards.hasget = cjson.encode(hasget)
        end
        do_redis({ "hmset", prefix..uid, rewards}, uid)
    end
    return prize
end

--! 领取新手累计任务的奖励
function quest.getNewBieRewards(msg)
    local recvobj = cjson.decode(msg)
    local uid = math.floor(recvobj.uid)
    local id = math.floor(recvobj.id) --奖励ID

    local retobj = {
        c = math.floor(recvobj.c),
        code = PDEFINE.RET.SUCCESS,
        spcode = 0,
        rewards = {}
    }

    local prefix = 'newbie:'
    local rewards = do_redis({ "hgetall", prefix .. uid},uid)
    rewards = make_pairs_table(rewards)
    if not rewards or table.empty(rewards) then
        retobj.spcode = PDEFINE.RET.ERROR.QUEST_NOT_DONE
        return resp(retobj)
    else
        local hasget = cjson.decode(rewards.hasget)
        if not table.empty(hasget) then
            for i=1,#hasget do
                hasget[i] = tonumber(hasget[i])
            end
        end
        local hasdone = cjson.decode(rewards.hasdone)
        if not table.empty(hasdone) then
            for i=1,#hasdone do
                hasdone[i] = tonumber(hasdone[i])
            end
        end
        if table.contain(hasget, id) then
            retobj.spcode = PDEFINE.RET.ERROR.QUEST_HAD_GET
            return resp(retobj)
        end
        if not table.contain(hasdone, id) then
            retobj.spcode = PDEFINE.RET.ERROR.QUEST_NOT_DONE
            return resp(retobj)
        end
        if table.contain(hasdone, id) and not table.contain(hasget, id) then
            table.insert(hasget, id)
            rewards.hasget = cjson.encode(hasget)
            rewards.hasdone = cjson.encode(hasdone)
            if tonumber(id) == 3 then
                handle.dcCall("user_data_dc","set_common_value", uid, PDEFINE.USERDATA.COMMON.DONE_NEWBIE, 1)
            end
            do_redis({ "hmset", prefix..uid, rewards}, uid)
            
            for _, row in pairs(PDEFINE.NEWBIE_QUEST) do
                if tonumber(row.id) == tonumber(id) then
                    if row.type == PDEFINE.PROP_ID.SKIN_CHAT or row.type == PDEFINE.PROP_ID.SKIN_FRAME then
                        handle.moduleCall("player", "addSkinImg", uid, row.img, row.category)
                        table.insert(retobj.rewards, {type=row.type, count=1, img=row.img})
                    elseif row.type == PDEFINE.PROP_ID.TEMP_VIP_LEVEL then
                        local playerInfo = handle.moduleCall("player", "getPlayerInfo", uid)
                        local oldEndtime = playerInfo.vipendtime or 0
                        local day = tonumber(row.days or 1)
                        local seconds = 86400 * day --赠送vip
                        local endtime = handle.dcCall("user_dc", "getvalue", uid, "vipendtime") or 0
                        local now = os.time()
                        if endtime >= now then
                            endtime = endtime + seconds
                        else
                            local leftTime = getTodayLeftTimeStamp()
                            endtime = now + leftTime + seconds - 86400 --当天已过时间也算到vip有效时间内
                        end
                        local ok, res = pcall(cluster.call, "master", ".configmgr", "getVipUpCfg")
                        local addExp = 0
                        local needExp = 0
                        local svipexp = playerInfo.svipexp
                        if ok then
                            needExp = res[row.level+1].diamond
                        end
                        -- 如果当前没有vip3的经验，
                        if needExp > svipexp then
                            addExp = needExp - svipexp
                            handle.dcCall("user_dc", "setvalue", UID, "svipexp", needExp)
                            handle.dcCall("user_data_dc","set_common_value", uid, PDEFINE.USERDATA.COMMON.TEMP_VIP_EXP, addExp)
                        end
                        handle.dcCall("user_dc", "setvalue", uid, "vipendtime", endtime)
                        handle.moduleCall("upgrade", "activeVip", oldEndtime)
                        table.insert(retobj.rewards, {type=PDEFINE.PROP_ID.VIP_POINT, count=addExp})
                    end
                    handle.moduleCall("player","syncLobbyInfo", UID)
                    
                    break
                end
            end
        end
    end
    return resp(retobj)
end

--! 完成新手任务的查看vip或排行功能
function quest.doneView(msg)
    local recvobj = cjson.decode(msg)
    local uid = math.floor(recvobj.uid)
    local id = math.floor(recvobj.id or 2)
    local questid = PDEFINE.QUESTID.DAILY.EMOJI --查看排行榜榜单 , 去掉了
    local retobj = {
        c = math.floor(recvobj.c),
        code = PDEFINE.RET.SUCCESS,
        spcode = 0,
    }
    if id == 2 then
        -- questid = PDEFINE.QUESTID.NEW.VIEWVIP --查看VIP榜单
    elseif id == 3 then
        questid = PDEFINE.QUESTID.DAILY.EMOJI --游戏内互动表情包
        quest.updateQuest(uid,PDEFINE.QUEST_TYPE.NEWER, questid, 1)
    end
    
    return resp(retobj)
end

-- 修改完昵称后，领取奖励
function quest.getChangeNickRewards(msg)
    local recvobj = cjson.decode(msg)
    local uid = math.floor(recvobj.uid)
    local retobj = {
        c = math.floor(recvobj.c),
        code = PDEFINE.RET.SUCCESS,
        spcode = 0,
        rewards = {}
    }
    -- local _, _, _, rewards = collectQuest(uid, {PDEFINE.QUESTID.NEW.CHANGENICKNAME})
    -- table.insert(rewards, {type=PDEFINE.PROP_ID.SKIN_FRAME, count=1, img=PDEFINE.SKIN.CHANGENICK.AVATAR.img, days=PDEFINE.SKIN.CHANGENICK.AVATAR.days})
    -- retobj.rewards = rewards

    -- handle.dcCall("user_dc", "setvalue", uid, "avatarframe", PDEFINE.SKIN.CHANGENICK.AVATAR.img)
    -- local charmlist = get_send_charm_list(uid)
    -- handle.syncUserInfo({uid=uid, charmlist=charmlist, avatarframe=PDEFINE.SKIN.CHANGENICK.AVATAR.img}) --同步211
    return resp(retobj)
end

-- 获取当日沙龙任务redis前缀
local function getSpecialQuestRedisKey(uid, questid)
    return "quest:special:"..uid..":"..questid
end

-- 获取当日特殊任务的红点状态
function quest.getSpecialQuestRedot(uid)
    local created, played = 0, 0
    for _, cfg in pairs(s_special_quest.tasks) do
        local redis_key = getSpecialQuestRedisKey(uid, cfg.id)
        local status = do_redis({"hget", redis_key, "status"}) 
        status = tonumber(status or s_special_quest.status.Doing)
        if status == s_special_quest.status.Done then
            if cfg.type == s_special_quest.type.CreateSalon then
                created = 1
            else
                played = 1
            end
        end
    end
    return created, played
end

-- 获取当日沙龙任务信息
function quest.getSpecialQuest(msg)
    local recvobj = cjson.decode(msg)
    local uid = math.floor(recvobj.uid)
    local retobj = {
        c = math.floor(recvobj.c),
        code = PDEFINE.RET.SUCCESS,
        spcode = 0,
        quests = {}
    }
    local firstTime = handle.dcCall("user_data_dc","get_common_value", uid, PDEFINE.USERDATA.COMMON.SPECIAL_QUEST)
    local zeroTime = date.GetTodayZeroTime(os.time())
    LOG_DEBUG("firstTime:",firstTime, " zeroTime:", zeroTime, " uid:", uid)
    if not firstTime or firstTime == 0 or firstTime == zeroTime then
        firstTime = true
    else
        firstTime = false
    end

    local redis_key = PDEFINE_REDISKEY.QUEUE.salon_tasks_list
    local tasks = s_special_quest.tasks
    local cacheVal = do_redis({"get", redis_key})
    local ok, cacheTasks = pcall(jsondecode, cacheVal)
    if ok and type(cacheTasks) == 'table' then
        tasks = cacheTasks
    end
    for _, cfg in pairs(tasks) do
        local task = table.copy(cfg)
        local redis_key = getSpecialQuestRedisKey(uid, cfg.id)
        local status = do_redis({"hget", redis_key, "status"}) or s_special_quest.status.Doing
        local count = do_redis({"hget", redis_key, "count"}) or 0
        status = tonumber(status)
        count = tonumber(count)
        task.status = status
        task.count = status

        if firstTime then
            task.rewards = task.firstTime
        end
        task.firstTime = nil
        table.insert(retobj.quests, task)
    end
    return resp(retobj)
end

-- 领取当日沙龙任务奖励
function quest.getSpecialQuestReward(msg)
    local recvobj = cjson.decode(msg)
    local uid = math.floor(recvobj.uid)
    local questid = math.floor(recvobj.questid)
    local retobj = {
        c = math.floor(recvobj.c),
        code = PDEFINE.RET.SUCCESS,
        spcode = 0,
        rewards = {}
    }
    local redis_key = getSpecialQuestRedisKey(uid, questid)
    local status = do_redis({"hget", redis_key, "status"}) or s_special_quest.status.Doing
    status = tonumber(status)
    if status == s_special_quest.status.Doing then
        retobj.spcode = PDEFINE_ERRCODE.ERROR.QUEST_NOT_DONE
        return resp(retobj)
    end
    if status == s_special_quest.status.Compelte then
        retobj.spcode = PDEFINE_ERRCODE.ERROR.QUEST_HAD_GET
        return resp(retobj)
    end
    local firstTime = handle.dcCall("user_data_dc","get_common_value", uid, PDEFINE.USERDATA.COMMON.SPECIAL_QUEST)
    local zeroTime = date.GetTodayZeroTime(os.time())
    LOG_DEBUG("firstTime:",firstTime, " zeroTime:", zeroTime, " uid:", uid)
    if not firstTime or firstTime == 0 or firstTime == zeroTime then
        firstTime = true
    else
        firstTime = false
    end

    for _, cfg in pairs(s_special_quest.tasks) do
        if cfg.id == questid then
            if firstTime then
                retobj.rewards = table.copy(cfg.firstTime)
            else
                retobj.rewards = table.copy(cfg.rewards)
            end
        end

    end
    for _, reward in pairs(retobj.rewards) do
        handle.addProp(reward.type, reward.count, 'quest')
    end
    -- 只有第一次需要插入数值
    -- if firstTime then
    --     handle.dcCall("user_data_dc","set_common_value", uid, PDEFINE.USERDATA.COMMON.SPECIAL_QUEST, zeroTime)
    -- end
    do_redis({"hset", redis_key, "status", s_special_quest.status.Compelte})
    handle.moduleCall("player","syncLobbyInfo", uid)
    -- 第一次任务，领取了所有奖励，则刷新
    if firstTime then
        local hasRewards = false
        for _, cfg in pairs(s_special_quest.tasks) do
            local redis_key = getSpecialQuestRedisKey(uid, cfg.id)
            local status = do_redis({"hget", redis_key, "status"}) or s_special_quest.status.Doing
            status = tonumber(status)
            if status ~= s_special_quest.status.Compelte then
                hasRewards = true
                break
            end
        end
        -- 如果领取了所有奖励，则设置倒计时刷新
        if not hasRewards then
            local delayTime = date.GetTodayZeroTime(os.time()) + 24*60*60 - os.time()
            for _, cfg in pairs(s_special_quest.tasks) do
                local redis_key = getSpecialQuestRedisKey(uid, cfg.id)
                do_redis({"expire", redis_key, delayTime})
            end
            handle.dcCall("user_data_dc","set_common_value", uid, PDEFINE.USERDATA.COMMON.SPECIAL_QUEST, zeroTime)
        end
    end
    return resp(retobj)
end

-- 完成当日沙龙任务
function quest.updateSpecialQuest(uid, type, cnt)
    local donePrequest = false
    for _, cfg in pairs(s_special_quest.tasks) do
        local redis_key = getSpecialQuestRedisKey(uid, cfg.id)
        local status = do_redis({"hget", redis_key, "status"}) or s_special_quest.status.Doing
        local count = do_redis({"hget", redis_key, "count"}) or 0
        status = tonumber(status)
        count = tonumber(count)
        if cfg.type == s_special_quest.type.CreateSalon and status ~= s_special_quest.status.Doing then
            donePrequest = true
        end
        if cfg.type == type and status ~= s_special_quest.status.Doing then
            return
        end
    end
    -- 玩一局沙龙游戏需要先完成第一个任务
    if type == s_special_quest.type.PlaySalon and not donePrequest then
        return
    end
    for _, cfg in pairs(s_special_quest.tasks) do
        if cfg.type == type then
            local redis_key = getSpecialQuestRedisKey(uid, cfg.id)
            local count = do_redis({"hget", redis_key, "count"}) or 0
            count = tonumber(count) + cnt
            if count >= cfg.need then
                count = cfg.need
                do_redis({"hset", redis_key, "status", s_special_quest.status.Done})
                handle.moduleCall("player","syncLobbyInfo", uid)
            end
            do_redis({"hset", redis_key, "count", count})
        end
    end
    local now = os.time()
    -- 只有第一次需要插入数值
    local firstTime = handle.dcCall("user_data_dc","get_common_value", uid, PDEFINE.USERDATA.COMMON.SPECIAL_QUEST)
    local zeroTime = date.GetTodayZeroTime(now)
    if not firstTime or firstTime == 0 or firstTime == zeroTime then
        firstTime = true
    else
        firstTime = false
    end
    -- 非第一次任务，设置一天过期
    if not firstTime then
        local delayTime = date.GetTodayZeroTime(now) + 24*60*60 - now
        for _, cfg in pairs(s_special_quest.tasks) do
            local redis_key = getSpecialQuestRedisKey(uid, cfg.id)
            do_redis({"expire", redis_key, delayTime})
        end
    else
        --记录第一次完成时间
        handle.dcCall("user_data_dc","set_common_value", uid, PDEFINE.USERDATA.COMMON.SPECIAL_QUEST..type, now)
    end
end

return quest