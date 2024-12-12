local cjson   = require "cjson"
local skynet = require "skynet"
local cluster = require "cluster"
local queue = require "skynet.queue"
cjson.encode_sparse_array(true)
cjson.encode_empty_table_as_object(false)

local cs = queue()
local sysmsg = {}

local handle
local UID

function sysmsg.bind(agent_handle)
	handle = agent_handle
end

function sysmsg.initUid(uid)
    UID = uid
end

function sysmsg.init(uid)
    UID = uid
end

-- 给个人发送最新的系统消息
function sysmsg.addNewMsg(uid)
	local sysMsgID = handle.dcCall("user_dc", "getvalue", uid, "sysMsgID") or 0
    local sql = string.format("select * from d_sys_msg where id > %d", sysMsgID)
    local rs = skynet.call(".mysqlpool", "lua", "execute", sql)
    if #rs > 0 then
		local sendtime = os.time()
        for _, row in pairs(rs) do
            local mailid = genMsgId()
            local message = {
                msgid = mailid,
                uid = uid,
                title = row.title,
                msg  = row.msg,
                stype = row.stype or PDEFINE.MAIL_TYPE.SYSTEM,
                attach = row.attach,
                create_time = sendtime,
                received = 0,
                hasread = 0,
                title_al = row.title_al,
                msg_al = row.msg_al,
            }
            handle.dcCall("sysusermsg_dc","add", message)
            if sysMsgID < row.id then
                sysMsgID = row.id
            end
        end
        handle.dcCall("user_dc", "setvalue", uid, "sysMsgID", sysMsgID)
    end
end

--删除多余邮件
local function deleteMuchMsg(uid)
	local mail_list = handle.dcCall("sysusermsg_dc","get_list", uid, "uid", uid, true)
	local datalist = {}
	for _, mail in pairs(mail_list) do
		table.insert(datalist, mail)
        if mail.hasread == 0 then
            handle.dcCall("sysusermsg_dc","setvalue", UID, mail.msgid, 'hasread', 1) --获取列表 就标识为已读
        end
	end
	table.sort(datalist,function(a,b) return a.create_time<b.create_time end )
	return datalist
end

--!读取系统消息
function sysmsg.getList(msg)
    local recvobj   = cjson.decode(msg)
	local uid       = math.floor(recvobj.uid)
	local ret_mail_list = {}
	local datalist = deleteMuchMsg(uid)
    -- LOG_DEBUG("sysmsg.getList datalist:", datalist)
	local tmp_list = table.copy(datalist)
	if not table.empty(tmp_list) then
        local isEnglish = handle.isEnglish()
		for _, row in pairs(tmp_list) do
            row.type = row.stype
            row.id = row.msgid
            row.msgid = nil
			row.uid = nil
            row.stype = nil

            if not isEnglish then
                row.title = row.title_al
                row.msg = row.msg_al
                row.title_al = nil
                row.msg_al = nil
            end

			table.insert(ret_mail_list, row)
		end
	end
    
	local retobj = { c = math.floor(recvobj.c), code = PDEFINE.RET.SUCCESS, msglist = ret_mail_list}
    handle.moduleCall('player', 'syncLobbyInfo', uid)
	return PDEFINE.RET.SUCCESS, cjson.encode(retobj)
end

--! 删除单条系统消息
function sysmsg.del(msg)
    local recvobj   = cjson.decode(msg)
    local msgId    = math.floor(recvobj.id or 0)
    if msgId > 0 then
        local data = {
            uid = UID,
            msgid = msgId
            }
        handle.dcCall("sysusermsg_dc","delete", data)
    end
    local retobj = { c = math.floor(recvobj.c), code = PDEFINE.RET.SUCCESS, id = msgId}
    return PDEFINE.RET.SUCCESS, cjson.encode(retobj)
end

--! 清空系统消息
function sysmsg.clear()
    local datalist = handle.dcCall("sysusermsg_dc","get_list", UID, "uid", UID, true)
    for _, row in pairs(datalist) do
        local data = {
            uid = UID,
            msgid = row.msgid
            }
        handle.dcCall("sysusermsg_dc","delete", data)
    end

    return PDEFINE.RET.SUCCESS
end

return sysmsg