DROP TABLE IF EXISTS `d_lb_agent`;
CREATE TABLE `d_lb_agent` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `invit_uid` bigint(20) DEFAULT NULL COMMENT '上级代理uid',
  `uid` bigint(20) DEFAULT NULL COMMENT 'uid',
  `create_time` int(11) DEFAULT NULL COMMENT '日期对应的时间戳',
  `bet` decimal(20,2) DEFAULT NULL COMMENT '下注',
  `wincoin` decimal(20,2) DEFAULT NULL COMMENT '赢分',
  PRIMARY KEY (`id`),
  UNIQUE KEY `idx_inviteuid` (`invit_uid`,`uid`,`create_time`) USING BTREE,
  KEY `idx_time` (`create_time`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin COMMENT='代理排行榜中间表';