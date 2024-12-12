local skynet = require "skynet"
local random = require "random"
local cjson = require "cjson"
local is_release = skynet.getenv("isrelease")
local is_logrelease = skynet.getenv("logrelease")
local APP = tonumber(skynet.getenv("app")) or 1
local md5 = require "md5"

--local file = io.open("./proto/dtmessage.pb","rb")
--local buffer = file:read "*a"
--file:close()
--protobuf.register(buffer)

systemprint = print
systemerror = error

local dailyRate = {
    [102] = 0.1, --钻石最低档
    [103] = 0.2, 
    [104] = 0.3,
    [105] = 0.4,
    [106] = 0.5,
    [5] = 0.1, --金币
    [4] = 0.2, 
    [3]  = 0.3,
    [16] = 0.4,
    [17] = 0.5,
}

function setSendRate(uid, shopid)
    -- local first = do_redis({ "get", 'shop_buy_first:' .. uid .. ':' .. shopid})
    -- first = math.floor(first or 0)
    -- if first == 0 then
        do_redis({ "set", 'shop_buy_first:' .. uid .. ':' .. shopid, 1})
    -- end
end


function getSendRate(uid, shopid)
    return 0
    -- local first = do_redis({ "get", 'shop_buy_first:' .. uid .. ':' .. shopid})
    -- first = math.floor(first or 0)
    -- if first == 0 then
    --     return firstRate
    -- end
    -- local is_class_day = do_redis({ "get", 'is_class_day'})
    -- is_class_day = math.floor(is_class_day or 0)
    -- if is_class_day > 0  then
    --     return firstRate
    -- end
    -- shopid = tonumber(shopid)
    -- if nil ~= dailyRate[shopid] then
    --     return dailyRate[shopid]
    -- end
    -- return 0
end

function getUserAttrRedis(uid, fieldName) 
    return do_redis({"hget", "d_user:"..uid, fieldName}, uid)
end

function do_redis(args, uid)
    local cmd = assert(args[1])
    args[1] = uid
    return skynet.call(".redispool", "lua", cmd, table.unpack(args))
end

function do_redis_async(args, uid)
    local cmd = assert(args[1])
    args[1] = uid
    return skynet.send(".redispool", "lua", cmd, table.unpack(args))
end

function do_redis_withprename(servicename, args, uid)
    local cmd = assert(args[1])
    args[1] = uid
    return skynet.call("." .. servicename .. "redispool", "lua", cmd, table.unpack(args))
end

function do_mysql_direct(sql)
    return skynet.call(".mysqlpool", "lua", "execute", sql)
end

function do_mysql_queue(sql)
    return skynet.call(".dbsync", "lua", "sync", sql)
end

--关闭房间
function updateDeskStatus(uuid, status)
    status = status or 3
    local sql = string.format("update d_desk set status=%d where uuid='%d' ", status, uuid)
    return skynet.call(".dbsync", "lua", "sync", sql)
end

--matchdepth 是用堆栈的第几行数据加到head里面
function GetLogHead(matchdepth)
    local tracebackarr = string.split(debug.traceback(), "\n")
    if #tracebackarr >= matchdepth then
        local tracebackmsg = string.split(tracebackarr[matchdepth], " ")[1] -- 	./lualib/webreq.lua:58:
        local msgarr = string.split(tracebackmsg, "/")
        local msg = msgarr[#msgarr] -- webreq.lua:58:      
        return string.format("%s:%08x(%s)", SERVICE_NAME, skynet.self(), msg)
    end
    return string.format("%s:%08x", SERVICE_NAME, skynet.self())
end

--四舍五入2位小数
function keepTwoDecimalPlaces(decimal)
    decimal = decimal * 100
    if decimal % 1 >= 0.5 then
            decimal=math.ceil(decimal)
    else
            decimal=math.floor(decimal)
    end
    return  decimal * 0.01
end

--用 concatstr 拼接字符串
--@param log_tbl日志table
--@param concatstr拼接的字符串 如果没传默认为 空格
--@return 拼接好的字符串
local function log_tostring(log_tbl, concatstr)
    if concatstr == nil then
        concatstr = " "
    end

    local tem = {}
    for idx, msg in pairs(log_tbl) do
        if type(msg) ~= "string" then
            msg = tostring(msg)
        end
        table.insert(tem, msg)
    end
    return table.concat(tem, concatstr)
end

--用空格拼接字符串
--@return str
function concatStr(...)
    return log_tostring({...})
end

function dlog(str, gameid, ...)
    if is_logrelease then
        return
    end
    print(os.date("%Y-%m-%d %H:%M:%S", os.time()) .. " " .. os.clock(), "游戏[" .. gameid .. "]", str, ...)
end

function plog(str, gameid, ...)
    if is_logrelease then
        return
    end
    local msg = log_tostring({str, gameid, ...})
    skynet.send(".log", "lua", "info", GetLogHead(4), msg)
end

function print(...)
    local head = string.format("%s [%s]", os.date("%Y-%m-%d %H:%M:%S"), GetLogHead(4))
    local msg = log_tostring({head, ...})
    systemprint(msg)
end

function error(...)
    local head = string.format("%s [%s]", os.date("%Y-%m-%d %H:%M:%S"), GetLogHead(4))
    local msg = log_tostring({head, ...})
    systemerror(msg)
end

function LOG_DEBUG(...)
    if is_logrelease then
        return
    end

    local msg = log_tostring({...})
    skynet.send(".log", "lua", "debug", GetLogHead(4), msg)
end

function LOG_INFO(...)
    local msg = log_tostring({...})
    skynet.send(".log", "lua", "info", GetLogHead(4), msg)
end

function LOG_WARNING(...)
    local msg = log_tostring({...})
    skynet.send(".log", "lua", "warning", GetLogHead(4), msg)
end

function LOG_ERROR(...)
    local msg = log_tostring({...})
    skynet.send(".log", "lua", "error", GetLogHead(4), msg)
end

function LOG_FATAL(...)
    local msg = log_tostring({...})
    skynet.send(".log", "lua", "fatal", GetLogHead(4), msg)
end

function MK_Index(first, second)
    local indexTem = 1000
    return tonumber(first * indexTem + second)
end

function Get_First_Index(index)
    if index > 10 then
        return math.floor(index / 10)
    else
        return index
    end
end

function Get_Second_Index(index)
    return index % 1000
end

function make_pairs_table(t, fields)
    assert(type(t) == "table", "make_pairs_table t is not table")

    local data = {}

    if not fields then
        for i = 1, #t, 2 do
            data[t[i]] = t[i + 1]
        end
    else
        for i = 1, #t do
            data[fields[i]] = t[i]
        end
    end

    return data
end

function make_pairs_table_int(t, fields)
    assert(type(t) == "table", "make_pairs_table t is not table")

    local data = {}

    if not fields then
        for i = 1, #t, 2 do
            data[t[i]] = tonumber(t[i + 1])
        end
    else
        for i = 1, #t do
            data[fields[i]] = tonumber(t[i])
        end
    end

    return data
end

-- 生成通知消息包
function NotifyObj(code, questInfo)
    local notifyobj = {}
    notifyobj.response = {}
    notifyobj.opCode = "NOTIFY_INFO"
    notifyobj.response.errorCode = PDEFINE.RET.SUCCESS
    notifyobj.response.notifyInfo = {}
    notifyobj.response.notifyInfo.questInfo = {}
    notifyobj.response.notifyInfo.questInfo = questInfo
    notifyobj.response.notifyInfo.notifyCode = code
    return notifyobj
end

-- 根据随机列表掉落物品
function RandomLoot(loot_list, times)
    local loot_result = {}
    local loop_times = 1
    if times and times > 0 then
        loop_times = times
    end
    local total_probability = 0
    for _, loot in pairs(loot_list) do
        total_probability = total_probability + loot.Probability
    end
    if total_probability > 1.0 then
        total_probability = 1.0
    end
    for i = 1, loop_times do
        local random_value = random.Get(0, total_probability)
        local ret_item = {}
        for _, loot in pairs(loot_list) do
            if loot.Probability >= 1.0 then
                ret_item = table.copy(loot, true)
                table.insert(loot_result, ret_item)
                break
            end
            random_value = random_value - loot.Probability
            if random_value < 0 then
                ret_item = table.copy(loot, true)
                table.insert(loot_result, ret_item)
                break
            end
        end
    end
    return loot_result
end

local mysqlEscapeMode = "[%z\'\"\\\26\b\n\r\t]";
local mysqlEscapeReplace = {
    ['\0']='\\0',
    ['\''] = '\\\'',
    ['\"'] = '\\\"',
    ['\\'] = '\\\\',
    ['\26'] = '\\z',
    ['\b'] = '\\b',
    ['\n'] = '\\n',
    ['\r'] = '\\r',
    ['\t'] = '\\t',

    };

function mysqlEscapeString(s)
    return string.gsub(s, mysqlEscapeMode, mysqlEscapeReplace);
end

function OFFLINE_CMD(uid, cmd, params, append)
    local param = ""
    for i, v in pairs(params) do
        if i == 1 then
            param = param .. v
        else
            param = param .. "|" .. v
        end
    end
    param = mysqlEscapeString(param)
    local sql = ""
    if append then
        sql = "insert into d_offline_multi_cmd(uid,cmd,param) values(" .. uid .. ",'" .. cmd .. "','" .. param .. "')"
    else
        sql = "replace into d_offline_single_cmd(uid,cmd,param) values(" .. uid .. ",'" .. cmd .. "','" .. param .. "')"
    end
    LOG_DEBUG("OFFLINE_CMD sql:", sql)
    do_mysql_direct(sql)
    return true
end

function GUID()
    local seed = {"0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "a", "b", "c", "d", "e", "f"}
    local tb = {}
    for i = 1, 32 do
        table.insert(tb, seed[random.Get(1, 16)])
    end
    local sid = table.concat(tb)
    return string.format(
        "%s-%s-%s-%s-%s",
        string.sub(sid, 1, 8),
        string.sub(sid, 9, 12),
        string.sub(sid, 13, 16),
        string.sub(sid, 17, 20),
        string.sub(sid, 21, 32)
    )
end

function randomInviteCode()
    local seed = {"1", "2", "3", "4", "5", "6", "7", "8", "9",'A','B','C','D','E','F','G','H','J','K','L','M','N','P','Q','R','S','T','U','V','W','X','Y','Z'}
    local tb = {}
    for i = 1, 8 do
        table.insert(tb, seed[random.Get(1, 33)])
    end
    local sid = table.concat(tb)
    return sid
end

function payId()
    local seed = {"0", "1", "2", "3", "4", "5", "6", "7", "8", "9"}
    local tb = {}
    for i = 1, 8 do
        table.insert(tb, seed[random.Get(1, 10)])
    end
    local sid = table.concat(tb)
    return sid
end

--生成订单流水号
function genOrderId(cat) 
    local icat = 0
    if cat == 'bonus' then
        icat = 4
    elseif cat == 'draw' then
        icat = 3
    end
    return os.date("%Y%m%d%H%M%S", os.time()) .. '0' .. icat .. payId()
end

function random_s_e_value()
    return random.GetRange(1, 9, 6)
end

function randomSomeRValue(s, e, cnt)
    return random.GetRange(s, e, cnt)
end

function random_value(value)
	return random.Get(1, value)
end

function random_get(min, max)
    return random.Get(min, max)
end

local function printT(t)
    local result = {}
    for k, v in pairs(t) do
        table.insert(result, v)
    end
    table.sort(result)
    --
    local str = ""
    for k, v in ipairs(result) do
        str = str .. v .. ","
    end
    --
    return str
end

local function insertList(t, t1)
    for i = 1, #t1 do
        table.insert(t, t1[i])
    end
end

local function seprateLaizi(t, LaiZi)
    local tTmpList = {}
    local laiziList = {}

    for i = #t, 1, -1 do
        local v = t[i]
        if v == LaiZi then
            table.insert(laiziList, v)
        else
            table.insert(tTmpList, v)
        end
    end
    return tTmpList, laiziList
end

local function removeOneNum(t, v)
    for i = 1, #t do
        if t[i] == v then
            table.remove(t, i)
            break
        end
    end
end

local function getSameNumCount(t, v)
    local count = 0
    for i = 1, #t do
        if v == t[i] then
            count = count + 1
        end
    end
    return count
end

function getCoin(htype, difen, pcsC, TgangC, htp)
    local db = 0
    local tmp_coin = 0
    for _, gtype in pairs(htype) do
        db = PDEFINE.COIN_TYPE[gtype]
        tmp_coin = tmp_coin + db
    end
    local taddcoin = 0
    if TgangC then
        if htp == 2 then
            taddcoin = taddcoin + (TgangC - 1) * 2
        end
    end
    if pcsC > 0 then
        taddcoin = taddcoin + (pcsC - 1) * 2
    end
    return tmp_coin + taddcoin
end

function random_uid(uid)
    local CACHE_KEY = "UID_LIST"
    if uid then
        do_redis({"zrem", CACHE_KEY, uid})
    else
        local row = do_redis({"zrevrangebyscore", CACHE_KEY, 1})
        if #row == 0 then
            local num = do_redis({"zcard", "UID_LIST"}) or 0
            error("Get uid error ---->------>-----> Redis 池子中的uid个数：", num)
        end
        uid = row[1]
        do_redis({"zrem", CACHE_KEY, uid})
    end
    return tonumber(uid)

    --local random_value = random.GetRange(0, 9, 7)
    --local uid = ""
    --for i,key in pairs(random_value) do
    --	if i == 1 and key == 0 then
    --		key = 3
    --	end
    --	uid = uid .. key
    --end
    --return tonumber(uid)
end

-------- 打乱数组 --------
function random_array(arr)
    local tmp, index
    for i = 1, #arr - 1 do
        index = math.random(i, #arr)
        if i ~= index then
            tmp = arr[index]
            arr[index] = arr[i]
            arr[i] = tmp
        end
    end
end

function getCardValue(card)
    return card & 0x0F
end

function getCardColor(card)
    return card & 0xF0
end
--所有游戏中每次押注嬴得金币≥200金币时

local function horse_format(uid, coin)
    -- uid = tostring(math.floor(tonumber(uid)))
    local len = #uid
    uid = string.sub(uid,1,1) .."******" ..string.sub(uid, len, len)
    if not coin then
        coin = 0
    end
    coin = string.format("%.2f", coin)
    return uid, coin
end

--跑马灯  玩家中得分数大于等于押注总额的30倍时
function horse_race_lamp1(uname, coin, betcoin)
    if betcoin ~= nil and coin > 0 and coin >= betcoin * 30 then
        uname, coin = horse_format(uname, coin)
        local MSG_CONF = {
            "玩家<color=#05f989>******%s</c>赢得<color=#f525d5>%s</c>",
            "Player<color=#05f989>******%s</c>won <color=#f525d5>%s</c> "
        }
        local msg = {}
        for k, v in pairs(MSG_CONF) do
            table.insert(msg, string.format(v, string.sub(uname, -4), tostring(coin)))
        end
        return msg
    end
    return nil
end

--跑马灯  免费游戏的公告
function horse_race_lamp2(uname)
    uname = horse_format(uname)
    local MSG_CONF = {
        "玩家<color=#05f989>******%s</c>赢得免费游戏",
        "Player<color=#05f989>******%s</c>won FREE GAME "
    }
    local msg = {}
    for k, v in pairs(MSG_CONF) do
        table.insert(msg, string.format(v, string.sub(uname, -4)))
    end
    return msg
end

--跑马灯  玩家中得JP奖池的公告：
function horse_race_lamp3(uname, coin)
    if coin > 0 then
        uname, coin = horse_format(uname, coin)
        local MSG_CONF = {
            "玩家<color=#05f989>******%s</c>赢取了随机积宝大奖<color=#f525d5>%s</c>",
            "Player<color=#05f989>******%s</c>won random jackpot<color=#f525d5>%s</c>"
        }
        local msg = {}
        for k, v in pairs(MSG_CONF) do
            table.insert(msg, string.format(v, string.sub(uname, -4), tostring(coin)))
        end
        return msg
    end
end


--跑马灯  多人游戏跑马灯：
function horse_race_lamp4(uname, gname,cname, coin)
	--[[
		--获取什么  恭喜 "玩家名字" 在 "游戏名称"中拿到"什么牌型",一把获得"金币数"5万--------------这种类型的游戏
		function strinigColorA(uname,gname,cname,gold)
			local msg = string.format("恭喜<color=#ff0000>%s</c>在<color=#ff0000>%s</c>游戏中拿到<color=#ff0000>%s</c>牌型,一把获得<color=#ff0000>%s金币</c>",uname,gname,cname,gold)
			return msg
		end
	]]
	if coin > 0 then
		uname, coin = horse_format(uname, coin)
		local MSG_CONF = 
		{
			"恭喜<color=#ff0000>%s</c>在<color=#ff0000>%s</c>游戏中拿到<color=#ff0000>%s</c>牌型,一把获得<color=#ff0000>%s金币</c>",
			"Congratulations<color=#ff0000>%s</c>from<color=#ff0000>%s</c>game which get<color=#ff0000>%s</c>cardType and <color=#ff0000>%scoin</c>",
		}
		local msg = {}
		for k,v in pairs(MSG_CONF) do
			-- ,uname,gname,cname,gold
			table.insert(msg, string.format(v, uname, gname, cname, tostring(coin)))
		end
		return msg
	end
end

function horse_race_lamp5(uname,gname,coin)
	--[[
	
	--获取什么  恭喜 "玩家名字" 在 "游戏名称"中一把"什么牌型"
	function strinigColorTongsha(uname,gname,gold)
		local msg = string.format("恭喜<color=#ff0000>%s</c>在<color=#ff0000>%s</c>游戏中庄家通杀,一把获得<color=#ff0000>%s金币</c>",uname,gname,gold)
		return msg
	end

	]]
	if coin > 0 then
		uname, coin = horse_format(uname, coin)
		local MSG_CONF = 
		{
			"恭喜<color=#ff0000>%s</c>在<color=#ff0000>%s</c>游戏中庄家通杀,一把获得<color=#ff0000>%s金币</c>",
			"Congratulations<color=#ff0000>%s</c>from<color=#ff0000>%s</c>game all win which get <color=#ff0000>%scoin</c>",
		}
		local msg = {}
		for k,v in pairs(MSG_CONF) do
			-- ,uname,gname,cname,gold
			table.insert(msg, string.format(v, uname, gname, tostring(coin)))
		end
		return msg
	end
end

function horse_race_lamp6(uname,gname,cname,coin)
	--[[
	--获取什么  恭喜 "玩家名字" 在 "游戏名称"中押中"什么牌型",一把获得"金币数"5万--------------这种类型的游戏
	function strinigColorC(uname,gname,cname,gold)
		local msg = string.format("恭喜<color=#ff0000>%s</c>在<color=#ff0000>%s</c>游戏中押中<color=#ff0000>%s</c>牌型,一把获得<color=#ff0000>%s金币</c>",uname,gname,cname,gold)
		return msg
	end
	]]
	if coin > 0 then
		uname, coin = horse_format(uname, coin)
		local MSG_CONF = 
		{
			"恭喜<color=#ff0000>%s</c>在<color=#ff0000>%s</c>游戏中押中<color=#ff0000>%s</c>牌型,一把获得<color=#ff0000>%s金币</c>",
			"Congratulations<color=#ff0000>%s</c>from<color=#ff0000>%s</c>game which get <color=#ff0000>%s</c>card type and <color=#ff0000>%scoin</c>",
		}
		local msg = {}
		for k,v in pairs(MSG_CONF) do
			table.insert(msg, string.format(v, uname, gname, cname, tostring(coin)))
		end
		return msg
	end
end

--过滤特殊字符
function filter_spec_chars(s)
    local charTypes = {num = "数字", char = "字母", chs = "中文"}
    local ss = {}
    local k = 1
    while true do
        if k > #s then
            break
        end
        local c = string.byte(s, k)
        if not c then
            break
        end
        if c < 192 then
            if (c >= 48 and c <= 57) then
                if charTypes.num then
                    table.insert(ss, string.char(c))
                end
            elseif (c >= 65 and c <= 90) or (c >= 97 and c <= 122) then
                if charTypes.char then
                    table.insert(ss, string.char(c))
                end
            end
            k = k + 1
        elseif c < 224 then
            k = k + 2
        elseif c < 240 then
            if c >= 228 and c <= 233 then
                local c1 = string.byte(s, k + 1)
                local c2 = string.byte(s, k + 2)
                if c1 and c2 then
                    local a1, a2, a3, a4 = 128, 191, 128, 191
                    if c == 228 then
                        a1 = 184
                    elseif c == 233 then
                        a2, a4 = 190, c1 ~= 190 and 191 or 165
                    end
                    if c1 >= a1 and c1 <= a2 and c2 >= a3 and c2 <= a4 then
                        if charTypes.chs then
                            table.insert(ss, string.char(c, c1, c2))
                        end
                    end
                end
            end
            k = k + 3
        elseif c < 248 then
            k = k + 4
        elseif c < 252 then
            k = k + 5
            -- elseif c<254 then
            k = k + 6
        end
    end
    return table.concat(ss)
end

--用cjson来解析字符串
function jsondecode(body)
    return cjson.decode(body)
end

--double的加
function Double_Add(...)
    local para_tbl = {...}
    local value = 0
    for _, v in pairs(para_tbl) do
        -- value = value + v
        value = value + v * 100
    end
    -- return value
    return math.floor(value + 0.01) / 100
end

function urldecode(input)
    input = string.gsub(input, "+", " ")
    input =
        string.gsub(
        input,
        "%%(%x%x)",
        function(h)
            return string.char(checknumber(h, 16))
        end
    )
    input = string.gsub(input, "\r\n", "\n")
    return input
end

function urlencode(input)
    input =
        string.gsub(
        input,
        "([^%w%.%- ])",
        function(c)
            return string.format("%%%02X", string.byte(c))
        end
    )
    return string.gsub(input, " ", "+")
end

--加载配置文件，用换行和=分割
function load_config(filename)
    local f = assert(io.open(filename))
    local source = f:read "*a"
    f:close()
    local tmp = {}
    -- source.split()
    assert(load(source, "@" .. filename, "t", tmp))()

    return tmp
end

--检测table中是否有指定的value
--@param table_p 待检测的table
--@param value 指定value
--@return true表示包含  false表示不包含
function checkInTable(table_p, value)
    for k, v in pairs(table_p) do
        if v == value then
            return true
        end
    end
    return false
end

--table元素乱序
--@param arr 待乱序的table
--@param arr_index arr的原序列 arr乱序的时候会跟着一起乱序
function stufftable(arr, arr_index)
    assert(arr ~= nil)
    if arr_index ~= nil then
        assert(#arr == #arr_index)
    end

    if #arr > 1 then
        for i = 1, #arr do
            local ranOne = math.random(1, #arr + 1 - i)
            arr[ranOne], arr[#arr + 1 - i] = arr[#arr + 1 - i], arr[ranOne]
            if arr_index ~= nil then
                arr_index[ranOne], arr_index[#arr_index + 1 - i] = arr_index[#arr_index + 1 - i], arr_index[ranOne]
            end
        end
    end
end

--根据概率从指定data中选择数据
--@param rate 概率 概率运算的时候会把概率运算放大1W倍
--@param data 数据table
--@return 选择的数据,选择的数据在表中的序号
function randomtablebyrate(rate, data)
    local choose
    local allrate = 0
    for i, v in ipairs(rate) do
        allrate = allrate + v
    end
    allrate = allrate * 10000
    local randrate = math.random(1, math.ceil(allrate))
    local tmprate = 0
    local choose
    local choosei
    for i, v in ipairs(data) do
        tmprate = tmprate + rate[i] * 10000
        if randrate <= tmprate then
            choose = v
            choosei = i
            break
        end
    end
    if choose == nil then
        choose = data[#data]
        choosei = #data
    end
    return choose, choosei
end

--根据赔率从指定data中选择数据
--@param mult_t 赔率 概率运算的时候会把概率运算放大1W倍
--@param data 数据table
--@return 选择的数据,选择的数据在表中的序号
function randomtablebymult(mult_t, data)
    local rate = {}
    local rate_tmp = {}
    local all = 0
    for i, mult in ipairs(mult_t) do
        local num = 1 / mult
        table.insert(rate_tmp, num)
        all = all + num
    end
    for _, prob in ipairs(rate_tmp) do
        table.insert(rate, prob / all * 10000)
    end
    return randomtablebyrate(rate, data)
end

--替换整列为万能牌
--@param resultCards手牌 wild 万能牌对应line全部替换成line
function changeCardsLineWild(resultCards, wild, line, lineIndex)
    if not line then
        for _, lineInfo in pairs(lineIndex) do
            local tmpLineInfo = nil
            for i = 1, #lineInfo do
                if resultCards[lineInfo[i]] == wild then
                    tmpLineInfo = lineInfo
                    break
                end
            end
            if tmpLineInfo then
                for i = 1, #tmpLineInfo do
                    resultCards[tmpLineInfo[i]] = wild
                end
            end
        end
    else
        for l, lineInfo in pairs(lineIndex) do
            if l == line then
                local tmpLineInfo = nil
                for i = 1, #lineInfo do
                    if resultCards[lineInfo[i]] == wild then
                        tmpLineInfo = lineInfo
                        break
                    end
                end
                if tmpLineInfo then
                    for i = 1, #tmpLineInfo do
                        resultCards[tmpLineInfo[i]] = wild
                    end
                end
            end
        end
    end
end

--@param 替换对应列为对应的牌
function assignLineCard(resultCards, line, card, lineIndex)
    if line then
        for i = 1, #lineIndex[line] do
            resultCards[lineIndex[line][i]] = card
        end
    end
end

--每一列只能出现一个散列牌
--@param resultCards手牌 scatter 万能牌, line替换对应的列
function changeCardsLineOnlyOneFreeCard(resultCards, scatter, spcards, line)
    local lineIndex = {{1, 6, 11}, {2, 7, 12}, {3, 8, 13}, {4, 9, 14}, {5, 10, 15}}
    if not line then
        for _, lineInfo in pairs(lineIndex) do
            local scatterCnt = 0
            for _, index in pairs(lineInfo) do
                if resultCards[index] == scatter then
                    if scatterCnt == 1 then
                        local spIndex = math.random(#spcards)
                        resultCards[index] = spcards[spIndex]
                    end
                    scatterCnt = scatterCnt + 1
                end
            end
        end
    else
        for l, lineInfo in pairs(lineIndex) do
            if l == line then
                local scatterCnt = 0
                for _, index in pairs(lineInfo) do
                    if resultCards[index] == scatter then
                        if scatterCnt == 1 then
                            local spIndex = math.random(#spcards)
                            resultCards[index] = spcards[spIndex]
                        end
                        scatterCnt = scatterCnt + 1
                    end
                end
            end
        end
    end
end

--更改对应下标对应的整列牌
function changeCardsIndexLine(resultCards, card, index, lineIndex)
    for line, lineInfo in pairs(lineIndex) do
        local tmpLineInfo = nil
        for i = 1, #lineInfo do
            if lineInfo[i] == index then
                tmpLineInfo = lineInfo
                break
            end
        end
        if tmpLineInfo then
            for i = 1, #tmpLineInfo do
                resultCards[tmpLineInfo[i]] = card
            end
        end
    end
end

--从arg中取出不相同的count个不包含ps表的元素
function selectPsNumber(count, ps, indexs, lineIndex)
    local selected = {}
    if count < 1 then
        return selected
    end
    if not indexs then --每一列找出一个下标
        --[[while #selected < count do
	    	if #lineIndex[1] == 0 and #lineIndex[2] == 0 and #lineIndex[3] == 0 and #lineIndex[4] == 0 and #lineIndex[5] == 0  then
	    		break
	    	end
	    	for i = 1, #lineIndex do
	    		if #lineIndex[i] == 0 then

	    		end
		        local key = table.remove(lineIndex[i],math.random(#lineIndex[i]))
		        local flg = true
		        if ps then
			        for _,k in pairs(ps) do
			            if k == key then
			                flg = false
			                break
			            end
			        end
			    end
		        if flg then
		          table.insert(selected,key)
		        end
		        break
		    end
	    end]]
        local tmpIineIndex = table.copy(lineIndex)
        local value = 1
        local swap = 1
        local l = #tmpIineIndex
        for i = 1, l do
            local x = l - i
            local rv = random_value(x)
            if x == 0 then
                rv = 0
            end
            value = i + rv
            swap = tmpIineIndex[i]
            tmpIineIndex[i] = tmpIineIndex[value]
            tmpIineIndex[value] = swap
        end
        for i = 1, 5 do
            for j = 1, #lineIndex[1] do
                if #tmpIineIndex[i] == 0 then
                    break
                end
                local key = table.remove(tmpIineIndex[i], math.random(#tmpIineIndex[i]))
                local flg = true
                if ps then
                    for _, k in pairs(ps) do
                        if k == key then
                            flg = false
                            break
                        end
                    end
                end
                if flg then
                    table.insert(selected, key)
                    if #selected == count then
                        return selected
                    end
                    break
                end
            end
        end
    else
        indexs = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15}
        while #selected < count do
            if #indexs == 0 then
                break
            end
            local index = table.remove(indexs, math.random(#indexs))
            local flg = true
            if ps then
                for _, k in pairs(ps) do
                    if k == index then
                        flg = false
                        break
                    end
                end
            end
            if flg then
                table.insert(selected, index)
            end
        end
    end
    return selected
end

function findIdx(tbl, card)
    local idx = -1
    for k, v in ipairs(tbl) do
        if v == card then
            idx = k
            break
        end
    end
    return idx
end

-- 反转一个表 {1, 2, 3, 4, 5} ==>> {5, 4, 3, 2, 1}
function reverseTable(tbl)
    local ret = {}
    for i = #tbl, 1, -1 do
        table.insert(ret, tbl[i])
    end
    return ret
end

-- 随机取出几个不同的元素(除ps中出现的)
function getAntBunCount(count, tab, ps)
    local value = 1
    local swap = 1
    local indexs = table.copy(tab)
    local l = #indexs
    for i = 1, l do
        local x = l - i
        local rv = math.floor(random_value(x))
        if x == 0 then
            rv = 0
        end
        value = i + rv
        swap = indexs[i]
        indexs[i] = indexs[value]
        indexs[value] = swap
    end

    local selected = {}
    while #selected < count do
        if #indexs == 0 then
            break
        end
        local index = table.remove(indexs, math.random(#indexs))
        local flag = false
        if ps then
            for _, key in pairs(ps) do
                if key == index then
                    flag = true
                    break
                end
            end
        end
        if not flag then
            table.insert(selected, index)
        end
    end
    return selected
end

function makeDeskBaseInfo(gameid, deskid)
    return {gameid = gameid, deskid = deskid}
end

function isempty(s)
    return s == nil or s == ""
end

function get_array_diff(arr, arr_other)
    assert(type(arr) == "table" and type(arr_other) == "table")
    local ht_other = {}
    for i, unit in ipairs(arr_other) do
        ht_other[unit] = true
    end

    local t_diff = {}
    local t_same = {}

    for i, unit in ipairs(arr) do
        if ht_other[unit] then
            table.insert(t_same, unit)
        else
            table.insert(t_diff, unit)
        end
    end
    return t_diff, t_same
end
--! 获取统计打点key，按天
function getStatisKey(event_type, gameid)
    local date = os.date("%Y%m%d", os.time())
    local key = "statis:" .. event_type .. ":" .. date
    if nil ~= gameid then
        key =  key .. ":" .. gameid
    end
    return key
end

-- 判断用户是否是今天注册
function isTodayReg(timestamp)
    local now = os.time()
    if (now - timestamp) > 86400 then
        return false
    end
    return true
end

--获取今天剩余时间戳
function getTodayLeftTimeStamp()
    local cur_timestamp = os.time()
    local temp_date = os.date("*t", cur_timestamp)
    local beginTime = os.time({year=temp_date.year, month=temp_date.month, day=temp_date.day, hour=0})
    local hadCosume = cur_timestamp - beginTime
    local leftTime = 86400 - hadCosume
    if leftTime < 0 then
        leftTime = 0
    end
    return leftTime
end

-- 获取每月1号开始的时间戳
function getMonthStartTimeStamp()
    local cur_timestamp = os.time()
    local temp_date = os.date("*t", cur_timestamp)
    local beginTime = os.time({year=temp_date.year, month=temp_date.month, day=1, hour=0, min =0, sec = 00})
    return beginTime
end

function lottery(weightConf)
    local prizeWeight = {}
    local tmp = 0
    local weightSum = 0
    for i, value in ipairs(weightConf) do
        tmp = tmp + value
        table.insert(prizeWeight, tmp)
        weightSum = weightSum + value
    end

    local random = math.random(1, weightSum)
    table.insert(prizeWeight, random)
    table.sort(prizeWeight)
    local randomIdx = findIdx(prizeWeight, random)
    randomIdx = math.min(randomIdx, #prizeWeight-1)
    return randomIdx
end

--生成1个poolround_id
function insertPoolRoundInfo()
    return do_redis({'incr', PDEFINE.CACHE_LOG_KEY.poolround_log});
end

--[[
    刮刮乐根据押注次数获取在线奖励的倍数
    1、游戏服和node服是使用
]]
function getMultFromTimes(times)
    times = tonumber(times)
    local mult = 1
    if not times then
        times = 0
    end
    if times >= 0 and times <= 55 then
        mult = 1
    elseif times >= 56 and times <= 177 then
        mult = 2
    elseif times >= 178 and times <= 408 then
        mult = 3
    elseif times >= 409 and times <= 909 then
        mult = 4
    elseif times >= 910 and times <= 2000 then
        mult = 5
    elseif times >= 2001 then
        mult = 10
    end
    return mult
end

-- 生成是否购买的缓存key
function genBuyCacheKey(uid, rtype)
    return string.format("buy_%s_%d", rtype, uid)
end

-- 从redis中生成mailid
function genMailId()
    local mailid = do_redis({ "incr", "d_mail:mailid"})
    return mailid
end

function genMsgId()
    local mailid = do_redis({ "incr", "d_sys_user_msg:id"})
    return mailid
end

function genPwd(uid, passwd)
    return md5.sumhexa(passwd ..'|'.. uid)
end

-- 保留n位小数
function keepDecimal(num, n)
    if type(num) ~= "number" then
        return num    
    end
    n = n or 2
    if num < 0 then
        return -(math.abs(num) - math.abs(num) % 0.1 ^ n)
    else
        return num - num % 0.1 ^ n
    end
end

function decodePrize(str)
    local rewards = {}
    if str == "" or nil == str then
        return {}
    end
    local tempRewards = string.split(str, "|")
    for _, reward in ipairs(tempRewards) do
        local info = string.split(reward, ":")
        local tmp = {type=tonumber(info[1]), count=tonumber(info[2])}
        tmp['img']  = info[3]
        if nil ~= info[4] then
            tmp['days'] = tonumber(info[4])
        end
        
        table.insert(rewards, tmp)
    end
    return rewards
end

--解开进入不同钱包的分成比例
function decodeRate(str)
    local rateArr = {1, 0, 0}
    if nil == str or str == "" then
        return rateArr
    end
    rateArr = string.split(str, ':')
    return rateArr
end

--- 将奖励从字符串解析成列表
function decodeRewards(str)
    local rewards = {}
    if str == "" then
        return {}
    end
    local tempRewards = string.split(str, "|")
    for _, reward in ipairs(tempRewards) do
        local info = string.split_to_number(reward, ":")
        local reward = {type=tonumber(info[1]), count=tonumber(info[2])}
        -- 部分奖励有额外字段
        if info[3] then
            reward.addition = info[3]
        end
        if reward.type == PDEFINE.PROP_ID.SKIN_EXP then
            if info[3] then
                if info[3] == 25 then
                    reward.img = "exp_25"
                elseif info[3] == 50 then
                    reward.img = "exp_50"
                elseif info[3] == 100 then
                    reward.img = "exp_100"
                end 
            end
        elseif reward.type == PDEFINE.PROP_ID.SKIN_FRAME then
            reward.count = 1 --数量
            reward.img = '' --图片
            if tonumber(info[2]) == 141 then
                reward.img = PDEFINE.SKIN.CHANGENICK.AVATAR.img
            end
            reward.day = info[3] --使用天数
        end
        table.insert(rewards, reward)
    end
    return rewards
end

-- 将奖励从列表解析成字符串
function encodeRewards(rewards)
    local rewardStr = ""
    for _, reward in ipairs(rewards) do
        if rewardStr ~= "" then
            rewardStr = rewardStr.."|"
        end
        rewardStr = rewardStr..reward.type..":"..reward.count
        if reward.addition then
            rewardStr = rewardStr..reward.addition
        end
    end
    return rewardStr
end

-------------------------------------------------------------------
-- 根据weight来计算出随机结果
-- 只要在子对象中设有weight字段，就可以使用该函数来随机出一个子项
-- eg: tbl = {
--    {id=1, weight=5},
--    {id=2, weight=6},
--    {id=3, weight=7},
-- }
-------------------------------------------------------------------

function randByWeight(tbl, num)
    local totalWeight = 0
    for _, value in pairs(tbl) do
        totalWeight = totalWeight + value.weight
    end
    -- 如果权重都为空，则返回nil
    if totalWeight == 0 then
        return nil, nil
    end
    if num then
        local idxs = {}
        local values = {}
        for i = 1, num do
            local currWeight = 0
            local randNum = math.random(totalWeight)
            for idx, value in pairs(tbl) do
                currWeight = currWeight + value.weight
                if randNum <= currWeight then
                    table.insert(idxs, idx)
                    table.insert(values, value)
                    break
                end
            end
        end
        return idxs, values
    else
        local currWeight = 0
        local randNum = math.random(totalWeight)
        for idx, value in pairs(tbl) do
            currWeight = currWeight + value.weight
            if randNum <= currWeight then
                return idx, value
            end
        end
    end
end

-- 计算当前周期对应的结算时间戳
function calRoundEndTime()
    local temp_date = os.date("*t", os.time())
    local start_time = os.time({year=temp_date.year, month=temp_date.month, day=temp_date.day, hour=0}) --当天0点
    return (start_time + 86400)
end

-- 计算当前周期对应的开始时间戳
function calRoundBeginTime()
    local end_time = calRoundEndTime()
    return (end_time - 86400)
end

-- 计算距离当前周期结束时间还有多少s
function getThisPeriodTimeStamp()
    local now = os.time()
    local end_time = calRoundEndTime()
    return (end_time - now)
end

-------------------------------------------------------------------
-- 将一个列表随机打乱
-- eg: tbl = {1, 2, 3, 4, 5}
-------------------------------------------------------------------
function shuffle(tbl)
    for i = #tbl, 2, -1 do
        local j = math.random(i)
        tbl[i], tbl[j] = tbl[j], tbl[i]
    end
    return tbl
end

-------------------------------------------------------------------
-- 从指定序号中，随机出指定数量的随机数
-- eg: genRandIdxs(10, 3) = {3, 10, 4}
-------------------------------------------------------------------
function genRandIdxs(total, num)
    if total < num then
        return nil
    end
    local totalIdxs = {}
    for i = 1, total do
        local pos = math.random(i)
        table.insert(totalIdxs, pos, i)
    end
    local randIdxs = {}
    for i = 1, num do
        table.insert(randIdxs, totalIdxs[i])
    end
    return randIdxs
end

-- 给道具列表排序使用
function sortByPropType(a, b)
    return a.type <= b.type
end

-- 抽卡，可能单个碎片有N张
function lottery_cards(cardList, num)
    local _, cards = randByWeight(cardList, num)
    local lottery = {}
    for _, row in pairs(cards) do
         if lottery[row.cardid] == nil then
            lottery[row.cardid] = 0
         end
         lottery[row.cardid] = lottery[row.cardid] + 1
    end
    return lottery
end

-- 计算下次结算财富榜榜首奖励的时间戳
function getWealthRankNextSettleTime()
    local nowTime = os.time()
    local nextTime = do_redis({"get", PDEFINE.REDISKEY.RANK_SETTLE.WEATHTIME})
    if nil == nextTime or tonumber(nextTime) <= nowTime then
        nextTime, _ = getWeekEndTimestamp()
        do_redis({"set", PDEFINE.REDISKEY.RANK_SETTLE.WEATHTIME, nextTime})
    end
    return nextTime
end

function user_timeout_call(ti, f,parme)
    local function t()
        if f then
            f(parme)
        end
    end
    skynet.timeout(ti, t)
    return function(parme) f=nil end
end

function isKing(uid)
    local cacheKey1 = PDEFINE.REDISKEY.RANK_SETTLE.WEALTHKING..uid
    local flag1 = do_redis({"get", cacheKey1})
    -- LOG_DEBUG("isKing flag1:", flag1, ' cacheKey1:',cacheKey1)
    if flag1 and tonumber(flag1) > 0 then
        return true
    end
    return false
end

function getItemFromList(datalist, img)
    for _, row in pairs(datalist) do
        if row.img == img then
            return row
        end
    end
end

function getLeagueGameIds()
    local gameids = {}
    for gid, row in pairs(PDEFINE.GAME_TYPE_INFO[APP][1]) do
        if row['MATCH'] == 'FIGHT' then
            table.insert(gameids, gid)
        end
    end
    return gameids
end

-- 使用赠送的魅力值道具次数
function minus_send_charm_time(uid, img)
    local cacheKey = PDEFINE.REDISKEY.TASK.SKIN_CHARM .. uid
    local skinlist = do_redis({"get", cacheKey})
    if nil == skinlist or "" == skinlist then
        return false
    end
    local minused = false
    skinlist = cjson.decode(skinlist)
    if #skinlist > 0 then
        for i=#skinlist, 1, -1 do
            if skinlist[i].img == img then
                skinlist[i].times = tonumber(skinlist[i].times) - 1
                if skinlist[i].times >= 0 then
                    minused = true
                else
                    skinlist[i].times = 0
                end
                break
            end
        end
        do_redis({"set", cacheKey, cjson.encode(skinlist)})
        if minused then
            return true
        end
    end
    return false
end

-- 加魅力值道具赠送的次数
function add_send_charm_times(uid, img, isexp, times)
    local _uid = uid
    local cacheKey = PDEFINE.REDISKEY.TASK.SKIN_CHARM .. _uid
    local skinlist = do_redis({"get", cacheKey})
    if nil == skinlist or "" == skinlist then
        skinlist = "[]"
    end
    if times == nil then
        times = 1
    end
    local item
    local _item = {
        ["times"] = times,
        ["img"] = img,
    }
    if isexp then
        _item['exp'] = 1 --经验值道具
    end
    skinlist = cjson.decode(skinlist)
    if #skinlist > 0 then
        for _, row in pairs(skinlist) do
            if row.img == img then
                row.times = row.times + times  --已有就直接修改次数
                item = row
                break
            end
        end
        if nil == item then
            table.insert(skinlist, _item) --没有就插入数据
        end
    else
        table.insert(skinlist, _item) --没有就插入数据
    end
    do_redis({"set", cacheKey, cjson.encode(skinlist)})
end

-- 获取赠送的魅力值道具列表
function get_send_charm_list(uid)
    local sendList = {}
    local cacheKey = PDEFINE.REDISKEY.TASK.SKIN_CHARM .. uid --签到赠送的道具加入到已有列表中
    local sendSkinList = do_redis({"get", cacheKey})
    if nil ~= sendSkinList and "" ~= sendSkinList then
        sendList = cjson.decode(sendSkinList)
    end
    return sendList
end

-- 赠送限时的道具
function send_timeout_skin(img, endtime, uid)
    local cacheKey = PDEFINE.REDISKEY.TASK.SKIN_SEND .. uid
    local sendSkinList = do_redis({"get", cacheKey})
    if nil == sendSkinList or "" == sendSkinList then
        sendSkinList = "[]"
    end
    local item
    local _item = {
        ["endtime"] = endtime + os.time(),
        ["img"] = img,
    }
    sendSkinList = cjson.decode(sendSkinList)
    if #sendSkinList > 0 then
        for _, row in pairs(sendSkinList) do
            if row.img == img then
                row.endtime = row.endtime + endtime --已有就直接修改过期时间
                item = row
                break
            end
        end
        if nil == item then
            table.insert(sendSkinList, _item) --没有就插入数据
        end
    else
        table.insert(sendSkinList, _item) --没有就插入数据
    end
    do_redis({"set", cacheKey, cjson.encode(sendSkinList)})
end

-- 删除限时的道具(有些道具会在不同地方赠送，有限时，有永久)
function del_timeout_skin(uid, img)
    local cacheKey = PDEFINE.REDISKEY.TASK.SKIN_SEND .. uid
    local sendSkinList = do_redis({"get", cacheKey})
    if nil == sendSkinList or "" == sendSkinList then
        return
    end
    sendSkinList = cjson.decode(sendSkinList)
    if #sendSkinList > 0 then
        for i=#sendSkinList, 1, -1 do
            if sendSkinList[i].img == img then
                table.remove(sendSkinList, i)
                break
            end
        end
        do_redis({"set", cacheKey, cjson.encode(sendSkinList)})
    end
end

-- 机器人构建游戏内发送互动表情
function buildEmojiMsg(userInfo, id, toUid)
    local retobj = {c=PDEFINE.NOTIFY.NOTIFY_ROOM_CHAT, code=PDEFINE.RET.SUCCESS}
    retobj.uid = userInfo.uid
    retobj.seatid = userInfo.seatid
    retobj.coin = userInfo.coin
    local cotent = cjson.encode({
        cmd='interactive_emotion',
        emotionId = id,
        fromUid = userInfo.uid,
        toUid = toUid,
    })
    local nowtime = os.time()
    local msg = cjson.encode({
        uid = userInfo.uid,
        nick=userInfo.playername,
        gender = userInfo.sex,
        icon = userInfo.usericon,
        avatar = userInfo.avatarframe,
        fontSkin = userInfo.frontskin,
        msgType = 4,
        sendTime = nowtime * 1000,
        content = cotent
    })
    retobj.msg = msg
    return retobj
end

-- 机器人构建游戏内发送文字信息
function buildChatMsg(userInfo, id)
    local retobj = {c=PDEFINE.NOTIFY.NOTIFY_ROOM_CHAT, code=PDEFINE.RET.SUCCESS}
    retobj.uid = userInfo.uid
    retobj.seatid = userInfo.seatid
    local nowtime = os.time()
    local msg = cjson.encode({
        uid = userInfo.uid,
        nick=userInfo.playername,
        gender = userInfo.sex,
        icon = userInfo.usericon,
        avatar = userInfo.avatarframe,
        fontSkin = userInfo.frontskin,
        chatSkin = userInfo.chatSkin,
        fcoin = userInfo.coin,
        msgType = 3,
        sendTime = nowtime * 1000,
        content = id
    })
    retobj.msg = msg
    return retobj
end

-- 获取本周末倒计时时间戳
function getWeekEndTimestamp()
    local nowD = os.date("*t")
    local zeroTime = os.time({year=nowD.year, month=nowD.month, day=nowD.day, hour=0, min =0, sec = 00}) --今日开始时间戳
    local wday = os.date("%w")
    wday = tonumber(wday)
    wday = wday - 1
    local begintime = zeroTime - (wday * 86400) --本周一0点
    local stoptime = begintime + 7*86400 - 1 --本周日24点
    return stoptime, begintime
end

-- 判断服务器是否在维护中
function isMaintain()
    local cache = do_redis({ "get", PDEFINE.REDISKEY.YOU9API.MAIN_TAIN})
    cache = tonumber(cache or 0)
    if cache > 0 then --维护中
        return true
    end
    return false
end

local function luckyBufferLimit(gameid)
    local cnt = 5
    gameid = tonumber(gameid)
    if gameid == PDEFINE_GAME.GAME_TYPE.BALOOT then
        cnt = 8
    end
    if gameid == PDEFINE_GAME.GAME_TYPE.LUDO then
        cnt = 20
    end
    return cnt
end

-- 是否新人buffer
-- 如果是新人buffer，进入固定的几个游戏会给好牌，尽量要他赢几轮
function hasLuckyBuffer(uid, gameid)
    return false
end

-- 是否印度文/英文/数字
-- 印度文 0900-097F
function isIndiaLimit(str)
    for _, c in utf8.codes(str) do 
        if (c > 127 and c < 0x0900) or c > 0x097F then
            return false
        end
    end
    return true
end

-- 轮询，直到满足要求, 然后运行函数
function roundCheckBytimestamp(redis_key, func, interval)
    local targetTime = do_redis({"get", redis_key})
    -- LOG_DEBUG("roundCheckBytimestamp, redis_key:", redis_key, " interval:", interval, " targetTimestamp:", targetTime)
    local delayTime = nil
    if targetTime then
        targetTime = tonumber(targetTime)
        delayTime = targetTime - os.time()
    end 
    if delayTime and delayTime <= interval then
        if delayTime <= 0 then
            func()
        else
            skynet.timeout(delayTime*100, function ()
                func()
            end)
        end
    else
        skynet.timeout(interval*100, function()
            roundCheckBytimestamp(redis_key, func, interval)
        end)
    end
end

-- 获取是否打开777游戏
function isOpen777(gameid)
    -- if DEBUG then
    --     return 1
    -- else
    --     local isOpen = 0
    --     local open777 = do_redis({"get", "open777:"..gameid})
    --     if open777 then
    --         isOpen = 1
    --     end
    --     return isOpen
    -- end
    return 0
end

-- 获取排行榜开始日期
-- 每周是从周六开始
function getLeaderBorderRangeTime(timestamp)
    local result = {
        day = {start=nil, stop=nil},
        week = {start=nil, stop=nil},
        month = {start=nil, stop=nil},
    }
    local d = os.date("*t", timestamp)
    -- 计算天
    result.day.start = os.time({year=d.year, month=d.month, day=d.day, hour=0, min=0, sec=0})
    result.day.stop = result.day.start + 86400 - 1
    --result.day.stop = timestamp + 300
    -- 计算周
    local weekDay = d.wday
    if weekDay == 0 then
        weekDay = 7
    end
    if weekDay >= 6 then
        result.week.start = result.day.start - (weekDay - 6)*86400
    else
        result.week.start = result.day.start - (weekDay + 1)*86400
    end
    result.week.stop = result.week.start + 7*86400 - 1
    -- 计算月
    result.month.start = os.time({year=d.year, month=d.month, day=1, hour=0, min=0, sec=0})
    local nextMonth = d.month + 1
    local addYead = 0
    if nextMonth > 12 then
        nextMonth = 1
        addYead = 1
    end
    result.month.stop = os.time({year=d.year+addYead, month=nextMonth, day=1, hour=0, min=0, sec=0}) - 1

    -- if true then
    --     result.day.stop = timestamp + 300
    --     result.week.stop = timestamp + 360
    --     result.month.stop = timestamp + 420
    -- end

    return result
end

-- 用户名增加星号
function hidePlayername(str)
    if type(str) ~= 'string' then
        return ""
    end
    local s = ""
    local strlen = utf8.len(str)
    local showIdxs = {}
    if strlen == 1 then
        return str..'*'
    elseif strlen == 2 then
        showIdxs = {1}
    elseif strlen == 3 then
        showIdxs = {1,strlen}
    else
        showIdxs = {1,2,strlen}
    end
    for idx, c in utf8.codes(str) do 
        if table.contain(showIdxs, idx) then
            s = s..utf8.char(c)
        else
            s = s..'*'
        end
    end
    return s
end

-- 获取245协议对应的时间分表
function getStatisticsTbName()
    local tbname = 'd_statistics'
    local ts = os.time()
    if ts >= 1677646800 then --2023年3月1日
        local suffix = os.date('%Y%m', ts)
        tbname = string.format("d_statistics_%s", suffix)
    end
    return tbname
end

-- 获取d_app_log分表
function getDAppLogTbName()
    local tbname = 'd_app_log'
    local ts = os.time()
    if ts >= 1677609000 then --2023年3月1日
        local suffix = os.date('%Y%m', ts)
        tbname = string.format("d_app_log_%s", suffix)
    end
    return tbname
end

--返回当前字符实际占用的字符数
local function SubStringGetByteCount(str, index)
    local curByte = string.byte(str, index)
    local byteCount = 1;
    if curByte == nil then
        byteCount = 0
    elseif curByte > 0 and curByte <= 127 then
        byteCount = 1
    elseif curByte >= 192 and curByte <= 223 then
        byteCount = 2
    elseif curByte >= 224 and curByte <= 239 then
        byteCount = 3
    elseif curByte >= 240 and curByte <= 247 then
        byteCount = 4
    end
    return byteCount;
end 

--获取中英混合UTF8字符串的真实字符数量
local function SubStringGetTotalIndex(str)
    local curIndex = 0;
    local i = 1;
    local lastCount = 1;
    repeat
        lastCount = SubStringGetByteCount(str, i)
        i = i + lastCount;
        curIndex = curIndex + 1;
    until(lastCount == 0);
    return curIndex - 1;
end

--获取字符串的真实索引值
local function SubStringGetTrueIndex(str, index)
    local curIndex = 0;
    local i = 1;
    local lastCount = 1;
    repeat
        lastCount = SubStringGetByteCount(str, i)
        i = i + lastCount;
        curIndex = curIndex + 1;
    until(curIndex >= index);
    return i - lastCount;
end

--截取中英混合的UTF8字符串，endIndex可缺省
function SubStringUTF8(str, startIndex, endIndex)
    if startIndex < 0 then
        startIndex = SubStringGetTotalIndex(str) + startIndex + 1;
    end

    if endIndex ~= nil and endIndex < 0 then
        endIndex = SubStringGetTotalIndex(str) + endIndex + 1;
    end

    if endIndex == nil then
        return string.sub(str, SubStringGetTrueIndex(str, startIndex));
    else
        return string.sub(str, SubStringGetTrueIndex(str, startIndex), SubStringGetTrueIndex(str, endIndex + 1) - 1);
    end
end

function addBindCache(uid, ddid, nickname, platform, timestamp, password)
    timestamp = tonumber(timestamp or 0)
    if nil == password then
        password = ''
    end
    local tbl = {
        uid = uid,
        unionid = ddid,
        nickname = nickname,
        sex = 0,
        platform = platform,
        create_time = timestamp,
        passwd = password
    }
    do_redis({"hmset", 'd_user_bind:'..ddid, tbl})
end

function GetAPPUrl(key)
    if PDEFINE.APPS.URLS[APP] then
        return PDEFINE.APPS.URLS[APP][key]
    end
    return PDEFINE.APPS.URLS['DEFAULT'][key]
end
