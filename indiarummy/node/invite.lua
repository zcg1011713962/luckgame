-- 邀请好友注册,绑定邀请码
local cjson   = require "cjson"
local skynet = require "skynet"
local cluster = require "cluster"
local player_tool = require "base.player_tool"
local queue = require "skynet.queue"
cjson.encode_sparse_array(true)
cjson.encode_empty_table_as_object(false)

local CMD = {}
local handle
local UID

local cachePrefix = PDEFINE_REDISKEY.LOBBY.INVITE_USER

function CMD.bind(agent_handle)
	handle = agent_handle
end

function CMD.initUid(uid)
    UID = uid
end

function CMD.init(uid)
    UID = uid
end

local function getInviteCnt(uid, nocache)
    local key = 'total_refers:'.. uid
    local ordernumCache = do_redis({"get", key})
    if ordernumCache == nil or nocache then
        local sql = string.format("select max(ord) as cnt from d_user_invite where invit_uid = %d", uid)
        local res = skynet.call(".mysqlpool", "lua", "execute", sql)
        ordernumCache = tonumber(res[1].cnt or 0)
        do_redis({"setex", key,  ordernumCache, 180})
    end 
    ordernumCache = tonumber(ordernumCache or 0)
    return ordernumCache
end

local function getTodayInviteCnt(uid)
    local key = 'today_refers:'.. uid
    local cachecnt = do_redis({"get", key})
    if   cachecnt    == nil then
        local temp_date = os.date("*t", os.time())
        local beginTime = os.time({year=temp_date.year, month=temp_date.month, day=temp_date.day, hour=0})
        local sql = string.format("select max(ord) as cnt from d_user_invite where invit_uid = %d and create_time>%d", uid, beginTime)
        local res = skynet.call(".mysqlpool", "lua", "execute", sql)
        cachecnt = tonumber(res[1].cnt or 0)
        do_redis({"setex", key,  cachecnt, 180})
    end 
    cachecnt = tonumber(cachecnt or 0)
    return cachecnt
end

local function getInviteConf()
    local ok, cfg = pcall(cluster.call, "master", ".configmgr", "get",'invite')
    local inviteCfg = {}
    if ok then
        ok , inviteCfg = pcall(jsondecode, cfg.v)
    end
    return inviteCfg
end

local function getInviteRewardsCoin(uid)
    local bonus = do_redis({"hget", cachePrefix .. uid, 'bonus_1'})
    if bonus == nil then
        local sql = string.format("select sum(coin1) as t from d_commission where parentid=%d and type=1", uid)
        local res = skynet.call(".mysqlpool", "lua", "execute", sql)
        bonus  = tonumber(res[1].t or 0)
        do_redis({"hset", cachePrefix .. uid, 'bonus_1', bonus})
    end
    bonus = tonumber(bonus or 0)
    return bonus
end

local function getTotalBonus(uid)
    local info = do_redis({ "hgetall", cachePrefix .. uid})
    info = make_pairs_table_int(info)
    local totalbonus = info.totalbonus or 0 --总
    local reg = info.bonus_1 or 0 --下级注册
    local recharge = info.bonus_2 or 0 --下级充值
    local bet = info.bonus_3 or 0 --下级下注
    if totalbonus == 0 then
        local sql = string.format("select sum(coin1) as t, type from d_commission where parentid=%d group by type", uid)
        local res = skynet.call(".mysqlpool", "lua", "execute", sql)
        for _, row in pairs(res) do
            totalbonus = totalbonus + tonumber(row['t'] or 0)
            if row.type == PDEFINE.TYPE.SOURCE.REG then
                reg = reg + row['t']
            elseif row.type == PDEFINE.TYPE.SOURCE.BUY then
                recharge = recharge + row['t']
            elseif row.type == PDEFINE.TYPE.SOURCE.BET then
                bet = bet + row['t']
            end
        end

        local data = {}
        data.totalbonus = totalbonus
        data.bonus_1 = reg
        data.bonus_2 = recharge
        data.bonus_3 = bet
        do_redis({ "hmset",cachePrefix .. uid, data})
    end
    return totalbonus, reg, recharge, bet
end

-- 获取今日得到的bonus
local function getTodayTotalBonus(uid)
    local key = 'today_bonus:' .. uid
    local cachestr = do_redis({ "get", key})
    local today_total, reg, buy, bet = 0, 0, 0, 0
    if cachestr then
        local ok , cache = pcall(jsondecode, cachestr)
        if ok and cache then
            today_total = cache.today_total
            reg = cache.reg or 0
            buy = cache.buy or 0
            bet = cache.bet or 0
        end
    else
        local temp_date = os.date("*t", os.time())
        local beginTime = os.time({year=temp_date.year, month=temp_date.month, day=temp_date.day, hour=0})
        local sql = string.format("select sum(coin1) as t, type from d_commission where parentid=%d and `datetime`>=%d group by type", uid, beginTime)
        local res = skynet.call(".mysqlpool", "lua", "execute", sql)
        for _, row in pairs(res) do
            today_total = today_total + tonumber(row['t'] or 0)
            if row.type == PDEFINE.TYPE.SOURCE.REG then
                reg = reg + row['t']
            elseif row.type == PDEFINE.TYPE.SOURCE.BUY then
                buy = buy + row['t']
            elseif row.type == PDEFINE.TYPE.SOURCE.BET then
                bet = bet + row['t']
            end
        end
        local jsondata = {
            ['today_total'] = today_total,
            ['reg'] = reg,
            ['buy'] = buy,
            ['bet'] = bet,
        }
        do_redis({ "setex", key, cjson.encode(jsondata), 180})
    end
    return today_total, reg, buy, bet
end

--! 邀请信息
function CMD.info(msg)
    local recvobj   = cjson.decode(msg)
    local playerInfo = player_tool.getPlayerInfo(UID)
    local retobj = {['c'] = math.floor(recvobj.c), ['code']= PDEFINE.RET.SUCCESS}
    local cfg = getInviteConf()
    local totalbonus, reg, buy, bet = getTotalBonus(UID) --total earnings
    retobj.info = {
        code = playerInfo.code, --我的邀请码
        invite = {
            coin1 = cfg['invite']['coin1'],
            coin2 = cfg['invite']['coin2'],
        },
        recharge = {
            rate1 = cfg['recharge']['rrate1'],
            rate2 = cfg['recharge']['rrate2'],
        },
        bet = {
            rate1 = cfg['bet']['rrate1'],
            rate2 = cfg['bet']['rrate2'],
        },
        total_refers = getInviteCnt(playerInfo.uid), --total referrals
        reg_bonus    = getInviteRewardsCoin(UID), --邀请下级获得的奖励
        total_bonus  = totalbonus, --total earnings
        url = GetAPPUrl('fbshare') .. '?code='..UID, --分享出去的邀请链接
        cash = 0, -- cash balance
        bonus = 0, --cash bonus
        today_total_bonus = 0, --今日总bonus
        today_cash = 0, --今日获得的cash balance
        today_refers = getTodayInviteCnt(playerInfo.uid), --今日邀请注册
    }
    local rateReg = string.split(cfg['invite']['rate1'],':')
    local rateBuy = string.split(cfg['recharge']['rate1'],':')
    local rateBet = string.split(cfg['bet']['rate1'],':')

    local today_total_bonus, today_reg, today_buy, today_bet = getTodayTotalBonus(UID)
    retobj.info.today_total_bonus = today_total_bonus
    if today_total_bonus > 0 then
        local cash = today_reg * rateReg[1] + today_buy * rateBuy[1] + today_bet * rateBet[1]
        retobj.info.today_cash = cash
    end
    if retobj.info.total_bonus < 0 then
        retobj.info.total_bonus = 0
    else
        local cash = reg * rateReg[1] + buy * rateBuy[1] + bet * rateBet[1]
        retobj.info.cash = cash
        retobj.info.bonus = math.floor(totalbonus - cash)
    end
    if playerInfo.invit_uid and playerInfo.invit_uid > 0 then
        local upper = player_tool.getPlayerInfo(playerInfo.invit_uid)
        retobj.info.upper = ''
        if upper then
            retobj.info.upper = upper.code --我的上级的邀请码    
        end
    end

    local ok, domainlist = pcall(cluster.call, "master", ".configmgr", "getDomainList")
    if ok then
        local domain = domainlist[math.random(1, #domainlist)]
        local url = string.format("%s/?code=%s", domain, playerInfo.code)
        retobj.info.url = url
    end
    return PDEFINE.RET.SUCCESS, cjson.encode(retobj)
end

-- 是否可以领取奖励了(1019协议使用)
function CMD.canClaim(uid)
    local ids = {}
    -- for _, row in pairs(cfg) do
    --     table.insert(ids, row.num)
    -- end
    local claim = 0
    local sql = string.format( "select ord, status from d_user_invite where invit_uid=%d and `ord` in (%s)", uid, table.concat(ids, ","))
    local rs = skynet.call(".mysqlpool", "lua", "execute", sql)
    if #rs > 0 then
        for _, row in pairs(rs) do
            if tonumber(row.status) == 0 then
                claim = 1
                break
            end
        end
    end
    return claim
end

local function genInvitCode(uid, prefix)
    for i=1,5000 do
        local code = prefix .. randomInviteCode()
        local inPool = do_redis({"sismember", PDEFINE_REDISKEY.LOBBY.ALL_INVITE_CODES, code})
        if not inPool then
            LOG_DEBUG('genInvitCode uid:', uid, ' code2:', code)
            handle.dcCall("user_dc", "setvalue", uid, 'code', code)
            do_redis({"sadd", PDEFINE_REDISKEY.LOBBY.ALL_INVITE_CODES, code})
            break
        end
    end
end

--! 绑定邀请码(被邀请人)
function CMD.bindCode(msg)
    local recvobj = cjson.decode(msg)
    assert(recvobj.code)
    local code    = recvobj.code or ''
    local iscache = recvobj.cache --是否缓存请求
    local channelx = recvobj.cx or '' -- 渠道随机数
    if channelx == 'null' then
        channelx = ''
    end
    local uid = UID
    local retobj = {['c'] = math.floor(recvobj.c), ['code']= PDEFINE.RET.SUCCESS, spcode = 0, uid=uid}
    local invitcode = handle.dcCall("user_dc", "getvalue", uid, "invit_uid")
    if invitcode ~= 0 then
        retobj.spcode = PDEFINE.RET.ERROR.INVITE_HAD_BINDED --已经绑定过邀请码
        return PDEFINE.RET.SUCCESS, cjson.encode(retobj)
    end
    local regtime = handle.dcCall("user_dc", "getvalue", uid, "create_time")
    if os.time() > (regtime + 180) then
        --注册时间3分钟后，不允许再绑码
        return PDEFINE.RET.SUCCESS, cjson.encode(retobj)
    end

    local channelid = 0
    local sql = string.format("select uid, invit_uid,forbidcode from d_user where code = '%s'", code)
    local rst = skynet.call(".mysqlpool", "lua", "execute", sql)
    local invite_uid = nil
    if #rst == 0 then
        if string.len(code) ~= 11 then
            retobj.spcode = PDEFINE.RET.ERROR.INVITE_BIND_ERR
            return PDEFINE.RET.SUCCESS, cjson.encode(retobj)
        end

        local sql = string.format("select id from d_account_channel where code = '%s'", code)
        local rst = skynet.call(".mysqlpool", "lua", "execute", sql)
        if #rst == 0 then
            retobj.spcode = PDEFINE.RET.ERROR.INVITE_BIND_ERR
            return PDEFINE.RET.SUCCESS, cjson.encode(retobj)
        end

        channelid = rst[1].id --渠道id
        local playerInfo = player_tool.getPlayerInfo(uid)
        if playerInfo and isempty(playerInfo.cx) and not isempty(channelx) then
            handle.dcCall("user_dc", "setvalue", UID, "cx", channelx)
            
        end
        if nil == playerInfo.channelid or 0 ==playerInfo.channelid then
            handle.dcCall("user_dc", "setvalue", uid, "channelid", channelid) --把渠道码绑上
        end
        if isempty(playerInfo.code) or tonumber(playerInfo.code) == uid then
            local prefix = SubStringUTF8(code, 1, 3)
            genInvitCode(uid, prefix)
        end
        handle.addStatistics(uid, "bindcode", channelid) --打点
    else
        if rst[1].uid == uid then
            retobj.spcode = PDEFINE.RET.ERROR.INVITE_BIND_SELF   --绑定的是自己邀请码
            return PDEFINE.RET.SUCCESS, cjson.encode(retobj)
        end
        if rst[1].forbidcode == 1 then
            retobj.spcode = PDEFINE.RET.ERROR.INVITE_BIND_FORBID
            return PDEFINE.RET.SUCCESS, cjson.encode(retobj)
        end

        local sql = string.format("select * from d_user_tree where (ancestor_id=%d and descendant_id=%d) or (ancestor_id=%d and descendant_id=%d)", rst[1].uid, UID, UID, rst[1].uid)
        local rs = skynet.call(".mysqlpool", "lua", "execute", sql)
        if #rs > 0 then  --已经存在绑定关系 或 存在循环绑定关系
            retobj.spcode = PDEFINE.RET.ERROR.INVITE_BIND_IN_CIRCLE 
            return PDEFINE.RET.SUCCESS, cjson.encode(retobj)   
        end

        invite_uid = rst[1].uid
        local playerInfo = player_tool.getPlayerInfo(UID)
        if playerInfo and isempty(playerInfo.cx) and not isempty(channelx) then
            handle.dcCall("user_dc", "setvalue", UID, "cx", channelx)
            
        end
        local now = os.time()
        local ordnum = getInviteCnt(rst[1].uid, true)
        ordnum = ordnum + 1
        local cfg = getInviteConf()
        local rewards = {{type=PDEFINE.PROP_ID.COIN, count=cfg.invite.coin1}}
    
        sql = string.format( "insert into d_user_invite(uid,playername,usericon,invit_uid,create_time,ord,rewards,cx) value(%d,'%s','%s',%d,%d,%d,'%s','%s')",
        UID, playerInfo.playername, playerInfo.usericon, rst[1].uid, now, ordnum, cjson.encode(rewards), channelx) --邀请记录
        do_mysql_queue(sql)

        local ordernumCache = do_redis({"hget", cachePrefix .. rst[1].uid, 'users'})
        ordernumCache = tonumber(ordernumCache or 0)
        if ordernumCache == 0 then
            do_redis({"hset", cachePrefix .. rst[1].uid, 'users', ordnum})
        else
            do_redis({"hincrby", cachePrefix .. rst[1].uid, 'users', 1})
        end
        
        if string.len(code) == 11 then
            local prefix = SubStringUTF8(code, 1, 3)
            local sql = string.format("select id, prefix from d_account_channel where prefix = '%s'", prefix)
            local rs  = skynet.call(".mysqlpool", "lua", "execute", sql)
            if #rs == 1 then
                if nil == playerInfo.channelid or 0 ==playerInfo.channelid then
                    handle.dcCall("user_dc", "setvalue", UID, "channelid", rs[1].id) --设置渠道号
                end
                if isempty(playerInfo.code) or tonumber(playerInfo.code) == uid then
                    genInvitCode(uid, prefix)
                end
            end
        else
            if isempty(playerInfo.code) or tonumber(playerInfo.code) == uid then
                genInvitCode(uid, '')
            end
        end
        if nil == playerInfo.invit_uid or 0 ==playerInfo.invit_uid then
            handle.dcCall("user_dc", "setvalue", UID, "invit_uid", rst[1].uid) --设置绑定上下级
        end
        
        pcall(cluster.send, "master", ".userCenter", "addInviteCount", invite_uid) --邀请码的所属人的统计数更新
        --设置绑定关系列表
        local agent = 0
        sql = string.format("select * from d_user_tree where descendant_id=%d order by id desc", invite_uid)
        local ret = skynet.call(".mysqlpool", "lua", "execute", sql)
        if #ret > 0 then
            for _, item in pairs(ret) do
                local sql2 = string.format( "insert into d_user_tree(ancestor_id,descendant_id,descendant_agent,ancestor_h) value(%d, %d, %d, %d)", item['ancestor_id'], UID, agent, (item['ancestor_h'] + 1)) --邀请记录
                LOG_DEBUG(sql2)
                skynet.call(".mysqlpool", "lua", "execute", sql2)
            end
        end

        if not iscache then
            handle.addStatistics(UID, "bindcode", rst[1].uid) --打点
        end

        local ok, cfg = pcall(cluster.call, "master", ".configmgr", 'getRebateCfg')
        if cfg and cfg.invite ~= nil and cfg.invite.rtype~=nil and tonumber(cfg.invite.rtype) == 2 then --绑定的时候返注册奖励
            local regSql = string.format("select count(*) as t from d_commission where uid=%d and type=1", UID)
            local rst = skynet.call(".mysqlpool", "lua", "execute", regSql)
            if nil ~= rst and nil~=rst[1] and rst[1].t == 0 then
                LOG_DEBUG('bindcode before AddSuperiorRewards uid:', UID)
                pcall(cluster.send, "master", ".userCenter", "AddSuperiorRewards", UID, PDEFINE.TYPE.SOURCE.REG, cfg.invite.coin1, cfg.invite.rtype)
            end
        end
    end

    return PDEFINE.RET.SUCCESS, cjson.encode(retobj)
end

--! 我的下级列表
function CMD.myrefers(msg)
    local recvobj = cjson.decode(msg)
    local subuid = tonumber(recvobj.member or 0)
    local retobj = {['c'] = math.floor(recvobj.c), ['code']= PDEFINE.RET.SUCCESS, data = {}, spcode=0}
    local sql = string.format("select uid, sum(bettimes) as totaltimes, sum(betcoin) as totalbet,sum(rechargecoin) as buycoin,  sum(coin1+coin2) as totalcoin from d_commission where parentid=%d group by uid ", UID)
    if subuid > 0 then
        sql = string.format("select uid, sum(bettimes) as totaltimes, sum(betcoin) as totalbet,sum(rechargecoin) as buycoin,  sum(coin1+coin2) as totalcoin from d_commission where parentid=%d and uid=%d group by uid ", UID, subuid)
    end
    local rst = skynet.call(".mysqlpool", "lua", "execute", sql)
    if #rst == 0 then
        return PDEFINE.RET.SUCCESS, cjson.encode(retobj)
    end
    for _, row in pairs(rst) do
        local user = player_tool.getPlayerInfo(row.uid)
        local item = {
            uid = row.uid,
            playername = user.playername,
            usericon = user.usericon,
            avatarframe = user.avatarframe or PDEFINE.SKIN.DEFAULT.AVATAR.img,
            svip = user.svip,
            svipexp = user.svipexp,
            times = row.totaltimes,
            bet = row.totalbet,
            recharge = row.buycoin, --充值金额
            coin = row.totalcoin, --佣金
            login_time = user.login_time, --最后登录时间戳
        }
        table.insert(retobj.data, item)
    end
    return PDEFINE.RET.SUCCESS, cjson.encode(retobj)
end

--! 我的代理下级，新
function CMD.myagents(msg)
    local recvobj = cjson.decode(msg)
    -- local subuid = tonumber(recvobj.member or 0)
    local retobj = {['c'] = math.floor(recvobj.c), ['code']= PDEFINE.RET.SUCCESS, data = {}, spcode=0}
    local sql = string.format("select uid, sum(bettimes) as totaltimes from d_commission where parentid=%d group by uid ", UID)
    local rst = skynet.call(".mysqlpool", "lua", "execute", sql)
    if #rst == 0 then
        return PDEFINE.RET.SUCCESS, cjson.encode(retobj)
    end
    local sql = string.format("select uid,create_time from d_user_invite where invit_uid =%d", UID)
    local res =  skynet.call(".mysqlpool", "lua", "execute", sql)
    local data = {}
    for _, row in pairs(res) do
        data[row['uid']] = row['create_time']
    end
    for _, row in pairs(rst) do
        local user = player_tool.getPlayerInfo(row.uid)
        local item = {
            uid = row.uid,
            playername = user.playername,
            usericon = user.usericon,
            svip = user.svip,
            svipexp = user.svipexp,
            times = row.totaltimes, --下注次数
            create_time = user.create_time, --注册时间
            login_time = user.login_time, --最后登录时间戳
        }
        if nil ~= data[row.uid] then
            item.create_time = data[row.uid]
        end
        table.insert(retobj.data, item)
    end
    return PDEFINE.RET.SUCCESS, cjson.encode(retobj)
end

--! 我的佣金列表，佣金分开显示
function CMD.myrefersnew(msg)
    local recvobj = cjson.decode(msg)
    local uid = math.floor(recvobj.uid or 0)
    local retobj = {['c'] = math.floor(recvobj.c), ['code']= PDEFINE.RET.SUCCESS, data = {}, spcode=0}
    local sql = [[
            select uid,sum(bettimes) as totaltimes,sum(rechargecoin) as buycoin, sum(betcoin) as totalbet, sum(coin1+coin2) as totalcoin, unix_timestamp(from_unixtime(create_time,'%Y-%m-%d')) as day, type 
            from d_commission
            where parentid=
    ]]
        sql = sql .. uid
        sql = sql .. [[
            group by uid,`type`, day
            order by id  desc
            limit 100
    ]]
    local rst = skynet.call(".mysqlpool", "lua", "execute", sql)
    if #rst == 0 then
        return PDEFINE.RET.SUCCESS, cjson.encode(retobj)
    end
    LOG_DEBUG('myrefersnew rst:', rst)
    local cfg = getInviteConf()
    local rateReg = string.split(cfg['invite']['rate1'],':')
    local rateBuy = string.split(cfg['recharge']['rate1'],':')
    local rateBet = string.split(cfg['bet']['rate1'],':')
    local datalist = {}
    for _ , row in pairs(rst) do
        row.cash = 0
        row.reg = 0
        if row['type'] == PDEFINE.TYPE.SOURCE.REG then
            row.cash = math.floor(row['totalcoin'] * rateReg[1])
            row.reg = row['totalcoin']
        elseif row['type'] == PDEFINE.TYPE.SOURCE.BUY then
            row.cash = math.floor(row['totalcoin'] * rateBuy[1])
        elseif row['type'] == PDEFINE.TYPE.SOURCE.BET then
            row.cash = math.floor(row['totalcoin'] * rateBet[1])
        end
        local k = row['day'] ..''.. row['uid']
        if datalist[k] == nil then
            datalist[k] = {
                ['create_time'] = row['day'],
                ['uid'] = row['uid'],
                ['times'] = row['totaltimes'],
                ['recharge'] = row['buycoin'],
                ['bet'] = row['totalbet'],
                ['coin'] = row['totalcoin'],
                ['cash'] = row['cash'],
                ['reg']  = row['reg']
            }
        else
            local item = datalist[k]
            item['reg']      = item['reg'] + row['totalcoin']
            item['times']    = item['times'] + row['totaltimes']
            item['recharge'] = item['recharge'] + row['buycoin']
            item['bet']      = item['bet'] + row['totalbet']
            item['coin']     = item['coin'] + row['totalcoin']
            item['cash']     = item['cash'] + row['cash']
            datalist[k] = item
        end
    end
    -- LOG_DEBUG('myrefersnew datalist:', datalist)

    for _ , row in pairs(datalist) do
        local user = player_tool.getPlayerInfo(row.uid)
        row.playername = user.playername or ''
        row.usericon = user.usericon or ''
        table.insert(retobj.data, row)
    end
    return PDEFINE.RET.SUCCESS, cjson.encode(retobj)
end

--! 我的佣金列表
function CMD.comm(msg)
    local recvobj = cjson.decode(msg)
    local retobj = {['c'] = math.floor(recvobj.c), ['code']= PDEFINE.RET.SUCCESS, data = {}, spcode=0}
    local sql = string.format("select sum(betcoin) as totalbet,sum(rechargecoin) as buycoin, sum(coin1) as totalcoin, datetime from d_commission where parentid=%d group by datetime ", UID)
    LOG_DEBUG("CMD.comm sql:", sql)
    local rst = skynet.call(".mysqlpool", "lua", "execute", sql)
    if #rst == 0 then
        return PDEFINE.RET.SUCCESS, cjson.encode(retobj)
    end
    for _, row in pairs(rst) do
        local item = {
            create_time = row.datetime, --日期时间戳,需要客户端转为日期
            bet = row.totalbet, --总下注
            recharge = row.buycoin, --充值金额
            coin = row.totalcoin, --该日对应的总佣金
        }
        table.insert(retobj.data, item)
    end
    return PDEFINE.RET.SUCCESS, cjson.encode(retobj)
end

--! 我的某天的佣金明细
function CMD.commdetail(msg)
    local recvobj = cjson.decode(msg)
    local time = math.floor(recvobj.time)
    local endtime = time + 86400
    local retobj = {['c'] = math.floor(recvobj.c), ['code']= PDEFINE.RET.SUCCESS, data = {}, spcode=0}
    local sql = string.format("select uid, sum(betcoin) as totalbet,sum(rechargecoin) as buycoin, sum(coin1) as totalcoin, create_time from d_commission where (parentid=%d) and (create_time >=%d and create_time<%d) group by uid ", UID, time, endtime)
    LOG_DEBUG("CMD.commdetail sql:", sql)
    local rst = skynet.call(".mysqlpool", "lua", "execute", sql)
    if #rst == 0 then
        return PDEFINE.RET.SUCCESS, cjson.encode(retobj)
    end
    for _, row in pairs(rst) do
        local user = player_tool.getPlayerInfo(row.uid)
        local item = {
            uid = row.uid,
            playername = user.playername,
            usericon = user.usericon,
            avatarframe = user.avatarframe or PDEFINE.SKIN.DEFAULT.AVATAR.img,
            svip = user.svip,
            svipexp = user.svipexp,
            create_time = row.create_time, --日期时间戳,需要客户端转为日期
            bet = row.totalbet, --总下注
            recharge = row.buycoin, --充值金额
            coin = row.totalcoin, --该日对应的总佣金
        }
        table.insert(retobj.data, item)
    end
    return PDEFINE.RET.SUCCESS, cjson.encode(retobj)
end

--收益轮播
function CMD.commcarousel(msg)
    local recvobj = cjson.decode(msg)
    local retobj = {
        c = recvobj. c,
        cpde = PDEFINE.RET.SUCCESS,
        data = {}
    }
    local sql = "select parentid, coin1, type from d_commission where type=2 or type=3 order by create_time desc limit 5"
    local rs = skynet.call(".mysqlpool", "lua", "execute", sql)
    for _, row in ipairs(rs) do
        local playername = getUserAttrRedis(row.parentid, "playername")
        local item = {
            name = hidePlayername(playername),
            type = row.type,  --2:充值 3:下注
            coin = row.coin1,
        }
        table.insert(retobj.data, item)
    end
    return PDEFINE.RET.SUCCESS, cjson.encode(retobj)
end

return CMD