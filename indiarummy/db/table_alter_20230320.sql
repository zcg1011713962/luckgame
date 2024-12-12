ALTER TABLE `indiarummy_game`.`d_user_bind` 
ADD COLUMN `gid` varchar(255) NULL DEFAULT '' COMMENT 'gsfid' AFTER `passwd`,
ADD COLUMN `sid` varchar(255) NULL DEFAULT '' COMMENT 'simcardid' AFTER `gid`,
ADD COLUMN `logintype` tinyint(2) NULL DEFAULT 1 COMMENT '登录方式' AFTER `sid`;

update d_user_bind set logintype=9 where passwd != '';

ALTER TABLE `indiarummy_game`.`d_user` 
MODIFY COLUMN `code` varchar(12) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NULL DEFAULT '' COMMENT '邀请码' AFTER `rp`;

DROP TABLE IF EXISTS `indiarummy_adm`.`account_agent`;
CREATE TABLE `indiarummy_adm`.`account_agent` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `username` varchar(255) COLLATE utf8mb4_bin DEFAULT NULL COMMENT '后台账号用户名',
  `password` varchar(32) COLLATE utf8mb4_bin DEFAULT NULL COMMENT '密码密文',
  `status` tinyint(1) DEFAULT '1' COMMENT '1可用 0不可用',
  `salt` char(6) COLLATE utf8mb4_bin DEFAULT NULL COMMENT '随机盐值',
  `agentids` varchar(1024) COLLATE utf8mb4_bin DEFAULT '0' COMMENT '关联的代理id',
  `channelids` int(11) DEFAULT NULL COMMENT '渠道个数',
  `nickname` varchar(255) COLLATE utf8mb4_bin DEFAULT NULL COMMENT '昵称',
  `phone` varchar(255) COLLATE utf8mb4_bin DEFAULT NULL COMMENT '电话',
  `remark` varchar(255) COLLATE utf8mb4_bin DEFAULT NULL COMMENT '备注',
  `create_time` int(11) DEFAULT NULL COMMENT '创建时间',
  `uid` int(11) DEFAULT NULL COMMENT '创建时间',
  `token` varchar(32) COLLATE utf8mb4_bin DEFAULT '' COMMENT '登录token',
  PRIMARY KEY (`id`),
  KEY `idx_username` (`username`(32))
) ENGINE=InnoDB AUTO_INCREMENT=4 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin COMMENT='2b后台账号表';

DROP TABLE IF EXISTS `d_account_channel`;
CREATE TABLE `d_account_channel` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `title` varchar(255) COLLATE utf8mb4_bin DEFAULT NULL COMMENT '渠道名称',
  `token` varchar(255) COLLATE utf8mb4_bin DEFAULT NULL COMMENT '临时token',
  `uid` int(11) DEFAULT '0',
  `create_time` int(11) DEFAULT '0',
  `uuid` int(11) DEFAULT '0',
  `update_time` int(11) DEFAULT '0',
  `accountid` int(11) DEFAULT '0' COMMENT '账号id',
  `remark` varchar(255) COLLATE utf8mb4_bin DEFAULT NULL COMMENT '备注',
  `prefix` char(3) COLLATE utf8mb4_bin DEFAULT NULL COMMENT '渠道码前缀',
  `code` char(11) COLLATE utf8mb4_bin DEFAULT NULL COMMENT '渠道码',
  PRIMARY KEY (`id`),
  KEY `idx_account` (`accountid`),
  KEY `idx_prefix` (`prefix`),
  KEY `idx_code` (`code`)
) ENGINE=InnoDB AUTO_INCREMENT=4 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin COMMENT='渠道配置信息';

INSERT INTO `d_account_channel` (`id`, `title`, `token`, `uid`, `create_time`, `uuid`, `update_time`, `accountid`, `remark`, `prefix`, `code`) VALUES (1, '默认通道', NULL, 11497, 1679388140, 0, 1679388140, 3, '官网渠道包', 'GK1', 'GK19YRVKHP9');
INSERT INTO `d_account_channel` (`id`, `title`, `token`, `uid`, `create_time`, `uuid`, `update_time`, `accountid`, `remark`, `prefix`, `code`) VALUES (7, 'Google', NULL, 11497, 1679393061, 0, 1679393061, 3, '提审渠道包', 'PBR', 'PBRY9ST7NLX');

DROP TABLE IF EXISTS `d_user_phone`;
CREATE TABLE `d_user_phone` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `uid` bigint(20) DEFAULT NULL COMMENT 'uid',
  `mobile` varchar(255) COLLATE utf8mb4_bin DEFAULT NULL COMMENT '手机号账号',
  `ddid` varchar(255) COLLATE utf8mb4_bin DEFAULT NULL COMMENT '设备号',
  `fname` varchar(255) COLLATE utf8mb4_bin DEFAULT NULL COMMENT '昵称',
  `fphone` varchar(255) COLLATE utf8mb4_bin DEFAULT NULL COMMENT '联系方式',
  `create_time` int(11) DEFAULT NULL COMMENT '创建时间',
  `ip` varchar(255) COLLATE utf8mb4_bin DEFAULT NULL COMMENT '客户端ip',
  PRIMARY KEY (`id`),
  KEY `idx_uid` (`uid`),
  KEY `idx_phone` (`fphone`(32),`ddid`(32)) USING BTREE
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin COMMENT='用户通讯录';

DROP TABLE IF EXISTS `d_safe_user`;
CREATE TABLE `d_safe_user` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `uid` bigint(20) DEFAULT NULL COMMENT '用户uid',
  `fcmhash` varchar(32) COLLATE utf8mb4_bin DEFAULT '' COMMENT 'Fcmtoken hash',
  `regdifftime` int(11) DEFAULT '0' COMMENT '协议1和协议2的时间戳差',
  `startlog` tinyint(1) DEFAULT '0' COMMENT '是否包含启动日期',
  `gsfhash` varchar(255) COLLATE utf8mb4_bin DEFAULT NULL COMMENT 'Gsfid hash',
  `contacthash` varchar(32) COLLATE utf8mb4_bin DEFAULT NULL COMMENT '通讯录hash',
  `create_time` int(11) DEFAULT '0',
  `update_time` int(11) DEFAULT NULL COMMENT '更新时间',
  PRIMARY KEY (`id`),
  KEY `idx_time` (`create_time`),
  KEY `idx_uid` (`uid`) USING BTREE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin COMMENT='用户安全相关标记';

ALTER TABLE `indiarummy_game`.`d_user_invite` 
ADD COLUMN `cx` varchar(255) NULL COMMENT '下包时的随机码' AFTER `rewards`;

ALTER TABLE `indiarummy_game`.`d_user` 
add column `channelid` int(11) DEFAULT '0' COMMENT '渠道编号',
ADD COLUMN `cx` varchar(32) NULL DEFAULT '' COMMENT '底包随机码' AFTER `channelid`,
ADD INDEX `idx_cx`(`cx`);

ALTER TABLE `indiarummy_game`.`d_user` 
ADD COLUMN `logintype` int(11) NULL COMMENT '登录方式' AFTER `cx`;