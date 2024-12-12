ALTER TABLE `d_tn_config` ADD `win_ratio` VARCHAR(128) DEFAULT '' COMMENT '赢家获奖比例(百分比)eg: 30.0,20.0,10.0,10.0,10.0,10.0,10.0' AFTER `max_cnt`;

create index `idx_tn_result` on `d_tn_result`(`tn_id`, `date`);
create index `idx_tn_register` on `d_tn_register`(`tn_id`, `date`, `uid`);

create index `idx_lb_reward_log` on `d_lb_reward_log`(`settle_date`, `rtype`);

ALTER TABLE `d_tn_config` CHANGE `start_time` `start_time` int(4) NOT NULL COMMENT '开始时间,eg 1310';
ALTER TABLE `d_tn_config` CHANGE `stop_time` `stop_time` int(4) NOT NULL COMMENT '结束时间,eg 1340';

TRUNCATE TABLE `d_tn_config`;
INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(1,293,10,3,30, "30,20,10,10,10,5,5,5,5",0,5,300,180, 2,100,70, 1666936722, 1666936722);
    
INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(2,293,10,3,30, "30,20,10,10,10,5,5,5,5",10,15,300,180, 2,100,70, 1666936722, 1666936722);
    
INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(3,293,10,3,30, "30,20,10,10,10,5,5,5,5",20,25,300,180, 2,100,70, 1666936722, 1666936722);
    
INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(4,293,10,3,30, "30,20,10,10,10,5,5,5,5",30,35,300,180, 2,100,70, 1666936722, 1666936722);
    
INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(5,293,10,3,30, "30,20,10,10,10,5,5,5,5",40,45,300,180, 2,100,70, 1666936722, 1666936722);
    
INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(6,293,10,3,30, "30,20,10,10,10,5,5,5,5",50,55,300,180, 2,100,70, 1666936722, 1666936722);
    
INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(7,293,10,3,30, "30,20,10,10,10,5,5,5,5",100,105,300,180, 2,100,70, 1666936722, 1666936722);
    
INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(8,293,10,3,30, "30,20,10,10,10,5,5,5,5",110,115,300,180, 2,100,70, 1666936722, 1666936722);
    
INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(9,293,10,3,30, "30,20,10,10,10,5,5,5,5",120,125,300,180, 2,100,70, 1666936722, 1666936722);
    
INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(10,293,10,3,30, "30,20,10,10,10,5,5,5,5",130,135,300,180, 2,100,70, 1666936722, 1666936722);
    
INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(11,293,10,3,30, "30,20,10,10,10,5,5,5,5",140,145,300,180, 2,100,70, 1666936722, 1666936722);
    
INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(12,293,10,3,30, "30,20,10,10,10,5,5,5,5",150,155,300,180, 2,100,70, 1666936722, 1666936722);
    
INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(13,293,10,3,30, "30,20,10,10,10,5,5,5,5",200,205,300,180, 2,100,70, 1666936722, 1666936722);
    
INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(14,293,10,3,30, "30,20,10,10,10,5,5,5,5",210,215,300,180, 2,100,70, 1666936722, 1666936722);
    
INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(15,293,10,3,30, "30,20,10,10,10,5,5,5,5",220,225,300,180, 2,100,70, 1666936722, 1666936722);
    
INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(16,293,10,3,30, "30,20,10,10,10,5,5,5,5",230,235,300,180, 2,100,70, 1666936722, 1666936722);
    
INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(17,293,10,3,30, "30,20,10,10,10,5,5,5,5",240,245,300,180, 2,100,70, 1666936722, 1666936722);
    
INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(18,293,10,3,30, "30,20,10,10,10,5,5,5,5",250,255,300,180, 2,100,70, 1666936722, 1666936722);
    
INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(19,293,10,3,30, "30,20,10,10,10,5,5,5,5",300,305,300,180, 2,100,70, 1666936722, 1666936722);
    
INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(20,293,10,3,30, "30,20,10,10,10,5,5,5,5",310,315,300,180, 2,100,70, 1666936722, 1666936722);
    
INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(21,293,10,3,30, "30,20,10,10,10,5,5,5,5",320,325,300,180, 2,100,70, 1666936722, 1666936722);
    
INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(22,293,10,3,30, "30,20,10,10,10,5,5,5,5",330,335,300,180, 2,100,70, 1666936722, 1666936722);
    
INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(23,293,10,3,30, "30,20,10,10,10,5,5,5,5",340,345,300,180, 2,100,70, 1666936722, 1666936722);
    
INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(24,293,10,3,30, "30,20,10,10,10,5,5,5,5",350,355,300,180, 2,100,70, 1666936722, 1666936722);
    
INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(25,293,10,3,30, "30,20,10,10,10,5,5,5,5",400,405,300,180, 2,100,70, 1666936722, 1666936722);
    
INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(26,293,10,3,30, "30,20,10,10,10,5,5,5,5",410,415,300,180, 2,100,70, 1666936722, 1666936722);
    
INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(27,293,10,3,30, "30,20,10,10,10,5,5,5,5",420,425,300,180, 2,100,70, 1666936722, 1666936722);
    
INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(28,293,10,3,30, "30,20,10,10,10,5,5,5,5",430,435,300,180, 2,100,70, 1666936722, 1666936722);
    
INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(29,293,10,3,30, "30,20,10,10,10,5,5,5,5",440,445,300,180, 2,100,70, 1666936722, 1666936722);
    
INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(30,293,10,3,30, "30,20,10,10,10,5,5,5,5",450,455,300,180, 2,100,70, 1666936722, 1666936722);
    
INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(31,293,10,3,30, "30,20,10,10,10,5,5,5,5",500,505,300,180, 2,100,70, 1666936722, 1666936722);
    
INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(32,293,10,3,30, "30,20,10,10,10,5,5,5,5",510,515,300,180, 2,100,70, 1666936722, 1666936722);
    
INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(33,293,10,3,30, "30,20,10,10,10,5,5,5,5",520,525,300,180, 2,100,70, 1666936722, 1666936722);
    
INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(34,293,10,3,30, "30,20,10,10,10,5,5,5,5",530,535,300,180, 2,100,70, 1666936722, 1666936722);
    
INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(35,293,10,3,30, "30,20,10,10,10,5,5,5,5",540,545,300,180, 2,100,70, 1666936722, 1666936722);
    
INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(36,293,10,3,30, "30,20,10,10,10,5,5,5,5",550,555,300,180, 2,100,70, 1666936722, 1666936722);
    
INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(37,293,10,3,30, "30,20,10,10,10,5,5,5,5",600,605,300,180, 2,100,70, 1666936722, 1666936722);
    
INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(38,293,10,3,30, "30,20,10,10,10,5,5,5,5",610,615,300,180, 2,100,70, 1666936722, 1666936722);
    
INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(39,293,10,3,30, "30,20,10,10,10,5,5,5,5",620,625,300,180, 2,100,70, 1666936722, 1666936722);
    
INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(40,293,10,3,30, "30,20,10,10,10,5,5,5,5",630,635,300,180, 2,100,70, 1666936722, 1666936722);
    
INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(41,293,10,3,30, "30,20,10,10,10,5,5,5,5",640,645,300,180, 2,100,70, 1666936722, 1666936722);
    
INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(42,293,10,3,30, "30,20,10,10,10,5,5,5,5",650,655,300,180, 2,100,70, 1666936722, 1666936722);
    
INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(43,293,10,3,30, "30,20,10,10,10,5,5,5,5",700,705,300,180, 2,100,70, 1666936722, 1666936722);
    
INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(44,293,10,3,30, "30,20,10,10,10,5,5,5,5",710,715,300,180, 2,100,70, 1666936722, 1666936722);
    
INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(45,293,10,3,30, "30,20,10,10,10,5,5,5,5",720,725,300,180, 2,100,70, 1666936722, 1666936722);
    
INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(46,293,10,3,30, "30,20,10,10,10,5,5,5,5",730,735,300,180, 2,100,70, 1666936722, 1666936722);
    
INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(47,293,10,3,30, "30,20,10,10,10,5,5,5,5",740,745,300,180, 2,100,70, 1666936722, 1666936722);
    
INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(48,293,10,3,30, "30,20,10,10,10,5,5,5,5",750,755,300,180, 2,100,70, 1666936722, 1666936722);
    
INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(49,293,10,3,30, "30,20,10,10,10,5,5,5,5",800,805,300,180, 2,100,70, 1666936722, 1666936722);
    
INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(50,293,10,3,30, "30,20,10,10,10,5,5,5,5",810,815,300,180, 2,100,70, 1666936722, 1666936722);
    
INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(51,293,10,3,30, "30,20,10,10,10,5,5,5,5",820,825,300,180, 2,100,70, 1666936722, 1666936722);
    
INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(52,293,10,3,30, "30,20,10,10,10,5,5,5,5",830,835,300,180, 2,100,70, 1666936722, 1666936722);
    
INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(53,293,10,3,30, "30,20,10,10,10,5,5,5,5",840,845,300,180, 2,100,70, 1666936722, 1666936722);
    
INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(54,293,10,3,30, "30,20,10,10,10,5,5,5,5",850,855,300,180, 2,100,70, 1666936722, 1666936722);
    
INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(55,293,10,3,30, "30,20,10,10,10,5,5,5,5",900,905,300,180, 2,100,70, 1666936722, 1666936722);
    
INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(56,293,10,3,30, "30,20,10,10,10,5,5,5,5",910,915,300,180, 2,100,70, 1666936722, 1666936722);
    
INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(57,293,10,3,30, "30,20,10,10,10,5,5,5,5",920,925,300,180, 2,100,70, 1666936722, 1666936722);
    
INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(58,293,10,3,30, "30,20,10,10,10,5,5,5,5",930,935,300,180, 2,100,70, 1666936722, 1666936722);
    
INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(59,293,10,3,30, "30,20,10,10,10,5,5,5,5",940,945,300,180, 2,100,70, 1666936722, 1666936722);
    
INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(60,293,10,3,30, "30,20,10,10,10,5,5,5,5",950,955,300,180, 2,100,70, 1666936722, 1666936722);
    
INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(61,293,10,3,30, "30,20,10,10,10,5,5,5,5",1000,1005,300,180, 2,100,70, 1666936722, 1666936722);
    
INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(62,293,10,3,30, "30,20,10,10,10,5,5,5,5",1010,1015,300,180, 2,100,70, 1666936722, 1666936722);
    
INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(63,293,10,3,30, "30,20,10,10,10,5,5,5,5",1020,1025,300,180, 2,100,70, 1666936722, 1666936722);
    
INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(64,293,10,3,30, "30,20,10,10,10,5,5,5,5",1030,1035,300,180, 2,100,70, 1666936722, 1666936722);
    
INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(65,293,10,3,30, "30,20,10,10,10,5,5,5,5",1040,1045,300,180, 2,100,70, 1666936722, 1666936722);
    
INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(66,293,10,3,30, "30,20,10,10,10,5,5,5,5",1050,1055,300,180, 2,100,70, 1666936722, 1666936722);
    
INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(67,293,10,3,30, "30,20,10,10,10,5,5,5,5",1100,1105,300,180, 2,100,70, 1666936722, 1666936722);
    
INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(68,293,10,3,30, "30,20,10,10,10,5,5,5,5",1110,1115,300,180, 2,100,70, 1666936722, 1666936722);
    
INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(69,293,10,3,30, "30,20,10,10,10,5,5,5,5",1120,1125,300,180, 2,100,70, 1666936722, 1666936722);
    
INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(70,293,10,3,30, "30,20,10,10,10,5,5,5,5",1130,1135,300,180, 2,100,70, 1666936722, 1666936722);
    
INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(71,293,10,3,30, "30,20,10,10,10,5,5,5,5",1140,1145,300,180, 2,100,70, 1666936722, 1666936722);
    
INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(72,293,10,3,30, "30,20,10,10,10,5,5,5,5",1150,1155,300,180, 2,100,70, 1666936722, 1666936722);
    
INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(73,293,10,3,30, "30,20,10,10,10,5,5,5,5",1200,1205,300,180, 2,100,70, 1666936722, 1666936722);
    
INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(74,293,10,3,30, "30,20,10,10,10,5,5,5,5",1210,1215,300,180, 2,100,70, 1666936722, 1666936722);
    
INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(75,293,10,3,30, "30,20,10,10,10,5,5,5,5",1220,1225,300,180, 2,100,70, 1666936722, 1666936722);
    
INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(76,293,10,3,30, "30,20,10,10,10,5,5,5,5",1230,1235,300,180, 2,100,70, 1666936722, 1666936722);
    
INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(77,293,10,3,30, "30,20,10,10,10,5,5,5,5",1240,1245,300,180, 2,100,70, 1666936722, 1666936722);
    
INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(78,293,10,3,30, "30,20,10,10,10,5,5,5,5",1250,1255,300,180, 2,100,70, 1666936722, 1666936722);
    
INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(79,293,10,3,30, "30,20,10,10,10,5,5,5,5",1300,1305,300,180, 2,100,70, 1666936722, 1666936722);
    
INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(80,293,10,3,30, "30,20,10,10,10,5,5,5,5",1310,1315,300,180, 2,100,70, 1666936722, 1666936722);
    
INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(81,293,10,3,30, "30,20,10,10,10,5,5,5,5",1320,1325,300,180, 2,100,70, 1666936722, 1666936722);
    
INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(82,293,10,3,30, "30,20,10,10,10,5,5,5,5",1330,1335,300,180, 2,100,70, 1666936722, 1666936722);
    
INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(83,293,10,3,30, "30,20,10,10,10,5,5,5,5",1340,1345,300,180, 2,100,70, 1666936722, 1666936722);
    
INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(84,293,10,3,30, "30,20,10,10,10,5,5,5,5",1350,1355,300,180, 2,100,70, 1666936722, 1666936722);
    
INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(85,293,10,3,30, "30,20,10,10,10,5,5,5,5",1400,1405,300,180, 2,100,70, 1666936722, 1666936722);
    
INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(86,293,10,3,30, "30,20,10,10,10,5,5,5,5",1410,1415,300,180, 2,100,70, 1666936722, 1666936722);
    
INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(87,293,10,3,30, "30,20,10,10,10,5,5,5,5",1420,1425,300,180, 2,100,70, 1666936722, 1666936722);
    
INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(88,293,10,3,30, "30,20,10,10,10,5,5,5,5",1430,1435,300,180, 2,100,70, 1666936722, 1666936722);
    
INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(89,293,10,3,30, "30,20,10,10,10,5,5,5,5",1440,1445,300,180, 2,100,70, 1666936722, 1666936722);
    
INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(90,293,10,3,30, "30,20,10,10,10,5,5,5,5",1450,1455,300,180, 2,100,70, 1666936722, 1666936722);
    
INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(91,293,10,3,30, "30,20,10,10,10,5,5,5,5",1500,1505,300,180, 2,100,70, 1666936722, 1666936722);
    
INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(92,293,10,3,30, "30,20,10,10,10,5,5,5,5",1510,1515,300,180, 2,100,70, 1666936722, 1666936722);
    
INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(93,293,10,3,30, "30,20,10,10,10,5,5,5,5",1520,1525,300,180, 2,100,70, 1666936722, 1666936722);
    
INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(94,293,10,3,30, "30,20,10,10,10,5,5,5,5",1530,1535,300,180, 2,100,70, 1666936722, 1666936722);
    
INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(95,293,10,3,30, "30,20,10,10,10,5,5,5,5",1540,1545,300,180, 2,100,70, 1666936722, 1666936722);
    
INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(96,293,10,3,30, "30,20,10,10,10,5,5,5,5",1550,1555,300,180, 2,100,70, 1666936722, 1666936722);
    
INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(97,293,10,3,30, "30,20,10,10,10,5,5,5,5",1600,1605,300,180, 2,100,70, 1666936722, 1666936722);
    
INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(98,293,10,3,30, "30,20,10,10,10,5,5,5,5",1610,1615,300,180, 2,100,70, 1666936722, 1666936722);
    
INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(99,293,10,3,30, "30,20,10,10,10,5,5,5,5",1620,1625,300,180, 2,100,70, 1666936722, 1666936722);
    
INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(100,293,10,3,30, "30,20,10,10,10,5,5,5,5",1630,1635,300,180, 2,100,70, 1666936722, 1666936722);
    
INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(101,293,10,3,30, "30,20,10,10,10,5,5,5,5",1640,1645,300,180, 2,100,70, 1666936722, 1666936722);
    
INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(102,293,10,3,30, "30,20,10,10,10,5,5,5,5",1650,1655,300,180, 2,100,70, 1666936722, 1666936722);
    
INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(103,293,10,3,30, "30,20,10,10,10,5,5,5,5",1700,1705,300,180, 2,100,70, 1666936722, 1666936722);
    
INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(104,293,10,3,30, "30,20,10,10,10,5,5,5,5",1710,1715,300,180, 2,100,70, 1666936722, 1666936722);
    
INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(105,293,10,3,30, "30,20,10,10,10,5,5,5,5",1720,1725,300,180, 2,100,70, 1666936722, 1666936722);
    
INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(106,293,10,3,30, "30,20,10,10,10,5,5,5,5",1730,1735,300,180, 2,100,70, 1666936722, 1666936722);
    
INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(107,293,10,3,30, "30,20,10,10,10,5,5,5,5",1740,1745,300,180, 2,100,70, 1666936722, 1666936722);
    
INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(108,293,10,3,30, "30,20,10,10,10,5,5,5,5",1750,1755,300,180, 2,100,70, 1666936722, 1666936722);
    
INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(109,293,10,3,30, "30,20,10,10,10,5,5,5,5",1800,1805,300,180, 2,100,70, 1666936722, 1666936722);
    
INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(110,293,10,3,30, "30,20,10,10,10,5,5,5,5",1810,1815,300,180, 2,100,70, 1666936722, 1666936722);
    
INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(111,293,10,3,30, "30,20,10,10,10,5,5,5,5",1820,1825,300,180, 2,100,70, 1666936722, 1666936722);
    
INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(112,293,10,3,30, "30,20,10,10,10,5,5,5,5",1830,1835,300,180, 2,100,70, 1666936722, 1666936722);
    
INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(113,293,10,3,30, "30,20,10,10,10,5,5,5,5",1840,1845,300,180, 2,100,70, 1666936722, 1666936722);
    
INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(114,293,10,3,30, "30,20,10,10,10,5,5,5,5",1850,1855,300,180, 2,100,70, 1666936722, 1666936722);
    
INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(115,293,10,3,30, "30,20,10,10,10,5,5,5,5",1900,1905,300,180, 2,100,70, 1666936722, 1666936722);
    
INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(116,293,10,3,30, "30,20,10,10,10,5,5,5,5",1910,1915,300,180, 2,100,70, 1666936722, 1666936722);
    
INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(117,293,10,3,30, "30,20,10,10,10,5,5,5,5",1920,1925,300,180, 2,100,70, 1666936722, 1666936722);
    
INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(118,293,10,3,30, "30,20,10,10,10,5,5,5,5",1930,1935,300,180, 2,100,70, 1666936722, 1666936722);
    
INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(119,293,10,3,30, "30,20,10,10,10,5,5,5,5",1940,1945,300,180, 2,100,70, 1666936722, 1666936722);
    
INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(120,293,10,3,30, "30,20,10,10,10,5,5,5,5",1950,1955,300,180, 2,100,70, 1666936722, 1666936722);
    
INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(121,293,10,3,30, "30,20,10,10,10,5,5,5,5",2000,2005,300,180, 2,100,70, 1666936722, 1666936722);
    
INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(122,293,10,3,30, "30,20,10,10,10,5,5,5,5",2010,2015,300,180, 2,100,70, 1666936722, 1666936722);
    
INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(123,293,10,3,30, "30,20,10,10,10,5,5,5,5",2020,2025,300,180, 2,100,70, 1666936722, 1666936722);
    
INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(124,293,10,3,30, "30,20,10,10,10,5,5,5,5",2030,2035,300,180, 2,100,70, 1666936722, 1666936722);
    
INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(125,293,10,3,30, "30,20,10,10,10,5,5,5,5",2040,2045,300,180, 2,100,70, 1666936722, 1666936722);
    
INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(126,293,10,3,30, "30,20,10,10,10,5,5,5,5",2050,2055,300,180, 2,100,70, 1666936722, 1666936722);
    
INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(127,293,10,3,30, "30,20,10,10,10,5,5,5,5",2100,2105,300,180, 2,100,70, 1666936722, 1666936722);
    
INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(128,293,10,3,30, "30,20,10,10,10,5,5,5,5",2110,2115,300,180, 2,100,70, 1666936722, 1666936722);
    
INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(129,293,10,3,30, "30,20,10,10,10,5,5,5,5",2120,2125,300,180, 2,100,70, 1666936722, 1666936722);
    
INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(130,293,10,3,30, "30,20,10,10,10,5,5,5,5",2130,2135,300,180, 2,100,70, 1666936722, 1666936722);
    
INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(131,293,10,3,30, "30,20,10,10,10,5,5,5,5",2140,2145,300,180, 2,100,70, 1666936722, 1666936722);
    
INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(132,293,10,3,30, "30,20,10,10,10,5,5,5,5",2150,2155,300,180, 2,100,70, 1666936722, 1666936722);
    
INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(133,293,10,3,30, "30,20,10,10,10,5,5,5,5",2200,2205,300,180, 2,100,70, 1666936722, 1666936722);
    
INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(134,293,10,3,30, "30,20,10,10,10,5,5,5,5",2210,2215,300,180, 2,100,70, 1666936722, 1666936722);
    
INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(135,293,10,3,30, "30,20,10,10,10,5,5,5,5",2220,2225,300,180, 2,100,70, 1666936722, 1666936722);
    
INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(136,293,10,3,30, "30,20,10,10,10,5,5,5,5",2230,2235,300,180, 2,100,70, 1666936722, 1666936722);
    
INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(137,293,10,3,30, "30,20,10,10,10,5,5,5,5",2240,2245,300,180, 2,100,70, 1666936722, 1666936722);
    
INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(138,293,10,3,30, "30,20,10,10,10,5,5,5,5",2250,2255,300,180, 2,100,70, 1666936722, 1666936722);
    
INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(139,293,10,3,30, "30,20,10,10,10,5,5,5,5",2300,2305,300,180, 2,100,70, 1666936722, 1666936722);
    
INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(140,293,10,3,30, "30,20,10,10,10,5,5,5,5",2310,2315,300,180, 2,100,70, 1666936722, 1666936722);
    
INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(141,293,10,3,30, "30,20,10,10,10,5,5,5,5",2320,2325,300,180, 2,100,70, 1666936722, 1666936722);
    
INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(142,293,10,3,30, "30,20,10,10,10,5,5,5,5",2330,2335,300,180, 2,100,70, 1666936722, 1666936722);
    
INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(143,293,10,3,30, "30,20,10,10,10,5,5,5,5",2340,2345,300,180, 2,100,70, 1666936722, 1666936722);
    
INSERT INTO `d_tn_config` (id, gameid, buy_in, min_cnt, max_cnt, win_ratio, start_time, stop_time, ahead_time, deadline_time, bet, init_coin, pool_rate, update_time, create_time)
    VALUES(144,293,10,3,30, "30,20,10,10,10,5,5,5,5",2350,2355,300,180, 2,100,70, 1666936722, 1666936722);