<?php
namespace App\Model;

use App\Model\Model;
use Swoole\Coroutine\Redis;
use App\Model\Constants\RedisKey;
use App\Utility\Helper;
use EasySwoole\Component\TableManager;

class RedisCli extends Model
{
    public function getDb() : Redis
    {
        return $this->redis->getDb();
    }
    
    private function _arrayfilter($in = []) : array
    {
        $target = [];
        
        if(is_array($in) && ($_count = count($in)) > 1)
        {
            for ($i=0; $i<count($in); $i+=2) {
                $target[$in[$i]] = $in[$i+1];
            }
        }
        
        return $target;
    }
    
    private function _arrayConvertKV($in = []) : array
    {
        $_result = [];
        
        foreach ($in as $key => $value) {
            $_result[] = "{$key}=\"".addslashes($value)."\"";
        }
        
        return $_result;
    }
    
    public function loadLuaScript() : void
    {

        /**
         * 系统内部异步使用 只弹出队列
         * KEYS[1] redis key    队列的键名
         * KEYS[2] redis key    队列备份的键名
         * @var string
         */
        $scripts['_luascript_inner_queue'] = <<<EOF
local c=redis.call('RPOP',KEYS[1])
-- if c then
    -- redis.call('ZADD',KEYS[2],ARGV[1],ARGV[1] ..c)
-- end
return {c}
EOF;
        /**
         * KEYS[1] redis key    队列的键名
         * KEYS[2] redis key    队列备份的键名
         * @var string
         */
        $scripts['_luascript_queue_coin_player'] = <<<EOF
local c=redis.call('RPOP',KEYS[1])
-- if c then
-- redis.call('ZADD',KEYS[2],ARGV[1],ARGV[1] ..c)
-- end
return {c}
EOF;

        /**
         * KEYS[1] redis key    coins队列
         * KEYS[3] redis key    game_log队列
         * KEYS[5] redis key    第三方game_log队列
         * @var string
         */
        $scripts['_luascript_readqueue'] = <<<EOF
local c=redis.call('RPOP',KEYS[1])
local g=redis.call('RPOP',KEYS[3])
local tpg=redis.call('RPOP',KEYS[5])
if c then
    redis.call('ZADD',KEYS[2],ARGV[1],ARGV[1] ..c)
end
if g then
    redis.call('ZADD',KEYS[4],ARGV[1],ARGV[1] ..g)
end
if tpg then
    redis.call('ZADD',KEYS[6],ARGV[1],ARGV[1] ..tpg)
end
return {c,g,tpg}
EOF;

        /**
         * KEYS[1] redis key    是否关闭
         * KEYS[2] redis key    当前税池余额
         * KEYS[3] redis key    上一次税池余额
         * KEYS[4] redis key    彩池poolnormal余额
         * KEYS[5] redis key    JP池pooljp余额
         * ARGV[1] bet coin     下注额
         * ARGV[2] tax par      抽水率
         * ARGV[3] tax limitup  抽水上限
         * ARGV[4] tax interval 抽水时间隔
         * ARGV[5] pooljp par   JP池抽水率
         * @var string
         */
        $scripts['_luascript_commission'] = <<<EOF
local tax_reset = 0
local tax_close = redis.call('GET',KEYS[1])
local tax_extract = "0.00"
-- TAX池 最终余额
local pool_tax_balance_last = "0.00"
if tax_close and tonumber(tax_close) == 1 then
    tax_extract = "0.00"
    pool_tax_balance_last = redis.call('GET',KEYS[3])
else
    local tax_coin_last = redis.call('GET',KEYS[2])
    if not tax_coin_last then
        redis.call('SET',KEYS[2],"0.00")
        tax_coin_last = "0.00"
    end
    -- TAX池 本次玩家贡献额度
    tax_extract = string.format("%.4f", tonumber(tonumber(ARGV[1])*(tonumber(ARGV[2])/100)))
    local tax_coin_new = string.format("%.4f", tonumber(tax_coin_last)+tonumber(tax_extract))
    pool_tax_balance_last = tax_coin_new
    if tonumber(tax_coin_new) >= tonumber(ARGV[3]) then
        redis.call('SETEX',KEYS[1],tonumber(ARGV[4])*60,1)
        redis.call('SETEX',KEYS[3],tonumber(ARGV[4])*60,tax_coin_new)
        redis.call('SET',KEYS[2],"0.00")
        tax_reset = tax_coin_new
    else
        redis.call('SET',KEYS[2],tax_coin_new)
    end
end
local balance_poolnormal = redis.call('GET',KEYS[4])
if not balance_poolnormal then
    redis.call('SET',KEYS[4],"0.00")
    balance_poolnormal = "0.00"
end
local balance_jp = redis.call('GET',KEYS[5])
if not balance_jp then
    redis.call('SET',KEYS[5],"0.00")
    balance_jp = "0.00"
end
-- JP池 本次玩家贡献额度
local jp_extract = string.format("%.4f", (tonumber(ARGV[1])-tonumber(tax_extract))*(tonumber(ARGV[5])))
-- JP池 最终余额
local pool_jp_balance_last = string.format("%.4f", tonumber(balance_jp)+tonumber(jp_extract))
redis.call('SET',KEYS[5],pool_jp_balance_last)
-- 彩池 本次玩家贡献额度
local normal_extract = string.format("%.4f", tonumber(ARGV[1])-tonumber(tax_extract)-tonumber(jp_extract))
-- 彩池 最终余额
local pool_normal_balance_last = string.format("%.4f", tonumber(balance_poolnormal)+tonumber(normal_extract))
redis.call('SET',KEYS[4],pool_normal_balance_last)

return {tax_extract,jp_extract,normal_extract,tax_reset,pool_tax_balance_last,pool_jp_balance_last,pool_normal_balance_last}
EOF;

        //玩家结算
        $scripts['_transfer'] = <<<EOF
-- 彩池余额 结算前
local balance_poolnormal = redis.call('GET',KEYS[1])
if not balance_poolnormal then
    redis.call('SET',KEYS[1],"0.00")
    balance_poolnormal = "0.00"
end
local balance_jp = redis.call('GET',KEYS[2])
if not balance_jp then
    redis.call('SET',KEYS[2],"0.00")
    balance_jp = "0.00"
end
-- 彩池 结算额度
local outnormal = string.format("%.4f",ARGV[1])
-- JP池 结算额度
local outjp = "0.00"
-- 彩池 结算后余额
local newbalancenormal = string.format("%.4f",tonumber(balance_poolnormal)-tonumber(outnormal))
-- JP池 结算后余额
local newbalancejp = string.format("%.4f",tonumber(balance_jp))

    redis.call('SET',KEYS[1],newbalancenormal)
    if tonumber(ARGV[2]) > 0 and tonumber(balance_jp) >= tonumber(ARGV[3]) then
        outjp = string.format("%.4f",tonumber(balance_jp)*tonumber(ARGV[2]))
        newbalancejp = string.format("%.4f",tonumber(balance_jp)-tonumber(outjp))
        redis.call('SET',KEYS[2],newbalancejp)
    end
    return {outnormal,outjp,newbalancenormal,newbalancejp}

--    return {"0","0","0","0"}
EOF;

//        $scripts['_transfer'] = <<<EOF
//-- 彩池余额 结算前
//local balance_poolnormal = redis.call('GET',KEYS[1])
//if not balance_poolnormal then
//    redis.call('SET',KEYS[1],"0.00")
//    balance_poolnormal = "0.00"
//end
//local balance_jp = redis.call('GET',KEYS[2])
//if not balance_jp then
//    redis.call('SET',KEYS[2],"0.00")
//    balance_jp = "0.00"
//end
//-- 彩池 结算额度
//local outnormal = string.format("%.4f",ARGV[1])
//-- JP池 结算额度
//local outjp = "0.00"
//-- 彩池 结算后余额
//local newbalancenormal = string.format("%.4f",tonumber(balance_poolnormal)-tonumber(outnormal))
//-- JP池 结算后余额
//local newbalancejp = string.format("%.4f",tonumber(balance_jp))
//if tonumber(newbalancenormal) >= 0 then
//    redis.call('SET',KEYS[1],newbalancenormal)
//    if tonumber(ARGV[2]) > 0 and tonumber(balance_jp) >= tonumber(ARGV[3]) then
//        outjp = string.format("%.4f",tonumber(balance_jp)*tonumber(ARGV[2]))
//        newbalancejp = string.format("%.4f",tonumber(balance_jp)-tonumber(outjp))
//        redis.call('SET',KEYS[2],newbalancejp)
//    end
//    return {outnormal,outjp,newbalancenormal,newbalancejp}
//else
//    return {"0","0","0","0"}
//end
//EOF;

        //彩池借款
        $scripts['_loan'] = <<<EOF
local balance_poolnormal = redis.call('GET',KEYS[1])
if not balance_poolnormal then
    redis.call('SET',KEYS[1],"0.00")
    balance_poolnormal = "0.00"
end
local newbalance = string.format("%.4f",tonumber(balance_poolnormal)-tonumber(ARGV[1]))
redis.call('SET',KEYS[1],newbalance)
return {ARGV[1],newbalance}
end
EOF;

//        $scripts['_loan'] = <<<EOF
//local balance_poolnormal = redis.call('GET',KEYS[1])
//if not balance_poolnormal then
//    redis.call('SET',KEYS[1],"0.00")
//    balance_poolnormal = "0.00"
//end
//local newbalance = string.format("%.4f",tonumber(balance_poolnormal)-tonumber(ARGV[1]))
//if tonumber(newbalance) >= 0 then
//    redis.call('SET',KEYS[1],newbalance)
//    return {ARGV[1],newbalance}
//else
//    return {"0","0"};
//end
//EOF;
        //彩池还款
        $scripts['_revert'] = <<<EOF
local balance_poolnormal = redis.call('GET',KEYS[1])
if not balance_poolnormal then
    redis.call('SET',KEYS[1],"0.00")
    balance_poolnormal = "0.00"
end
local newbalance = string.format("%.4f",tonumber(balance_poolnormal)+tonumber(ARGV[1]))
redis.call('SET',KEYS[1],newbalance)
return {ARGV[1],newbalance}
EOF;

        //获取用户
        $scripts['getuser'] = <<<EOF
local userdata = ""
local _userid = tonumber(ARGV[1])
local _username = ARGV[2]
if string.len(_username) > 0 then
    _userid = redis.call('HGET', KEYS[1] .. 'username', _username)
end
local _userpid = ARGV[3]
if string.len(_userpid) > 0 then
    _userid = redis.call('HGET', KEYS[1] .. 'userpid', _userpid)
end
local _token = ARGV[4]
if string.len(_token) == 32 then
    _userid = redis.call('HGET', KEYS[1] .. 'usertoken', _token)
end
local _pcode = ARGV[5]
if string.len(_pcode) == 8 then
    _userid = redis.call('HGET', KEYS[1] .. 'userpcode', _pcode)
end
if tostring(_userid) ~= "" then
    userdata = redis.call('HGETALL', KEYS[1] .. _userid)
end
return userdata
EOF;

        //缓存用户
        $scripts['setuser'] = <<<EOF
local datas = {}
local userid = ""
local vuserid = ""
local oldtoken = "";
if ARGV[1] and tonumber(ARGV[1]) > 1 then
    for i=2,tonumber(ARGV[1])+1 do
        if i%2 == 0 and tostring(ARGV[i]) == "account_id" and tonumber(ARGV[i+1]) > 0 then
            userid = tostring(ARGV[i+1])
        end
        if i%2 == 0 and tostring(ARGV[i]) == "virtual_vid" and tonumber(ARGV[i+1]) > 0 then
            for j=2,tonumber(ARGV[1])+1 do
                if j%2 == 0 and tostring(ARGV[j]) == "virtual_parent_id" and tonumber(ARGV[j+1]) > 0 then
                    userid = tostring(ARGV[j+1]) .. "." .. tostring(ARGV[i+1])
                end
            end
        end
    end
end
if ARGV[1] and tonumber(ARGV[1]) > 1 then
    for i=2,tonumber(ARGV[1])+1 do
        if i%2 == 0 then
            if tostring(userid) ~= "" and tostring(ARGV[i]) == "account_username" and tostring(ARGV[i+1]) ~= "" then
                redis.call('HSETNX', KEYS[1] .. 'username', tostring(ARGV[i+1]), tostring(userid))
            elseif tostring(userid) ~= "" and tostring(ARGV[i]) == "account_pusername" and tostring(ARGV[i+1]) ~= "" then
                redis.call('HSETNX', KEYS[1] .. 'username', tostring(ARGV[i+1]), tostring(userid))
            elseif tostring(userid) ~= "" and tostring(ARGV[i]) == "virtual_username" and tostring(ARGV[i+1]) ~= "" then
                redis.call('HSETNX', KEYS[1] .. 'username', tostring(ARGV[i+1]), tostring(userid))
            end
            if tostring(userid) ~= "" and tostring(ARGV[i]) == "account_pid" and tostring(ARGV[i+1]) ~= "" then
                redis.call('HSETNX', KEYS[1] .. 'userpid', tostring(ARGV[i+1]), tostring(userid))
            elseif tostring(userid) ~= "" and tostring(ARGV[i]) == "account_pcode" and tostring(ARGV[i+1]) ~= "" then
                redis.call('HSETNX', KEYS[1] .. 'userpcode', tostring(ARGV[i+1]), tostring(userid))
            end
            if tostring(userid) ~= "" and tostring(ARGV[i]) == "account_token" then
                oldtoken = redis.call('HGET', KEYS[1] .. tostring(userid), "account_token")
                if tostring(oldtoken) ~= "" then
                    redis.call('HDEL', KEYS[1] .. 'usertoken', tostring(oldtoken))
                end
                if tostring(ARGV[i+1]) ~= "" then
                    redis.call('HSETNX', KEYS[1] .. 'usertoken', tostring(ARGV[i+1]), tostring(userid))
                end
            elseif tostring(userid) ~= "" and tostring(ARGV[i]) == "virtual_token" then
                oldtoken = redis.call('HGET', KEYS[1] .. tostring(userid), "virtual_token")
                if tostring(oldtoken) ~= "" then
                    redis.call('HDEL', KEYS[1] .. 'usertoken', tostring(oldtoken))
                end
                if tostring(ARGV[i+1]) ~= "" then
                    redis.call('HSETNX', KEYS[1] .. 'usertoken', tostring(ARGV[i+1]), tostring(userid))
                end
            end
            if tostring(userid) ~= "" then
                datas[ARGV[i]] = tostring(ARGV[i+1])
            end
        end
    end
end
if tostring(userid) ~= "" and datas then
    for k,v in pairs(datas) do
        redis.call('HSET', KEYS[1] .. tostring(userid), k, v)
    end
    return "success"
else
    return "faile"
end
EOF;

        //清除登录限制
        $scripts['delloginlimit'] = <<<EOF
redis.call('DEL', KEYS[1])
redis.call('DEL', KEYS[2])
redis.call('DEL', KEYS[3])
EOF;

        //获取账号是否禁用
        $scripts['getuserban'] = <<<EOF
local isban = ""
isban = redis.call('HGET', KEYS[1] .. 'userban', tostring(ARGV[1]))
if isban then
    return isban
else
    return "null"
end
EOF;

        $table = TableManager::getInstance()->get('table.redis.LuaSHa1s');
        if (! $table->count()) {
            foreach ($scripts as $key => $value) {
                $sha1 = $this->redis->getDb()->script('load', $value);
                $table->set(strtolower($key), ['sha1'=> $sha1]);
            }
        }
    }
    
    public function getLuaSha1s($key = '') : string
    {
        $tables = TableManager::getInstance()->get('table.redis.LuaSHa1s');
        
        return $tables->get($key, 'sha1');
    }
    
    private function searchMultiArray(array $array, $search, string $mode = 'key') : array
    {
        $res = [];
        
        foreach (new \RecursiveIteratorIterator(new \RecursiveArrayIterator($array)) as $key => $value) {
            if ($search === ${${"mode"}}) {
                if ($mode == 'key') {
                    $res[] = $value;
                } else {
                    $res[] = $key;
                }
            }
        }
        
        return $res;
    }
    
    private function getMysqlTableFields() : array
    {
        $tablelist = [];
        $ref = new \ReflectionClass('\\App\\Model\\Constants\\MysqlTables');
        $tables = $ref->getConstants();
        foreach ($tables as $tableName) {
            $fs = (array)$this->mysql->getDb()->rawQuery("SHOW FULL COLUMNS FROM {$tableName}");
            $tablelist[$tableName] = $this->searchMultiArray($fs, 'Field');
        }
        
        return $tablelist;
    }
    
    /**
     * mysql表缓存到内存
     */
    public function setMysqlTableNameToTable() : void
    {
        $table = TableManager::getInstance()->get('table.mysql.tables');
        if (! $table->count()) {
            $tablelist = $this->getMysqlTableFields();
            foreach ($tablelist as $key => $value) {
                $table->set($key, ['fields'=> implode(",", $value)]);
            }
        }
    }
    
    /**
     * 结算
     * @param number $coin
     * @param array $_system_setting
     * @param bool $can_get_jp          是否可以获得JP奖金
     * @return array
     */
    public function _transfer($coin = 0, $_system_setting = [], $can_get_jp = true)
    {
        $coin = Helper::format_money($coin);
        
        /**
         * JP池开奖比率
         */
        if ($can_get_jp && $_system_setting['pool_jp_outlimup'] > $_system_setting['pool_jp_outlimdown']) {
            $_pooljp_par = mt_rand($_system_setting['pool_jp_outlimdown'], $_system_setting['pool_jp_outlimup'])/100;
            $_pooljp_outline = $_system_setting['pool_jp_outline'];
        } else {
            $_pooljp_par = 0;
            $_pooljp_outline = 0;
        }
        
        list($_normal, $_jp, $_pool_normal_balance_last, $_pool_jp_balance_last) = $this->redis->getDb()->evalSha(
            $this->getLuaSha1s('_transfer'), 
            [
                RedisKey::SYSTEM_BALANCE_POOLNORMAL,
                RedisKey::SYSTEM_BALANCE_POOLJP,
                $coin,
                $_pooljp_par,
                $_pooljp_outline
            ],
            2
        );
        
        return [$_normal, $_jp, $_pool_normal_balance_last, $_pool_jp_balance_last];
    }
    
    /**
     * 借款
     * @param number $coin
     * @return array
     */
    public function _loan($coin = 0)
    {
        $coin = Helper::format_money($coin);
        
        list($_c_out, $_c_b) = $bbb = $this->redis->getDb()->evalSha(
            $this->getLuaSha1s('_loan'), 
            [
                RedisKey::SYSTEM_BALANCE_POOLNORMAL,
                $coin
            ],
            1
        );
        
        return [$_c_out, $_c_b];
    }
    
    /**
     * 还款
     * @param number $coin
     * @return array
     */
    public function _revert($coin = 0)
    {
        $coin = Helper::format_money($coin);
        
        list($_c_in, $_c_b) = $this->redis->getDb()->evalSha(
            $this->getLuaSha1s('_revert'),
            [
                RedisKey::SYSTEM_BALANCE_POOLNORMAL,
                $coin
            ],
            1
        );
        
        return [$_c_in, $_c_b];
    }
    
    public function getUser($par = null) : array
    {
        $pars = [
            RedisKey::USERS_,
            //id
            is_numeric($par) && $par > 0 && ((strpos($par, ".") === false && strlen($par) < 10) || strpos($par, ".") !== false) ? $par : 0,
            //username
            ! is_numeric($par) && ! Helper::account_format_login($par) && ! preg_match('/^[a-z0-9]{32}$/i', $par) ? $par : '',
            //pid
            !! ($_pid = Helper::account_format_login($par)) && is_numeric($_pid) ? $_pid : '',
            //token
            ! is_numeric($par) && preg_match('/^[a-z0-9]{32}$/i', $par) ? $par : '',
            //pcode
            ! is_numeric($par) && strpos($par, "_pcode_") !== false ? str_replace("_pcode_", "", $par) : ''
        ];
        
        $user = $this->redis->getDb()->evalSha(
            $this->getLuaSha1s('getuser'),
            $pars,
            1
        );
        
        return $this->_arrayfilter($user);
    }
    
    public function setUser($user = [])
    {
        $pars = [
            RedisKey::USERS_,
            count($user)*2
        ];
        
        foreach ($user as $key => $value) {
            $pars[] = $key;
            $pars[] = $value;
        }
        
        $result = $this->redis->getDb()->evalSha(
            $this->getLuaSha1s('setuser'),
            $pars,
            1
        );
        
        return $result;
    }
    
    public function delLoginLimit($key1 = '', $key2 = '', $key3 = '') : void
    {
        $this->redis->getDb()->evalSha(
            $this->getLuaSha1s('delloginlimit'),
            [
                $key1,
                $key2,
                $key3
            ],
            3
        );
    }
    
    public function getUserBan($account_id = "0") : string
    {
        return $this->redis->getDb()->evalSha(
            $this->getLuaSha1s('getuserban'),
            [
                RedisKey::USERS_,
                $account_id
            ],
            1
         );
    }
}