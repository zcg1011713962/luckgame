ALTER TABLE `indiarummy_game`.`d_log_sms` 
ADD COLUMN `title` varchar(255) NULL COMMENT '通道名' AFTER `status`;

ALTER TABLE `indiarummy_game`.`d_desk_user` 
MODIFY COLUMN `betinfo` varchar(3000) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NULL DEFAULT '' COMMENT '方位押注明细' AFTER `bet`;