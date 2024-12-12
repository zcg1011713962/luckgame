DROP TABLE IF EXISTS `d_log_msgoneerr`;
CREATE TABLE `d_log_msgoneerr` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `cat` smallint(5) unsigned DEFAULT '1' COMMENT '错误类型：1版本号 2手机型号或设备号为空 3设备号 4手机型号 5手机号验证码不对 6登录失败 7错误码',
  `msg` varchar(1000) COLLATE utf8mb4_bin DEFAULT NULL COMMENT '协议1内容',
  `create_time` int(11) DEFAULT NULL,
  `ip` int(11) DEFAULT '0',
  `platform` smallint(5) DEFAULT NULL,
  `errcode` int(11) DEFAULT '0' COMMENT '错误码',
  PRIMARY KEY (`id`),
  KEY `idx_time` (`create_time`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin COMMENT='协议1被屏蔽的记录';

ALTER TABLE `indiarummy_game`.`d_rake_back` 
MODIFY COLUMN `state` tinyint(1) NULL DEFAULT 1 COMMENT '1:待领取 2已领取 3:过期作废 4:暂不能领取' AFTER `wincoin`,
ADD COLUMN `available_time` int(11) NULL DEFAULT 0 COMMENT '可以领取的起始时间' AFTER `frate`;