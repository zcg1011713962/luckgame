ALTER TABLE `indiarummy_game`.`s_rake_back` 
ADD COLUMN `status` tinyint(1) NULL DEFAULT 0 COMMENT '1有效0无效' AFTER `uuid`;
ALTER TABLE `indiarummy_game`.`s_rake_back` 
ADD COLUMN `rate` varchar(255) NULL DEFAULT '1:0:0' COMMENT '优惠分成比例' AFTER `status`;
update `indiarummy_game`.`s_rake_back`  set rate='1:0:0' where id>0;
update `indiarummy_game`.`s_rake_back`  set `status`=1 where id>0;

ALTER TABLE `indiarummy_game`.`d_rake_back` 
ADD COLUMN `frate` varchar(255) NULL DEFAULT '1:0:0' COMMENT '各个钱包分成比例' AFTER `backcoin`;
update `d_rake_back`  set frate = '1:0:0' where id>0;

insert into s_config(k,v,memo) value('leaderboardgames','','支持排行榜的游戏');
ALTER TABLE `indiarummy_game`.`d_desk_user` ADD COLUMN `flag` tinyint(1) NULL DEFAULT 0 COMMENT '标记 1:算入排行榜' AFTER `issue`;
insert into s_config(k,v,memo) value('salonvip','4','创建和加入沙龙房需要的vip等级');

DROP TABLE IF EXISTS `s_pay_popup`;
CREATE TABLE `s_pay_popup` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `status` tinyint(1) DEFAULT '1' COMMENT '状态1:显示 0:不显示',
  `svip` varchar(255) COLLATE utf8mb4_bin DEFAULT '0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20' COMMENT 'vip等级',
  `content` varchar(1000) COLLATE utf8mb4_bin DEFAULT '' COMMENT '公告内容',
  `cat` tinyint(1) DEFAULT NULL COMMENT '1:充值 2:提现 3:绑定银行卡',
  `create_time` int(11) DEFAULT NULL,
  `cuid` int(11) DEFAULT NULL,
  `update_time` int(11) DEFAULT NULL,
  `uuid` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=4 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin COMMENT='弹窗配置';
ALTER TABLE `indiarummy_game`.`s_pay_popup` 
MODIFY COLUMN `content` varchar(1000) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NULL DEFAULT '' COMMENT '公告内容' AFTER `svip`;
INSERT INTO `s_pay_popup` (`id`, `status`, `svip`, `content`, `cat`, `create_time`, `cuid`, `update_time`, `uuid`) VALUES (1, 0, '0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20', 'test', 1, NULL, NULL, NULL, NULL);
INSERT INTO `s_pay_popup` (`id`, `status`, `svip`, `content`, `cat`, `create_time`, `cuid`, `update_time`, `uuid`) VALUES (2, 0, '0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20', 'test', 2, NULL, NULL, NULL, NULL);
INSERT INTO `s_pay_popup` (`id`, `status`, `svip`, `content`, `cat`, `create_time`, `cuid`, `update_time`, `uuid`) VALUES (3, 0, '0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20', 'test', 3, NULL, NULL, NULL, NULL);