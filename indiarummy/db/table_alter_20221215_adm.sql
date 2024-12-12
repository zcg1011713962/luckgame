update s_config set v='{"mobile":{"open":1,"ord":1,"title":"Mobile Number","icon":"icon-mobile","note":"For login options and customer service contact."},"pan":{"open":1,"ord":2,"title":"ID Card","icon":"icon-idcard","note":"For safety and security of all transactions."},"bank":{"open":1,"ord":3,"title":"Bank Card","icon":"icon-bank","note":"For quick withdrawals to you bank account."}}' where k='kycverify';

ALTER TABLE `indiarummy_game`.`d_lb_reward_log` 
MODIFY COLUMN `settle_date` varchar(255) NULL DEFAULT '' COMMENT '结算日期' AFTER `uid`,
DROP INDEX `idx_lb_reward_log`,
ADD INDEX `idx_lb_reward_log`(`settle_date`(20), `rtype`) USING BTREE;