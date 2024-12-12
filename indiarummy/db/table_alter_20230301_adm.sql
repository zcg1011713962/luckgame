DROP TABLE IF EXISTS `indiarummy_game`.`d_log_order`;
CREATE TABLE `indiarummy_game`.`d_log_order` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `cat` tinyint(1) DEFAULT NULL COMMENT '类型 1:支付订单 2:提现订单',
  `orderid` varchar(32) COLLATE utf8mb4_bin DEFAULT '' COMMENT '订单号',
  `create_time` int(11) DEFAULT '0',
  `memo` varchar(255) COLLATE utf8mb4_bin DEFAULT '' COMMENT '备注',
  `uid` int(11) DEFAULT '0' COMMENT '操作人uid',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin COMMENT='订单日志管理';

ALTER TABLE `indiarummy_adm`.`stat_market_day` 
MODIFY COLUMN `arpu` double(10, 4) NULL DEFAULT NULL AFTER `dau`,
MODIFY COLUMN `arppu` double(10, 4) NULL DEFAULT NULL AFTER `arpu`;