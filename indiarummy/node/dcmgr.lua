local user_dc = require "user_dc" --玩家相关的dc列表
local user_data_dc = require "user_data_dc"
local mail_dc = require "mail_dc"
local quest_dc = require "quest_dc"
-- local sysusermsg_dc = require "sysusermsg_dc"
-- local pass_dc = require "pass_dc"
-- local bank_dc = require "bank_dc"
local userdc_list = {
    user_dc,
    user_data_dc,
    mail_dc,
    quest_dc,
    -- sysusermsg_dc,
    -- pass_dc,
    -- bank_dc,
}

local dcmgr = {}
dcmgr.user_dc      = user_dc
dcmgr.user_data_dc = user_data_dc
dcmgr.mail_dc      = mail_dc
-- dcmgr.stamp_dc     = stamp_dc
dcmgr.quest_dc     = quest_dc
-- dcmgr.sysusermsg_dc = sysusermsg_dc
-- dcmgr.pass_dc      = pass_dc
-- dcmgr.bank_dc      = bank_dc

function dcmgr.start()
    for _, dc in pairs(userdc_list) do
        dc.init(uid)
    end
end

function dcmgr.load(uid)
    for _, dc in pairs(userdc_list) do
        dc.load(uid)
    end
end

function dcmgr.unload(uid)
    for _, dc in pairs(userdc_list) do
        dc.unload(uid)
    end
end

return dcmgr
