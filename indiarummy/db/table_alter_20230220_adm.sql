ALTER TABLE `indiarummy_game`.`s_notice` 
ADD COLUMN `btntxt` varchar(255) NULL DEFAULT '' COMMENT '跳转按钮txt' AFTER `create_time`;

-- redis 设置
-- set bonus_wheel_list '[{"weight":60,"rewards":[{"type":1,"count":1}]},{"weight":30,"rewards":[{"type":1,"count":5}]},{"weight":5,"rewards":[{"type":1,"count":10}]},{"weight":3,"rewards":[{"type":1,"count":15}]},{"weight":1,"rewards":[{"type":1,"count":20}]},{"weight":1,"rewards":[{"type":1,"count":50}]}]'

ALTER TABLE `indiarummy_game`.`d_rake_back` ADD INDEX `idx_uid_time`(`uid`, `create_time`);