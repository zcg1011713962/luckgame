-- 德州扑克需要特殊的游戏记录，比如rasie次数，call次数，check次数，allin次数，游戏次数，胜率等等
DROP TABLE IF EXISTS `d_texas_record`;
CREATE TABLE `d_texas_record` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `uid` int(11) DEFAULT NULL,
  `bet_coin` decimal(10,2) DEFAULT 0 COMMENT '下注金额',
  `win_coin` decimal(10,2) DEFAULT 0 COMMENT '赢取金额',
  `play_cnt` int(11) DEFAULT 0 COMMENT '玩的局数',
  `win_cnt` int(11) DEFAULT 0 COMMENT '赢取次数',
  `allin_cnt` int(11) DEFAULT 0 COMMENT 'allin次数',
  `raise` int(11) DEFAULT 0 COMMENT 'raise次数',
  `fold` int(11) DEFAULT 0 COMMENT 'fold次数',
  `max_win` decimal(10,2) DEFAULT 0 COMMENT '最大赢取奖池大小',
  `raise_preflop` int(11) DEFAULT 0 COMMENT 'preflop阶段加注次数',
  `raise_flop` int(11) DEFAULT 0 COMMENT 'preflop阶段加注次数',
  `raise_turn` int(11) DEFAULT 0 COMMENT 'preflop阶段加注次数',
  `raise_river` int(11) DEFAULT 0 COMMENT 'preflop阶段加注次数',
  `create_time` int(11) DEFAULT NULL,
  `update_time` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `uid` (`uid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='德州扑克额外记录';
