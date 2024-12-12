--商品列表管理
local skynet = require "skynet"
require "skynet.manager"
local cluster = require "cluster"
local snax = require "snax"
local cjson   = require "cjson"

local shop_type_list     = {}
local review_shop_type_list = {}
local CMD = {}

--初始化商品列表 保持数据库中的结构，只是存储在内存中按类型分组
local function initShopList(isReview)
    local tmp_list = {}
    local sql = "select * from s_shop where `status`=1 order by id desc"
    if isReview then
        sql = "select * from s_shop_tishen where `status`=1 order by id desc"
    end
    local rs = skynet.call(".mysqlpool", "lua", "execute", sql)
    if #rs > 0 then
        for _, row in pairs(rs) do
            local stype = row.stype
            if nil == tmp_list[stype] then
                tmp_list[stype] = {}
            end
            table.insert(tmp_list[row["stype"]], row)
        end
    end
    if isReview then
        review_shop_type_list = tmp_list
    else
        shop_type_list = tmp_list
    end
end

--按照类型获取商品列表 或 获取总的列表
function CMD.getShopList(stype, isReview)
    if isReview then --提审
        if table.empty(review_shop_type_list) then
            initShopList(true)
        end
        if nil ~= stype and nil ~= review_shop_type_list[stype] then
            return review_shop_type_list[stype]
        end
        return review_shop_type_list
    end

    if table.empty(shop_type_list) then
        initShopList()
    end
    if nil ~= stype and nil ~= shop_type_list[stype] then
        return shop_type_list[stype]
    end
    return shop_type_list
end

function CMD.start()
    if table.empty(shop_type_list) then
        initShopList()
    end
    if table.empty(review_shop_type_list) then
        initShopList(true)
    end
end

--重新加载商品列表
function CMD.reload()
    initShopList()
    initShopList(true)
end

skynet.start(function()
	skynet.dispatch("lua", function(session, address, cmd, ...)
		local f = CMD[cmd]
		skynet.retpack(f(...))
	end)
	skynet.register(".shopmgr")
end)