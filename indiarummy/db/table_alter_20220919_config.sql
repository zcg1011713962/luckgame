DROP TABLE IF EXISTS `s_config_sms`;
CREATE TABLE `s_config_sms` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `title` varchar(255) COLLATE utf8mb4_bin DEFAULT NULL COMMENT '名称',
  `url` varchar(255) COLLATE utf8mb4_bin DEFAULT NULL COMMENT '接口地址',
  `accesskey` varchar(255) COLLATE utf8mb4_bin DEFAULT NULL COMMENT 'accesskey',
  `secretkey` varchar(255) COLLATE utf8mb4_bin DEFAULT NULL COMMENT 'secretkey',
  `code` varchar(255) COLLATE utf8mb4_bin DEFAULT NULL COMMENT '通道',
  `status` tinyint(1) DEFAULT NULL COMMENT '1:启用 2:待定 3:停用',
  `weight` int(11) DEFAULT NULL COMMENT '优先级，大的优先',
  `cuid` int(11) DEFAULT NULL,
  `create_time` int(11) DEFAULT NULL,
  `uuid` int(11) DEFAULT NULL,
  `update_time` int(11) DEFAULT NULL,
  `callmethod` tinyint(1) DEFAULT NULL COMMENT '1:post 2:get',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin COMMENT='短信通道配置';

INSERT INTO `s_config_sms` (`id`, `title`, `url`, `accesskey`, `secretkey`, `code`, `status`, `weight`, `cuid`, `create_time`, `uuid`, `update_time`, `callmethod`) VALUES (1, 'kmicloud', 'http://api.kmicloud.com/sms/send/v1/otp', '0c5d4f31b5694778bd1e31fedbf22c51', '734818a742414281a1c5dcebd8c2e3f7', NULL, 1, 100, 100, NULL, NULL, NULL, NULL);
INSERT INTO `s_config_sms` (`id`, `title`, `url`, `accesskey`, `secretkey`, `code`, `status`, `weight`, `cuid`, `create_time`, `uuid`, `update_time`, `callmethod`) VALUES (2, '传信云', 'http://47.242.85.7:9090/sms/batch/v2', 'bMkYVw', 'fNH3D6', '1000', 1, 90, 100100, NULL, NULL, NULL, NULL);

ALTER TABLE `s_config_sms` ADD COLUMN `ext` varchar(300) NULL COMMENT '其他配置' AFTER `callmethod`;

ALTER TABLE `s_config_sms` ADD COLUMN `classname` varchar(255) NULL COMMENT '代码类名' AFTER `ext`;


--修改奖品配置 type:count:img:days
--签到
update s_sign_vip set prize='44:1:chat_002:5' where id=1;
update s_sign_vip set prize='54:5:gift_1' where id=2;
update s_sign_vip set prize='54:1:gift_tea' where id=3;
update s_sign_vip set prize='54:6:gift_4' where id=4;
update s_sign_vip set prize='54:2:gift_hookah' where id=5;
update s_sign_vip set prize='54:8:gift_5' where id=6;
update s_sign_vip set prize='54:2:gift_kiss|43:1:avatarframe_2004:7|44:1:chat_008:7' where id=7;

--每日任务
update s_quest set rewards='1:1000|54:5:gift_1' where id=1;
update s_quest set rewards='54:2:gift_4|54:1:gift_cake' where id=2;
update s_quest set rewards='54:2:gift_2|54:1:gift_tea' where id=3;
update s_quest set rewards='54:2:gift_3|55:1:exp_25' where id=4;
update s_quest set rewards='1:2000|54:2:gift_kiss' where id=5;
update s_quest set rewards='54:3:gift_4|54:3:gift_6' where id=6;
update s_quest set rewards='54:3:gift_3|54:3:gift_5' where id=7;

--新手任务
update s_quest set rewards='1:10000|54:3:gift_tea' where id=130;
update s_quest set rewards='54:3:gift_car' where id=134;
update s_quest set rewards='1:5000|54:1:gift_kiss' where id=135;
update s_quest set rewards='1:2000' where id=140;
update s_quest set rewards='43:1:avatarframe_1002:3|54:2:gift_car' where id=141;
update s_quest set rewards='54:1:gift_hookah' where id=142;
update s_quest set rewards='54:1:gift_cake' where id=144;


CREATE TABLE `d_user_recharge`  (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `orderid` varchar(32) NULL COMMENT '订单号',
  `uid` bigint(20) NULL COMMENT 'uid',
  `coin` decimal(20, 2) NULL COMMENT '金币数',
  `before_coin` decimal(20, 2) NULL COMMENT '充值前金币',
  `svip` int(11) NULL COMMENT '充值时vip等级',
  `svipexp` int(11) NULL COMMENT '充值时vip经验值',
  `channelid` int(11) NULL COMMENT '通道id',
  `groupid` int(11) NULL COMMENT '通道组id',
  `status` tinyint(1) NULL COMMENT '0:刚创建 1:处理中 2：支付成功',
  `create_time` int(11) NULL COMMENT '下单时间',
  `pay_time` int(11) NULL COMMENT '到账时间',
  `uuid` int(11) NULL COMMENT '更新人',
  `update_time` int(11) NULL COMMENT '更新时间',
  PRIMARY KEY (`id`),
  INDEX `idx_orderid`(`orderid`),
  INDEX `idx_uid`(`uid`),
  INDEX `idx_time`(`create_time`)
) COMMENT = '用户充值订单';