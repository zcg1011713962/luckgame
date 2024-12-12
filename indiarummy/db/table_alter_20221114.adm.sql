delete from d_quest where questid=3;

ALTER TABLE `indiarummy_game`.`d_main_task` 
DROP COLUMN `is_show`,
DROP COLUMN `vipstate`;

DROP TABLE IF EXISTS `d_main_task_log`;
CREATE TABLE `d_main_task_log` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `uid` bigint(20) DEFAULT NULL COMMENT 'uid',
  `taskid` int(11) DEFAULT NULL,
  `create_time` int(11) DEFAULT NULL,
  `type` int(11) DEFAULT NULL  COMMENT '任务类型',
  PRIMARY KEY (`id`),
  KEY `time` (`uid`,`create_time`),
  KEY `stat` (`taskid`,`create_time`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin COMMENT='每日任务完成日志';

DROP TABLE IF EXISTS `d_main_task_stat`;
CREATE TABLE `d_main_task_stat` (
  `id` int(11) DEFAULT NULL,
  `day` date DEFAULT NULL,
  `taskid` int(11) DEFAULT NULL,
  `type` int(11) DEFAULT NULL,
  `total` int(11) DEFAULT NULL,
  `update_time` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `item` (`day`,`taskid`,`type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin COMMENT='每日任务完成统计表';

ALTER TABLE `indiarummy_game`.`d_main_task_stat` 
DROP INDEX `item`,
ADD INDEX `item`(`day`, `type`) USING BTREE;

ALTER TABLE `indiarummy_game`.`s_pay_cfg_drawcom` 
ADD COLUMN `times` int(11) NULL DEFAULT 0 COMMENT '单词最大次数' AFTER `maxcoin`,
ADD COLUMN `intervel` int(11) NULL DEFAULT 0 COMMENT '单词间隔分钟数' AFTER `times`,
ADD COLUMN `svip` varchar(255) NULL COMMENT 'vip层级' AFTER `intervel`;

ALTER TABLE `indiarummy_game`.`s_pay_cfg_drawcom` 
ADD COLUMN `icon` varchar(255) NULL COMMENT 'Icon' AFTER `title`;
ALTER TABLE `indiarummy_game`.`s_pay_cfg_drawcom` 
MODIFY COLUMN `icon` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NULL DEFAULT '' COMMENT 'Icon' AFTER `title`;

ALTER TABLE `indiarummy_game`.`s_game` 
ADD COLUMN `svip` varchar(255) NULL DEFAULT "0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20," COMMENT 'svip' AFTER `aijoin`;
update s_game set svip="0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,";

ALTER TABLE `indiarummy_game`.`d_user_draw` 
ADD COLUMN `channelid` int(11) NULL COMMENT '提现渠道id' AFTER `taxthird`;

ALTER TABLE `indiarummy_game`.`d_user_draw` 
MODIFY COLUMN `status` int(11) NULL DEFAULT 0 COMMENT '-1: 拒绝出款 0:待处理 1：处理中  2:已处理' AFTER `coin`,
MODIFY COLUMN `memo` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_bin NULL DEFAULT NULL COMMENT '取款备注' AFTER `uuid`,
ADD COLUMN `chanstate` int(11) NULL DEFAULT 0 COMMENT '渠道出款状态, -1:出款失败,0:待处理 1:出款中 2:已出款' AFTER `channelid`,
ADD COLUMN `memo2` varchar(255) NULL COMMENT '用户备注' AFTER `chanstate`;

ALTER TABLE `indiarummy_game`.`d_user_draw` 
DROP COLUMN `verify_status`;

ALTER TABLE `indiarummy_game`.`d_user_draw` 
ADD COLUMN `acttype` tinyint(1) NULL DEFAULT 0 COMMENT '出款类型 1:手动 2:自动' AFTER `memo2`;

ALTER TABLE `indiarummy_game`.`d_user_draw` 
MODIFY COLUMN `status` int(11) NULL DEFAULT 0 COMMENT '0:待处理 1：处理中  2:已处理 3:拒绝' AFTER `coin`,
MODIFY COLUMN `chanstate` int(11) NULL DEFAULT 0 COMMENT '渠道出款状态,0:待处理 1:出款中 2:已出款 3:出款失败' AFTER `channelid`;

ALTER TABLE `indiarummy_game`.`d_user_draw` 
ADD COLUMN `agentno` varchar(32) NULL COMMENT '第3方订单号' AFTER `acttype`;
ALTER TABLE `indiarummy_game`.`d_user_draw` 
ADD COLUMN `notify_time` int(11) NULL COMMENT '第3方通知时间' AFTER `agentno`;

ALTER TABLE `indiarummy_game`.`d_user_draw` 
MODIFY COLUMN `backcoin` decimal(20, 2) NULL DEFAULT 0 COMMENT '到账金额' AFTER `type`,
MODIFY COLUMN `tax` decimal(20, 2) NULL DEFAULT 0 COMMENT '税' AFTER `backcoin`,
MODIFY COLUMN `taxthird` decimal(20, 2) NULL DEFAULT 0 COMMENT '第3方税' AFTER `tax`,
MODIFY COLUMN `channelid` int(11) NULL DEFAULT 0 COMMENT '提现渠道id' AFTER `taxthird`,
MODIFY COLUMN `memo2` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_bin NULL DEFAULT '' COMMENT '用户备注' AFTER `chanstate`,
MODIFY COLUMN `agentno` varchar(32) CHARACTER SET utf8mb4 COLLATE utf8mb4_bin NULL DEFAULT '' COMMENT '第3方订单号' AFTER `acttype`,
MODIFY COLUMN `notify_time` int(11) NULL DEFAULT 0 COMMENT '第3方通知时间' AFTER `agentno`;