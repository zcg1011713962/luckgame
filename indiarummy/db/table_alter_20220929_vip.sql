DROP TABLE IF EXISTS `s_config_vip_upgrade`;
CREATE TABLE `s_config_vip_upgrade` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `level` int(11) DEFAULT NULL,
  `diamond` bigint(20) DEFAULT NULL COMMENT '所需消耗的钻石数',
  `benefit` varchar(500) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '加成',
  `rewards` varchar(300) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `memo` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `rewards_rate` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '升级奖励分比例',
  `weeklybonus` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '周奖励',
  `weeklyrate` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '周奖励分比例',
  `monthlybonus` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '月奖励',
  `monthlyrate` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '月奖励比例',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=21 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Vip升级配置表';

-- ----------------------------
-- Records of s_config_vip_upgrade
-- ----------------------------
BEGIN;
INSERT INTO `s_config_vip_upgrade` (`id`, `level`, `diamond`, `benefit`, `rewards`, `memo`, `rewards_rate`, `weeklybonus`, `weeklyrate`, `monthlybonus`, `monthlyrate`) VALUES (1, 1, 0, '{\"badge\":\"vip0\",\"avatar\":\"avatarframe_100\",\"ticket\":1,\"friendscnt\":100,\"chatframe\":\"\"}', '0', 'vip1', '1:0:0', '0', '1:0:0', '0', '1:0:0');
INSERT INTO `s_config_vip_upgrade` (`id`, `level`, `diamond`, `benefit`, `rewards`, `memo`, `rewards_rate`, `weeklybonus`, `weeklyrate`, `monthlybonus`, `monthlyrate`) VALUES (2, 2, 200, '{\"badge\":\"vip1\",\"avatar\":\"avatarframe_101\",\"ticket\":1,\"friendscnt\":100,\"chatframe\":\"\"}', '1:10', 'vip2', '1:0:0', '1:5', '1:0:0', '1:10', '1:0:0');
INSERT INTO `s_config_vip_upgrade` (`id`, `level`, `diamond`, `benefit`, `rewards`, `memo`, `rewards_rate`, `weeklybonus`, `weeklyrate`, `monthlybonus`, `monthlyrate`) VALUES (3, 3, 1000, '{\"badge\":\"vip2\",\"avatar\":\"avatarframe_102\",\"ticket\":1,\"friendscnt\":100,\"chatframe\":\"\"}', '1:50', 'vip3', '1:0:0', '1:20', '1:0:0', '1:50', '1:0:0');
INSERT INTO `s_config_vip_upgrade` (`id`, `level`, `diamond`, `benefit`, `rewards`, `memo`, `rewards_rate`, `weeklybonus`, `weeklyrate`, `monthlybonus`, `monthlyrate`) VALUES (4, 4, 5000, '{\"badge\":\"vip3\",\"avatar\":\"avatarframe_103\",\"ticket\":2,\"friendscnt\":100,\"chatframe\":\"\"}', '1:100', 'vip4', '1:0:0', '1:30', '1:0:0', '1:80', '1:0:0');
INSERT INTO `s_config_vip_upgrade` (`id`, `level`, `diamond`, `benefit`, `rewards`, `memo`, `rewards_rate`, `weeklybonus`, `weeklyrate`, `monthlybonus`, `monthlyrate`) VALUES (5, 5, 20000, '{\"badge\":\"vip4\",\"avatar\":\"avatarframe_104\",\"ticket\":2,\"friendscnt\":100,\"chatframe\":\"\"}', '1:500', 'vip5', '1:0:0', '1:50', '1:0:0', '1:150', '1:0:0');
INSERT INTO `s_config_vip_upgrade` (`id`, `level`, `diamond`, `benefit`, `rewards`, `memo`, `rewards_rate`, `weeklybonus`, `weeklyrate`, `monthlybonus`, `monthlyrate`) VALUES (6, 6, 100000, '{\"badge\":\"vip5\",\"avatar\":\"avatarframe_105\",\"ticket\":3,\"friendscnt\":150,\"chatframe\":\"chat_vip_5\"}', '1:3000', 'vip6', '1:0:0', '1:80', '1:0:0', '1:200', '1:0:0');
INSERT INTO `s_config_vip_upgrade` (`id`, `level`, `diamond`, `benefit`, `rewards`, `memo`, `rewards_rate`, `weeklybonus`, `weeklyrate`, `monthlybonus`, `monthlyrate`) VALUES (7, 7, 500000, '{\"badge\":\"vip6\",\"avatar\":\"avatarframe_106\",\"ticket\":3,\"friendscnt\":150,\"chatframe\":\"chat_vip_6\"}', '1:15000', 'vip7', '1:0:0', '1:150', '1:0:0', '1:250', '1:0:0');
INSERT INTO `s_config_vip_upgrade` (`id`, `level`, `diamond`, `benefit`, `rewards`, `memo`, `rewards_rate`, `weeklybonus`, `weeklyrate`, `monthlybonus`, `monthlyrate`) VALUES (8, 8, 5000000, '{\"badge\":\"vip7\",\"avatar\":\"avatarframe_107\",\"ticket\":3,\"friendscnt\":200,\"chatframe\":\"chat_vip_7\"}', '1:65000', 'vip8', '1:0:0', '1:500', '1:0:0', '1:800', '1:0:0');
INSERT INTO `s_config_vip_upgrade` (`id`, `level`, `diamond`, `benefit`, `rewards`, `memo`, `rewards_rate`, `weeklybonus`, `weeklyrate`, `monthlybonus`, `monthlyrate`) VALUES (9, 9, 15000000, '{\"badge\":\"vip8\",\"avatar\":\"avatarframe_108\",\"ticket\":3,\"friendscnt\":200,\"chatframe\":\"chat_vip_8\"}', '1:200000', 'vip9', '1:0:0', '1:1000', '1:0:0', '1:1000', '1:0:0');
INSERT INTO `s_config_vip_upgrade` (`id`, `level`, `diamond`, `benefit`, `rewards`, `memo`, `rewards_rate`, `weeklybonus`, `weeklyrate`, `monthlybonus`, `monthlyrate`) VALUES (10, 10, 30000000, '{\"badge\":\"vip9\",\"avatar\":\"avatarframe_109\",\"ticket\":4,\"friendscnt\":300,\"chatframe\":\"chat_vip_9\"}', '1:600000', 'vip10', '1:0:0', '1:1500', '1:0:0', '1:1500', '1:0:0');
INSERT INTO `s_config_vip_upgrade` (`id`, `level`, `diamond`, `benefit`, `rewards`, `memo`, `rewards_rate`, `weeklybonus`, `weeklyrate`, `monthlybonus`, `monthlyrate`) VALUES (11, 11, 50000000, '{\"badge\":\"vip10\",\"avatar\":\"avatarframe_110\",\"ticket\":4,\"friendscnt\":300,\"chatframe\":\"chat_vip_10\"}', '1:1000000', 'vip11', '1:0:0', '1:2000', '0.5:0:0.5', '1:2000', '0.5:0:0.5');
INSERT INTO `s_config_vip_upgrade` (`id`, `level`, `diamond`, `benefit`, `rewards`, `memo`, `rewards_rate`, `weeklybonus`, `weeklyrate`, `monthlybonus`, `monthlyrate`) VALUES (12, 12, 80000000, '{\"badge\":\"vip11\",\"avatar\":\"avatarframe_111\",\"ticket\":5,\"friendscnt\":400,\"chatframe\":\"chat_vip_11\"}', '1:1600000', 'vip12', '1:0:0', '1:2500', '0.5:0:0.5', '1:2500', '0.5:0:0.5');
INSERT INTO `s_config_vip_upgrade` (`id`, `level`, `diamond`, `benefit`, `rewards`, `memo`, `rewards_rate`, `weeklybonus`, `weeklyrate`, `monthlybonus`, `monthlyrate`) VALUES (13, 13, 100000000, '{\"badge\":\"vip12\",\"avatar\":\"avatarframe_112\",\"ticket\":5,\"friendscnt\":400,\"chatframe\":\"chat_vip_12\"}', '1:2000000', 'vip13', '1:0:0', '1:3000', '0.5:0:0.5', '1:3000', '0.5:0:0.5');
INSERT INTO `s_config_vip_upgrade` (`id`, `level`, `diamond`, `benefit`, `rewards`, `memo`, `rewards_rate`, `weeklybonus`, `weeklyrate`, `monthlybonus`, `monthlyrate`) VALUES (14, 14, 150000000, NULL, '1:3000000', 'vip14', '1:0:0', '1:3500', '0.5:0:0.5', '1:3500', '0.5:0:0.5');
INSERT INTO `s_config_vip_upgrade` (`id`, `level`, `diamond`, `benefit`, `rewards`, `memo`, `rewards_rate`, `weeklybonus`, `weeklyrate`, `monthlybonus`, `monthlyrate`) VALUES (15, 15, 200000000, NULL, '1:4000000', 'vip15', '1:0:0', '1:4000', '0.5:0:0.5', '1:4000', '0.5:0:0.5');
INSERT INTO `s_config_vip_upgrade` (`id`, `level`, `diamond`, `benefit`, `rewards`, `memo`, `rewards_rate`, `weeklybonus`, `weeklyrate`, `monthlybonus`, `monthlyrate`) VALUES (16, 16, 300000000, NULL, '1:6000000', 'vip16', '1:0:0', '1:5000', '0.5:0:0.5', '1:5000', '0.5:0:0.5');
INSERT INTO `s_config_vip_upgrade` (`id`, `level`, `diamond`, `benefit`, `rewards`, `memo`, `rewards_rate`, `weeklybonus`, `weeklyrate`, `monthlybonus`, `monthlyrate`) VALUES (17, 17, 500000000, NULL, '1:10000000', 'vip17', '1:0:0', '1:7000', '0.5:0:0.5', '1:7000', '0.5:0:0.5');
INSERT INTO `s_config_vip_upgrade` (`id`, `level`, `diamond`, `benefit`, `rewards`, `memo`, `rewards_rate`, `weeklybonus`, `weeklyrate`, `monthlybonus`, `monthlyrate`) VALUES (18, 18, 1000000000, NULL, '1:20000000', 'vip18', '1:0:0', '1:15000', '0.5:0:0.5', '1:15000', '0.5:0:0.5');
INSERT INTO `s_config_vip_upgrade` (`id`, `level`, `diamond`, `benefit`, `rewards`, `memo`, `rewards_rate`, `weeklybonus`, `weeklyrate`, `monthlybonus`, `monthlyrate`) VALUES (19, 19, 1500000000, NULL, '1:30000000', 'vip19', '1:0:0', '1:35000', '0.5:0:0.5', '1:35000', '0.5:0:0.5');
INSERT INTO `s_config_vip_upgrade` (`id`, `level`, `diamond`, `benefit`, `rewards`, `memo`, `rewards_rate`, `weeklybonus`, `weeklyrate`, `monthlybonus`, `monthlyrate`) VALUES (20, 20, 2000000000, NULL, '1:40000000', 'vip20', '1:0:0', '1:50000', '0.5:0:0.5', '1:50000', '0.5:0:0.5');
COMMIT;


CREATE TABLE `d_svip_task`  (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `uid` bigint(20) NULL,
  `svip` int(11) NULL,
  `state` tinyint(1) NULL COMMENT '1:可领取 2：已领取',
  `create_time` int(11) NULL,
  `update_time` int(11) NULL,
  PRIMARY KEY (`id`),
  INDEX `idx_uid`(`uid`)
) COMMENT = 'Vip等级塔任务进度';

ALTER TABLE `d_svip_task` ADD COLUMN `type` tinyint(1) NULL COMMENT '1:升级 2:周 3:月' AFTER `svip`;

ALTER TABLE `d_svip_task` DROP INDEX `idx_uid`, ADD UNIQUE INDEX `idx_uid`(`uid`) USING BTREE;

ALTER TABLE `d_user` 
CHANGE COLUMN `drawmax` `maxdraw` decimal(20, 2) NULL DEFAULT NULL COMMENT '最大可提分' AFTER `totaldraw`,
ADD COLUMN `candraw` decimal(20, 2) NULL COMMENT '赠送的可提现金额' AFTER `maxdraw`;

ALTER TABLE `d_log_senddraw` 
MODIFY COLUMN `category` int(11) NULL DEFAULT NULL COMMENT '1:注册 2:购买 3:vip升级' AFTER `create_time`;

ALTER TABLE `d_user` 
ADD COLUMN `cashbonus` decimal(20, 2) NULL COMMENT 'bonus coin' AFTER `dcoin`;

update s_config set v='https://pay.yono99.com/sms.php' where k='sms_url';

ALTER TABLE `s_config_vip_upgrade` 
ADD COLUMN `uuid` int(11) NULL DEFAULT 0 AFTER `monthlyrate`,
ADD COLUMN `update_time` int(11) NULL DEFAULT 0 AFTER `uuid`;


DROP TABLE IF EXISTS `d_bank`;
CREATE TABLE `d_bank` (
  `uid` bigint(20) NOT NULL DEFAULT '0' COMMENT 'uid',
  `coin` decimal(20,2) DEFAULT '0.00' COMMENT '银行余额',
  `passwd` varchar(300) DEFAULT '' COMMENT '银行密码',
  `create_time` int(11) DEFAULT '0' COMMENT '创建时间',
  `update_time` int(11) DEFAULT '0' COMMENT '最后更新时间',
  `token` varchar(32) DEFAULT '' COMMENT '此次登录的token',
  PRIMARY KEY (`uid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='玩家银行';

DROP TABLE IF EXISTS `d_bank_record`;
CREATE TABLE `d_bank_record` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `uid` bigint(20) DEFAULT NULL,
  `after_coin` bigint(20) unsigned DEFAULT '0' COMMENT '操作之后的金额',
  `coin` bigint(20) unsigned DEFAULT NULL,
  `before_coin` bigint(20) unsigned DEFAULT '0' COMMENT '玩家操作之前的金币',
  `type` tinyint(1) DEFAULT '1' COMMENT '1存钱 2取钱',
  `gameid` int(11) DEFAULT '0' COMMENT '取钱时游戏id',
  `deskid` varchar(32) DEFAULT '' COMMENT '取钱时房间号',
  `create_time` int(11) DEFAULT NULL COMMENT '创建时间',
  PRIMARY KEY (`id`),
  KEY `idx_uid` (`uid`)
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8mb4 COMMENT='玩家银行记录';