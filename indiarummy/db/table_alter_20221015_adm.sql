ALTER TABLE `d_user` 
MODIFY COLUMN `dcoin` decimal(20, 2) NULL DEFAULT 0 COMMENT 'draw coin' AFTER `coin`,
MODIFY COLUMN `dcashbonus` decimal(20, 2) NULL DEFAULT 0 COMMENT '可提现的优惠余额' AFTER `dcoin`,
MODIFY COLUMN `cashbonus` decimal(20, 2) NULL DEFAULT 0 COMMENT 'bonus coin' AFTER `dcashbonus`,
MODIFY COLUMN `totalbet` decimal(20, 2) NULL DEFAULT 0 COMMENT '总下注' AFTER `cashbonus`,
MODIFY COLUMN `totalwin` decimal(20, 2) NULL DEFAULT 0 COMMENT '总赢分' AFTER `totalbet`,
MODIFY COLUMN `totaldraw` decimal(20, 2) NULL DEFAULT 0 COMMENT '总已提分' AFTER `totalwin`,
MODIFY COLUMN `maxdraw` decimal(20, 2) NULL DEFAULT 0 COMMENT '最大可提分' AFTER `totaldraw`,
MODIFY COLUMN `candraw` decimal(20, 2) NULL DEFAULT 00 COMMENT '赠送的可提现金额' AFTER `maxdraw`;