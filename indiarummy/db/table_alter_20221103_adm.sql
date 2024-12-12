DROP TABLE IF EXISTS `s_send_charm`;
CREATE TABLE `s_send_charm` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `title` varchar(300) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `title_al` varchar(300) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `img` varchar(300) COLLATE utf8mb4_unicode_ci DEFAULT '',
  `type` tinyint(2) DEFAULT '1' COMMENT '消耗金币或钻石',
  `count` int(11) DEFAULT '0',
  `charm` int(11) DEFAULT '0',
  `hot` tinyint(1) DEFAULT '0',
  `new` tinyint(1) DEFAULT NULL,
  `lamp` tinyint(1) DEFAULT '0' COMMENT '1播放跑马灯',
  `notice` tinyint(1) DEFAULT '0' COMMENT '1全服通告',
  `questid` int(11) DEFAULT '0',
  `cat` int(11) DEFAULT NULL,
  `isvip` tinyint(1) DEFAULT NULL,
  `level` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=19 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='魅力值道具';

INSERT INTO `s_send_charm` (`id`, `title`, `title_al`, `img`, `type`, `count`, `charm`, `hot`, `new`, `lamp`, `notice`, `questid`, `cat`, `isvip`, `level`) VALUES (1, 'slipper', 'النعال', 'gift_1', 1, 1000, 0, 0, NULL, 0, 0, 0, 2, NULL, 0);
INSERT INTO `s_send_charm` (`id`, `title`, `title_al`, `img`, `type`, `count`, `charm`, `hot`, `new`, `lamp`, `notice`, `questid`, `cat`, `isvip`, `level`) VALUES (2, 'flower', 'بيرة', 'gift_2', 1, 2000, 0, 0, NULL, 0, 0, 0, 2, NULL, 0);
INSERT INTO `s_send_charm` (`id`, `title`, `title_al`, `img`, `type`, `count`, `charm`, `hot`, `new`, `lamp`, `notice`, `questid`, `cat`, `isvip`, `level`) VALUES (3, 'durian', 'دوريان', 'gift_3', 1, 3000, 0, 0, NULL, 0, 0, 0, 2, NULL, 0);
INSERT INTO `s_send_charm` (`id`, `title`, `title_al`, `img`, `type`, `count`, `charm`, `hot`, `new`, `lamp`, `notice`, `questid`, `cat`, `isvip`, `level`) VALUES (4, 'egg', 'بيضة', 'gift_4', 1, 4000, 0, 0, NULL, 0, 0, 0, 2, NULL, 0);
INSERT INTO `s_send_charm` (`id`, `title`, `title_al`, `img`, `type`, `count`, `charm`, `hot`, `new`, `lamp`, `notice`, `questid`, `cat`, `isvip`, `level`) VALUES (5, 'lips', 'شفه', 'gift_5', 1, 5000, 0, 0, NULL, 0, 0, 0, 2, NULL, 0);
INSERT INTO `s_send_charm` (`id`, `title`, `title_al`, `img`, `type`, `count`, `charm`, `hot`, `new`, `lamp`, `notice`, `questid`, `cat`, `isvip`, `level`) VALUES (6, 'money', 'مال', 'gift_6', 1, 5000, 0, 0, NULL, 0, 0, 0, 2, NULL, 0);
INSERT INTO `s_send_charm` (`id`, `title`, `title_al`, `img`, `type`, `count`, `charm`, `hot`, `new`, `lamp`, `notice`, `questid`, `cat`, `isvip`, `level`) VALUES (7, 'vip', 'vip', 'gift_7', 1, 0, 0, 0, NULL, 0, 0, 0, 2, 1, 1);
INSERT INTO `s_send_charm` (`id`, `title`, `title_al`, `img`, `type`, `count`, `charm`, `hot`, `new`, `lamp`, `notice`, `questid`, `cat`, `isvip`, `level`) VALUES (8, 'vip5', 'vip5', 'gift_8', 1, 0, 0, 0, NULL, 0, 0, 0, 2, 1, 5);
INSERT INTO `s_send_charm` (`id`, `title`, `title_al`, `img`, `type`, `count`, `charm`, `hot`, `new`, `lamp`, `notice`, `questid`, `cat`, `isvip`, `level`) VALUES (9, 'vip7', 'vip7', 'gift_9', 1, 0, 0, 0, NULL, 0, 0, 0, 2, 1, 7);
INSERT INTO `s_send_charm` (`id`, `title`, `title_al`, `img`, `type`, `count`, `charm`, `hot`, `new`, `lamp`, `notice`, `questid`, `cat`, `isvip`, `level`) VALUES (10, 'vip9', 'vip9', 'gift_10', 1, 0, 0, 0, NULL, 0, 0, 0, 2, 1, 9);
INSERT INTO `s_send_charm` (`id`, `title`, `title_al`, `img`, `type`, `count`, `charm`, `hot`, `new`, `lamp`, `notice`, `questid`, `cat`, `isvip`, `level`) VALUES (11, 'vip11', 'vip11', 'gift_11', 1, 0, 0, 0, NULL, 0, 0, 0, 2, 1, 11);
INSERT INTO `s_send_charm` (`id`, `title`, `title_al`, `img`, `type`, `count`, `charm`, `hot`, `new`, `lamp`, `notice`, `questid`, `cat`, `isvip`, `level`) VALUES (12, 'vip12', 'vip12', 'gift_12', 1, 0, 0, 0, NULL, 0, 0, 0, 2, 1, 12);
INSERT INTO `s_send_charm` (`id`, `title`, `title_al`, `img`, `type`, `count`, `charm`, `hot`, `new`, `lamp`, `notice`, `questid`, `cat`, `isvip`, `level`) VALUES (13, 'sports car', 'سيارة سباق ', 'gift_car', 25, 10000, 10000, 0, NULL, 1, 1, 1, 1, NULL, NULL);
INSERT INTO `s_send_charm` (`id`, `title`, `title_al`, `img`, `type`, `count`, `charm`, `hot`, `new`, `lamp`, `notice`, `questid`, `cat`, `isvip`, `level`) VALUES (14, 'kiss', 'قبلة', 'gift_kiss', 25, 1000, 1000, 0, NULL, 1, 1, 1, 1, NULL, NULL);
INSERT INTO `s_send_charm` (`id`, `title`, `title_al`, `img`, `type`, `count`, `charm`, `hot`, `new`, `lamp`, `notice`, `questid`, `cat`, `isvip`, `level`) VALUES (15, 'ring', 'خاتم', 'gift_ring', 25, 5000, 5000, 0, NULL, 1, 1, 1, 1, NULL, NULL);
INSERT INTO `s_send_charm` (`id`, `title`, `title_al`, `img`, `type`, `count`, `charm`, `hot`, `new`, `lamp`, `notice`, `questid`, `cat`, `isvip`, `level`) VALUES (16, 'Dessert', 'الحلوى', 'gift_cake', 25, 500, 500, 0, NULL, 1, 1, 1, 1, NULL, NULL);
INSERT INTO `s_send_charm` (`id`, `title`, `title_al`, `img`, `type`, `count`, `charm`, `hot`, `new`, `lamp`, `notice`, `questid`, `cat`, `isvip`, `level`) VALUES (17, 'hookah', 'الشيشة', 'gift_hookah', 25, 800, 800, 0, NULL, 1, 1, 1, 1, NULL, NULL);
INSERT INTO `s_send_charm` (`id`, `title`, `title_al`, `img`, `type`, `count`, `charm`, `hot`, `new`, `lamp`, `notice`, `questid`, `cat`, `isvip`, `level`) VALUES (18, 'coffee', 'قهوة', 'gift_tea', 25, 600, 600, 0, NULL, 1, 1, 1, 1, NULL, NULL);

delete from s_quest where id=141;

ALTER TABLE `indiarummy_game`.`d_user_recharge` ADD COLUMN `isfirst` tinyint(1) NULL DEFAULT 0 AFTER `rsamount`;

update d_user_bank set `status`=2 where `status`=1;
update d_user set ispayer=ispay ;
ALTER TABLE `indiarummy_game`.`d_user` CHANGE COLUMN `ispay` `stopregrebat` tinyint(1) NULL DEFAULT 0 COMMENT '停止给上级注册返利' AFTER `kyc`;