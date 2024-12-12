ALTER TABLE `s_shop` 
CHANGE COLUMN `cuid` `uid` int(11) NULL DEFAULT 0 COMMENT '创建人uid' AFTER `status`,
ADD COLUMN `create_time` int(11) NULL AFTER `oamount`,
ADD COLUMN `update_time` int(11) NULL AFTER `create_time`;

ALTER TABLE `d_user_bank` 
ADD COLUMN `usdttype` int(11) NULL DEFAULT 1 COMMENT 'usdt类型 1:usdt' AFTER `status`,
ADD COLUMN `title` varchar(255) NULL DEFAULT '' COMMENT '名称' AFTER `usdttype`,
ADD COLUMN `update_time` int(11) NULL AFTER `title`,
ADD COLUMN `uuid` int(11) NULL AFTER `update_time`;

DROP TABLE IF EXISTS `s_config_pics`;
CREATE TABLE `s_config_pics` (
  `id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `img` varchar(255) DEFAULT '' COMMENT '图片地址',
  `status` tinyint(1) DEFAULT NULL COMMENT '状态: 1:有效 0:无效',
  `url` varchar(255) DEFAULT NULL COMMENT '跳转地址',
  `ord` int(11) DEFAULT NULL COMMENT '排序，越小越靠前',
  `title` varchar(255) DEFAULT NULL COMMENT '备注',
  `uid` int(11) DEFAULT NULL,
  `create_time` int(11) DEFAULT NULL,
  `uuid` int(11) DEFAULT NULL,
  `update_time` int(11) DEFAULT NULL,
  `cat` tinyint(1) DEFAULT NULL COMMENT '1大厅,2充值,3提现,4优惠',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=5 DEFAULT CHARSET=utf8mb4 COMMENT='广告图配置';

DROP TABLE IF EXISTS `s_config_amount`;
CREATE TABLE `s_config_amount` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `amount` int(11) DEFAULT NULL COMMENT '快捷金额',
  `status` tinyint(1) DEFAULT NULL,
  `uid` int(11) DEFAULT NULL,
  `create_time` int(11) DEFAULT NULL,
  `uuid` int(11) DEFAULT NULL,
  `update_time` int(11) DEFAULT NULL,
  `type` tinyint(1) DEFAULT '2' COMMENT '2:充值 3:提现',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin COMMENT='快捷金额设置';

ALTER TABLE `d_user` 
ADD COLUMN `dcashbonus` decimal(20, 2) NULL COMMENT '可提现的优惠余额' AFTER `dcoin`;

ALTER TABLE `s_config_kill` 
MODIFY COLUMN `totalbet` bigint(20) NULL DEFAULT 0 COMMENT '总投注额' AFTER `stopcoin`,
MODIFY COLUMN `totalprofit` bigint(20) NULL DEFAULT 0 COMMENT '总盈利' AFTER `totalbet`;

ALTER TABLE `d_user` 
ADD COLUMN `kyc` tinyint(1) NULL DEFAULT 0 COMMENT '是否通过kyc验证' AFTER `forbidfriend`;

ALTER TABLE `s_pay_group` 
ADD COLUMN `recommend` tinyint(1) NULL DEFAULT 0 COMMENT '是否推荐 1是' AFTER `update_time`;

ALTER TABLE `d_user_recharge` 
ADD COLUMN `utrnum` varchar(255) NULL DEFAULT '' COMMENT 'utrnum' AFTER `rate`;

ALTER TABLE `d_user_recharge` 
MODIFY COLUMN `disrate` float(5, 3) NULL DEFAULT 0.000 COMMENT '优惠比例' AFTER `memo`;

ALTER TABLE `d_desk_user` 
ADD COLUMN `svip` int(11) NULL COMMENT 'svip等级' AFTER `uid`,
ADD COLUMN `tax` decimal(10, 2) NULL COMMENT '税率' AFTER `league`;

ALTER TABLE `d_user_recharge` 
ADD COLUMN `drate` varchar(255) NULL DEFAULT '' COMMENT 'usdt drate' AFTER `utrnum`,
ADD COLUMN `rsamount` varchar(255) NULL DEFAULT '' COMMENT 'usdt rsamount' AFTER `drate`;

update s_config set v='{"mobile":{"open":0,"ord":1,"title":"Mobile","icon":"icon-mobile"},"pan":{"open":0,"ord":3,"title":"Pan Card","icon":"icon-idcard"},"bank":{"open":0,"ord":2,"title":"Bank Card","icon":"icon-bank"}}' where k='kycverify';
ALTER TABLE `d_diamond_log` 
MODIFY COLUMN `coin` decimal(20, 2) NULL DEFAULT 0 COMMENT '携带金币数' AFTER `afterdiamond`;

ALTER TABLE `d_kyc` 
MODIFY COLUMN `status` tinyint(1) NULL DEFAULT 1 COMMENT '1:申请 2:审核中 3:通过 4:拒绝' AFTER `pic1`,
ADD COLUMN `category` tinyint(1) NULL DEFAULT 1 COMMENT '1:手机号2pan 3bank' AFTER `update_time`;