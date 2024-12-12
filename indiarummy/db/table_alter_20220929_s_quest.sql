-- 新手任务
update s_quest set rewards='25:20|54:3:gift_tea' where id=130;
update s_quest set rewards='54:3:gift_car' where id=134;
update s_quest set rewards='25:20|54:1:gift_kiss' where id=135;
update s_quest set rewards='25:5' where id=140;
update s_quest set rewards='43:1:avatarframe_1002:3|54:2:gift_car' where id=141;
update s_quest set rewards='54:1:gift_hookah' where id=142;
update s_quest set rewards='54:1:gift_cake' where id=144;

-- 每日任务
update s_quest set rewards='25:10|54:5:gift_1' where id=1;
update s_quest set rewards='54:2:gift_4|54:1:gift_cake' where id=2;
update s_quest set rewards='54:2:gift_2|54:1:gift_tea' where id=3;
update s_quest set rewards='54:2:gift_3|55:1:exp_25' where id=4;
update s_quest set rewards='25:20|54:2:gift_kiss' where id=5;
update s_quest set rewards='54:3:gift_4|54:3:gift_6' where id=6;
update s_quest set rewards='54:3:gift_3|54:3:gift_5' where id=7;

-- 签到奖励
update s_sign_vip set coin = 5, prize = '' where id = 1;
update s_sign_vip set coin = 5, prize = '' where id = 2;
update s_sign_vip set coin = 10, prize = '' where id = 3;
update s_sign_vip set coin = 10, prize = '' where id = 4;
update s_sign_vip set coin = 15, prize = '' where id = 5;
update s_sign_vip set coin = 15, prize = '' where id = 6;
update s_sign_vip set coin = 20, prize = '' where id = 7;

-- vip等级奖励
truncate table s_config_vip_upgrade;

INSERT INTO s_config_vip_upgrade (id, level, diamond, benefit, rewards, memo) VALUES (1, 1, 0, '{"badge":"vip0","avatar":"avatarframe_100","ticket":1,"friendscnt":100,"chatframe":""}', '[{"s":25,"n":5}]', '基础vip');
INSERT INTO s_config_vip_upgrade (id, level, diamond, benefit, rewards, memo) VALUES (2, 2, 1000, '{"badge":"vip1","avatar":"avatarframe_101","ticket":1,"friendscnt":100,"chatframe":""}', '[{"s":25,"n":8}]', 'vip1');
INSERT INTO s_config_vip_upgrade (id, level, diamond, benefit, rewards, memo) VALUES (3, 3, 2000, '{"badge":"vip2","avatar":"avatarframe_102","ticket":1,"friendscnt":100,"chatframe":""}', '[{"s":25,"n":10}]', 'vip2');
INSERT INTO s_config_vip_upgrade (id, level, diamond, benefit, rewards, memo) VALUES (4, 4, 3000, '{"badge":"vip3","avatar":"avatarframe_103","ticket":2,"friendscnt":100,"chatframe":""}', '[{"s":25,"n":12}]', 'vip3');
INSERT INTO s_config_vip_upgrade (id, level, diamond, benefit, rewards, memo) VALUES (5, 5, 5000, '{"badge":"vip4","avatar":"avatarframe_104","ticket":2,"friendscnt":100,"chatframe":""}', '[{"s":25,"n":15}]', 'vip4');
INSERT INTO s_config_vip_upgrade (id, level, diamond, benefit, rewards, memo) VALUES (6, 6, 10000, '{"badge":"vip5","avatar":"avatarframe_105","ticket":3,"friendscnt":150,"chatframe":"chat_vip_5"}', '[{"s":25,"n":18}]', 'vip5');
INSERT INTO s_config_vip_upgrade (id, level, diamond, benefit, rewards, memo) VALUES (7, 7, 20000, '{"badge":"vip6","avatar":"avatarframe_106","ticket":3,"friendscnt":150,"chatframe":"chat_vip_6"}', '[{"s":25,"n":20}]', 'vip6');
INSERT INTO s_config_vip_upgrade (id, level, diamond, benefit, rewards, memo) VALUES (8, 8, 50000, '{"badge":"vip7","avatar":"avatarframe_107","ticket":3,"friendscnt":200,"chatframe":"chat_vip_7"}', '[{"s":25,"n":25}]', 'vip7');
INSERT INTO s_config_vip_upgrade (id, level, diamond, benefit, rewards, memo) VALUES (9, 9, 90000, '{"badge":"vip8","avatar":"avatarframe_108","ticket":3,"friendscnt":200,"chatframe":"chat_vip_8"}', '[{"s":25,"n":30}]', 'vip8');
INSERT INTO s_config_vip_upgrade (id, level, diamond, benefit, rewards, memo) VALUES (10, 10, 300000, '{"badge":"vip9","avatar":"avatarframe_109","ticket":4,"friendscnt":300,"chatframe":"chat_vip_9"}', '[{"s":25,"n":40}]', 'vip9');
INSERT INTO s_config_vip_upgrade (id, level, diamond, benefit, rewards, memo) VALUES (11, 11, 600000, '{"badge":"vip10","avatar":"avatarframe_110","ticket":4,"friendscnt":300,"chatframe":"chat_vip_10"}', '[{"s":25,"n":50}]', 'vip10');
INSERT INTO s_config_vip_upgrade (id, level, diamond, benefit, rewards, memo) VALUES (12, 12, 1000000, '{"badge":"vip11","avatar":"avatarframe_111","ticket":5,"friendscnt":400,"chatframe":"chat_vip_11"}', '[{"s":25,"n":80}]', 'vip11');
INSERT INTO s_config_vip_upgrade (id, level, diamond, benefit, rewards, memo) VALUES (13, 13, 1600000, '{"badge":"vip12","avatar":"avatarframe_112","ticket":5,"friendscnt":400,"chatframe":"chat_vip_12"}', '[{"s":25,"n":100}]', 'vip12');

-- 去掉免费金币,钻石
UPDATE s_shop set status=1, amount=0.99 where id=101;
UPDATE s_shop set status=1 where id in (3, 4, 5, 16, 17);
UPDATE s_shop set status=1, amount=0.99 where id=6;

-- 更改金驴商品
-- 还需要改pay.lua,暂时未改
-- UPDATE s_shop set count=300 where id=124;
-- UPDATE s_shop set count=1000 where id=125;
-- UPDATE s_shop set count=2880 where id=126;
-- UPDATE s_shop set count=9600 where id=127;
-- UPDATE s_shop set count=24000 where id=128;
