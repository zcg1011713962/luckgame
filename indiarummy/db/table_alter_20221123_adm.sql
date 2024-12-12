ALTER TABLE `indiarummy_game`.`d_user` 
MODIFY COLUMN `avatarframe` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NULL DEFAULT 'avatarframe_1000' AFTER `country`;

ALTER TABLE `indiarummy_game`.`d_user` 
MODIFY COLUMN `chatskin` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NULL DEFAULT 'chat_000' AFTER `skinlist`;

ALTER TABLE `indiarummy_game`.`d_user` 
MODIFY COLUMN `tableskin` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NULL DEFAULT 'desk_000' AFTER `chatskin`;

ALTER TABLE `indiarummy_game`.`d_user` 
MODIFY COLUMN `faceskin` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NULL DEFAULT 'poker_face_000' AFTER `emojiskin`;

update s_send_charm set isvip=0 where isvip is null;

ALTER TABLE `indiarummy_adm`.`account` 
MODIFY COLUMN `pusername` varchar(32) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NULL DEFAULT '' COMMENT '玩家登录用户名' AFTER `ppromoters`;

ALTER TABLE `indiarummy_game`.`s_pay_bank` 
ADD COLUMN `ifsc` varchar(32) NULL DEFAULT '' COMMENT 'Ifs' AFTER `update_time`;