insert into s_config(k,v,memo) value('bind_phonedevice', 0, '限制特定型号手机不能注册');
-- sadd phone_limit_set "^%w%w%w%w%w%w%w%w%w%w%w%w%w%w%w%w_%w%w%w%w%w%w%w%w%w%w%w%w%w%w%w%w"
-- sadd phone_limit_set "^%w%w%w%w%w%w%w%w%w%w%w%w%w%w%w_%w%w%w%w%w%w%w%w%w%w%w%w%w%w%w"