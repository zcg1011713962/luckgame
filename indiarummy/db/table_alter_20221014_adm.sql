ALTER TABLE `d_kyc`
MODIFY COLUMN `status` tinyint(1) NULL DEFAULT 1 COMMENT '1:申请中 2:审核通过 3:拒绝' AFTER `pic1`;

ALTER TABLE `d_kyc` 
ADD COLUMN `birthday` varchar(255) NULL COMMENT '生日' AFTER `category`;