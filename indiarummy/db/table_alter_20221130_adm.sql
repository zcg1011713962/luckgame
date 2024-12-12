ALTER TABLE `indiarummy_game`.`s_pay_cfg_channel` 
ADD COLUMN `screenshot` varchar(1024) NULL DEFAULT '' COMMENT '凭证提示截图' AFTER `svip`;

ALTER TABLE `indiarummy_game`.`s_pay_bank` 
ADD COLUMN `screenshot` varchar(1024) NULL DEFAULT '' COMMENT '凭证提示截图' AFTER `usdtrate`;