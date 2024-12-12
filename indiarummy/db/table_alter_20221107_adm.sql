ALTER TABLE `indiarummy_game`.`d_sys_mail` 
ADD COLUMN `svip` varchar(255) NULL COMMENT '支付vip层级' AFTER `msg_al`,
ADD COLUMN `rate` varchar(255) NULL COMMENT '奖励金额分配比例' AFTER `svip`;

ALTER TABLE `indiarummy_game`.`d_mail` 
ADD COLUMN `rate` varchar(255) NULL DEFAULT "" COMMENT '入各钱包的比例' AFTER `msg_al`;