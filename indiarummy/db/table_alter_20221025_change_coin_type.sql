-- 更改数据库格式，适应小数点
ALTER TABLE `d_texas_record` CHANGE `bet_coin` `bet_coin` decimal(10,2) DEFAULT 0 COMMENT '下注金额';
ALTER TABLE `d_texas_record` CHANGE `win_coin` `win_coin` decimal(10,2) DEFAULT 0 COMMENT '赢取金额';
ALTER TABLE `d_texas_record` CHANGE `max_win` `max_win` decimal(10,2) DEFAULT 0 COMMENT '最大赢取奖池大小';

ALTER TABLE `d_lb_register` CHANGE `coin` `coin` decimal(10,2) DEFAULT 0 COMMENT '报名金币';
ALTER TABLE `d_lb_register` CHANGE `own_coin` `own_coin` decimal(10,2) DEFAULT 0 COMMENT '拥有的金币';

ALTER TABLE `d_lb_reward_log` CHANGE `coin` `coin` decimal(10,2) DEFAULT 0 COMMENT '报名金币';
ALTER TABLE `d_lb_reward_log` CHANGE `reward_coin` `reward_coin` decimal(10,2) DEFAULT 0 COMMENT '奖励的金币';

ALTER TABLE `d_lb_reward_config` CHANGE `total` `total` decimal(10,2) DEFAULT 0 COMMENT '奖励总额';
ALTER TABLE `d_lb_reward_config` CHANGE `coin` `coin`  decimal(10,2) DEFAULT 0 COMMENT '奖励金币';
