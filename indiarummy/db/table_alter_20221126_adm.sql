ALTER TABLE `indiarummy_adm`.`stat_market_day` 
MODIFY COLUMN `payamount` double(20, 4) NULL DEFAULT NULL COMMENT '付费金额' AFTER `payrate`,
MODIFY COLUMN `pay2amount` double(20, 4) NULL DEFAULT NULL COMMENT '多次付费金额' AFTER `paynum`,
MODIFY COLUMN `payfirstamount` double(20, 4) NULL DEFAULT 0.00 COMMENT '首次付费金额' AFTER `payfirstnum`;

ALTER TABLE `indiarummy_adm`.`stat_market_day` 
ADD COLUMN `slot_num` int(11) NULL COMMENT 'slots人数' AFTER `vip_num`,
ADD COLUMN `slot_per_big` float(8, 2) NULL COMMENT 'slots人均局数' AFTER `slot_num`;

update d_user set diamond=0;

ALTER TABLE `indiarummy_adm`.`stat_user_coin_data` 
CHANGE COLUMN `coin_2k_down` `coin_1k_2k` int(11) NULL DEFAULT 0 COMMENT '金币1k-2k' AFTER `total_number`,
ADD COLUMN `coin_500_down` int(11) NULL COMMENT '金币500以下用户' AFTER `total_number`,
ADD COLUMN `coin_500_1k` int(11) NULL COMMENT '金币500-1k' AFTER `coin_500_down`;

ALTER TABLE `indiarummy_game`.`d_log_sign` 
ADD INDEX `time`(`create_time`);

ALTER TABLE `indiarummy_game`.`d_lb_reward_log` 
ADD INDEX `time`(`create_time`);

ALTER TABLE `indiarummy_game`.`d_commission` 
ADD INDEX `idx_time`(`create_time`);

ALTER TABLE `indiarummy_game`.`d_private_room_income` 
ADD INDEX `idx_time`(`create_time`);

DROP TABLE IF EXISTS `d_stat_coin`;
CREATE TABLE `d_stat_coin` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `create_time` int(11) DEFAULT '0' COMMENT '统计日期对应的时间戳',
  `out_newgift` decimal(20,4) DEFAULT '0.0000' COMMENT '产出:新手礼包',
  `out_bonus_sign` decimal(20,4) DEFAULT '0.0000' COMMENT '产出:签到',
  `out_bonus_share` decimal(20,4) DEFAULT '0.0000' COMMENT '产出:转盘分享',
  `out_bonus_rake` decimal(20,4) DEFAULT '0.0000' COMMENT '产出:下注返水',
  `out_bonus_quest` decimal(20,4) DEFAULT '0.0000' COMMENT '产出:任务奖励',
  `out_vip` decimal(20,4) DEFAULT '0.0000' COMMENT '产出:vip奖励',
  `out_rank` decimal(20,4) DEFAULT '0.0000' COMMENT '产出:排行榜派奖',
  `out_agent` decimal(20,4) DEFAULT '0.0000' COMMENT '产出:代理返现',
  `out_order_recharge` decimal(20,4) DEFAULT '0.0000' COMMENT '产出:充值',
  `out_order_send` decimal(20,4) DEFAULT '0.0000' COMMENT '产出:充值赠送',
  `out_salon_tax` decimal(20,4) DEFAULT '0.0000' COMMENT '产出:沙龙返水给房主',
  `out_admin` decimal(20,4) DEFAULT '0.0000' COMMENT '产出:后台充值',
  `in_win` decimal(20,4) DEFAULT '0.0000' COMMENT '回收:系统输赢',
  `in_tax` decimal(20,4) DEFAULT '0.0000' COMMENT '回收:系统抽水',
  `in_prop` decimal(20,4) DEFAULT '0.0000' COMMENT '回收:道具消耗',
  `update_time` int(11) DEFAULT '0' COMMENT '更新时间',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin COMMENT='系统金币统计';