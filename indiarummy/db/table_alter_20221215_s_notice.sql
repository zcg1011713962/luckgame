-- 公告
DROP TABLE IF EXISTS `s_notice`;
CREATE TABLE `s_notice` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `status` tinyint(1) DEFAULT '1' COMMENT '1正常 0过期',
  `ord` int(11) DEFAULT '0' COMMENT '排序，小的优先',
  `svip` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '支付层级',
  `title` varchar(127) COLLATE utf8mb4_bin DEFAULT NULL COMMENT '标题',
  `content` varchar(2047) COLLATE utf8mb4_bin DEFAULT NULL COMMENT '内容',
  `img` varchar(255) COLLATE utf8mb4_bin DEFAULT NULL COMMENT '图片地址',
  `jumpto` varchar(255) COLLATE utf8mb4_bin DEFAULT NULL COMMENT '跳转：Bank/Salon/Game/ReferEarn/Social/https:www.baidu.com',
  `create_time` int(11) DEFAULT NULL COMMENT '创建时间',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin COMMENT='活动公告';
