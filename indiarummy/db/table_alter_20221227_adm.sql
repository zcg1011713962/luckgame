DROP TABLE IF EXISTS `d_blacklist_ip`;
CREATE TABLE `d_blacklist_ip` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `ip` varchar(255) COLLATE utf8mb4_bin DEFAULT '',
  `status` tinyint(1) DEFAULT '1',
  `uid` int(11) DEFAULT '0' COMMENT '添加人',
  `create_time` int(11) DEFAULT '0' COMMENT '添加时间',
  `uuid` int(11) DEFAULT NULL,
  `update_time` int(11) DEFAULT '0' COMMENT '更新时间',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin COMMENT='ip黑名单池';

INSERT INTO `s_config` (`id`, `k`, `v`, `memo`, `mlrobot`) VALUES (76, 'popbindphone', '1', '强弹引导绑定手机号弹框', NULL);

ALTER TABLE `indiarummy_game`.`s_game` 
MODIFY COLUMN `aijoin` tinyint(1) NULL DEFAULT 1 COMMENT '是否加入ai' AFTER `firstbet`;
update s_game set aijoin=1 where id<400 ;
update s_game set aijoin=0 where id > 400 ;

INSERT INTO `s_config_sms` (`id`, `title`, `url`, `accesskey`, `secretkey`, `code`, `status`, `weight`, `cuid`, `create_time`, `uuid`, `update_time`, `callmethod`, `ext`, `classname`) VALUES (4, '语音短信通道', ' http://api.kmicloud.com/call/v1/VoiceVerifyCode', '0c5d4f31b5694778bd1e31fedbf22c51', '734818a742414281a1c5dcebd8c2e3f7', '', 2, 130, 11497, 1672277732, 11497, 1672291297, 1, NULL, 'SmsKmiCloudVoice');