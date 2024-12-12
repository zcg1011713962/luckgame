-- 锦标赛场次信息
DROP TABLE IF EXISTS `d_tn_config`;
CREATE TABLE `d_tn_config` (
    `id` int(11) NOT NULL AUTO_INCREMENT,
    `gameid` int(11) DEFAULT NULL COMMENT '游戏id',
    `buy_in` decimal(10,2) DEFAULT 0 COMMENT '报名金币',
    `min_cnt` int(11) DEFAULT 0 COMMENT '最少开始人数',
    `max_cnt` int(11) DEFAULT 0 COMMENT '最大报名人数',
    `start_time` int(4) NOT NULL COMMENT '开始时间,eg 1310',
    `stop_time` int(4) NOT NULL COMMENT '结束时间, eg 1340',
    `ahead_time` int(11) NOT NULL COMMENT '可提前进入的时间(s)',
    `deadline_time` int(11) NOT NULL COMMENT '截止进入的时间(s)',
    `bet` int(11) DEFAULT 0 COMMENT '下注额',
    `init_coin` decimal(10,2) DEFAULT 0 COMMENT '比赛初始金币',
    `pool_rate`  int(4) DEFAULT 0 COMMENT '报名金币投入百分比',
    `update_time` int(11) DEFAULT NULL COMMENT '更新时间',
    `create_time` int(11) DEFAULT NULL COMMENT '创建时间',
    PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='锦标赛配置表';

-- 锦标赛报名记录表
DROP TABLE IF EXISTS `d_tn_register`;
CREATE TABLE `d_tn_register` (
    `id` int(11) NOT NULL AUTO_INCREMENT,
    `tn_id` int(11) DEFAULT NULL COMMENT '锦标赛id',
    `date` date NOT NULl COMMENT '日期',
    `uid` int(11) DEFAULT NULL COMMENT 'uid',
    `coin` decimal(10,2) DEFAULT 0 COMMENT '报名金币',
    `status` int(4) DEFAULT 1 COMMENT '状态: 1=已报名,2=已取消,3=已消费,4=已退款',
    `update_time` int(11) DEFAULT NULL COMMENT '更新时间',
    `create_time` int(11) DEFAULT NULL COMMENT '创建时间',
    PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='锦标赛报名表';

-- 锦标赛结算记录表
DROP TABLE IF EXISTS `d_tn_result`;
CREATE TABLE `d_tn_result` (
    `id` int(11) NOT NULL AUTO_INCREMENT,
    `tn_id` int(11) DEFAULT NULL COMMENT '锦标赛id',
    `date` date NOT NULl COMMENT '日期',
    `uid` int(11) DEFAULT NULL COMMENT 'uid',
    `ord`  int(4) DEFAULT 0 COMMENT '获得名次',
    `settle_coin` decimal(10,2) DEFAULT 0 COMMENT '结算时金币',
    `reward_coin` decimal(10,2) DEFAULT 0 COMMENT '获得奖励金币',
    `total_coin` decimal(10,2) DEFAULT 0 COMMENT '奖池总金币',
    `status` int(4) DEFAULT 1 COMMENT '状态: 1=正常结束,2=已放弃, 3=已退款',
    `create_time` int(11) DEFAULT NULL COMMENT '创建时间',
    PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='锦标赛结果表';

TRUNCATE TABLE `d_tn_config`;
INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
                    VALUES(1,  293,    10,     3,       30,      '17:00',      '17:30',     180,        900,           2,   100,       70,        1666841089,  1666841089);
INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
                    VALUES(2,  293,    20,     3,       30,      '17:40',      '18:10',     180,        900,           4,   200,       70,        1666841089,  1666841089);
INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
                    VALUES(3,  293,    30,     3,       30,      '18:20',      '18:50',     180,        900,           6,   300,       70,        1666841089,  1666841089);