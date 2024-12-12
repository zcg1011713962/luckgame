ALTER TABLE `indiarummy_game`.`d_kyc` ADD COLUMN `admid` int NULL DEFAULT 0 COMMENT '管理员id' AFTER `birthday`;

ALTER TABLE `indiarummy_game`.`d_safe_user` ADD COLUMN `status` tinyint(1) NULL DEFAULT 1 COMMENT '是否异常用户' AFTER `cxtimes`;