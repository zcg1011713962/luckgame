local entity = require "Entity"

local quest_dc = {}
local EntQuest

--- @class QuestConfig
local QuestConfig = {
    id = nil,  -- 任务id
    parm1 = nil,  -- 参数1, 用于判断任务所需数量
    parm2 = nil,  -- 参数2
    parmCnt = nil,  -- 任务数量
    descr = nil,  -- 描述
    count = nil,  -- 金币奖励
    icon = nil,  -- 图标
    gameid = nil,  -- 对应游戏id
    type = nil,  -- 类型
    status = nil,  -- 状态
    create_time = nil,  -- 创建时间
    cuid = nil,  -- 
    update_time = nil, --
    uuid = nil,  --
    parm1coin = nil,  --
    parm2coin = nil,  --
    missionstar = nil,  --
    jumpTo = nil,  -- 跳转字符串，透传客户端
    rewards = nil,  -- 奖励字段，type:count|type:count
}

function quest_dc.init()
    EntQuest = entity.Get("d_quest")
    EntQuest:Init()
end

function quest_dc.load(uid)
    if not uid then return end
    EntQuest:Load(uid)
end

function quest_dc.unload(uid)
    if not uid then return end
    EntQuest:UnLoad(uid)
end

function quest_dc.getvalue(uid, id, key)
    return EntQuest:GetValue(uid, id, key)
end

function quest_dc.setvalue(uid, id, key, value)
    return EntQuest:SetValue(uid, id, key, value)
end

function quest_dc.add(row)
    return EntQuest:Add(row)
end

function quest_dc.delete(row)
    return EntQuest:Delete(row)
end

function quest_dc.get_list(uid)
    return EntQuest:Get(uid)
end

function quest_dc.get_info(uid, questid)
    return EntQuest:Get(uid, questid)
end


return quest_dc