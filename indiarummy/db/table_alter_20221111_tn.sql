-- 赛事表记录
DROP TABLE IF EXISTS `d_tn_stat`;
CREATE TABLE `d_tn_stat` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `tn_id` int(11) DEFAULT '0' COMMENT '赛事id',
  `gameid` int(11) DEFAULT NULL COMMENT '游戏id',
  `start_time` int(11) DEFAULT NULL COMMENT '开始时间',
  `stop_time` int(11) DEFAULT NULL COMMENT '结束时间',
  `buy_in` int(11) DEFAULT NULL COMMENT '报名金币',
  `rewardscoin` decimal(20,2) DEFAULT NULL COMMENT '总奖金',
  `enrolcount` int(11) DEFAULT NULL COMMENT '报名人数',
  `exitcount` int(11) DEFAULT NULL COMMENT '退费人数',
  `create_time` int(11) DEFAULT '0' COMMENT '赛事时间戳',
  PRIMARY KEY (`id`),
  KEY `time` (`create_time`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

-- 排行榜记录
DROP TABLE IF EXISTS `d_lb_log`;
CREATE TABLE `d_lb_log` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `uid` int(11) DEFAULT NULL COMMENT 'uid',
  `playername` varchar(255) COLLATE utf8mb4_bin DEFAULT NULL COMMENT '昵称',
  `usericon` varchar(255) COLLATE utf8mb4_bin DEFAULT NULL COMMENT '头像',
  `rtype` tinyint(1) DEFAULT NULL COMMENT '榜单类型',
  `score` int(11) DEFAULT NULL COMMENT '积分',
  `ord` int(11) DEFAULT NULL COMMENT '排名',
  `reward_coin` int(11) DEFAULT NULL COMMENT '奖励金币',
  `create_time` int(11) DEFAULT NULL COMMENT '创建时间',
  `settle_time` int(11) DEFAULT NULL COMMENT '结算时间',
  PRIMARY KEY (`id`),
  KEY uid (`uid`),
  KEY time (`settle_time`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin COMMENT='排行榜结算记录';