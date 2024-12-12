ALTER TABLE `d_private_room_income` CHANGE `total` `total` decimal(10,2) NOT NULL COMMENT '结算总金币';
ALTER TABLE `d_private_room_income` CHANGE `bet` `bet` decimal(10,2) NOT NULL COMMENT '下注额';
ALTER TABLE `d_private_room_income` CHANGE `income` `income` decimal(10,2) NOT NULL COMMENT '抽水金币数';


ALTER TABLE `d_desk_user` CHANGE `prize` `prize` decimal(10,2) DEFAULT '0.0' COMMENT '奖励';

-- DELETE FROM `s_config` WHERE id=60;
-- INSERT INTO `s_config` (id, k, v, memo) VALUES (60, 'leaderboard', '[{"rtype":1,"limit":500,"register":0,"prize":20000,"winners":10},{"rtype":2,"limit":500,"register":0,"prize":75000,"winners":50},{"rtype":3,"limit":500,"register":0,"prize":200000,"winners":1000},{"rtype":4,"limit":0,"register":0,"prize":100000,"winners":15}]', '排行榜配置信息');

ALTER TABLE `d_lb_reward_log` ADD `ord` int(4) DEFAULT 0 COMMENT '获得名次' AFTER `settle_date`;

-- 代理榜
INSERT INTO `d_lb_reward_config` VALUES(NULL, 4, 1,  1,  100000, 25000);
INSERT INTO `d_lb_reward_config` VALUES(NULL, 4, 2,  2,  100000, 15000);
INSERT INTO `d_lb_reward_config` VALUES(NULL, 4, 3,  3,  100000, 10000);
INSERT INTO `d_lb_reward_config` VALUES(NULL, 4, 4,  4,  100000,  8000);
INSERT INTO `d_lb_reward_config` VALUES(NULL, 4, 5,  5,  100000,  7000);
INSERT INTO `d_lb_reward_config` VALUES(NULL, 4, 6,  6,  100000,  6000);
INSERT INTO `d_lb_reward_config` VALUES(NULL, 4, 7,  7,  100000,  5500);
INSERT INTO `d_lb_reward_config` VALUES(NULL, 4, 8,  8,  100000,  5000);
INSERT INTO `d_lb_reward_config` VALUES(NULL, 4, 9,  9,  100000,  4500);
INSERT INTO `d_lb_reward_config` VALUES(NULL, 4, 10, 10, 100000,  4000);
INSERT INTO `d_lb_reward_config` VALUES(NULL, 4, 11, 11, 100000,  3000);
INSERT INTO `d_lb_reward_config` VALUES(NULL, 4, 12, 12, 100000,  2500);
INSERT INTO `d_lb_reward_config` VALUES(NULL, 4, 13, 13, 100000,  2000);
INSERT INTO `d_lb_reward_config` VALUES(NULL, 4, 14, 14, 100000,  1500);
INSERT INTO `d_lb_reward_config` VALUES(NULL, 4, 15, 15, 100000,  1000);