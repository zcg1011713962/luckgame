local cfg = {}

-- 俱乐部加入方式
cfg.ClubType = {
    Apply = 1,  -- 申请加入
    Forbid = 2,  -- 不允许加入, 这里如果更改，需要更改 club_db中推荐sql，里面写死了不显示2
    Direct = 3,  -- 直接加入
}

-- 俱乐部容量选项
cfg.ClubCapacity = {
    [1] = 50,
    [2] = 100,
    [3] = 200
}

-- 俱乐部职位
cfg.ClubMemberLevel = {
    Common = 0,  -- 普通成员

    
    Owner = 10,  -- 所有者
}

return cfg