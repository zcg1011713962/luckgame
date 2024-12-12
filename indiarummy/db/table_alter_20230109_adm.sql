ALTER TABLE `indiarummy_game`.`d_mail` 
ADD COLUMN `remark` varchar(1024) NULL DEFAULT '' COMMENT '备注' AFTER `svip`;

ALTER TABLE `indiarummy_game`.`d_sys_mail` 
ADD COLUMN `remark` varchar(1024) NULL DEFAULT '' COMMENT '备注' AFTER `rate`;

ALTER TABLE `indiarummy_game`.`d_log_cashbonus` 
ADD COLUMN `remark` varchar(1024) NULL DEFAULT '' COMMENT '备注' AFTER `useruid`;

ALTER TABLE `indiarummy_game`.`coin_log` 
MODIFY COLUMN `log` varchar(1024) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL DEFAULT '' COMMENT '备注' AFTER `after_coin`;

ALTER TABLE `indiarummy_game`.`d_user_login_log` 
ADD INDEX `idx_ip`(`ip`),
ADD INDEX `idx_ddid`(`ddid`(100));

ALTER TABLE `indiarummy_game`.`d_firebase_msg` 
ADD COLUMN `content` varchar(1024) NULL DEFAULT '' COMMENT '内容' AFTER `update_time`,
ADD COLUMN `img` varchar(255) NULL DEFAULT '' COMMENT '图片地址' AFTER `content`;

ALTER TABLE `indiarummy_game`.`d_sys_mail` 
ADD COLUMN `creator` varchar(255) NULL DEFAULT '' COMMENT '发件人' AFTER `remark`;

ALTER TABLE `indiarummy_game`.`d_mail` 
ADD COLUMN `creator` varchar(255) NULL DEFAULT '' COMMENT '发件人' AFTER `remark`;