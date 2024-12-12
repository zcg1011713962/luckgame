local cmd = {}
local handle
local date = require "date"
local skynet = require "skynet"
local cjson   = require "cjson"
cjson.encode_sparse_array(true)
cjson.encode_empty_table_as_object(false)
local cluster = require "cluster"
local sysmarquee = require "sysmarquee"
local DEBUG = skynet.getenv("DEBUG")

function cmd.bind(agent_handle)
    handle = agent_handle
end

local taskConfig = {}
local allTask
local UID

local TASK_TYPE = {
    ["RECHARGE"] = 11 , --充值任务
    ["BET"] = 33, --下注任务
    ["WINCOIN"] = 23, --盈利任务
    ["GAMETIMES"] = 22, --游戏局数
}
--成功返回
local function resp(retobj)
    return PDEFINE.RET.SUCCESS, cjson.encode(retobj)
end

--加载配置
local function loadTaskConfig()
    if table.empty(taskConfig) then
        local ok, tmp = pcall(cluster.call, "master", ".configmgr", 'getMainTasks')
        if ok then
            taskConfig = tmp
        end
    end
    return taskConfig
end

-- 根据sql语句返回tasks对象
local function getTasksFromDb(sql)
    local rs = skynet.call(".mysqlpool", "lua", "execute", sql)
    local tasks = {}
    if rs and #rs > 0 then
        loadTaskConfig()
        for _, d in ipairs(rs) do
            -- 只缓存目前配置中有的数据
            if taskConfig[d['type']] then
                local task = {
                    id = d['id'],
                    uid = d['uid'],
                    taskid = d['taskid'],
                    type = d['type'],
                    count = d['count'],
                    state = d['state'],
                    createtime = d['createtime'],
                }
                table.insert(tasks, task)
            end
        end
        return tasks
    else
        return nil
    end
end

-- 更新所有数据到redis中
local function getTasksAndCache(uid)
    local sql = string.format("select * from d_main_task where uid=%d", uid)
    allTask = getTasksFromDb(sql)
end

-- 从数据库中加载指定任务配置
-- 数据库中的索引是(uid, type, taskid)
local function getTask(uid, taskid, type)
    if allTask then
        for _, task in ipairs(allTask) do
            if task.taskid == taskid and task.type == type then
                return task
            end
        end
    end
    local sql = string.format("select * from d_main_task where uid=%d and type=%d and taskid=%d", uid, type, taskid)
    local tasks = getTasksFromDb(sql)
    if tasks and #tasks > 0 then
        table.insert(allTask, tasks[1])
        return tasks[1]
    end
    return nil
end

-- 更新数据库中的状态和数量
local function updateTaskFromDb(task)
    local sql
    local nowtime = os.time()
    task.count = tonumber(task.count or 0)
    task.count = math.floor(task.count)
    if not task.id then
        sql = string.format("update d_main_task set update_time=%d,state=%d, count=%d where uid=%d and taskid=%d and type=%d", nowtime, task.state, task.count,task.uid, task.taskid, task.type)
    else
        sql = string.format("update d_main_task set state=%d, count=%d where id=%d", task.state, task.count,task.id)
        if task.state == PDEFINE.MAIN_TASK.STATE.Complete then
            sql = string.format("update d_main_task set update_time=%d,state=%d, count=%d where id=%d", nowtime, task.state, task.count,task.id)
        end
    end
    LOG_DEBUG("updateTaskFromDb task:", sql)
    skynet.send(".mysqlpool", "lua", "execute", sql, true)
end

-- 获取已完成任务的数量
local function getTaskReddotFromDb(uid)
    loadTaskConfig()
    if allTask then
        local cnt = 0
        for _, task in ipairs(allTask) do
            if task.state == PDEFINE.MAIN_TASK.STATE.Done then
                cnt = cnt + 1
            end
        end
        return cnt
    else
        local sql = string.format("select count(*) as cnt from d_main_task where uid=%d and state=%d", uid, PDEFINE.MAIN_TASK.STATE.Done)
        local rs = skynet.call(".mysqlpool", "lua", "execute", sql)
        if rs and #rs > 0 then
            return rs[1]['cnt']
        end
    end
    return 0
end

-- 获取所有可显示的任务
local function getShowTasks(uid)
    local tasks = {}
    if allTask then
        for _, task in ipairs(allTask) do
            table.insert(tasks, task)
        end
    else
        local sql = string.format("select * from d_main_task where uid=%d order by id desc", uid)
        tasks = getTasksFromDb(sql)
        if not tasks then
            return {}
        end
    end
    return tasks
end

-- 获取所有正在进行中的任务
local function getDoingTasks(uid)
    local tasks = {}
    if allTask then
        for _, task in ipairs(allTask) do
            if task.state == PDEFINE.MAIN_TASK.STATE.Doing then
                table.insert(tasks, task)
            end
        end
    else
        local sql = string.format("select * from d_main_task where uid=%d and state=%d order by id desc", uid, PDEFINE.MAIN_TASK.STATE.Doing)
        tasks = getTasksFromDb(sql)
        if not tasks then
            return {}
        end
    end
    return tasks
end

-- 添加完成日志
local function addDoneLog(uid, task)
    if nil == uid then
        return
    end
    -- 完成日志
    local nowtime = os.time()
    local sql = string.format([[
        insert into d_main_task_log(uid,taskid,type,create_time)
        values(%d,%d,%d,%d)
    ]], uid, task.taskid, task.type, nowtime)
    do_mysql_queue(sql)

    -- 统计
    local sql = string.format([[
        insert into d_main_task_stat(day,taskid,type,total,update_time)
        values('%s',%d,%d,%d,%d)
        on duplicate key update `total`=total+1, `update_time`=%d
    ]], os.date("%Y-%m-%d", nowtime), task.taskid, task.type, 1, nowtime,nowtime)
    do_mysql_queue(sql)
end

local function getNextTask(type, current)
    local taskListCfg = taskConfig[type]
    local nextTask = nil
    if taskListCfg then
        for _, taskCfg in pairs(taskListCfg) do
            if taskCfg.param1 > current then
                if not nextTask or taskCfg.param1 < nextTask.param1 then
                    nextTask = taskCfg
                end
            end
        end
    end
    return nextTask
end

--通知前端任务完成
local function notifyTaskDone(uid, task, desc, delaySec)
    local notify  = {
        c = PDEFINE.NOTIFY.QUEST_UPDATED,
        code = PDEFINE.RET.SUCCESS,
        uid = uid,
        taskid = task.taskid,
        type = task.type,
        desc = desc,
        count = task.count,
        nextdesc = "",
        nextcount = -1,
    }
    local nextTask = getNextTask(task.type, task.count)
    if nextTask then
        notify.nextcount = nextTask.param1
        notify.nextdesc = nextTask.title_en
    end
    skynet.timeout(delaySec*100, function()
        handle.sendToClient(cjson.encode(notify))
    end)
end

-- 初始化任务
local function initTask(taskCfg, uid, type, count, state)
    local task = {
        uid = uid,
        taskid = taskCfg.id,
        type = type,
        count = count or 0,
        state = state or PDEFINE.MAIN_TASK.STATE.Doing,
        createtime = os.time(),
    }
    local sql = string.format([[
        insert into d_main_task(uid, taskid, type, count, state, createtime) 
        values(%d,%d,%d,%d,%d,%d)
        on duplicate key update `count`=%d, `state`=%d
    ]], task.uid, task.taskid, task.type, task.count, task.state, task.createtime, task.count, task.state)
    skynet.call(".mysqlpool", "lua", "execute", sql, true)
    if not allTask then
        allTask = {}
    end
    table.insert(allTask, task)
    LOG_DEBUG("initTask user tasks:", allTask)
    return task
end

function cmd.initUid(uid)
    UID = uid
end

-- 任务初始化
function cmd.init(uid)
    loadTaskConfig()
    if table.empty(taskConfig) then
        return nil
    end
    -- 先获取所有需要更新的task
    getTasksAndCache(uid)
    UID = uid
    for type, cfgs in pairs(taskConfig) do
        for _, cfg in pairs(cfgs) do
            local task = getTask(uid, cfg.id, type)
            if not task then
                initTask(cfg, uid, type)
            end
        end
    end
end

-- 重置所有每日任务
function cmd.reset(uid)
    local sql = string.format("update d_main_task set state=1,count=0,update_time=0 where uid=%d", uid)
    skynet.call(".mysqlpool", "lua", "execute", sql)
    cmd.init(uid)
end

-- 查询小红点状态
function cmd.reddot(uid, level)
    if not level then
        return 0
    end
    local doneCnt = getTaskReddotFromDb(uid)
    if doneCnt > 0 then
        return doneCnt
    end
    return 0 
end

-- 获取所有任务
function cmd.getTaskList(msg)
    local recvobj   = cjson.decode(msg)
    local uid       = math.floor(recvobj.uid)
    local agentLanguage = recvobj.language or 1 -- 1:阿拉伯 2:英文
    local retobj = {
        c = math.floor(recvobj.c),
        code = PDEFINE.RET.SUCCESS, 
        spcode = nil,
        tasks = {},
    }
    
    -- 获取当前显示任务
    local tasks = getShowTasks(uid)
    -- local is_english = handle.isEnglish()
    local is_english = true
    for _, task in ipairs(tasks) do
        local taskCfg = taskConfig[task.type][task.taskid]
        if taskCfg then
            local taskObj = {
                taskid = task.taskid,
                desc = is_english and taskCfg.title_en or taskCfg.title,
                type = task.type,
                need = taskCfg.param1,
                count = task.count,
                state = task.state,
                rewards = table.copy(taskCfg.rewards),
                ord = taskCfg.ord,
                jumpTo = 0, --往哪里跳转
            }
            -- 时长类型的，需要特殊处理，需要将分钟转成小时
            if taskObj.state == PDEFINE.MAIN_TASK.STATE.Doing then
                if task.type == PDEFINE.MAIN_TASK.KIND.MatchGameTime 
                or task.type == PDEFINE.MAIN_TASK.KIND.OnlineTime
                or task.type == PDEFINE.MAIN_TASK.KIND.PrivateGameTime then
                    taskObj.count = taskObj.count // 60
                end
            end
            if taskObj.state == PDEFINE.MAIN_TASK.STATE.Complete or taskObj.state == PDEFINE.MAIN_TASK.STATE.Done then
                taskObj.count = taskObj.need
            end
            table.insert(retobj.tasks, taskObj)
        end
    end

    return resp(retobj)
end

-- 更新任务状态
-- 通过 kind类型 来更新状态
-- objs: {{kind=1, count=1, limit}, {kind=1, count=1}}
function cmd.updateTask(uid, objs)
    local tasks = getDoingTasks(uid)
    local change = false
    for _, obj in ipairs(objs) do
        for _, task in ipairs(tasks) do
            if task.state ~= PDEFINE.MAIN_TASK.STATE.Complete and task.state ~= PDEFINE.MAIN_TASK.STATE.Done then
                local taskCfg = taskConfig[task.type][task.taskid]
                local exist = false
                if obj.kind == PDEFINE.MAIN_TASK.KIND.GameTimes then
                    if nil~=taskCfg and not table.empty(taskCfg.gameids) then
                        if table.contain(taskCfg.gameids, tonumber(obj.gameid)) then
                            exist = true
                        end
                    end
                elseif obj.kind == task.type then
                    exist = true
                end
                if exist then
                    if task.type == PDEFINE.MAIN_TASK.KIND.ContinuousLogin then
                        if task.count == 0 then
                            task.count = 1
                        else
                            task.count = task.count + 1
                        end
                    elseif task.type == PDEFINE.MAIN_TASK.KIND.VipLevel then
                        if task.count < obj.count then
                            task.count = obj.count
                        end
                    else
                        task.count = task.count + obj.count
                    end
                    local getRealCount = function(task_type, count)
                        -- 时长类型的，需要特殊处理，需要将分钟转成小时
                        if task_type == PDEFINE.MAIN_TASK.KIND.MatchGameTime 
                        or task_type == PDEFINE.MAIN_TASK.KIND.OnlineTime
                        or task_type == PDEFINE.MAIN_TASK.KIND.PrivateGameTime then
                            count = count // 60
                        end
                        return count
                    end
                    -- 不能超出最大值
                    if nil~=taskCfg and getRealCount(task.type, task.count) >= taskCfg.param1 then
                        --通知任务完成
                        local delaySec = 2
                        if task.type == PDEFINE.MAIN_TASK.KIND.WinCoin then
                            delaySec = 15
                        end
                        notifyTaskDone(uid, task, taskCfg.title_en, delaySec)
                        --修改任务状态
                        task.count = taskCfg.param1
                        task.state = PDEFINE.MAIN_TASK.STATE.Done
                        --任务完成日志
                        addDoneLog(uid, task)
                    end
                    updateTaskFromDb(task)
                    change = true
                end
            end
        end
    end
    if change then
        handle.moduleCall("player","syncLobbyInfo", UID)
    end
end

-- 获取任务奖励
function cmd.getTaskReward(msg)
    local recvobj   = cjson.decode(msg)
    local uid       = math.floor(recvobj.uid)
    local taskid    = recvobj.taskid and math.floor(recvobj.taskid) or nil
    local type      = recvobj.type and math.floor(recvobj.type) or nil
    local retobj = {
        c = math.floor(recvobj.c),
        code = PDEFINE.RET.SUCCESS,
        spcode = 0,
        taskid = taskid,
        type = type,
        rewards = {}, -- 获取到的奖励
        shadow = {},  -- 需要隐藏的任务 {type, taskid}
    }

    -- 先获取所有任务信息
    local task = getTask(uid, taskid, type)
    if not task then
        retobj.spcode = PDEFINE_ERRCODE.ERROR.QUEST_NOT_DONE
        return resp(retobj)
    end
    -- local rewardMapSkin = {} --桌背，牌背，牌花，聊天框，头像框
    local totaladdcoin = 0
    local coin = 0
    local coin_can_draw = 0
    local coin_bonus = 0
    if task.state == PDEFINE.MAIN_TASK.STATE.Done then
        task.state = PDEFINE.MAIN_TASK.STATE.Complete   -- 更改任务状态
        local taskCfg = taskConfig[task.type][task.taskid]
        local addcoin = 0
        for _, reward in ipairs(taskCfg.rewards) do
            if reward.type == PDEFINE.PROP_ID.COIN then
                addcoin = addcoin + reward.count
            end
        end
        if addcoin > 0 then
            local bonusRemark = "任务充值金额".. taskCfg.param1 .. ",任务奖励:"..addcoin
            if type == TASK_TYPE.BET then
                bonusRemark = "任务投注金额".. taskCfg.param1 .. ",任务奖励:"..addcoin
            elseif type == TASK_TYPE.WINCOIN then
                bonusRemark = "任务盈利金额".. taskCfg.param1 .. ",任务奖励:"..addcoin
            elseif type == TASK_TYPE.GAMETIMES then
                bonusRemark = "任务游戏场次".. taskCfg.param1 .. ",任务奖励:"..addcoin
            end
            local coins = handle.moduleCall("player", 'addCoinByRate', uid, addcoin, taskCfg.rate, task.type, nil, nil, nil, nil, bonusRemark)
            coin = coin + coins[1]
            coin_can_draw = coin_can_draw + coins[2]
            coin_bonus = coin_bonus + coins[3]
        end

        totaladdcoin = totaladdcoin + addcoin
        updateTaskFromDb(task)
    else
        retobj.spcode = PDEFINE_ERRCODE.ERROR.QUEST_NOT_DONE
        return resp(retobj)
    end

    if coin > 0 then table.insert(retobj.rewards, {type=PDEFINE.PROP_ID.COIN, count=coin}) end
    if coin_can_draw > 0 then table.insert(retobj.rewards, {type=PDEFINE.PROP_ID.COIN_CAN_DRAW, count=coin_can_draw}) end
    if coin_bonus > 0 then table.insert(retobj.rewards, {type=PDEFINE.PROP_ID.COIN_BONUS, count=coin_bonus}) end

    handle.moduleCall("player","syncLobbyInfo", UID)

    local playerData = handle.dcCall("user_dc", "get", uid)
    sysmarquee.onTaskBonus(playerData.playername, totaladdcoin)

    return resp(retobj)
end

return cmd