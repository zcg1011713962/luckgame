delete from d_mail_tpl where id in (16,17);
delete from s_game where id=691;

DROP TABLE IF EXISTS `d_stat_game`;
CREATE TABLE `d_stat_game` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `gameid` int(11) DEFAULT '0' COMMENT '游戏id',
  `roomtype` tinyint(1) DEFAULT NULL COMMENT '房间类型',
  `rooms` int(11) DEFAULT '0' COMMENT '房间数',
  `users` int(11) DEFAULT NULL COMMENT '玩游戏的人数',
  `totalbet` decimal(20,2) DEFAULT NULL COMMENT '用户下注',
  `totalwin` decimal(20,2) DEFAULT NULL COMMENT '用户赢钱',
  `create_time` int(11) DEFAULT NULL COMMENT '统计时间',
  PRIMARY KEY (`id`),
  KEY `time` (`create_time`,`gameid`,`roomtype`) USING BTREE
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin COMMENT='游戏数据统计';

ALTER TABLE `indiarummy_game`.`d_desk_user` MODIFY COLUMN `settle` varchar(1024) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NULL DEFAULT NULL AFTER `create_time`;