DROP TABLE IF EXISTS `indiarummy_game`.`d_log_msgoneerr`;
CREATE TABLE `indiarummy_game`.`d_log_msgoneerr` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `cat` smallint(5) unsigned DEFAULT '1' COMMENT '错误类型：1版本号 2手机型号或设备号为空 3设备号 4手机型号 5手机号验证码不对 6登录失败 7错误码',
  `msg` varchar(1000) COLLATE utf8mb4_bin DEFAULT NULL COMMENT '协议1内容',
  `create_time` int(11) DEFAULT NULL,
  `ip` int(11) DEFAULT '0',
  `platform` smallint(5) DEFAULT NULL,
  `errcode` int(11) DEFAULT '0' COMMENT '错误码',
  PRIMARY KEY (`id`),
  KEY `idx_time` (`create_time`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin COMMENT='协议1被屏蔽的记录';
ALTER TABLE `indiarummy_game`.`d_log_msgoneerr` 
ADD COLUMN `ddid` varchar(32) NULL DEFAULT '' COMMENT '设备号' AFTER `errcode`;

ALTER TABLE `indiarummy_game`.`d_app_log` 
ADD COLUMN `waistcoat` tinyint(1) NULL DEFAULT 0 COMMENT '是否是马甲包' AFTER `create_time`,
ADD COLUMN `isapp` tinyint(1) NULL DEFAULT 0 COMMENT '是否app请求' AFTER `waistcoat`,
ADD COLUMN `isnew` tinyint(1) NULL DEFAULT 0 COMMENT '是否新设备' AFTER `isapp`;

CREATE TABLE `indiarummy_game`.`d_app_log_202302` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `uid` int(10) DEFAULT '0' COMMENT 'uid',
  `act` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '操作类型',
  `ts` int(11) DEFAULT NULL COMMENT '操作时间',
  `ddid` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '设备id',
  `os` tinyint(1) DEFAULT NULL COMMENT '设备类型1安卓 2ios 3web',
  `appid` int(10) DEFAULT NULL COMMENT '客户端类型',
  `appver` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT '' COMMENT '客户端版本',
  `ip` varchar(64) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '客户端ip',
  `country` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '国家',
  `countrycn` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '国家中文',
  `city` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '城市',
  `latitude` double(20,6) DEFAULT NULL COMMENT '纬度',
  `longitude` double(20,6) DEFAULT NULL COMMENT '经度',
  `gameid` int(11) DEFAULT NULL COMMENT '子游戏id',
  `ext` varchar(300) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '扩展',
  `create_time` int(11) DEFAULT NULL COMMENT '服务器创建时间',
  `net` tinyint(4) DEFAULT '1',
  `phone` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT '',
  `waistcoat` tinyint(1) DEFAULT '0' COMMENT '是否是马甲包',
  `isapp`  tinyint(1) DEFAULT '0' COMMENT '是否是真实app',
  `isnew` tinyint(1) NULL DEFAULT 0 COMMENT '是否新用户',
  PRIMARY KEY (`id`),
  KEY `index_ts_ddid` (`ts`,`ddid`)
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='启动日志';

ALTER TABLE `indiarummy_game`.`d_statistics` 
MODIFY COLUMN `ext` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NULL DEFAULT '' COMMENT '操作类型唯一id' AFTER `itemid`;

DROP TABLE IF EXISTS `indiarummy_game`.`d_statistics_202302`;
CREATE TABLE `d_statistics_202302` (
  `id` int(11) NOT NULL AUTO_INCREMENT COMMENT '序列id',
  `uid` int(11) unsigned NOT NULL COMMENT '玩家uid',
  `act` varchar(1024) DEFAULT '' COMMENT '操作位置',
  `ts` int(11) DEFAULT NULL COMMENT '时间戳',
  `gameid` int(11) DEFAULT '0' COMMENT '游戏id',
  `menu` tinyint(1) DEFAULT '0' COMMENT '菜单id',
  `itemid` int(11) DEFAULT '0',
  `ext` varchar(100) DEFAULT '' COMMENT '操作类型唯一id',
  PRIMARY KEY (`id`),
  KEY `uid` (`uid`) USING BTREE,
  KEY `create_time` (`ts`)
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC COMMENT='245打点日志';
