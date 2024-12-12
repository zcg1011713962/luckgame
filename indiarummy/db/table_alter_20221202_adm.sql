ALTER TABLE `indiarummy_game`.`d_user_recharge` 
ADD COLUMN `category` int(11) NULL DEFAULT 0 COMMENT '分组类型 1:线上' AFTER `readed`;

