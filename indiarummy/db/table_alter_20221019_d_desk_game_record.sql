ALTER TABLE d_desk_game_record ADD COLUMN `ssid` int(11) DEFAULT 0 COMMENT '场次ID';
ALTER TABLE d_desk_game_record ADD COLUMN `issue` varchar(32) COLLATE utf8mb4_unicode_ci DEFAULT '' COMMENT '投注期号';

