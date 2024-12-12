ALTER TABLE `d_user_login_log` ADD COLUMN `login_coin` bigint(20) NULL COMMENT '登录时金币' AFTER `login_level`;

ALTER TABLE `coin_log` DROP INDEX `idx_state`, ADD INDEX `idx_time`(`time`) USING BTREE;

ALTER TABLE `d_user` ADD COLUMN `isbindphone` tinyint(1) NULL DEFAULT 0 COMMENT '是否绑定手机号' AFTER `bindusdt`;

ALTER TABLE `d_user_bind` ADD COLUMN `passwd` varchar(255) NULL DEFAULT '' COMMENT '加密过的密码' AFTER `create_time`;

ALTER TABLE `d_user` ADD COLUMN `suspendagent` tinyint(1) NULL COMMENT '暂停代理身份' AFTER `isbindphone`;

DROP TABLE IF EXISTS `d_user_tree`;
CREATE TABLE `d_user_tree` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `ancestor_id` bigint(20) unsigned NOT NULL COMMENT '祖先id',
  `descendant_id` bigint(20) unsigned NOT NULL COMMENT '自己id',
  `descendant_agent` tinyint(1) unsigned NOT NULL DEFAULT '0' COMMENT '自己代理级别',
  `ancestor_h` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '与祖先高度',
  PRIMARY KEY (`id`),
  KEY `ancestor_id` (`ancestor_id`),
  KEY `descendant_id` (`descendant_id`)
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8mb4 ROW_FORMAT=DYNAMIC COMMENT='账号-树关系';

insert into s_config (k,v,memo) value('invite','{"each":{"coin":50,"maxcoin":500},"recharge":{"begin":100,"level1":10,"level2":5},"bet":{"level1":10,"level2":5}}','邀请奖励配置');

DROP TABLE IF EXISTS `s_invite_domain`;
CREATE TABLE `s_invite_domain` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `domain` varchar(255) COLLATE utf8mb4_bin DEFAULT NULL COMMENT '域名',
  `status` tinyint(1) DEFAULT '1' COMMENT '状态:0:待审核 1:有效 2:无效',
  `create_time` int(11) DEFAULT NULL COMMENT '创建时间',
  `cuid` bigint(20) DEFAULT NULL COMMENT '创建人',
  `update_time` int(11) DEFAULT NULL COMMENT '更新时间',
  `uuid` bigint(20) DEFAULT NULL COMMENT '更新人',
  PRIMARY KEY (`id`),
  KEY `idx_time` (`create_time`)
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin COMMENT='分享域名配置表';

DROP TABLE IF EXISTS `d_commission`;
CREATE TABLE `d_commission`  (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `uid` bigint(20) NULL COMMENT 'uid',
  `betcoin` bigint(20) NULL COMMENT '下注金额',
  `bettimes` int(11) NULL COMMENT '游戏局数',
  `parentid` bigint(20) NULL COMMENT '上级uid',
  `pparentid` bigint(20) NULL COMMENT '上上级uid',
  `coin1` bigint(20) NULL COMMENT '给上级的贡献',
  `coin2` bigint(20) NULL COMMENT '给上上级的贡献',
  `create_time` int(11) NULL COMMENT '创建时间',
  PRIMARY KEY (`id`),
  INDEX `idx_pid_time`(`parentid`, `create_time`),
  INDEX `idx_uid`(`uid`)
) COMMENT = '佣金明细';

DROP TABLE IF EXISTS `d_user_recharge`;
CREATE TABLE `d_user_recharge`  (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `uid` bigint(20) NULL COMMENT '玩家id',
  `coin` bigint(20) NULL COMMENT '充值金币数',
  `send_coin` bigint(20) NULL COMMENT '赠送金币数',
  `before_coin` bigint(20) NULL COMMENT '之前金币数',
  `after_coin` bigint(20) NULL COMMENT '之后金币数',
  `create_time` int(11) NULL,
  `cuid` int(11) NULL,
  `cat` tinyint(1) NULL DEFAULT 1 COMMENT '1:线下 2:usdt',
  PRIMARY KEY (`id`),
  INDEX `idx_uid`(`create_time`, `uid`)
) COMMENT = '用户线下充值';

ALTER TABLE `d_desk_user` ADD COLUMN `betinfo` varchar(1000) NULL COMMENT '方位押注明细' AFTER `bet`;
ALTER TABLE `d_desk_user` ADD COLUMN `wincoin` bigint(20) NULL COMMENT '赢的金币' AFTER `win`;

ALTER TABLE `d_desk_game` ADD COLUMN `usernum` int(11) NULL COMMENT '用户人数' AFTER `status`;


ALTER TABLE `d_user` ADD COLUMN `dcoin` bigint(20) NULL COMMENT '可提现金额，单位分' AFTER `coin`;

insert into s_config (k,v,memo) value('sms_url','http://sms.yonogame.com/sms.php','短信通道');
