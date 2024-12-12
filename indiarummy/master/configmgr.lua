local skynet = require "skynet"
require "skynet.manager"
local cluster = require "cluster"
local snax = require "snax"
local cjson = require "cjson"
-- s_config表配置表管理

local CMD = {}
local config_list = {} --存储配置
local new_sign_list = {} --签到配置 新的， daily bonus
local vipsign_list = {} --vip每周登录奖励列表
local skin_list = {}
local vipup_list = {} --vip升级配置
local charmprop_list = {} --魅力值道具列表(字典)
local invite_domain_list = {} --邀请分享域名列表
local maintask_list = {} --每日任务列表
local leader_board_rewards = {}  -- 排行榜奖励
local mailtpl_list = {} --站内信模板
local CFG_REBATE = {} --代理返利配置
local notice_list = {} --活动公告
local total_sign_bonus_coin = 0 --签到总奖励
local drawlimit_list = {} --提现限制列表
local label_list = {} --标签列表

-- 站内信模板列表
local function loadMailTPL()
    local tmp = {}
    local sql = "select * from d_mail_tpl where status=1"
    local rs = skynet.call(".mysqlpool", "lua", "execute", sql)
    if #rs > 0 then
        for _, row in pairs(rs) do
            tmp[row['type']] = row
        end
    end
    mailtpl_list = tmp
end

--加载每日任务优惠列表
local function loadMainTask()
    local tmp = {}
    local sql = "select * from s_config_maintask order by ord asc"
    local rs = skynet.call(".mysqlpool", "lua", "execute", sql)
    if #rs > 0 then
        for _, row in pairs(rs) do
            if nil == tmp[row['type']] then
                tmp[row['type']] = {}
            end
            row['rewards'] = decodePrize(row['rewards'])
            local gameids = {}
            if nil ~= row['gameids'] then
                local gameidArr = string.split(row['gameids'], ',')
                for _, gid in pairs(gameidArr) do
                    table.insert(gameids, tonumber(gid))
                end
            end
            row['gameids'] = gameids
            tmp[row['type']][row['id']] = row
        end
    end
    maintask_list = tmp
end

-- 加载域名分享列表
local function loadDomainList()
    local tmp = {}
    local sql = "select * from s_invite_domain where status=1"
    local rs = skynet.call(".mysqlpool", "lua", "execute", sql)
    if #rs > 0 then
        for _, row in pairs(rs) do
            table.insert(tmp, row['domain'])
        end
    end
    invite_domain_list = tmp
end

local function loadCharmProp()
    local tmp = {}
    local sql = "select * from s_send_charm where level is not null order by isvip asc, cat asc,`count` asc, `level` asc"
    local rs = skynet.call(".mysqlpool", "lua", "execute", sql)
    if #rs > 0 then
        for _, row in pairs(rs) do
            tmp[row.id] = row
            row.type = 1
        end
    end
    charmprop_list = tmp
end

-- 广播修改了开启排行榜的游戏id列表
local function broadcastLBGameids(newGameidstr)
    if not table.empty(config_list) then
        local oldstr = CMD.getVal(PDEFINE_REDISKEY.LEADERBOARD.GAMEIDS)
        if oldstr ~= newGameidstr then
            pcall(cluster.send, "game", ".dsmgr", "setGameIDs", newGameidstr)
        end
    end
end

local function loadConfigList()
    local temp_config_list = {}
    local sql = "select * from s_config"
    local rs = skynet.call(".mysqlpool", "lua", "execute", sql)
    if #rs > 0 then
        for _, row in pairs(rs) do
            temp_config_list[row.id] = row
            if row.k == PDEFINE_REDISKEY.LEADERBOARD.GAMEIDS then
                broadcastLBGameids(row.v)
            end
        end
    end
    config_list = temp_config_list
end

-- 加载无优惠标签列表
local function loadDiscountLabelList()
    local temp_list = {}
    local sql = "select * from d_discount_label where status=1"
    local rs = skynet.call(".mysqlpool", "lua", "execute", sql)
    if #rs > 0 then
        for _, row in pairs(rs) do
            temp_list[row.id] = string.split(row['discount'], ',')
        end
    end
    label_list = temp_list
end

-- 加载皮肤商城商品
local function loadSkinCfgList()
    local temp_config_list = {}
    local sql = "select * from s_shop_skin"
    local rs = skynet.call(".mysqlpool", "lua", "execute", sql)
    if #rs > 0 then
        for _, row in pairs(rs) do
            row.coin = row.diamond
            row.diamond = nil
            temp_config_list[row.id] = row
        end
    end
    skin_list = temp_config_list

end

-- 新的签到数据配置
local function loadNewSignInfo()
    local temp_list = {
        ['pack'] = {},
        ['data'] = {},
        ['cardlist'] = {}
    }
    local sql = "select * from s_sign_new"
    local rs = skynet.call(".mysqlpool", "lua", "execute", sql)
    if #rs > 0 then
        for _, row in pairs(rs) do
            local title, title_al
            local ok, prize = pcall(jsondecode, row.prize)
            if not ok then
                prize = {}
            end
            title_al = row.title_al or ""
            title = row.title or ""
            if row.coin and row.coin > 0 then
                local tmp = {
                    ["s"] = 1,
                    ["n"] = row.coin,
                }
                table.insert(prize, tmp) --将金币数据配置进去
            else
                local day = 0
                for k, v in pairs(prize) do
                    if v.s == PDEFINE.PROP_ID.VIP_DAY or v.s == PDEFINE.PROP_ID.SKIN_TABLE or v.s == PDEFINE.PROP_ID.SKIN_POKER then
                        day = v.day
                        break
                    end                   
                end
                if day > 0 then
                    title = day ..''.. title
                    if row.id ~= 20 and row.id ~= 10 then
                        title_al = day .. ' ' .. title_al
                    end
                end
            end
            temp_list['data'][row.id] = {
                title = title,
                title_al = title_al,
                prize = prize -- 1-28天的签到奖励
            }
        end
    end

    temp_list['cardlist'] = {}

    new_sign_list = temp_list
end

local function loadVipSignInfo()
    local tmpList = {}
    local tmpcoin = 0
    local sql = "select * from s_sign_vip"
    local rs = skynet.call(".mysqlpool", "lua", "execute", sql)
    if #rs > 0 then
        for _, row in pairs(rs) do
            local prize = decodePrize(row.prize)
            if row.coin and row.coin > 0 then
                local tmp = {
                    ["type"] = 1,
                    ["count"] = row.coin
                }
                table.insert(prize, tmp) --将金币数据配置进去
                tmpcoin = tmpcoin + row.coin
            end

            tmpList[row.id] = {
                ['prize'] = prize,
                ['svip']  = row.svip, --需要的vip等级
            }
        end
    end
    vipsign_list = tmpList
    total_sign_bonus_coin = tmpcoin
end

-- 可用兑换码加入redis中
local function loadExchangeCode2Cache()
    local sql = "select * from d_exchange_code where state=1"
    local rs = skynet.call(".mysqlpool", "lua", "execute", sql)
    if #rs > 0 then
        for _, row in pairs(rs) do
            do_redis({"sadd", PDEFINE.REDISKEY.LOBBY.exchange, row['code']})
        end
    end
end

-- 加载排名对应奖励
local function loadLeaderBoardRewards()
    local sql = "select * from d_lb_reward_config"
    local rs = skynet.call(".mysqlpool", "lua", "execute", sql)
    if #rs > 0 then
        local tmp = {}
        for _, row in pairs(rs) do
            table.insert(tmp, row)
        end
        leader_board_rewards = tmp
    end
end

--加载活动公告
local function loadNotice()
    local temp_notice_list = {}
    local sql = "select * from s_notice where status = 1 order by ord"
    local rs = skynet.call(".mysqlpool", "lua", "execute", sql)
    if #rs > 0 then
        for _, row in pairs(rs) do
            table.insert(temp_notice_list, {
                svips = string.split_to_number(row.svip, ','),
                data = {
                    id = row.id,
                    title = row.title,
                    content = row.content,
                    img = row.img,
                    btntxt = row.btntxt,
                    jumpto = row.jumpto,
                }
            })
        end
    end
    notice_list = temp_notice_list
end

-- 提现限制
local function loadDrawLimitList() 
    local tmp_list = {}
    local sql = "select * from s_pay_cfg_drawlimit"
    local rs = skynet.call(".mysqlpool", "lua", "execute", sql)
    if #rs > 0 then
        for _, row in pairs(rs) do
            table.insert(tmp_list, {
                userid = row.useruid or 0,
                svips = string.split_to_number(row.svip, ','),
                limit = {
                    daytimes = row.times, --每日次数限制
                    daycoin = row.daycoin, --每日提现金币限制
                    totaltimes = row.totaltimes, --总提现次数限制
                    totalcoin = row.totalcoin, --总提现金额
                    -- interval = row.interval, --提现间隔
                }
            })
        end
    end
    drawlimit_list = tmp_list
end

-- 根据uid和svip获取提现限制
function CMD.getDrawLimit(svip, uid)
    if table.empty(drawlimit_list) then
        loadDrawLimitList()
    end
    local limit = {
        daytimes = -1, --每日次数限制
        daycoin = -1, --每日提现金币限制
        totaltimes = -1, --总提现次数限制
        totalcoin = -1, --总提现金额
        -- interval = -1, 
    }
    for _ , row in pairs(drawlimit_list) do
        if row.userid == 0 then 
            if table.contain(row.svips, svip) then
                if row.limit.daytimes > limit.daytimes then
                    limit.daytimes = row.limit.daytimes
                end
                if row.limit.daycoin > limit.daycoin then
                    limit.daycoin = row.limit.daycoin
                end
                if row.limit.totaltimes > limit.totaltimes then
                    limit.totaltimes = row.limit.totaltimes
                end
                if row.limit.totalcoin > limit.totalcoin then
                    limit.totalcoin = row.limit.totalcoin
                end
                -- if row.limit.interval > limit.interval then
                --     limit.interval = row.limit.interval
                -- end
            end
        elseif row.userid == uid then
                limit.daytimes = row.limit.daytimes
                limit.daycoin = row.limit.daycoin
                limit.totaltimes = row.limit.totaltimes
                limit.totalcoin = row.limit.totalcoin
            -- if row.limit.interval > limit.interval then
            --     limit.interval = row.limit.interval
            -- end
            break
        end
    end

    return limit
end

-- 获取提现限制相关
function CMD.getDrawLimitInfo(svip, uid)
    local limit = CMD.getDrawLimit(svip, uid)
    limit['maxcoin'] = 0
    local row = CMD.get('newuser_no_pay_drawlimit')
    limit['maxcoin'] = tonumber(row.v)
    return limit
end

-- 获取站内信模板内容
function CMD.getMailTPLList()
    if table.empty(mailtpl_list) then
        loadMailTPL()
    end
    return mailtpl_list
end

function CMD.getMailTPL(cat)
    if cat == nil then return nil end
    if table.empty(mailtpl_list) then
        loadMailTPL()
    end
    return mailtpl_list[cat]
end

function CMD.getVipSignInfo()
    if table.empty(vipsign_list) then
        loadVipSignInfo()
    end
    return vipsign_list
end

function CMD.getSkinList(catetory)
    if table.empty(skin_list) then
        loadSkinCfgList()
    end
    local list = {}
    if catetory then
        catetory = tonumber(catetory)
        for id, item in pairs(skin_list) do
            if tonumber(item.category) == catetory then
                table.insert(list, item)
            end
        end
    else
        list = table.copy(skin_list)
    end
    return list
end

function CMD.getNotice(svip)
    for _, notice in ipairs(notice_list) do
        if table.contain(notice.svips, svip) then
            return notice.data
        end
    end
end

function CMD.getLoginCfgData(svip)
    local ret = {}
    ret['notice'] = {}
    --公告
    for _, notice in ipairs(notice_list) do
        if table.contain(notice.svips, svip) then
            table.insert(ret.notice, notice.data)
            -- ret.notice = notice.data
            -- break
        end
    end
    --注册金币
    local charmpack = CMD.get("charmpack")
    ret.reg_bonus_coin = charmpack.v or 0
    --签到金币
    ret.sign_bonus_coin = total_sign_bonus_coin
    return ret
end

local function loadVIPUpgradeCfg()
    local tp_list = {}
    local sql = "select * from s_config_vip_upgrade order by id asc"
    local rs = skynet.call(".mysqlpool", "lua", "execute", sql)
    if #rs > 0 then
        for _, row in pairs(rs) do
            local ok benefit = pcall(jsondecode, row.benefit)
            if not ok  or type(benefit) ~= 'table'  then
                benefit = {}
            end
            benefit['id']           = row.id
            benefit["level"]        = row.level --vip级别
            benefit["diamond"]      = row.diamond --达到vip级别需要消耗的钻石
            benefit["rewards"]      = decodePrize(row.rewards) --每天领取的金币数和钻石数
            benefit['rewards_rate'] = row.rewards_rate
            benefit['weeklybonus']  = decodePrize(row.weeklybonus) --周奖励
            benefit['weeklyrate']  = row.weeklyrate
            benefit['monthlybonus'] = decodePrize(row.monthlybonus) --月奖励
            benefit['monthlyrate']  = row.monthlyrate
            benefit['tranrate']     = tonumber(row.tranrate)
            benefit['trantimes']     = tonumber(row.trantimes)
            benefit['salonrooms']     = tonumber(row.salonrooms)
            benefit['slotmaxbet']     = tonumber(row.slotmaxbet)
            tp_list[row.level] = benefit
        end
    end
    vipup_list = tp_list
end


--! 获取分享域名列表
function CMD.getDomainList()
    if table.empty(invite_domain_list) then
        loadDomainList()
    end
    return invite_domain_list
end

--! 获取魅力值道具列表
function CMD.getCharmPropList()
    if table.empty(charmprop_list) then
        loadCharmProp()
    end
    return charmprop_list
end

-- 获取vip升级配置
function CMD.getVipUpCfg()
    if table.empty(vipup_list) then
        loadVIPUpgradeCfg()
    end
    return vipup_list
end

--获取slots最大下注
function CMD.getSlotsMaxBet(svip)
    if vipup_list[svip] then
        return vipup_list[svip].slotmaxbet
    end
end

--重新从库里加载配置到游戏
function CMD.reload()
    loadConfigList()
    loadNewSignInfo()
    loadVipSignInfo()
    loadSkinCfgList()
    loadVIPUpgradeCfg()
    loadCharmProp()
    loadExchangeCode2Cache()
    loadDomainList()
    loadMainTask()
    loadMailTPL()
    loadNotice()
    loadDrawLimitList()
    loadDiscountLabelList()
    CFG_REBATE = {}

    skynet.send(".userCenter", "lua", "clearRebateGameids")
end

function CMD.getMainTasks()
    if table.empty(maintask_list) then 
        loadMainTask()
    end
    return maintask_list
end

-- 批量获取排行榜图片
function CMD.getLeaderBoardData()
    if table.empty(config_list) then 
        loadConfigList()
    end
    local pics = {
        ['leaderpic1'] = '', --日榜
        ['leaderpic2'] = '', --周榜
        ['leaderpic3'] = '', --月榜
        ['leaderpic4'] = '', --人数榜
    }
    
    local cfg = {} --配置数据
    local keys = table.indices(pics)
    for _, row in pairs(config_list) do
        if table.contain(keys, row.k) and row.v ~= '' then
            pics[row.k] = GetAPPUrl('upload')..'/'.. row.v
        end
        if row.k == 'leaderboard' then
            cfg = row
        end
    end
    local data = {
        ['pics'] = pics,
        ['cfg'] = {}
    }
    if not table.empty(cfg) then
        local ok , item = pcall(jsondecode, cfg.v)
        if ok then
            data.cfg = item
        end
    end
    return data
end

function CMD.get(key)
    local res = {}
    if table.empty(config_list) then 
        loadConfigList()
    end
    for _, row in pairs(config_list) do
        if row.k == key then
            res = row
            break
        end
    end
    return res
end

function CMD.getVal(key)
    if table.empty(config_list) then 
        loadConfigList()
    end
    for _, row in pairs(config_list) do
        if row.k == key then
            return row.v
        end
    end
end

-- 批量获取key
function CMD.getBatchItems(keyDict)
    local result = {}
    for _, key in pairs(keyDict) do
        local item = CMD.getVal(key)
        if nil ~= item then
            result[key] = item            
        end
    end
    return result
end

-- 获取无优惠标签配置项
function CMD.getDiscountLabel(id)
    if table.empty(label_list) then
        loadDiscountLabelList()
    end
    return label_list[id]
end

--获取代理返利配置
function CMD.getRebateCfg()
    if table.empty(CFG_REBATE) then
        local key = 'invite'
        local row = CMD.get(key)
        LOG_DEBUG('getRebateCfg row:', row)
        if not table.empty(row) then
            local ok, data = pcall(jsondecode, row.v)
            LOG_DEBUG('getRebateCfg ok', ok, ' data:', data)
            if ok then
                CFG_REBATE = data
            end
        end
    end
    return CFG_REBATE --代理返佣配置
end

--根据key 批量获取
function CMD.batchGet(keys)
    local res = {}
    if table.empty(config_list) then 
        loadConfigList()
    end
    for _, row in pairs(config_list) do
        for _, key in pairs(keys) do
            if row.k == key then
                res[key] = row
            end
        end
    end
    return res
end

-- 获取掉落卡包配置
function CMD.getCardList()
    if table.empty(new_sign_list) then
        loadNewSignInfo()
    end
    return new_sign_list['cardlist']
end

-- 获取新的签到数据
function CMD.getNewSignList()
    if table.empty(new_sign_list) then
        loadNewSignInfo()
    end
    local tmpData = table.copy(new_sign_list)
    local data ={['signData']={}, ['pack'] = {}, ['cardlist']= tmpData['cardlist']}
    for i=1, 30 do
        local index = i
        local prize = tmpData['data'][index]['prize']
        for _, row in pairs(prize) do
            row['type'] = row['s']
            row['count']= row['n']
            row['s'] = nil
            row['n'] = nil
        end
        table.sort(prize, sortByPropType)

        table.insert(data['signData'], {
            ['day'] = i,
            ['prize'] = prize,
            ['title'] = tmpData['data'][index].title,
            ['title_al'] = tmpData['data'][index].title_al,
        }) -- 只找出显示的签到数据
    end
    return data
end

-- 获取榜单奖励数据
function CMD.getLeaderBoardRewards(rtype)
    if table.empty(leader_board_rewards) then
        loadLeaderBoardRewards()
    end
    local tmp = {}
    for _, row in pairs(leader_board_rewards) do
        if row.rtype == rtype then
            table.insert(tmp, row)
        end
    end
    return tmp
end

--获取进游戏的绑定手机和kyc的配置
function CMD.getPlayBindConfig()
    local phone = CMD.getVal("play_bind_phone")
    local kyc = CMD.getVal("play_bind_kyc")
    return {
        bind_phone = tonumber(phone),
        bind_kyc = tonumber(kyc),
    }
end

function CMD.start()
    CMD.reload()
end

skynet.start(function()
    skynet.dispatch("lua", function(session, address, cmd, ...)
        local f = CMD[cmd]
        skynet.retpack(f(...))
    end)
    skynet.register(".configmgr")
end)
