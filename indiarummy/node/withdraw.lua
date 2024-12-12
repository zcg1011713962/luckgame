local skynet  = require "skynet"
local cjson   = require "cjson"
cjson.encode_sparse_array(true)
cjson.encode_empty_table_as_object(false)
local queue = require "skynet.queue"
local cluster = require "cluster"
local snax    = require "snax"
local player_tool = require "base.player_tool"
local cs = queue()
--[[
--- 提现功能
--- 1、绑定账号信息(银行/UPI/USDT)
--- 2、提现
--- 3、记录
]]

local handle
local cmd = {}
function cmd.bind(agent_handle)
    handle = agent_handle
end

-------- 成功返回函数 --------
local function resp(retobj)
    return PDEFINE.RET.SUCCESS, cjson.encode(retobj)
end

-- 获取可提现金额
local function getDrawCoin(uid)
    local sql = string.format( "select uid,totalwin, totalbet, totaldraw, candraw, maxdraw from d_user where uid=%d", uid)
    local res = skynet.call(".mysqlpool", "lua", "execute", sql)
    local user = res[1]
    local totalwin = user.totalwin or 0 --总赢钱
    local totalbet = user.totalbet or 0 --总下注
    local totaldraw = user.totaldraw or 0 --已提
    local candraw = user.candraw or 0 --赠送的可提现
    -- local maxdraw = user.maxcraw or 0 --限制的最大可提现
    local dcoin = totalwin - totalbet - totaldraw + candraw
    if dcoin < 0 then
        dcoin = 0
    end
    return dcoin
end

local function getBindInfoList(uid)
    local ret = {bankList = {}, upiList = {}, usdtList = {}}
    local sql = string.format( "select * from d_user_bank where uid=%d", uid)
    local datalist = skynet.call(".mysqlpool", "lua", "execute", sql)
    if #datalist > 0 then
        for _, row in pairs(datalist) do
            local cat = math.floor(row.cat)
            if cat == 1 then
                table.insert(ret.bankList, {
                    ['account'] = row['account'],
                    ['username']= row['username'],
                    ['ifsc']    = row['ifsc'],
                    ['bankname']= row['bankname'],
                    ['email']   = row['email'],
                    ['id']      = row['id']
                })
            elseif cat == 2 then
                table.insert(ret.upiList, {
                    ['upi']     = row['account'],
                    ['username']= row['username'],
                    ['phone']   = row['phone'],
                    ['id']      = row['id']
                })
            elseif cat == 3 then
                table.insert(ret.usdtList, {
                    ['addr']    = row['account'],
                    ['id']      = row['id']
                })
            end
        end
    end
    
    local coin = handle.dcCall("user_dc", "getvalue", uid, "coin")
    ret.coin = coin
    ret.dcoin = getDrawCoin(uid)
    return ret
end

--! 获取绑定的信息
function cmd.getInfo(msg)
    local recvobj = cjson.decode(msg)
    local uid = math.floor(recvobj.uid)

    local retobj = {c=math.floor(recvobj.c), code= PDEFINE.RET.SUCCESS, uid=uid, spcode = 0, bankList = {}, upiList = {}, usdtList = {}}
    local tbl = getBindInfoList(uid)
    table.merge(retobj, tbl)
    return resp(retobj)
end

--! 绑定信息
function cmd.bindInfo(msg)
    local recvobj = cjson.decode(msg)
    local cat = math.floor(recvobj.cat or 1) --1:bank 2:upi 3:usdt
    local uid = math.floor(recvobj.uid)
    
    local retobj = {c = math.floor(recvobj.c), code = PDEFINE.RET.SUCCESS, spcode=0, uid=uid}
    local checkList = {}
    if cat == 1 then --bank
        checkList = {
            ['account'] = PDEFINE_ERRCODE.ERROR.DRAW_EMPTY_ACCOUNT,
            ['username'] = PDEFINE_ERRCODE.ERROR.DRAW_EMPTY_USERNAME,
            ['ifsc'] = PDEFINE_ERRCODE.ERROR.DRAW_EMPTY_IFSC,
            ['bankid'] = PDEFINE_ERRCODE.ERROR.DRAW_EMPTY_BANK,
            ['email'] = PDEFINE_ERRCODE.ERROR.DRAW_EMPTY_EMAIL,
        }
    elseif cat == 2 then --upi
        checkList = {
            ['account'] = PDEFINE_ERRCODE.ERROR.DRAW_EMPTY_UPI,
            ['username'] = PDEFINE_ERRCODE.ERROR.DRAW_EMPTY_USERNAME,
            ['phone'] = PDEFINE_ERRCODE.ERROR.DRAW_EMPTY_PHONE,
        }
    elseif cat == 3 then --usdt
        checkList = {
            ['account'] = PDEFINE_ERRCODE.ERROR.DRAW_EMPTY_USDTADDR,
        }
    end
    for key, errCode in pairs(checkList) do
        if isempty(recvobj[key]) then
            retobj.spcode = errCode
            return resp(retobj)
        end
    end

    local account = recvobj.account or ''
    local username = recvobj.username or ''
    local ifsc = recvobj.ifsc or ''
    
    local bankid = recvobj.bankid or 0 --银行id
    local email = recvobj.email or ''
    local phone = recvobj.phone or ''

    local sql = string.format("select count(*) as t from d_user_bank where uid=%d and account='%s'", uid, account)
    local res = skynet.call(".mysqlpool", "lua", "execute", sql)
    if res[1]['t'] > 0 then
        retobj.spcode = PDEFINE_ERRCODE.ERROR.DRAW_ACCOUNT_EXISTS
        return resp(retobj)
    end

    account = mysqlEscapeString(account)
    username = mysqlEscapeString(username)
    ifsc = mysqlEscapeString(ifsc)
    email = mysqlEscapeString(email)
    phone = mysqlEscapeString(phone)
    local bindflag = ''
    if cat == 1 then --bank
        bindflag = 'bindbank'
        local bankname = ''
        sql = string.format("select * from s_bank where id=%d limit 1", bankid)
        local rs = skynet.call(".mysqlpool", "lua", "execute", sql)
        if #rs > 0 then
            bankname = rs[1].title
        end
        sql = string.format("insert into d_user_bank (uid,cat,account,username,ifsc,bankname,email,create_time,status,bankid) values(%d,%d,'%s','%s','%s','%s', '%s',%d,%d,%d)", 
                            uid,cat,account,username, ifsc, bankname, email, os.time(), 1, bankid)
        LOG_INFO("with draw Binkinfo22 sql:", sql)              
    elseif cat == 2 then --upi
        bindflag = 'bindupi'
        sql = string.format("insert into d_user_bank (uid,cat,account,username,ifsc,bankname,phone,create_time,status) values(%d,%d,'%s','%s','%s','%s', '%s',%d,%d)", 
                        uid,cat,account,username, '', '', phone, os.time(), 1)
    elseif cat == 3 then --usdt
        bindflag = 'bindusdt'
        sql = string.format("insert into d_user_bank (uid,cat,account,username,ifsc,bankname,phone,create_time,status) values(%d,%d,'%s','%s','%s','%s', '%s',%d,%d)", uid,cat,account,'', '', '', '', os.time(), 1)
    end
    LOG_INFO("with draw Binkinfo sql:", sql)
    skynet.call(".mysqlpool", "lua", "execute", sql)
    if bindflag ~= '' then
        handle.dcCall("user_dc", "setvalue", uid, bindflag, 1)
    end

    local tbl = getBindInfoList(uid)
    table.merge(retobj, tbl)
    return resp(retobj)
end

local function doDrawJob(uid, coin, bankinfo)
    return cs(
        function()
            local dcoin = getDrawCoin(uid)
            if dcoin < coin then
                return PDEFINE_ERRCODE.ERROR.DRAW_COIN_NOT_ENOUGH --金币不足
            end
            local addCoin = -coin
            local code, beforecoin, aftercoin = player_tool.funcAddCoin(uid, addCoin, "提现", PDEFINE.ALTERCOINTAG.DOWN, PDEFINE.GAME_TYPE.SPECIAL.DRAW_COIN, PDEFINE.POOL_TYPE.none, nil, nil)
            if code == PDEFINE.RET.SUCCESS then
                handle.dcCall("user_dc", "user_addvalue", uid, "totaldraw", coin)
                local sql = string.format("insert into d_user_draw (uid,cat,bankid,userbankid,account,create_time,coin,status) values(%d, %d, %d,%d,'%s', %d, %d, %d)", 
                                    uid,bankinfo.cat,bankinfo.id, bankinfo.bankid, bankinfo.account, os.time(), coin, 0)
                LOG_INFO(" draw log sql:", sql)
                skynet.call(".mysqlpool", "lua", "execute", sql)
                return PDEFINE.RET.SUCCESS
            end
            return code
        end)
end

--! 提交取现
function cmd.draw(msg)
    local recvobj = cjson.decode(msg)
    local cat = math.floor(recvobj.cat or 1) --1:bank 2:upi 3:usdt
    local uid = math.floor(recvobj.uid)
    local coin = math.floor(recvobj.coin or 0) --操作金币
    local bankid = math.floor(recvobj.bankid or 0) --用户银行账号信息id
    
    local retobj = {c = math.floor(recvobj.c), code = PDEFINE.RET.SUCCESS, spcode=0, uid=uid}
    if coin <= 0 then
        retobj.spcode = PDEFINE_ERRCODE.ERROR.DRAW_ERR_PARAM_COIN
        return resp(retobj)
    end

    local dcoin = getDrawCoin(uid)
    if dcoin < coin then
        retobj.spcode = PDEFINE_ERRCODE.ERROR.COIN_NOT_ENOUGH --可提现金币不足
        return resp(retobj)
    end

    local sql = string.format("select * from d_user_bank where id=%d and uid=%d", bankid, uid)
    local ret = skynet.call(".mysqlpool", "lua", "execute", sql)
    if ret==nil or ret[1] == nil then
        retobj.spcode = PDEFINE_ERRCODE.ERROR.DRAW_ERR_BANKINFO --账户信息
        return resp(retobj)
    end

    local errCode = doDrawJob(uid, coin, ret[1])
    if errCode ~= PDEFINE.RET.SUCCESS then
        retobj.spcode = errCode
        return resp(retobj)
    end
    local playerInfo = player_tool.getPlayerInfo(uid)
    retobj.coin = playerInfo.coin
    retobj.dcoin = getDrawCoin(uid)

    return resp(retobj)
end

--! 操作历史记录
function cmd.histroy(msg)
    local recvobj = cjson.decode(msg)
    local uid = recvobj.uid
    local ctype = math.floor(recvobj.cat or 1) --1:pay 2:操作
    local retobj= {c=math.floor(recvobj.c), code= PDEFINE.RET.SUCCESS, spcode = 0, cat=ctype, dataList = {}}
    
    if ctype == 2 then
        local sql = string.format("select * from d_user_draw where uid=%d order by id desc limit 50", uid)
        local datalist = skynet.call(".mysqlpool", "lua", "execute", sql)
        for _, row in pairs(datalist) do
            local item = {
                ['id'] = row['id'],
                ['coin'] = row['coin'],
                ['create_time'] = row['create_time'],
                ['status'] = row['status'] 
            }
            table.insert(retobj.dataList, item)
        end
    else 
        local sql = string.format("select * from d_user_recharge where uid=%d order by id desc limit 50", uid)
        local datalist = skynet.call(".mysqlpool", "lua", "execute", sql)
        for _, row in pairs(datalist) do
            local item = {
                ['id'] = row['id'],
                ['coin'] = row['count'],
                ['type'] = row['goodstype'],
                ['create_time'] = row['create_time'],
                ['status'] = row['status'] 
            }
            table.insert(retobj.dataList, item)
        end
    end
    return resp(retobj)
end

--! 绑定银行的银行列表
function cmd.banklist(msg)
    local recvobj = cjson.decode(msg)
    local uid = recvobj.uid
    local retobj= {c=math.floor(recvobj.c), code= PDEFINE.RET.SUCCESS, spcode = 0, dataList = {}}

    local sql = string.format("select id,title from s_bank where status=1 order by id desc", uid)
    local datalist = skynet.call(".mysqlpool", "lua", "execute", sql)
    for _, row in pairs(datalist) do
        local item = {
            ['id'] = row['id'],
            ['title'] = row['title'],
        }
        table.insert(retobj.dataList, item)
    end

    return resp(retobj)
end

return cmd