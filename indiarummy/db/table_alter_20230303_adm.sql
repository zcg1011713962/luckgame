ALTER TABLE `indiarummy_game`.`d_user` 
ADD COLUMN `istest` tinyint(1) NULL DEFAULT 0 COMMENT '是否测试账号 0:否 1:是' AFTER `isrobot`;

ALTER TABLE `indiarummy_game`.`d_desk_user` 
ADD COLUMN `istest` tinyint(1) NULL DEFAULT 0 COMMENT '是否是测试账号的记录' AFTER `flag`;