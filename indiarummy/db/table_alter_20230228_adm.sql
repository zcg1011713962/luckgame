ALTER TABLE `indiarummy_game`.`s_config_customer` 
ADD COLUMN `showpage` smallint(5) NULL DEFAULT 1 COMMENT '展示页面' AFTER `type`;

update `s_config_customer` set `showpage`=1;