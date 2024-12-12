ALTER TABLE `indiarummy_game`.`s_config_pics` 
ADD COLUMN `url2` varchar(255) NULL COMMENT '外部地址' AFTER `url`;

truncate table d_sys_mail;
INSERT INTO `d_sys_mail` (`id`, `title`, `msg`, `attach`, `timestamp`, `stype`, `bonus_type`, `cover_img`, `title_al`, `msg_al`, `svip`, `rate`) VALUES (2, 'Welcome to the Yono Game!We\'ve been waiting for you for a long time!', 'We\'ve been waiting for you for a long time!One of the best games ever! It will change your perception of fun! Unlimited challenges are waiting for you to open! Start playing and create your own world,You only need one games App!', '[]', 1611292940, 8, NULL, NULL, '', '', NULL, NULL);

DROP TABLE IF EXISTS `d_mail_tpl`;
CREATE TABLE `d_mail_tpl` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `type` int(11) DEFAULT '0' COMMENT '类型',
  `title` varchar(255) COLLATE utf8mb4_bin DEFAULT NULL COMMENT '邮件标题',
  `content` text COLLATE utf8mb4_bin COMMENT '邮件内容',
  `status` tinyint(1) DEFAULT '1' COMMENT '1:有效 0:无效',
  `param1` int(11) DEFAULT NULL COMMENT '参数1，根据类型变动',
  `param2` int(11) DEFAULT NULL COMMENT '参数2，辅助参数',
  `coin` int(11) DEFAULT '0' COMMENT '奖励金币',
  `svip` varchar(255) COLLATE utf8mb4_bin DEFAULT NULL COMMENT 'vip类型',
  `rate` varchar(255) COLLATE utf8mb4_bin DEFAULT '' COMMENT '奖金分成比例',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin COMMENT='邮件模板';

INSERT INTO `d_mail_tpl` (`id`, `type`, `title`, `content`, `status`, `param1`, `param2`, `coin`, `svip`, `rate`) VALUES (1, 24, 'Welcome back!', 'Welcome back, we haven\'t seen you in days. Miss you very much. have fun!', 1, 2, NULL, 0, NULL, '');
INSERT INTO `d_mail_tpl` (`id`, `type`, `title`, `content`, `status`, `param1`, `param2`, `coin`, `svip`, `rate`) VALUES (2, 25, 'Recharge successfully', 'Congratulations, the first recharge is successful.', 1, NULL, NULL, 0, NULL, '');
INSERT INTO `d_mail_tpl` (`id`, `type`, `title`, `content`, `status`, `param1`, `param2`, `coin`, `svip`, `rate`) VALUES (3, 26, 'Successful withdrawal', 'Congratulations, the first cash withdrawal is successful.', 1, NULL, NULL, 0, NULL, '');
INSERT INTO `d_mail_tpl` (`id`, `type`, `title`, `content`, `status`, `param1`, `param2`, `coin`, `svip`, `rate`) VALUES (4, 27, 'Reward bonus', 'You have successfully invited your friends.', 1, NULL, NULL, 0, NULL, '');
INSERT INTO `d_mail_tpl` (`id`, `type`, `title`, `content`, `status`, `param1`, `param2`, `coin`, `svip`, `rate`) VALUES (5, 28, 'Reward bonus', 'You will get bonus for inviting friends.', 1, NULL, NULL, 0, NULL, '');
INSERT INTO `d_mail_tpl` (`id`, `type`, `title`, `content`, `status`, `param1`, `param2`, `coin`, `svip`, `rate`) VALUES (6, 29, 'Reward bonus', 'Raise the ranking in the leaderboard to get a bonus.', 1, 3, NULL, 0, NULL, '');
INSERT INTO `d_mail_tpl` (`id`, `type`, `title`, `content`, `status`, `param1`, `param2`, `coin`, `svip`, `rate`) VALUES (7, 17, 'Reward bonus', 'You get a bonus in the leaderboard.', 1, NULL, NULL, 0, NULL, '');
INSERT INTO `d_mail_tpl` (`id`, `type`, `title`, `content`, `status`, `param1`, `param2`, `coin`, `svip`, `rate`) VALUES (8, 18, 'Recharge successfully', 'The online recharge is successful.', 1, NULL, NULL, 0, NULL, '');
INSERT INTO `d_mail_tpl` (`id`, `type`, `title`, `content`, `status`, `param1`, `param2`, `coin`, `svip`, `rate`) VALUES (9, 30, 'Successful withdrawal', 'Your withdrawal is successful.', 1, NULL, NULL, 0, NULL, '');
INSERT INTO `d_mail_tpl` (`id`, `type`, `title`, `content`, `status`, `param1`, `param2`, `coin`, `svip`, `rate`) VALUES (10, 31, 'Withdrawal failure', 'The withdrawal of your application failed.', 1, NULL, NULL, 0, NULL, '');
INSERT INTO `d_mail_tpl` (`id`, `type`, `title`, `content`, `status`, `param1`, `param2`, `coin`, `svip`, `rate`) VALUES (11, 32, 'Verification succeeded.', 'Verify mobile phone number successfully.', 1, NULL, NULL, 0, NULL, '');
INSERT INTO `d_mail_tpl` (`id`, `type`, `title`, `content`, `status`, `param1`, `param2`, `coin`, `svip`, `rate`) VALUES (12, 33, 'Verification succeeded.', 'PAN verification succeeded.', 1, NULL, NULL, 0, NULL, '');
INSERT INTO `d_mail_tpl` (`id`, `type`, `title`, `content`, `status`, `param1`, `param2`, `coin`, `svip`, `rate`) VALUES (13, 34, 'Verification failed', 'PAN verification failed.', 1, NULL, NULL, 0, NULL, '');
INSERT INTO `d_mail_tpl` (`id`, `type`, `title`, `content`, `status`, `param1`, `param2`, `coin`, `svip`, `rate`) VALUES (14, 35, 'Verification succeeded.', 'You successfully verified your bank card.', 1, NULL, NULL, 0, NULL, '');
INSERT INTO `d_mail_tpl` (`id`, `type`, `title`, `content`, `status`, `param1`, `param2`, `coin`, `svip`, `rate`) VALUES (15, 36, 'Verification failed', 'Failed to verify your bank card.', 1, NULL, NULL, 0, NULL, '');
INSERT INTO `d_mail_tpl` (`id`, `type`, `title`, `content`, `status`, `param1`, `param2`, `coin`, `svip`, `rate`) VALUES (16, 37, 'Consecutive victory', 'You\'ve won XXX games in a row.', 1, 3, NULL, 0, NULL, '');
INSERT INTO `d_mail_tpl` (`id`, `type`, `title`, `content`, `status`, `param1`, `param2`, `coin`, `svip`, `rate`) VALUES (17, 38, 'Win coins', 'You won more than XXX coins.', 1, 200, NULL, 0, NULL, '');

DROP TABLE IF EXISTS `d_forbid`;
CREATE TABLE `d_forbid` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `userid` int(11) DEFAULT NULL,
  `playername` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `memo` text COLLATE utf8mb4_unicode_ci COMMENT '备注',
  `status` tinyint(1) DEFAULT NULL,
  `uid` int(11) DEFAULT NULL,
  `create_time` int(11) DEFAULT NULL,
  `uuid` int(11) DEFAULT NULL,
  `update_time` int(11) DEFAULT NULL,
  `forbiddevote` tinyint(1) DEFAULT '0' COMMENT '是否禁止俸禄',
  `forbidadd` tinyint(1) DEFAULT '0' COMMENT '是否禁止加好友',
  `forbidchat` tinyint(1) DEFAULT '0' COMMENT '是否禁止聊天',
  `recomadd` tinyint(1) DEFAULT '0' COMMENT '是否推荐给其他人加好友',
  `svip` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'Vip标签等级',
  `tag` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'Tag标签等级',
  `targetuids` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '推荐给指定的好友uid',
  PRIMARY KEY (`id`),
  KEY `idx_uid` (`userid`)
) ENGINE=InnoDB AUTO_INCREMENT=11 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='禁止列表';

ALTER TABLE `indiarummy_game`.`d_feedback` 
ADD COLUMN `language` varchar(255) NULL COMMENT '语言' AFTER `playername`,
ADD COLUMN `phone` varchar(255) NULL COMMENT '手机号' AFTER `language`;

ALTER TABLE `indiarummy_game`.`d_user` 
ADD COLUMN `phone` varchar(255) NULL COMMENT '绑定的手机号' AFTER `playername`;

ALTER TABLE `indiarummy_game`.`d_user` 
MODIFY COLUMN `stopregrebat` tinyint(1) NULL DEFAULT 0 COMMENT '停止接收下级的返利' AFTER `kyc`;

ALTER TABLE `indiarummy_game`.`d_user` 
ADD COLUMN `forbidnick` tinyint(1) NULL DEFAULT 0 COMMENT '禁止修改昵称和头像' AFTER `stopregrebat`;

ALTER TABLE `indiarummy_game`.`d_forbid` 
ADD COLUMN `stopregrebat` tinyint(1) NULL COMMENT '是否禁止返佣' AFTER `targetuids`;

ALTER TABLE `indiarummy_game`.`s_pay_cfg_channel` 
ADD COLUMN `taxrate` decimal(5, 4) NULL DEFAULT 0 COMMENT '手续费' AFTER `update_time`;
ALTER TABLE `indiarummy_game`.`d_user_recharge` 
MODIFY COLUMN `tax` decimal(20, 4) NULL DEFAULT 0.00 COMMENT '手续费' AFTER `backcoin`;

ALTER TABLE `indiarummy_game`.`d_user_draw` 
ADD COLUMN `type` tinyint(1) NULL COMMENT '类型 1:银行 2:usdt' AFTER `verify_status`,
ADD COLUMN `backcoin` decimal(20, 2) NULL COMMENT '到账金额' AFTER `type`,
ADD COLUMN `tax` decimal(20, 2) NULL COMMENT '税' AFTER `backcoin`,
ADD COLUMN `taxthird` decimal(20, 2) NULL COMMENT '第3方税' AFTER `tax`;

ALTER TABLE `indiarummy_game`.`s_pay_cfg_other` 
ADD COLUMN `memberid` varchar(255) NULL COMMENT '商户号' AFTER `title`;
ALTER TABLE `indiarummy_game`.`s_pay_cfg_other` 
ADD COLUMN `md5key` varchar(255) NULL COMMENT '签名key' AFTER `status`,
ADD COLUMN `queryurl` varchar(255) NULL DEFAULT '' COMMENT '查看地址' AFTER `md5key`;

ALTER TABLE `indiarummy_game`.`s_pay_cfg_other` 
ADD COLUMN `private_key` text NULL COMMENT '私钥' AFTER `queryurl`,
ADD COLUMN `pub_key` varchar(1024) NULL COMMENT '公钥' AFTER `private_key`;

ALTER TABLE `indiarummy_game`.`s_pay_cfg_channel` 
MODIFY COLUMN `groupid` int(11) NULL DEFAULT NULL COMMENT '支付分组' AFTER `status`,
MODIFY COLUMN `code` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NULL DEFAULT NULL COMMENT '支付通道号' AFTER `otherid`,
ADD COLUMN `planid` int(11) NULL DEFAULT 1 COMMENT '1:每次; 2:每天; 3:首次' AFTER `maxcoin`,
ADD COLUMN `discoin` decimal(20, 2) NULL COMMENT '优惠固定金额' AFTER `disrate`,
ADD COLUMN `autorun` tinyint(1) NULL DEFAULT 1 COMMENT '1:自动 0:关闭' AFTER `taxrate`;

ALTER TABLE `indiarummy_game`.`s_pay_cfg_channel` 
ADD COLUMN `svip` varchar(255) NULL COMMENT '支付vip等级' AFTER `autorun`;

insert into s_config (k,v,memo) values('version_manifest_url','https://inter.yono99.com/GameX/Main/version.manifest','服务器资源版本');

ALTER TABLE `indiarummy_game`.`s_pay_bank` 
CHANGE COLUMN `cardaddr` `bankname` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NULL DEFAULT NULL COMMENT '银行名称' AFTER `cardnum`,
MODIFY COLUMN `disrate` decimal(5, 4) NULL DEFAULT NULL COMMENT '优惠比例' AFTER `bankname`;

ALTER TABLE `indiarummy_game`.`d_feedback` 
ADD COLUMN `uuid` int(11) NULL DEFAULT 0 AFTER `status`,
ADD COLUMN `update_time` int(11) NULL DEFAULT 0 AFTER `uuid`,
ADD COLUMN `feedback` varchar(255) NULL DEFAULT '' COMMENT '回复内容' AFTER `update_time`,
ADD COLUMN `memo` varchar(255) NULL COMMENT '备注' AFTER `feedback`;

insert into indiarummy_adm.system_setting(skey,sval) values('openip', 0);

delete from s_config where id in (23,24,25,29,44,42,49,30,13,28,35,45,43,50);

DROP TABLE IF EXISTS `d_tn_stat`;
CREATE TABLE `d_tn_stat` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `tn_id` int(11) DEFAULT '0' COMMENT '赛事id',
  `gameid` int(11) DEFAULT NULL COMMENT '游戏id',
  `start_time` int(11) DEFAULT NULL COMMENT '开始时间',
  `stop_time` int(11) DEFAULT NULL COMMENT '结束时间',
  `buy_in` int(11) DEFAULT NULL COMMENT '报名金币',
  `rewardscoin` decimal(20,2) DEFAULT NULL COMMENT '总奖金',
  `enrolcount` int(11) DEFAULT NULL COMMENT '报名人数',
  `exitcount` int(11) DEFAULT NULL COMMENT '退费人数',
  `create_time` int(11) DEFAULT '0' COMMENT '赛事时间戳',
  PRIMARY KEY (`id`),
  KEY `time` (`create_time`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

ALTER TABLE `indiarummy_game`.`s_pay_cfg_drawcom` 
DROP COLUMN `payid`,
CHANGE COLUMN `fixedrate` `tax` int(11) NULL DEFAULT NULL COMMENT '三方单笔固定手续费' AFTER `rate`,
ADD COLUMN `apiurl` varchar(255) NULL COMMENT '下单地址' AFTER `title`,
ADD COLUMN `queryurl` varchar(255) NULL COMMENT '查单地址' AFTER `apiurl`,
MODIFY COLUMN `rate` decimal(5, 4) NULL DEFAULT NULL COMMENT '三方费率%' AFTER `maxcoin`,
ADD COLUMN `platformrate` decimal(5, 4) NULL COMMENT '平台费率%' AFTER `tax`,
ADD COLUMN `platformtax` int(11) NULL COMMENT '平台单笔固定费率' AFTER `platformrate`;
ALTER TABLE `indiarummy_game`.`s_pay_cfg_drawcom` 
DROP COLUMN `domain`;

ALTER TABLE `indiarummy_game`.`s_pay_cfg_drawcom` 
MODIFY COLUMN `publickey` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NULL COMMENT '公钥' AFTER `secretkey`,
MODIFY COLUMN `privatekey` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NULL COMMENT '私钥' AFTER `publickey`;

ALTER TABLE `indiarummy_game`.`s_pay_cfg_drawcom` 
ADD COLUMN `channel` varchar(255) NULL COMMENT '支付通道号' AFTER `merchant`;

ALTER TABLE `indiarummy_game`.`s_pay_cfg_drawrate` 
CHANGE COLUMN `mincoin` `tax` int(11) NULL DEFAULT NULL COMMENT '单笔固定费用' AFTER `rate`,
MODIFY COLUMN `rate` decimal(5, 4) NULL DEFAULT NULL COMMENT '提现手续费率' AFTER `daymaxcoin`;

DROP TABLE IF EXISTS `d_lb_log`;
CREATE TABLE `d_lb_log` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `uid` int(11) DEFAULT NULL COMMENT 'uid',
  `playername` varchar(255) COLLATE utf8mb4_bin DEFAULT NULL COMMENT '昵称',
  `usericon` varchar(255) COLLATE utf8mb4_bin DEFAULT NULL COMMENT '头像',
  `rtype` tinyint(1) DEFAULT NULL COMMENT '榜单类型',
  `score` int(11) DEFAULT NULL COMMENT '积分',
  `ord` int(11) DEFAULT NULL COMMENT '排名',
  `reward_coin` int(11) DEFAULT NULL COMMENT '奖励金币',
  `create_time` int(11) DEFAULT NULL COMMENT '创建时间',
  `settle_time` int(11) DEFAULT NULL COMMENT '结算时间',
  PRIMARY KEY (`id`),
  KEY `uid` (`uid`),
  KEY `time` (`settle_time`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin COMMENT='排行榜结算记录';

ALTER TABLE `indiarummy_game`.`d_commission` 
ADD COLUMN `gameid` int(11) NULL COMMENT '下注游戏id' AFTER `datetime`,
ADD COLUMN `issue` varchar(32) NULL COMMENT '游戏记录id' AFTER `gameid`;

ALTER TABLE `indiarummy_game`.`d_user` 
MODIFY COLUMN `suspendagent` tinyint(1) NULL DEFAULT NULL COMMENT '禁止俸禄' AFTER `isbindphone`;

DROP TABLE IF EXISTS `d_lb_stat`;
CREATE TABLE `d_lb_stat` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `start_time` int(11) DEFAULT '0' COMMENT '榜单开始时间',
  `rtype` tinyint(1) DEFAULT '1' COMMENT '类型',
  `regcnt` int(11) DEFAULT NULL COMMENT '报名人数',
  `rewardcnt` int(11) DEFAULT NULL COMMENT '中奖人数',
  `reward_coin` bigint(20) DEFAULT NULL COMMENT '总奖金',
  `create_time` int(11) DEFAULT '0' COMMENT '创建时间',
  PRIMARY KEY (`id`),
  KEY `time` (`start_time`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin COMMENT='排行榜汇总表';
