local skynet = require "skynet"
local db = {}  -- 用来访问数据库

------------------------------
--- db 对象用来访问数据库
------------------------------

-- 获取随机俱乐部
function db.getRandClubList(limit, name)
    if not limit then
        limit = 10
    end
    local sql
    if name then
        sql = string.format([[
        select * from d_club
        where name like '%%%s%%' and join_type <> 2 limit %d]], name, limit)
    else
        sql = string.format("select * from d_club order by rand() limit %d", limit)
    end
    local rs = skynet.call(".mysqlpool", "lua", "execute", sql)
    if not rs or #rs == 0 then
        return {}
    end
    return rs
end

-- 获取积分排行榜
function db.getScoreRank(page, limit)
    if not limit then
        limit = 20
    end
    if not page then
        page = 1
    end
    local sql = string.format("select * from d_club order by score desc limit %d offset %d", limit, (page-1)*limit)
    local rs = skynet.call(".mysqlpool", "lua", "execute", sql)
    if not rs or #rs == 0 then
        return {}
    end
    return rs
end

-- 获取某一个俱乐部详情
function db.getClubById(cid)
    if not cid then
        return nil
    end
    local sql = string.format("select * from d_club where cid = %d", cid)
    local rs = skynet.call(".mysqlpool", "lua", "execute", sql)
    if not rs or #rs == 0 then
        return {}
    end
    return rs[1]
end

-- 通过玩家获取所在俱乐部信息
function db.getClubByUid(uid)
    if not uid then
        return nil
    end
    local sql = string.format("select dc.*, dcm.level from d_club_member dcm inner join d_club dc on dcm.cid = dc.cid where dcm.uid = %d", uid)
    local rs = skynet.call(".mysqlpool", "lua", "execute", sql)
    if not rs or #rs == 0 then
        return {}
    end
    return rs[1]
end

-- 获取一个俱乐部的所有人
function db.getClubMember(cid, name, page, limit)
    if not limit then
        limit = 20
    end
    if not page then
        page = 1
    end
    local sql = string.format("select * from d_club_member where cid = %d limit %d offset %d", cid, limit, (page-1)*limit)
    if name then
        sql = string.format([[
            select * from d_club_member dcm 
            inner join d_user du on dcm.uid=du.uid
            where dcm.cid = %d and du.name like %%%s%% limit %d offset %d]], cid, name, limit, (page-1)*limit
        )
    else
        sql = string.format("select * from d_club_member where cid = %d limit %d offset %d", cid, limit, (page-1)*limit)
    end
    local rs = skynet.call(".mysqlpool", "lua", "execute", sql)
    if not rs or #rs == 0 then
        return {}
    end
    return rs
end

-- 获取俱乐部中所有人的uid
function db.getClubAllUid(cid)
    local sql = string.format("select uid from d_club_member where cid = %d", cid)
    local rs = skynet.call(".mysqlpool", "lua", "execute", sql)
    if not rs or #rs == 0 then
        return {}
    end
    return rs
end

-- 找到某个等级的成员
function db.getClubManager(cid, level)
    local sql = string.format("select uid from d_club_member where cid = %d and level=%d", cid, level)
    local rs = skynet.call(".mysqlpool", "lua", "execute", sql)
    if not rs or #rs == 0 then
        return {}
    end
    return rs
end

-- 获取俱乐部人数
function db.getClubLength(cid)
    local sql = string.format("select count(*) as cnt from d_club_member where cid = %d", cid)
    local rs = skynet.call(".mysqlpool", "lua", "execute", sql)
    if not rs or #rs == 0 then
        return 0
    end
    return rs[1]['cnt']
end

-- 获取一个俱乐部指定人的信息
function db.getClubMemberByUid(cid, uid)
    if not cid or not uid then
        return nil
    end
    local sql = string.format("select * from d_club_member where cid = %d and uid = %d", cid, uid)
    local rs = skynet.call(".mysqlpool", "lua", "execute", sql)
    if not rs or #rs == 0 then
        return nil
    end
    return rs[1]
end

-- 创建一个俱乐部
function db.createClub(cid, uid, name, avatar, detail, join_type, cap)
    local sql = string.format([[
        insert into d_club 
            (cid, name, avatar, detail, uid, create_time, join_type, cap)
        values
            (%d, '%s', '%s', '%s', %d, %d, %d, %d)
    ]], cid, name, avatar, detail, uid, os.time(), join_type, cap)
    LOG_DEBUG("createClub sql: ", sql)
    local rs = skynet.call(".mysqlpool", "lua", "execute", sql, true)
    if not rs then
        LOG_DEBUG("create club err: ", sql)
        return nil
    end
    return true
end

-- 修改一个俱乐部
function db.modifyClub(cid, name, avatar, detail, join_type, cap)
    local sql = "update d_club set "
    if name then
        sql = sql.."name='"..name.."',"
    end
    if avatar then
        sql = sql.."avatar='"..avatar.."',"
    end
    if detail then
        sql = sql.."detail='"..detail.."',"
    end
    if join_type then
        sql = sql.."join_type="..join_type..","
    end
    if cap then
        sql = sql.."cap="..cap..","
    end
    -- 加一个 member_cnt 防止都为空
    sql = sql.."member_cnt=member_cnt where cid="..cid
    local rs = skynet.call(".mysqlpool", "lua", "execute", sql, true)
    if not rs then
        return nil
    end
    return true
end

-- 加入一个俱乐部
function db.joinClub(cid, uid, level)
    if not level then
        level = 0
    end
    local sql = string.format([[
        insert into d_club_member
            (cid, uid, join_time, level, score)
        values
            (%d, %d, %d, %d, 0)
    ]], cid, uid, os.time(), level)
    local rs = skynet.call(".mysqlpool", "lua", "execute", sql, true)
    if not rs then
        return nil
    end
    -- 更新俱乐部人数信息
    local updateSql = string.format("update d_club set member_cnt=(select count(*) from d_club_member where cid=%d) where cid=%d", cid, cid)
    skynet.call(".mysqlpool", "lua", "execute", updateSql, true)
    return true
end

-- 从俱乐部剔除用户
function db.deleteFromClub(cid, uid)
    if not cid or not uid then
        return nil
    end
    local sql = string.format([[
        delete from d_club_member where cid = %d and uid = %d
    ]], cid, uid)
    local rs = skynet.call(".mysqlpool", "lua", "execute", sql, true)
    if not rs then
        return nil
    end
    -- 更新俱乐部人数信息
    local updateSql = string.format("update d_club set member_cnt=(select count(*) from d_club_member where cid=%d) where cid=%d",cid, cid)
    skynet.call(".mysqlpool", "lua", "execute", updateSql, true)
    return true
end

-- 删除俱乐部
function db.deleteClub(cid, uid)
    if not cid or not uid then
        return nil
    end
    local d_user_sql = string.format([[
        delete from d_club_member where cid = %d
    ]], cid, uid)
    local d_user_rs = skynet.call(".mysqlpool", "lua", "execute", d_user_sql, true)
    if not d_user_rs then
        return nil
    end
    local d_club_sql = string.format([[
        delete from d_club where cid = %d
    ]], cid, uid)
    local d_club_rs = skynet.call(".mysqlpool", "lua", "execute", d_club_sql, true)
    if not d_club_rs then
        return nil
    end
    return true
end

-- 增加俱乐部积分
function db.increaseScore(cid, uid, score)
    if not cid or not score or not uid then
        return nil
    end
    local updateUserScoreSql = string.format("update d_club_member set score=score+%d where cid=%d and uid=%d", score, cid, uid)
    local rs = skynet.call(".mysqlpool", "lua", "execute", updateUserScoreSql, true)
    if not rs then
        return nil
    end
    local updateClubScoreSql = string.format("update d_club set score=score+%d where cid=%d", score, cid)
    local rs = skynet.call(".mysqlpool", "lua", "execute", updateClubScoreSql, true)
    if not rs then
        return nil
    end
    return true
end

-- 刷新所有积分，重新开始
function db.refreshScore()
    local sql = "update d_club set his_score=score, score=0 where 1=1"
    local rs = skynet.call(".mysqlpool", "lua", "execute", sql, true)
    if not rs then
        return nil
    end
    sql = "update d_club_member set score=0 where 1=1"
    rs = skynet.call(".mysqlpool", "lua", "execute", sql, true)
    if not rs then
        return nil
    end
    return true
end

return db