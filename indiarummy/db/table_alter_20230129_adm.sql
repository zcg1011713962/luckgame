ALTER TABLE `indiarummy_game`.`d_user` 
MODIFY COLUMN `kycfield` int(11) NULL DEFAULT 0 COMMENT 'Kyc审核类型' AFTER `kyc`;

CREATE TABLE `d_log_sms` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `uid` bigint(20) DEFAULT NULL,
  `phone` varchar(32) COLLATE utf8mb4_bin DEFAULT NULL COMMENT '手机号',
  `remark` varchar(1024) COLLATE utf8mb4_bin DEFAULT '' COMMENT '备注',
  `create_time` int(11) DEFAULT NULL COMMENT '创建时间',
  `status` tinyint(1) DEFAULT '1' COMMENT '请求发送状态',
  PRIMARY KEY (`id`),
  KEY `time` (`create_time`,`phone`),
  KEY `uid` (`uid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin COMMENT='短信发送记录';

ALTER TABLE `indiarummy_game`.`d_kyc` 
ADD COLUMN `svip` int(11) NULL DEFAULT 0 COMMENT '支付vip等级' AFTER `uid`;

CREATE TABLE `d_stat_profit` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `create_time` int(11) DEFAULT NULL,
  `day` varchar(8) COLLATE utf8mb4_bin DEFAULT NULL COMMENT '日期',
  `total_users` int(11) DEFAULT NULL COMMENT '总会员数',
  `total_agents` int(11) DEFAULT NULL COMMENT '总代理人数',
  `dnu` int(11) DEFAULT NULL COMMENT '注册人数',
  `dau` int(11) DEFAULT NULL COMMENT '日活',
  `new_agents` int(11) DEFAULT NULL COMMENT '新增代理数',
  `game_users` int(11) DEFAULT NULL COMMENT '今日游戏人数',
  `betcoin` bigint(20) DEFAULT NULL COMMENT '今日下注',
  `wincoin` bigint(20) DEFAULT NULL COMMENT '今日中奖',
  `rechargesucc` bigint(20) DEFAULT NULL COMMENT '今日充值成功金额',
  `rechargecoin` bigint(20) DEFAULT NULL COMMENT '今日下单金额',
  `drawcoin` bigint(20) DEFAULT NULL COMMENT '今日提现金额',
  `drawsucc` bigint(20) DEFAULT NULL COMMENT '今日提现成功金额',
  `tax` double(10,2) DEFAULT NULL COMMENT '今日税收',
  `rebate` bigint(20) DEFAULT NULL COMMENT '今日返佣',
  PRIMARY KEY (`id`),
  KEY `idx_date` (`day`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin COMMENT='游戏核心数据统计';
ALTER TABLE `indiarummy_game`.`d_stat_profit` 
MODIFY COLUMN `betcoin` double(18, 2) NULL DEFAULT NULL COMMENT '今日下注' AFTER `game_users`,
MODIFY COLUMN `wincoin` double(18, 2) NULL DEFAULT NULL COMMENT '今日中奖' AFTER `betcoin`,
MODIFY COLUMN `rebate` double(18, 2) NULL DEFAULT NULL COMMENT '今日返佣' AFTER `tax`;

CREATE TABLE `d_stat_dau` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `create_time` int(11) DEFAULT NULL,
  `dau` int(11) DEFAULT '0' COMMENT 'Dau当前人数',
  PRIMARY KEY (`id`),
  KEY `idx_time` (`create_time`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin COMMENT='在线人数曲线记录';