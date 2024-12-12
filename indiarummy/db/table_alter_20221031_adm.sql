insert into s_config (k,v,memo) values('salonrate','[{"min":0,"max":5000,"rate":0.001},{"min":5001,"max":10000,"rate":0.001},{"min":10001,"max":50000,"rate":0.001},{"min":50001,"max":-1,"rate":0.001}]','salon税收比例');insert into s_config (k,v,memo) values('salonrate','[{"min":0,"max":5000,"rate":0.001},{"min":5001,"max":10000,"rate":0.001},{"min":10001,"max":50000,"rate":0.001},{"min":50001,"max":-1,"rate":0.001}]','salon税收比例');
ALTER TABLE `s_game` MODIFY COLUMN `aiwinrate` int(11) NULL DEFAULT NULL COMMENT '百分位,70表示70%' AFTER `aijoin`,MODIFY COLUMN `taxrate` decimal(5, 2) NULL DEFAULT NULL COMMENT '小数点2位' AFTER `aiwinrate`;
update s_game set aiwinrate=70,taxrate=0.05,aijoin=1 where id <200;
update s_game set aiwinrate=70,taxrate=0.05;

ALTER TABLE `indiarummy_game`.`s_config_vip_upgrade` DROP COLUMN `salonrate`;
ALTER TABLE `indiarummy_game`.`d_user_draw` ADD COLUMN `orderid` varchar(32) NULL COMMENT '订单号' AFTER `id`;

ALTER TABLE `indiarummy_game`.`d_bank_record` ADD COLUMN `orderid` varchar(32) NULL COMMENT '订单id' AFTER `id`;
ALTER TABLE `indiarummy_game`.`coin_log` MODIFY COLUMN `type` int(11) NOT NULL COMMENT '修改方式' AFTER `uid`;
ALTER TABLE `indiarummy_game`.`d_user` ADD COLUMN `ispay` tinyint(1) NULL DEFAULT 0 COMMENT '是否支付用户' AFTER `kyc`;
update d_user set ispay=0, suspendagent=0;