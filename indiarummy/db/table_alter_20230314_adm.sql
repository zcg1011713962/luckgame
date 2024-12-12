DROP TABLE IF EXISTS `account_agent`;
CREATE TABLE `account_agent` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `username` varchar(255) COLLATE utf8mb4_bin DEFAULT NULL COMMENT '后台账号用户名',
  `password` varchar(32) COLLATE utf8mb4_bin DEFAULT NULL COMMENT '密码密文',
  `status` tinyint(1) DEFAULT '1' COMMENT '1可用 0不可用',
  `salt` char(6) COLLATE utf8mb4_bin DEFAULT NULL COMMENT '随机盐值',
  `agentids` int(11) DEFAULT '0' COMMENT '关联的代理id个数',
  `channelids` int(11) DEFAULT NULL COMMENT '渠道个数',
  `nickname` varchar(255) COLLATE utf8mb4_bin DEFAULT NULL COMMENT '昵称',
  `phone` varchar(255) COLLATE utf8mb4_bin DEFAULT NULL COMMENT '电话',
  `remark` varchar(255) COLLATE utf8mb4_bin DEFAULT NULL COMMENT '备注',
  `create_time` int(11) DEFAULT NULL COMMENT '创建时间',
  `uid` int(11) DEFAULT NULL COMMENT '创建时间',
  PRIMARY KEY (`id`),
  KEY `idx_username` (`username`(32))
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin COMMENT='2b后台账号表';

DROP TABLE IF EXISTS `account_channel`;
CREATE TABLE `account_channel` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `title` varchar(255) COLLATE utf8mb4_bin DEFAULT NULL COMMENT '渠道名称',
  `token` varchar(255) COLLATE utf8mb4_bin DEFAULT NULL COMMENT '临时token',
  `uid` int(11) DEFAULT '0',
  `create_time` int(11) DEFAULT '0',
  `uuid` int(11) DEFAULT '0',
  `update_time` int(11) DEFAULT '0',
  `accountid` int(11) DEFAULT '0' COMMENT '账号id',
  `remark` varchar(255) COLLATE utf8mb4_bin DEFAULT NULL COMMENT '备注',
  PRIMARY KEY (`id`),
  KEY `idx_account` (`accountid`)
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin COMMENT='渠道配置信息';