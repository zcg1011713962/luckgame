ALTER TABLE `d_tn_config` ADD `win_ratio` VARCHAR(128) DEFAULT '' COMMENT '赢家获奖比例(百分比)eg: 30.0,20.0,10.0,10.0,10.0,10.0,10.0' AFTER `max_cnt`;

create index `idx_tn_result` on `d_tn_result`(`tn_id`, `date`);
create index `idx_tn_register` on `d_tn_register`(`tn_id`, `date`, `uid`);

create index `idx_lb_reward_log` on `d_lb_reward_log`(`settle_date`, `rtype`);

TRUNCATE TABLE `d_tn_config`;
INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(1,293,10,3,30, "30,20,10,10,10,5,5,5,5",'00:00','00:05',300,180, 2,100,70, 1666927803, 1666927803);

INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(2,293,10,3,30, "30,20,10,10,10,5,5,5,5",'00:10','00:15',300,180, 2,100,70, 1666927803, 1666927803);

INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(3,293,10,3,30, "30,20,10,10,10,5,5,5,5",'00:20','00:25',300,180, 2,100,70, 1666927803, 1666927803);

INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(4,293,10,3,30, "30,20,10,10,10,5,5,5,5",'00:30','00:35',300,180, 2,100,70, 1666927803, 1666927803);

INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(5,293,10,3,30, "30,20,10,10,10,5,5,5,5",'00:40','00:45',300,180, 2,100,70, 1666927803, 1666927803);

INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(6,293,10,3,30, "30,20,10,10,10,5,5,5,5",'00:50','00:55',300,180, 2,100,70, 1666927803, 1666927803);

INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(7,293,10,3,30, "30,20,10,10,10,5,5,5,5",'01:00','01:05',300,180, 2,100,70, 1666927803, 1666927803);

INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(8,293,10,3,30, "30,20,10,10,10,5,5,5,5",'01:10','01:15',300,180, 2,100,70, 1666927803, 1666927803);

INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(9,293,10,3,30, "30,20,10,10,10,5,5,5,5",'01:20','01:25',300,180, 2,100,70, 1666927803, 1666927803);

INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(10,293,10,3,30, "30,20,10,10,10,5,5,5,5",'01:30','01:35',300,180, 2,100,70, 1666927803, 1666927803);

INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(11,293,10,3,30, "30,20,10,10,10,5,5,5,5",'01:40','01:45',300,180, 2,100,70, 1666927803, 1666927803);

INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(12,293,10,3,30, "30,20,10,10,10,5,5,5,5",'01:50','01:55',300,180, 2,100,70, 1666927803, 1666927803);

INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(13,293,10,3,30, "30,20,10,10,10,5,5,5,5",'02:00','02:05',300,180, 2,100,70, 1666927803, 1666927803);

INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(14,293,10,3,30, "30,20,10,10,10,5,5,5,5",'02:10','02:15',300,180, 2,100,70, 1666927803, 1666927803);

INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(15,293,10,3,30, "30,20,10,10,10,5,5,5,5",'02:20','02:25',300,180, 2,100,70, 1666927803, 1666927803);

INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(16,293,10,3,30, "30,20,10,10,10,5,5,5,5",'02:30','02:35',300,180, 2,100,70, 1666927803, 1666927803);

INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(17,293,10,3,30, "30,20,10,10,10,5,5,5,5",'02:40','02:45',300,180, 2,100,70, 1666927803, 1666927803);

INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(18,293,10,3,30, "30,20,10,10,10,5,5,5,5",'02:50','02:55',300,180, 2,100,70, 1666927803, 1666927803);

INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(19,293,10,3,30, "30,20,10,10,10,5,5,5,5",'03:00','03:05',300,180, 2,100,70, 1666927803, 1666927803);

INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(20,293,10,3,30, "30,20,10,10,10,5,5,5,5",'03:10','03:15',300,180, 2,100,70, 1666927803, 1666927803);

INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(21,293,10,3,30, "30,20,10,10,10,5,5,5,5",'03:20','03:25',300,180, 2,100,70, 1666927803, 1666927803);

INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(22,293,10,3,30, "30,20,10,10,10,5,5,5,5",'03:30','03:35',300,180, 2,100,70, 1666927803, 1666927803);

INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(23,293,10,3,30, "30,20,10,10,10,5,5,5,5",'03:40','03:45',300,180, 2,100,70, 1666927803, 1666927803);

INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(24,293,10,3,30, "30,20,10,10,10,5,5,5,5",'03:50','03:55',300,180, 2,100,70, 1666927803, 1666927803);

INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(25,293,10,3,30, "30,20,10,10,10,5,5,5,5",'04:00','04:05',300,180, 2,100,70, 1666927803, 1666927803);

INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(26,293,10,3,30, "30,20,10,10,10,5,5,5,5",'04:10','04:15',300,180, 2,100,70, 1666927803, 1666927803);

INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(27,293,10,3,30, "30,20,10,10,10,5,5,5,5",'04:20','04:25',300,180, 2,100,70, 1666927803, 1666927803);

INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(28,293,10,3,30, "30,20,10,10,10,5,5,5,5",'04:30','04:35',300,180, 2,100,70, 1666927803, 1666927803);

INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(29,293,10,3,30, "30,20,10,10,10,5,5,5,5",'04:40','04:45',300,180, 2,100,70, 1666927803, 1666927803);

INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(30,293,10,3,30, "30,20,10,10,10,5,5,5,5",'04:50','04:55',300,180, 2,100,70, 1666927803, 1666927803);

INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(31,293,10,3,30, "30,20,10,10,10,5,5,5,5",'05:00','05:05',300,180, 2,100,70, 1666927803, 1666927803);

INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(32,293,10,3,30, "30,20,10,10,10,5,5,5,5",'05:10','05:15',300,180, 2,100,70, 1666927803, 1666927803);

INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(33,293,10,3,30, "30,20,10,10,10,5,5,5,5",'05:20','05:25',300,180, 2,100,70, 1666927803, 1666927803);

INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(34,293,10,3,30, "30,20,10,10,10,5,5,5,5",'05:30','05:35',300,180, 2,100,70, 1666927803, 1666927803);

INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(35,293,10,3,30, "30,20,10,10,10,5,5,5,5",'05:40','05:45',300,180, 2,100,70, 1666927803, 1666927803);

INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(36,293,10,3,30, "30,20,10,10,10,5,5,5,5",'05:50','05:55',300,180, 2,100,70, 1666927803, 1666927803);

INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(37,293,10,3,30, "30,20,10,10,10,5,5,5,5",'06:00','06:05',300,180, 2,100,70, 1666927803, 1666927803);

INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(38,293,10,3,30, "30,20,10,10,10,5,5,5,5",'06:10','06:15',300,180, 2,100,70, 1666927803, 1666927803);

INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(39,293,10,3,30, "30,20,10,10,10,5,5,5,5",'06:20','06:25',300,180, 2,100,70, 1666927803, 1666927803);

INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(40,293,10,3,30, "30,20,10,10,10,5,5,5,5",'06:30','06:35',300,180, 2,100,70, 1666927803, 1666927803);

INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(41,293,10,3,30, "30,20,10,10,10,5,5,5,5",'06:40','06:45',300,180, 2,100,70, 1666927803, 1666927803);

INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(42,293,10,3,30, "30,20,10,10,10,5,5,5,5",'06:50','06:55',300,180, 2,100,70, 1666927803, 1666927803);

INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(43,293,10,3,30, "30,20,10,10,10,5,5,5,5",'07:00','07:05',300,180, 2,100,70, 1666927803, 1666927803);

INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(44,293,10,3,30, "30,20,10,10,10,5,5,5,5",'07:10','07:15',300,180, 2,100,70, 1666927803, 1666927803);

INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(45,293,10,3,30, "30,20,10,10,10,5,5,5,5",'07:20','07:25',300,180, 2,100,70, 1666927803, 1666927803);

INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(46,293,10,3,30, "30,20,10,10,10,5,5,5,5",'07:30','07:35',300,180, 2,100,70, 1666927803, 1666927803);

INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(47,293,10,3,30, "30,20,10,10,10,5,5,5,5",'07:40','07:45',300,180, 2,100,70, 1666927803, 1666927803);

INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(48,293,10,3,30, "30,20,10,10,10,5,5,5,5",'07:50','07:55',300,180, 2,100,70, 1666927803, 1666927803);

INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(49,293,10,3,30, "30,20,10,10,10,5,5,5,5",'08:00','08:05',300,180, 2,100,70, 1666927803, 1666927803);

INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(50,293,10,3,30, "30,20,10,10,10,5,5,5,5",'08:10','08:15',300,180, 2,100,70, 1666927803, 1666927803);

INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(51,293,10,3,30, "30,20,10,10,10,5,5,5,5",'08:20','08:25',300,180, 2,100,70, 1666927803, 1666927803);

INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(52,293,10,3,30, "30,20,10,10,10,5,5,5,5",'08:30','08:35',300,180, 2,100,70, 1666927803, 1666927803);

INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(53,293,10,3,30, "30,20,10,10,10,5,5,5,5",'08:40','08:45',300,180, 2,100,70, 1666927803, 1666927803);

INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(54,293,10,3,30, "30,20,10,10,10,5,5,5,5",'08:50','08:55',300,180, 2,100,70, 1666927803, 1666927803);

INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(55,293,10,3,30, "30,20,10,10,10,5,5,5,5",'09:00','09:05',300,180, 2,100,70, 1666927803, 1666927803);

INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(56,293,10,3,30, "30,20,10,10,10,5,5,5,5",'09:10','09:15',300,180, 2,100,70, 1666927803, 1666927803);

INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(57,293,10,3,30, "30,20,10,10,10,5,5,5,5",'09:20','09:25',300,180, 2,100,70, 1666927803, 1666927803);

INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(58,293,10,3,30, "30,20,10,10,10,5,5,5,5",'09:30','09:35',300,180, 2,100,70, 1666927803, 1666927803);

INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(59,293,10,3,30, "30,20,10,10,10,5,5,5,5",'09:40','09:45',300,180, 2,100,70, 1666927803, 1666927803);

INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(60,293,10,3,30, "30,20,10,10,10,5,5,5,5",'09:50','09:55',300,180, 2,100,70, 1666927803, 1666927803);

INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(61,293,10,3,30, "30,20,10,10,10,5,5,5,5",'10:00','10:05',300,180, 2,100,70, 1666927803, 1666927803);

INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(62,293,10,3,30, "30,20,10,10,10,5,5,5,5",'10:10','10:15',300,180, 2,100,70, 1666927803, 1666927803);

INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(63,293,10,3,30, "30,20,10,10,10,5,5,5,5",'10:20','10:25',300,180, 2,100,70, 1666927803, 1666927803);

INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(64,293,10,3,30, "30,20,10,10,10,5,5,5,5",'10:30','10:35',300,180, 2,100,70, 1666927803, 1666927803);

INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(65,293,10,3,30, "30,20,10,10,10,5,5,5,5",'10:40','10:45',300,180, 2,100,70, 1666927803, 1666927803);

INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(66,293,10,3,30, "30,20,10,10,10,5,5,5,5",'10:50','10:55',300,180, 2,100,70, 1666927803, 1666927803);

INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(67,293,10,3,30, "30,20,10,10,10,5,5,5,5",'11:00','11:05',300,180, 2,100,70, 1666927803, 1666927803);

INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(68,293,10,3,30, "30,20,10,10,10,5,5,5,5",'11:10','11:15',300,180, 2,100,70, 1666927803, 1666927803);

INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(69,293,10,3,30, "30,20,10,10,10,5,5,5,5",'11:20','11:25',300,180, 2,100,70, 1666927803, 1666927803);

INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(70,293,10,3,30, "30,20,10,10,10,5,5,5,5",'11:30','11:35',300,180, 2,100,70, 1666927803, 1666927803);

INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(71,293,10,3,30, "30,20,10,10,10,5,5,5,5",'11:40','11:45',300,180, 2,100,70, 1666927803, 1666927803);

INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(72,293,10,3,30, "30,20,10,10,10,5,5,5,5",'11:50','11:55',300,180, 2,100,70, 1666927803, 1666927803);

INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(73,293,10,3,30, "30,20,10,10,10,5,5,5,5",'12:00','12:05',300,180, 2,100,70, 1666927803, 1666927803);

INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(74,293,10,3,30, "30,20,10,10,10,5,5,5,5",'12:10','12:15',300,180, 2,100,70, 1666927803, 1666927803);

INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(75,293,10,3,30, "30,20,10,10,10,5,5,5,5",'12:20','12:25',300,180, 2,100,70, 1666927803, 1666927803);

INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(76,293,10,3,30, "30,20,10,10,10,5,5,5,5",'12:30','12:35',300,180, 2,100,70, 1666927803, 1666927803);

INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(77,293,10,3,30, "30,20,10,10,10,5,5,5,5",'12:40','12:45',300,180, 2,100,70, 1666927803, 1666927803);

INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(78,293,10,3,30, "30,20,10,10,10,5,5,5,5",'12:50','12:55',300,180, 2,100,70, 1666927803, 1666927803);

INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(79,293,10,3,30, "30,20,10,10,10,5,5,5,5",'13:00','13:05',300,180, 2,100,70, 1666927803, 1666927803);

INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(80,293,10,3,30, "30,20,10,10,10,5,5,5,5",'13:10','13:15',300,180, 2,100,70, 1666927803, 1666927803);

INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(81,293,10,3,30, "30,20,10,10,10,5,5,5,5",'13:20','13:25',300,180, 2,100,70, 1666927803, 1666927803);

INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(82,293,10,3,30, "30,20,10,10,10,5,5,5,5",'13:30','13:35',300,180, 2,100,70, 1666927803, 1666927803);

INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(83,293,10,3,30, "30,20,10,10,10,5,5,5,5",'13:40','13:45',300,180, 2,100,70, 1666927803, 1666927803);

INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(84,293,10,3,30, "30,20,10,10,10,5,5,5,5",'13:50','13:55',300,180, 2,100,70, 1666927803, 1666927803);

INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(85,293,10,3,30, "30,20,10,10,10,5,5,5,5",'14:00','14:05',300,180, 2,100,70, 1666927803, 1666927803);

INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(86,293,10,3,30, "30,20,10,10,10,5,5,5,5",'14:10','14:15',300,180, 2,100,70, 1666927803, 1666927803);

INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(87,293,10,3,30, "30,20,10,10,10,5,5,5,5",'14:20','14:25',300,180, 2,100,70, 1666927803, 1666927803);

INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(88,293,10,3,30, "30,20,10,10,10,5,5,5,5",'14:30','14:35',300,180, 2,100,70, 1666927803, 1666927803);

INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(89,293,10,3,30, "30,20,10,10,10,5,5,5,5",'14:40','14:45',300,180, 2,100,70, 1666927803, 1666927803);

INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(90,293,10,3,30, "30,20,10,10,10,5,5,5,5",'14:50','14:55',300,180, 2,100,70, 1666927803, 1666927803);

INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(91,293,10,3,30, "30,20,10,10,10,5,5,5,5",'15:00','15:05',300,180, 2,100,70, 1666927803, 1666927803);

INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(92,293,10,3,30, "30,20,10,10,10,5,5,5,5",'15:10','15:15',300,180, 2,100,70, 1666927803, 1666927803);

INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(93,293,10,3,30, "30,20,10,10,10,5,5,5,5",'15:20','15:25',300,180, 2,100,70, 1666927803, 1666927803);

INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(94,293,10,3,30, "30,20,10,10,10,5,5,5,5",'15:30','15:35',300,180, 2,100,70, 1666927803, 1666927803);

INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(95,293,10,3,30, "30,20,10,10,10,5,5,5,5",'15:40','15:45',300,180, 2,100,70, 1666927803, 1666927803);

INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(96,293,10,3,30, "30,20,10,10,10,5,5,5,5",'15:50','15:55',300,180, 2,100,70, 1666927803, 1666927803);

INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(97,293,10,3,30, "30,20,10,10,10,5,5,5,5",'16:00','16:05',300,180, 2,100,70, 1666927803, 1666927803);

INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(98,293,10,3,30, "30,20,10,10,10,5,5,5,5",'16:10','16:15',300,180, 2,100,70, 1666927803, 1666927803);

INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(99,293,10,3,30, "30,20,10,10,10,5,5,5,5",'16:20','16:25',300,180, 2,100,70, 1666927803, 1666927803);

INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(100,293,10,3,30, "30,20,10,10,10,5,5,5,5",'16:30','16:35',300,180, 2,100,70, 1666927803, 1666927803);

INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(101,293,10,3,30, "30,20,10,10,10,5,5,5,5",'16:40','16:45',300,180, 2,100,70, 1666927803, 1666927803);

INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(102,293,10,3,30, "30,20,10,10,10,5,5,5,5",'16:50','16:55',300,180, 2,100,70, 1666927803, 1666927803);

INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(103,293,10,3,30, "30,20,10,10,10,5,5,5,5",'17:00','17:05',300,180, 2,100,70, 1666927803, 1666927803);

INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(104,293,10,3,30, "30,20,10,10,10,5,5,5,5",'17:10','17:15',300,180, 2,100,70, 1666927803, 1666927803);

INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(105,293,10,3,30, "30,20,10,10,10,5,5,5,5",'17:20','17:25',300,180, 2,100,70, 1666927803, 1666927803);

INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(106,293,10,3,30, "30,20,10,10,10,5,5,5,5",'17:30','17:35',300,180, 2,100,70, 1666927803, 1666927803);

INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(107,293,10,3,30, "30,20,10,10,10,5,5,5,5",'17:40','17:45',300,180, 2,100,70, 1666927803, 1666927803);

INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(108,293,10,3,30, "30,20,10,10,10,5,5,5,5",'17:50','17:55',300,180, 2,100,70, 1666927803, 1666927803);

INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(109,293,10,3,30, "30,20,10,10,10,5,5,5,5",'18:00','18:05',300,180, 2,100,70, 1666927803, 1666927803);

INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(110,293,10,3,30, "30,20,10,10,10,5,5,5,5",'18:10','18:15',300,180, 2,100,70, 1666927803, 1666927803);

INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(111,293,10,3,30, "30,20,10,10,10,5,5,5,5",'18:20','18:25',300,180, 2,100,70, 1666927803, 1666927803);

INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(112,293,10,3,30, "30,20,10,10,10,5,5,5,5",'18:30','18:35',300,180, 2,100,70, 1666927803, 1666927803);

INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(113,293,10,3,30, "30,20,10,10,10,5,5,5,5",'18:40','18:45',300,180, 2,100,70, 1666927803, 1666927803);

INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(114,293,10,3,30, "30,20,10,10,10,5,5,5,5",'18:50','18:55',300,180, 2,100,70, 1666927803, 1666927803);

INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(115,293,10,3,30, "30,20,10,10,10,5,5,5,5",'19:00','19:05',300,180, 2,100,70, 1666927803, 1666927803);

INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(116,293,10,3,30, "30,20,10,10,10,5,5,5,5",'19:10','19:15',300,180, 2,100,70, 1666927803, 1666927803);

INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(117,293,10,3,30, "30,20,10,10,10,5,5,5,5",'19:20','19:25',300,180, 2,100,70, 1666927803, 1666927803);

INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(118,293,10,3,30, "30,20,10,10,10,5,5,5,5",'19:30','19:35',300,180, 2,100,70, 1666927803, 1666927803);

INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(119,293,10,3,30, "30,20,10,10,10,5,5,5,5",'19:40','19:45',300,180, 2,100,70, 1666927803, 1666927803);

INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(120,293,10,3,30, "30,20,10,10,10,5,5,5,5",'19:50','19:55',300,180, 2,100,70, 1666927803, 1666927803);

INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(121,293,10,3,30, "30,20,10,10,10,5,5,5,5",'20:00','20:05',300,180, 2,100,70, 1666927803, 1666927803);

INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(122,293,10,3,30, "30,20,10,10,10,5,5,5,5",'20:10','20:15',300,180, 2,100,70, 1666927803, 1666927803);

INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(123,293,10,3,30, "30,20,10,10,10,5,5,5,5",'20:20','20:25',300,180, 2,100,70, 1666927803, 1666927803);

INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(124,293,10,3,30, "30,20,10,10,10,5,5,5,5",'20:30','20:35',300,180, 2,100,70, 1666927803, 1666927803);

INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(125,293,10,3,30, "30,20,10,10,10,5,5,5,5",'20:40','20:45',300,180, 2,100,70, 1666927803, 1666927803);

INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(126,293,10,3,30, "30,20,10,10,10,5,5,5,5",'20:50','20:55',300,180, 2,100,70, 1666927803, 1666927803);

INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(127,293,10,3,30, "30,20,10,10,10,5,5,5,5",'21:00','21:05',300,180, 2,100,70, 1666927803, 1666927803);

INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(128,293,10,3,30, "30,20,10,10,10,5,5,5,5",'21:10','21:15',300,180, 2,100,70, 1666927803, 1666927803);

INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(129,293,10,3,30, "30,20,10,10,10,5,5,5,5",'21:20','21:25',300,180, 2,100,70, 1666927803, 1666927803);

INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(130,293,10,3,30, "30,20,10,10,10,5,5,5,5",'21:30','21:35',300,180, 2,100,70, 1666927803, 1666927803);

INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(131,293,10,3,30, "30,20,10,10,10,5,5,5,5",'21:40','21:45',300,180, 2,100,70, 1666927803, 1666927803);

INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(132,293,10,3,30, "30,20,10,10,10,5,5,5,5",'21:50','21:55',300,180, 2,100,70, 1666927803, 1666927803);

INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(133,293,10,3,30, "30,20,10,10,10,5,5,5,5",'22:00','22:05',300,180, 2,100,70, 1666927803, 1666927803);

INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(134,293,10,3,30, "30,20,10,10,10,5,5,5,5",'22:10','22:15',300,180, 2,100,70, 1666927803, 1666927803);

INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(135,293,10,3,30, "30,20,10,10,10,5,5,5,5",'22:20','22:25',300,180, 2,100,70, 1666927803, 1666927803);

INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(136,293,10,3,30, "30,20,10,10,10,5,5,5,5",'22:30','22:35',300,180, 2,100,70, 1666927803, 1666927803);

INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(137,293,10,3,30, "30,20,10,10,10,5,5,5,5",'22:40','22:45',300,180, 2,100,70, 1666927803, 1666927803);

INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(138,293,10,3,30, "30,20,10,10,10,5,5,5,5",'22:50','22:55',300,180, 2,100,70, 1666927803, 1666927803);

INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(139,293,10,3,30, "30,20,10,10,10,5,5,5,5",'23:00','23:05',300,180, 2,100,70, 1666927803, 1666927803);

INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(140,293,10,3,30, "30,20,10,10,10,5,5,5,5",'23:10','23:15',300,180, 2,100,70, 1666927803, 1666927803);

INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(141,293,10,3,30, "30,20,10,10,10,5,5,5,5",'23:20','23:25',300,180, 2,100,70, 1666927803, 1666927803);

INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(142,293,10,3,30, "30,20,10,10,10,5,5,5,5",'23:30','23:35',300,180, 2,100,70, 1666927803, 1666927803);

INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(143,293,10,3,30, "30,20,10,10,10,5,5,5,5",'23:40','23:45',300,180, 2,100,70, 1666927803, 1666927803);

INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(144,293,10,3,30, "30,20,10,10,10,5,5,5,5",'23:50','23:55',300,180, 2,100,70, 1666927803, 1666927803);