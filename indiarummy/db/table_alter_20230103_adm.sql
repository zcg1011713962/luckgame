ALTER TABLE `indiarummy_game`.`d_mail` 
ADD COLUMN `svip` varchar(255) NULL DEFAULT '' COMMENT '用户支付等级' AFTER `rate`;

ALTER TABLE `indiarummy_game`.`d_user_login_log` 
ADD COLUMN `ddid` varchar(255) NULL DEFAULT '' COMMENT '设备号' AFTER `countrycn`;

ALTER TABLE `indiarummy_game`.`d_user` 
ADD COLUMN `totalrecharge` decimal(20, 2) NULL DEFAULT 0 COMMENT '总充值' AFTER `totaldraw`;

ALTER TABLE `indiarummy_game`.`d_user` 
ADD COLUMN `device` varchar(255) NULL DEFAULT '' COMMENT '设备型号' AFTER `drawsucccoin`;

CREATE TABLE `s_notice` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `status` tinyint(1) DEFAULT '1' COMMENT '1正常 0过期',
  `ord` int(11) DEFAULT '0' COMMENT '排序，小的优先',
  `svip` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '支付层级',
  `title` varchar(127) COLLATE utf8mb4_bin DEFAULT NULL COMMENT '标题',
  `content` varchar(2047) COLLATE utf8mb4_bin DEFAULT NULL COMMENT '内容',
  `img` varchar(255) COLLATE utf8mb4_bin DEFAULT NULL COMMENT '图片地址',
  `jumpto` varchar(255) COLLATE utf8mb4_bin DEFAULT NULL COMMENT '跳转:Bank/Salon/Game/ReferEarn/Social/https:www.baidu.com',
  `create_time` int(11) DEFAULT NULL COMMENT '创建时间',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin COMMENT='活动公告';

ALTER TABLE `indiarummy_game`.`d_user_login_log` 
ADD COLUMN `device` varchar(255) NULL DEFAULT '' COMMENT '设备型号' AFTER `ddid`;

ALTER TABLE `indiarummy_game`.`d_user` 
ADD COLUMN `username` varchar(255) NULL DEFAULT '' COMMENT '真实姓名' AFTER `playername`,
ADD COLUMN `remark` varchar(255) NULL DEFAULT '' COMMENT '用户备注' AFTER `device`;

ALTER TABLE `indiarummy_game`.`d_user` 
ADD COLUMN `forbidcode` tinyint(1) NULL DEFAULT 0 COMMENT '是否禁用邀请码' AFTER `code`;

ALTER TABLE `indiarummy_game`.`d_user` 
ADD COLUMN `ddid` varchar(255) NULL DEFAULT '' COMMENT '注册时期机器码' AFTER `create_time`;

ALTER TABLE `indiarummy_game`.`d_user` 
ADD COLUMN `reg_ip` varchar(255) NULL DEFAULT '' COMMENT '注册ip' AFTER `login_time`;

INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (230, 'Entry_Main', NULL, '进入大厅');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (231, 'Reg_succ', NULL, '注册成功');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (232, 'online_start_game', NULL, '进入竞技类游戏');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (233, 'sg_btn_shop', NULL, '百人游戏点击加号充值');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (234, 'sg_btn_record', NULL, '百人游戏点击投注记录');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (235, 'sg_btn_setting', NULL, '百人游戏点击设置');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (236, 'sg_btn_exitGame', NULL, '点击退出游戏');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (237, 'sg_bet', NULL, '百人游戏投注');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (238, 'sg_emotion', NULL, '百人游戏发送互动表情');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (239, 'Bank_AddCash', NULL, 'Bank点击AddCash');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (240, 'Bank_Verfy', NULL, 'Bank点击verify');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (241, 'Bank_Withdraw', NULL, 'Bank点击提现');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (242, 'popup_open', 'yd_bonus_transfer', 'Bank点击-TransferNow');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (243, 'Bank_Payments', NULL, 'Bank点击-ManagePayments');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (244, 'BonusTransfer_Collect', NULL, 'Bank点击-BonusTransfer的collect按钮');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (245, 'Refer_WhatsApp', NULL, '点击-Refer-WhatsApp按钮');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (246, 'Refer_SystemShare', NULL, '点击-Refer-System Share按钮');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (247, 'Refer_Copy', NULL, '点击-Refer-Copy按钮');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (248, 'popup_open', 'yd_bonus', '大厅打开bonus');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (249, 'event_share_fb', NULL, '点击Bonus-share按钮');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (250, 'event_reward_get', NULL, 'Bonus中领取任务奖励');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (251, 'event_reward_get_sg', NULL, '游戏内领取任务奖励');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (252, 'bigwin_close', NULL, 'bigwin弹窗关闭');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (253, 'open_menu_sound', NULL, '打开菜单中音效');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (254, 'close_menu_sound', NULL, '关闭菜单中音效');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (255, 'subgame_auto_10', NULL, '自动挂机下注10次');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (256, 'subgame_auto_20', NULL, '自动挂机下注20次');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (257, 'subgame_auto_50', NULL, '自动挂机下注50次');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (258, 'subgame_auto_100', NULL, '自动挂机下注100次');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (259, 'subgame_auto_500', NULL, '自动挂机下注500次');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (260, 'popup_open', 'yd_service', '打开客服界面');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (261, 'popup_open', 'yd_activity', '打开活动弹窗');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (262, 'popup_close', 'yd_activity', '关闭活动弹窗');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (263, 'popup_close', 'yd_service', '关闭客服界面');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (264, 'newcome_gift', NULL, '获取新人大礼包弹框');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (265, 'open_menu_music', NULL, '游戏中打开音乐');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (266, 'close_menu_music', NULL, '游戏中关闭音乐');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (267, 'popup_open', 'yd_rank_detail', '打开查看全部玩家弹框');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (268, 'popup_close', 'yd_rank_detail', '关闭查看全部玩家弹框');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (269, 'popup_open', 'yd_historical_record', '大厅打开历史记录');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (270, 'popup_open', 'yd_rule_help', '打开排行榜规则弹框');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (271, 'popup_close', 'yd_rule_help', '关闭排行榜规则弹框');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (272, 'entergame', NULL, '进入游戏');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (273, 'exitgame', NULL, '退出游戏');

DROP TABLE IF EXISTS `d_firebase_msg`;
CREATE TABLE `d_firebase_msg` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `title` varchar(1024) COLLATE utf8mb4_bin DEFAULT '' COMMENT '推送内容',
  `create_time` int(11) DEFAULT '0' COMMENT '创建时间',
  `receiver_uid` varchar(255) COLLATE utf8mb4_bin DEFAULT NULL COMMENT '特定接收人',
  `receiver_svip` varchar(255) COLLATE utf8mb4_bin DEFAULT NULL COMMENT '特定接收等级',
  `status` int(11) DEFAULT '1' COMMENT '状态1创建 2已提交 3失败',
  `uid` int(11) DEFAULT '0' COMMENT '创建人',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin COMMENT='firebase推送记录';

ALTER TABLE `indiarummy_game`.`d_firebase_msg` 
ADD COLUMN `update_time` int(11) NULL DEFAULT 0 AFTER `uid`;