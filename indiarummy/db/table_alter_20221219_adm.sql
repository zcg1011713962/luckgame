INSERT INTO `d_mail_tpl` (`id`, `type`, `title`, `content`, `status`, `param1`, `param2`, `coin`, `svip`, `rate`) VALUES (16, 39, 'Deposit failed', 'Dear AAA:\nyour deposit BBB at CCC channel has failed , the reason is as follows：XXX; if you have any questions, please feel free to contact our 247 online customer service for help.', 1, NULL, NULL, 0, NULL, '');

ALTER TABLE `indiarummy_game`.`s_pay_cfg_drawlimit` 
ADD COLUMN `daycoin` bigint(20) NULL DEFAULT -1 COMMENT '单日最大金额' AFTER `times`,
ADD COLUMN `totaltimes` int(11) NULL DEFAULT -1 COMMENT '总提现次数' AFTER `daycoin`,
ADD COLUMN `totalcoin` bigint(20) NULL DEFAULT -1 COMMENT '总提现金额' AFTER `totaltimes`;

ALTER TABLE `indiarummy_game`.`s_pay_cfg_drawlimit` 
MODIFY COLUMN `times` int(11) NULL DEFAULT -1 COMMENT '次数' AFTER `mincoin`;

insert into s_config (k,v,memo) values('play_bind_phone','0','下注前必须绑定手机号'),('play_bind_kyc','','下注前必须完成KYC'),('newuser_no_pay_drawlimit','','未付款新会员最高提现金额');

update s_config set v='https://service.yonogames.com/sms/dosend' where k='sms_url';

ALTER TABLE `indiarummy_game`.`d_user` ADD COLUMN `drawsucctimes` int(11) NULL DEFAULT 0 COMMENT '提现成功次数' AFTER `payratetype`;
update d_user set drawsucctimes = 0;


CREATE TABLE `indiarummy_game`.`d_chat`  (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `msgid` int(11) NULL COMMENT '编号',
  `uid` bigint(20) NULL COMMENT 'uid',
  `cid` int(11) NULL,
  `stype` int(11) NULL COMMENT '类型',
  `name` varchar(32) NULL,
  `levelexp` int(11) NULL,
  `avatar` varchar(255) NULL COMMENT '玩家头像',
  `svip` int(11) NULL COMMENT '用户svip',
  `avatarframe` varchar(255) NULL COMMENT '头像框',
  `chatskin` varchar(255) NULL COMMENT '聊天框',
  `frontskin` varchar(255) NULL COMMENT '文字框',
  `content` varchar(1000) NULL COMMENT '内容',
  `ext` varchar(1000) NULL COMMENT '其他',
  PRIMARY KEY (`id`),
  INDEX `idx_uid`(`uid`),
  INDEX `idx_msgid`(`msgid`)
) COMMENT = '聊天内容';

ALTER TABLE `indiarummy_game`.`d_chat` 
ADD COLUMN `status` tinyint(1) NULL DEFAULT 1 COMMENT '状态1:正常 2:删除' AFTER `ext`;

ALTER TABLE `indiarummy_game`.`d_chat` 
ADD COLUMN `create_time` int(11) NULL DEFAULT 0 AFTER `status`;