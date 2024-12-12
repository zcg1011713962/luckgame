ALTER TABLE `indiarummy_game`.`d_desk_user` 
DROP INDEX `uid`,
DROP INDEX `uuid`,
ADD INDEX `uid`(`uid`, `gameid`) USING BTREE;

