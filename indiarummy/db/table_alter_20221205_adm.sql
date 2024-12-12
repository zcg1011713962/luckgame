ALTER TABLE `indiarummy_adm`.`sys_globalnotice` 
ADD COLUMN `svip` varchar(255) NULL DEFAULT '' COMMENT '支付vip等级' AFTER `create_time`;