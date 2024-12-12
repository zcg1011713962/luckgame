ALTER TABLE `d_user` 
MODIFY COLUMN `coin` bigint(20) UNSIGNED NULL DEFAULT NULL COMMENT '金币数,单位分' AFTER `create_platform`;

ALTER TABLE `coin_log` 
MODIFY COLUMN `before_coin` bigint(20) UNSIGNED NOT NULL DEFAULT 0 COMMENT '变动前分数' AFTER `game_id`,
MODIFY COLUMN `coin` bigint(20) UNSIGNED NOT NULL DEFAULT 0 COMMENT '变动分数' AFTER `before_coin`,
MODIFY COLUMN `after_coin` bigint(20) UNSIGNED NOT NULL DEFAULT 0 COMMENT '变动后分数' AFTER `coin`;

CREATE TABLE `d_bank` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `uid` bigint(20) NOT NULL DEFAULT '0' COMMENT 'uid',
  `coin` bigint(20) unsigned DEFAULT '0' COMMENT '银行余额，单位分',
  `passwd` varchar(300) DEFAULT '' COMMENT '银行密码',
  `create_time` int(11) DEFAULT '0' COMMENT '创建时间',
  `update_time` int(11) DEFAULT '0' COMMENT '最后更新时间',
  `token` varchar(32) DEFAULT '' COMMENT '此次登录的token',
  PRIMARY KEY (`id`) USING BTREE,
  KEY `idx_uid` (`uid`)
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=utf8mb4 COMMENT='玩家保险箱';

CREATE TABLE `d_bank_record` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `uid` bigint(20) DEFAULT NULL,
  `after_coin` bigint(20) UNSIGNED DEFAULT '0' COMMENT '操作之后的金额',
  `coin` bigint(20) UNSIGNED DEFAULT NULL,
  `before_coin` bigint(20) UNSIGNED DEFAULT '0' COMMENT '玩家操作之前的金币',
  `type` tinyint(1) DEFAULT '1' COMMENT '1存钱 2取钱',
  `gameid` int(11) DEFAULT '0' COMMENT '取钱时游戏id',
  `deskid` varchar(32) DEFAULT '' COMMENT '取钱时房间号',
  `create_time` int(11) DEFAULT NULL COMMENT '创建时间',
  PRIMARY KEY (`id`),
  KEY `idx_uid` (`uid`)
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8mb4 COMMENT='玩家保险箱记录';

CREATE TABLE `d_user_bank`  (
  `id` int(11) UNSIGNED NOT NULL AUTO_INCREMENT,
  `uid` bigint(20) UNSIGNED NULL COMMENT 'uid',
  `account` varchar(255) NULL DEFAULT '' COMMENT '账号',
  `username` varchar(255) NULL DEFAULT '' COMMENT '姓名',
  `ifsc` varchar(100) NULL DEFAULT '' COMMENT 'ifsc_code',
  `bankname` varchar(255) NULL DEFAULT '' COMMENT '银行名称',
  `email` varchar(255) NULL DEFAULT '' COMMENT '邮件',
  `create_time` int(11) NULL COMMENT '添加时间',
  `status` tinyint(1) NULL COMMENT '状态 1:有效 0:无效',
  PRIMARY KEY (`id`),
  INDEX `idx_uid`(`uid`)
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8mb4 COMMENT='玩家的银行账户记录';

ALTER TABLE `d_user_bank` 
ADD COLUMN `cat` int(11) NULL DEFAULT 1 COMMENT '1:bank 2:upi 3:usdt' AFTER `uid`,
MODIFY COLUMN `account` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_bin NULL DEFAULT '' COMMENT '账号或地址' AFTER `uid`,
ADD COLUMN `phone` varchar(255) NULL COMMENT '电话' AFTER `email`;

CREATE TABLE `s_config_pics` (
  `id` int(11) UNSIGNED NOT NULL AUTO_INCREMENT,
  `img` varchar(255) NULL DEFAULT '' COMMENT '图片地址',
  `create_time` int(11) NULL COMMENT '添加时间',
  `status` tinyint(1) NULL COMMENT '状态: 1:有效 0:无效',
  `url` varchar(255) NULL COMMENT '跳转地址',
  `ord` int(11) NULL COMMENT '排序，越小越靠前',
  `memo` varchar(255) NULL COMMENT '备注',
  PRIMARY KEY (`id`),
  INDEX `idx_time`(`create_time`)
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8mb4 COMMENT = '广告图配置';

DROP TABLE IF EXISTS `d_user_draw`;
CREATE TABLE `d_user_draw` (
  `id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `uid` bigint(20) DEFAULT NULL COMMENT 'uid',
  `cat` int(11) DEFAULT NULL COMMENT '采用的账号类型',
  `bankid` int(11) DEFAULT NULL COMMENT '采用的银行账户',
  `create_time` int(11) DEFAULT NULL COMMENT '操作时间',
  `account` varchar(255) COLLATE utf8mb4_bin DEFAULT NULL COMMENT '账号',
  `coin` bigint(20) unsigned DEFAULT NULL COMMENT '操作金币',
  `status` tinyint(1) DEFAULT NULL COMMENT '0:待处理 1：处理中  2:已处理',
  `update_time` int(11) DEFAULT NULL COMMENT '处理时间',
  `update_uid` int(11) DEFAULT NULL COMMENT '处理人',
  PRIMARY KEY (`id`),
  KEY `idxuid` (`uid`),
  KEY `idxbankid` (`bankid`),
  KEY `idxtime` (`create_time`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin COMMENT='用户操作提现';

ALTER TABLE `d_user` 
ADD COLUMN `bindbank` tinyint(1) NULL DEFAULT 0 COMMENT '是否绑定银行' AFTER `countrycn`,
ADD COLUMN `bindupi` tinyint(1) NULL COMMENT '是否绑定upi' AFTER `bindbank`,
ADD COLUMN `bindusdt` tinyint(1) NULL COMMENT '是否绑定usdt' AFTER `bindupi`;