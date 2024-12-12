ALTER TABLE `indiarummy_game`.`d_desk_user` ADD INDEX `issue`(`issue`);

update `indiarummy_adm`.`auth_rule` set name = replace(name,'/admin','admin') where name like '/admin%';

ALTER TABLE `indiarummy_game`.`d_user` 
ADD COLUMN `gamedraw` decimal(20, 2) NULL COMMENT '游戏可提现金额' AFTER `candraw`;
ALTER TABLE `indiarummy_game`.`d_user` 
MODIFY COLUMN `gamedraw` decimal(20, 2) NULL DEFAULT 0 COMMENT '游戏可提现金额' AFTER `candraw`;

ALTER TABLE `indiarummy_game`.`d_user` 
ADD COLUMN `gamebonus` decimal(20, 2) NULL DEFAULT 0 COMMENT '游戏可转bonus' AFTER `gamedraw`;


DROP TABLE IF EXISTS `s_config_statis`;
CREATE TABLE `s_config_statis` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `act` varchar(32) COLLATE utf8mb4_bin DEFAULT '' COMMENT '操作类型',
  `ext` varchar(32) COLLATE utf8mb4_bin DEFAULT NULL COMMENT '扩展类型',
  `title` varchar(255) COLLATE utf8mb4_bin DEFAULT '' COMMENT '操作标题中文',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=230 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin COMMENT='打点记录翻译';

INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (1, 'add_friend_bymobile', '0', '通过手机号加好友');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (2, 'bigwin_pop', ' ', 'SLOT-BIGWIN');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (3, 'bindcode', '11460', NULL);
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (4, 'chat_send_emoji', NULL, '发送表情');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (5, 'chat_send_text', NULL, '发送文字聊天');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (6, 'down_bet', ' ', 'SLOT-减注');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (7, 'Entry_Main', '{\"novice\":0,\"charmpack\":0}', '进入大厅');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (8, 'event_reward_get', NULL, '领取Bonus奖励');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (9, 'EXIT:635', '0.0', NULL);
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (10, 'EXPEXIT:6', '0.0', NULL);
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (11, 'feedback', ' ', '反馈界面');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (12, 'game_help', ' ', 'SLOT-菜单开');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (13, 'game_help_back', ' ', 'SLOT-菜单关');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (14, 'invite_share', 'other', '邀请分享-系统');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (15, 'invite_share', 'whatsapp', '邀请分享-WHATSAPP');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (16, 'JOIN:635', '0.0', NULL);
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (17, 'Load_End', ' ', '大厅加载完成');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (18, 'Load_Start', ' ', '大厅加载开始');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (19, 'Login_login_fail', NULL, '登陆失败');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (20, 'Login_login_succ', NULL, '登陆成功');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (21, 'maxbet', ' ', 'SLOT-MAXBET');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (22, 'newcome_gift', '0', NULL);
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (23, 'Node_login_fail', 'baned', NULL);
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (24, 'Node_login_succ', '2', '登录游戏服成功');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (25, 'Node_login_succ', '3', '重连游戏服成功');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (26, 'online_start_game', ' ', '游戏列表-进入游戏');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (27, 'open_set', ' ', '大厅-打开设置');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (28, 'popup_close', 'CafeGameInvite', '关闭-沙龙邀请');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (29, 'popup_close', 'CafeUIDInvite', '关闭-UID邀请');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (30, 'popup_close', 'ChangeHead', '关闭-换头像');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (31, 'popup_close', 'ChangeName', '关闭-换名字');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (32, 'popup_close', 'InviteCode', '关闭-邀请下载');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (33, 'popup_close', 'KnockoutHintNotJoin', '关闭-赛事未加入');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (34, 'popup_close', 'KnockoutResultRegister', '关闭-赛事报名');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (35, 'popup_close', 'KnockoutSchedule', '关闭-赛事等待');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (36, 'popup_close', 'newergift_rule', '关闭-新手礼物规则');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (37, 'popup_close', 'page_slots', '关闭-slot列表');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (38, 'popup_close', 'PersonalInfo', '关闭-个人详情');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (39, 'popup_close', 'PhoneBindingView', '关闭-手机绑定');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (40, 'popup_close', 'PopupAboutUs', '关闭-Aboutus');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (41, 'popup_close', 'PopupChatFriendsList', '关闭-好友聊天列表');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (42, 'popup_close', 'PopupCreateRoom', '关闭-创建沙龙房');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (43, 'popup_close', 'PopupEmoji', '关闭-表情');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (44, 'popup_close', 'PopupFeedback', '关闭-客服中心');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (45, 'popup_close', 'PopupFriendAdd', '关闭-添加好友');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (46, 'popup_close', 'PopupMail', '关闭-站内信');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (47, 'popup_close', 'PopupMailInfo', '关闭-邮件详情');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (48, 'popup_close', 'PopupNewComerGift', '关闭-新手礼物');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (49, 'popup_close', 'PopupNewGuide', '关闭-首次取名');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (50, 'popup_close', 'PopupParivateService', '关闭-隐私');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (51, 'popup_close', 'PopupResponsible', '关闭-权责');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (52, 'popup_close', 'PopupRuleExp', '关闭-升级经验');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (53, 'popup_close', 'PopupSetting', '关闭-设置');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (54, 'popup_close', 'PopupSign', '关闭-签到');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (55, 'popup_close', 'PopupTermsService', '关闭-服务条款');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (56, 'popup_close', 'rankOnlinePeoplelView', '关闭-阿拉丁轮盘');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (57, 'popup_close', 'ReferAddTips', '关闭-新增代理弹窗');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (58, 'popup_close', 'ReferEarn', '关闭-代理界面');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (59, 'popup_close', 'ReferShareRule', '关闭-代理规则');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (60, 'popup_close', 'resultTotalView', '关闭-阿拉丁轮盘结果');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (61, 'popup_close', 'RoomFriendJoin', '关闭-输入房间号');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (62, 'popup_close', 'RoomListView', '关闭-机台列表');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (63, 'popup_close', 'SalonIncome', '关闭-沙龙收益');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (64, 'popup_close', 'SalonRule', '关闭-沙龙规则');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (65, 'popup_close', 'ShopWalletHintAmount', '关闭-Bank-GameBalance');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (66, 'popup_close', 'ShopWalletHintCashBouns', '关闭-Bank-GameBouns');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (67, 'popup_close', 'ShopWalletHintWinnings', '关闭-Bank-Winnings');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (68, 'popup_close', 'SkinShop', '关闭-皮肤背包');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (69, 'popup_close', 'table_info', '关闭-桌子信息');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (70, 'popup_close', 'yd_bonus', '关闭-Bonus');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (71, 'popup_close', 'yd_bonus_transfer', '关闭-Bonustransfer');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (72, 'popup_close', 'yd_call_back', '关闭-留言板');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (73, 'popup_close', 'yd_historical_record', '关闭-历史记录');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (74, 'popup_close', 'yd_rank', '关闭-排行榜');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (75, 'popup_close', 'yd_rebate_rule', '关闭-Bonus-RebateRule');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (76, 'popup_close', 'yd_rule_rewards', '关闭-Bonus-RewardsRule');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (77, 'popup_close', 'yd_safe', '关闭-保险箱');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (78, 'popup_close', 'yd_transaction', '关闭-Bonus-转移列表');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (79, 'popup_close', 'yd_vip', '关闭-VIP界面');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (80, 'popup_close', 'yd_vip_help', '关闭-VIP规则');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (81, 'popup_open', 'CafeGameInvite', '打开-沙龙邀请');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (82, 'popup_open', 'CafeUIDInvite', '打开-按UID邀请');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (83, 'popup_open', 'ChangeHead', '打开-切换头像');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (84, 'popup_open', 'ChangeName', '打开-切换姓名');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (85, 'popup_open', 'InviteCode', '打开-邀请下载');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (86, 'popup_open', 'KnockoutHintNotJoin', '打开-赛事未加入');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (87, 'popup_open', 'KnockoutResultRegister', '打开-赛事注册');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (88, 'popup_open', 'KnockoutSchedule', '打开-赛事安排');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (89, 'popup_open', 'KnockoutWaitStart', '打开-赛事等待');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (90, 'popup_open', 'newergift_rule', '打开-新手礼物规则');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (91, 'popup_open', 'page_slots', '打开-slot列表');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (92, 'popup_open', 'PersonalInfo', '打开-个人详情');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (93, 'popup_open', 'PhoneBindingView', '打开-手机绑定');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (94, 'popup_open', 'PhoneLogin', '打开-手机登陆');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (95, 'popup_open', 'PopupAboutUs', '打开-Aboutus');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (96, 'popup_open', 'PopupChatFriendsList', '打开-好友聊天列表');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (97, 'popup_open', 'PopupCreateRoom', '打开-沙龙创建房间');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (98, 'popup_open', 'PopupEmoji', '打开-聊天表情');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (99, 'popup_open', 'PopupFeedback', '打开-客服中心');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (100, 'popup_open', 'PopupFriendAdd', '打开-添加好友');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (101, 'popup_open', 'PopupMail', '打开-站内信');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (102, 'popup_open', 'PopupMailInfo', '打开-邮件详情');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (103, 'popup_open', 'PopupNewComerGift', '打开-新手礼物');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (104, 'popup_open', 'PopupNewGuide', '打开-新手取名');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (105, 'popup_open', 'PopupParivateService', '打开-隐私服务');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (106, 'popup_open', 'PopupResponsible', '打开-权责');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (107, 'popup_open', 'PopupRuleExp', '打开-经验升级');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (108, 'popup_open', 'PopupSetting', '打开-设置');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (109, 'popup_open', 'PopupSign', '打开-签到');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (110, 'popup_open', 'PopupTermsService', '打开-服务条款');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (111, 'popup_open', 'rankOnlinePeoplelView', '打开-阿拉丁在线列表');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (112, 'popup_open', 'ReferAddTips', '打开-新增代理提示');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (113, 'popup_open', 'ReferEarn', '打开-代理界面');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (114, 'popup_open', 'ReferShareRule', '打开-代理规则');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (115, 'popup_open', 'resultTotalView', '打开-阿拉丁结果展示');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (116, 'popup_open', 'RoomFriendJoin', '打开-输入房间号');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (117, 'popup_open', 'RoomListView', '打开-机台界面');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (118, 'popup_open', 'SalonIncome', '打开-沙龙收益');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (119, 'popup_open', 'SalonRule', '打开-沙龙规则');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (120, 'popup_open', 'SceneTranslate', '打开-退出游戏过渡');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (121, 'popup_open', 'ShopWalletHintAmount', '打开-Bank-GameBalance');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (122, 'popup_open', 'ShopWalletHintCashBouns', '打开-Bank-CashBonus');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (123, 'popup_open', 'ShopWalletHintWinnings', '打开-Bank-Winnings');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (124, 'popup_open', 'SkinShop', '打开-皮肤背包');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (125, 'popup_open', 'table_info', '打开-桌子信息');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (126, 'popup_open', 'ToGameLoading', '打开-进入游戏Loading');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (127, 'popup_open', 'yd_bonus', '打开-Bonus');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (128, 'popup_open', 'yd_bonus_transfer', '打开-Bonus-转移详情');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (129, 'popup_open', 'yd_call_back', '打开-留言板');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (130, 'popup_open', 'yd_historical_record', '打开-历史记录');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (131, 'popup_open', 'yd_rank', '打开-排行榜');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (132, 'popup_open', 'yd_rebate_rule', '打开-Bonus-Rebaterule');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (133, 'popup_open', 'yd_rule_rewards', '打开-Bonus_Rewardsrule');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (134, 'popup_open', 'yd_safe', '打开-保险箱');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (135, 'popup_open', 'yd_transaction', '打开-Bank-transation');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (136, 'popup_open', 'yd_vip', '打开-VIP界面');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (137, 'popup_open', 'yd_vip_help', '打开-VIP规则');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (138, 'pop_mail_delall', ' ', '打开-邮件详情');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (139, 'pop_mail_open', ' ', '打开-站内信');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (140, 'quickstart', '0', NULL);
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (141, 'quickstart', '2', NULL);
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (142, 'Reg_succ', '', NULL);
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (182, 'salong_create_private', ' ', '沙龙-创建私人房');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (183, 'salong_create_public', ' ', '沙龙-创建公开房');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (184, 'salong_menu_switch_close', ' ', '沙龙-左菜单关');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (185, 'salong_menu_switch_open', ' ', '沙龙-左菜单开');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (186, 'salong_select_game_tab', '', '沙龙-切换游戏');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (193, 'salong_select_game_tab', '9999', '沙龙-切换游戏');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (194, 'salon_share', 'chat', '沙龙房-聊天邀请');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (195, 'salon_share', 'friend', '沙龙房-好友邀请');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (196, 'salon_share', 'other', '沙龙房-系统邀请');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (197, 'salon_share', 'uid', '沙龙房-UID邀请');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (198, 'salon_share', 'whatsapp', '沙龙房-WhatsApp邀请');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (199, 'send_express', '1,10244', '发送互动表情');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (200, 'setting_private', ' ', '打开-设置隐私');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (201, 'setting_service', ' ', '打开-设置服务');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (202, 'setting_sound_off', ' ', '音效关');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (203, 'sg_chat_send_emotion', '2', '聊天-发送表情');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (204, 'sg_chat_send_fw', '1', '聊天-发送快捷语句');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (205, 'sg_chat_send_input', ' ', '聊天-发送输入文字');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (206, 'sg_chat_view_record', ' ', '聊天-查看记录');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (207, 'sign_vip_reward_get', ' ', 'Bonus-获取签到奖励');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (208, 'skin_open', ' ', '打开皮肤背包');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (209, 'social_recent_friend_add', ' ', '社交-加好友');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (210, 'subgame_auto_500', ' ', 'SLOT-自动旋转500次');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (211, 'subgame_download_start', ' ', '子游戏下载开始');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (212, 'subgame_download_success', ' ', '子游戏下载成功');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (213, 'subgame_loading_start', ' ', '子游戏进入开始');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (214, 'subgame_loading_succ', ' ', '子游戏进入成功');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (215, 'subgame_stop_spin', ' ', 'SLOT-停止Spin');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (216, 'tabbar_open', 'FriendRoom', '大厅菜单-沙龙');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (217, 'tabbar_open', 'KnockoutMatch', '大厅菜单-赛事');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (218, 'tabbar_open', 'PageChat', '大厅菜单-世界聊天');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (219, 'tabbar_open', 'PageFriend', '大厅菜单-好友列表');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (220, 'tabbar_open', 'PageHall', '大厅菜单-游戏');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (221, 'tabbar_open', 'PagePrivateChat', '大厅菜单-私聊');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (222, 'tabbar_open', 'PageSocial', '大厅菜单-社交');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (223, 'tabbar_open', 'ShopViewMainV3', '大厅菜单-Bank');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (224, 'up_bet', ' ', 'SLOT-加注');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (225, 'userinfo_change_head', ' ', '切换头像');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (226, 'userinfo_change_head_default', '', '切换默认头像');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (227, 'userinfo_open', '', '点开玩家信息');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (228, 'vipsign1', ' ', '第1天签到');
INSERT INTO `s_config_statis` (`id`, `act`, `ext`, `title`) VALUES (229, 'vipsign2', ' ', '第2天签到');

ALTER TABLE `indiarummy_game`.`d_suspend` 
ADD INDEX `uid`(`userid`);

update d_user set forbidchat=0 where forbidchat is null;

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
  `svip` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT '' COMMENT 'Vip标签等级',
  `tag` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT '' COMMENT 'Tag标签等级',
  `targetuids` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT '' COMMENT '推荐给指定的好友uid',
  `stopregrebat` tinyint(1) DEFAULT NULL COMMENT '是否禁止返佣',
  PRIMARY KEY (`id`),
  KEY `idx_uid` (`userid`)
) ENGINE=InnoDB AUTO_INCREMENT=9 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='禁止列表';