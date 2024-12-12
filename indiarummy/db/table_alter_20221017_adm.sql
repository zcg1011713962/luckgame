DROP TABLE IF EXISTS `s_config_maintask_type`;
CREATE TABLE `s_config_maintask_type` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `title` varchar(255) COLLATE utf8mb4_bin DEFAULT NULL COMMENT '标题',
  `status` tinyint(1) DEFAULT '1',
  `ord` int(11) DEFAULT NULL COMMENT '排序，越小越靠前',
  `uid` int(11) DEFAULT NULL,
  `create_time` int(11) DEFAULT NULL,
  `uuid` int(11) DEFAULT NULL,
  `update_time` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=5 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin COMMENT='主线任务类型';

INSERT INTO `s_config_maintask_type` VALUES (11,'充值任务',1,1,NULL,NULL,NULL,NULL),(22,'游戏任务',1,4,NULL,NULL,NULL,NULL),(23,'盈利任务',1,3,NULL,NULL,NULL,NULL),(33,'下注任务',1,2,NULL,NULL,NULL,NULL);

DROP TABLE IF EXISTS `s_config_maintask`;
CREATE TABLE `s_config_maintask` (
  `id` int(11) NOT NULL AUTO_INCREMENT COMMENT 'id',
  `type` int(11) DEFAULT NULL COMMENT '任务类型',
  `title` varchar(255) COLLATE utf8mb4_bin DEFAULT NULL COMMENT '任务标题',
  `title_en` varchar(255) COLLATE utf8mb4_bin DEFAULT NULL COMMENT '任务标题英文',
  `preid` int(11) DEFAULT NULL COMMENT '同类型上一个任务',
  `param1` int(11) DEFAULT NULL COMMENT '完成任务需要达到的值',
  `rewards` varchar(255) COLLATE utf8mb4_bin DEFAULT NULL COMMENT '完成任务可以获得的奖励',
  `ord` int(11) DEFAULT NULL COMMENT '排序',
  `uid` int(11) DEFAULT NULL,
  `create_time` int(11) DEFAULT NULL,
  `uuid` int(11) DEFAULT NULL,
  `update_time` int(11) DEFAULT NULL,
  `gameids` varchar(255) COLLATE utf8mb4_bin DEFAULT NULL COMMENT '游戏id列表',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=7 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

ALTER TABLE `d_main_task` 
ADD COLUMN `update_time` int(11) NULL COMMENT '修改时间' AFTER `vipstate`;

DROP TABLE IF EXISTS `d_user_vip_bonus`;
CREATE TABLE `d_user_vip_bonus` (
  `id` int(11) NOT NULL,
  `uid` bigint(20) DEFAULT NULL COMMENT 'uid',
  `svip` int(11) DEFAULT NULL,
  `type` tinyint(1) DEFAULT NULL COMMENT '1:签到2:周 3:月 4:达到',
  `update_time` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idxuid` (`uid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin COMMENT='用户vipbonus记录';

insert into s_config(k,v) value ('worldchat','');

DROP TABLE IF EXISTS `s_chat_pics`;
CREATE TABLE `s_chat_pics` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `img` varchar(255) COLLATE utf8mb4_bin DEFAULT NULL COMMENT '图片',
  `title` varchar(255) COLLATE utf8mb4_bin DEFAULT NULL,
  `status` tinyint(1) DEFAULT NULL,
  `cat` tinyint(1) DEFAULT NULL COMMENT '1:图片生效2：文档生效',
  `uid` int(11) DEFAULT NULL,
  `create_time` int(11) DEFAULT NULL,
  `uuid` int(11) DEFAULT NULL,
  `update_time` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin COMMENT='世界聊天置顶广告';

update s_config set v='{"invite":{"coin":50,"rate":"0.2:0:0.8"},"recharge":{"rrate1":0.05,"rate1":"0.2:0:0.8","rrate2":0.02,"rate2":"0.2:0:0.8"},"bet":{"rrate1":0.05,"rate1":"0.2:0:0.8","rrate2":0.02,"rate2":"0.2:0:0.8"}}' where k='invite';

ALTER TABLE `d_desk_user` ADD INDEX `idxtime`(`create_time`);
truncate table d_desk_user;

DROP TABLE IF EXISTS `d_rake_back`;
CREATE TABLE `d_rake_back` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `uid` bigint(20) DEFAULT '0' COMMENT 'uid',
  `gameid` int(11) DEFAULT NULL COMMENT '游戏id',
  `bet` decimal(20,2) DEFAULT NULL COMMENT '下注',
  `wincoin` decimal(20,2) DEFAULT NULL COMMENT '赢钱',
  `state` tinyint(1) DEFAULT '1' COMMENT '1:待领取 2已领取 3:过期作废',
  `create_time` int(11) DEFAULT '0',
  `update_time` int(11) DEFAULT NULL,
  `rate` float(3,2) DEFAULT NULL COMMENT '返水比例',
  `backcoin` decimal(20,2) DEFAULT NULL COMMENT '返水金额',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin COMMENT='下级返水的游戏记录';

ALTER TABLE `s_pay_cfg_drawrate` 
ADD COLUMN `status` tinyint(1) NULL COMMENT '1开启0关闭' AFTER `uuid`;

DROP TABLE IF EXISTS `s_pay_cfg_drawlimit`;
CREATE TABLE `s_pay_cfg_drawlimit` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `useruid` bigint(20) DEFAULT NULL COMMENT '用户编号',
  `maxcoin` bigint(20) DEFAULT '0' COMMENT '最大金额',
  `mincoin` bigint(20) DEFAULT NULL COMMENT '最小金额',
  `times` int(11) DEFAULT NULL COMMENT '次数',
  `interval` int(11) DEFAULT NULL COMMENT '间隔分钟',
  `cat` int(11) DEFAULT '1' COMMENT '钱包类型1账户 3usdt',
  `svip` varchar(1000) COLLATE utf8mb4_bin DEFAULT NULL COMMENT '支付等级',
  `superuid` int(11) DEFAULT NULL COMMENT '上级uid',
  `memo` varchar(255) COLLATE utf8mb4_bin DEFAULT NULL COMMENT '备注',
  `uid` int(11) DEFAULT NULL,
  `create_time` int(11) DEFAULT NULL,
  `update_time` int(11) DEFAULT NULL,
  `uuid` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

DROP TABLE IF EXISTS `s_sess`;
CREATE TABLE `s_sess` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `gameid` int(11) NOT NULL DEFAULT '0' COMMENT '游戏id',
  `title` varchar(128) DEFAULT NULL COMMENT '场次名称',
  `basecoin` decimal(10,2) DEFAULT '0.00' COMMENT '底分',
  `mincoin` decimal(20,2) DEFAULT '0.00' COMMENT '最低入场',
  `maxcoin` decimal(20,2) DEFAULT '0.00' COMMENT '最大入场',
  `status` tinyint(1) DEFAULT '1' COMMENT '1正常开放 0关闭',
  `ord` int(11) DEFAULT '1' COMMENT '排序',
  `param1` decimal(10,2) DEFAULT '0.00' COMMENT '小盲/teenpatti最大下注/21点最小下注',
  `param2` decimal(10,2) DEFAULT '0.00' COMMENT '大盲/teenpatti最大总下注/21点最大下注',
  `param3` decimal(10,2) DEFAULT '0.00' COMMENT '扩充字段3',
  `param4` decimal(10,2) DEFAULT '0.00',
  PRIMARY KEY (`id`,`gameid`),
  KEY `idx_game` (`gameid`)
) ENGINE=InnoDB AUTO_INCREMENT=673 DEFAULT CHARSET=utf8mb4 ROW_FORMAT=DYNAMIC COMMENT='游戏场次信息表';

INSERT INTO `s_sess` (`id`, `gameid`, `title`, `basecoin`, `mincoin`, `maxcoin`, `status`, `ord`, `param1`, `param2`, `param3`, `param4`) VALUES (1, 293, 'TexasHoldem', 1.00, 1.00, 100.00, 1, 1, 0.10, 0.20, 0.00, 0.00);
INSERT INTO `s_sess` (`id`, `gameid`, `title`, `basecoin`, `mincoin`, `maxcoin`, `status`, `ord`, `param1`, `param2`, `param3`, `param4`) VALUES (2, 293, 'TexasHoldem', 1.00, 10.00, 1000.00, 0, 2, 0.25, 0.50, 0.00, 0.00);
INSERT INTO `s_sess` (`id`, `gameid`, `title`, `basecoin`, `mincoin`, `maxcoin`, `status`, `ord`, `param1`, `param2`, `param3`, `param4`) VALUES (3, 293, 'TexasHoldem', 1.00, 50.00, 5000.00, 1, 3, 1.00, 2.00, 0.00, 0.00);
INSERT INTO `s_sess` (`id`, `gameid`, `title`, `basecoin`, `mincoin`, `maxcoin`, `status`, `ord`, `param1`, `param2`, `param3`, `param4`) VALUES (4, 293, 'TexasHoldem', 1.00, 200.00, 20000.00, 0, 4, 10.00, 20.00, 0.00, 0.00);
INSERT INTO `s_sess` (`id`, `gameid`, `title`, `basecoin`, `mincoin`, `maxcoin`, `status`, `ord`, `param1`, `param2`, `param3`, `param4`) VALUES (5, 293, 'TexasHoldem', 1.00, 1000.00, 100000.00, 1, 5, 25.00, 50.00, 0.00, 0.00);
INSERT INTO `s_sess` (`id`, `gameid`, `title`, `basecoin`, `mincoin`, `maxcoin`, `status`, `ord`, `param1`, `param2`, `param3`, `param4`) VALUES (6, 293, 'TexasHoldem', 1.00, 2000.00, 200000.00, 0, 6, 50.00, 100.00, 0.00, 0.00);
INSERT INTO `s_sess` (`id`, `gameid`, `title`, `basecoin`, `mincoin`, `maxcoin`, `status`, `ord`, `param1`, `param2`, `param3`, `param4`) VALUES (7, 293, 'TexasHoldem', 1.00, 3000.00, 300000.00, 1, 7, 100.00, 200.00, 0.00, 0.00);
INSERT INTO `s_sess` (`id`, `gameid`, `title`, `basecoin`, `mincoin`, `maxcoin`, `status`, `ord`, `param1`, `param2`, `param3`, `param4`) VALUES (8, 293, 'TexasHoldem', 1.00, 10000.00, 1000000.00, 0, 8, 250.00, 500.00, 0.00, 0.00);
INSERT INTO `s_sess` (`id`, `gameid`, `title`, `basecoin`, `mincoin`, `maxcoin`, `status`, `ord`, `param1`, `param2`, `param3`, `param4`) VALUES (9, 293, 'TexasHoldem', 1.00, 20000.00, 2000000.00, 0, 9, 500.00, 1000.00, 0.00, 0.00);
INSERT INTO `s_sess` (`id`, `gameid`, `title`, `basecoin`, `mincoin`, `maxcoin`, `status`, `ord`, `param1`, `param2`, `param3`, `param4`) VALUES (10, 293, 'TexasHoldem', 1.00, 40000.00, -1.00, 0, 10, 1000.00, 2000.00, 0.00, 0.00);
INSERT INTO `s_sess` (`id`, `gameid`, `title`, `basecoin`, `mincoin`, `maxcoin`, `status`, `ord`, `param1`, `param2`, `param3`, `param4`) VALUES (11, 265, 'dominuo', 0.10, 1.00, 100.00, 1, 1, 0.00, 0.00, 0.00, 0.00);
INSERT INTO `s_sess` (`id`, `gameid`, `title`, `basecoin`, `mincoin`, `maxcoin`, `status`, `ord`, `param1`, `param2`, `param3`, `param4`) VALUES (12, 265, 'dominuo', 5.00, 30.00, 3000.00, 0, 2, 0.00, 0.00, 0.00, 0.00);
INSERT INTO `s_sess` (`id`, `gameid`, `title`, `basecoin`, `mincoin`, `maxcoin`, `status`, `ord`, `param1`, `param2`, `param3`, `param4`) VALUES (13, 265, 'dominuo', 10.00, 60.00, 6000.00, 1, 3, NULL, NULL, NULL, NULL);
INSERT INTO `s_sess` (`id`, `gameid`, `title`, `basecoin`, `mincoin`, `maxcoin`, `status`, `ord`, `param1`, `param2`, `param3`, `param4`) VALUES (14, 265, 'dominuo', 25.00, 150.00, 15000.00, 0, 4, NULL, NULL, NULL, NULL);
INSERT INTO `s_sess` (`id`, `gameid`, `title`, `basecoin`, `mincoin`, `maxcoin`, `status`, `ord`, `param1`, `param2`, `param3`, `param4`) VALUES (15, 265, 'dominuo', 50.00, 300.00, 30000.00, 1, 5, NULL, NULL, NULL, NULL);
INSERT INTO `s_sess` (`id`, `gameid`, `title`, `basecoin`, `mincoin`, `maxcoin`, `status`, `ord`, `param1`, `param2`, `param3`, `param4`) VALUES (16, 265, 'dominuo', 100.00, 600.00, 60000.00, 0, 6, NULL, NULL, NULL, NULL);
INSERT INTO `s_sess` (`id`, `gameid`, `title`, `basecoin`, `mincoin`, `maxcoin`, `status`, `ord`, `param1`, `param2`, `param3`, `param4`) VALUES (17, 265, 'dominuo', 250.00, 1500.00, 150000.00, 1, 7, NULL, NULL, NULL, NULL);
INSERT INTO `s_sess` (`id`, `gameid`, `title`, `basecoin`, `mincoin`, `maxcoin`, `status`, `ord`, `param1`, `param2`, `param3`, `param4`) VALUES (18, 265, 'dominuo', 500.00, 3000.00, 300000.00, 0, 8, NULL, NULL, NULL, NULL);
INSERT INTO `s_sess` (`id`, `gameid`, `title`, `basecoin`, `mincoin`, `maxcoin`, `status`, `ord`, `param1`, `param2`, `param3`, `param4`) VALUES (19, 265, 'dominuo', 1000.00, 6000.00, 600000.00, 0, 9, NULL, NULL, NULL, NULL);
INSERT INTO `s_sess` (`id`, `gameid`, `title`, `basecoin`, `mincoin`, `maxcoin`, `status`, `ord`, `param1`, `param2`, `param3`, `param4`) VALUES (20, 265, 'dominuo', 5000.00, 30000.00, -1.00, 0, 10, NULL, NULL, NULL, NULL);
INSERT INTO `s_sess` (`id`, `gameid`, `title`, `basecoin`, `mincoin`, `maxcoin`, `status`, `ord`, `param1`, `param2`, `param3`, `param4`) VALUES (21, 292, 'Rummy', 0.01, 0.80, 8.00, 1, 1, 0.00, 0.00, 0.00, 0.00);
INSERT INTO `s_sess` (`id`, `gameid`, `title`, `basecoin`, `mincoin`, `maxcoin`, `status`, `ord`, `param1`, `param2`, `param3`, `param4`) VALUES (22, 292, 'Rummy', 0.10, 8.00, 80.00, 0, 2, 0.00, 0.00, 0.00, 0.00);
INSERT INTO `s_sess` (`id`, `gameid`, `title`, `basecoin`, `mincoin`, `maxcoin`, `status`, `ord`, `param1`, `param2`, `param3`, `param4`) VALUES (23, 292, 'Rummy', 1.00, 80.00, 800.00, 1, 3, 0.00, 0.00, 0.00, 0.00);
INSERT INTO `s_sess` (`id`, `gameid`, `title`, `basecoin`, `mincoin`, `maxcoin`, `status`, `ord`, `param1`, `param2`, `param3`, `param4`) VALUES (24, 292, 'Rummy', 2.00, 160.00, 1600.00, 0, 4, 0.00, 0.00, 0.00, 0.00);
INSERT INTO `s_sess` (`id`, `gameid`, `title`, `basecoin`, `mincoin`, `maxcoin`, `status`, `ord`, `param1`, `param2`, `param3`, `param4`) VALUES (25, 292, 'Rummy', 3.00, 240.00, 2400.00, 1, 5, 0.00, 0.00, 0.00, 0.00);
INSERT INTO `s_sess` (`id`, `gameid`, `title`, `basecoin`, `mincoin`, `maxcoin`, `status`, `ord`, `param1`, `param2`, `param3`, `param4`) VALUES (26, 292, 'Rummy', 5.00, 400.00, 4000.00, 0, 6, 0.00, 0.00, 0.00, 0.00);
INSERT INTO `s_sess` (`id`, `gameid`, `title`, `basecoin`, `mincoin`, `maxcoin`, `status`, `ord`, `param1`, `param2`, `param3`, `param4`) VALUES (27, 292, 'Rummy', 10.00, 800.00, 8000.00, 1, 7, 0.00, 0.00, 0.00, 0.00);
INSERT INTO `s_sess` (`id`, `gameid`, `title`, `basecoin`, `mincoin`, `maxcoin`, `status`, `ord`, `param1`, `param2`, `param3`, `param4`) VALUES (28, 292, 'Rummy', 20.00, 1600.00, 16000.00, 0, 8, 0.00, 0.00, 0.00, 0.00);
INSERT INTO `s_sess` (`id`, `gameid`, `title`, `basecoin`, `mincoin`, `maxcoin`, `status`, `ord`, `param1`, `param2`, `param3`, `param4`) VALUES (29, 292, 'Rummy', 40.00, 3200.00, 32000.00, 0, 9, 0.00, 0.00, 0.00, 0.00);
INSERT INTO `s_sess` (`id`, `gameid`, `title`, `basecoin`, `mincoin`, `maxcoin`, `status`, `ord`, `param1`, `param2`, `param3`, `param4`) VALUES (30, 292, 'Rummy', 125.00, 10000.00, -1.00, 0, 10, 0.00, 0.00, 0.00, 0.00);
INSERT INTO `s_sess` (`id`, `gameid`, `title`, `basecoin`, `mincoin`, `maxcoin`, `status`, `ord`, `param1`, `param2`, `param3`, `param4`) VALUES (31, 291, 'Teenpatti', 0.10, 1.00, 100.00, 1, 1, 12.80, 102.40, 0.00, 0.00);
INSERT INTO `s_sess` (`id`, `gameid`, `title`, `basecoin`, `mincoin`, `maxcoin`, `status`, `ord`, `param1`, `param2`, `param3`, `param4`) VALUES (32, 291, 'Teenpatti', 1.00, 50.00, 500.00, 0, 2, 128.00, 1024.00, 0.00, 0.00);
INSERT INTO `s_sess` (`id`, `gameid`, `title`, `basecoin`, `mincoin`, `maxcoin`, `status`, `ord`, `param1`, `param2`, `param3`, `param4`) VALUES (33, 291, 'Teenpatti', 3.00, 150.00, 1500.00, 1, 3, 384.00, 3072.00, 0.00, 0.00);
INSERT INTO `s_sess` (`id`, `gameid`, `title`, `basecoin`, `mincoin`, `maxcoin`, `status`, `ord`, `param1`, `param2`, `param3`, `param4`) VALUES (34, 291, 'Teenpatti', 5.00, 250.00, 2500.00, 0, 4, 640.00, 5120.00, 0.00, 0.00);
INSERT INTO `s_sess` (`id`, `gameid`, `title`, `basecoin`, `mincoin`, `maxcoin`, `status`, `ord`, `param1`, `param2`, `param3`, `param4`) VALUES (35, 291, 'Teenpatti', 10.00, 500.00, 5000.00, 1, 5, 1280.00, 10240.00, 0.00, 0.00);
INSERT INTO `s_sess` (`id`, `gameid`, `title`, `basecoin`, `mincoin`, `maxcoin`, `status`, `ord`, `param1`, `param2`, `param3`, `param4`) VALUES (36, 291, 'Teenpatti', 50.00, 2500.00, 25000.00, 0, 6, 6400.00, 51200.00, 0.00, 0.00);
INSERT INTO `s_sess` (`id`, `gameid`, `title`, `basecoin`, `mincoin`, `maxcoin`, `status`, `ord`, `param1`, `param2`, `param3`, `param4`) VALUES (37, 291, 'Teenpatti', 100.00, 5000.00, 50000.00, 1, 7, 12800.00, 102400.00, 0.00, 0.00);
INSERT INTO `s_sess` (`id`, `gameid`, `title`, `basecoin`, `mincoin`, `maxcoin`, `status`, `ord`, `param1`, `param2`, `param3`, `param4`) VALUES (38, 291, 'Teenpatti', 300.00, 15000.00, 150000.00, 0, 8, 38400.00, 307200.00, 0.00, 0.00);
INSERT INTO `s_sess` (`id`, `gameid`, `title`, `basecoin`, `mincoin`, `maxcoin`, `status`, `ord`, `param1`, `param2`, `param3`, `param4`) VALUES (39, 291, 'Teenpatti', 500.00, 25000.00, 250000.00, 0, 9, 64000.00, 512000.00, 0.00, 0.00);
INSERT INTO `s_sess` (`id`, `gameid`, `title`, `basecoin`, `mincoin`, `maxcoin`, `status`, `ord`, `param1`, `param2`, `param3`, `param4`) VALUES (40, 291, 'Teenpatti', 1000.00, 50000.00, -1.00, 0, 10, 1000.00, 128000.00, 0.00, 0.00);
INSERT INTO `s_sess` (`id`, `gameid`, `title`, `basecoin`, `mincoin`, `maxcoin`, `status`, `ord`, `param1`, `param2`, `param3`, `param4`) VALUES (41, 269, 'ludo', 0.10, 1.00, 10.00, 1, 1, 0.00, 0.00, 0.00, 0.00);
INSERT INTO `s_sess` (`id`, `gameid`, `title`, `basecoin`, `mincoin`, `maxcoin`, `status`, `ord`, `param1`, `param2`, `param3`, `param4`) VALUES (42, 269, 'ludo', 1.00, 5.00, 50.00, 0, 2, 0.00, 0.00, 0.00, 0.00);
INSERT INTO `s_sess` (`id`, `gameid`, `title`, `basecoin`, `mincoin`, `maxcoin`, `status`, `ord`, `param1`, `param2`, `param3`, `param4`) VALUES (43, 269, 'ludo', 5.00, 25.00, 250.00, 1, 3, 0.00, 0.00, 0.00, 0.00);
INSERT INTO `s_sess` (`id`, `gameid`, `title`, `basecoin`, `mincoin`, `maxcoin`, `status`, `ord`, `param1`, `param2`, `param3`, `param4`) VALUES (44, 269, 'ludo', 10.00, 50.00, 500.00, 0, 4, 0.00, 0.00, 0.00, 0.00);
INSERT INTO `s_sess` (`id`, `gameid`, `title`, `basecoin`, `mincoin`, `maxcoin`, `status`, `ord`, `param1`, `param2`, `param3`, `param4`) VALUES (45, 269, 'ludo', 50.00, 250.00, 2500.00, 1, 5, 0.00, 0.00, 0.00, 0.00);
INSERT INTO `s_sess` (`id`, `gameid`, `title`, `basecoin`, `mincoin`, `maxcoin`, `status`, `ord`, `param1`, `param2`, `param3`, `param4`) VALUES (46, 269, 'ludo', 100.00, 500.00, 5000.00, 0, 6, 0.00, 0.00, 0.00, 0.00);
INSERT INTO `s_sess` (`id`, `gameid`, `title`, `basecoin`, `mincoin`, `maxcoin`, `status`, `ord`, `param1`, `param2`, `param3`, `param4`) VALUES (47, 269, 'ludo', 200.00, 1000.00, 10000.00, 1, 7, 0.00, 0.00, 0.00, 0.00);
INSERT INTO `s_sess` (`id`, `gameid`, `title`, `basecoin`, `mincoin`, `maxcoin`, `status`, `ord`, `param1`, `param2`, `param3`, `param4`) VALUES (48, 269, 'ludo', 300.00, 1500.00, 15000.00, 0, 8, 0.00, 0.00, 0.00, 0.00);
INSERT INTO `s_sess` (`id`, `gameid`, `title`, `basecoin`, `mincoin`, `maxcoin`, `status`, `ord`, `param1`, `param2`, `param3`, `param4`) VALUES (49, 269, 'ludo', 500.00, 2500.00, 25000.00, 0, 9, 0.00, 0.00, 0.00, 0.00);
INSERT INTO `s_sess` (`id`, `gameid`, `title`, `basecoin`, `mincoin`, `maxcoin`, `status`, `ord`, `param1`, `param2`, `param3`, `param4`) VALUES (50, 269, 'ludo', 1000.00, 5000.00, -1.00, 0, 10, 0.00, 0.00, 0.00, 0.00);
INSERT INTO `s_sess` (`id`, `gameid`, `title`, `basecoin`, `mincoin`, `maxcoin`, `status`, `ord`, `param1`, `param2`, `param3`, `param4`) VALUES (51, 287, 'uno', 0.10, 1.00, 10.00, 1, 1, 0.00, 0.00, 0.00, 0.00);
INSERT INTO `s_sess` (`id`, `gameid`, `title`, `basecoin`, `mincoin`, `maxcoin`, `status`, `ord`, `param1`, `param2`, `param3`, `param4`) VALUES (52, 287, 'uno', 1.00, 5.00, 50.00, 0, 2, 0.00, 0.00, 0.00, 0.00);
INSERT INTO `s_sess` (`id`, `gameid`, `title`, `basecoin`, `mincoin`, `maxcoin`, `status`, `ord`, `param1`, `param2`, `param3`, `param4`) VALUES (53, 287, 'uno', 5.00, 25.00, 250.00, 1, 3, 0.00, 0.00, 0.00, 0.00);
INSERT INTO `s_sess` (`id`, `gameid`, `title`, `basecoin`, `mincoin`, `maxcoin`, `status`, `ord`, `param1`, `param2`, `param3`, `param4`) VALUES (54, 287, 'uno', 10.00, 50.00, 500.00, 0, 4, 0.00, 0.00, 0.00, 0.00);
INSERT INTO `s_sess` (`id`, `gameid`, `title`, `basecoin`, `mincoin`, `maxcoin`, `status`, `ord`, `param1`, `param2`, `param3`, `param4`) VALUES (55, 287, 'uno', 50.00, 250.00, 2500.00, 1, 5, 0.00, 0.00, 0.00, 0.00);
INSERT INTO `s_sess` (`id`, `gameid`, `title`, `basecoin`, `mincoin`, `maxcoin`, `status`, `ord`, `param1`, `param2`, `param3`, `param4`) VALUES (56, 287, 'uno', 100.00, 500.00, 5000.00, 0, 6, 0.00, 0.00, 0.00, 0.00);
INSERT INTO `s_sess` (`id`, `gameid`, `title`, `basecoin`, `mincoin`, `maxcoin`, `status`, `ord`, `param1`, `param2`, `param3`, `param4`) VALUES (57, 287, 'uno', 200.00, 1000.00, 10000.00, 1, 7, 0.00, 0.00, 0.00, 0.00);
INSERT INTO `s_sess` (`id`, `gameid`, `title`, `basecoin`, `mincoin`, `maxcoin`, `status`, `ord`, `param1`, `param2`, `param3`, `param4`) VALUES (58, 287, 'uno', 300.00, 1500.00, 15000.00, 0, 8, 0.00, 0.00, 0.00, 0.00);
INSERT INTO `s_sess` (`id`, `gameid`, `title`, `basecoin`, `mincoin`, `maxcoin`, `status`, `ord`, `param1`, `param2`, `param3`, `param4`) VALUES (59, 287, 'uno', 500.00, 2500.00, 25000.00, 0, 9, 0.00, 0.00, 0.00, 0.00);
INSERT INTO `s_sess` (`id`, `gameid`, `title`, `basecoin`, `mincoin`, `maxcoin`, `status`, `ord`, `param1`, `param2`, `param3`, `param4`) VALUES (60, 287, 'uno', 1000.00, 5000.00, -1.00, 0, 10, 0.00, 0.00, 0.00, 0.00);
INSERT INTO `s_sess` (`id`, `gameid`, `title`, `basecoin`, `mincoin`, `maxcoin`, `status`, `ord`, `param1`, `param2`, `param3`, `param4`) VALUES (61, 255, 'BlackJack', 1.00, 1.00, 100.00, 1, 1, 0.10, 10.00, 0.00, 0.00);
INSERT INTO `s_sess` (`id`, `gameid`, `title`, `basecoin`, `mincoin`, `maxcoin`, `status`, `ord`, `param1`, `param2`, `param3`, `param4`) VALUES (62, 255, 'BlackJack', 1.00, 10.00, 1000.00, 0, 2, 1.00, 10.00, 0.00, 0.00);
INSERT INTO `s_sess` (`id`, `gameid`, `title`, `basecoin`, `mincoin`, `maxcoin`, `status`, `ord`, `param1`, `param2`, `param3`, `param4`) VALUES (63, 255, 'BlackJack', 1.00, 50.00, 5000.00, 1, 3, 5.00, 50.00, 0.00, 0.00);
INSERT INTO `s_sess` (`id`, `gameid`, `title`, `basecoin`, `mincoin`, `maxcoin`, `status`, `ord`, `param1`, `param2`, `param3`, `param4`) VALUES (64, 255, 'BlackJack', 1.00, 100.00, 10000.00, 0, 4, 10.00, 100.00, 0.00, 0.00);
INSERT INTO `s_sess` (`id`, `gameid`, `title`, `basecoin`, `mincoin`, `maxcoin`, `status`, `ord`, `param1`, `param2`, `param3`, `param4`) VALUES (65, 255, 'BlackJack', 1.00, 500.00, 50000.00, 1, 5, 50.00, 500.00, 0.00, 0.00);
INSERT INTO `s_sess` (`id`, `gameid`, `title`, `basecoin`, `mincoin`, `maxcoin`, `status`, `ord`, `param1`, `param2`, `param3`, `param4`) VALUES (66, 255, 'BlackJack', 1.00, 1000.00, 100000.00, 0, 6, 100.00, 1000.00, 0.00, 0.00);
INSERT INTO `s_sess` (`id`, `gameid`, `title`, `basecoin`, `mincoin`, `maxcoin`, `status`, `ord`, `param1`, `param2`, `param3`, `param4`) VALUES (67, 255, 'BlackJack', 1.00, 5000.00, 500000.00, 1, 7, 500.00, 5000.00, 0.00, 0.00);
INSERT INTO `s_sess` (`id`, `gameid`, `title`, `basecoin`, `mincoin`, `maxcoin`, `status`, `ord`, `param1`, `param2`, `param3`, `param4`) VALUES (68, 255, 'BlackJack', 1.00, 10000.00, 1000000.00, 0, 8, 1000.00, 10000.00, 0.00, 0.00);
INSERT INTO `s_sess` (`id`, `gameid`, `title`, `basecoin`, `mincoin`, `maxcoin`, `status`, `ord`, `param1`, `param2`, `param3`, `param4`) VALUES (69, 255, 'BlackJack', 1.00, 20000.00, 2000000.00, 0, 9, 2000.00, 20000.00, 0.00, 0.00);
INSERT INTO `s_sess` (`id`, `gameid`, `title`, `basecoin`, `mincoin`, `maxcoin`, `status`, `ord`, `param1`, `param2`, `param3`, `param4`) VALUES (70, 255, 'BlackJack', 1.00, 50000.00, -1.00, 0, 10, 5000.00, 50000.00, 0.00, 0.00);
update s_sess set basecoin=param1 where gameid in (255,293);

drop table s_sign_pack;

DROP TABLE IF EXISTS `s_sign_vip`;
CREATE TABLE `s_sign_vip` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `coin` int(11) DEFAULT NULL,
  `prize` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `svip` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=8 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='vip登录奖励配置';
INSERT INTO `s_sign_vip` (`id`, `coin`, `prize`, `svip`) VALUES (1, 3, '', 0);
INSERT INTO `s_sign_vip` (`id`, `coin`, `prize`, `svip`) VALUES (2, 7, '', 0);
INSERT INTO `s_sign_vip` (`id`, `coin`, `prize`, `svip`) VALUES (3, 9, '', 0);
INSERT INTO `s_sign_vip` (`id`, `coin`, `prize`, `svip`) VALUES (4, 13, '', 0);
INSERT INTO `s_sign_vip` (`id`, `coin`, `prize`, `svip`) VALUES (5, 17, '', 2);
INSERT INTO `s_sign_vip` (`id`, `coin`, `prize`, `svip`) VALUES (6, 19, '', 2);
INSERT INTO `s_sign_vip` (`id`, `coin`, `prize`, `svip`) VALUES (7, 32, '', 2);

ALTER TABLE `indiarummy_game`.`d_svip_task` 
MODIFY COLUMN `type` tinyint(1) NULL DEFAULT NULL COMMENT '1:签到 2:周 3:月 4:升级' AFTER `svip`;

update s_config set v='http://pay.yono99.com/sms.php' where k='sms_url';