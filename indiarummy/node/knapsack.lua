--[[
    背包
    只展示商城购买项配置表内的售卖项物品，其他物品不在商城展示
    商城物品购买完成后，物品下方打√表示购买完成，玩家无需再次购买
    其他物品展示在背包里
]]
local cjson   = require "cjson"
local skynet = require "skynet"
local cluster = require "cluster"
cjson.encode_sparse_array(true)
cjson.encode_empty_table_as_object(false)
local cmd = {}
local handle
local UID = 0
local VIP_SKIN_LIST = {}

function cmd.bind(agent_handle)
	handle = agent_handle
end

function cmd.initUid(uid)
    UID = uid
end

function cmd.init(uid)
    UID = uid
end

local function resp(retobj)
    return PDEFINE.RET.SUCCESS, cjson.encode(retobj)
end

local function loadFreeSkins()
    local datalist = {}
    for skintype, row in pairs(PDEFINE.SKIN.DEFAULT) do
        table.insert(datalist, row)
    end
    return datalist
end

local function loadAllSendList()
    local data = {}
    -- for _, taskList in pairs(PDEFINE.SKIN.UPGRADE) do --升级
    --     local tmp = {}
    --     for _, row in pairs(taskList) do
    --         table.insert(tmp, row)
    --     end
    --     table.sort(tmp, function(a, b) --保持顺序
    --         if a.lv < b.lv then
    --             return true
    --         end
    --         return false
    --     end)
    --     for _, row in pairs(tmp) do
    --         table.insert(data, row)
    --     end
    -- end
    -- for _, row in pairs(PDEFINE.SKIN.NEWBIE) do --新手任务
    --     table.insert(data, row)
    -- end
    -- for skintype, taskList in pairs(PDEFINE.SKIN.RANKDIAMOND) do
    --     if skintype == 'TOP1' or skintype=='TOP2' or skintype=='TOP3' then
    --         for _, row in pairs(taskList) do
    --             table.insert(data, row)
    --         end
    --     else
    --         table.insert(data, taskList)
    --     end
    -- end
    -- for skintype, taskList in pairs(PDEFINE.SKIN.LEAGUE) do
    --     if skintype == 'TOP1' or skintype=='TOP2' or skintype=='TOP3' then
    --         for _, row in pairs(taskList) do
    --             table.insert(data, row)
    --         end
    --     else
    --         table.insert(data, taskList)
    --     end
    -- end
    -- for skintype, row in pairs(PDEFINE.SKIN.FBSHARE) do --fb 分享
    --     table.insert(data, row)
    -- end
    for skintype, taskList in pairs(PDEFINE.SKIN.VIP) do --vip
        local tmp = {}
        for vipid, row in pairs(taskList) do
            if skintype == 'AVATAR' or skintype =='CHAT' then
                table.insert(tmp, row)
            end
        end
        table.sort(tmp, function(a, b) --保持vip头像框的顺序
            if a.lv < b.lv then
                return true
            end
            return false
        end)
        for _, row in pairs(tmp) do
            table.insert(data, row)
        end
    end
    -- for skintype, row in pairs(PDEFINE.SKIN.SIGN) do --签到
    --     table.insert(data, row)
    -- end
    -- for skintype, row in pairs(PDEFINE.SKIN.TASK_GROUTH) do --成长任务
    --     table.insert(data, row)
    -- end
    -- for skintype, row in pairs(PDEFINE.SKIN.INVITE) do --邀请好友
        -- table.insert(data, row)
    -- end
    return data
end

-- 加载ivp皮肤道具
local function loadVipSkin()
    local tmp_list = {}
    for skintype, taskList in pairs(PDEFINE.SKIN.VIP) do --vip
        for _, row in pairs(taskList) do
            if skintype ~= 'CHARM' then
                table.insert(tmp_list, row.img)
            end
        end
    end
    VIP_SKIN_LIST = tmp_list
end

-- 是否是vip道具
local function isVipSkin(img)
    if table.empty(VIP_SKIN_LIST) then
        loadVipSkin()
    end
    if table.contain(VIP_SKIN_LIST, img) then
        return true
    end
    return false
end

local VIP_UP_CFG --vip升级配置(用户消耗钻石，vip升级)
local function get_level_by_exp(exp, endtime)
    if VIP_UP_CFG == nil then
        local ok, res = pcall(cluster.call, "master", ".configmgr", "getVipUpCfg")
        if ok then
            VIP_UP_CFG = res
        end
    end
    if exp <= 0 then
        return 0 --基础
    end
    local target = -1
    for i=#VIP_UP_CFG, 1, -1 do
        if exp >= VIP_UP_CFG[i].diamond then
            target = i
            break
        end
    end
    return target
end

--! 获取背包里物品列表
function cmd.getList(msg)
    local recvobj   = cjson.decode(msg)
    local curPage   = math.floor(recvobj.page or 1)
    local uid     = math.floor(recvobj.uid)
    local stypeStr   = recvobj.type or "" --列表
    local agentLanguage = recvobj.language or 1 -- 1:阿拉伯 2:英文
    local ok, datalist  = pcall(cluster.call, "master", ".configmgr", 'getSkinList')

    local userInfo = handle.moduleCall("player", "getPlayerInfo", uid)
    local notVIP = true
    if userInfo.svip > 0 then
        notVIP = false
    end
    local ok, hadSkins = pcall(jsondecode, userInfo.skinlist) -- 1:头像框，2:聊天边框, 3:牌桌背景, 4:扑克牌背景 5:牌花 6:表情包 7:聊天文字颜色
    if not ok then
        hadSkins = {}
    end
    local hadSkinImgs = {} --已经获得的
    local hadAdded = {} --已添加的
    local language = handle.getNowLanguage()
    if tonumber(language) ~= tonumber(agentLanguage) then
        handle.changeLanguage(agentLanguage)
    end
    local isEnglish = handle.isEnglish()
    local UNIT_STRING = '$'
    local platform = handle.getPlatForm()
    local itemlist = {}
    for _, catdatalist in pairs(hadSkins) do
        if type(catdatalist) =="table" and #catdatalist > 0 then
            for _, img in pairs(catdatalist) do
                table.insert(hadSkinImgs, img)
            end
        end
    end
    --挑选出商城已有的
    for _, row in pairs(datalist) do
        row.have = 0
        if nil ~= hadSkins[row.category] and type(hadSkins[row.category])=="table" and (table.contain(hadSkins[row.category], row.id) or table.contain(hadSkins[row.category], row.img)) then
            row.have = 1
        end
        if row.have == 1 then
            table.insert(hadSkinImgs, row.img) --已有的皮肤列表
        end
    end

    --挑选出默认道具
    local freeList = loadFreeSkins()
    for _, row in pairs(freeList) do
        if row.category ~= 7 then --没有字体了
            table.insert(hadSkinImgs, row.img)
        end
    end
    --挑选出已经赠送的
    local cacheKey = PDEFINE.REDISKEY.TASK.SKIN_SEND .. uid --签到赠送的道具加入到已有列表中
    local sendSkinList = do_redis({"get", cacheKey})
    if nil ~= sendSkinList and "" ~= sendSkinList then
        local sendList = cjson.decode(sendSkinList)
        local now = os.time()
        for i=#sendList, 1, -1 do
            local item = sendList[i]
            if item.endtime <= now then
                table.remove(sendList, i)
            else
                table.insert(hadSkinImgs, item.img)
            end
        end
    end

    --挑选vip奖励的
    local cacheKey = PDEFINE.REDISKEY.OTHER.viprewards .. uid --签到赠送的道具加入到已有列表中
    local sendSkinList = do_redis({"get", cacheKey})
    if nil ~= sendSkinList and "" ~= sendSkinList then
        local sendList = cjson.decode(sendSkinList)
        for i=#sendList, 1, -1 do
            local item = sendList[i]
            table.insert(hadSkinImgs, item.img)
        end
    end

    -- 开始组织显示的数据, 1、免费道具
    local freeList = loadFreeSkins()
    for _, row in pairs(freeList) do
        if row.category ~= 7 then --没有字体了
            if itemlist['data'.. row.category] == nil then
                itemlist['data'.. row.category] = {}
            end
            local _item = table.copy(row)
            _item.have = 1
            _item.free = 1
            _item.vip = 0
            _item.content = row.title_al
            if isEnglish then
                _item.content = row.title_en
            end
            
            _item.title_al = nil
            _item.title_en = nil
            table.insert(hadAdded, _item.img)
            table.insert(itemlist['data'.. row.category], _item)
        end
    end

    --开始组织显示的数据, 2、商城
    for _, row in pairs(datalist) do
        if itemlist['data'.. row.category] == nil then
            itemlist['data'.. row.category] = {}
        end

        row.vip = 0
        row.have = 0
        row.free = 0
        if nil ~= hadSkins[row.category] and type(hadSkins[row.category])=="table" and (table.contain(hadSkins[row.category], row.id) or table.contain(hadSkins[row.category], row.img)) then
            row.have = 1
        end
        if row.amount and row.amount > 0 then
            row.unit = UNIT_STRING
            row.questid = row.questid or 5
        else
            row.unit= "COIN" --单位钻石
            -- row.productid = handle.moduleCall('pay', 'getProductId', row, platform)
            row.productid = ''
        end
        if row.subcat == 5 then
            if row.stype == 2 then
                if row.category == 1 then --临时用，把vip的调整位置4
                    row.subcat = 4
                end
                if row.category == 6 then --国王表情包(财富榜榜首)
                    if isKing(uid) then
                        row.have = 1
                        row.free = 1
                    end
                elseif row.category == 7 then
                    row.free = 0
                else
                    if userInfo.svip == 1 then
                        row.have = 1 --骑士会员
                        row.free = 1
                    end
                end
            elseif row.stype == 3 then
                if userInfo.svip == 2 then
                    row.have = 1 --爵士会员
                    row.free = 1
                end
                if row.category == 1 then
                    row.subcat = 4 --临时用，把vip的调整位置4
                end
            end
        end

        if row.category == 9 then
            local content = string.split(row.content, '|')
            if #content >= 2 then
                row.hours = math.floor(content[1])
                row.buffer = math.floor(content[2])
            end
            -- for i=#hadCharmList, 1, -1 do
            --     if hadCharmList[i].img == row.img then
            --         row.times = hadCharmList[i].times
            --         row.have = 1
            --         break
            --     end
            -- end
        end
        -- row.title = nil
        row.productid_gp = nil
        row.productid_gp2 = nil
        row.productid_huawei = nil
        row.productid_ios2 = nil
        if row.have == 0 then
            if table.contain(hadSkinImgs, row.img) then --已有
                row.have = 1
            end
        end

        if row.category == PDEFINE.SKINKIND.EXPCAT then
            row.have = 1
        end
        if isVipSkin(row.img) and notVIP then
            row.have = 0
        end
        
        if row.coin > 0 and row.have == 0 then
            row.title_en = row.title_en .. ' - '.. row.days .. ' days'
            -- if row.days == 3 then
            --     row.title_al = ' اليوم - ' .. row.title_al
            -- elseif row.days == 7 then
            --     row.title_al = ' يوميات - ' .. row.title_al
            -- else
            --     row.title_al =  row.days ..' days - ' .. row.title_al
            -- end
        end
        -- row.content = row.title_al
        -- if isEnglish then
            row.content = row.title_en
        -- end

        table.insert(hadAdded, row.img)
        if row.have == 1 then
            table.insert(itemlist['data'.. row.category], 1, row)
        else
            table.insert(itemlist['data'.. row.category], row)
        end
    end

    -- 组织显示的数据, 3、所有能获取到的
    local sendDictList = loadAllSendList()
    for i=1, #sendDictList do  --所有都要加上
        local item = sendDictList[i]
        if not table.contain(hadAdded, item.img) then
            if itemlist['data'..item.category] == nil then
                itemlist['data'..item.category] = {}
            end
            local _item = {
                -- ['id'] = item.id,
                ['img'] = item.img,
                -- ['stype'] = skin.stype,
                ['category'] = item.category,
                -- ['subcat'] = skin.subcat,
                ['id'] = 10,
                ['stype'] = 0,
                ['subcat'] = 0,
                ['have'] = 0,
                ['content'] = item.title_en,
                ['free'] = 0,
                ['time'] = 0,
                ['questid'] = item.questid or 0--是否要跳转任务
            }
            -- if isEnglish then
            --     _item.content = item.title_en
            -- end
            if table.contain(hadSkinImgs, item.img) then
                _item.have = 1
            end
            if isVipSkin(item.img) and notVIP then
                _item.have = 0
            end
            if _item.have == 1 then
                table.insert(itemlist['data'..item.category], 1, _item)
            else
                table.insert(itemlist['data'..item.category], _item)
            end
        else
            for i=#itemlist['data'..item.category], 1, -1 do
                local hasItem = itemlist['data'..item.category][i]
                if hasItem.img == item.img then
                    hasItem.questid = item.questid or 0
                end
            end
        end
    end

    --赠送的，把标识打上去
    if nil ~= sendSkinList and "" ~= sendSkinList then
        local sendList = cjson.decode(sendSkinList)
        local now = os.time()
        for i=#sendList, 1, -1 do
            local item = sendList[i]
            if nil~=item.endtime and item.endtime <= now then
                table.remove(sendList, i)
            else
                local skin = getItemFromList(sendDictList, item.img)
                if skin == nil then
                    skin =  getItemFromList(datalist, item.img)
                end
                if skin then
                    local leftdays =0
                    if nil~=item.endtime and item.endtime > now then
                        leftdays = math.floor((item.endtime - now)/86400)
                        if leftdays < 1 then
                            leftdays = 1
                        end
                    end
                    local _item = {
                        -- ['id'] = item.id,
                        ['img'] = item.img,
                        -- ['stype'] = skin.stype,
                        ['category'] = skin.category,
                        -- ['subcat'] = skin.subcat,
                        ['id'] = 10,
                        ['stype'] = 0,
                        ['subcat'] = 0,
                        ['have'] = 1,
                        ['content'] = skin.content or skin.title_al,
                        ['free'] = 0,
                        ['title'] = skin.title_al,
                        ['time'] = leftdays,
                        ['vip'] = 0, --vip专属才有vip=1
                    }
                    
                    if isVipSkin(item.img) and notVIP then
                        _item.have = 0
                    end
                    for j=#itemlist['data'..skin.category], 1, -1 do  
                        local row = itemlist['data'..skin.category][j]
                        if row.img == skin.img then
                            skin.title_al = row.title_al
                            skin.title_en = row.title_en
                            if row.content then
                                skin.content = row.content
                            end
                            table.remove(itemlist['data'..skin.category], j)
                            break
                        end
                    end
                    _item.content = skin.title_al
                    if isEnglish then
                        _item.content = skin.title_en
                    end
                    table.insert(itemlist['data'..skin.category], 1, _item)
                end
            end
        end
    end

    --魅力值道具列表
    local CAREGORY_CHARM = 8
    if itemlist['data' .. CAREGORY_CHARM] == nil then
        itemlist['data'.. CAREGORY_CHARM] = {}
    end
    local user_vip = tonumber(userInfo.svip or 0)
    -- LOG_DEBUG("user_vip uid:", userInfo.uid, ' vip:', user_vip)
    local ok, charmlist = pcall(cluster.call, "master", ".configmgr", "getCharmPropList")
    if ok then
        for idx, row in pairs(charmlist) do
            local _item = {
                ['img'] = row.img,
                ['category'] = CAREGORY_CHARM,
                ['id'] = 10,
                ['stype'] = 0,
                ['coin'] = row.count,
                ['subcat'] = 0,
                ['have'] = 0,
                ['content'] = '',
                ['free'] = 0,
                ['times'] = 0, --免费使用次数
                ['questid'] = row.questid or 0,
                ['vip'] = 0, --vip专属才有vip=1
                ['charm'] = row.charm or 0, --魅力值
            }
            if row.isvip and row.isvip > 0 then
                _item['vip'] = 1
            end
            if row.count > 0 then
                _item['have'] = 1 --可以买的都标记为1
            end
            if row.cat == 2 then
                _item['diamond'] = nil
                _item['coin'] = row.count
                if user_vip >= row.level then
                    _item['have'] = 1
                end
            end
            _item.content = row.title
            if isVipSkin(row.img) and notVIP then
                _item.have = 0
            end
            table.insert(itemlist['data'..CAREGORY_CHARM], _item)
        end
    end

    local hasNextPage = false
    local retobj = {c = math.floor(recvobj.c), code = PDEFINE.RET.SUCCESS, curPage = curPage, hasNextPage = hasNextPage, shoplist=itemlist, spcode=0}
	return PDEFINE.RET.SUCCESS, cjson.encode(retobj)
end

function cmd.findExpressItem(img, hadSendList)
    if #hadSendList > 0 then
        for i=#hadSendList, 1, -1 do
            if hadSendList[i].img == img then
                return hadSendList[i].times
            end
        end
    end
end

--! 互动表情已有次数
function cmd.exprestimes(msg)
    local recvobj = cjson.decode(msg)
    local uid     = math.floor(recvobj.uid)

    local retobj  = {c=math.floor(recvobj.c), code=PDEFINE.RET.SUCCESS, spcode=0, data={}}
    local hadSendList = get_send_charm_list(uid)
    local ok, charmCfg = pcall(cluster.call, "master", ".configmgr", "getCharmPropList")
    if ok then
        for idx, row in pairs(charmCfg) do
            local times = cmd.findExpressItem(row.img, hadSendList)
            if times ~= nil then
                table.insert(retobj.data, {id=idx, times=times})
            end
        end
    end
    return resp(retobj)
end

--! 使用经验值道具
function cmd.useSkinExp(msg)
    local recvobj = cjson.decode(msg)
    local uid     = math.floor(recvobj.uid)
    local img     = recvobj.img or ""
    local retobj  = {c=math.floor(recvobj.c), code=PDEFINE.RET.SUCCESS, spcode=0, data={}}
    if img == "" then
        retobj.spcode = PDEFINE_ERRCODE.ERROR.SKIN_NOT_FOUND
        LOG_DEBUG("道具名称错误 uid:", uid)
        return resp(retobj)
    end

    local findIt = 0
    local hadSendList = get_send_charm_list(uid)
    for i=#hadSendList, 1, -1 do
        if hadSendList[i].img == img then
            findIt = i
            break
        end
    end
    if findIt == 0 then
        retobj.spcode = PDEFINE_ERRCODE.ERROR.SKIN_NOT_FOUND
        LOG_DEBUG("没有该道具 uid:", uid, ' img:', img)
        return resp(retobj)
    end

    minus_send_charm_time(uid, img)
    local nowtime = os.time()
    local _, shopSkinList  = pcall(cluster.call, "master", ".configmgr", 'getSkinList')
    local shopItem
    for _, item in pairs(shopSkinList) do
        if item.img == img then
            shopItem = item
            break
        end
    end
    retobj.img = img
    retobj.category = shopItem.category
    local hours, buffer = 0, 0
    local content = string.split(shopItem.content, '|')
    if #content >= 2 then
        hours = math.floor(content[1])
        buffer = math.floor(content[2])
    end

    local cacheKey = PDEFINE_REDISKEY.OTHER.booster .. uid

    local timeout = do_redis({"hget", cacheKey, buffer})
    if nil == timeout or 0 == tonumber(timeout) then
        local dataset = {
            [buffer] = nowtime + (hours * 3600)
        }
        do_redis({"hmset", cacheKey, dataset})
    else
        do_redis({"hset", cacheKey, buffer, (tonumber(timeout) + (hours * 3600))})
    end

    local charm_list = get_send_charm_list(uid)
    handle.syncUserInfo({uid=uid, charmlist = charm_list})
    return resp(retobj)
end

return cmd