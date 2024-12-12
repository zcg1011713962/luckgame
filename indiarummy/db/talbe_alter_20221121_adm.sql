update d_user_draw set chanstate=2 where status=2;
update d_user_draw set chanstate=4 where status=3;
ALTER TABLE `indiarummy_game`.`d_user_draw` 
MODIFY COLUMN `type` tinyint(1) NULL DEFAULT 1 COMMENT '类型 1:银行 2:usdt' AFTER `memo`;
update d_user_draw set `type`=1;
ALTER TABLE `indiarummy_game`.`d_user_draw` 
ADD COLUMN `readed` tinyint(1) NULL DEFAULT 0 COMMENT '是否已经看过' AFTER `notify_time`;

ALTER TABLE `indiarummy_game`.`d_user_recharge` 
ADD COLUMN `readed` tinyint(1) NULL DEFAULT 0 COMMENT '是否已经看过' AFTER `isfirst`;

delete from d_sys_mail where id=2;
INSERT INTO `d_sys_mail` (`id`, `title`, `msg`, `attach`, `timestamp`, `stype`, `bonus_type`, `cover_img`, `title_al`, `msg_al`, `svip`, `rate`) VALUES (2, 'Welcome to Yono Games', 'We\'re so thrilled you decided to join our big community from where you can easily create your own world, embrace the challengs, enjoy the fun and win big prifits!\r\nAre you ready to get rewarded? Start your adventure now!', '[]', 1611292940, 8, NULL, NULL, '', '', NULL, NULL);

DROP TABLE IF EXISTS `d_mail_tpl`;
CREATE TABLE `d_mail_tpl` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `type` int(11) DEFAULT '0' COMMENT '类型',
  `title` varchar(255) COLLATE utf8mb4_bin DEFAULT NULL COMMENT '邮件标题',
  `content` text COLLATE utf8mb4_bin COMMENT '邮件内容',
  `status` tinyint(1) DEFAULT '1' COMMENT '1:有效 0:无效',
  `param1` int(11) DEFAULT NULL COMMENT '参数1:根据类型变动',
  `param2` int(11) DEFAULT NULL COMMENT '参数2:辅助参数',
  `coin` int(11) DEFAULT '0' COMMENT '奖励金币',
  `svip` varchar(255) COLLATE utf8mb4_bin DEFAULT NULL COMMENT 'vip类型',
  `rate` varchar(255) COLLATE utf8mb4_bin DEFAULT '' COMMENT '奖金分成比例',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=18 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin COMMENT='邮件模板';

INSERT INTO `d_mail_tpl` (`id`, `type`, `title`, `content`, `status`, `param1`, `param2`, `coin`, `svip`, `rate`) VALUES (1, 24, 'Welcome back to Yono Games', 'We\'re so glad to see you again, please take the bonus as our gift for your return. We wish you have fun and win big here!', 1, 2, NULL, 0, NULL, '');
INSERT INTO `d_mail_tpl` (`id`, `type`, `title`, `content`, `status`, `param1`, `param2`, `coin`, `svip`, `rate`) VALUES (2, 25, 'First deposit successfully', 'Congratulations, your first deposit completed successfully! We know you\'ve smoothly mastered the deposit skill in Yono Games, but our 24/7 online support is here in case of any issues you may encounter!', 1, NULL, NULL, 0, NULL, '');
INSERT INTO `d_mail_tpl` (`id`, `type`, `title`, `content`, `status`, `param1`, `param2`, `coin`, `svip`, `rate`) VALUES (3, 26, 'First withdrawal successfully', 'Congratulations, your first withdrawal completed successfully! We know you\'ve smoothly mastered the withdrawal skill in Yono Games, but our 24/7 online support is here in case of any issues you may encounter!', 1, NULL, NULL, 0, NULL, '');
INSERT INTO `d_mail_tpl` (`id`, `type`, `title`, `content`, `status`, `param1`, `param2`, `coin`, `svip`, `rate`) VALUES (4, 27, 'First refer successfully', 'Congratulations, first player joined your team successfully! You\'re so close to our huge and unlimited agent rewards, let\'s keep refering more players to expand your team and increase your income. For any questions about the refer, please contact our 24/7 customer service support!', 1, NULL, NULL, 0, NULL, '');
INSERT INTO `d_mail_tpl` (`id`, `type`, `title`, `content`, `status`, `param1`, `param2`, `coin`, `svip`, `rate`) VALUES (5, 28, 'First refer&earn bonus claim successfully', 'Congratulations, first Refer&Earn bonus claimed successfully! More bonuses are coming your way, let\'s keep refering more players to expand your team and increase your income.  For any questions about the refer, please contact our 24/7 customer service support!', 1, NULL, NULL, 0, NULL, '');
INSERT INTO `d_mail_tpl` (`id`, `type`, `title`, `content`, `status`, `param1`, `param2`, `coin`, `svip`, `rate`) VALUES (6, 29, 'Leaderboard rewards', 'Congratulations, you have won the leaderboard rewards for high rankings.We offer daily,weekly and monthly leaderboards rewards for players,the more you played ,the higher you ranked ,the more rewards you claimed.Any questions about your ranking,please connect our 24/7 customer service support!', 1, 3, NULL, 0, NULL, '');
INSERT INTO `d_mail_tpl` (`id`, `type`, `title`, `content`, `status`, `param1`, `param2`, `coin`, `svip`, `rate`) VALUES (7, 17, 'Leaderboard rewards', 'Congratulations, you have won the leaderboard rewards for high rankings.We offer daily,weekly and monthly leaderboards rewards for players,the more you played ,the higher you ranked ,the more rewards you claimed.Any questions about your ranking,please connect our 24/7 customer service support!', 1, NULL, NULL, 0, NULL, '');
INSERT INTO `d_mail_tpl` (`id`, `type`, `title`, `content`, `status`, `param1`, `param2`, `coin`, `svip`, `rate`) VALUES (8, 18, 'Deposit successfully', 'Dear XXX, you have successfully deposited [XXX].Start playing and create your own world, we hope you enjoy your time and win big in Yono Games. For any questions about the deposit, please contact our 24/7 customer service support!', 1, NULL, NULL, 0, NULL, '');
INSERT INTO `d_mail_tpl` (`id`, `type`, `title`, `content`, `status`, `param1`, `param2`, `coin`, `svip`, `rate`) VALUES (9, 30, 'Withdrawal successfully', 'Dear XXX, you have successfully withdrawn [XXX], the amount will be arrived in your bank/usdt account within 5 minutes. For any questions about the withdrawal, please contact our 24/7 customer service support!', 1, NULL, NULL, 0, NULL, '');
INSERT INTO `d_mail_tpl` (`id`, `type`, `title`, `content`, `status`, `param1`, `param2`, `coin`, `svip`, `rate`) VALUES (10, 31, 'Withdrawal refund', 'Dear XXX, your withdrawal of [XXX] has been failed and the amount has been refunded to your game account. The reasons are as follows:XXX. For any questions about the withdrawal, please contact our 24/7 customer service support!', 1, NULL, NULL, 0, NULL, '');
INSERT INTO `d_mail_tpl` (`id`, `type`, `title`, `content`, `status`, `param1`, `param2`, `coin`, `svip`, `rate`) VALUES (11, 32, 'Mobile number verified', 'You have successfully verified your mobile number.', 1, NULL, NULL, 0, NULL, '');
INSERT INTO `d_mail_tpl` (`id`, `type`, `title`, `content`, `status`, `param1`, `param2`, `coin`, `svip`, `rate`) VALUES (12, 33, 'PAN verified', 'You have successfully verified your PAN', 1, NULL, NULL, 0, NULL, '');
INSERT INTO `d_mail_tpl` (`id`, `type`, `title`, `content`, `status`, `param1`, `param2`, `coin`, `svip`, `rate`) VALUES (13, 34, 'PAN verify failed', 'PAN verification failed,the reasons are as follows:XXX', 1, NULL, NULL, 0, NULL, '');
INSERT INTO `d_mail_tpl` (`id`, `type`, `title`, `content`, `status`, `param1`, `param2`, `coin`, `svip`, `rate`) VALUES (14, 35, 'Bank account verified', 'You have successfully verified your bank account', 1, NULL, NULL, 0, NULL, '');
INSERT INTO `d_mail_tpl` (`id`, `type`, `title`, `content`, `status`, `param1`, `param2`, `coin`, `svip`, `rate`) VALUES (15, 36, 'Bank account verify failed', 'Bank account verification failed,the reasons are as follows:XXX', 1, NULL, NULL, 0, NULL, '');