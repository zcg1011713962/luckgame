local skynet = require "skynet"
local cluster = require "cluster"
local cjson   = require "cjson"
local player_tool = require "base.player_tool"
-- local reddot = require "reddot"
cjson.encode_sparse_array(true)
cjson.encode_empty_table_as_object(false)
local mailbox = {}
local handle
local APP = tonumber(skynet.getenv("app")) or 1
function mailbox.bind(agent_handle)
	handle = agent_handle
end

function mailbox.init(uid)
	handle.dcCall("user_data_dc","set_common_value", uid, PDEFINE.USERDATA.COMMON.HAS_NEW_MAIL, 0)
	handle.dcCall("user_data_dc","set_common_value", uid, PDEFINE.USERDATA.COMMON.HAS_UNREAD_MAIL, 0)
end

-- 邮箱状态获取
function mailbox.getFlagInfo(uid)
	local ret = {}
	ret.hasnewmail = handle.dcCall("user_data_dc","get_common_value", uid, PDEFINE.USERDATA.COMMON.HAS_NEW_MAIL)
	ret.hasunreadmail = handle.dcCall("user_data_dc","get_common_value", uid, PDEFINE.USERDATA.COMMON.HAS_UNREAD_MAIL)
	return ret
end

--删除邮件
function mailbox.removeMail(msg)
	local recvobj = cjson.decode(msg)
	local uid     = math.floor(recvobj.uid)
	local mailid  = assert(recvobj.mailid)
	local data = {
		uid = uid,
		mailid = mailid
	}
	local hasread = handle.dcCall("mail_dc","getvalue", uid, mailid,"hasread")
	local ret     = handle.dcCall("mail_dc","delete", data)
	if ret then
		if math.floor(hasread) == 0 then
			-- 删除未读邮件可能需要修改总标记
			local mailList = handle.dcCall("mail_dc","get", uid)
			for _,mailinfo in pairs(mailList) do
				if mailinfo.hasread == 0 then
					-- 还有未读的直接返回不修改未读总标记
					return PDEFINE.RET.SUCCESS
				end
			end
			handle.dcCall("user_data_dc","set_common_value", uid, PDEFINE.USERDATA.COMMON.HAS_UNREAD_MAIL, 0)
			return PDEFINE.RET.SUCCESS
		end
		return PDEFINE.RET.SUCCESS
	end
	return PDEFINE.RET.ERROR.MAIL_NOT_FOUND
end

--删除多余邮件
local function deleteMuchMail(uid)
	local mail_list = handle.dcCall("mail_dc", "get_list_by_uid", uid)
	local ret_mail_list = {}
	if mail_list then
		for _, mail in pairs(mail_list) do
			table.insert(ret_mail_list, mail)
		end
	end
	table.sort(ret_mail_list,function(a,b) return a.sendtime<b.sendtime end )
	return ret_mail_list
end

-- 添加系统邮件
function mailbox.addSystemMail(uid)
	if not uid then return end
	local sysMailID = handle.dcCall("user_dc", "getvalue", uid, "sysMailID")
	sysMailID = tonumber(sysMailID or 0)
    local sql = string.format("select * from d_sys_mail where id > %d", sysMailID)
    local rs = skynet.call(".mysqlpool", "lua", "execute", sql)
    if #rs > 0 then
		local sendtime = os.time()
		local svip = handle.dcCall("user_dc", "getvalue", uid, "svip")
        for _, row in pairs(rs) do
			local add = false
			if row.svip == nil or row.svip == "" then
				add = true			
			else
				local svipArr = string.split(row.svip, ',')
				if table.size(svipArr) > 0 then
					for _, tvip in pairs(svipArr) do
						if tonumber(tvip) == svip then
							add = true
							break
						end
					end
				end
			end
			if add then
				local mailid = genMailId()
				local mail_message = {
					mailid = mailid,
					uid = uid,
					fromuid = 0,
					msg  = row.msg,
					type = row.stype or PDEFINE.MAIL_TYPE.SYSTEM,
					title = row.title,
					attach = row.attach,
					sendtime = sendtime,
					received = 0,
					hasread = 0,
					sysMailID=row.id,
					title_al = row.title_al,
					msg_al = row.msg_al,
					rate = row.rate,
					remark = row.remark or "",
					creator = row.creator or ""
				}
				mailbox.addMail(uid, mail_message, true)
				-- local field = 'mail_notify'
				-- if row.stype == PDEFINE.MAIL_TYPE.MAINTAIN then
				-- 	field = 'mail_gift'
				-- elseif row.stype == PDEFINE.MAIL_TYPE.RACE or row.stype == PDEFINE.MAIL_TYPE.TOURNAMENT_REFUND or row.stype == PDEFINE.MAIL_TYPE.TOURNAMENT_SETTLE then
				-- 	field = 'mail_activity'
				-- end
				-- reddot.incr(uid, field, 1)
			end
			if sysMailID < row.id then
				sysMailID = row.id
			end
        end
        handle.dcCall("user_dc", "setvalue", uid, "sysMailID", sysMailID)
    end
end

-- 202协议，获取用户邮件列表
function mailbox.getMailList(msg)
	local recvobj   = cjson.decode(msg)
	local uid       = math.floor(recvobj.uid)
	local iscache = recvobj.cache --是否缓存请求
	local ret_mail_list = {}
	local has_new = handle.dcCall("user_data_dc","get_common_value", uid, PDEFINE.USERDATA.COMMON.HAS_NEW_MAIL)
	if has_new == 1 then
		-- 设置新邮件总状态
		handle.dcCall("user_data_dc","set_common_value", uid, PDEFINE.USERDATA.COMMON.HAS_NEW_MAIL, 0)
	end
	local mailList = deleteMuchMail(uid)
	local tmp_mail_list = table.copy(mailList)
	local attachList = 0
	local isEnglish = handle.isEnglish()
	if not table.empty(tmp_mail_list) then
		for k, mail_info in pairs(tmp_mail_list) do
			mail_info.status = 1
			mail_info.rewards = {}
			if nil~= mail_info.received and mail_info.received == 1 then
				do_redis({"hset", "showmail:uid:"..uid, "mailid:"..mail_info.mailid, 1}, uid)
				mail_info.status = 0
			end
			local ok, attach = pcall(jsondecode, mail_info.attach)
			if ok and nil ~=attach and not table.empty(attach) then
				if mail_info.status == 1 then --status=1 标识客户端可以领取
					attachList = attachList + 1
				end
				mail_info.rewards = attach
				mail_info.attach = nil
			end
			mail_info.uid = nil
			mail_info.sysMailID = nil
			mail_info.fromuid = nil
			mail_info.sender = 'Yono Games'
			if APP == PDEFINE.APPID.RUMMYVIP then
				mail_info.sender = PDEFINE.APPS.URLS[APP].mailsender
			end
			if not isEnglish then
				mail_info.title = mail_info.title_al
				mail_info.msg = mail_info.msg_al
				mail_info.sender = 'نظام'
			end
			mail_info.title_al = nil
			mail_info.msg_al = nil
			mail_info.type = math.floor(mail_info.type)
			table.insert(ret_mail_list, mail_info)
		end
	end
	local allCollection = 3
	if attachList > 0 then
		allCollection = 2
	end
	if not iscache then
		handle.addStatistics(uid,'pop_mail_open', '')
	end
	local retobj = { c = math.floor(recvobj.c), code = PDEFINE.RET.SUCCESS, mails = ret_mail_list, allCollection = allCollection}
	return PDEFINE.RET.SUCCESS, cjson.encode(retobj)
end

-- 重置邮件
function mailbox.resetMail(uid, mailid)
	local myself = handle.getUid()
	mailid = tonumber(mailid)
	if tonumber(uid) == tonumber(myself) then
		handle.dcCall("mail_dc","setvalue", uid, mailid, "sendtime", os.time())
		handle.dcCall("mail_dc","setvalue", uid, mailid, "received", 0)
		handle.dcCall("mail_dc","setvalue", uid, mailid, "hasread", 0)
		local retobj = {c =  PDEFINE.NOTIFY.MAIL_STATUS, code = PDEFINE.RET.SUCCESS, uid=uid}
		handle.sendToClient(cjson.encode(retobj))
	else
		
		local ok = pcall(cluster.call, "master", ".userCenter", "resetUserMail", uid, mailid, true)
	end
end

-- 添加新的邮件
function mailbox.addMail(uid, data, init)
	if init == nil then
		init = false
	end
	if data.mailid == nil then
		local mailid = do_redis({ "incr", "d_mail:mailid"})
		data.mailid = mailid
	end
	if data.received == nil then
		data.received = 0
	end
	if data.hasread == nil then
		data.hasread = 0
	end
	if data.sysMailID == nil then
		data.sysMailID = 0
	end
	local myself = handle.getUid()
	LOG_DEBUG("myself:", myself, ' uid:', uid)
	if tonumber(uid) == tonumber(myself) then
		handle.dcCall("mail_dc","add", data)
		local retobj = {c =  PDEFINE.NOTIFY.MAIL_STATUS, code = PDEFINE.RET.SUCCESS, uid=uid}
		handle.sendToClient(cjson.encode(retobj))

		if not init then
			handle.moduleCall("player","syncLobbyInfo", uid) --在线的用户同步一下红点状态；被好友赠送了，接发邮件也会走到这里通知
		end
	else
		local ok = pcall(cluster.call, "master", ".userCenter", "addUsersMail", uid, data, true)
	end
end

-- 203协议 邮件读取
function mailbox.readMail(msg)
	local recvobj = cjson.decode(msg)
	local uid     = math.floor(recvobj.uid)
	local mailid  = assert(recvobj.mailid)
	mailid = math.floor(mailid)

	local hasread = handle.dcCall("mail_dc","getvalue", uid, mailid,"hasread")
	if 1 == hasread then
		--已读
		local retobj = { c = math.floor(recvobj.c), code = PDEFINE.RET.SUCCESS}
		return PDEFINE.RET.SUCCESS, cjson.encode(retobj)
	end

	-- 读取邮件 解析邮件物品
	local mail_info = handle.dcCall("mail_dc","get_info", uid, mailid)
	if not mail_info then return PDEFINE.RET.ERROR.MAIL_NOT_FOUND end
	if mail_info.type == PDEFINE.MAIL_TYPE.NEWGAMES then
		local retobj = { c = math.floor(recvobj.c), code = PDEFINE.RET.SUCCESS}
		return PDEFINE.RET.SUCCESS, cjson.encode(retobj)
	end
	handle.moduleCall("player","syncLobbyInfo", uid)
	local isAllMailRead = true
	local mailList = handle.dcCall("mail_dc","get", uid)
	for _,mailinfo in pairs(mailList) do
		if mailinfo.hasread == 0 then
			-- 还有未读的直接返回不修改未读总标记
			isAllMailRead = false
			break
		end
	end
	if isAllMailRead then
		handle.dcCall("user_data_dc","set_common_value", uid, PDEFINE.USERDATA.COMMON.HAS_UNREAD_MAIL, 0)
	end
	handle.dcCall("mail_dc","setvalue", uid, mailid, "hasread", 1)

	local retobj = { c = math.floor(recvobj.c), code = PDEFINE.RET.SUCCESS}
	return PDEFINE.RET.SUCCESS, cjson.encode(retobj)
end

--!204协议, 领取附件
function mailbox.getAttach(msg)
	local recvobj = cjson.decode(msg)
	local uid     = math.floor(recvobj.uid)
	local mailid  = math.floor(recvobj.mailid)
	local server = recvobj.server or 0 --是否是服务器调用
	server = tonumber(server)
	mailbox.readMail(msg) --直接领取附件
	local hasreceived = handle.dcCall("mail_dc","getvalue", uid, mailid, "received")
	if hasreceived == 1 then
		--已读
		local retobj = { c = math.floor(recvobj.c), code = PDEFINE.RET.SUCCESS}
		return PDEFINE.RET.SUCCESS, cjson.encode(retobj)
	end
	-- 读取邮件 解析邮件物品
	local mail_info = handle.dcCall("mail_dc","get_info", uid, mailid)	--系统邮件时，没有对应的

	if not mail_info then return PDEFINE.RET.ERROR.MAIL_NOT_FOUND end
	handle.dcCall("mail_dc","setvalue", uid, mailid, "received", 1)

	local totalAddCoin = 0
	local rewards = {}
	local hasCharm = false
	if type(mail_info.attach) == "string" and mail_info.type ~= PDEFINE.MAIL_TYPE.FRIENDS then
		local ok, attachInfo = pcall(jsondecode, mail_info.attach)
		if ok and attachInfo ~= nil then
			if type(attachInfo) == "table" and not table.empty(attachInfo) then
				local addcoin = 0
				for _, row in pairs(attachInfo) do
					-- id 使用 PDEFINE.PROP_ID
					-- num 对应 数量
					-- 防止有些骚操作的邮件
					if row.count then
						local reward = {type=row.type, count=row.count, img=row.img}
						if row.type == PDEFINE.PROP_ID.COIN then
							if nil ~= mail_info.rate and mail_info.rate ~= "" then
								addcoin = addcoin + row.count
							else
								local remark = mail_info.remark or '' --防止老邮件值为nil
								local act ='mail'
								if mail_info.type == PDEFINE.MAIL_TYPE.RANKING then
									act = 'leaderboard'
								elseif mail_info.type == PDEFINE.MAIL_TYPE.TOURNAMENT_SETTLE then
									act = 'tn_reward'
								end
								handle.addProp(row.type, row.count, act, '', remark)
								table.insert(rewards, reward)
							end
							totalAddCoin = totalAddCoin + row.count
						else
							if row.type == PDEFINE.PROP_ID.SKIN_CHARM then -- 直接给
								for i=1, row.count do
									add_send_charm_times(uid, row.img)
									hasCharm = true
								end
							elseif row.type == PDEFINE.PROP_ID.SKIN_EXP then
								add_send_charm_times(uid, row.img, true, row.count)
								hasCharm = true
							elseif row.type == PDEFINE.PROP_ID.SKIN_CHAT or row.type == PDEFINE.PROP_ID.SKIN_FACE 
							or row.type == PDEFINE.PROP_ID.SKIN_FRAME or row.type == PDEFINE.PROP_ID.SKIN_POKER or row.type == PDEFINE.PROP_ID.SKIN_TABLE then
								handle.moduleCall("upgrade","sendSkins", row.img, row.days*86400)
							else
								handle.addProp(row.type, row.count, 'mail')
							end

							table.insert(rewards, reward)
						end
					end
				end
				--分流得金币
				if addcoin > 0 then
					if isempty(mail_info.creator) then
						mail_info.creator = 'System'
					end
					mail_info.remark = mail_info.remark or '' --防止老邮件值为nil
					local remark = '操作人:'.. mail_info.creator .. ',备注:'.. mail_info.remark
					local bonusRemark = remark
					local coins = handle.moduleCall("player","addCoinByRate", uid, addcoin, mail_info.rate, PDEFINE.TYPE.SOURCE.Mail, 0, nil, nil, remark, bonusRemark)
					if coins[1] > 0 then table.insert(rewards, {type=PDEFINE.PROP_ID.COIN, count=coins[1]}) end
					if coins[2] > 0 then table.insert(rewards, {type=PDEFINE.PROP_ID.COIN_CAN_DRAW, count=coins[2]}) end
					if coins[3] > 0 then table.insert(rewards, {type=PDEFINE.PROP_ID.COIN_BONUS, count=coins[3]}) end
				end
			end
		end
	end
	local aftercoin = handle.moduleCall("player","getPlayerCoin", uid)
	if totalAddCoin > 0 then
		local notifyobj = {}
		notifyobj.c = PDEFINE.NOTIFY.coin
		notifyobj.code = PDEFINE.RET.SUCCESS
		notifyobj.uid = uid
		notifyobj.deskid = 0
		notifyobj.count = totalAddCoin
		notifyobj.coin = aftercoin
		notifyobj.type = 1
		notifyobj.rewards = {}
		handle.sendToClient(cjson.encode(notifyobj))
	end
	local retobj = { 
		c = math.floor(recvobj.c), 
		code = PDEFINE.RET.SUCCESS,
		user = {uid = uid, coin = aftercoin}, 
		mailid= mailid, 
		addCoin=totalAddCoin, 
		rewards=rewards
	}
	local isOk, rs = mailbox.getMailList(msg)
	local ret = cjson.decode(rs)
	retobj.allCollection = ret.allCollection
	if server == 0 then
		handle.moduleCall("player","syncLobbyInfo", uid)
	end
	if hasCharm then
		local charmlist = get_send_charm_list(uid)
    	handle.syncUserInfo({uid=uid, charmlist=charmlist})
	end
	return PDEFINE.RET.SUCCESS, cjson.encode(retobj), rewards
end


--! 一键领取
function mailbox.getAllAttach(msg)
	local recvobj = cjson.decode(msg)
	local uid     = math.floor(recvobj.uid)
	local iscache = recvobj.cache --是否缓存请求
	local retobj  = {}
    retobj.c      = PDEFINE.NOTIFY.coin
    retobj.code   = PDEFINE.RET.SUCCESS
	retobj.uid    = uid

	-- 获取玩家所有列表
	local isOk, rs_1 = mailbox.getMailList(msg)
	local ret_1 = cjson.decode(rs_1)
	local rewards = {}
	if ret_1.allCollection == 2 then
		if not table.empty(ret_1.mails) then
			for _, row in pairs(ret_1.mails) do
				if not table.empty(row.rewards) then
					local tmp_msg = cjson.encode({c = 204, uid = uid, mailid = row.mailid, server = 1})
					-- 获取每封邮件的内容
					local ret_ok, _, _rewards = mailbox.getAttach(tmp_msg)
					if ret_ok == PDEFINE.RET.SUCCESS and _rewards then
						for _, _reward in ipairs(_rewards) do
							local hasMerge = false
							for _, reward in ipairs(rewards) do
								if reward.type == _reward.type then
									hasMerge = true
									reward.count = reward.count + _reward.count
								end
							end
							if not hasMerge then
								table.insert(rewards, _reward)
							end
						end
					end
				end
			end
		end
	end

	local isOk_2, rs_2 = mailbox.getMailList(msg)
	local ret_2 = cjson.decode(rs_2)
	retobj.mails = ret_2.mails
	retobj.allCollection = ret_2.allCollection
	retobj.rewards = rewards
	handle.moduleCall("player","syncLobbyInfo", uid)
	if not iscache then
		handle.addStatistics(uid, 'pop_mail_getall', '')
	end
	return PDEFINE.RET.SUCCESS, cjson.encode(retobj)
end

--! 一键删除
function mailbox.deleteAll(msg)
	local recvobj = cjson.decode(msg)
	local uid     = math.floor(recvobj.uid)
	local iscache = recvobj.cache --是否缓存请求
	local retobj  = {}
    retobj.c      = PDEFINE.NOTIFY.coin
    retobj.code   = PDEFINE.RET.SUCCESS
	retobj.uid    = uid
	retobj.rewards = {}

	local isOk, rs_1 = mailbox.getMailList(msg)
	local ret_1 = cjson.decode(rs_1)
	local rewards = {}
	if not table.empty(ret_1.mails) then
		for _, row in pairs(ret_1.mails) do
			if not table.empty(row.rewards) then
				local tmp_msg = cjson.encode({c = 204, uid = uid, mailid = row.mailid, server = 1})
				-- 获取每封邮件的内容
				local ret_ok, _, _rewards = mailbox.getAttach(tmp_msg)
				if ret_ok == PDEFINE.RET.SUCCESS and _rewards then
					for _, _reward in ipairs(_rewards) do
						local hasMerge = false
						for _, reward in ipairs(rewards) do
							if reward.type == _reward.type then
								hasMerge = true
								reward.count = reward.count + _reward.count
							end
						end
						if not hasMerge then
							table.insert(rewards, _reward)
						end
					end
				end
			end

			local data = {
				uid = uid,
				mailid = row.mailid
			}
			handle.dcCall("mail_dc","delete", data)
		end
	end
	retobj.rewards = rewards
	handle.moduleCall("player","syncLobbyInfo", uid)
	if not iscache then
		handle.addStatistics(uid, 'pop_mail_delall', '')
	end
	return PDEFINE.RET.SUCCESS, cjson.encode(retobj)
end

-- 获取未被领取完的邮件数
function mailbox.getUnRecieved(uid)
	--local rs = handle.dcCall("mail_dc", "get_list", uid, "recieved", 0, true)
	local rs = handle.dcCall("mail_dc", "get_list_by_uid", uid)
	-- LOG_DEBUG(" getUnRecieved rs:", rs)
	-- local count = 0
	local ret = {
		['notify'] = 0,
		['gift'] = 0,
		['activity'] = 0,
	}
	if nil~=rs and not table.empty(rs) then
		for _, v in pairs(rs) do
			if not v.received or v.received ==0 then
				local mailtype = tonumber(v.type)
				-- count = count + 1
				if mailtype == 13 then
					ret['gift'] = ret['gift'] + 1
				-- elseif v.type == PDEFINE.MAIL_TYPE.SYSTEM or v.type == PDEFINE.MAIL_TYPE.VIP or v.type == PDEFINE.MAIL_TYPE.SHOP or v.type == PDEFINE.MAIL_TYPE.RANKING or v.type == PDEFINE.MAIL_TYPE.INVITE then
					-- ret['notify'] = ret['notify'] + 1
				elseif mailtype == PDEFINE.MAIL_TYPE.RACE or v.type == PDEFINE.MAIL_TYPE.TOURNAMENT_REFUND or v.type == PDEFINE.MAIL_TYPE.TOURNAMENT_SETTLE then
					ret['activity'] = ret['activity'] + 1
				else
					ret['notify'] = ret['notify'] + 1
				end
			end
		end
	end
	return ret
end

return mailbox