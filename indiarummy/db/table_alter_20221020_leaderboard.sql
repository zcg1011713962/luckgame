-- 排位赛报名以及奖励表
DROP TABLE IF EXISTS `d_lb_register`;
CREATE TABLE `d_lb_register` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `rtype` int(11) DEFAULT 1 COMMENT '类型 1:日榜 2:周榜 3:月榜 4:代理榜',
  `uid` int(11) DEFAULT NULL,
  `coin` decimal(10,2) DEFAULT 0 COMMENT '报名金币',
  `own_coin` decimal(10,2) DEFAULT 0 COMMENT '拥有的金币',
  `create_time` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `uid` (`uid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='排行榜报名表';

DROP TABLE IF EXISTS `d_lb_reward_log`;
CREATE TABLE `d_lb_reward_log` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `rtype` int(11) DEFAULT 1 COMMENT '类型 1:日榜 2:周榜 3:月榜',
  `uid` int(11) DEFAULT NULL,
  `settle_date` date DEFAULT NULL COMMENT '结算日期',
  `ord`  int(4) DEFAULT 0 COMMENT '获得名次',
  `coin` decimal(10,2) DEFAULT 0 COMMENT '报名金币',
  `score` int(11) DEFAULT 0 COMMENT '结算分数',
  `reward_coin` decimal(10,2) DEFAULT 0 COMMENT '奖励的金币',
  `create_time` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `uid` (`uid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='排行榜奖励记录';

-- 奖励配置表
DROP TABLE IF EXISTS `d_lb_reward_config`;
CREATE TABLE `d_lb_reward_config` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `rtype` int(11) DEFAULT 1 COMMENT '类型 1:日榜 2:周榜 3:月榜',
  `l_ord` int(11) DEFAULT NULL COMMENT '奖励名次(左区间)',
  `r_ord` int(11) DEFAULT NULL COMMENT '奖励名次(右区间)',
  `total` decimal(10,2) DEFAULT 0 COMMENT '奖励总额',
  `coin`  decimal(10,2) DEFAULT 0 COMMENT '奖励金币',
  PRIMARY KEY (`id`),
  KEY `rtype` (`rtype`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='排行榜奖励配置';

-- 基础配置
INSERT INTO `s_config` (id, k, v, memo) VALUES (60, 'leaderboard', v='[{"rtype":1,"limit":500,"register":1},{"rtype":1,"limit":500,"register":1},{"rtype":1,"limit":500,"register":1}]', '排行榜配置信息');
insert into `s_config` (id, k, v, memo) values (61, 'charmpack', 100, '新手大礼包金币数')

-- 奖励配置
TRUNCATE TABLE `d_lb_reward_config`;
-- 日榜
INSERT INTO `d_lb_reward_config` VALUES(NULL, 1, 1,  1,  20000, 5000);
INSERT INTO `d_lb_reward_config` VALUES(NULL, 1, 2,  2,  20000, 4000);
INSERT INTO `d_lb_reward_config` VALUES(NULL, 1, 3,  3,  20000, 3000);
INSERT INTO `d_lb_reward_config` VALUES(NULL, 1, 4,  4,  20000, 2000);
INSERT INTO `d_lb_reward_config` VALUES(NULL, 1, 5,  5,  20000, 1500);
INSERT INTO `d_lb_reward_config` VALUES(NULL, 1, 6,  6,  20000, 1250);
INSERT INTO `d_lb_reward_config` VALUES(NULL, 1, 7,  7,  20000, 1100);
INSERT INTO `d_lb_reward_config` VALUES(NULL, 1, 8,  8,  20000,  900);
INSERT INTO `d_lb_reward_config` VALUES(NULL, 1, 9,  9,  20000,  750);
INSERT INTO `d_lb_reward_config` VALUES(NULL, 1, 10, 10, 20000,  500);
-- 周榜
INSERT INTO `d_lb_reward_config` VALUES(NULL, 2, 1,  1,  75000, 10000);
INSERT INTO `d_lb_reward_config` VALUES(NULL, 2, 2,  2,  75000,  7600);
INSERT INTO `d_lb_reward_config` VALUES(NULL, 2, 3,  3,  75000,  5000);
INSERT INTO `d_lb_reward_config` VALUES(NULL, 2, 4,  4,  75000,  3500);
INSERT INTO `d_lb_reward_config` VALUES(NULL, 2, 5,  5,  75000,  3000);
INSERT INTO `d_lb_reward_config` VALUES(NULL, 2, 6,  10, 75000,  2000);
INSERT INTO `d_lb_reward_config` VALUES(NULL, 2, 11, 15, 75000,  1200);
INSERT INTO `d_lb_reward_config` VALUES(NULL, 2, 16, 25, 75000,  1000);
INSERT INTO `d_lb_reward_config` VALUES(NULL, 2, 26, 50, 75000,   800);
-- 月榜
INSERT INTO `d_lb_reward_config` VALUES(NULL, 3, 1,   1,    200000, 20000);
INSERT INTO `d_lb_reward_config` VALUES(NULL, 3, 2,   2,    200000, 15000);
INSERT INTO `d_lb_reward_config` VALUES(NULL, 3, 3,   3,    200000, 12000);
INSERT INTO `d_lb_reward_config` VALUES(NULL, 3, 4,   4,    200000, 10000);
INSERT INTO `d_lb_reward_config` VALUES(NULL, 3, 5,   5,    200000,  8000);
INSERT INTO `d_lb_reward_config` VALUES(NULL, 3, 6,   6,    200000,  6000);
INSERT INTO `d_lb_reward_config` VALUES(NULL, 3, 7,   7,    200000,  4000);
INSERT INTO `d_lb_reward_config` VALUES(NULL, 3, 8,   8,    200000,  3000);
INSERT INTO `d_lb_reward_config` VALUES(NULL, 3, 9,   9,    200000,  2500);
INSERT INTO `d_lb_reward_config` VALUES(NULL, 3, 10,  10,   200000,  2000);
INSERT INTO `d_lb_reward_config` VALUES(NULL, 3, 11,  100,  200000,   500);
INSERT INTO `d_lb_reward_config` VALUES(NULL, 3, 101, 500,  200000,   150);
INSERT INTO `d_lb_reward_config` VALUES(NULL, 3, 501, 1000, 200000,    25);
