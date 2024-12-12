ALTER TABLE `d_safe_user` COMMENT = '新用户行为安全相关记录';
ALTER TABLE `d_safe_user` ADD COLUMN `fcmtimes` int(11) NULL DEFAULT 0 COMMENT '重复次数' AFTER `fcmhash`;
ALTER TABLE `d_safe_user` ADD COLUMN `gsftimes` int(11) NULL DEFAULT 0 COMMENT 'Gsf重复次数' AFTER `gsfhash`;
ALTER TABLE `d_safe_user` ADD COLUMN `ctxhash` varchar(32) CHARACTER SET utf8mb4 COLLATE utf8mb4_bin NULL DEFAULT NULL COMMENT '通讯录hash' AFTER `gsftimes`;
ALTER TABLE `d_safe_user` ADD COLUMN `ctxtimes` int(11) NULL DEFAULT 0 COMMENT '通讯录次数' AFTER `ctxhash`;
ALTER TABLE `d_safe_user` ADD COLUMN `device` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_bin NULL DEFAULT NULL COMMENT '机型' AFTER `ctxtimes`;
ALTER TABLE `d_safe_user` ADD COLUMN `regip` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_bin NULL DEFAULT NULL COMMENT '注册ip' AFTER `device`;
ALTER TABLE `d_safe_user` ADD COLUMN `regtime` int(11) NULL DEFAULT NULL COMMENT '注册时间' AFTER `regip`;
ALTER TABLE `d_safe_user` ADD COLUMN `username` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_bin NULL DEFAULT NULL COMMENT '名字' AFTER `regtime`;
ALTER TABLE `d_safe_user` ADD COLUMN `ddid` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_bin NULL DEFAULT '' COMMENT '设备号' AFTER `update_time`;
ALTER TABLE `d_safe_user` MODIFY COLUMN `gsfhash` varchar(32) CHARACTER SET utf8mb4 COLLATE utf8mb4_bin NULL DEFAULT NULL COMMENT 'Gsfid hash' AFTER `startlog`;
ALTER TABLE `d_safe_user` DROP COLUMN `contacthash`;
ALTER TABLE `d_safe_user` ADD INDEX `idx_fcmhash`(`fcmhash`) USING BTREE;
ALTER TABLE `d_safe_user` ADD INDEX `idx_gsf`(`gsfhash`) USING BTREE;
ALTER TABLE `d_safe_user` ADD INDEX `idx_device`(`device`(32)) USING BTREE;
ALTER TABLE `d_safe_user` ADD INDEX `idx_ctx`(`ctxhash`) USING BTREE;

ALTER TABLE `indiarummy_game`.`d_account_channel` 
ADD COLUMN `secretkey` varchar(255) NULL DEFAULT '' COMMENT 'appsfly秘钥' AFTER `code`,
ADD COLUMN `packagename` varchar(255) NULL COMMENT '包名' AFTER `secretkey`;

ALTER TABLE `indiarummy_adm`.`stat_user_coin_data` 
ADD COLUMN `agentaccid` int(11) NULL DEFAULT 0 COMMENT '代理后台账号id' AFTER `id`;

ALTER TABLE `indiarummy_adm`.`stat_user_coin_data` 
DROP INDEX `day`,
ADD UNIQUE INDEX `day`(`day`, `agentaccid`) USING BTREE;

ALTER TABLE `indiarummy_adm`.`stat_market_day` 
CHANGE COLUMN `adchannel` `agentaccid` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NULL DEFAULT NULL COMMENT '广告渠道' AFTER `Id`;
update stat_market_day set agentaccid=0;
ALTER TABLE `indiarummy_adm`.`stat_market_day` 
MODIFY COLUMN `agentaccid` int(11) NULL DEFAULT 0 COMMENT '广告渠道' AFTER `Id`;

ALTER TABLE `indiarummy_adm`.`stat_newuser_rate` 
ADD COLUMN `agentaccid` int(11) NULL DEFAULT 0 COMMENT '2b后台账号id, 默认官网为0' AFTER `id`;

ALTER TABLE `indiarummy_game`.`d_stat_coin` 
ADD COLUMN `agentaccid` int(11) NULL DEFAULT 0 COMMENT '2b后台账号id' AFTER `id`;
ALTER TABLE `indiarummy_game`.`d_stat_coin` 
ADD UNIQUE INDEX `idx_agentime`(`create_time`, `agentaccid`);

ALTER TABLE `indiarummy_game`.`d_safe_user` 
ADD COLUMN `cx` varchar(32) NULL COMMENT '底包中的cx' AFTER `ddid`,
ADD COLUMN `cxtimes` int(11) NULL DEFAULT 0 COMMENT '底包中cx的重复次数' AFTER `cx`,
ADD INDEX `idx_cx`(`cx`);

ALTER TABLE `indiarummy_game`.`d_safe_user` 
MODIFY COLUMN `cx` varchar(32) CHARACTER SET utf8mb4 COLLATE utf8mb4_bin NULL DEFAULT '' COMMENT '底包中的cx' AFTER `ddid`;