update s_quest set `status`=0 where `type`=2;
update s_quest set `status`=0 where id!=3;
delete from d_quest where questid != 3;

update s_config set v='{"mobile":{"open":1,"ord":1,"title":"Mobile Number","icon":"icon-mobile","note":"For login options and customer service contact."},"pan":{"open":1,"ord":2,"title":"Pan Card","icon":"icon-idcard","note":"For safety and security of all transactions."},"bank":{"open":1,"ord":3,"title":"Bank Card","icon":"icon-bank","note":"For quick withdrawals to you bank account."}}' where k= 'kycverify';

insert into s_config(k, v, memo) values ('kycmemo', 'test','kyc memo');

ALTER TABLE `d_user_bank` ADD COLUMN `pic` varchar(255) NULL COMMENT '银行卡图片' AFTER `uuid`;

ALTER TABLE `d_user_bank` ADD COLUMN `upitype` tinyint(1) NULL DEFAULT 0 COMMENT '1 paytm 2phonepe 3gpay 4other' AFTER `pic`;

ALTER TABLE `s_config_vip_upgrade` ADD COLUMN `tranrate` decimal(5, 4) NULL DEFAULT 0 COMMENT 'bonus transfer rate' AFTER `update_time`,ADD COLUMN `trantimes` int(11) NULL DEFAULT 0 COMMENT '每日transfertimes' AFTER `tranrate`;

ALTER TABLE `d_user` 
MODIFY COLUMN `dcashbonus` decimal(20, 2) NULL DEFAULT 0.00 COMMENT '已提现的优惠余额' AFTER `dcoin`;

ALTER TABLE `s_config_vip_upgrade` ADD COLUMN `salonrooms` int(11) NULL COMMENT '沙龙房间数' AFTER `trantimes`,ADD COLUMN `salonrate` decimal(5, 4) NULL COMMENT '沙龙房佣金比例' AFTER `salonrooms`;

ALTER TABLE `d_commission` ADD COLUMN `type` tinyint(1) NULL COMMENT '类型' AFTER `create_time`;
ALTER TABLE `d_commission` ADD COLUMN `rechargecoin` bigint(20) NULL DEFAULT 0 COMMENT '充值金额' AFTER `betcoin`;

ALTER TABLE `d_commission` 
MODIFY COLUMN `betcoin` decimal(20, 4) NULL DEFAULT NULL COMMENT '下注金额' AFTER `uid`,
MODIFY COLUMN `rechargecoin` decimal(20, 4) NULL DEFAULT 0 COMMENT '充值金额' AFTER `betcoin`;

update s_send_charm set level=level-1 where id>=13 and id<=18;
delete from s_shop_skin where category in (9, 10);

ALTER TABLE `d_user` MODIFY COLUMN `coin` decimal(20, 2) UNSIGNED NULL DEFAULT 0 COMMENT 'cash coin' AFTER `create_platform`;

DROP TABLE IF EXISTS `d_log_sign`;
CREATE TABLE `d_log_sign` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `uid` bigint(20) DEFAULT NULL,
  `signtimes` int(11) DEFAULT '0' COMMENT '第1次签到',
  `create_time` int(11) DEFAULT '0' COMMENT '签到时间',
  `svip` int(11) DEFAULT '0' COMMENT '用户支付等级',
  `coin` decimal(10,2) DEFAULT '0.00' COMMENT '获得奖励',
  PRIMARY KEY (`id`),
  KEY `idxuid` (`uid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin COMMENT='用户签到日志';

ALTER TABLE `s_config_maintask` ADD COLUMN `rate` varchar(255) DEFAULT '1:0:0' COMMENT '比例分配' AFTER `gameids`;
update s_config_maintask set rate='1:0:0';

ALTER TABLE `s_config_customer` ADD COLUMN `ord` int(11) NULL DEFAULT 100 COMMENT '排序,小的靠前' AFTER `update_time`;

ALTER TABLE `d_commission` ADD COLUMN `datetime` int(11) NULL DEFAULT 0 COMMENT '日期' AFTER `type`;
ALTER TABLE `d_commission` DROP INDEX `idx_pid_time`, ADD INDEX `idx_pid_time`(`parentid`, `datetime`) USING BTREE;

ALTER TABLE `coin_log` MODIFY COLUMN `coin` decimal(20, 2) NOT NULL DEFAULT 0.00 COMMENT '变动分数' AFTER `before_coin`;

ALTER TABLE `d_desk_game` MODIFY COLUMN `bet` decimal(10, 2) NULL DEFAULT 0 AFTER `roomtype`, MODIFY COLUMN `prize` decimal(10, 2) NULL DEFAULT 0 COMMENT '奖励' AFTER `bet`;

delete from s_shop_skin where id in (23,24,25,26,2,4,7,8);