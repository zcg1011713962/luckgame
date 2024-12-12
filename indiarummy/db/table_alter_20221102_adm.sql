ALTER TABLE `indiarummy_game`.`d_log_cashbonus` 
ADD COLUMN `orderid` varchar(32) NULL DEFAULT "" COMMENT '订单id' AFTER `id`;

ALTER TABLE `indiarummy_game`.`d_log_cashbonus` 
MODIFY COLUMN `uid` bigint(20) NULL DEFAULT NULL COMMENT 'uid' AFTER `category`,
ADD COLUMN `useruid` bigint(20) NULL DEFAULT 0 COMMENT '下级uid' AFTER `uid`;

ALTER TABLE `indiarummy_game`.`d_log_senddraw` 
ADD COLUMN `orderid` varchar(32) NULL COMMENT '订单id' AFTER `id`,
ADD COLUMN `useruid` bigint(20) NULL DEFAULT 0 COMMENT '下级uid' AFTER `uid`;