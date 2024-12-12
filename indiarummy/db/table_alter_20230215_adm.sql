DROP TABLE IF EXISTS indiarummy_adm.`d_stat_register_bind`;
CREATE TABLE indiarummy_adm.`d_stat_register_bind` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `create_time` int(11) DEFAULT '0',
  `reg` int(11) DEFAULT '0' COMMENT '注册人数',
  `bindphone` int(11) DEFAULT '0' COMMENT '绑定了手机号的人数',
  PRIMARY KEY (`id`),
  KEY `idx_time` (`create_time`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin COMMENT='注册人数中绑定手机号比例监控';

DROP TABLE IF EXISTS indiarummy_adm.`d_stat_recharge`;
CREATE TABLE indiarummy_adm.`d_stat_recharge` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `create_time` int(11) DEFAULT '0',
  `amount` bigint(20) DEFAULT '0' COMMENT '充值额 ',
  `succamount` bigint(20) DEFAULT '0' COMMENT '充值成功金额',
  PRIMARY KEY (`id`),
  KEY `idx_time` (`create_time`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin COMMENT='充值订单统计';

ALTER TABLE `indiarummy_adm`.`stat_market_day` 
ADD COLUMN `dnu_not_bindphone` int(11) NULL DEFAULT 0 COMMENT '新用户未绑定手机号' AFTER `dau_not_spin_count`;



ALTER TABLE `indiarummy_adm`.`stat_newuser_rate` ADD COLUMN `beforeauth` int(11) NULL DEFAULT NULL COMMENT '开始授权' AFTER `getmsg1`;
ALTER TABLE `indiarummy_adm`.`stat_newuser_rate` ADD COLUMN `authend` int(11) NULL DEFAULT NULL COMMENT '服务器授权结束' AFTER `beforeauth`;
ALTER TABLE `indiarummy_adm`.`stat_newuser_rate` ADD COLUMN `authfail1` int(11) NULL DEFAULT NULL COMMENT '授权失败1' AFTER `authend`;
ALTER TABLE `indiarummy_adm`.`stat_newuser_rate` ADD COLUMN `authfail2` int(11) NULL DEFAULT NULL COMMENT '授权失败2' AFTER `authfail1`;
ALTER TABLE `indiarummy_adm`.`stat_newuser_rate` ADD COLUMN `loadstart` int(11) NULL DEFAULT NULL COMMENT '开始加载' AFTER `regsucc`;
ALTER TABLE `indiarummy_adm`.`stat_newuser_rate` ADD COLUMN `loadend` int(11) NULL DEFAULT NULL COMMENT '加载完毕' AFTER `loadstart`;
ALTER TABLE `indiarummy_adm`.`stat_newuser_rate` ADD COLUMN `entrymain` int(11) NULL DEFAULT NULL COMMENT '进入大厅' AFTER `loadend`;
ALTER TABLE `indiarummy_adm`.`stat_newuser_rate` ADD COLUMN `pro_failed` int(11) NULL DEFAULT 0 COMMENT '存在资源热更失败人数(会自动重新下载)' AFTER `create_time`;
ALTER TABLE `indiarummy_adm`.`stat_newuser_rate` ADD COLUMN `http_disconnect` int(11) NULL DEFAULT 0 COMMENT '链接登陆服失败人数' AFTER `pro_failed`;
ALTER TABLE `indiarummy_adm`.`stat_newuser_rate` ADD COLUMN `net_timeout` int(11) NULL DEFAULT 0 AFTER `http_disconnect`;
ALTER TABLE `indiarummy_adm`.`stat_newuser_rate` ADD COLUMN `shownamepop` int(11) NULL DEFAULT NULL COMMENT '弹改名字' AFTER `net_timeout`;
ALTER TABLE `indiarummy_adm`.`stat_newuser_rate` ADD COLUMN `shownewgift` int(11) NULL DEFAULT NULL COMMENT '弹新手礼包' AFTER `shownamepop`;
ALTER TABLE `indiarummy_adm`.`stat_newuser_rate` ADD COLUMN `showautosign` int(11) NULL DEFAULT NULL COMMENT '弹自动签到' AFTER `shownewgift`;
ALTER TABLE `indiarummy_adm`.`stat_newuser_rate` ADD COLUMN `onegames` int(11) NULL DEFAULT NULL COMMENT '大于等于1局游戏' AFTER `showautosign`;
ALTER TABLE `indiarummy_adm`.`stat_newuser_rate` CHANGE COLUMN `restart` `needhot` int(11) NULL DEFAULT 0 COMMENT '重启' AFTER `endhot`;
ALTER TABLE `indiarummy_adm`.`stat_newuser_rate` ADD COLUMN `bindphone` int(11) NULL DEFAULT 0 COMMENT '绑定手机号的人数' AFTER `onegames`;
ALTER TABLE `indiarummy_adm`.`stat_newuser_rate` ADD COLUMN `showbindphone` int(11) NULL DEFAULT 0 COMMENT '弹绑定手机号弹框' AFTER `shownewgift`;
ALTER TABLE `indiarummy_adm`.`stat_newuser_rate` 
ADD COLUMN `updatelatest` int(11) NULL DEFAULT 0 COMMENT '热更到最新' AFTER `bindphone`,
ADD COLUMN `updaterestart` int(11) NULL DEFAULT 0 COMMENT '热更完重启' AFTER `updatelatest`;

ALTER TABLE `indiarummy_game`.`s_config_customer` ADD COLUMN `svip` varchar(255) NULL DEFAULT '' COMMENT 'vip等级' AFTER `ord`;
update `s_config_customer` set svip='0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20' where id>0;