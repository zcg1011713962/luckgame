DROP TABLE IF EXISTS `d_promo`;
CREATE TABLE `d_promo` (
  `id` int NOT NULL AUTO_INCREMENT,
  `title` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT '' COMMENT '活动名',
  `ord` int DEFAULT NULL COMMENT '排序，越小越靠前',
  `svip` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '特定的支付vip等级才展示',
  `banner` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT '' COMMENT '入口图片地址',
  `memo` varchar(1000) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '描述图片地址',
  `status` tinyint(1) DEFAULT '0' COMMENT '是否有效',
  `uid` int DEFAULT NULL,
  `create_time` int DEFAULT NULL COMMENT '创建时间戳',
  `uuid` int DEFAULT NULL,
  `update_time` int DEFAULT NULL COMMENT '更新时间',
  PRIMARY KEY (`id`),
  KEY `idx_ord` (`ord`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='优惠活动入口';

insert into s_config(k,v,memo) value('promo_open', 1,'促销展示开关'); -- 系统配置中的促销展示开关

ALTER TABLE `indiarummy_game`.`d_user_recharge` ADD COLUMN `otherid` int NULL DEFAULT 0 COMMENT '第3方id' AFTER `groupid`;

ALTER TABLE `indiarummy_game`.`d_user_draw` 
ADD COLUMN `lock_uid` int NULL DEFAULT 0 COMMENT '锁定的uid' AFTER `readed`,
ADD COLUMN `lock_time` int NULL COMMENT '锁定的时间戳' AFTER `lock_uid`;

DROP TABLE IF EXISTS `d_discount_label`;
CREATE TABLE `d_discount_label` (
  `id` int NOT NULL AUTO_INCREMENT,
  `title` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '标签名称',
  `memo` varchar(1000) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '标签备注',
  `discount` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '不享受的优惠列表',
  `status` tinyint(1) DEFAULT '1' COMMENT '是否有效',
  `uid` int DEFAULT NULL,
  `create_time` int DEFAULT NULL,
  `uuid` int DEFAULT NULL,
  `update_time` int DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='无优惠标签';

ALTER TABLE `indiarummy_game`.`d_user` 
ADD COLUMN `nodislabelid` int NULL DEFAULT 0 COMMENT '无优惠标签id' AFTER `logintype`;

ALTER TABLE `indiarummy_game`.`s_pay_bank` 
ADD COLUMN `nodislabelid` int NULL DEFAULT 0 COMMENT '无优惠标签id' AFTER `screenshot`;

ALTER TABLE `indiarummy_game`.`s_pay_cfg_channel` 
ADD COLUMN `nodislabelid` int NULL DEFAULT 0 COMMENT '无优惠标签id' AFTER `screenshot`;

ALTER TABLE `indiarummy_game`.`s_pay_cfg_drawcom` 
ADD COLUMN `nodislabelid` int NULL DEFAULT 0 COMMENT '无优惠标签通道id' AFTER `update_time`;

ALTER TABLE `indiarummy_game`.`s_pay_cfg_draw` 
ADD COLUMN `mincoin` int NULL DEFAULT 0 COMMENT '最小金额' AFTER `status`,
ADD COLUMN `maxcoin` bigint NULL DEFAULT 1000000 COMMENT '最大提现金额限制' AFTER `mincoin`;

update  `indiarummy_game`.`s_pay_cfg_draw` set `type`=1 where `type`='BANK';
update  `indiarummy_game`.`s_pay_cfg_draw` set `type`=2 where `type`='USDT';
ALTER TABLE `indiarummy_game`.`s_pay_cfg_draw` 
MODIFY COLUMN `type` int NULL DEFAULT 1 COMMENT '类型' AFTER `ord`;

-- 新包appid 19 专用
ALTER TABLE `indiarummy_game`.`d_user` 
ADD COLUMN `ckrechargecoin` bigint NULL DEFAULT 0 COMMENT '充值金额' AFTER `nodislabelid`,
ADD COLUMN `cksendcoin` bigint NULL DEFAULT 0 COMMENT '赠送金额' AFTER `ckrechargecoin`;

insert into s_config (k,v,memo) value('check_recharge',1,'充值金额稽核倍数');
insert into s_config (k,v,memo) value('check_discount',2,'优惠金额稽核倍数');
insert into s_config (k,v,memo) value('check_stop',50,'停止稽核阔值');