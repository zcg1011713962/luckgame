CREATE TABLE `s_config_vip_bonus`  (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `level` int(11) NULL COMMENT 'vip等级',
  `trate` int(11) NULL COMMENT '可转移百分比, 千分位',
  `maxcoin` bigint(20) NULL COMMENT '优惠金额最高限额',
  `days` int(11) NULL COMMENT '可使用天数',
  PRIMARY KEY (`id`),
  INDEX `idex_level`(`level`)
) COMMENT = 'Vip 优惠金额配置';

ALTER TABLE `d_user` ADD COLUMN `ourself` tinyint(1) NULL COMMENT '是否自己人，推荐给其他人加好友' AFTER `suspendagent`;

drop table s_stamp;
drop table s_stamp_album;
drop table s_stamp_package;
drop table s_stamp_session;
drop table s_stamp_shop;

drop table s_herocamp;
drop table s_herocard;
drop table s_herocard_betidx_drop_coeff;
drop table s_herocard_card_drop;
drop table s_herocard_common_drop;
drop table s_herocard_game_drop;
drop table s_herocard_level;
drop table s_herocard_skill;
drop table s_herocard_star;

alter table s_customer rename as s_config_customer;
drop table s_record_control;
drop table poolround_log;

ALTER TABLE `s_game` 
DROP COLUMN `robotcoin`,
DROP COLUMN `bankercoin`,
DROP COLUMN `storage`,
DROP COLUMN `newmark`,
DROP COLUMN `newstorage`,
DROP COLUMN `targetstorage`,
DROP COLUMN `targetminrate`,
DROP COLUMN `winrate`,
DROP COLUMN `loserate`,
DROP COLUMN `storaterate`,
DROP COLUMN `iscontrol`,
DROP COLUMN `robot`,
DROP COLUMN `apply_coin`,
DROP COLUMN `bet_mincoin`,
DROP COLUMN `version`,
DROP COLUMN `cuid`;

DROP TABLE IF EXISTS `s_tax`;
DROP TABLE IF EXISTS `d_tax`;
CREATE TABLE `d_tax` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `gameid` int(11) DEFAULT '0' COMMENT '游戏id',
  `ssid` tinyint(1) DEFAULT '0' COMMENT '场次id',
  `deskid` varchar(8) DEFAULT NULL COMMENT '房间号',
  `uuid` varchar(32) DEFAULT '' COMMENT '唯一id',
  `uid` bigint(20) DEFAULT '0' COMMENT '玩家id',
  `coin` bigint(20) DEFAULT NULL,
  `create_time` int(11) DEFAULT '0' COMMENT '添加时间',
  PRIMARY KEY (`id`),
  KEY `idx_deskid` (`deskid`),
  KEY `idx_create_time` (`create_time`),
  KEY `idx_uuid` (`uuid`)
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8mb4 ROW_FORMAT=DYNAMIC COMMENT='税收记录';

drop table tmp_nickname;
ALTER TABLE `s_game` DROP COLUMN `aicontrol`;

ALTER TABLE `s_game` 
ADD COLUMN `aijoin` tinyint(1) NULL COMMENT '是否加入ai' AFTER `firstbet`,
ADD COLUMN `aiwinrate` int(11) NULL COMMENT '千分位' AFTER `aijoin`;


ALTER TABLE `d_user` 
MODIFY COLUMN `coin` decimal(20, 2) UNSIGNED NULL DEFAULT NULL COMMENT 'cash coin' AFTER `create_platform`,
MODIFY COLUMN `dcoin` decimal(20, 2) NULL DEFAULT NULL COMMENT 'draw coin' AFTER `coin`;

ALTER TABLE `d_tax` 
MODIFY COLUMN `coin` decimal(20, 2) NULL DEFAULT NULL COMMENT '抽水' AFTER `uid`;

ALTER TABLE `coin_log` 
MODIFY COLUMN `before_coin` decimal(20, 2) UNSIGNED NOT NULL DEFAULT 0 COMMENT '变动前分数' AFTER `game_id`,
MODIFY COLUMN `coin` decimal(20, 2) UNSIGNED NOT NULL DEFAULT 0 COMMENT '变动分数' AFTER `before_coin`,
MODIFY COLUMN `after_coin` decimal(20, 2) UNSIGNED NOT NULL DEFAULT 0 COMMENT '变动后分数' AFTER `coin`;

ALTER TABLE `d_desk_user` 
MODIFY COLUMN `wincoin` decimal(20, 2) NULL DEFAULT NULL COMMENT '赢的金币' AFTER `win`,
MODIFY COLUMN `bet` decimal(20, 2) NULL DEFAULT 0 COMMENT '押注' AFTER `exited`;

ALTER TABLE `d_user_draw` 
MODIFY COLUMN `coin` decimal(20, 2) UNSIGNED NULL DEFAULT NULL COMMENT '操作金币' AFTER `account`;

ALTER TABLE `d_bank` 
MODIFY COLUMN `coin` decimal(20, 2) UNSIGNED NULL DEFAULT 0 COMMENT '银行余额' AFTER `uid`;

ALTER TABLE `s_game` 
ADD COLUMN `taxrate` int(11) NULL COMMENT '千分位' AFTER `aiwinrate`;