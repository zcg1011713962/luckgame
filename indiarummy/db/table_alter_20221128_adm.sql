ALTER TABLE `indiarummy_game`.`d_user` 
ADD COLUMN `nevershowtips` tinyint(1) NULL DEFAULT 0 COMMENT '提现列表禁止弹框' AFTER `forbidnick`;

ALTER TABLE `indiarummy_game`.`s_pay_cfg_channel` 
ADD COLUMN `f_drate` float(3, 2) NULL COMMENT '首次充值优惠比例' AFTER `planid`,
ADD COLUMN `f_dcoin` decimal(20, 2) NULL COMMENT '首次充值优惠金额' AFTER `f_drate`,
ADD COLUMN `f_rate` varchar(255) NULL COMMENT '首次充值优惠比例分成字符串' AFTER `f_dcoin`,
ADD COLUMN `fd_drate` float(3, 2) NULL COMMENT '当天首充优惠比例' AFTER `f_rate`,
ADD COLUMN `fd_dcoin` decimal(20, 2) NULL COMMENT '当天首充优惠金额' AFTER `fd_drate`,
ADD COLUMN `fd_rate` varchar(255) NULL COMMENT '当天首充优惠分成字符串' AFTER `fd_dcoin`;

ALTER TABLE `indiarummy_game`.`s_pay_bank` 
ADD COLUMN `f_drate` decimal(5, 4) NULL COMMENT '首次充值优惠' AFTER `rate`,
ADD COLUMN `f_dcoin` decimal(20, 2) NULL COMMENT '首次充值优惠金额' AFTER `f_drate`,
ADD COLUMN `f_rate` varchar(255) NULL COMMENT '首次充值优惠比例分成字符串' AFTER `f_dcoin`,
ADD COLUMN `fd_drate` decimal(5, 4) NULL COMMENT '当天首充优惠比例' AFTER `f_rate`,
ADD COLUMN `fd_dcoin` decimal(20, 2) NULL COMMENT '当天首充优惠金额' AFTER `fd_drate`,
ADD COLUMN `fd_rate` varchar(255) NULL COMMENT '当天首充优惠分成字符串' AFTER `fd_dcoin`,
ADD COLUMN `usdtrate` float(5, 2) NULL COMMENT 'usdt汇率' AFTER `ifsc`;

ALTER TABLE `indiarummy_game`.`d_user_recharge` 
CHANGE COLUMN `goodstype` `planid` tinyint NULL DEFAULT 0 COMMENT '优惠类型:1首次2每次3当天首次' AFTER `count`;

ALTER TABLE `indiarummy_game`.`s_pay_cfg_channel` 
MODIFY COLUMN `f_drate` float(3, 2) NULL DEFAULT 0 COMMENT '首次充值优惠比例' AFTER `planid`,
MODIFY COLUMN `f_dcoin` decimal(20, 2) NULL DEFAULT 0 COMMENT '首次充值优惠金额' AFTER `f_drate`,
MODIFY COLUMN `f_rate` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NULL DEFAULT "0:0:0" COMMENT '首次充值优惠比例分成字符串' AFTER `f_dcoin`,
MODIFY COLUMN `fd_drate` float(3, 2) NULL DEFAULT 0 COMMENT '当天首充优惠比例' AFTER `f_rate`,
MODIFY COLUMN `fd_dcoin` decimal(20, 2) NULL DEFAULT 0 COMMENT '当天首充优惠金额' AFTER `fd_drate`,
MODIFY COLUMN `fd_rate` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NULL DEFAULT "0:0:0" COMMENT '当天首充优惠分成字符串' AFTER `fd_dcoin`,
MODIFY COLUMN `discoin` decimal(20, 2) NULL DEFAULT 0 COMMENT '优惠固定金额' AFTER `disrate`,
MODIFY COLUMN `rate` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NULL DEFAULT "0:0:0" COMMENT '分成占比' AFTER `discoin`;

ALTER TABLE `indiarummy_game`.`d_commission` 
MODIFY COLUMN `coin1` decimal(20, 2) NULL DEFAULT 0 COMMENT '给上级的贡献' AFTER `pparentid`,
MODIFY COLUMN `coin2` decimal(20, 2) NULL DEFAULT 0 COMMENT '给上上级的贡献' AFTER `coin1`;

update d_mail_tpl set param1=3 where id=1;

ALTER TABLE `indiarummy_game`.`s_pay_bank` 
ADD COLUMN `discoin` decimal(20, 2) NULL DEFAULT 0 COMMENT '固定优惠金额' AFTER `bankname`,
MODIFY COLUMN `disrate` decimal(5, 4) NULL DEFAULT 0 COMMENT '优惠比例' AFTER `bankname`,
MODIFY COLUMN `rate` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NULL DEFAULT "0:0:0" COMMENT '优惠分成比例' AFTER `disrate`,
MODIFY COLUMN `f_drate` decimal(5, 4) NULL DEFAULT 0 COMMENT '首次充值优惠' AFTER `rate`,
MODIFY COLUMN `f_dcoin` decimal(20, 2) NULL DEFAULT 0 COMMENT '首次充值优惠金额' AFTER `f_drate`,
MODIFY COLUMN `f_rate` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NULL DEFAULT "0:0:0" COMMENT '首次充值优惠比例分成字符串' AFTER `f_dcoin`,
MODIFY COLUMN `fd_drate` decimal(5, 4) NULL DEFAULT 0 COMMENT '当天首充优惠比例\n' AFTER `f_rate`,
MODIFY COLUMN `fd_dcoin` decimal(20, 2) NULL DEFAULT 0 COMMENT '当天首充优惠金额' AFTER `fd_drate`,
MODIFY COLUMN `fd_rate` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NULL DEFAULT "0:0:0" COMMENT '当天首充优惠分成字符串' AFTER `fd_dcoin`;