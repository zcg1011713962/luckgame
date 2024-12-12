ALTER TABLE `indiarummy_game`.`s_config_vip_upgrade` 
ADD COLUMN `slotmaxbet` int(11) NULL DEFAULT 5000 COMMENT '不同vip等级在slots中的最大押注' AFTER `salonrooms`;
update s_config_vip_upgrade set  slotmaxbet =5000;

update d_log_cashbonus set category=34 where coin<0 and category!=6;

insert into s_config (k,v,memo) values('rechargememo','','充值描述'),('drawmemo','','提现描述');

insert into s_config (k,v,memo) values('leaderpic1','','排行榜第1张'),('leaderpic2','','排行榜第2张'),('leaderpic3','','排行榜第3张'),('leaderpic4','','排行榜第4张');