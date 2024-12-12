-- 老的账号对账表
DROP TABLE IF EXISTS indiarummy_adm.stat_count;
-- 老的游戏统计表
DROP TABLE IF EXISTS indiarummy_adm.stat_games;
-- 老的游戏统计表 时序库
DROP TABLE IF EXISTS indiarummy_adm.stat_games_log;
-- 老的对账表
DROP TABLE IF EXISTS indiarummy_adm.stat_alarm;

--老的玩家金币表
DROP TABLE IF EXISTS indiarummy_adm.stat_coin_player;

ALTER TABLE `indiarummy_game`.`d_stat_coin` 
ADD COLUMN `in_draw` decimal(20, 4) NULL COMMENT '回收:提现成功' AFTER `in_prop`,
ADD COLUMN `in_admin` decimal(20, 4) NULL COMMENT '回收:后台下分' AFTER `in_draw`;

ALTER TABLE `indiarummy_game`.`d_log_cashbonus` 
ADD INDEX `idx_time`(`create_time`);