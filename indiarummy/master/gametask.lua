local skynet = require "skynet"
require "skynet.manager"
local cluster = require "cluster"
local snax = require "snax"

local obj = {}
local CMD = {}

local round_list = {}
local winMaxCoin = {0,0,0}

function obj.getRound(round_list, roundid)
    for _, round in pairs(round_list) do
        if round.roundid == roundid then
            return round, winMaxCoin
        end
    end
    return nil, winMaxCoin
end

function obj.getRoundTask(round_list, roundid, taskid)
    local round = obj.getRound(round_list, roundid)
    if round and round.tasks and #round.tasks > 0 then
        for _, task in pairs(round.tasks) do
            if task.taskid == taskid then
                return task
            end
        end
    end
    return nil
end

-------- 开始加载数据 --------
function obj.loadConfig()
    local temp_round_list = {}
    local sql = string.format("select * from s_game_task order by roundid asc, taskid asc")
    local rs = skynet.call(".mysqlpool", "lua", "execute", sql)
    if #rs > 0 then
        local round = nil
        for _, row in pairs(rs) do
            if not round or round.roundid ~= row.roundid then
                round = {roundid=row.roundid, tasks={}}
                table.insert(temp_round_list, round)
            end
            row.details = {}
            table.insert(round.tasks, row)
            if row.rewardnum > winMaxCoin[row.roundid] then
                winMaxCoin[row.roundid] = row.rewardnum
            end
        end
    end

    sql = string.format("select * from s_game_task_detail order by roundid asc, taskid asc, detailid asc")
    rs = skynet.call(".mysqlpool", "lua", "execute", sql)
    if #rs > 0 then
        local task = nil
        for _, row in pairs(rs) do
            if not task or task.roundid ~= row.roundid or task.taskid ~= row.taskid then
                task = obj.getRoundTask(temp_round_list, row.roundid, row.taskid)
            end
            if task then
                table.insert(task.details, row)
            end
        end
    end
    LOG_DEBUG("game task round_list", temp_round_list)
    round_list = temp_round_list
end

function CMD.getNextRound(roundid)
    for _, round in pairs(round_list) do
        if round and round.tasks and #round.tasks > 0 and round.roundid >= roundid then
            return round
        end
    end
end

function CMD.getRound(roundid)
    return obj.getRound(round_list, roundid)
end

function CMD.getNextRoundTask(roundid, taskid)
    for _, round in pairs(round_list) do
        if round and round.tasks and #round.tasks > 0 and round.roundid >= roundid then
            for _, task in pairs(round.tasks) do
                if round.roundid > roundid or task.taskid > taskid then
                    return task
                end
            end
        end
    end
end

function CMD.getRoundTask(roundid, taskid)
    return obj.getRoundTask(round_list, roundid, taskid)
end

-- bonus页显示 winupto
function CMD.getMaxWinCoin()
    return winMaxCoin
end

function CMD.getAll()
    -- if table.empty(round_list) then
    --     loadConfig()
    -- end
    return round_list
end

function CMD.reload()
    obj.loadConfig()
    return PDEFINE.RET.SUCCESS
end

function CMD.start()
    obj.loadConfig()
    return PDEFINE.RET.SUCCESS
end

skynet.start(function()
    skynet.dispatch("lua", function(session, address, cmd, ...)
        local f = CMD[cmd]
        if not f then
            LOG_ERROR("invalid cmd: ", cmd)
            return
        end
        skynet.retpack(f(...))
    end)
    -- obj.loadConfig()
    skynet.register(".gametask")
end)
