<?php
namespace App\Model;

use App\Model\Model;
use App\Model\Constants\RedisKey;
use App\Model\Constants\MysqlTables;
use App\Utility\Helper;
use EasySwoole\Utility\Random;
use App\Task\MysqlQuery;
use EasySwoole\EasySwoole\Swoole\Task\TaskManager;
use EasySwoole\EasySwoole\Config;
use EasySwoole\EasySwoole\Logger;
use PHPMailer\PHPMailer\PHPMailer;

class Account extends Model
{
    /**
     * 获取账号信息ByToken
     * @param string $token
     * @return array
     */
    public function getAccountByToken($token = '') : array
    {
        return $this->models->rediscli_model->getUser($token);
    }
    
    public function getAccountByAppID(string $appID = '') : array
    {
        $username = $this->mysql->getDb()->where('appid', $appID)->getValue(MysqlTables::ACCOUNT, 'username');
        if (! ($agent = $this->models->rediscli_model->getUser($username))) {
            $agent = $this->getAgent($username, 0, false, true, true);
        }
        
        return $agent ?: [];
    }
    
    public function getAppKeyByAppID(string $appID = '') : string
    {
        $appKey = $this->models->platform_model->getApiPassword($appID);
        
        return $appKey ?: '';
    }
    
    /**
     * 系统管理员
     * @return array
     */
    public function getSystemer() : array
    {
        return $this->mysql->getDb()->where('agent', 3)->orderBy('id', 'ASC')->getOne(MysqlTables::ACCOUNT, 'id,username');
    }
    
    /**
     * 当前玩家ID
     * @return int
     */
    public function getCurentPlayerID() : int
    {
        return $this->getTokenObj()->account_id;
    }
    
    /**
     * 当前玩家是否允许获得JP奖金
     * @param string $account_id
     * @param string $timeNow
     */
    public function getPlayerCanGetJP(string $account_id = '0', string $timeNow = '0')
    {
        $timeNow = $timeNow && is_numeric($timeNow) ? $timeNow : time();
        
        $lasttime = $this->mysql->getDb()->where('account_id', $account_id)->where('type', 2)->orderBy('id', 'DESC')->getValue(MysqlTables::POOL_JP, 'create_time');
        if (is_numeric($lasttime) && $timeNow - $lasttime < 60) {
            return false;
        }
        
        $prob = $this->models->prob_model->getUserProb($account_id);
        if ($prob && isset($prob['prob']) && $prob['prob'] == 5) {
            return false;
        }
        
        return true;
    }
    
    /**
     * 登录日志
     * 并返回玩家信息
     * 
     * @param string $ip
     * @param string $gameid
     * @param string $signstr
     * @return array|bool
     */
    public function putPlayerLoginByToken(string $ip = '', string $gameid = '', string $signstr = '') : array
    {
        $sql = [];
        $_login_time = time();
        
        if (! ($_player = $this->getPlayer($this->getTokenObj()->account_pid, 0, true))) {
            return [];
        }
        
        //判断ip是否与一级代理设定的区域一致
        if (!$this->checkIp($_player['account_parent_agent_first_id'], $ip)) {
            return [];
        }
        
        //是否被禁用了账号的登录操作
        if (isset($_player['account_bandepth']) && $_player['account_bandepth']) {
            $this->setErrCode(3003);
            $this->setErrMsg('游戏账号禁止登陆', true);
            
            return [];
        }
        
        //是否被踢下线60秒，并且还未到解除时间点
        if (isset($_player['account_ban_time']) && (int)$_player['account_ban_time'] > time()) {
            $this->setErrCode(3003);
            $this->setErrMsg('游戏账号禁用'.($_player['account_ban_time']-time()).'秒', true);
            
            return [];
        }
        
        $_account = [
            'id'=> $_player['account_id'],
            'coin'=> $this->getCoinFieldValue($_player['account_id']),
            'login_time'=> $_login_time
        ];
        
        //db字段
        $_upData = ['login_time'=> $_login_time, 'update_time'=> time(), 'online'=> 1];
        //redis字段
        $_upRedisData = Helper::reFieldPre($_upData, 'account');
        $_upRedisData['account_id'] = $_player['account_id'];
        
        //db更新账号信息
        $sql[] = $this->mysql->getDb()->where('id', $_player['account_id'])->fetchSql()->update(MysqlTables::ACCOUNT, $_upData);
        $this->mysql->getDb()->resetDbStatus();
        
        //更新redis玩家账号信息
        $this->models->rediscli_model->setUser($_upRedisData);
        
        //添加登录日志
        $sql[] = $this->mysql->getDb()->fetchSql()->insert(MysqlTables::LOG_LOGIN_PLAYER, [
            't'=> 2,
            'account_id'=> $_player['account_id'],
            'account_parent_agent_first_id'=> $_player['account_parent_agent_first_id'],
            'account_parent_id'=> $_player['account_parent_id'],
            'account_pid'=> Helper::account_format_login($_player['account_pid']),
            'ip'=> $ip,
            'date_y'=> date("Y", $_login_time),
            'date_m'=> date("m", $_login_time),
            'date_d'=> date("d", $_login_time),
            'date_h'=> date("H", $_login_time),
            'create_time'=> $_login_time
        ]);
        $this->mysql->getDb()->resetDbStatus();
        
        //异步执行SQL
        TaskManager::async(new MysqlQuery($sql));
        
        Helper::array_insert($_account, ['account'=> Helper::account_format_display($_player['account_pid'])], 'coin');
        
        return ['token'=> $_player['account_token'], 'expires_in'=> -1, 'account'=> $_account];
    }
    
    /**
     * 检查账号与密码的匹配
     * 代理账号
     * @param string $account   账号PID或者USERNAME
     * @param string $pwd       md5(密码明文)
     * @return array
     */
    public function getAgentCheckPwd(string $account = '', string $pwd = '') : array
    {
        $agent = [];
        
        //内部调试专用逻辑
        if (substr_count($account, '.') === 1) {
            $fromPort = substr($account, 0, strpos($account, '.'));
            $account = substr($account, strpos($account, '.')+1);
        }
        
        //是否此账号登录操作被锁定
        if (!! ($_lock_login_sec = $this->redis->getDb()->get(RedisKey::ACCOUNT_LOGIN_MATCHPWD_LOCKSEC_ . $account)) && $_lock_login_sec > 1) {
            //解锁剩余时间，单位：秒
            $_locksec = $this->redis->getDb()->ttl(RedisKey::ACCOUNT_LOGIN_MATCHPWD_LOCKSEC_ . $account);
            $this->setErrData(['locksec'=> $_locksec]);
            
            switch (abs(intval($_lock_login_sec))) {
                case 2:
                    $this->setErrCode(3005002);
                    $this->setErrMsg('无法登录，稍等2秒再试(HEAD)，剩余：' . $_locksec.'秒。', true);
                    break;
                case 5:
                    $this->setErrCode(3005005);
                    $this->setErrMsg('无法登录，稍等5秒再试(HEAD)，剩余：' . $_locksec.'秒。', true);
                    break;
                case 10:
                    $this->setErrCode(3005010);
                    $this->setErrMsg('无法登录，稍等10秒再试(HEAD)，剩余：' . $_locksec.'秒。', true);
                    break;
                case 20:
                    $this->setErrCode(3005020);
                    $this->setErrMsg('无法登录，稍等20秒再试(HEAD)，剩余：' . $_locksec.'秒。', true);
                    break;
                case 600:
                    $this->setErrCode(3005600);
                    $this->setErrMsg('无法登录，稍等10分钟再试(HEAD)，剩余：' . $_locksec.'秒。', true);
                    break;
                default:
                    $this->setErrCode(3005000);
                    $this->setErrMsg('无法登录，稍后再试(SEC NULL)(HEAD)，剩余：' . $_locksec.'秒。', true);
                    break;
            }
            
            return [];
        }

        //获取账号信息
        if(! ($agent = $this->models->rediscli_model->getUser($account)/* 从redis取代理账号缓存 */))
        {
            //从db取代理账号信息
            $_a_fieldstrs = $this->getTableFields(MysqlTables::ACCOUNT, ['a', 'account_', ',']);
            $_v_fieldstrs = $this->getTableFields(MysqlTables::ACCOUNT_CHILD_AGENT, ['v', 'virtual_', ',']);
            $_fieldstrs = $_a_fieldstrs . "," . $_v_fieldstrs;

            $agent = $this->mysql->getDb()
                ->where("(a.username='{$account}' and a.agent>0) OR (v.username='{$account}' and a.agent>0 AND v.vid IS NOT NULL)")
                ->orderBy('a.id', 'DESC')->orderBy('v.vid', 'DESC')
                ->join("account as a", 'a.id=v.parent_id', 'right')
                ->getOne('account_child_agent as v ', $_fieldstrs);



            $agent = isset($agent['account_id']) ? $agent : [];
        }
        
        //子账号
        if ($agent && isset($agent['virtual_vid']) && $agent['virtual_vid'] && $account == $agent['virtual_username']) {
            //匹配密码
            $agent = $agent['virtual_password'] === md5($agent['virtual_username'] . $pwd . $agent['virtual_salt']) ? Helper::arrayFilterHoldByKeypre($agent, 'virtual_') : [];
            
            //更新redis代理账号信息
            if ($agent) $agent['virtual_fromport'] = $fromPort ?? 0;
            if ($agent) $this->models->rediscli_model->setUser($agent);
        }
        //主账号
        elseif ($agent && $account == $agent['account_username']) {
            //匹配密码
            $agent = $agent['account_password'] === md5($agent['account_username'] . $pwd . $agent['account_salt']) ? Helper::arrayFilterHoldByKeypre($agent, 'account_') : [];
            
            //更新redis代理账号信息
            if ($agent) $agent['account_fromport'] = $fromPort ?? 0;
            if ($agent) $this->models->rediscli_model->setUser($agent);
        }
        
        //无法获取账号，或者账号和密码匹配错误
        if (! $agent) {
            //密码已连续输入错误
            if (
                ($_resec = $this->redis->getDb()->ttl(RedisKey::ACCOUNT_LOGIN_MATCHPWD_TIME_ . $account)) > 0
                && !! ($_lock_login_time/* 连续错误次数 */ = $this->redis->getDb()->get(RedisKey::ACCOUNT_LOGIN_MATCHPWD_TIME_ . $account))
            ) {
                //错误次数增加1
                $_nextlocktime = intval($_lock_login_time+1);
                $this->redis->getDb()->setex(RedisKey::ACCOUNT_LOGIN_MATCHPWD_TIME_ . $account, $_resec, $_nextlocktime);
                
                switch ($_nextlocktime) {
                    case 2:
                        $this->redis->getDb()->setex(RedisKey::ACCOUNT_LOGIN_MATCHPWD_LOCKSEC_ . $account, 5, 5);
                        $this->setErrData(['locksec'=> 5]);
                        $this->setErrCode(3005005);
                        $this->setErrMsg('无法登录，稍等5秒再试(SER)', true);
                        break;
                    case 3:
                        $this->redis->getDb()->setex(RedisKey::ACCOUNT_LOGIN_MATCHPWD_LOCKSEC_ . $account, 10, 10);
                        $this->setErrData(['locksec'=> 10]);
                        $this->setErrCode(3005010);
                        $this->setErrMsg('无法登录，稍等10秒再试(SER)', true);
                        break;
                    case 4:
                        $this->redis->getDb()->setex(RedisKey::ACCOUNT_LOGIN_MATCHPWD_LOCKSEC_ . $account, 20, 20);
                        $this->setErrData(['locksec'=> 20]);
                        $this->setErrCode(3005020);
                        $this->setErrMsg('无法登录，稍等20秒再试(SER)', true);
                        break;
                    case 5:
                        $this->redis->getDb()->setex(RedisKey::ACCOUNT_LOGIN_MATCHPWD_LOCKSEC_ . $account, 600, 600);
                        $this->setErrData(['locksec'=> 600]);
                        $this->setErrCode(3005600);
                        $this->setErrMsg('无法登录，稍等10分钟再试(SER)', true);
                        break;
                    default:
                        $this->redis->getDb()->setex(RedisKey::ACCOUNT_LOGIN_MATCHPWD_LOCKSEC_ . $account, 600, 600);
                        $this->setErrData(['locksec'=> 600]);
                        $this->setErrCode(3005600);
                        $this->setErrMsg('无法登录，稍等10分钟再试(SER)', true);
                        break;
                }
            }
            //密码首次输入错误
            else {
                //1分钟之内密码输入错误次数大于或等于5次
                if (!! ($_MATCHPWD_INIT = $this->redis->getDb()->get(RedisKey::ACCOUNT_LOGIN_MATCHPWD_INIT_ . $account)) && $_MATCHPWD_INIT >=5) {
                    //设连续错误次数为1，并设置键值过期时间为10分钟
                    $this->redis->getDb()->setex(RedisKey::ACCOUNT_LOGIN_MATCHPWD_TIME_ . $account, 600, 1);
                    //设置锁定时间为2秒
                    $this->redis->getDb()->setex(RedisKey::ACCOUNT_LOGIN_MATCHPWD_LOCKSEC_ . $account, 2, 2);
                    
                    $this->setErrData(['locksec'=> 2]);
                    $this->setErrCode(3005002);
                    $this->setErrMsg('无法登录，稍等2秒再试(FIR)', true);
                }
                //1分钟之内首次密码输入错误
                elseif ($_MATCHPWD_INIT == false) {
                    //首次密码错误
                    $this->redis->getDb()->setex(RedisKey::ACCOUNT_LOGIN_MATCHPWD_INIT_ . $account, 60, 1);
                }
                //1分钟之内密码输入错误次数小于5次
                elseif ($_MATCHPWD_INIT < 5) {
                    //本次为第5次密码错误
                    if ($_MATCHPWD_INIT + 1 == 5) {
                        $this->redis->getDb()->setex(RedisKey::ACCOUNT_LOGIN_MATCHPWD_INIT_ . $account, 1200, 5);
                    }
                    //本次为小于5次密码错误
                    else {
                        $_mi_ttl = $this->redis->getDb()->ttl(RedisKey::ACCOUNT_LOGIN_MATCHPWD_INIT_ . $account);
                        $this->redis->getDb()->setex(RedisKey::ACCOUNT_LOGIN_MATCHPWD_INIT_ . $account, $_mi_ttl, $_MATCHPWD_INIT+1);
                    }
                }
            }
            
            return [];
        }
        //账号和密码匹配正确
        else
        {
            //清除因账号与密码不匹配造成的登录限制
            $this->models->rediscli_model->delLoginLimit(
                RedisKey::ACCOUNT_LOGIN_MATCHPWD_INIT_ . $account,
                RedisKey::ACCOUNT_LOGIN_MATCHPWD_TIME_ . $account,
                RedisKey::ACCOUNT_LOGIN_MATCHPWD_LOCKSEC_ . $account
            );
            //主账号
            if (isset($agent['account_id'])) {
                //是否被禁用了账号的登录操作
                if ($this->checkAccountBan($agent['account_id'])) {
                    $this->setErrCode(3003);
                    $this->setErrMsg('账号禁止登陆', true);
                    return [];
                }
            }
            //子账号
            else {
                //主账号判断
                if ($this->checkAccountBan($agent['virtual_parent_id'])) {
                    $this->setErrCode(3003);
                    $this->setErrMsg('账号禁止登陆，主账号被禁止', true);
                    return [];
                } elseif ($agent['virtual_ban'] == 1) {
                    $this->setErrCode(3003);
                    $this->setErrMsg('账号禁止登陆，主账号被禁止', true);
                    return [];
                }
            }
        }
        
        return $agent;
    }
    
    public function getPlayerRelation(string $account = '') : array
    {
        //根据账号获取UID
        if ($account) {
            return ['account_id'=> $this->mysql->getDb()->where('pid', $account)->getValue(MysqlTables::ACCOUNT, 'id'), 'account_pid'=> $account];
        }
        
        //获取关系列表
        $result = ['parents'=> [], 'childrens'=> []];
        
        //祖先
//        if (!! ($parents = $this->mysql->getDb()->join('account as a', 't.ancestor_id=a.id', 'left')
//            ->where('t.descendant_id', $this->getTokenObj()->account_id)->where('t.descendant_agent', 0)
//            ->where('t.ancestor_h', 0, '>')->where('t.ancestor_h', 6, '<')->where('a.agent', 0)
//            ->orderBy('t.ancestor_h', 'ASC')
//            ->get('account_tree as t', null, 'a.pid,a.pusername,t.ancestor_id,t.ancestor_h'))) {
//                foreach ($parents as $p) {
//                    $result['parents'][] = ['account_id'=> $p['ancestor_id'], 'account'=> $p['pid'], 'username'=> $p['pusername'] ?: $p['pid'], 'height'=> $p['ancestor_h']];
//                }
//        }
//        //子孙
//        if (!! ($childrens = $this->mysql->getDb()->join('account as a', 't.descendant_id=a.id', 'left')
//            ->where('t.ancestor_id', $this->getTokenObj()->account_id)->where('t.descendant_agent', 0)
//            ->where('t.ancestor_h', 0, '>')->where('t.ancestor_h', 6, '<')->orderBy('t.ancestor_h', 'ASC')
//            ->get('account_tree as t', null, 'a.pid,a.pusername,t.descendant_id,t.ancestor_h'))) {
//                foreach ($childrens as $c) {
//                    $result['childrens'][] = ['account_id'=> $c['descendant_id'], 'account'=> $c['pid'], 'username'=> $c['pusername'] ?: $c['pid'], 'height'=> $c['ancestor_h']];
//                }
//        }
        
        return $result;
    }
    
    public function checkPlayerRelation(string $account_id = '0', string $relation = '') : bool
    {
        $result = ['parents'=> [], 'childrens'=> []];
        
        //祖先
        if (!! ($parents = $this->mysql->getDb()->join('account as a', 't.ancestor_id=a.id', 'left')
            ->where('t.descendant_id', $this->getTokenObj()->account_id)->where('t.descendant_agent', 0)
            ->where('t.ancestor_h', 0, '>')->where('t.ancestor_h', 6, '<')->where('a.agent', 0)
            ->orderBy('t.ancestor_h', 'ASC')
            ->get('account_tree as t', null, 't.ancestor_id,t.ancestor_h'))) {
                foreach ($parents as $p) {
                    $result['parents'][$p['ancestor_id']] = ['account_id'=> $p['ancestor_id'], 'height'=> $p['ancestor_h']];
                }
        }
        //子孙
        if (!! ($childrens = $this->mysql->getDb()->where('ancestor_id', $this->getTokenObj()->account_id)->where('descendant_agent', 0)
            ->where('ancestor_h', 0, '>')->where('ancestor_h', 6, '<')->orderBy('ancestor_h', 'ASC')
            ->get(MysqlTables::ACCOUNT_TREE, null, 'descendant_id,ancestor_h'))) {
                foreach ($childrens as $c) {
                    $result['childrens'][$c['descendant_id']] = ['account_id'=> $c['descendant_id'], 'height'=> $c['ancestor_h']];
                }
        }
        
        if ($relation == 'parent') {
            return isset($result['parents'][$account_id]);
        } else {
            return isset($result['childrens'][$account_id]);
        }
    }
    
    public function putReChildPlayerPassword(string $account_id = '0') : bool
    {
        $result = ['childrens'=> []];
        
        //子孙
        if (!! ($childrens = $this->mysql->getDb()->where('ancestor_id', $this->getTokenObj()->account_id)->where('descendant_agent', 0)
            ->where('ancestor_h', 0, '>')->where('ancestor_h', 6, '<')->orderBy('ancestor_h', 'ASC')
            ->get(MysqlTables::ACCOUNT_TREE, null, 'descendant_id,ancestor_h'))) {
                foreach ($childrens as $c) {
                    $result['childrens'][$c['descendant_id']] = ['account_id'=> $c['descendant_id'], 'height'=> $c['ancestor_h']];
                }
        }
        
        //判断为当前账号的子孙
        if (isset($result['childrens'][$account_id])) {
            //获取账号
            if (! ($_child = $this->getPlayer(null, $account_id))) {
                return false;
            }
            //db字段
            $_needDbData = ['update_time'=> time(), 'token'=> null, 'token_expires'=> 0, 'online'=> 0];
            //清空token
            $_needDbData['salt'] = $salt = mt_rand(100000,999999);
            $_needDbData['password'] = md5($_child['account_pid'] . md5('123456') . $salt);
            $_needDbData['psecurity_pwd'] = md5($_child['account_pid'] . md5('123456'));
            //redis字段
            $_upRedisData = Helper::reFieldPre($_needDbData, 'account');
            $_upRedisData['account_id'] = $account_id;
            
            //db更新账号信息
            $sql[] = $this->mysql->getDb()->where('id', $account_id)->fetchSql()->update(MysqlTables::ACCOUNT, $_needDbData);
            $this->mysql->getDb()->resetDbStatus();
            
            //更新redis玩家账号信息
            $this->models->rediscli_model->setUser($_upRedisData);
            
            //删除玩家账号token
            $this->redis->getDb()->hDel(RedisKey::USERS_."usertoken", $_child['account_token']);
            
            //异步执行SQL
            TaskManager::async(new MysqlQuery($sql));
        }
        
        return true;
    }
    
    /**
     * 检查游客账号与密码的匹配
     * 游戏账号
     * @param string $account
     * @param string $pwd
     * @param string $ip
     * @param string $clientuuid
     * @param bool $ignoreCheck
     * @return array|bool
     */
    public function getYKPlayerCheckPwd(string $account_id='', string $pwd='', string $ip='', string $clientuuid='', bool $ignoreCheck=false) : array
    {
        $_login = [];
        $db   = $this->mysql->getDb();
        $account_data = $db->where('id', $account_id)->getOne(MysqlTables::ACCOUNT);
        if(!empty($account_data)) {
           $_account     = $this->getPlayerCheckPwd($account_data['pid'], $pwd, $ip, $clientuuid, $ignoreCheck);
            if(!empty($_account)) {
                $_account['account_ip'] = $ip;
                $_account['account_clientuuid'] = $clientuuid;
                $_login = $this->putPlayerLogin($_account);
            } 
        }
        return $_login;
    }

    /**
     * 检查账号与密码的匹配
     * 游戏账号
     * @param string $account
     * @param string $pwd
     * @param string $ip
     * @param string $clientuuid
     * @param bool $ignoreCheck
     * @return array|bool
     */
    public function getPlayerCheckPwd(string $account = '', string $pwd = '', string $ip = '', string $clientuuid = '', bool $ignoreCheck = false) : array
    {
        $player = [];
        //获取账号信息
        if(! ($player = $this->models->rediscli_model->getUser($account)/* 从redis取玩家账号缓存 */))
        {
            //从db取玩家账号信息
            $_fieldstrs = $this->getTableFields(MysqlTables::ACCOUNT, ['a', 'account_', ',']);
            $_sql = "
                    SELECT
                        {$_fieldstrs}
                    FROM
                        account as a
                    WHERE
                        a.agent=0
                        AND " . (Helper::isPlayerUsername($account) ? "a.pusername='{$account}'" : "a.pid='{$account}'") . "
                    LIMIT 0,1
                    ";
            //查询数据
            $_ds = $this->mysql->getDb()->rawQuery($_sql);
            $player = isset($_ds[0]) ? array_shift($_ds) : [];
            //更新redis玩家账号信息
            if($player) {
                $this->models->rediscli_model->setUser($player);
            } 
        }
        //如果是通过username登录，需要判断是否为玩家账号身份
        elseif (Helper::isPlayerUsername($account) && $player['account_agent'] != "0") {
            $player = [];
        }
        
        //无法获取账号，或者账号和密码匹配错误
        if (! $player || (! $ignoreCheck && ! ($player['account_password'] === md5($player['account_pid'] . $pwd . $player['account_salt'])))) {
            //密码已连续输入错误
            if (
                ($_resec = $this->redis->getDb()->ttl(RedisKey::ACCOUNT_LOGIN_MATCHPWD_TIME_ . $account)) > 0
                && !! ($_lock_login_time/* 连续错误次数 */ = $this->redis->getDb()->get(RedisKey::ACCOUNT_LOGIN_MATCHPWD_TIME_ . $account))
            ) {
                //错误次数增加1
                $_nextlocktime = intval($_lock_login_time+1);
                $this->redis->getDb()->setex(RedisKey::ACCOUNT_LOGIN_MATCHPWD_TIME_ . $account, $_resec, $_nextlocktime);
                
                switch ($_nextlocktime) {
                    case 2:
                        $this->redis->getDb()->setex(RedisKey::ACCOUNT_LOGIN_MATCHPWD_LOCKSEC_ . $account, 5, 5);
                        $this->setErrData(['locksec'=> 5]);
                        $this->setErrCode(3005005);
                        $this->setErrMsg('无法登录，稍等5秒再试(SER)', true);
                        break;
                    case 3:
                        $this->redis->getDb()->setex(RedisKey::ACCOUNT_LOGIN_MATCHPWD_LOCKSEC_ . $account, 10, 10);
                        $this->setErrData(['locksec'=> 10]);
                        $this->setErrCode(3005010);
                        $this->setErrMsg('无法登录，稍等10秒再试(SER)', true);
                        break;
                    case 4:
                        $this->redis->getDb()->setex(RedisKey::ACCOUNT_LOGIN_MATCHPWD_LOCKSEC_ . $account, 20, 20);
                        $this->setErrData(['locksec'=> 20]);
                        $this->setErrCode(3005020);
                        $this->setErrMsg('无法登录，稍等20秒再试(SER)', true);
                        break;
                    case 5:
                        $this->redis->getDb()->setex(RedisKey::ACCOUNT_LOGIN_MATCHPWD_LOCKSEC_ . $account, 600, 600);
                        $this->setErrData(['locksec'=> 600]);
                        $this->setErrCode(3005600);
                        $this->setErrMsg('无法登录，稍等10分钟再试(SER)', true);
                        break;
                    default:
                        $this->redis->getDb()->setex(RedisKey::ACCOUNT_LOGIN_MATCHPWD_LOCKSEC_ . $account, 600, 600);
                        $this->setErrData(['locksec'=> 600]);
                        $this->setErrCode(3005600);
                        $this->setErrMsg('无法登录，稍等10分钟再试(SER)', true);
                        break;
                }
            }
            //密码首次输入错误
            else
            {
                //1分钟之内密码输入错误次数大于或等于5次
                if (!! ($_MATCHPWD_INIT = $this->redis->getDb()->get(RedisKey::ACCOUNT_LOGIN_MATCHPWD_INIT_ . $account)) && $_MATCHPWD_INIT >=5) {
                    //设连续错误次数为1，并设置键值过期时间为10分钟
                    $this->redis->getDb()->setex(RedisKey::ACCOUNT_LOGIN_MATCHPWD_TIME_ . $account, 600, 1);
                    //设置锁定时间为2秒
                    $this->redis->getDb()->setex(RedisKey::ACCOUNT_LOGIN_MATCHPWD_LOCKSEC_ . $account, 2, 2);
                    
                    $this->setErrData(['locksec'=> 2]);
                    $this->setErrCode(3005002);
                    $this->setErrMsg('无法登录，稍等2秒再试(FIR)', true);
                }
                //1分钟之内首次密码输入错误
                elseif ($_MATCHPWD_INIT == false) {
                    //首次密码错误
                    $this->redis->getDb()->setex(RedisKey::ACCOUNT_LOGIN_MATCHPWD_INIT_ . $account, 60, 1);
                }
                //1分钟之内密码输入错误次数小于5次
                elseif ($_MATCHPWD_INIT < 5) {
                    //本次为第5次密码错误
                    if ($_MATCHPWD_INIT + 1 == 5) {
                        $this->redis->getDb()->setex(RedisKey::ACCOUNT_LOGIN_MATCHPWD_INIT_ . $account, 1200, 5);
                    }
                    //本次为小于5次密码错误
                    else {
                        $_mi_ttl = $this->redis->getDb()->ttl(RedisKey::ACCOUNT_LOGIN_MATCHPWD_INIT_ . $account);
                        $this->redis->getDb()->setex(RedisKey::ACCOUNT_LOGIN_MATCHPWD_INIT_ . $account, $_mi_ttl, $_MATCHPWD_INIT+1);
                    }
                }
            }
            
            return [];
        }
        //账号和密码匹配正确
        else
        {
            //清除因账号与密码不匹配造成的登录限制
            $this->models->rediscli_model->delLoginLimit(
                RedisKey::ACCOUNT_LOGIN_MATCHPWD_INIT_ . $account,
                RedisKey::ACCOUNT_LOGIN_MATCHPWD_TIME_ . $account,
                RedisKey::ACCOUNT_LOGIN_MATCHPWD_LOCKSEC_ . $account
            );

//            //是否被踢下线60秒，并且还未到解除时间点
//            if ((int)$player['account_ban_time'] > time()) {
//                $this->setErrCode(3003);
//                $this->setErrMsg('游戏账号禁用' . ($player['account_ban_time'] - time()) . '秒', true);
//                return [];
//            }
//            //判断账号是否被直接或者间接禁用
//            elseif ($this->checkAccountBan($player['account_id'])) {
//                $this->setErrCode(3003);
//                $this->setErrMsg('游戏账号禁止登陆', true);
//                return [];
//            }
        }
        
        return $player;
    }
    
    private function getAccountBan($accountId)
    {
        $db = $this->mysql->getDb();
        $rs = $db->where('descendant_id', $accountId)->getOne(MysqlTables::ACCOUNT_BAN);
        return $rs ? true : false;
    }
    
    public function checkAccountBan(string $account_id = '') : bool
    {
        $hasBan = false;
        
        //查询是否被直接禁用
        if ($this->mysql->getDb()->where('id', $account_id)->where('banby_id', 0, '>')->has(MysqlTables::ACCOUNT)) {
            $hasBan = true;
        }
        
        //查询是否被间接禁用，即账号的任一上级被禁用
        if (!$hasBan) {
            if ($this->mysql->getDb()->sum("(
                    
                    SELECT a.banby_id FROM account_tree as a_t LEFT JOIN account as a ON (a_t.ancestor_id=a.id AND a.banby_id>0)
                    WHERE a_t.ancestor_id!={$account_id} AND a_t.descendant_id={$account_id} AND a.banby_id>0
                    
                ) as T", 'banby_id')) {
                $hasBan = true;
            }
        }
        
        return $hasBan;
    }

    /**
     * 检查是否是上下级关系
     * @param $account_id
     * @return bool
     * @throws \EasySwoole\Mysqli\Exceptions\ConnectFail
     * @throws \EasySwoole\Mysqli\Exceptions\PrepareQueryFail
     * @throws \Throwable
     */
    private function checkRelation($account_id) : bool
    {
        $row = $this->mysql->getDb()->where('ancestor_id', $this->getTokenObj()->account_id)
            ->where('descendant_id', $account_id)->getOne(MysqlTables::ACCOUNT_TREE);
        if(!$row) {
            return false;
        }

        return true;
    }

    /**
     * 保存登录限制ip状态
     * 游戏账号
     * @param array $_account
     * @return array
     */
    public function saveLoginIPStatus($username, $state) : bool
    {
        $_agent = $this->getTokenArray();
        $account = $this->mysql->getDb()->where('username', $username)->getOne(MysqlTables::ACCOUNT);
        if(!$this->checkRelation($account['id'])) {
            return false;
        }
        $sql = [];
        $account_row = $this->mysql->getDb()->where('account_id', $account['id'])->getOne(MysqlTables::ACCOUNT_LOGINIP);
        if($account_row) {
            $_upData['status'] = $state;
            $sql[] = $this->mysql->getDb()->where('account_id', $account['id'])->fetchSql()->update(MysqlTables::ACCOUNT_LOGINIP, $_upData);
            $this->mysql->getDb()->resetDbStatus();
            if(!empty($sql)) {
                //异步执行SQL
                TaskManager::async(new MysqlQuery($sql));
            }
        } else {
            $_upData = [];
            $_upData['account_id'] = $account['id'];
            $_upData['status'] = $state;
            $_upData['ipjson'] = json_encode([]);

            //批量插入数据
            $this->mysql->getDb()->insert(MysqlTables::ACCOUNT_LOGINIP, $_upData);
            if (($_count = $this->mysql->getDb()->getAffectRows()) > 0) {
                return true;
            } else {
                return false;
            }
        }
        return true;
    }

    /**
     * 编辑登录限制ip
     * 游戏账号
     * @param array $_account
     * @return array
     */
    public function putLoginIP($username, $ip, $oldip) : bool
    {
        $_agent = $this->getTokenArray();
        $account = $this->mysql->getDb()->where('username', $username)->getOne(MysqlTables::ACCOUNT);
        if(!$this->checkRelation($account['id'])) {
            return false;
        }
        $sql = [];
        $account_row = $this->mysql->getDb()->where('account_id', $account['id'])->getOne(MysqlTables::ACCOUNT_LOGINIP);
        if($account_row) {
            $ip_arr = json_decode($account_row['ipjson'], true);
            foreach ($ip_arr as $k=>$v) {
                if($v['ip'] == $oldip) {
                    $ip_arr[$k]['ip'] = $ip;
                }
            }
            $_upData['ipjson'] = json_encode($ip_arr);
            $sql[] = $this->mysql->getDb()->where('account_id', $account['id'])->fetchSql()->update(MysqlTables::ACCOUNT_LOGINIP, $_upData);
            $this->mysql->getDb()->resetDbStatus();
            if(!empty($sql)) {
                //异步执行SQL
                TaskManager::async(new MysqlQuery($sql));
            }
        }
        return true;
    }


    /**
     * 删除登录限制ip
     * 游戏账号
     * @param array $_account
     * @return array
     */
    public function delLoginIP($username, $ip) : bool
    {
        $_agent = $this->getTokenArray();
        $account = $this->mysql->getDb()->where('username', $username)->getOne(MysqlTables::ACCOUNT);
        if(!$this->checkRelation($account['id'])) {
            return false;
        }
        $sql = [];
        $account_row = $this->mysql->getDb()->where('account_id', $account['id'])->getOne(MysqlTables::ACCOUNT_LOGINIP);
        if($account_row) {
            $ip_arr = json_decode($account_row['ipjson'], true);
            foreach ($ip_arr as $k=>$v) {
                if($v['ip'] == $ip) {
                    unset($ip_arr[$k]);
                }
            }
            $_upData['ipjson'] = json_encode($ip_arr);
            $sql[] = $this->mysql->getDb()->where('account_id', $account['id'])->fetchSql()->update(MysqlTables::ACCOUNT_LOGINIP, $_upData);
            $this->mysql->getDb()->resetDbStatus();
            if(!empty($sql)) {
                //异步执行SQL
                TaskManager::async(new MysqlQuery($sql));
            }
        }
        return true;
    }

    /**
     * 获取登录限制ip
     * 游戏账号
     * @param array $_account
     * @return array
     */
    public function getLoginIP($username) : array
    {
        $curUser = $this->getTokenObj();

        $account = $this->mysql->getDb()->where('username', $username)->getOne(MysqlTables::ACCOUNT);
        if(!$this->checkRelation($account['id'])) {
            return false;
        }
        $data = [];
        $account_row = $this->mysql->getDb()->where('account_id', $account['id'])->getOne(MysqlTables::ACCOUNT_LOGINIP);
        if($account_row) {
            $data = $account_row;
            $data['ipjson'] = json_decode($account_row['ipjson'], true);
        }
        return $data;
    }

    //获取允许代理的登录的ip
    public function getAgentLoginIp($account_id) : array
    {
        $ret = [];
        $account_row = $this->mysql->getDb()->where('account_id', $account_id)->getOne(MysqlTables::ACCOUNT_LOGINIP);
        if($account_row && $account_row['status']==1) {
            $tmp = json_decode($account_row['ipjson'], true);
            foreach($tmp as $row) {
                $ret[] = $row['ip'];
            }
        }
        return $ret;
    }

    /**
     * 添加登录限制ip
     * 游戏账号
     * @param array $_account
     * @return array
     */
    public function addLoginIP($username, $ip) : bool
    {
        $curUser = $this->getTokenObj();

        $account = $this->mysql->getDb()->where('username', $username)->getOne(MysqlTables::ACCOUNT);
        if(!$this->checkRelation($account['id'])) {
            return false;
        }
        $sql = [];
        $account_row = $this->mysql->getDb()->where('account_id', $account['id'])->getOne(MysqlTables::ACCOUNT_LOGINIP);
        if($account_row) {
            $exists = false;
            $ip_arr = json_decode($account_row['ipjson'], true);
            foreach ($ip_arr as $v) {
                if($v['ip'] == $ip) {
                    $exists = true;
                }
            }
            if(!$exists) {
                $ip_arr[] = [
                    'ip' => $ip,
                    't' => time(),
                ];
                $_upData['ipjson'] = json_encode($ip_arr);
                $sql[] = $this->mysql->getDb()->where('account_id', $account['id'])->fetchSql()->update(MysqlTables::ACCOUNT_LOGINIP, $_upData);
                $this->mysql->getDb()->resetDbStatus();
            }
            if(!empty($sql)) {
                //异步执行SQL
                TaskManager::async(new MysqlQuery($sql));
            }
        } else {
            $_upData = [];
            $_upData['account_id'] = $account['id'];
            $_upData['status'] = 2;
            $_upData['ipjson'] = json_encode([[
                'ip' => $ip,
                't' => time(),
            ]]);

            //批量插入数据
            $this->mysql->getDb()->insert(MysqlTables::ACCOUNT_LOGINIP, $_upData);
            if (($_count = $this->mysql->getDb()->getAffectRows()) > 0) {
                return true;
            } else {
                return false;
            }
        }
        return true;
    }
    
    /**
     * 修改账号对应的token
     * 游戏账号
     * @param array $_account
     * @return array
     */
    public function putAgentLogin(array $_account = []) : array
    {
        $sql = [];
        
        //当前时间
        $_login_time = time();
        
        //子账号
        if (isset($_account['virtual_vid'])) {
            //随机生成新token
            $_token = md5($_account['virtual_password'] . time() . Random::character(32));
            //db字段
            $_upData = ['token'=> $_token, 'token_expires'=> -1, 'login_time'=> $_login_time, 'update_time'=> time(), 'online'=> 1];
            //redis字段
            $_upRedisData = Helper::reFieldPre($_upData, 'virtual');
            $_upRedisData['virtual_vid'] = $_account['virtual_vid'];
            $_upRedisData['virtual_parent_id'] = $_account['virtual_parent_id'];
            
            //生成SQL - 更新db玩家账号信息
            $sql[] = $this->mysql->getDb()->where('vid', $_account['virtual_vid'])->where('password', $_account['virtual_password'])->fetchSql()->update(MysqlTables::ACCOUNT_CHILD_AGENT, $_upData);
            $this->mysql->getDb()->resetDbStatus();
            
            //更新redis玩家账号信息
            $this->models->rediscli_model->setUser($_upRedisData);
            
            //异步执行SQL
            TaskManager::async(new MysqlQuery($sql));
            
            //获取父账号
            $parentAgent = $this->getAgent(null, $_account['virtual_parent_id']);
            $_login = [
                'id'=> $_account['virtual_parent_id'],
                'vid'=> $_account['virtual_vid'],
                'username'=> $_account['virtual_username'],
                'agent'=> $parentAgent['account_agent'],
                //获取coin最新值
                'coin'=> $this->getCoinFieldValue($_account['virtual_parent_id']),
                'login_time'=> $_login_time
            ];
        }
        //主账号
        else {
            //随机生成新token
            $_token = md5($_account['account_password'].time().Random::character(32));
            //db字段
            $_upData = ['token'=> $_token, 'token_expires'=> -1, 'login_time'=> $_login_time, 'update_time'=> time(), 'online'=> 1];
            //redis字段
            $_upRedisData = Helper::reFieldPre($_upData, 'account');
            $_upRedisData['account_id'] = $_account['account_id'];
            
            //生成SQL - 更新db玩家账号信息
            $sql[] = $this->mysql->getDb()->where('id', $_account['account_id'])->where('password', $_account['account_password'])->fetchSql()->update(MysqlTables::ACCOUNT, $_upData);
            $this->mysql->getDb()->resetDbStatus();
            
            //更新redis玩家账号信息
            $this->models->rediscli_model->setUser($_upRedisData);
            
            //异步执行SQL
            TaskManager::async(new MysqlQuery($sql));
            
            $_login = [
                'id'=> $_account['account_id'],
                'vid'=> 0,
                'username'=> $_account['account_username'],
                'agent'=> $_account['account_agent'],
                //获取coin最新值
                'coin'=> $this->getCoinFieldValue($_account['account_id']),
                'login_time'=> $_login_time
            ];
        }

        // 获取当前账号的权限
        $auth = $this->mysql->getDb()->where('account_id', $_login['id'])->getOne(MysqlTables::ACCOUNT_AUTH);
        $_login['auth_id'] = $auth ? $auth['auth_id'] : '';
        
        return ['token'=> $_token, 'expires_in'=> -1, 'account'=> $_login];
    }
    
    private function _createPCode() : string
    {
        $_code = Random::number(8);
        if ($this->redis->getDb()->sAdd(RedisKey::SETS_PCODE, $_code)) {
            return $_code;
        }
        
        return $this->_createPCode();
    }
    
    /**
     * 修改账号对应的token
     * 游戏账号
     * @param array $_account
     * @return array|bool
     */
    public function putPlayerLogin(array $_account = []) : array
    {
        //当前时间
        $_login_time = time();
        
        //随机生成新token
        $_token = md5($_account['account_password'].time().Random::character(32));
        
        //db字段
        $_upData = ['token'=> $_token, 'token_expires'=> -1, 'login_time'=> $_login_time, 'update_time'=> $_login_time, 'online'=> 1];
        
        //redis字段
        $_upRedisData = Helper::reFieldPre($_upData, 'account');
        $_upRedisData['account_id'] = $_account['account_id'];
        
        //生成SQL - 更新db玩家账号信息
        $sql = [];
        $sql[] = $this->mysql->getDb()->where('pid', $_account['account_pid'])->where('password', $_account['account_password'])->fetchSql()->update(MysqlTables::ACCOUNT, $_upData);
        $this->mysql->getDb()->resetDbStatus();
        
        //更新redis玩家账号信息
        $this->models->rediscli_model->setUser($_upRedisData);

        $this->mysql->getDb()->resetDbStatus();
        
        //异步执行SQL
        TaskManager::async(new MysqlQuery($sql));

        return [
                'token'=> $_token, 
                'expires_in'=> -1, 
                'account'=> [
                        'id'=> $_account['account_id'],
                        'account'=> Helper::account_format_display($_account['account_pid']),
                        'coin'=> $this->getCoinFieldValue($_account['account_id']),
                        'login_time'=> $_login_time,
                        'svip' => isset($_account['account_svip']) ? $_account['account_svip'] : 0,
                        'svipexp' => isset($_account['account_svipexp']) ? $_account['account_svipexp'] : 0,
                        'level' => isset($_account['account_level']) ? $_account['account_level'] : 0,
                        'levelexp' => isset($_account['account_levelexp']) ? $_account['account_levelexp'] : 0,
                        'pcode' => isset($_account['account_pcode']) ? $_account['account_pcode'] : 0,
                    ]
                ];
    }
    
    public function putSoulS1Prob(string $account_id = '', string $sec = '1') : bool
    {
        $params = array(
            'st_p' => time(),
            't_p' => 1,
            'vt_p' => $sec,
            'v_p' => $sec > 1 ? 2 : 3
        );
        
        if (! $this->models->curl_model->pushPlayerProb(array($account_id), $params)) {
            Logger::getInstance()->log(PHP_EOL . ($sec > 1 ? '添加' : '移除') . '小赢概率失败' . PHP_EOL . '账号：' . $account_id . PHP_EOL . json_encode($params), 'soul-s1-fail');
            return false;
        }
        else {
            $key = RedisKey::PROB_SET_UID_ . $account_id;
            $this->redis->getDb()->setex($key, $sec, $sec > 1 ? 2 : 3);
        }
        
        return true;
    }
    
    /**
     * 清空账号对应的token
     * @return array
     */
    public function putAgentLogout()
    {
        $sql = [];
        $_agent = $this->getTokenArray();
        
        //子账号
        if (isset($_agent['virtual_vid'])) {
            //db字段
            $_upData = ['update_time'=> time(), 'token'=> null, 'token_expires'=> 0, 'online'=> 0];
            //redis字段
            $_upRedisData = Helper::reFieldPre($_upData, 'virtual');
            $_upRedisData['virtual_vid'] = $_agent['virtual_vid'];
            $_upRedisData['virtual_parent_id'] = $_agent['virtual_parent_id'];
            
            //db更新账号信息
            $sql[] = $this->mysql->getDb()->where('vid', $_agent['virtual_vid'])->fetchSql()->update(MysqlTables::ACCOUNT_CHILD_AGENT, $_upData);
            $this->mysql->getDb()->resetDbStatus();
            
            //更新redis玩家账号信息
            $this->models->rediscli_model->setUser($_upRedisData);
            
            //异步执行SQL
            TaskManager::async(new MysqlQuery($sql));
        }
        //主账号
        else {
            //db字段
            $_upData = ['update_time'=> time(), 'token'=> null, 'token_expires'=> 0, 'online'=> 0];
            //redis字段
            $_upRedisData = Helper::reFieldPre($_upData, 'account');
            $_upRedisData['account_id'] = $_agent['account_id'];
            
            //db更新账号信息
            $sql[] = $this->mysql->getDb()->where('id', $_agent['account_id'])->fetchSql()->update(MysqlTables::ACCOUNT, $_upData);
            $this->mysql->getDb()->resetDbStatus();
            
            //更新redis玩家账号信息
            $this->models->rediscli_model->setUser($_upRedisData);
            
            //异步执行SQL
            TaskManager::async(new MysqlQuery($sql));
        }
        
        return ['token'=> '', 'expires_in'=> 0];
    }
    
    /**
     * 清空账号对应的token
     * @param null|string $username
     * @param number $onlinetime
     * @return array
     */
    public function putPlayerLogout($username = null, $onlinetime = 0)
    {
        $sql = [];
        
        $_player = $this->getTokenArray();
        
        //db字段
        $_upData = ['update_time'=> time(), 'online'=> 0];
        //redis字段
        $_upRedisData = Helper::reFieldPre($_upData, 'account');
        $_upRedisData['account_id'] = $_player['account_id'];
        
        //db更新账号信息
        $sql[] = $this->mysql->getDb()->where('id', $_player['account_id'])->fetchSql()->update(MysqlTables::ACCOUNT, $_upData);
        $this->mysql->getDb()->resetDbStatus();
        
        //更新redis玩家账号信息
        $this->models->rediscli_model->setUser($_upRedisData);
        
        $_time = time();
        //添加登录日志
        $sql[] = $this->mysql->getDb()->fetchSql()->insert(MysqlTables::LOG_LOGIN_PLAYER, [
            't'=> 3,
            'account_id'=> $_player['account_id'],
            'account_parent_agent_first_id'=> $_player['account_parent_agent_first_id'],
            'account_parent_id'=> $_player['account_parent_id'],
            'account_pid'=> Helper::account_format_login($_player['account_pid']),
            'online'=> $onlinetime,
            'date_y'=> date("Y", $_time),
            'date_m'=> date("m", $_time),
            'date_d'=> date("d", $_time),
            'date_h'=> date("H", $_time),
            'create_time'=> $_time
        ]);
        $this->mysql->getDb()->resetDbStatus();
        
        //异步执行SQL
        TaskManager::async(new MysqlQuery($sql));
        
        return ['token'=> $_player['account_token'], 'expires_in'=> -1];
    }
    
    public function putOpenApiPlayerLogout(string $account = '') : bool
    {
        //踢下线10秒，并禁止10秒内不能登陆
        $Pars['ban_time'] = time()+10;
        
        if (!! $this->models->account_model->putPlayer($account, $Pars, ['ban_time'])) {
            return true;
        }
        
        return false;
    }
    
    public function getOpenGameGames() : array
    {
        $games = [];
        $_games = $this->models->curl_model->getGameLists(1);
        
        if (is_array($_games) && count($_games) && isset($_games[0]['id'])) {
            foreach ($_games as $g) {
                if ($g['id'] <= 1000) {
                    $games[] = [
                        'game_id'=> (string)$g['id'],
                        'game_name'=> (string)$g['name'],
                        'game_icon'=> Config::getInstance()->getConf('OPENAPIGAMEICON') . '/game_icon/' . 'g1'/* (string)$g['id'] */ . '.png'
                    ];
                }
            }
            return $games;
        }
        
        return [];
    }

    //退出第3方，需要把余额都带下来
    public function confirmEvolutionBackMount(string $transid, int $result) : bool
    {
        //账号信息
        $account_id = $this->getTokenObj()->account_id;
        if (!in_array($result, [1,2])) {
            return false;
        }
        //poly 只有poly 有这个
        if (Config::getInstance()->getConf('APPTYPE') == '2') {
            $this->updateTranscationOrder($transid, $account_id, [
                'finish_status' => $result, 
                'finish_time' => time(),
            ]); //下分失败流水
                   
            
            return true;
        }

        return false;
    }

    //退出第3方，需要把余额都带下来
    public function postEvolutionEdb(string $ipAddr = '') : array
    {
        //账号信息
        $account_id = $this->getTokenObj()->account_id;
        $account_pid = $this->getTokenObj()->account_pid;
        $result = [];
        //BB
        if (Config::getInstance()->getConf('APPTYPE') == '1') {

            $ecr_url    = Config::getInstance()->getConf('JBGAME.HOST') ; //http://api.jdb711.com/apiRequest.do
            $ecr_dc     = Config::getInstance()->getConf('JBGAME.DC');//D9
            $ecr_parent = Config::getInstance()->getConf('JBGAME.AGENT');//d9ag
            $ecr_key    = Config::getInstance()->getConf('JBGAME.KEY');//d9ag
            $ecr_iv     = Config::getInstance()->getConf('JBGAME.IV');//d9ag

            $now = round(microtime(true)*1000);
            $uid =  $account_pid;
            $json_data = [
                'action' => 15,
                'ts'     => $now,
                'parent' => $ecr_parent,
                'uid'    => $uid,
            ];
            $jsonString  = json_encode($json_data);
            $encryptData = Helper::encrypt($ecr_key, $ecr_iv, $jsonString);
            $post_data   = ['dc'=>$ecr_dc, 'x'=>$encryptData];

            $result['timeout']['reg']['S'] = microtime();
            $ecrResult = Helper::is_json_str($this->models->curl_model->simple_post($ecr_url, $post_data));

            $result['timeout']['reg']['E'] = microtime();
            if (!isset($ecrResult['status']) || $ecrResult['status'] != '0000') {
                $result['eTransID'] = '-2';
                $result['withdraw'] = Helper::format_money('0');
                return $result;
            }
            $balance = $ecrResult['data'][0]['balance'];
            if(!$balance) {
                $result['eTransID'] = '0';
                $result['withdraw'] = Helper::format_money('0');
                return $result;
            }

            $now = round(microtime(true)*1000);
            $serialNo = Random::character(10);
            $json_data = [
                'action' => 19,
                'ts'     => $now,
                'parent' => $ecr_parent,
                'uid'    => $uid,
                'amount' => (-1) * $balance,
                'serialNo' => $serialNo,
                'remark' => 'withdraw', //备注
                'allCashOutFlag' => '1',
            ];
            $jsonString  = json_encode($json_data);
            $encryptData = Helper::encrypt($ecr_key, $ecr_iv, $jsonString);
            $post_data   = ['dc'=>$ecr_dc, 'x'=>$encryptData];

            $result['timeout']['reg']['S'] = microtime();
            $ecrResult = Helper::is_json_str($this->models->curl_model->simple_post($ecr_url, $post_data));

            $result['timeout']['reg']['E'] = microtime();
            if (!isset($ecrResult['status']) || $ecrResult['status'] != '0000') {
                $this->setErrCode(2000000);
                $this->setErrMsg('下分失败', true);
                return [];
            }
            $result['eTransID'] = $serialNo;
            $result['withdraw'] = Helper::format_money($balance);
            return $result;
        }
        //POLY
        elseif (Config::getInstance()->getConf('APPTYPE') == '2') {
            //请求获取E余额
            $rwaUrl = Config::getInstance()->getConf('EVOLUTION.HOST') . '/api/ecashier?cCode=RWA&ecID=' . Config::getInstance()->getConf('EVOLUTION.KEY') . '&euID='.$account_pid.'&output=0';
            $rwaResult = $this->models->curl_model->simple_get($rwaUrl,[],[]);
            $rwaResult = Helper::is_json_str($rwaResult);
            //获取E余额成功
            if (isset($rwaResult['userbalance']['result']) && $rwaResult['userbalance']['result'] == 'Y' && isset($rwaResult['userbalance']['tbalance'])) {
                //E余额不为0
                if ($rwaResult['userbalance']['tbalance'] > 0) {
                    //E下分
                    $eTransID = Random::character(16);
                    $edbUrl = Config::getInstance()->getConf('EVOLUTION.HOST') . '/api/ecashier?cCode=EDB&ecID=' . Config::getInstance()->getConf('EVOLUTION.KEY') . '&euID='.$account_pid.'&amount='.$rwaResult['userbalance']['tbalance'].'&eTransID='.$eTransID.'&output=0';

                    //添加交互流水日志
                    $this->addTranscationOrder($eTransID, $account_id, $rwaResult['userbalance']['tbalance'], 0, 0, 2, 1);

                    $edbResult = $this->models->curl_model->simple_get($edbUrl,[],[]);
                    $edbResult = Helper::is_json_str($edbResult);
                    //E下分失败
                    if (!isset($edbResult['transfer']) || !isset($edbResult['transfer']['result']) || $edbResult['transfer']['result'] != 'Y') {
                        $result['eTransID'] = '-1';
                        $result['withdraw'] = Helper::format_money('0');

                        $this->updateTranscationOrder($eTransID, $account_id, [
                            'update_status' => 2, 
                            'update_time' => time(),
                        ]); //下分失败流水
                    }
                    //E下分成功
                    else {
                        $result['eTransID'] = $eTransID;
                        $result['withdraw'] = Helper::format_money( $rwaResult['userbalance']['tbalance'] );

                        $this->updateTranscationOrder($eTransID, $account_id, [
                            'update_status' => 1, 
                            'update_time'   => time(),
                        ]); //下分成功流水
                    }
                }
                //E余额为0
                else {
                    $result['eTransID'] = '0';
                    $result['withdraw'] = Helper::format_money('0');
                }
            }
            //获取E余额失败
            else {
                $result['eTransID'] = '-2';
                $result['withdraw'] = Helper::format_money('0');
            }
            
            return $result;
        }

        return [];
    }

    private function getBBEovName($account_id) {
        $ecr_env     = Config::getInstance()->getConf('JBGAME.ENV');
        return 'B'.$ecr_env.$account_id;
    }

    private function getCountryCode() {
        $area_code = Config::getInstance()->getConf('AREACODE');
        $area_code = intval($area_code);
        $country = 'MY'; //马来
        if($area_code == 2) {
            $country = 'SG'; //新加坡
        } elseif ($area_code == 3) {
            $country = 'BN'; //文莱
        } elseif ($area_code == 4) {
            $country = 'TH'; //泰国
        }
        return $country;
    }

    //添加第3方的流水日志(上分不用补单,游戏服已补; 下分可能要补单)
    private function addTranscationOrder($eTransID, $account_id, $amount, $game_identification, $result, $type=1, $appid = 1, $finished=false) {
        $time = time();
        $sql = [];
        $data = [
            'appid'        => $appid,
            'type'         => $type,
            'transid'      => $eTransID,
            'account_id'   => $account_id,
            'coin'         => $amount,
            'create_time'  => $time,
            'update_time'  => $time,
            'update_status'=> $result,
            'game_identification'=> $game_identification
        ];
        if($finished) {
            $data['finish_time']   = $data['update_time'];
            $data['finish_status'] = 1;
        }
        $sql[] = $this->mysql->getDb()->fetchSql()->insert(MysqlTables::TRANSACTION_ORDER, $data);
        file_put_contents('/tmp/testevo.log', json_encode($sql) . "\r\n", FILE_APPEND);
        $this->mysql->getDb()->resetDbStatus();
        TaskManager::async(new MysqlQuery($sql)); //异步执行SQL
        return true;
    }

    //更新第3方的流水日志(下分可能要补单)
    private function updateTranscationOrder($eTransID, $account_id, $data) {
        $sql = [];
        $sql[] = $this->mysql->getDb()->fetchSql()->where('transid', $eTransID)->where('account_id', $account_id)->update(MysqlTables::TRANSACTION_ORDER, $data);
        $this->mysql->getDb()->resetDbStatus();
        TaskManager::async(new MysqlQuery($sql)); //异步执行SQL
        return true;
    }
    
    public function getEvolutionGameUri(string $game_identification = '0', string $coin = '0.00', string $ipAddr = '', string $evoAccount='') : array
    {
        //账号信息
        $account_id = $this->getTokenObj()->account_id;
        $account_pid = $this->getTokenObj()->account_pid;
        //上分额度
        $ecrAmount = $coin;
        
        $result = [];
        //BB
        if (Config::getInstance()->getConf('APPTYPE') == '1') {

            $ecr_url    = Config::getInstance()->getConf('JBGAME.HOST') ; //http://api.jdb711.com/apiRequest.do
            $ecr_dc     = Config::getInstance()->getConf('JBGAME.DC');//D9
            $ecr_parent = Config::getInstance()->getConf('JBGAME.AGENT');//d9ag
            $ecr_key    = Config::getInstance()->getConf('JBGAME.KEY');
            $ecr_iv     = Config::getInstance()->getConf('JBGAME.IV');
            
            $uid =  $account_pid;
            //是否要创建账号, 没有传第三方账号，表示没有
            if(empty($evoAccount)) {
                $now = round(microtime(true)*1000);
                $json_data = [
                    'action' => 12,
                    'ts' => $now,
                    'parent' => $ecr_parent,
                    'uid'  => $uid,
                    'name' => $this->getBBEovName($uid),
                    'credit_allocated' => 0, //初始账号为0分
                ];
                $jsonString  = json_encode($json_data);
                $encryptData = Helper::encrypt($ecr_key, $ecr_iv, $jsonString);
                $post_data   = ['dc'=>$ecr_dc, 'x'=>$encryptData];

                $result['timeout']['reg']['S'] = microtime();
                $ecrResult = Helper::is_json_str($this->models->curl_model->simple_post($ecr_url, $post_data));
                $result['timeout']['reg']['E'] = microtime();
                if (!isset($ecrResult['status']) || $ecrResult['status'] != '0000') {
                    if($ecrResult['status'] != '7602') { //该账号已经创建
                        $this->setErrCode(2000000);
                        $this->setErrMsg('账号创建失败', true);
                        return [];
                    }
                    
                }
            }
            //login
            $now = round(microtime(true)*1000);
            $json_data = [
                'action' => 11,
                'ts' => $now,
                'uid'  => $uid,
                'lang' => 'ch',
                'isAPP' => true,
            ];
            $jsonString  = json_encode($json_data);
            $encryptData = Helper::encrypt($ecr_key, $ecr_iv, $jsonString);
            $post_data   = ['dc'=>$ecr_dc, 'x'=>$encryptData];
            $result['timeout']['reg']['S'] = microtime();

            $ecrResult = Helper::is_json_str($this->models->curl_model->simple_post($ecr_url, $post_data));
            $result['timeout']['reg']['E'] = microtime();
            if (!isset($ecrResult['status']) || $ecrResult['status'] != '0000') {
                $this->setErrCode(2000000);
                $this->setErrMsg('获取登录token失败', true);
                return [];
            }
            $result['uri'] = $ecrResult['path'];
            $result['euid']= $account_pid;

            return $result;
        }
        //POLY
        elseif (Config::getInstance()->getConf('APPTYPE') == '2') {
            //上分
            $eTransID = Random::character(16);
            if ($ecrAmount > 0) {
                //上分请求URL
                $ecrUrl = Config::getInstance()->getConf('EVOLUTION.HOST')
                . '/api/ecashier?cCode=ECR&ecID='
                . Config::getInstance()->getConf('EVOLUTION.KEY')
                . '&euID=' . $account_pid
                . '&amount=' . $ecrAmount
                . '&eTransID=' . $eTransID
                . '&createuser=Y&output=0';
                $result['timeout']['ECR']['S'] = microtime();
                //上分请求操作
                $ecrResult = $this->models->curl_model->simple_get($ecrUrl,[],[]);
                $result['timeout']['ECR']['E'] = microtime();
                //上分请求结果
                $ecrResult = Helper::is_json_str($ecrResult);
                //上分失败，终止启动
                if (! isset($ecrResult['transfer']['result']) || $ecrResult['transfer']['result'] != 'Y') {
                    $this->setErrCode(170002);
                    $this->setErrMsg('Evolution上分失败');

                    //添加交互流水日志
                    $this->addTranscationOrder($eTransID, $account_id, $ecrAmount, $game_identification, 2, 1, 1, true);
                    return [];
                } 
                //添加交互流水日志
                $this->addTranscationOrder($eTransID, $account_id, $ecrAmount, $game_identification, 1, 1, 1, true);
            }
            
            //获取H5游戏链接
            $postUrl = Config::getInstance()->getConf('EVOLUTION.HOST')
            . '/ua/v1/'
            . Config::getInstance()->getConf('EVOLUTION.KEY')
            . '/'
            . Config::getInstance()->getConf('EVOLUTION.TOKEN');

            $prefix = 'P@';
            if(Config::getInstance()->getConf('EVOLUTION.ENV') == 'TEST') {
                $prefix = 'T@';
            }

            
            $result['timeout']['H5']['S'] = microtime();
            //发送请求
            $country = $this->getCountryCode();
            $currency = Config::getInstance()->getConf('EVOLUTION.CURRENCY');

            $post_data = [
                "uuid" => $account_pid,
                "player" => [
                    "id" =>  $account_pid,
                    "update" => true,
                    "firstName" => "Game",
                    "lastName" => "Player",
                    "nickname" => $prefix.$account_pid,
                    "country" => $country,
                    "language" => "en",
                    "currency" => $currency,
                    "session" => [
                        "id" => "session.id.".$account_pid,
                        "ip" => $ipAddr,
                    ],
                ],
                "config"=>[
                    "brand" => [
                        "id" => "1",
                        "skin" => "1"
                    ],
                    "channel" => [
                        "wrapped" => false,
                        "mobile" => false
                    ],
                ]
            ];
            
            $result = $this->models->curl_model->simple_post(
                    $postUrl,
                    json_encode($post_data),
                    ['HTTPHEADER'=> ['Content-Type: text/plain']]
                );
            $result = Helper::is_json_str($result);
            $result['timeout']['H5']['E'] = microtime();
            //获取失败
            if (! isset($result['entryEmbedded']) || ! $result['entryEmbedded']) {
                return [];
            }
            //上分成功，并且启动成功，需要传递上分订单号
            $this->mysql->getDb()->where('game_identification', $game_identification)->update(MysqlTables::COINS_PLAYER, ['extent1'=> $eTransID]);
            //H5游戏链接信息
            $result['eTransID'] = $eTransID;
            $result['uri']      = $result['entryEmbedded'];
            $result['euid']     = $account_pid;
            
            return $result;
        }
        
        return [];
    }

    //往第3方充值
    public function recharge2Evolution(string $game_identification = '0', string $coin = '0.00', string $ipAddr = '') : array
    {
        //账号信息
        $account_id = $this->getTokenObj()->account_id;
        $account_pid = $this->getTokenObj()->account_pid;
        $result = [];
        //BB
        if (Config::getInstance()->getConf('APPTYPE') == '1') {

            if(!$coin) {
//                 $this->setErrCode(2000000);
//                 $this->setErrMsg('不用上分', true);
                return [];
            }
            $ecr_url    = Config::getInstance()->getConf('JBGAME.HOST') ; //http://api.jdb711.com/apiRequest.do
            $ecr_dc     = Config::getInstance()->getConf('JBGAME.DC');//D9
            $ecr_parent = Config::getInstance()->getConf('JBGAME.AGENT');//d9ag
            $ecr_key    = Config::getInstance()->getConf('JBGAME.KEY');
            $ecr_iv     = Config::getInstance()->getConf('JBGAME.IV');

            $now = round(microtime(true)*1000);
            $serialNo = Random::character(10);
            $json_data = [
                'action' => 19,
                'ts'     => $now,
                'parent' => $ecr_parent,
                'uid'    => $account_pid,
                'amount' => $coin,
                'serialNo' => $serialNo,
                'remark' => 'rechare', //备注
            ];
            $jsonString  = json_encode($json_data);
            $encryptData = Helper::encrypt($ecr_key, $ecr_iv, $jsonString);
            $post_data   = ['dc'=>$ecr_dc, 'x'=>$encryptData];

            $result['timeout']['reg']['S'] = microtime();
            $ecrResult = Helper::is_json_str($this->models->curl_model->simple_post($ecr_url, $post_data));
            $result['timeout']['reg']['E'] = microtime();
            if (!isset($ecrResult['status']) || $ecrResult['status'] != '0000') {
                $this->setErrCode(2000000);
                $this->setErrMsg('上分失败', true);
                return [];
            }

            $result['serialNo'] = $serialNo; //输入的交易序号
            $result['pid'] = $ecrResult['pid'];//交易流水号
            //上分成功，需要传递上分订单号
            $this->mysql->getDb()->where('game_identification', $game_identification)->update(MysqlTables::COINS_PLAYER, ['extent1'=> $serialNo]);
            return $result;
        }
        //POLY
        elseif (Config::getInstance()->getConf('APPTYPE') == '2') {
            if ($coin > 0) {
                //上分
                $eTransID = Random::character(16);
                //上分请求URL
                $ecrUrl = Config::getInstance()->getConf('EVOLUTION.HOST')
                . '/api/ecashier?cCode=ECR&ecID='
                . Config::getInstance()->getConf('EVOLUTION.KEY')
                . '&euID=' . $account_pid
                . '&amount=' . $coin
                . '&eTransID=' . $eTransID
                . '&createuser=N&output=0';
                $result['timeout']['ECR']['S'] = microtime();
                //上分请求操作
                $ecrResult = $this->models->curl_model->simple_get($ecrUrl,[],[]);
                
                //上分请求结果
                $ecrResult = Helper::is_json_str($ecrResult);
                $result['timeout']['ECR']['E'] = microtime();
                
                //上分失败，终止启动
                if (! isset($ecrResult['transfer']['result']) || $ecrResult['transfer']['result'] != 'Y') {
                    $this->setErrCode(170002);
                    $this->setErrMsg('Evolution上分失败');

                    //添加交互流水日志, 上分只记录流水
                    $this->addTranscationOrder($eTransID, $account_id, $coin, $game_identification, 2, 1, 1, true);
                    return [];
                }
                //添加交互流水日志, 上分只记录流水
                $this->addTranscationOrder($eTransID, $account_id, $coin, $game_identification, 1, 1, 1, true);

                //上分成功，并且启动成功，需要传递上分订单号
                $this->mysql->getDb()->where('game_identification', $game_identification)->update(MysqlTables::COINS_PLAYER, ['extent1'=> $eTransID]);
            }

            $result['eTransID'] = $eTransID;
            return $result;
        }
        
        return [];
    }
    
    public function getOpenGameUri(string $gameid = '', string $account = '', string $ipAddr = '') : string
    {
        $_login = [];
        
        //获取游戏ID列表
        $gameids = array_column($this->models->curl_model->getGameLists(1), 'id');
        //判断gameid参数
        if (! in_array($gameid, $gameids)) {
            $this->setErrMsg('gameid不存在', true);
            return '';
        }
        
        //账号匹配
        if (!! ($_account = $this->models->account_model->getPlayerCheckPwd($account, '', $ipAddr, '', true)) &&
            !! ($_account['account_ip'] = $ipAddr)) {
                if (! ($_login = $this->models->account_model->putPlayerLogin($_account))) {
                    $this->setErrMsg('登录失败', true);
                    return '';
                }
        } else {
            $this->setErrMsg('账号匹配失败', true);
            return '';
        }
        
        return $this->redis->getDb()->get(RedisKey::OPENAPI_GAMEURL) . '/?' . 'gameid=' . $gameid . '&token=' . $_login['token'] . '&signstr=' . Random::character(32);
    }
    
    /**
     * 获取当前玩家账号
     * @return array|bool
     */
    public function getCurAgent()
    {
        $result = [];
        $curUser = $this->getTokenObj();
        
        //子账号
        if (isset($curUser->virtual_vid)) {
            //获取主账号
            $fieldstrs = $this->getTableFields(MysqlTables::ACCOUNT, ['a', 'account_', ',']);
            $_sql = "
                    SELECT
                        {$fieldstrs}
                    FROM
                        account as a
                    WHERE
                        a.agent>0
                        AND a.id=".$curUser->virtual_parent_id."
                    LIMIT 0,1
                    ";
            //查询数据
            $_r = $this->mysql->getDb()->rawQuery($_sql);
            
            if (! isset($_r[0]) || ! $_r[0]) {
                $this->setErrCode(1002);
                $this->setErrMsg('账号不存在', true);
                
                return false;
            }
            
            $parent_agent = array_shift($_r);
            
            //获取子账号
            $fieldstrs = $this->getTableFields(MysqlTables::ACCOUNT_CHILD_AGENT, ['v', 'virtual_', ',']);
            $_sql = "
                    SELECT
                        {$fieldstrs}
                    FROM
                        account_child_agent as v
                    WHERE
                        v.vid=".$curUser->virtual_vid."
                        AND v.parent_id=".$parent_agent['account_id']."
                    LIMIT 0,1
                    ";
            //查询数据
            $_r = $this->mysql->getDb()->rawQuery($_sql);
            
            if (! isset($_r[0]) || ! $_r[0]) {
                $this->setErrCode(1002);
                $this->setErrMsg('账号不存在', true);
                
                return false;
            }
            
            $virtual_agent = array_shift($_r);
            
            $result = array_merge($parent_agent, $virtual_agent);
        }
        //主账号
        else {
            $fieldstrs = $this->getTableFields(MysqlTables::ACCOUNT, ['a', 'account_', ',']);
            $_sql = "
                    SELECT
                        {$fieldstrs}
                    FROM
                        account as a
                    WHERE
                        a.agent>0
                        AND a.id=".$curUser->account_id."
                    LIMIT 0,1
                    ";
            //查询数据
            $_r = $this->mysql->getDb()->rawQuery($_sql);
            
            if (! isset($_r[0]) || ! $_r[0]) {
                $this->setErrCode(1002);
                $this->setErrMsg('账号不存在', true);
                
                return false;
            }
            
            $result = array_shift($_r);
        }
        
        return $result;
    }
    
    /**
     * 获取当前玩家账号
     * @return array|bool
     */
    public function getCurPlayer()
    {
        $result = [];
        
        $fieldstrs = $this->getTableFields(MysqlTables::ACCOUNT, ['a', 'account_', ','], [
            'id','pid',
            'coin','pprofit_balance','pprofit_total','pcode',
            'vip',
            'create_time','login_time'
        ]);
        
        $_sql = "
                SELECT
                    {$fieldstrs}
                FROM
                    account as a
                WHERE
                    a.agent=0
                    AND a.id=".$this->getTokenObj()->account_id."
                LIMIT 0,1
                ";
        //查询数据
        $_r = $this->mysql->getDb()->rawQuery($_sql);
        
        if (! isset($_r[0]) || ! $_r[0]) {
            $this->setErrCode(1002);
            $this->setErrMsg('玩家账号不存在', true);
            
            return [];
        }
        
        $result = array_shift($_r);
        
        return $result;
    }
    
    /**
     * 设置密码
     * 代理账号
     * @param string $oldpassword
     * @param string $newpassword
     * @return bool
     */
    public function putAgentPassword($oldpassword = '', $newpassword = '') : bool
    {
        $_needUpData = ['update_time'=> time()];
        $curUser = $this->getTokenObj();
        
        //原密码匹配正确
        if (!! ($_agent = $this->getAgentCheckPwd(isset($curUser->virtual_username) ? $curUser->virtual_username : $curUser->account_username, $oldpassword))) {
            //子账号
            if (isset($_agent['virtual_vid'])) {
                //db字段
                $_needDbData = ['update_time'=> time(), 'token'=> null, 'token_expires'=> 0, 'online'=> 0];
                //清空token
                $_needDbData['salt'] = $salt = mt_rand(100000,999999);
                $_needDbData['password'] = md5($_agent['virtual_username'].$newpassword.$salt);
                
                //redis字段
                $_upRedisData = Helper::reFieldPre($_needDbData, 'virtual');
                $_upRedisData['virtual_vid'] = $_agent['virtual_vid'];
                $_upRedisData['virtual_parent_id'] = $_agent['virtual_parent_id'];
                
                //db更新账号信息
                $sql[] = $this->mysql->getDb()->where('vid', $_agent['virtual_vid'])->fetchSql()->update(MysqlTables::ACCOUNT_CHILD_AGENT, $_needDbData);
                $this->mysql->getDb()->resetDbStatus();
                
                //更新redis玩家账号信息
                $this->models->rediscli_model->setUser($_upRedisData);
                
                //删除玩家账号token
                $this->redis->getDb()->hDel(RedisKey::USERS_."usertoken", $_agent['virtual_token']);
                
                //异步执行SQL
                TaskManager::async(new MysqlQuery($sql));
            }
            //主账号
            else {
                //db字段
                $_needDbData = ['update_time'=> time(), 'token'=> null, 'token_expires'=> 0, 'online'=> 0];
                //清空token
                $_needDbData['salt'] = $salt = mt_rand(100000,999999);
                $_needDbData['password'] = md5($_agent['account_username'].$newpassword.$salt);
                
                //redis字段
                $_upRedisData = Helper::reFieldPre($_needDbData, 'account');
                $_upRedisData['account_id'] = $_agent['account_id'];
                
                //db更新账号信息
                $sql[] = $this->mysql->getDb()->where('id', $_agent['account_id'])->fetchSql()->update(MysqlTables::ACCOUNT, $_needDbData);
                $this->mysql->getDb()->resetDbStatus();
                
                //更新redis玩家账号信息
                $this->models->rediscli_model->setUser($_upRedisData);
                
                //删除玩家账号token
                $this->redis->getDb()->hDel(RedisKey::USERS_."usertoken", $_agent['account_token']);
                
                //异步执行SQL
                TaskManager::async(new MysqlQuery($sql));
            }
        }
        //匹配错误
        else {
            $this->setErrMsg('原密码不正确');
            return false;
        }
        
        return true;
    }
    
    public function putAgentPasswordX(string $username = '', string $oldpassword = '', string $newpassword = '') : bool
    {
        $_needUpData = ['update_time'=> time()];
        
        $curUser = $this->getAgent($username, 0, false, false, false); //从redis缓存取账号信息
        
        //原密码匹配正确
        if (!! ($_agent = $this->getAgentCheckPwd(isset($curUser['virtual_username']) && $curUser['virtual_username'] ? $curUser['virtual_username'] : $curUser['account_username'], $oldpassword))) {
            //子账号
            if (isset($_agent['virtual_vid'])) {
                //db字段
                $_needDbData = ['update_time'=> time(), 'token'=> null, 'token_expires'=> 0, 'online'=> 0];
                //清空token
                $_needDbData['salt'] = $salt = mt_rand(100000,999999);
                $_needDbData['password'] = md5($_agent['virtual_username'] . $newpassword . $salt);
                
                //redis字段
                $_upRedisData = Helper::reFieldPre($_needDbData, 'virtual');
                $_upRedisData['virtual_vid'] = $_agent['virtual_vid'];
                $_upRedisData['virtual_parent_id'] = $_agent['virtual_parent_id'];
                
                //db更新账号信息
                $sql[] = $this->mysql->getDb()->where('vid', $_agent['virtual_vid'])->fetchSql()->update(MysqlTables::ACCOUNT_CHILD_AGENT, $_needDbData);
                $this->mysql->getDb()->resetDbStatus();
                
                //更新redis玩家账号信息
                $this->models->rediscli_model->setUser($_upRedisData);
                
                //删除玩家账号token
                $this->redis->getDb()->hDel(RedisKey::USERS_."usertoken", $_agent['virtual_token']);
                
                //异步执行SQL
                TaskManager::async(new MysqlQuery($sql));
            }
            //主账号
            else {
                //db字段
                $_needDbData = ['update_time'=> time(), 'token'=> null, 'token_expires'=> 0, 'online'=> 0];
                //清空token
                $_needDbData['salt'] = $salt = mt_rand(100000,999999);
                $_needDbData['password'] = md5($_agent['account_username'] . $newpassword . $salt);
                
                //redis字段
                $_upRedisData = Helper::reFieldPre($_needDbData, 'account');
                $_upRedisData['account_id'] = $_agent['account_id'];
                
                //db更新账号信息
                $sql[] = $this->mysql->getDb()->where('id', $_agent['account_id'])->fetchSql()->update(MysqlTables::ACCOUNT, $_needDbData);
                $this->mysql->getDb()->resetDbStatus();
                
                //更新redis玩家账号信息
                $this->models->rediscli_model->setUser($_upRedisData);
                
                //删除玩家账号token
                $this->redis->getDb()->hDel(RedisKey::USERS_."usertoken", $_agent['account_token']);
                
                //异步执行SQL
                TaskManager::async(new MysqlQuery($sql));
            }
        }
        //匹配错误
        else {
            $this->setErrMsg('原密码不正确');
            return false;
        }
        
        return true;
    }
    
    public function postCaptchaEmail(string $username = '', string $email = '') : bool
    {
        if(! ($account = $this->models->rediscli_model->getUser($username))) {
            $this->setErrCode(160004);
            $this->setErrMsg('账号与邮箱不匹配', true);
            return false;
        } elseif ($account['account_pemail'] != $email) {
            $this->setErrCode(160004);
            $this->setErrMsg('账号与邮箱不匹配2', true);
            return false;
        }
        
        $CAPTCHA = Random::number(6);
        $this->redis->getDb()->setEx(RedisKey::ACCOUNT_CAPTCHA_EMAIL_ . $CAPTCHA, 3600, $account['account_pusername'] . '|||' . $email);
        
        //在此处发送邮件
        /* require EASYSWOOLE_ROOT . '/App/Tools/PHPMailer/Exception.php';
        require EASYSWOOLE_ROOT . '/App/Tools/PHPMailer/PHPMailer.php';
        require EASYSWOOLE_ROOT . '/App/Tools/PHPMailer/SMTP.php';
        $mail = new PHPMailer();
        $body = $CAPTCHA;
        $mail->IsSMTP(); // telling the class to use SMTP
        $mail->Host = "mail.gmail.com"; // SMTP server
        $mail->SMTPDebug = 2; // enables SMTP debug information (for testing)
        $mail->SMTPAuth = true; // enable SMTP authentication
        $mail->SMTPSecure = "ssl"; // sets the prefix to the servier
        $mail->Host = "smtp.gmail.com"; // sets GMAIL as the SMTP server
        $mail->Port = 465; // set the SMTP port for the GMAIL server
        $mail->Username = "xiongyuanyuan166@gmail.com"; // GMAIL username
        $mail->Password = "QQ8351qq"; // GMAIL password
        $mail->SetFrom('xiongyuanyuan166@gmail.com', 'BigBang');
        //$mail->AddReplyTo("xiongyuanyuan166@gmail.com","BigBang");
        $mail->Subject = "Verification Code";
        //$mail->AltBody = "To view the message, please use an HTML compatible email viewer!"; // optional, comment out and test
        $mail->MsgHTML($body);
        $mail->CharSet = "utf-8"; // 这里指定字符集！
        $address = $email;
        $mail->AddAddress($address, "Account");
        
        if(!$mail->Send()) {
            echo "<pre>";
            print_r( "Mailer Error: " . $mail->ErrorInfo );
            echo "</pre>".PHP_EOL;
        } else {
            echo "<pre>";
            print_r( "Message sent!" );
            echo "</pre>".PHP_EOL;
        }*/
        
        return true;
    }
    
    public function postRegisterPlayer(array $user = []) : array
    {
        $username = $pwdmd5 = $email = $pcode = '';
        extract($user);
        
        if ($this->_getExistPlayerUsername($username)) {
            $this->setErrCode(160001);
            $this->setErrMsg('用户名已经存在', true);
            return [];
        }
        
        if ($this->_getExistPlayerEmail($email)) {
            $this->setErrCode(160002);
            $this->setErrMsg('Email已经存在', true);
            return [];
        }
        
        //判断邀请者
//        if(! ($inviter = $this->models->rediscli_model->getUser("_pcode_" . $pcode))) {
//            $this->setErrCode(160003);
//            $this->setErrMsg('邀请码不存在', true);
//            return [];
//        }
        
        //接口需要返回的新建玩家账号列表
        $accounts = [];
        //新玩家账号id数组集合
        $_pids = [];
        //入redis新玩家账号信息集合
        $_redisQueue = [];
        
        //开启事务
        $this->mysql->getDb()->startTransaction();
        
        //邀请者推广员级别更新 - DB
        //如果邀请者账号ppromoters字段为0，表示此账号是后台系统生成，并且从未邀请过其它人注册，所以需要设置此账号为一级推广员，即ppromoters=1
//        if (! $inviter['account_ppromoters']) {
//            $updateInviterAccountPpromoters = ['ppromoters'=> '1', 'update_time'=> time()];
//            $this->mysql->getDb()->where('id', $inviter['account_id'])->update(MysqlTables::ACCOUNT, $updateInviterAccountPpromoters);
//            if (! $this->mysql->getDb()->getAffectRows()) {
//                $this->mysql->getDb()->rollback();
//                $this->setErrCode(160010);
//                $this->setErrMsg('DB更新（邀请者的推广员级别）错误', true);
//                return [];
//            }
//            $updateInviterAccountPpromoters['id'] = $inviter['account_id'];
//        } elseif ($inviter['account_ppromoters'] == 1) {
//            //后台添加收就设置为1级推广员了
//            $updateInviterAccountPpromoters = ['ppromoters'=> '1', 'update_time'=> time()];
//            $updateInviterAccountPpromoters['id'] = $inviter['account_id'];
//        }
        
        //创建玩家账号
        $salt =  mt_rand(1,9) . Random::number(5);
        $pid = $this->_randPlayerPID();
        $password = md5($pid . $pwdmd5 . $salt);
        $psecurity_pwd = md5($pid . $pwdmd5); //安全支付密码
        $agent = 0;
        
        $newUser = [
            'parent_id'=> $inviter['account_id'],
            'parent_agent_first_id'=> $inviter['account_parent_agent_first_id'],
            'pid'=> $pid,
            //因为此账号是被邀请来注册的，所以此账号自动成为二级推广员，即ppromoters=2
            'ppromoters'=> '2',
            'pusername'=> $username,
            'pemail'=> $email,
            'password'=> $password,
            'psecurity_pwd'=> $psecurity_pwd,
            'salt'=> $salt,
            'group_id'=> 0,
            'agent'=> $agent,
            'create_time'=> time()
        ];
        
        // DB Insert 新玩家账号
        $this->mysql->getDb()->insert(MysqlTables::ACCOUNT, $newUser);
        
        //新玩家账号ID
        if (! ($last_id = $_pids[] = $this->mysql->getDb()->getInsertId())) {
            $this->mysql->getDb()->rollback();
            $this->setErrCode(160007);
            $this->setErrMsg('DB新增账号错误', true);
            return [];
        }
        
        //将新玩家账号信息放入redis预队列
        $_redisQueue[] = ['uid'=> $last_id, 'pid'=> $pid, 'coin'=> Helper::format_money(0)];
        
        //新玩家PID
        $accounts[] = Helper::account_format_login($pid);
        if (! $accounts) {
            return [];
        }
        
        //维护树结构
//        if (! $this->_insertAccountTree($inviter['account_id'], $_pids, $agent)) {
//            $this->mysql->getDb()->rollback();
//            $this->setErrCode(160008);
//            $this->setErrMsg('DB新增（树关系）错误', true);
//            return [];
//        }
        
        //保存账号关联关系
        //prelation_parents为此账号的所有上级的account_id集合，一共5级，其中自己的第1级
//        if (!! ($parents = $this->mysql->getDb()->join('account as a', 't.ancestor_id=a.id', 'left')
//        ->where('t.descendant_id', $last_id)->where('t.descendant_agent', 0)
//        ->where('t.ancestor_h', 0, '>')->where('t.ancestor_h', 5, '<')->where('a.agent', 0)
//        ->orderBy('t.ancestor_h', 'ASC')
//        ->get('account_tree as t', null, 't.ancestor_id,t.ancestor_h'))) {
//            $ps = [];
//            //把自己放到第1级
////            $ps[1] = json_decode($inviter['account_prelation_parents'], true);
//            $ps[1] = ['account_id'=> $last_id, 'height'=> 1];
//            foreach ($parents as $p) {
//                $ps[intval($p['ancestor_h'] + 1)] = ['account_id'=> $p['ancestor_id'], 'height'=> intval($p['ancestor_h'] + 1)];
//            }
//            $this->mysql->getDb()->where('id', $last_id)->update(MysqlTables::ACCOUNT, ['prelation_parents'=> json_encode($ps)]);
//        } else {
//            $this->mysql->getDb()->rollback();
//            $this->setErrCode(160009);
//            $this->setErrMsg('DB更新账号错误', true);
//            return [];
//        }
        
        //提交事务
        $this->mysql->getDb()->commit();
        
        //邀请者推广员级别更新 - redis
//        if (isset($updateInviterAccountPpromoters)) {
//            $this->models->rediscli_model->setUser(Helper::reFieldPre($updateInviterAccountPpromoters, 'account'));
//        }
        
        //将username加入到redis集合中
        $this->models->rediscli_model->getDb()->sAdd(RedisKey::SETS_USERNAME, $username);
        //将email加入到redis集合中
        $this->models->rediscli_model->getDb()->sAdd(RedisKey::SETS_USEREMAIL, $email);
        
        //将新玩家账号信息放入redis队列
        foreach ($_redisQueue as $_r_u) {
            $this->models->rediscli_model->getDb()->lPush(RedisKey::LOGS_PLAYERS, json_encode($_r_u, JSON_UNESCAPED_UNICODE|JSON_UNESCAPED_SLASHES));
        }
        
        return $accounts ? $accounts : [];
    }
    
    /**
    * 游客注册
    */
    public function postRegisterYKPlayer(array $user = [], $inviter_id=1025, $channel='') : array
    {
        $username = '';
        $pwdmd5 = '';
        $clientuuid = '';
        $nickname = '';
        extract($user);
        if(empty($username)) {
            $username = substr(md5($clientuuid),0, 12);
        }
        if ($this->_getExistPlayerUsername($username)) {
            $this->setErrCode(160001);
            $this->setErrMsg('用户名已经存在', true);
            return [];
        }

        //新玩家账号id数组集合
        $_pids = [];
        
        //开启事务
        $this->mysql->getDb()->startTransaction();
        
        //创建玩家账号
        $salt =  mt_rand(1,9) . Random::number(5);
        $pid = $this->_randPlayerPID();
        $password = md5($pid . $pwdmd5 . $salt);
        $psecurity_pwd = md5($pid . $pwdmd5); //安全支付密码
        $agent = 0;
        $newUser = [
            'parent_id' => $inviter_id,
            'parent_agent_first_id'=> 0,
            'pid'       => $pid,
            'ppromoters'=> 0,
            'pusername' => $username,
            'pemail'    => '',
            'password'  => $password,
            'psecurity_pwd'=> $psecurity_pwd,
            'salt'      => $salt,
            'group_id'  => 0,
            'agent'     => $agent,
            'create_time'=> time()
        ];
        if(!empty($channel)) {
            $newUser['pusername'] = '';
            $newUser['pemail'] = $username;
            $newUser['nickname'] = $nickname;
            $newUser['remark'] = $channel;
        }
        
        // DB Insert 新玩家账号
        $this->mysql->getDb()->insert(MysqlTables::ACCOUNT, $newUser);
        $last_id = $this->mysql->getDb()->getInsertId();
        $_pids[] = $last_id;
        //新玩家账号ID
        if (!$last_id) {
            $err = $this->mysql->getDb()->getLastError();
            $this->mysql->getDb()->rollback();
            $this->setErrCode(160007);

            $this->setErrMsg('DB新增账号错误' . $err, true);
            return[];
        }

        //提交事务
        $this->mysql->getDb()->commit();

        //将username加入到redis集合中
        $this->models->rediscli_model->getDb()->sAdd(RedisKey::SETS_USERNAME, $username);

        //从db取玩家账号信息
        $_fieldstrs = $this->getTableFields(MysqlTables::ACCOUNT, ['a', 'account_', ',']);
        $_sql = " SELECT {$_fieldstrs} FROM account as a WHERE id={$last_id} LIMIT 1";
        $_ds = $this->mysql->getDb()->rawQuery($_sql);
        $player = isset($_ds[0]) ? array_shift($_ds) : [];
        //更新redis玩家账号信息
        if($player) {
            $this->models->rediscli_model->setUser($player);
        } 
        return $player;
    }


    /**
     * 当前账号设置密码
     * 玩家账号
     * @param string $oldpwd
     * @param string $newpwd
     * @return bool
     */
    public function putPlayerPassword($oldpwd = '', $newpwd = '')
    {
        $sql = [];
        
        $account = $this->getTokenObj();
        $account_pid = $account->account_pid;
        $account_id = $account->account_id;
        
        if ($this->getPlayerCheckPwd($account_pid, $oldpwd)) {
            //db字段
            $_needDbData = ['update_time'=> time(), 'token'=> null, 'token_expires'=> 0, 'online'=> 0];
            //清空token
            $_needDbData['salt'] = $salt = mt_rand(100000,999999);
            $_needDbData['password'] = md5($account_pid.$newpwd.$salt);
            
            //redis字段
            $_upRedisData = Helper::reFieldPre($_needDbData, 'account');
            $_upRedisData['account_id'] = $account_id;
            
            //db更新账号信息
            $sql[] = $this->mysql->getDb()->where('id', $account_id)->fetchSql()->update(MysqlTables::ACCOUNT, $_needDbData);
            $this->mysql->getDb()->resetDbStatus();
            
            //更新redis玩家账号信息
            $this->models->rediscli_model->setUser($_upRedisData);
            
            //删除玩家账号token
            $this->redis->getDb()->hDel(RedisKey::USERS_."usertoken", $account->account_token);
            
            //异步执行SQL
            TaskManager::async(new MysqlQuery($sql));
        } else {
            $this->setErrMsg('原密码不正确');
            
            return false;
        }
        
        return true;
    }
    
    public function getPlayerSecurityPassword(string $pwd = '') : bool
    {
        $account = $this->getTokenObj();
        $account_pid = $account->account_pid;
        
        if (md5($account_pid . $pwd) == $account->account_psecurity_pwd
            //未设置过支付密码，默认为登录密码
            || (in_array($account->account_ppromoters, ['0','1']) && $account->account_password == md5($account->account_pid . $pwd . $account->account_salt))) {
            return true;
        } else {
            $this->setErrMsg('密码不正确');
            return false;
        }
        
        return true;
    }
    
    public function putPlayerSecurityPassword(string $oldpwd = '', string $newpwd = '') : bool
    {
        $sql = [];
        
        $account = $this->getTokenObj();
        $account_pid = $account->account_pid;
        $account_id = $account->account_id;
        
        if (md5($account_pid . $oldpwd) == $account->account_psecurity_pwd
            //未设置过支付密码，默认为登录密码
            || (in_array($account->account_ppromoters, ['0','1']) && $account->account_password == md5($account->account_pid . $oldpwd . $account->account_salt))) {
            //db字段
            $_needDbData = ['update_time'=> time()];
            $_needDbData['psecurity_pwd'] = md5($account_pid . $newpwd);
            
            //redis字段
            $_upRedisData = Helper::reFieldPre($_needDbData, 'account');
            $_upRedisData['account_id'] = $account_id;
            
            //db更新账号信息
            $sql[] = $this->mysql->getDb()->where('id', $account_id)->fetchSql()->update(MysqlTables::ACCOUNT, $_needDbData);
            $this->mysql->getDb()->resetDbStatus();
            
            //更新redis玩家账号信息
            $this->models->rediscli_model->setUser($_upRedisData);
            
            //异步执行SQL
            TaskManager::async(new MysqlQuery($sql));
        } else {
            $this->setErrMsg('原密码不正确');
            
            return false;
        }
        
        return true;
    }
    
    public function postPlayerTransferProfit(string $md5pwd = '') : array
    {
        $pprofit_balance = '0';
        
        if (md5($this->getTokenObj()->account_pid . $md5pwd) == $this->getTokenObj()->account_psecurity_pwd
            //未设置过支付密码，默认为登录密码
            || (in_array($this->getTokenObj()->account_ppromoters, ['0','1']) && $this->getTokenObj()->account_password == md5($this->getTokenObj()->account_pid . $md5pwd . $this->getTokenObj()->account_salt))) {
            //当前可提现收益余额
            $pprofit_balance = $this->mysql->getDb()->where('id', $this->getTokenObj()->account_id)->getValue(MysqlTables::ACCOUNT, 'pprofit_balance');
            if (! ($pprofit_balance > 0)) {
                $this->setErrCode(160012);
                $this->setErrMsg('当前没有可提现收益');
                return [];
            }
            //开启事务
            $this->mysql->getDb()->startTransaction();
            //减去收益
            $this->mysql->getDb()->where('id', $this->getTokenObj()->account_id)->setDec(MysqlTables::ACCOUNT, 'pprofit_balance', $pprofit_balance);
            if (! $this->mysql->getDb()->getAffectRows()) {
                $this->mysql->getDb()->rollback();
                $this->setErrCode(160013);
                $this->setErrMsg('DB 更新（收益余额）失败');
                return [];
            }
            //添加流水
            $this->mysql->getDb()->insert(MysqlTables::LOG_PROFIT_PLAYER, [
                't'=> '2',
                'account_id'=> $this->getTokenObj()->account_id,
                'coin'=> $pprofit_balance * -1,
                'create_time'=> time()
            ]);
            if (! $this->mysql->getDb()->getInsertId()) {
                $this->mysql->getDb()->rollback();
                $this->setErrCode(160014);
                $this->setErrMsg('DB 新增（提现记录）失败');
                return [];
            }
            //提交事务
            $this->mysql->getDb()->commit();
            $this->getPlayer(null, $this->getTokenObj()->account_id, false, true, true);
        } else {
            $this->setErrCode(160011);
            $this->setErrMsg('支付密码不正确');
            return [];
        }
        
        return ['coin'=> $pprofit_balance];
    }
    
    public function postPlayerEmailCaptchaRestPassword(array $datas = []) : bool
    {
        $sql = [];
        
        $username = $pwdmd5 = $email = $captcha = '';
        extract($datas);
        
        $_captcha = $this->redis->getDb()->get(RedisKey::ACCOUNT_CAPTCHA_EMAIL_ . $captcha);
        if (! $_captcha || $_captcha != $username . '|||' . $email) {
            $this->setErrCode(160005);
            $this->setErrMsg('验证码错误或过期', true);
            return false;
        }
        
        $this->redis->getDb()->del(RedisKey::ACCOUNT_CAPTCHA_EMAIL_ . $captcha);
        
        //获取账号信息
        if(! ($account = $this->models->rediscli_model->getUser($username)))
        {
            $this->setErrCode(160006);
            $this->setErrMsg('账号不存在', true);
            return false;
        }
        
        $account_pid = $account['account_pid'];
        $account_id = $account['account_id'];
        
        if ($this->getPlayerCheckPwd($account_pid, '', '', '', true)) {
            //db字段
            $_needDbData = ['update_time'=> time(), 'token'=> null, 'token_expires'=> 0, 'online'=> 0];
            //清空token
            $_needDbData['salt'] = $salt = mt_rand(100000,999999);
            $_needDbData['password'] = md5($account_pid . $pwdmd5 . $salt);
            
            //redis字段
            $_upRedisData = Helper::reFieldPre($_needDbData, 'account');
            $_upRedisData['account_id'] = $account_id;
            
            //db更新账号信息
            $sql[] = $this->mysql->getDb()->where('id', $account_id)->fetchSql()->update(MysqlTables::ACCOUNT, $_needDbData);
            $this->mysql->getDb()->resetDbStatus();
            
            //更新redis玩家账号信息
            $this->models->rediscli_model->setUser($_upRedisData);
            
            //删除玩家账号token
            $this->redis->getDb()->hDel(RedisKey::USERS_."usertoken", $account['account_token']);
            
            //异步执行SQL
            TaskManager::async(new MysqlQuery($sql));
        } else {
            $this->setErrMsg('系统错误');
            return false;
        }
        
        return true;
    }
    
    /**
     * 检查总代是否存在
     * @return unknown
     */
    private function _checkExistRootAgent()
    {
        $_exist = $this->mysql->getDb()->rawQuery(sprintf("SELECT COUNT(1) AS count FROM %s WHERE agent=2", MysqlTables::ACCOUNT))[0]['count'];
        
        return $_exist ? true : false;
    }
    
    /**
     * 添加账号的树关系
     * @param number $ancestor_id               祖先id
     * @param number|array $descendant          自己id
     * @param number $descendant_agent          自己级别
     * @return boolean
     */
    private function _insertAccountTree($ancestor_id = 0, $descendant = null, $descendant_agent = 0) : bool
    {
        $complete = false;
        $_descendant_ids = [];
        
        if (is_array($descendant)) {
            $descendant_id = $descendant[0];
            unset($descendant[0]);
            $_descendant_ids = $descendant;
        } else {
            $descendant_id = $descendant;
        }
        
        $_treelist = [];
        //与自己
        $_treelist[] = [
            'ancestor_id'=> $descendant_id,
            'descendant_id'=> $descendant_id,
            'descendant_agent'=> $descendant_agent,
            'ancestor_h'=> 0
        ];

        $ds = $this->mysql->getDb()->where('descendant_id', $ancestor_id)->orderBy('ancestor_id', 'DESC')->get(MysqlTables::ACCOUNT_TREE);
        

        if(!empty($ds)) {
            foreach ($ds as $_node) {
                $_treelist[] = [
                    'ancestor_id'=> $_node['ancestor_id'],//直属祖先的祖先id同时也是自己的祖先id
                    'descendant_id'=> $descendant_id,
                    'descendant_agent'=> $descendant_agent,
                    'ancestor_h'=> $_node['ancestor_h']+1
                ];
            }
        }
        
        if (count($_treelist) > 0) {
            if ($_descendant_ids && $_tl = $_treelist) {
                foreach ($_descendant_ids as $_ancestor_id) {
                    foreach ($_tl as $_i) {
                        if (! $_i['ancestor_h']) {
                            $_i['ancestor_id'] = $_ancestor_id;
                            $_i['descendant_id'] = $_ancestor_id;
                        } else {
                            $_i['descendant_id'] = $_ancestor_id;
                        }
                        $_treelist[] = $_i;
                    }
                }
            }
            //批量插入数据
            $insert_ids = $this->mysql->getDb()->insertMulti(MysqlTables::ACCOUNT_TREE, $_treelist);
            $_count = count($insert_ids);
            if ($_count > 0) {
                $complete = true;
            }
        }
        
        return $complete;
    }
    
    /**
     * 创建代理账号
     * @return array
     */
    public function postAgent($username = '', $password = '', $nickname = '', string $phone = '', string $remark = '', string $coin = '0', string $ipaddr = '', string $prefix_username = '', int $region_id = 0) : array
    {
        $curUser = $this->getTokenObj();
        
        //代理级别
        $agent = ($_agent = abs(intval($curUser->account_agent))) === 3 ? 2 : ($_agent === 2 ? 1 : ($_agent === 1 ? 1 : -1) );
        //仅允许一个总代账号存在
        if ($agent === 2 && $this->_checkExistRootAgent()) {
            $this->setErrCode(4001);
            $this->setErrMsg('违规操作。总代数量超额');
            return [];
        }
        
        $parentAgentFirstId = abs(intval($curUser->account_agent)) === 1 ? ($curUser->account_parent_agent_first_id ?: $curUser->account_id) : 0;
        // 获取代理账号前缀
        if ($parentAgentFirstId > 0) {
            $firstAgent = $this->mysql->getDb()->where('id', $parentAgentFirstId)->getOne(MysqlTables::ACCOUNT);
            if ($firstAgent && $firstAgent['prefix_username']) {
                $username = $firstAgent['prefix_username'] . $username;
            }
        }

        //检测用户名是否重复
        if ($this->_getExistAgentUsername($username)) {
            $this->setErrCode(3004);
            $this->setErrMsg('用户名已存在');
            return [];
        }

        $salt = mt_rand(100000,999999);
        $_password = md5($username.$password.$salt);

        //开启事务
        $this->mysql->getDb()->startTransaction();
        $this->mysql->getDb()->insert(
            MysqlTables::ACCOUNT,
            [
                'parent_id'=> $curUser->account_id,
                'parent_agent_first_id'=> $parentAgentFirstId,
                'username'=> $username,
                'password'=> $_password,
                'salt'=> $salt,
                'nickname'=> $nickname,
                'phone'=> $phone,
                'remark'=> $remark,
                'group_id'=> 0,
                'agent'=> $agent,
                'create_time'=> time(),
                'prefix_username'=> $prefix_username,
                'region_id'=> $region_id
            ]
        );
        if (! ($last_id = $this->mysql->getDb()->getInsertId())) {
            //回滚
            $this->mysql->getDb()->rollback();
            $this->setErrMsg('数据库操作。创建账号记录失败');
            return [];
        }
        //维护树结构
        if (! $this->_insertAccountTree($curUser->account_id, $last_id, $agent)) {
            //回滚
            $this->mysql->getDb()->rollback();
            $this->setErrMsg('维护账号树结构失败');
            return [];
        }
        //给新账号上分操作
        if ($coin) {
            if (! $this->models->finance_model->postAgentCoinUp($username, Helper::format_money($coin), $ipaddr)) {
                //回滚       
                $this->mysql->getDb()->rollback();
                $this->setErrMsg('上分失败');
                return [];
            }
        }
        //提交事务
        $this->mysql->getDb()->commit();
        
        //添加到redis已存在库
        $this->models->rediscli_model->getDb()->sAdd(RedisKey::SETS_USERNAME, $username);
        
        return $last_id ? ['username'=> $username] : [];
    }
    
    /**
     * 设置代理账号
     * @param string $username
     * @param array $pars
     * @return boolean
     */
    public function putAgent($username = '', $pars = []) : bool
    {
        if (
            (isset($pars['password']) && ! $pars['password'])
            && (isset($pars['nickname']) && ! $pars['nickname'])
        ) {
            $this->setErrMsg('违规操作：无字段');
            return false;
        }
        
        $_needUpData = ['update_time'=> time()];
        
        //查找账号
        if (! ($_agent = $this->getAgent($username))) {
            $this->setErrMsg('代理账号不存在');
            return false;
        }
        
        //重置密码
        if (isset($pars['password']) && $pars['password']) {
            $_needUpData['salt'] = $salt = mt_rand(100000,999999);
            $_needUpData['password'] = md5($_agent['account_username'].$pars['password'].$salt);
            $_needUpData['token'] = null;
            $_needUpData['token_expires'] = 0;
            $_needUpData['online'] = 0;
        }
        
        //重置昵称
        if (isset($pars['nickname']) && $pars['nickname']) {
            $_needUpData['nickname'] = $pars['nickname'];
        }

        //电话
        if (isset($pars['phone']) && $pars['phone']) {
            $_needUpData['phone'] = $pars['phone'];
        }

        //备注
        if (isset($pars['remark']) && $pars['remark']) {
            $_needUpData['remark'] = $pars['remark'];
        }
        
        //redis字段
        $_upRedisData = Helper::reFieldPre($_needUpData, 'account');
        $_upRedisData['account_id'] = $_agent['account_id'];
        
        $this->mysql->getDb()->where('id', $_agent['account_id'])->update(MysqlTables::ACCOUNT, $_needUpData);
        
        if (! $this->mysql->getDb()->getAffectRows()) {
            $this->setErrMsg('更新数据失败');
            return false;
        }
        
        //更新redis代理账号信息
        //$data = $this->mysql->getDb()->where('id', $_agent['account_id'])->getOne(MysqlTables::ACCOUNT);
        $this->models->rediscli_model->setUser($_upRedisData);
        
        return true;
    }
    
    /**
     * 获取代理
     * 列表
     * @param string $keyword
     * @param string $orderby
     * @param number $page
     * @return boolean|array
     */
    public function getAgents($keyword = '', $orderby = '', $page = 0, $username = '')
    {
        $_limit_value = 20;
        $_limit_offset = ($page = abs(intval($page))) > 0 ? ($page - 1) * $_limit_value : 0;
        
        $result = ['total'=> 0, 'page'=> ! $page ? 1 : $page, 'limit'=> $_limit_value, 'list'=> [], 'account' => []];

        $db = $this->mysql->getDb();

        if ($username) {
            $account = $db->where('username', $username)->getOne(MysqlTables::ACCOUNT);
            if (empty($account)) {
                return $result;
            }
            $result['account'] = $account;
        } else {
            $account = $db->where('id', $this->getTokenObj()->account_id)->getOne(MysqlTables::ACCOUNT);
            if (empty($account)) {
                return $result;
            }
            $result['account'] = $account;
        }
        
        $parentId = $result['account']['id'];
        // 判断是否是当前登录用户的子孙（包括自己）
        if (!$this->isDescendant($this->getTokenObj()->account_id, $parentId)) {
            return $result;
        }
        
        $_table_account_fields_ar = [];
        $_table_account_fields = $this->getTableFields('account', ['a', ['account_', &$_table_account_fields_ar]], [
            'id', 
            'nickname', 
            'username', 
            'create_time', 
            'login_time', 
            'coin', 
            'phone', 
            'remark', 
            'prefix_username', 
            'banby_id']);
        $fieldstrs = implode(",", $_table_account_fields);
        
        if ($orderby) {
            list($_od_f, $_od_b) = explode("|", $orderby);
            $_od_f = in_array($_od_f, $_table_account_fields_ar) && ($_od_f = str_replace(['account_'], ['a.'], $_od_f)) ? $_od_f : false;
            $_od_b = strtoupper($_od_b);
            
            if ($_od_f === false || ! $_od_b || ! in_array($_od_b, ['DESC', 'ASC'])) {
                $this->setErrMsg('orderby参数非法');
                return false;
            }
            
            $orderby = [$_od_f, $_od_b];
        } else {
            $orderby = ['a.id', 'DESC'];
        }
        
        //$fieldstrs.= ",ban.depth as account_bandepth";
        //$db->join('(SELECT descendant_id,COUNT(descendant_id) as depth FROM '.MysqlTables::ACCOUNT_BAN.' GROUP BY descendant_id) as ban', 'a.id=ban.descendant_id', 'left');
        
        $db->where('a.agent', 0, '>')->where('a.agent', 3, '<')->where('a.parent_id', $parentId);
        if ($keyword) {
            $db->where("(a.username LIKE '%{$keyword}%' OR a.nickname LIKE '%{$keyword}%')");
        }
        
        $result['list'] = $db->orderBy($orderby[0], $orderby[1])->withTotalCount()->get('account as a', [$_limit_offset, $_limit_value], $fieldstrs);
        $result['total'] = $db->getTotalCount();
        
        return $result;
    }
    
    public function getCoinFieldValue($account_id = 0)
    {
        $account = $this->mysql->getDb()->where('id', $account_id)->getOne(MysqlTables::ACCOUNT, 'coin');
        
        return Helper::format_money($account['coin']);
    }

    /**
     * 获取代理账号
     * @param string $username          代理账号名称
     * @param int $uid                  代理uid
     * @param bool $needbandepth        是否加入被禁用
     * @param bool $forceFromDB         从DB获取
     * @param bool $forceToRedis        更新到redis缓存
     * @return array|bool
     */
    public function getAgent($username = null, $uid = 0, $needbandepth = false, $forceFromDB = false, $forceToRedis = true) : array
    {
        $agent = [];
        
        if (! $username && ! $uid) {
            $this->setErrCode(1002);
            $this->setErrMsg('代理账号不存在', true);
            
            return [];
        }
        
        $_p_par = $username ?: $uid;
        
        if (! $forceFromDB && !! ($agent = $this->models->rediscli_model->getUser($_p_par))) {
            //是否被禁用了账号的登录操作，db查询
            if ($needbandepth) {
                
                //直接拿banby_id来判断即可，无需获取上级是否被禁状态
                
                //$agent['account_bandepth'] = $this->checkAccountBan($agent['account_id']) ? 1 : 0;
                //$agent['account_bandepth'] = (int)$this->mysql->getDb()->rawQuery(sprintf("SELECT COUNT(1) AS account_bandepth FROM %s WHERE descendant_id=%d", MysqlTables::ACCOUNT_BAN, $agent['account_id']))[0]['account_bandepth'];
            }
            
            return $agent;
        }
        
        //获取表字段集合
        $fieldstrs = $this->getTableFields(MysqlTables::ACCOUNT, ['a', 'account_', ',']);
        //if ($needbandepth) $fieldstrs.= ",ban.depth as account_bandepth";
        $db = $this->mysql->getDb()->where('a.agent', 0, '>');
        if ($username) {
            $db->where('a.username', $username);
        } elseif ($uid) {
            $db->where('a.id', $uid);
        }
        /* if ($needbandepth) {
            $db->join("(SELECT descendant_id,COUNT(1) as depth FROM account_ban WHERE descendant_agent>0 GROUP BY descendant_id) as ban", 'a.id=ban.descendant_id', 'left');
        } */
        $agent = $db->getOne('account as a', $fieldstrs);
        
        if (! $agent || ! isset($agent['account_id'])) {
            $this->setErrCode(1002);
            $this->setErrMsg('代理账号不存在', true);
            
            return [];
        }
        
        //更新redis代理账号信息
        //$agent['account_token'] = null;
        //$agent['account_token_expires'] = 0;
        //$agent['account_online'] = 0;
        if ($forceToRedis) $this->models->rediscli_model->setUser($agent);
        
        return $agent;
    }
    
    /**
     * 判断是否可创建指定数量玩家账号
     * @param number $parent_id
     * @param number $neednum
     * @return boolean[]|number[]
     */
    private function getExceedMaxPlayerNum($parent_id = 0, $neednum = 0)
    {
        $_en = $this->mysql->getDb()->rawQuery(sprintf("SELECT COUNT(1) AS count FROM %s WHERE parent_id=%d", MysqlTables::ACCOUNT, $parent_id))[0]['count'];
        
        //最多允许添加的玩家个数
        $_max = 5000;
        
        return [$_en + $neednum > $_max, $_max - $_en];
    }
    
    /**
     * 随机一个PID，并存入redis
     * @return string
     */
    private function _randPlayerPID() : string
    {
        //此处加入地区代码区分 2019.08.27
        if ( Config::getInstance()->getConf('APPTYPE') == 1 ) {
            $_pid = Config::getInstance()->getConf('AREACODE') . '00' . Random::number(4) . Random::number(4);
        } else {
            $_pid = mt_rand(1,9) . Random::number(4) . Random::number(4) . Random::number(3);
        }
        
        if ($this->models->rediscli_model->getDb()->sAdd(RedisKey::SETS_PID, $_pid))
        {
            return $_pid;
        }
        
        return $this->_randPlayerPID();
    }
    
    /**
     * 随机一个PID，并存入redis
     * @return string
     */
    private function _randPlayerPolyPID()
    {
        //此处加入地区代码区分 2019.08.27
        if ( Config::getInstance()->getConf('APPTYPE') == 1 ) {
            $_pid = Config::getInstance()->getConf('AREACODE') . '00' . Random::number(4) . Random::number(4);
        } else {
            $_pid = '0'. Config::getInstance()->getConf('AREACODE') . Random::number(8);
        }
        
        if ($this->models->rediscli_model->getDb()->sAdd(RedisKey::SETS_PID, $_pid))
        {
            return $_pid;
        }
        
        return $this->_randPlayerPolyPID();
    }
    
    private function _isExistPid(string $pid = '') : bool
    {
        return $this->mysql->getDb()->where('pid', $pid)->has(MysqlTables::ACCOUNT);
    }
    
    private function _isExistSetPid(string $pid = '') : bool
    {
        return $this->models->rediscli_model->getDb()->sismember(RedisKey::SETS_PID, $pid) ? true : false;
    }
    
    /**
     * 创建玩家账号
     * @param number $playertotal       需要添加的账号总数
     * @param string $md5pwd            md5密码明文
     * @param string $nickname          账号昵称
     * @param string $openApiAppUID
     * @return array
     */
    public function postPlayers($playertotal = 0, $md5pwd = '', $nickname = '', string $openApiAppUID = '') : array
    {
        $curUser = $this->getTokenObj();
        /**
         * @var bool $_cannotdo 是否可以继续创建
         * @var int $_leavenum 剩余可创建账号数量
         */
        list($_cannotdo, $_leavenum) = $this->getExceedMaxPlayerNum($curUser->account_id, $playertotal);
        if ($_cannotdo) {
            $this->setErrCode(4001);
            $this->setErrMsg("Limit {$_leavenum}", true);
            return [];
        }
        
        //接口需要返回的新建玩家账号列表
        $accounts = [];
        //新玩家账号id数组集合
        $_pids = [];
        //入redis新玩家账号信息集合
        $_redisQueue = [];
        $accountSetting = $this->models->system_model->getAccountSetting();
        
        //批量插入玩家账号
        for ($i = 0; $i < $playertotal; $i++) {
            //开启事务
            $this->mysql->getDb()->startTransaction();

            $salt =  mt_rand(1,9) . Random::number(5);
            $pid = $this->_randPlayerPID();
            $password = md5($pid . $md5pwd . $salt);
            $agent = 0;

            $newUser = [
                'parent_id'=> $curUser->account_id,
                'parent_agent_first_id'=> abs(intval($curUser->account_agent)) === 1 ? ($curUser->account_parent_agent_first_id ?: $curUser->account_id) : 0,
                'pid'=> $pid,
                'password'=> $password,
                'salt'=> $salt,
                'group_id'=> 0,
                'agent'=> $agent,
                'create_time'=> time(),
                'ppromoters'=> 1,
            ];
            if ($nickname) {
                $newUser['nickname'] = $nickname;
            }
            
            //OpenApi 账号ID
            if ($this->getAbutmentKey('isOpenApi') && $openApiAppUID) {
                if ($this->mysql->getDb()->where('appuid', $openApiAppUID)->where('parent_id', $curUser->account_id)->has(MysqlTables::ACCOUNT)) {
                    $this->setErrMsg('Duplicate Account ID');
                    $accounts = [];
                    break;
                }
                $newUser['appuid'] = $openApiAppUID;
            }
            
            $this->mysql->getDb()->insert(MysqlTables::ACCOUNT, $newUser);
            $last_id =  $this->mysql->getDb()->getInsertId();
            $_pids[] = $last_id;

            //新玩家账号ID
            if (!$last_id) {
                $this->mysql->getDb()->rollback();
                $this->setErrMsg('Db Insert');
                $accounts = [];
                continue;
            }

            $ps = [];
            $ps[1] = ['account_id'=> $last_id, 'height'=> 1];
            $this->mysql->getDb()->where('id', $last_id)->update(MysqlTables::ACCOUNT, ['prelation_parents'=> json_encode($ps)]);

            // 是否开启了新手红包
            $coin = 0;
            if ($accountSetting && $accountSetting['red_envelope_switch'] == 1) {
                $coin = mt_rand($accountSetting['red_envelope_min'] * 100, $accountSetting['red_envelope_max'] * 100) / 100;

                if ($curUser->account_coin < $coin) {
                    $this->mysql->getDb()->rollback();
                    $this->setErrMsg('额度不足');
                    continue;
                }
                $this->mysql->getDb()->where('id', $curUser->account_id)->setDec(MysqlTables::ACCOUNT, 'coin', $coin);
                $this->models->account_model->updateAccountRedis($curUser->account_id);

            }

            //维护树结构
            if (! $this->_insertAccountTree($curUser->account_id, $_pids, $agent)) {
                $this->mysql->getDb()->rollback();
                $this->setErrMsg('Build Tree');
                continue;
            }
        
            //提交事务
            $this->mysql->getDb()->commit();
        
            //将新玩家账号信息放入redis预队列
            $_redisQueue = ['uid'=> $last_id, 'pid'=> $pid, 'coin'=> 0.00, 'red_envelope' => Helper::format_money($coin)];
            $this->models->rediscli_model->getDb()->lPush(RedisKey::LOGS_PLAYERS, json_encode($_redisQueue, JSON_UNESCAPED_UNICODE|JSON_UNESCAPED_SLASHES));

            //新玩家PID
            $accounts[] = Helper::account_format_login($pid);
        }

        return $accounts ? $accounts : [];
    }
    
    public function postAssignPlayer($md5pwd = '', $nickname = '', $account_id = '0', $account_coin = '0') : array
    {
        //接口需要返回的新建玩家账号列表
        $accounts = [];
        //新玩家账号id数组集合
        $_pids = [];
        
        //开启事务
        $this->mysql->getDb()->startTransaction();
        
        //批量插入玩家账号
        for ($i = 0; $i < 1; $i++) {
            $salt =  mt_rand(1,9) . Random::number(5);
            $pid = $this->_randPlayerPID();
            $password = md5($pid . $md5pwd . $salt);
            $agent = 0;
            $this->mysql->getDb()->insert(MysqlTables::ACCOUNT,
                [
                    'id'=> $account_id,
                    'parent_id'=> 1025,
                    'parent_agent_first_id'=> 1025,
                    'pid'=> $pid,
                    'password'=> $password,
                    'salt'=> $salt,
                    'nickname'=> $nickname,
                    'group_id'=> 0,
                    'agent'=> $agent,
                    'create_time'=> time(),
                    'coin'=> $account_coin
                ]);
            
            $_pids[] = $account_id;
            
            //新玩家账号ID
            /* if (! ($last_id = $_pids[] = $this->mysql->getDb()->getInsertId())) {
                $this->mysql->getDb()->rollback();
                $this->setErrMsg('数据库错误。创建单个玩家账号失败');
                $accounts = [];
                break;
            } */
            
            //新玩家PID
            $accounts[] = Helper::account_format_login($pid);
        }
        
        if (! $accounts) {
            return [];
        }
        
        //维护树结构
        if (! $this->_insertAccountTree(1025, $_pids, $agent)) {
            $this->mysql->getDb()->rollback();
            $this->setErrMsg('添加树结构失败');
            return [];
        }
        
        $this->mysql->getDb()->commit();
        
        return $accounts ? $accounts : [];
    }
    
    public function postAssignPlayer2(int $total = 1,
        string $md5pwd = '',
        string $nickname = '',
        string $coin = '0',
        string $parent_id = '1025',
        string $pusername = '',
        string $extent1 = '') : array
        {
            $totalCoin = 0;
            if (! ($agentAccount = $this->getAgent(null, $parent_id, false, true, false))) {
                $this->setErrMsg('代理不存在');
                return [];
            }
            
            if (!isset($agentAccount['parent_agent_first_id']) || !$agentAccount['parent_agent_first_id']) {
                $parent_agent_first_id = $agentAccount['account_id'];
            } else {
                $parent_agent_first_id = $agentAccount['parent_agent_first_id'];
            }
            
            //接口需要返回的新建玩家账号列表
            $accounts = [];
            //新玩家账号id数组集合
            $_pids = [];
            //入redis新玩家账号信息集合
            $_redisQueue = [];
            
            //开启事务
            $this->mysql->getDb()->startTransaction();
            
            //批量插入玩家账号
            for ($i = 0; $i < $total; $i++) {
                $salt =  mt_rand(1,9) . Random::number(5);
                $pid = $this->_randPlayerPID();
                $password = md5($pid . $md5pwd . $salt);
                $newUser = [];
                $newUser = [
                    'parent_id'=> $parent_id,
                    'parent_agent_first_id'=> $parent_agent_first_id,
                    'pid'=> $pid,
                    'password'=> $password,
                    'salt'=> $salt,
                    'group_id'=> 0,
                    'agent'=> 0,
                    'extent1'=> $extent1,
                    'create_time'=> time()
                ];
                if ($nickname) {
                    $newUser['nickname'] = $nickname;
                }
                if ($coin > 0) {
                    $newUser['coin'] = $coin;
                    $totalCoin = $totalCoin + $coin;
                }
                if ($pusername) {
                    $newUser['pusername'] = $pusername;
                }
                
                $this->mysql->getDb()->insert(MysqlTables::ACCOUNT, $newUser);
                
                //新玩家账号ID
                if (! ($last_id = $_pids[] = $this->mysql->getDb()->getInsertId())) {
                    $this->mysql->getDb()->rollback();
                    $this->setErrMsg('Db Insert');
                    $accounts = [];
                    break;
                }
                
                //将新玩家账号信息放入redis预队列
                $_redisQueue[] = ['uid'=> $last_id, 'pid'=> $pid, 'coin'=> Helper::format_money($coin)];
                //新玩家PID
                $accounts[] = Helper::account_format_login($pid);
            }
            
            if (! $accounts) {
                return [];
            }
            
            // 判断代理分数是否足够
            if ($totalCoin > 0) {
                if ($agentAccount['account_coin'] < $totalCoin) {
                    $this->mysql->getDb()->rollback();
                    $this->setErrMsg('代理额度不足');
                    return [];
                }
                // 扣除代理余额
                // 代理减分
                $this->mysql->getDb()->where('id', $agentAccount['account_id'])->setDec(MysqlTables::ACCOUNT, 'coin', $totalCoin);
                // 更新redis信息
                $this->updateAccountRedis($agentAccount['account_id']);
            }
            
            //维护树结构
            if (! $this->_insertAccountTree($agentAccount['account_id'], $_pids, 0)) {
                $this->mysql->getDb()->rollback();
                $this->setErrMsg('Build Tree');
                return [];
            }
            
            //提交事务
            $this->mysql->getDb()->commit();
            
            //将新玩家账号信息放入redis队列
            foreach ($_redisQueue as $_r_u) {
                $this->models->rediscli_model->getDb()->lPush(RedisKey::LOGS_PLAYERS, json_encode($_r_u, JSON_UNESCAPED_UNICODE|JSON_UNESCAPED_SLASHES));
            }
            
            return $accounts ? $accounts : [];
    }
    
    /**
     * 创建玩家账号
     * @param string $account
     * @param string $md5pwd            md5密码明文
     * @param string $nickname          账号昵称
     * @param string $phone
     * @param string $remark
     * @param string $coin
     * @param string $ipaddr
     * @return array
     */
    public function postPolyPlayer(string $account = '', string $md5pwd = '', string $nickname = '', string $phone = '', string $remark = '', string $coin = '0', string $ipaddr = '') : array
    {
        if ($this->_isExistPid($account)) {
            $this->setErrMsg('账号已存在');
            return [];
        } elseif (! $this->_isExistSetPid($account)) {
            $this->setErrMsg('账号非法');
            return [];
        }
        
        $curUser = $this->getTokenObj();
        //接口需要返回的新建玩家账号列表
        $accounts = [];
        //新玩家账号id数组集合
        $_pids = [];
        //入redis新玩家账号信息集合
        $_redisQueue = [];
        /* if ($this->getTokenObj()->account_flag_api_player_post_lock) {
            $this->setErrMsg('系统正忙，请稍后再试');
            return [];
        } */
        //开启事务
        $this->mysql->getDb()->startTransaction();
        //操作上锁
        /* $this->mysql->getDb()->where('id', $curUser->account_id)->update(MysqlTables::ACCOUNT, ['flag_api_player_post_lock'=> 1]);
        if (! $this->mysql->getDb()->getAffectRows()) {
            $this->mysql->getDb()->rollback();
            $this->setErrMsg('系统正忙，请稍后再试');
            return [];
        } */
        $salt =  mt_rand(1,9).Random::number(5);
        $pid = $account;
        $password = md5($pid.$md5pwd.$salt);
        $agent = 0;
        $this->mysql->getDb()->insert(
            MysqlTables::ACCOUNT,
            [
                'parent_id'=> $curUser->account_id,
                'parent_agent_first_id'=> abs(intval($curUser->account_agent)) === 1 ? ($curUser->account_parent_agent_first_id ?: $curUser->account_id) : 0,
                'pid'=> $pid,
                'password'=> $password,
                'salt'=> $salt,
                'nickname'=> $nickname,
                'phone'=> $phone,
                'remark'=> $remark,
                'group_id'=> 0,
                'agent'=> $agent,
                'create_time'=> time()
            ]
        );
        //新玩家账号ID
        if (! ($last_id = $_pids[] = $this->mysql->getDb()->getInsertId())) {
            $this->mysql->getDb()->rollback();
            $this->setErrMsg('数据库错误。创建单个玩家账号失败');
            return [];
        }
        //将新玩家账号信息放入redis预队列
        $_redisQueue[] = ['uid'=> $last_id, 'pid'=> $pid, 'coin'=> Helper::format_money($coin ?: 0), 'ipaddr'=> $ipaddr];
        //新玩家PID
        $accounts[] = Helper::account_format_login($pid);
        //维护树结构
        if (! $this->_insertAccountTree($curUser->account_id, $_pids, $agent)) {
            $this->mysql->getDb()->rollback();
            $this->setErrMsg('添加树结构失败');
            return [];
        }
        //需要给新账号进行上分
        if ($coin) {
            if (! $this->models->finance_model->postPlayerCoinUpNotNotice($pid, Helper::format_money($coin))) {
                $this->mysql->getDb()->rollback();
                $this->setErrMsg('上分失败');
                return [];
            }
        }
        //提交事务
        $this->mysql->getDb()->commit();
        //操作解锁
        //$this->mysql->getDb()->where('id', $curUser->account_id)->update(MysqlTables::ACCOUNT, ['flag_api_player_post_lock'=> 0]);
        //判断当前代理对应的一级代理是否被概率控制，有的话新增玩家也需要添加概率控制
        $uids = array_column($_redisQueue, 'uid');
        //此处需要轶哥修改
        //$this->load->model('prob_model');
        //$parent_agent_first_id = $curUser->account_parent_agent_first_id > 0 ? $curUser->account_parent_agent_first_id : $curUser->account_id;
        //$this->prob_model->pushProbByUids($parent_agent_first_id, $uids);
        
        //将新玩家账号信息放入redis队列
        foreach ($_redisQueue as $_r_u) {
            $this->models->rediscli_model->getDb()->lPush(RedisKey::LOGS_PLAYERS, json_encode($_r_u, JSON_UNESCAPED_UNICODE|JSON_UNESCAPED_SLASHES));
        }
        
        return $accounts ? $accounts : [];
    }
    
    public function postPlayerPolyAccount() : string
    {
        return $this->_randPlayerPolyPID();
    }
    
    /**
     * 设置玩家账号
     * @param string $account
     * @param array $_needUpData
     * @param array $checkfields
     * @return boolean|array
     */
    public function putPlayer($account = '', $_needUpData = [], $checkfields = [])
    {
        if (! ($_player = $this->getPlayer($account, 0))) {
            $this->setErrMsg('玩家账号不存在');
            return false;
        }
        
        $fields = $checkfields ?: ['password', 'nickname', 'remark', 'phone'];
        foreach ($_needUpData as $key => $value) {
            if (! in_array($key, $fields) || is_null($value)) {
                unset($_needUpData[$key]);
            }
        }
        
        //修改玩家登录密码
        if (isset($_needUpData['password']) && $_needUpData['password']) {
            $_password = $_needUpData['password'];
            $_needUpData['salt'] = $salt = mt_rand(1,9).Random::number(5);
            $_needUpData['password'] = md5($_player['account_pid'].$_password.$salt);
            //清空token
            $_needUpData['token'] = null;
            $_needUpData['token_expires'] = 0;
            $_needUpData['online'] = 0;
        }
        
        if (! $_needUpData) {
            $this->setErrMsg('Fields Empty');
            return false;
        }
        
        //如果进行的是修改账号密码的话
        //如果进行的是将玩家踢下线60秒操作的话
        //需要向游戏服务器请求此操作，以便判断是否能将玩家踢下线
        if (isset($_needUpData['salt']) || (isset($_needUpData['ban_time']) && $_needUpData['ban_time'] > time())) {
            //向游戏服务器推送数据
            if (! $this->models->curl_model->pushPlayerOffline60Sec(['uid'=> $_player['account_id']])) {
                $this->setErrMsg($this->models->curl_model->getErrMsssage());
                return false;
            }
        }

        //电话
        if (isset($_needUpData['phone']) && $_needUpData['phone']) {
            $_needUpData['phone'] = $_needUpData['phone'];
        }

        //备注
        if (isset($_needUpData['remark']) && $_needUpData['remark']) {
            $_needUpData['remark'] = $_needUpData['remark'];
        }
        
        $_needUpData['update_time'] = time();
        
        $this->mysql->getDb()->where('id', $_player['account_id'])->update(MysqlTables::ACCOUNT, $_needUpData);
        if(! $this->mysql->getDb()->getAffectRows())
        {
            $this->setErrMsg('Db Update');
            return false;
        }
        
        //redis字段
        $_upRedisData = Helper::reFieldPre($_needUpData, 'account');
        $_upRedisData['account_id'] = $_player['account_id'];
        //更新redis玩家账号信息
        $this->models->rediscli_model->setUser($_upRedisData);
        
        return $_needUpData;
    }
    
    /**
     * 获取玩家
     * 列表
     * @param string $keywords  pid或nickname关键字
     * @param string $orderby   排序字段            以|符号进行分隔，如：account_id|DESC
     * @param number $page      页数
     * @return array|bool
     */
    public function getPlayers($keywords = '', $orderby = '', $page = 0, $username = '')
    {
        $curUser = $this->getTokenObj();
        
        $_limit_value = 20;
        $_limit_offset = ($page = abs(intval($page))) > 0 ? ($page - 1) * $_limit_value : 0;
        $result = ['total'=> 0, 'page'=> ! $page ? 1 : $page, 'limit'=> $_limit_value, 'list'=> []];

        if ($username && !($account = $this->mysql->getDb()->where('username', $username)->getOne(MysqlTables::ACCOUNT))) {
            return $result;
        }
        
        $parentId = isset($account) && $account ? $account['id'] : $curUser->account_id;
        
        $_table_account_fields_ar = [];
        $_table_account_fields = $this->getTableFields('account', ['a', ['account_', &$_table_account_fields_ar]], [
            'id',
            'nickname',
            'pid',
            'appuid',
            'vip',
            'create_time',
            'login_time',
            'coin',
            'online',
            'phone',
            'remark',
            'banby_id']);
        //查询字段
        $fieldstrs = implode(",", $_table_account_fields); //.",ban.depth as account_bandepth";
        //排序字段
        if ($orderby) {
            list($_od_f, $_od_b) = explode("|", $orderby);
            $_od_f = in_array($_od_f, $_table_account_fields_ar) && ($_od_f = str_replace(['account_'], ['a.'], $_od_f)) ? $_od_f : false;
            $_od_b = strtoupper($_od_b);
            if ($_od_f === false || ! $_od_b || ! in_array($_od_b, ['DESC', 'ASC'])) {
                $this->setErrMsg('orderby参数非法');
                return false;
            }
            $orderby = [$_od_f, $_od_b];
        } else {
            $orderby = ['a.id', 'DESC'];
        }
        //db查询
        $db = $this->mysql->getDb();
        //->join('(SELECT descendant_id,COUNT(1) as depth FROM '.MysqlTables::ACCOUNT_BAN.' GROUP BY descendant_id) as ban', 'a.id=ban.descendant_id', 'left');
        $db->where('a.agent', 0)->where('a.parent_id', $parentId);
        if ($keywords) {
            $db->where("a.pid LIKE '%".str_replace('-', '', $keywords)."%' OR a.nickname LIKE '%{$keywords}%' OR a.id LIKE '%{$keywords}%'");
        }
        $ds = $db->orderBy($orderby[0], $orderby[1])->withTotalCount()->get('account as a', [$_limit_offset, $_limit_value], $fieldstrs);
        //记录总数
        $result['total'] = $db->getTotalCount();
        
        //开放平台请求
        if ($this->getAbutmentKey('isOpenApi')) {
            foreach ($ds as $_p) {
                $_pids[] = $_p['account_id'];
                $result['list'][] = [
                    'account'=> (string)$_p['account_appuid'],
                    'coin'=> (string)$_p['account_coin'],
                    'ban'=> $this->checkAccountBan($_p['account_id']) ? 1 : 0,
                    'create_time'=> (string)$_p['account_create_time'],
                    'lastlogin_time'=> (string)$_p['account_login_time']
                ];
            }
            if (isset($_pids) && $_pids) {
                if (!! ($_onlines = $this->models->curl_model->getOnlinePlayerOne($_pids))) {
                    foreach ($result['list'] as $pk=> $pp) {
                        $result['list'][$pk]['online'] = $_onlines[$_pids[$pk]] ? 1 : 0;
                    }
                }
            }
        }
        //常规请求
        else {
            foreach ($ds as $_p) {
                $_pids[] = $_p['account_id'];
                $result['list'][] = $_p;
            }
            if (isset($_pids) && $_pids) {
                if (!! ($_onlines = $this->models->curl_model->getOnlinePlayerOne($_pids))) {
                    foreach ($result['list'] as $pk=> $pp) {
                        $result['list'][$pk]['account_online'] = $_onlines[$pp['account_id']] ? 1 : 0;
                    }
                }
            }
        }

        $accountIds = array_column($result['list'], 'account_id');
        if ($accountIds) {
            $coinsPlayer = $db->whereIn('account_id', $accountIds)->where('type', 12)->get(MysqlTables::COINS_PLAYER, null, 'account_id, coin');
            $coinsPlayer = array_column($coinsPlayer, 'coin', 'account_id');
            foreach ($result['list'] as &$one) {
                $one['red_envelope'] = isset($coinsPlayer[$one['account_id']]) ? $coinsPlayer[$one['account_id']] : 0;
            }
        }
        
        return $result;
    }
    
    /**
     * 获取玩家账号
     * @param string $account           玩家账号名称
     * @param int $uid                  玩家uid
     * @param bool $needbandepth        是否加入被禁用
     * @param bool $forceFromDB         从DB获取
     * @param bool $forceToRedis        更新到reids
     * @return array|bool
     */
    public function getPlayer($account = null, $uid = 0, $needbandepth = false, $forceFromDB = false, $forceToRedis = true)
    {
        $player = [];
        
        if (! $account && ! $uid) {
            $this->setErrCode(1002);
            $this->setErrMsg('玩家账号不存在', true);
            return false;
        }
        
        $_p_par = $account ? Helper::account_format_login($account) : $uid;
        if (! $forceFromDB && !! ($player = $this->models->rediscli_model->getUser($_p_par))) {
            //是否被禁用了账号的登录操作，db查询
            if ($needbandepth) {
                // $player['account_bandepth'] = (int)$this->mysql->getDb()->rawQuery(sprintf("SELECT COUNT(1) AS account_bandepth FROM %s WHERE descendant_id=%d", MysqlTables::ACCOUNT_BAN, $player['account_id']))[0]['account_bandepth'];

                if($this->checkAccountBan($player['account_id'])){
                    $player['account_bandepth'] = 1;
                }
            }
            
            return $player;
        }
        
        //获取表字段集合
        $fieldstrs = $this->getTableFields(MysqlTables::ACCOUNT, ['a', 'account_', ',']);
        if ($needbandepth) $fieldstrs.= ",ban.depth as account_bandepth";
        
        $db = $this->mysql->getDb()->where('a.agent', 0);
        if ($account) {
            $db->where('a.pid', $account);
        } elseif ($uid) {
            $db->where('a.id', $uid);
        }
        if ($needbandepth) {
            $db->join("(SELECT descendant_id,COUNT(1) as depth FROM account_ban WHERE descendant_agent=0 GROUP BY descendant_id) as ban", 'a.id=ban.descendant_id', 'left');
        }
        $player = $db->getOne('account as a', $fieldstrs);
        if (! $player || ! isset($player['account_id'])) {
            $this->setErrCode(1002);
            $this->setErrMsg('玩家账号不存在', true);
            return false;
        }
        
        //更新redis玩家账号信息
        if ($forceToRedis) $this->models->rediscli_model->setUser($player);
        
        return $player;
    }
    
    public function getOpenApiPlayerPID(string $appUID = '')
    {
        return $this->mysql->getDb()->where('parent_id', $this->getTokenObj()->account_id)
        ->where('appuid', $appUID)
        ->getValue(MysqlTables::ACCOUNT, 'pid');
    }
    
    /**
     * 获取玩家登录日志
     * @param number $account_id_or_pid
     * @param number $time_s
     * @param number $time_e
     * @param number $page
     * @return number[]|array[]|mixed|array|object
     */
    public function getPlayerLoginLogs($account_id_or_pid = 0, $time_s = 0, $time_e = 0, $page = 0)
    {
        $_limit_value = 20;
        $_limit_offset = ($page = abs(intval($page))) > 0 ? ($page - 1) * $_limit_value : 0;
        
        $result = ['total'=> 0, 'page'=> ! $page ? 1 : $page, 'limit'=> $_limit_value, 'list'=> []];
        
        $db = $this->mysql->getDb()->where('alll.t', 3, '<');
        if ($account_id_or_pid) {
            $db->where("(alll.account_id=".(int)$account_id_or_pid." OR alll.account_pid='".Helper::account_format_login($account_id_or_pid)."')");
        }
        
        if ($this->getAbutmentKey('isOpenApi')) {
            if ($time_e < $time_s || $time_e - $time_s > 2592000) {
                $this->setErrMsg('时间范围错误');
                return $result;
            }
        }
        
        if ($time_s && $time_e && $time_e >= $time_s) {
            $db->where('alll.create_time', $time_s, '>=');
            $db->where('alll.create_time', $time_e, '<=');
        }
        
        $db->orderBy('alll.id', 'DESC');
        $result['list'] = $db->withTotalCount()->get('log_login_player as alll', [$_limit_offset, $_limit_value]);
        $result['total'] = $db->getTotalCount();
        
        if ($this->getAbutmentKey('isOpenApi')) {
            $_list = $result['list'];
            $result['list'] = [];
            foreach ($_list as $item) {
                $result['list'][] = [
                    'login_ip'=> (string)$item['ip'],
                    'login_create_time'=> (string)$item['create_time']
                ];
            }
        }
        
        return $result;
    }
    
    /**
     * 获取玩家游戏记录日志
     * @param unknown $account
     * @param unknown $gameid
     * @param string $orderby
     * @param number $page
     * @return array|bool
     */
    public function getPlayerGameLogs($account, $gameid, $orderby = '', $page = 0, $limitValue = 20)
    {
        $offset = ($page = abs(intval($page))) > 0 ? ($page - 1) * $limitValue : 0;
        
        $result = ['total'=> 0, 'list'=> []];

        $db = $this->mysql->getDb();
        $db->join(MysqlTables::ACCOUNT . ' AS a', 'c.account_id=a.id', 'LEFT');
        $account && $db->where('a.pid', $account);
        $gameid && $db->where('c.game_id', $gameid);
        $db->where('c.type', [3, 4], 'IN');
        $orderby = $orderby ? $orderby : 'create_time|DESC';
        list($orderByField, $orderByDirection) = explode("|", $orderby);
        $db->orderBy($orderByField, $orderByDirection);
        $fields = 'c.account_id, a.pid, c.`before`, c.`after`, c.coin, c.type, c.game_id, c.create_time';
        $rs = $db->withTotalCount()->get(MysqlTables::COINS_PLAYER . ' AS c', [$offset, $limitValue], $fields);
        
        $result['list'] = $rs;
        $result['total'] = $db->getTotalCount();
        return $result;
    }
    
    /**
     * 获取子孙id集合
     * @param number $ancestor_id   祖先id
     * @param string $andself       是否包含自己
     * @param number|bool $agent    代理级别
     * @param string $rearray       是否返回数组
     * @return mixed
     */
    private function _getAccountDescendantsIDS($ancestor_id = 0, $andself = false, $agent = -1, $rearray = false)
    {
        $_array = [];
        
        if (! $rearray) {
            $this->mysql->getDb()->rawQuery('SET SESSION group_concat_max_len=18446744073709551610');
        }
        
        if (! $rearray) {
            $fields = 'GROUP_CONCAT(descendant_id) as IDS';
        } else {
            $fields = '*';
        }
        
        $db = $this->mysql->getDb()->where('ancestor_id', $ancestor_id);
        
        //不包含自己
        if(! $andself) $db->where('descendant_id', $ancestor_id, '>');
        
        if (is_bool($agent) && $agent) {
            $db->where("(descendant_id={$ancestor_id} OR descendant_agent IN(1,2))");
        } elseif (is_bool($agent) && ! $agent) {
            $db->where("(descendant_id={$ancestor_id} OR descendant_agent=0)");
        } elseif (is_numeric($agent) && $agent > -1) {
            $db->where("(descendant_id={$ancestor_id} OR descendant_agent={$agent})");
        }
        
        if ($rearray) {
            $_array = $db->orderBy('descendant_id', 'ASC')->get(MysqlTables::ACCOUNT_TREE, null, $fields);
        } else {
            $_r = $db->orderBy('descendant_id', 'ASC')->getOne(MysqlTables::ACCOUNT_TREE, $fields);
        }
        
        return $rearray ? $_array : (isset($_r['IDS']) ? $_r['IDS'] : '');
    }
    
    /**
     * 判断账号是否被禁用
     * 包括代理账号和游戏账号
     * @param number $ancestor_id           祖先id
     * @param number $descendant_id         自己id
     * @param number|bool $isagent          自己代理等级
     */
    private function _getAccountIsBan($ancestor_id = 0, $descendant_id = 0, $isagent = -1) : int
    {
        $db = $this->mysql->getDb();
        if ($ancestor_id) $db->where('ancestor_id', $ancestor_id);
        $db->where('descendant_id', $descendant_id);
        if (is_bool($isagent) && $isagent) {
            $db->whereIn('descendant_agent', [1,2]);
        } elseif (is_bool($isagent) && ! $isagent) {
            $db->where('descendant_agent', 0);
        } elseif (! is_bool($isagent) && is_numeric($isagent) && $isagent > -1) {
            $db->where('descendant_agent', $isagent);
        }
        
        $_r = $db->getOne(MysqlTables::ACCOUNT_BAN, 'COUNT(descendant_id) as ISBAN');
        
        return (isset($_r['ISBAN']) && $_r['ISBAN']) ? $_r['ISBAN'] : 0;
    }
    
    /**
     * 添加账号禁用
     * @param number $ancestor_id
     * @param number $descendant_id
     * @return array|bool
     */
    private function _insertAccountBan($ancestor_id = 0, $descendant_id = 0)
    {
        $result = false;
        
        //被执行禁用的玩家id集合
        $_player_ids = [];
        $_player_pids = [];
        //被执行禁用的代理id集合
        $_agent_ids = [];
        $_agent_usernames = [];
        
        $_inserts = [];
        //获取子孙id集合
        $_descendants_ids = $this->_getAccountDescendantsIDS($descendant_id, true, -1, true);
        
        //遍历子孙
        foreach ($_descendants_ids as $_u) {
            $_inserts[] = [
                'ancestor_id'=> $ancestor_id,
                'descendant_id'=> $_u['descendant_id'],
                'descendant_agent'=> $_u['descendant_agent']
            ];
        }
        
        if ($_inserts) {
            //开启事务
            $this->mysql->getDb()->startTransaction();
            
            foreach ($_inserts as $_banItem) {
                //是否未被禁用
                if (! $this->_getAccountIsBan($_banItem['ancestor_id'], $_banItem['descendant_id'])) {
                    $this->mysql->getDb()->insert(MysqlTables::ACCOUNT_BAN, $_banItem);
                    //禁用单个账号执行成功
                    if ($this->mysql->getDb()->getAffectRows()) {
                        if (! $_banItem['descendant_agent']) {
                            //将玩家id放入集合
                            $_player_ids[] = $_banItem['descendant_id'];
                            //redis更新玩家账号禁用缓存 - 禁用
                            $this->models->rediscli_model->getDb()->hSet(RedisKey::USERS_."userban", $_banItem['descendant_id'], 1);
                            
                            if (($_ginfo = $this->getPlayer(null, $_banItem['descendant_id'])) && isset($_ginfo['account_pid']) && $_ginfo['account_pid']) {
                                $_player_pids[] = Helper::account_format_display($_ginfo['account_pid']);
                            }
                        } else {
                            //将代理id放入集合
                            $_agent_ids[] = $_banItem['descendant_id'];
                            if (($_ainfo = $this->getAgent(null, $_banItem['descendant_id'])) && isset($_ainfo['account_username']) && $_ainfo['account_username']) {
                                $_agent_usernames[] = $_ainfo['account_username'];
                            }
                        }
                    }
                }
            }
            
            if ($_agent_ids) {
                //更新代理account字段
                $this->mysql->getDb()->whereIn('id', $_agent_ids)->update(MysqlTables::ACCOUNT, ['token'=> '', 'token_expires'=> 0, 'update_time'=> time(), 'online'=> 0]);
                
                if (! $this->mysql->getDb()->getAffectRows()) {
                    $this->mysql->getDb()->rollback();
                }
            }
            
            $this->mysql->getDb()->commit();
            
            if ($_player_ids) {
                //通知游戏服批量将玩家踢下线
                for ($i = 0; $i < ceil(count($_player_ids)/100); $i++) {
                    $_pis = array_slice($_player_ids, 100*$i, 100*($i+1));
                    if ($_pis) $this->models->curl_model->pushPlayerOffline60Sec(['uid'=> implode(",", $_pis)]);
                }
            }
            
            $result = [];
            $result['player'] = $_player_pids;
            $result['agent'] = $_agent_usernames;
        }
        
        return $result;
    }
    
    /**
     * 解除账号禁用
     * @param number $ancestor_id
     * @param number $descendant_id
     */
    private function _removeAccountBan($ancestor_id = 0, $descendant_id = 0)
    {
        $_descendants_ids = $this->_getAccountDescendantsIDS($descendant_id, true, -1, false);
        
        $this->mysql->getDb()->where('ancestor_id', $ancestor_id)->whereIn('descendant_id', explode(",", $_descendants_ids))->delete(MysqlTables::ACCOUNT_BAN);
        
        if ($this->mysql->getDb()->getAffectRows()) {
            //redis更新玩家账号禁用缓存 - 解禁
            $this->models->rediscli_model->getDb()->hSet(RedisKey::USERS_."userban", $descendant_id, 0);
            
            return true;
        }
        
        return false;
    }
    
    /**
     * 禁用账号
     * 禁用代理，需要禁用其下所有子账号、直属玩家、所子孙代理(不限级)、子孙代理(不限级)的玩家
     * 包括代理账号和游戏账号
     * @param string $username      代理用户名
     * @param string $account       玩家PID
     * @return bool
     */
    public function banAccount($username = '', $account = '') : bool
    {
        $curUser = $this->getTokenObj();
        $descendant_id = 0;
        
        if (! $username && ! $account) {
            $this->setErrMsg('非法操作，账号为空');
            return false;
        }
        
        //禁用代理下所有玩家
        if ($account == '000000000000' && 1==2) {
            //获取代理下所有玩家
            $_playerids = [];
            
            $_playerids = $this->mysql->getDb()->where('parent_id', $curUser->account_id)
            ->where('agent', 0)->get(MysqlTables::ACCOUNT, null, 'id,pid');
            
            //禁用玩家账号
            if ($_playerids) {
                foreach ($_playerids as $_player) {
                    //禁用成功
                    if (($_banR = $this->_insertAccountBan($curUser->account_id, $_player['id'])) !== false) {
                        if (in_array(Helper::account_format_display($_player['pid']), $_banR['player'])) {
                            //$_wApiLogPs[] = account_format_display($_player['pid'])." ";
                        } else {
                            //$_wApiLogPs[] = account_format_display($_player['pid'])." 失败（重复操作）";
                        }
                    }
                    //禁用失败
                    else {
                        //$_wApiLogPs[] = account_format_display($_player['pid'])." 失败";
                    }
                }
            }
            
            return true;
        }
        //解禁代理下所有玩家
        elseif ($account == '000000000001' && 1==2) {
            //获取代理下所有玩家
            $_playerids = [];
            $_playerids = $this->mysql->getDb()->where('parent_id', $curUser->account_id)->where('agent', 0)->get(MysqlTables::ACCOUNT, null, 'id,pid');
            
            if ($_playerids) {
                foreach ($_playerids as $_player) {
                    if ($this->_removeAccountBan($curUser->account_id, $_player['id'])) {
                        //$_wApiLogPs[] = account_format_display($_player['pid'])." 成功";
                    } else {
                        //$_wApiLogPs[] = account_format_display($_player['pid'])." 失败";
                    }
                }
            }
            
            return true;
        }
        //正常禁用/解禁账号
        else {
            //禁用代理
            if ($username) {
                if (! ($accountInfo = $this->getAgent($username, 0, false, true))) {
                    $this->setErrMsg('代理不存在');
                    return false;
                }
                
                $descendant_id = $accountInfo['account_id'];
            }
            //禁用玩家
            else {
                if (! ($accountInfo = $this->getPlayer($account, 0, false, true))) {
                    $this->setErrMsg('玩家不存在');
                    return false;
                }
                
                $descendant_id = $accountInfo['account_id'];
            }
            
            //判断是否非法传参
            if ($curUser->account_id == $descendant_id) {
                $this->setErrMsg('非法操作');
                return false;
            }
            
            //查询目标账号的任一祖先是否被禁用
            if ($this->mysql->getDb()->sum("(
                
                SELECT a.banby_id FROM account_tree as a_t LEFT JOIN account as a ON (a_t.ancestor_id=a.id AND a.banby_id>0) 
                WHERE a_t.ancestor_id!={$descendant_id} AND a_t.descendant_id={$descendant_id} AND a.banby_id>0
                
            ) as T", 'banby_id')) {
                $this->setErrMsg('禁止操作，上级已被禁用');
                return false;
            }
            
            //判断目标账号是否为当前账号的子孙
            if (! $this->mysql->getDb()->where('ancestor_id', $curUser->account_id)->where('descendant_id', $descendant_id)->has(MysqlTables::ACCOUNT_TREE)) {
                $this->setErrMsg('无权操作');
                return false;
            }
            
            //解禁操作
            if ($accountInfo['account_banby_id']) {
                //db字段
                $_needDbData = ['banby_id'=> 0];
                $this->mysql->getDb()->where('id', $descendant_id)->update(MysqlTables::ACCOUNT, $_needDbData);
                //redis字段
                $_upRedisData = Helper::reFieldPre($_needDbData, 'account');
                $_upRedisData['account_id'] = $descendant_id;
                //更新账号信息
                $this->models->rediscli_model->setUser($_upRedisData);
                $this->setErrData(['ban'=> 0]);
                $this->setErrMsg('解禁成功', true);
            }
            //禁用操作
            else {
                //db字段
                $_needDbData = ['banby_id'=> $curUser->account_id];
                $this->mysql->getDb()->where('id', $descendant_id)->update(MysqlTables::ACCOUNT, $_needDbData);
                //redis字段
                $_upRedisData = Helper::reFieldPre($_needDbData, 'account');
                $_upRedisData['account_id'] = $descendant_id;
                //更新账号信息
                $this->models->rediscli_model->setUser($_upRedisData);
                $this->setErrData(['ban'=> 1]);
                $this->setErrMsg('禁用成功', true);
            }
        }
        
        return true;
    }
    
    /**
     * 添加系统公告
     * @param $content
     * @return array
     */
    public function postNoticeSystem($content)
    {
        $this->mysql->getDb()->insert(
            MysqlTables::SYS_GLOBALNOTICE,
            [
                'content'=> $content,
                'create_time'=> time()
            ]
        );
        
        if (! ($last_id = $this->mysql->getDb()->getInsertId())) {
            $this->setErrMsg('数据库操作');
            return [];
        }
        
        return ['id'=> $last_id];
    }
    
    /**
     * 编辑系统公告
     * @param $id
     * @param $content
     * @return array|bool
     */
    public function putNoticeSystem($id, $content)
    {
        $this->mysql->getDb()->where('id', $id)->update(MysqlTables::SYS_GLOBALNOTICE, ['content'=> $content, 'create_time'=> time()]);
        
        return $this->mysql->getDb()->getAffectRows() ? ['id'=> $id] : false;
    }
    
    /**
     * 获取系统公告
     * @return array
     */
    public function getNoticeSystem()
    {
        $notice = $this->mysql->getDb()->getOne(MysqlTables::SYS_GLOBALNOTICE);
        
        return $notice;
    }
    
    /**
     * 判断代理账号用户名是否已经存在
     * @param string $username
     * @return unknown
     */
    private function _getExistAgentUsername(string $username = '') : bool
    {
        if ($this->models->rediscli_model->getDb()->sIsMember(RedisKey::SETS_USERNAME, $username)) {
            return true;
        }
        
        $_exist = $this->mysql->getDb()->rawQuery(sprintf("SELECT COUNT(1) AS count FROM %s WHERE username='%s'", MysqlTables::ACCOUNT, $username))[0]['count'];
        
        return $_exist ? true : false;
    }
    
    private function _getExistPlayerUsername(string $username = '') : bool
    {
        if ($this->models->rediscli_model->getDb()->sIsMember(RedisKey::SETS_USERNAME, $username)) {
            return true;
        }
        
        return false;
    }
    
    private function _getExistPlayerEmail(string $email = '') : bool
    {
        if ($this->models->rediscli_model->getDb()->sIsMember(RedisKey::SETS_USEREMAIL, $email)) {
            return true;
        }
        
        return false;
    }
    
    /**
     * 判断子账号用户名是否已经存在
     * @param string $username
     * @return unknown
     */
    private function _getExistVchildUsername($username = '')
    {
        if ($this->_getExistAgentUsername($username)) {
            $this->setErrCode(3004);
            $this->setErrMsg('用户名已存在');
            return true;
        }
        
        if ($this->models->rediscli_model->getDb()->sIsMember(RedisKey::SETS_VUSERNAME, $username)) {
            return true;
        }
        
        $_exist = $this->mysql->getDb()->rawQuery(sprintf("SELECT COUNT(1) AS count FROM %s WHERE username='%s'", MysqlTables::ACCOUNT_CHILD_AGENT, $username))[0]['count'];
        
        return $_exist ? true : false;
    }
    
    /**
     * 创建子账号
     * @param string $username
     * @param string $password
     * @param string $nickname
     * @param string $pergids
     * @return array
     */
    public function postVchild($username = '', $password = '', $nickname = '', $pergids = '') : array
    {
        if ($this->_getExistVchildUsername($username)) {
            $this->setErrCode(3004);
            $this->setErrMsg('子账号用户名已存在');
            return [];
        }
        
        $curUser = $this->getTokenObj();

        $exists_child_count = $this->mysql->getDb()->where('parent_id', $curUser->account_id)->count(MysqlTables::ACCOUNT_CHILD_AGENT, 'vid');
        if($exists_child_count >= 5) {
            $this->setErrCode(3005);
            $this->setErrMsg('子账号个数已满');
            return [];
        }
        // 屏蔽验证，不然得区分poly跟bigbang的权限id，而且验证这种id意义不大
        // $pergids = Helper::array_pergids($pergids, $curUser->account_agent);
        // if (! $pergids || ! is_array($pergids)) {
        //     $this->setErrMsg('pergids参数错误');
        //     return [];
        // }
        $pergids = explode('|', $pergids);
        
        $salt = mt_rand(100000,999999);
        $_password = md5($username.$password.$salt);
        
        $this->mysql->getDb()->insert(
            MysqlTables::ACCOUNT_CHILD_AGENT,
            [
                'parent_id'=> $curUser->account_id,
                'username'=> $username,
                'nickname'=> $nickname,
                'password'=> $_password,
                'salt'=> $salt,
                'group_id'=> implode(",", $pergids),
                'create_time'=> time()
            ]
        );
        
        if (! ($last_uid = $this->mysql->getDb()->getInsertId())) {
            $this->setErrMsg('数据库操作。创建子账号记录失败');
            return [];
        }
        
        $this->models->rediscli_model->getDb()->sAdd(RedisKey::SETS_VUSERNAME, $username);
        
        return ['username'=> $username];
    }
    
    /**
     * 获取子账号详情
     * @param null $username
     * @param number $vid
     * @return array
     */
    public function getVchild($username = null, $vid = 0):? array
    {
        $result = [];
        
        $fieldstrs = $this->getTableFields(MysqlTables::ACCOUNT_CHILD_AGENT, ['v', 'virtual_', ',', ',']).$this->getTableFields(MysqlTables::ACCOUNT, ['a', 'account_', ',']);
        
        $db = $this->mysql->getDb()->join('account as a', 'v.parent_id=a.id', 'left')
        ->where('v.parent_id', $this->getTokenObj()->account_id);
        if ($username) {
            $db->where('v.username', $username);
        } elseif ($vid) {
            $db->where('v.id', $vid);
        } else {
            return $result;
        }
        $result = $db->getOne('account_child_agent as v', $fieldstrs);
        
        return $result;
    }
    
    /**
     * 设置子账号
     * @param string $username
     * @param array $pars
     * @return bool
     */
    public function putVchild($username = '', $pars = []) : bool
    {
        if (
            (isset($pars['password']) && ! $pars['password'])
            && (isset($pars['nickname']) && ! $pars['nickname'])
            && (isset($pars['pergids']) && ! $pars['pergids'])
            && ! isset($pars['switch'])
        ) {
            $this->setErrMsg('违规操作：无字段');
            return false;
        }
        
        $_needUpData = ['update_time'=> time()];
        
        if (($_vchild = $this->getVchild($username)) === []) {
            $this->setErrMsg('子账号不存在');
            return false;
        }
        
        //设置密码
        if (isset($pars['password']) && $pars['password']) {
            $_needUpData['salt'] = $salt = mt_rand(100000,999999);
            $_needUpData['password'] = md5($_vchild['virtual_username'].$pars['password'].$salt);
            $_needUpData['token'] = '';
            $_needUpData['token_expires'] = 0;
            $_needUpData['online'] = 0;
        }
        
        //设置昵称
        if (isset($pars['nickname']) && $pars['nickname']) {
            $_needUpData['nickname'] = $pars['nickname'];
        }
        
        //设置用户组
        if (isset($pars['pergids'])) {
            $pergids = explode('|', $pars['pergids']);
            $_needUpData['token'] = '';
            $_needUpData['token_expires'] = 0;
            $_needUpData['online'] = 0;
            $_needUpData['group_id'] = implode(",", $pergids);
        }
        
        //账号开关设置
        if (isset($pars['switch'])) {
            $_needUpData['token'] = '';
            $_needUpData['token_expires'] = 0;
            $_needUpData['online'] = 0;
            $_needUpData['ban'] = $pars['switch'];
        }
        
        //redis字段
        $_upRedisData = Helper::reFieldPre($_needUpData, 'virtual');
        $_upRedisData['virtual_vid'] = $_vchild['virtual_vid'];
        $_upRedisData['virtual_parent_id'] = $_vchild['virtual_parent_id'];
        
        $this->mysql->getDb()->where('vid', $_vchild['virtual_vid'])->update(MysqlTables::ACCOUNT_CHILD_AGENT, $_needUpData);
        
        if (! $this->mysql->getDb()->getAffectRows()) {
            $this->setErrMsg('更新数据失败');
            return false;
        }
        
        //更新redis子账号信息
        $this->models->rediscli_model->setUser($_upRedisData);
        
        return true;
    }
    
    /**
     * 获取子账号
     * 列表
     * @param string $orderby
     * @param number $page
     * @return boolean|array
     */
    public function getVchilds($orderby = '', $page = 0)
    {
        $_limit_value = 20;
        $_limit_offset = ($page = abs(intval($page))) > 0 ? ($page - 1) * $_limit_value : 0;
        
        $result = ['total'=> 0, 'page'=> ! $page ? 1 : $page, 'limit'=> $_limit_value, 'list'=> []];
        
        $_table_vchild_fields_ar = $_table_account_fields_ar = [];
        $_table_vchild_fields = $this->getTableFields('account_child_agent', ['v', ['virtual_', &$_table_vchild_fields_ar]], ['vid', 'nickname', 'username', 'create_time', 'group_id', 'login_time', 'ban']);
        $_table_account_fields = $this->getTableFields('account', ['a', ['account_', &$_table_account_fields_ar]], ['id', 'nickname', 'username', 'create_time', 'login_time', 'coin']);
        
        $fieldstrs = implode(",", $_table_vchild_fields).",".implode(",", $_table_account_fields);
        
        if ($orderby) {
            list($_od_f, $_od_b) = explode("|", $orderby);
            $_od_f = (in_array($_od_f, $_table_vchild_fields_ar) || in_array($_od_f, $_table_account_fields_ar)) && ($_od_f = str_replace(['virtual_', 'account_'], ['v.','a.'], $_od_f)) ? $_od_f : false;
            $_od_b = strtoupper($_od_b);
            
            if ($_od_f === false || ! $_od_b || ! in_array($_od_b, ['DESC', 'ASC'])) {
                $this->setErrMsg('orderby参数非法');
                return false;
            }
            
            $orderby = [$_od_f, $_od_b];
        } else {
            $orderby = ['v.vid', 'DESC'];
        }
        
        $db = $this->mysql->getDb();
        $db->join('account as a', 'v.parent_id=a.id', 'left');
        // 管理员也需要添加子账号
        $db->where('a.agent', 0, '>')/*->where('a.agent', 3, '<')*/->where('v.parent_id', $this->getTokenObj()->account_id);
        $db->orderBy($orderby[0], $orderby[1]);
        $result['list'] = $db->withTotalCount()->get('account_child_agent as v', [$_limit_offset, $_limit_value], $fieldstrs);
        $result['total'] = $db->getTotalCount();
        
        return $result;
    }
    
    /**
     * 更新token到redis缓存
     * @param string $token
     * @param array $datas
     * @param string $role
     * @return bool
     */
    public function setTokenToRedis($token = '', $datas = [])
    {
        if ($token && $datas) {
            //存入redis缓存，token
            $this->redis->getDb()->set(RedisKey::PLAYER_TOKEN_.$token, json_encode($datas, JSON_UNESCAPED_UNICODE|JSON_UNESCAPED_SLASHES));
            
            if (isset($datas['account_id']) && $datas['account_id']) {
                $this->redis->getDb()->set(RedisKey::PLAYER_USERS_UID_.$datas['account_id'], json_encode($datas, JSON_UNESCAPED_UNICODE|JSON_UNESCAPED_SLASHES));
            }
            
            //仅玩家，代理没有pid字段，所以仅会在role=player的时候才会保存到redis
            if (isset($datas['account_pid']) && $datas['account_pid']) {
                $this->redis->getDb()->set(RedisKey::PLAYER_USERS_PID_.$datas['account_pid'], json_encode($datas, JSON_UNESCAPED_UNICODE|JSON_UNESCAPED_SLASHES));
            }
        }
        
        return true;
    }
    
    /**
     * 删除token从redis缓存
     * @param unknown $tokens
     * @param string $role
     * @return bool
     */
    public function delTokenFromRedis($tokens = null)
    {
        $_role_rediskeys = [
            'player'=> RedisKey::PLAYER_TOKEN_
        ];
        
        //删除单个
        if ($tokens && is_string($tokens)) {
            $this->redis->getDb()->del(RedisKey::PLAYER_TOKEN_.$tokens);
        }
        //批量删除
        elseif ($tokens && is_array($tokens)) {
            array_walk($tokens, function(&$_tk)use($_role_rediskeys){ $_tk = $_role_rediskeys['player'].$_tk; });
            $this->redis->getDb()->del(implode(" ", $tokens));
        }
        
        return true;
    }

    /**
     * 获取单个代理或玩家的信息
     * @param number $page
     * @param array $par
     * @return array|bool
     */
    public function searchAccount($username)
    {
        $curUser = $this->getTokenObj();

        $db = $this->mysql->getDb();
        $db->where("(username='{$username}' OR pid='{$username}' OR id='{$username}')");
        $account = $db->getOne(MysqlTables::ACCOUNT);
        if (empty($account)) {
            return [];
        }
        if (!$this->isDescendant($curUser->account_id, $account['id'])) {
            return [];
        }

        $parentAccount = $db->where('id', $account['parent_id'])->getOne(MysqlTables::ACCOUNT);
        $parentAccount && $account['parent_username'] = $parentAccount['username'];
        //$account['bandepth'] = 0;
        $account['online'] = 0;
        // 查询是否被禁用
        /* if ($db->where('descendant_id', $account['id'])->getOne(MysqlTables::ACCOUNT_BAN)) {
            $account['bandepth'] = 1;
        } */

        if ($account['agent'] == 0) {
            // 判断玩家是否在线
            $online = $this->models->curl_model->getOnlinePlayerOne($account['id']);
            $account['online'] = $online;
        }
        
        // 是否直属
        $account['is_direct'] = (int)$curUser->account_id === $account['parent_id'] ? 1 : 0;

        $agentlist = [];
        $res = $db->where('descendant_id', $account['id'])->get(MysqlTables::ACCOUNT_TREE);
        foreach ($res as $row) {
            if($row['ancestor_id'] != $account['id'] && ($row['ancestor_id'] > $curUser->account_id)) {
                $parent = $db->where('id', $row['ancestor_id'])->getOne(MysqlTables::ACCOUNT);
                $item = [
                    'id'       => $row['ancestor_id'],
                    'username' => $parent['username'],
                    'nickname' => $parent['nickname'],
                    'coin'     => intval($parent['coin']),
                    'phone'    => $parent['phone'],
                    'remark'   => $parent['remark'],
                    'is_direct'=> 0,
                    'banby_id'   => $parent['banby_id'],
                ];
                if($parent['parent_id'] == $curUser->account_id) {
                    $item['is_direct'] = 1;
                }
                $top_parent = $db->where('id', $parent['parent_id'])->getOne(MysqlTables::ACCOUNT);
                $item['parent_id'] = $top_parent['id'];
                $item['parent_username'] = $top_parent['username'];
                $agentlist[] = $item;
            }
        }

        $data['account'] = $account;
        $data['agentlist'] = $agentlist;
        return $data;
    }

    public function addAgent($parentId, $username, $password, $agent, $appid)
    {
        $db = $this->mysql->getDb();
        $salt = mt_rand(100000,999999);
        $password = md5($username.$password.$salt);
        $this->mysql->getDb()->insert(
            MysqlTables::ACCOUNT,
            [
                'appid' => $appid,
                'parent_id'=> $parentId,
                'parent_agent_first_id'=> 0,
                'username'=> $username,
                'password'=> $password,
                'salt'=> $salt,
                'nickname'=> '',
                'group_id'=> 0,
                'agent'=> $agent,
                'create_time'=> time()
            ]
        );
        if (!($last_id = $db->getInsertId())) {
            $this->setErrMsg('数据库操作。创建账号记录失败');
            return false;
        }
        //维护树结构
        if (! $this->_insertAccountTree($parentId, $last_id, $agent)) {
            $this->setErrMsg('维护账号树结构失败');
            return false;
        }
        return true;
    }

    /**
     * 判断是否子孙（包括自己）
     * @param  int  $ancestorId
     * @param  int  $descendantId
     * @return boolean
     */
    public function isDescendant($ancestorId, $descendantId)
    {
        $db = $this->mysql->getDb();
        $rs = $db->where('ancestor_id', $ancestorId)->where('descendant_id', $descendantId)->getOne(MysqlTables::ACCOUNT_TREE);
        return $rs ? true : false;
    }

    public function postAuth($username, $auth)
    {
        $db = $this->mysql->getDb();

        $account = $db->where('username', $username)->getOne(MysqlTables::ACCOUNT);
        if (!$account) {
            $this->setErrCode(4001);
            $this->setErrMsg('账号不存在');
            return false;
        }

        if ($db->where('account_id', $account['id'])->getOne(MysqlTables::ACCOUNT_AUTH)) {
            $rs = $db->where('account_id', $account['id'])->update(MysqlTables::ACCOUNT_AUTH, ['auth_id' => $auth]);
        } else {
            $rs = $db->insert(MysqlTables::ACCOUNT_AUTH, [
                'account_id' => $account['id'],
                'auth_id' => $auth,
                'create_time' => time()
            ]);
        }

        return $rs ? true : false;
    }

    public function deleteAuth($id)
    {
        $db = $this->mysql->getDb();

        $account = $db->where('id', $id)->getOne(MysqlTables::ACCOUNT);
        if (!$account) {
            $this->setErrCode(4001);
            $this->setErrMsg('账号不存在');
            return false;
        }

        $db->where('account_id', $id)->delete(MysqlTables::ACCOUNT_AUTH);

        return true;
    }

    public function getAuths($page = 1)
    {
        $_limit_value = 20;
        $_limit_offset = ($page = abs(intval($page))) > 0 ? ($page - 1) * $_limit_value : 0;

        $db = $this->mysql->getDb();
        $db->join(MysqlTables::ACCOUNT . ' AS a', 'u.account_id=a.id');
        $fields = 'u.*, a.username';
        $db->orderBy('u.create_time', 'desc');
        $list = $db->withTotalCount()->get(MysqlTables::ACCOUNT_AUTH . ' AS u', [$_limit_offset, $_limit_value], $fields);
        $total = $db->getTotalCount();
        return ['list' => $list, 'total' => $total];
    }

    /**
     * 判断ip是否与一级代理设定的区域一致
     */
    private function checkIp($firstAgentId, $ip)
    {
        // 获取一级代理信息
        if(! ($firstAgent = $this->models->rediscli_model->getUser($firstAgentId)/* 从redis取玩家账号缓存 */))
        {
            $this->updateAccountRedis($firstAgentId);
        }

        if (isset($firstAgent['account_region_id']) && $firstAgent['account_region_id'] && $regionName=Helper::getRegion($ip)) {
            $region = $this->mysql->getDb()->where('name_cn', $regionName)->getOne(MysqlTables::REGION, 'id');
            if (!($region && $region['id'] == $firstAgent['account_region_id'])) { //ip不匹配
                $this->setErrCode(3006);
                $this->setErrMsg('账号禁止在该区域登录', true);
                return false;
            }
        }

        $lock_china = $this->models->rediscli_model->getDb()->get(RedisKey::LOCK_CHINA);
        if($lock_china) {
            $regionName=Helper::getRegion($ip);
            if(false !== strpos($regionName,"中国")) {
                $this->setErrCode(3006);
                $this->setErrMsg('账号禁止在该区域登录', true);
                return false;
            }
        }
        return true;
    }

    public function updateAccountRedis($accountId)
    {
        //从db取玩家账号信息
        $_fieldstrs = $this->getTableFields(MysqlTables::ACCOUNT, ['a', 'account_', ',']);
        $account = $this->mysql->getDb()->where('a.id', $accountId)->getOne(MysqlTables::ACCOUNT . ' AS a', $_fieldstrs);
        
        //更新redis玩家账号信息
        if ($account) {
            $this->models->rediscli_model->setUser($account);
        }
        return $account;
    }
}
