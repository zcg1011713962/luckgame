alter table `indiarummy_game`.d_log_order modify `memo` varchar(1024) default '' COMMENT '备注';
ALTER TABLE `indiarummy_game`.`d_log_order` 
ADD INDEX `idx_orderid`(`orderid`),
ADD INDEX `idx_time`(`create_time`);