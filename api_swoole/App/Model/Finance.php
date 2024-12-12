<?php
namespace App\Model;

use App\Model\Model;
use App\Model\Constants\RedisKey;
use App\Model\Constants\MysqlTables;
use App\Task\NewProtection;
use App\Task\NewWinProtection;
use App\Task\MysqlQuery;
use EasySwoole\EasySwoole\Swoole\Task\TaskManager;
use EasySwoole\EasySwoole\Logger;
use App\Utility\Helper;
use EasySwoole\Utility\Random;
use PhpParser\Node\Stmt\TryCatch;
use EasySwoole\EasySwoole\Config;

class Finance extends Model
{
    private $domsgcode = [
        'S001'=> ['key'=> 'S001', 'dec'=> '平台上分至总代理'],
        'S002'=> ['key'=> 'S002', 'dec'=> '平台下分至总代理'],
        'A001'=> ['key'=> 'A001', 'dec'=> '总代理上分至代理'],
        'A002'=> ['key'=> 'A002', 'dec'=> '总代理下分至代理'],
        'B001'=> ['key'=> 'B001', 'dec'=> '代理上分至下级'],
        'B002'=> ['key'=> 'B002', 'dec'=> '代理下分至下级'],
        'B003'=> ['key'=> 'B003', 'dec'=> '代理上分至玩家'],
        'B004'=> ['key'=> 'B004', 'dec'=> '代理下分至玩家'],
        'C001'=> ['key'=> 'C001', 'dec'=> '玩家下注'],
        'C002'=> ['key'=> 'C002', 'dec'=> '玩家赢钱'],
        'C003'=> ['key'=> 'C003', 'dec'=> '玩家获得红包救济'],
        'C004'=> ['key'=> 'C004', 'dec'=> '玩家获得BB大奖'],
        'C005'=> ['key'=> 'C005', 'dec'=> '玩家从BigBang转出余额至第三方平台'],
        'C006'=> ['key'=> 'C006', 'dec'=> '玩家从第三方平台转出余额至BigBang']
    ];
    
    /**
     * 代理上分
     * 当前减分，目前加分
     * @param string $username
     * @param string $coin
     * @param string $ipaddr
     * @return boolean
     */
    public function postAgentCoinUp(string $username = '', string $coin = '0', string $ipaddr = '') : bool
    {
        if (! $coin || $coin <= 0) {
            $this->setErrMsg('非法操作');
            return false;
        }
        
        //获取代理
        //获取目标用户
        //此处不能同步到redis，因为创建代理上分的时候，可能失败
        if (! ($_u_tar = $this->models->account_model->getAgent($username, 0, false, false, false))) {
            $this->setErrMsg('代理不存在');
            return false;
        }
        
        //是否被禁用了账号
        if ($this->models->account_model->checkAccountBan($_u_tar['account_id'])) {
            $this->setErrCode(3003);
            $this->setErrMsg('账号被禁用', true);
            return false;
        }
        
        $curUser = $this->getTokenObj();
        /**
         * 当前用户金币
         * 出币
         */
        //用户金币额度字段判断
        if (abs(intval($curUser->account_agent)) !== 3 && $curUser->account_coin < $coin) {
            $this->setErrCode(3002);
            $this->setErrMsg('额度不足');
            return false;
        }
        /*
         *1、最后一条上下分记录跟account表的coins字段是同一个事务，没必要重复判断
         *2、数据库结构改变之后，代理给下级上分不会给自己添加一条上下分记录，故屏蔽下面的代码
         **/
        /*//取出用户额度记录
        if (! ($_u_cur['_coin'] = $this->getAgentLastCoin($curUser->account_id))) {
            return false;
        }
        //用户金币额度记录判断
        elseif (abs(intval($curUser->account_agent)) !== 3 && ($_u_cur['_coin']['after'] <= 0 || $_u_cur['_coin']['after'] < $coin)) {
            $this->setErrCode(3002);
            $this->setErrMsg('额度不足');
            return false;
        }*/
        
        /**
         * 目标用户金币
         */
        //取出用户额度记录
        // if (! ($_u_tar['_coin'] = $this->getAgentLastCoin($_u_tar['account_id']))) {
        //     return false;
        // }
        
        //金币变化
        $_data = [
            'account_id'=> $_u_tar['account_id'],
            'agent'=> $_u_tar['account_agent'],
            'type'=> 1,
            'before'=> $_u_tar['account_coin'],
            'coin'=> $coin,
            'after'=> Helper::format_money($_u_tar['account_coin'] + $coin),
            'create_time'=> time(),
            'ipaddr'=> $ipaddr
        ];
        
        $this->mysql->getDb()->insert(MysqlTables::SCORE_LOG, $_data);
        if ($this->mysql->getDb()->getInsertId()) {
            //减
            $this->mysql->getDb()->where('id', $curUser->account_id)->setDec(MysqlTables::ACCOUNT, 'coin', $coin);
            //加
            $this->mysql->getDb()->where('id', $_u_tar['account_id'])->setInc(MysqlTables::ACCOUNT, 'coin', $coin);
            // 更新redis信息
            $this->models->account_model->updateAccountRedis($curUser->account_id);
            $this->models->account_model->updateAccountRedis($_u_tar['account_id']);
        }
        else
        {
            $this->setErrMsg('数据库操作');
            return false;
        }
        
        return true;
    }
    
    /**
     * 代理下分
     * 目标减分，当前加分
     * @param string $username
     * @param string $coin
     * @param string $ipaddr
     * @return boolean
     */
    public function postAgentCoinDown(string $username = '', string $coin = '0', string $ipaddr = '') : bool
    {
        if (! $coin || $coin <= 0) {
            $this->setErrMsg('非法操作');
            return false;
        }
        
        //获取代理
        //获取目标用户
        if (! ($_u_tar = $this->models->account_model->getAgent($username))) {
            $this->setErrMsg('代理不存在');
            return false;
        }
        
        //是否被禁用了账号
        if ($this->models->account_model->checkAccountBan($_u_tar['account_id'])) {
            $this->setErrCode(3003);
            $this->setErrMsg('账号被禁用', true);
            return false;
        }

        //用户金币额度记录判断
        if ($_u_tar['account_coin'] < $coin) {
            $this->setErrCode(3002);
            $this->setErrMsg('额度不足');
            return false;
        }
        
        /**
         * 目标用户金币
         * 出币
         */
        /*//取出用户额度记录
        if (! ($_u_tar['_coin'] = $this->getAgentLastCoin($_u_tar['account_id']))) {
            return false;
        }
        //用户金币额度记录判断
        elseif ($_u_tar['_coin']['after'] <= 0 || $_u_tar['_coin']['after'] < $coin) {
            $this->setErrCode(3002);
            $this->setErrMsg('额度不足');
            return false;
        }*/
        
        $curUser = $this->getTokenObj();
        /**
         * 当前用户金币
         */
        //取出用户额度记录
        // if (! ($_u_cur['_coin'] = $this->getAgentLastCoin($curUser->account_id))) {
        //     return false;
        // }
        
        //金币变化
        $_data = [
            'account_id'=> $_u_tar['account_id'],
            'agent'=> $_u_tar['account_agent'],
            'type'=> 2,
            'before'=> $_u_tar['account_coin'],
            'coin'=> $coin * -1,
            'after'=> Helper::format_money($_u_tar['account_coin'] - $coin),
            'create_time'=> time(),
            'ipaddr'=> $ipaddr
        ];
        
        $this->mysql->getDb()->insert(MysqlTables::SCORE_LOG, $_data);
        
        if ($this->mysql->getDb()->getInsertId()) {
            //减
            $this->mysql->getDb()->where('id', $_u_tar['account_id'])->setDec(MysqlTables::ACCOUNT, 'coin', $coin);
            //加
            $this->mysql->getDb()->where('id', $curUser->account_id)->setInc(MysqlTables::ACCOUNT, 'coin', $coin);
            // 更新redis信息
            $this->models->account_model->updateAccountRedis($curUser->account_id);
            $this->models->account_model->updateAccountRedis($_u_tar['account_id']);
        } else {
            $this->setErrMsg('数据库操作');
            return false;
        }
        
        return true;
    }
    
    /**
     * 获取某一玩家上分总额
     * @param string $account_id
     */
    public function getTotalPlayerCoinUp(string $account_id = '0') : string
    {
        $total = $this->mysql->getDb()->where('account_id', $account_id)
            ->where('type' , 1)
            ->sum(MysqlTables::SCORE_LOG, 'coin');
        
        return $total ? Helper::format_money($total) : Helper::format_money(0);
    }
    
    private function __array_to_object(array $arr) : \stdClass
    {
        foreach ($arr as $k => $v) {
            if (gettype($v) == 'array' || getType($v) == 'object') {
                $arr[$k] = (object)$this->array_to_object($v);
            }
        }
        
        return (object)$arr;
    }
    
    /**
     * 玩家上分
     * 当前减分，目前加分
     * @param string $account
     * @param string $coin
     * @param string $ipaddr
     * @param array $agentUser
     * @return boolean
     */
    public function postPlayerCoinUp(string $account = '', string $coin = '0', string $ipaddr = '', array $agentUser = []) : bool
    {
        if (! $coin || $coin <= Helper::format_money('0')) {
            $this->setErrMsg('非法操作');
            return false;
        }
        
        //获取玩家
        //获取目标用户
        if (! ($_u_tar = $this->models->account_model->getPlayer($account, 0, false, true, false))) {
            $this->setErrMsg('玩家不存在');
            return false;
        }
        
        //是否被禁用了账号
        if ($this->models->account_model->checkAccountBan($_u_tar['account_id'])) {
            $this->setErrCode(3003);
            $this->setErrMsg('账号被禁用', true);
            return false;
        }
        
        if ($agentUser) {
            $curUser = $this->__array_to_object($agentUser);
        } else {
            $curUser = $this->getTokenObj();
        }
        
        /**
         * 当前用户金币
         * 出币
         */
        //用户金币额度字段判断
        if ($curUser->account_coin < $coin) {
            $this->setErrCode(3002);
            $this->setErrMsg('额度不足');
            return false;
        }
        
        /**
         * 目标用户金币
         */
        //向游戏服务器推送数据
        if (! $this->models->curl_model->pushPlayerCoinUp(Random::character(32), $_u_tar['account_id'], $coin, $ipaddr)) {
            $this->setErrMsg($this->models->curl_model->getErrMsssage());
            return false;
        } else {
            //代理减分
            $this->mysql->getDb()->where('id', $curUser->account_id)->setDec(MysqlTables::ACCOUNT, 'coin', $coin);
            // 更新redis信息
            $this->models->account_model->updateAccountRedis($curUser->account_id);
            
            // if (in_array(Config::getInstance()->getConf('APPTYPE'), [1, 2])) {
            //     /**
            //      * 游戏灵魂 - 开始
            //      */
            //     if (!! ($s = $this->models->system_model->getSystemPars('soul_s1_start_ipnum|soul_s1_over_withinhour|soul_s1_over_bettotal|soul_s1_over_wintotal|soul_s1_over_agentwintotal'))) {
            //         //判断还未登录登录，以及首次上分
            //         if (! $_u_tar['account_login_time'] &&
            //             ! $this->mysql->getDb()->where('account_id', $_u_tar['account_id'])->where('type', 1)->has(MysqlTables::SCORE_LOG)) {
            //                 //进入
            //                 //判断代理今日总上分
            //                 if ((int)$this->redis->getDb()->hGet(RedisKey::SOUL_S1_HASH_AGENT_ . $curUser->account_id, date("Ymd")) <= (int)$s['soul_s1_over_agentwintotal']) {
            //                     //进入
            //                     $this->redis->getDb()->sAdd(RedisKey::SOUL_S1_SET_ACCOUNTS, $_u_tar['account_id']);
            //                     $this->redis->getDb()->hIncrByFloat(RedisKey::SOUL_S1_HASH_AGENT_ . $curUser->account_id, date("Ymd"), $coin);
            //                 }
            //             }
            //             //非首次上分，取消权益
            //             elseif (//是否属于活动账号+是否在有效期内
            //                 !! ($vt = $this->redis->getDb()->zScore(RedisKey::SOUL_S1_SSET_ACCOUNTS, $_u_tar['account_id'])) &&
            //                 //是否在有效期内
            //                 $vt > time()) {
            //                     //移除小赢概率
            //                     if ($this->models->account_model->putSoulS1Prob($_u_tar['account_id'], 1)) {
            //                         //取消有效资格
            //                         $this->redis->getDb()->zAdd(RedisKey::SOUL_S1_SSET_ACCOUNTS, 0, $_u_tar['account_id']);
            //                         $this->mysql->getDb()->where('account_id', $_u_tar['account_id'])->update(MysqlTables::SOUL_S1_ACCOUNT, ['available'=> 0]);
            //                     }
            //             }
            //     }
            //     //游戏灵魂 - 结束
            // }
        }
        
        return true;
    }
    
    public function postPlayerCoinUpNotNotice(string $account = '', string $coin = '0') : bool
    {
        if (! $coin || $coin <= 0) {
            $this->setErrMsg('非法操作');
            return false;
        }
        
        //获取玩家
        //获取目标用户
        //此处不能同步到redis，因为创建代理上分的时候，可能失败
        if (! ($_u_tar = $this->models->account_model->getPlayer($account, 0, false, false, false))) {
            $this->setErrMsg('玩家不存在');
            return false;
        }
        
        $curUser = $this->getTokenObj();
        /**
         * 当前用户金币
         * 出币
         */
        //用户金币额度字段判断
        if ($curUser->account_coin < $coin) {
            $this->setErrCode(3002);
            $this->setErrMsg('额度不足');
            return false;
        }
        
        //取出用户额度记录
        /*if (! ($_u_cur['_coin'] = $this->getAgentLastCoin($curUser->account_id))) {
            return false;
        }
        //用户金币额度记录判断
        elseif ($_u_cur['_coin']['after'] <= 0 || $_u_cur['_coin']['after'] < $coin)
        {
            $this->setErrCode(3002);
            $this->setErrMsg('额度不足');
            return false;
        }*/
        
        /**
         * 目标用户金币
         */
        //取出用户额度记录
        // if (! ($_u_tar['_coin'] = $this->getPlayerLastCoin($_u_tar['account_id'])))
        // {
        //     return false;
        // }
        
        //代理减分
        $this->mysql->getDb()->where('id', $curUser->account_id)->setDec(MysqlTables::ACCOUNT, 'coin', $coin);
        // 更新redis信息
        $this->models->account_model->updateAccountRedis($curUser->account_id);
        
        /**
         * 游戏灵魂 - 开始
         */
        if (!! ($s = $this->models->system_model->getSystemPars('soul_s1_start_ipnum|soul_s1_over_withinhour|soul_s1_over_bettotal|soul_s1_over_wintotal|soul_s1_over_agentwintotal'))) {
            //判断还未登录登录，以及首次上分
            if (! $_u_tar['account_login_time'] &&
                ! $this->mysql->getDb()->where('account_id', $_u_tar['account_id'])->where('type', 1)->has(MysqlTables::SCORE_LOG)) {
                    //进入
                    //判断代理今日总上分
                    if ((int)$this->redis->getDb()->hGet(RedisKey::SOUL_S1_HASH_AGENT_ . $curUser->account_id, date("Ymd")) <= (int)$s['soul_s1_over_agentwintotal']) {
                        //进入
                        $this->redis->getDb()->sAdd(RedisKey::SOUL_S1_SET_ACCOUNTS, $_u_tar['account_id']);
                        $this->redis->getDb()->hIncrByFloat(RedisKey::SOUL_S1_HASH_AGENT_ . $curUser->account_id, date("Ymd"), $coin);
                    }
            }
        }
        //游戏灵魂 - 结束
        
        return true;
    }
    
    /**
     * 玩家下分
     * 目标减分，当前加分
     * @param string $account
     * @param string $coin
     * @param string $ipaddr
     * @return boolean
     */
    public function postPlayerCoinDown(string $account = '', string $coin = '0', string $ipaddr = '')
    {
        if (! $coin || $coin <= Helper::format_money('0')) {
            $this->setErrMsg('非法操作');
            return false;
        }
        
        //获取玩家
        //获取目标用户
        if (! ($_u_tar = $this->models->account_model->getPlayer($account, 0, false, true, false))) {
            $this->setErrMsg('玩家不存在');
            return false;
        }
        
        //是否被禁用了账号
        if ($this->models->account_model->checkAccountBan($_u_tar['account_id'])) {
            $this->setErrCode(3003);
            $this->setErrMsg('账号被禁用', true);
            return false;
        }
        
        //用户金币额度记录判断
        if ($_u_tar['account_coin'] < $coin) {
            $this->setErrCode(3002);
            $this->setErrMsg('额度不足');
            return false;
        }
        
        /**
         * 目标用户金币
         * 出币
         */
        $curUser = $this->getTokenObj();
        /**
         * 当前用户金币
         */
        //向游戏服务器推送数据
        if (! $this->models->curl_model->pushPlayerCoinDown(Random::character(32), $_u_tar['account_id'], $coin, $ipaddr)) {
            $this->setErrMsg($this->models->curl_model->getErrMsssage());
            return false;
        } else {
            //代理加分
            $this->mysql->getDb()->where('id', $curUser->account_id)->setInc(MysqlTables::ACCOUNT, 'coin', $coin);
            // 更新redis信息
            $this->models->account_model->updateAccountRedis($curUser->account_id);
        }
        
        return true;
    }
    
    /**
     * 获取代理上下分记录
     * @param number $page
     * @param array $par
     * @return array|bool
     */
    public function getAgentCoins($page = 0, $par = [])
    {
        $curUser = $this->getTokenObj();
        $_limit_value = 10;
        $_limit_offset = ($page = abs(intval($page))) > 0 ? ($page - 1) * $_limit_value : 0;
        $result = ['total'=> 0, 'cointotal'=> 0, 'page'=> ! $page ? 1 : $page, 'limit'=> $_limit_value, 'list'=> []];
        $_table_user_coinlog_fields_ar = ['coin_befor', 'coin_after', 'coin_change', 'coin_time'];
        $fieldstrs = "
                        c.before AS coin_befor,
                        c.after AS coin_after,
                        c.coin AS coin_change,
                        c.create_time AS coin_time,
                        a.username,
                        c.account_id,
                        c.ipaddr,
                        a.parent_id
                    ";
        //orderby 排序字段
        if (isset($par['orderby']) && $par['orderby'] && $orderby = $par['orderby']) {
            list($_od_f, $_od_b) = explode("|", $orderby);
            $_od_f = in_array($_od_f, $_table_user_coinlog_fields_ar) ? $_od_f : false;
            $_od_b = strtoupper($_od_b);
            if ($_od_f === false || ! $_od_b || ! in_array($_od_b, ['DESC', 'ASC'])) {
                $this->setErrMsg('orderby参数非法');
                return false;
            }
            $orderby = [$_od_f, $_od_b];
        } else {
            $orderby = ['c.id', 'DESC'];
        }
        
        //获取当前账号的子代理
        //$childAgents = $this->mysql->getDb()->where('parent_id', $curUser->account_id)->get(MysqlTables::ACCOUNT, null, 'id');
        //$accountIDS = array_column($childAgents, 'id');
        
        $db = $this->mysql->getDb()->join('account as a', 'c.account_id=a.id', 'left')->where('c.agent', 0, '>');
        
        //where 代理用户名
        if (isset($par['username']) && $par['username']) {
            $db->where('a.username', $par['username'])->where('a.parent_id', $curUser->account_id);
        }

        //where 时间段
        if (isset($par['times']) && $par['times']) {
            list($_ts, $_te) = explode(".", $par['times']);
            $db->where('c.create_time', [$_ts, $_te], 'BETWEEN');
        }
        //在第一页返回总上下分
        if ($page == 1) {
            $db_clone1 = clone $db;
            $result['cointotal'] = $db_clone1->sum('score_log as c', "c.coin");
        }
        $list = $db->orderBy($orderby[0], $orderby[1])->withTotalCount()->get('score_log as c', [$_limit_offset, $_limit_value], $fieldstrs);
        if (empty($list)) {
            return $result;
        }
        $result['total'] = $db->getTotalCount();
        $parent_ids = array_unique(array_column($list, 'parent_id'));
        // 获取上级
        $parentAccount = $this->mysql->getDb()->whereIn('id', $parent_ids)->get(MysqlTables::ACCOUNT, null, 'id, username');
        $parentAccount = array_column($parentAccount, 'username', 'id');
        foreach ($list as &$one) {
            $one['from_username'] = isset($parentAccount[$one['parent_id']]) ? $parentAccount[$one['parent_id']] : '';
            $one['to_username'] = $one['username'];
        }
        $result['list'] = $list;
        
        return $result;
    }
    
    /**
     * 获取单个玩家某个时间段的总上分和总下分
     * @param $account
     * @param $time
     * @return array
     */
    public function getPlayerCoin($account = '', $time = '')
    {
        $result = ['reload' => '0' /*上分*/, 'withdraw' => '0' /*下分*/];
        
        if ($this->getAbutmentKey('isOpenApi')) {
            if ($time['end_time'] < $time['start_time'] || $time['end_time'] - $time['start_time'] > 2592000) {
                $this->setErrMsg('时间范围错误');
                return $result;
            }
            $startTime = $time['start_time'];
            $endTime = $time['end_time'];
        } else {
            list($startTime, $endTime) = explode(".", $time);
        }
        $db = $this->mysql->getDb()->where('a.pid', Helper::account_format_login($account))
        ->join('score_log as c', "a.id=c.account_id AND c.create_time BETWEEN {$startTime} AND {$endTime}", 'left');
        $result = $db->getOne('account as a', 'SUM(IF(c.type=1, c.coin, 0)) AS reload, SUM(IF(c.type=2, (-1) * c.coin, 0)) AS withdraw');
        
        return $result;
    }
    
    /**
     * 获取玩家上下分记录
     * @param number $page
     * @param array $par
     * @return array|bool
     */
    public function getPlayerCoins($page = 0, $par = [])
    {
        $curUser = $this->getTokenObj();
        $_limit_value = 10;
        $_limit_offset = ($page = abs(intval($page))) > 0 ? ($page - 1) * $_limit_value : 0;
        $result = ['total'=> 0, 'page'=> ! $page ? 1 : $page, 'limit'=> $_limit_value, 'list'=> []];
        $_table_user_coinlog_fields_ar = ['coin_befor', 'coin_after', 'coin_change', 'coin_time'];
                                // c.coin AS coin_change,
        $fieldstrs = "
                        c.before AS coin_befor,
                        c.after AS coin_after,
                        if(c.type=2, (-1)*c.coin, c.coin) as coin_change,
                        c.create_time AS coin_time,
                        c.type AS con_type,
                        c.account_id,
                        c.ipaddr,
                        a.pid,
                        a.parent_id
                    ";
        //orderby 排序字段
        if (isset($par['orderby']) && $par['orderby'] && $orderby = $par['orderby']) {
            list($_od_f, $_od_b) = explode("|", $orderby);
            $_od_f = in_array($_od_f, $_table_user_coinlog_fields_ar) ? $_od_f : false;
            $_od_b = strtoupper($_od_b);
            if ($_od_f === false || ! $_od_b || ! in_array($_od_b, ['DESC', 'ASC'])) {
                $this->setErrMsg('orderby参数非法');
                return false;
            }
            $orderby = [$_od_f, $_od_b];
        } else {
            $orderby = ['c.id', 'DESC'];
        }
        $db = $this->mysql->getDb()->join('account as a', 'c.account_id=a.id', 'left')->where('c.agent', 0);
        //where 玩家pid
        if (isset($par['account']) && ($par['account'] = Helper::account_format_login($par['account']))) {
            $db->where('a.pid', $par['account'])->where('a.parent_id', $curUser->account_id);
        }
        
        if ($this->getAbutmentKey('isOpenApi')) {
            if ($par['end_time'] < $par['start_time'] || $par['end_time'] - $par['start_time'] > 2592000) {
                $this->setErrMsg('时间范围错误');
                return false;
            }
        }
        
        //where 时间段
        if (isset($par['times']) && $par['times']) {
            list($_ts, $_te) = explode(".", $par['times']);
            $db->where("(c.create_time>{$_ts} AND c.create_time<{$_te})");
        }
        //在第一页返回总上下分
        if ($page == 1) {
            $db_clone1 = clone $db;
            $result['cointotal'] = $db_clone1->sum('score_log as c', "if(c.type=2, (-1)*c.coin, c.coin)");
        }
        $list = $db->orderBy($orderby[0], $orderby[1])->withTotalCount()->get('score_log as c', [$_limit_offset, $_limit_value], $fieldstrs);
        if (empty($list)) {
            return $result;
        }
        $result['total'] = $db->getTotalCount();
        $parent_ids = array_unique(array_column($list, 'parent_id'));
        // 获取上级
        $parentAccount = $this->mysql->getDb()->whereIn('id', $parent_ids)->get(MysqlTables::ACCOUNT, null, 'id, username');
        $parentAccount = array_column($parentAccount, 'username', 'id');
        foreach ($list as &$one) {
            $one['from_username'] = isset($parentAccount[$one['parent_id']]) ? $parentAccount[$one['parent_id']] : '';
            $one['to_username'] = $one['pid'];
        }
        
        if ($this->getAbutmentKey('isOpenApi')) {
            $openAPiList = [];
            foreach ($list as $l) {
                $openAPiList[] = [
                    'coin_befor'=> (string)$l['coin_befor'],
                    'coin_update'=> (string)(($l['con_type'] == 1 ? '' : '-') . (string)$l['coin_change']),
                    'coin_after'=> (string)$l['coin_after'],
                    'coin_time'=> (string)$l['coin_time']
                ];
            }
            $result['list'] = $openAPiList;
        } else {
            $result['list'] = $list;
        }
        
        return $result;
    }
    
    /**
     * 获取玩家游戏记录
     * @param number $page
     * @param array $par
     * @return array|bool
     */
    public function getOpenApiPlayerBets($page = 0, $par = [])
    {
        $curUser = $this->getTokenObj();
        
        //游戏列表
        $games = [];
        $_games = $this->models->curl_model->getGameLists(1);
        if (is_array($_games) && count($_games) && isset($_games[0]['id'])) {
            foreach ($_games as $g) {
                if ($g['id'] <= 1000) {
                    $games[$g['id']] = $g['name'];
                }
            }
        }
        if (!$games) {
            $this->setErrMsg('游戏列表不存在', true);
            return false;
        }
        
        $_limit_value = 10;
        $_limit_offset = ($page = abs(intval($page))) > 0 ? ($page - 1) * $_limit_value : 0;
        $result = ['total'=> 0, 'page'=> ! $page ? 1 : $page, 'limit'=> $_limit_value, 'list'=> []];
        $_table_user_coinlog_fields_ar = ['coin_befor', 'coin_after', 'coin_change', 'coin_time'];
        $fieldstrs = "
                        a.appuid AS game_account,
                        gl.game_id AS game_gamename,
                        gl.bet AS game_bet,
                        gl.win AS game_win,
                        gl.create_time AS game_create_time,
                        gl.before AS game_coin_before,
                        gl.after AS game_coin_after
                    ";
        //orderby 排序字段
        if (isset($par['orderby']) && $par['orderby'] && $orderby = $par['orderby']) {
            list($_od_f, $_od_b) = explode("|", $orderby);
            $_od_f = in_array($_od_f, $_table_user_coinlog_fields_ar) ? $_od_f : false;
            $_od_b = strtoupper($_od_b);
            if ($_od_f === false || ! $_od_b || ! in_array($_od_b, ['DESC', 'ASC'])) {
                $this->setErrMsg('orderby参数非法');
                return false;
            }
            $orderby = [$_od_f, $_od_b];
        } else {
            $orderby = ['gl.id', 'DESC'];
        }
        $db = $this->mysql->getDb()->join('account as a', 'gl.account_id=a.id', 'left')
        ->where('gl.bet', 0, '>')
        ->where('a.pid', $par['account']);
        
        if ($this->getAbutmentKey('isOpenApi')) {
            if ($par['end_time'] < $par['start_time'] || $par['end_time'] - $par['start_time'] > 2592000) {
                $this->setErrMsg('时间范围错误');
                return false;
            }
        }
        
        $list = $db->orderBy($orderby[0], $orderby[1])->withTotalCount()->get('gameserver_gamelog as gl', [$_limit_offset, $_limit_value], $fieldstrs);
        if (empty($list)) {
            return $result;
        }
        $result['total'] = $db->getTotalCount();
        foreach ($list as &$one) {
            $one['game_gamename'] = $games[$one['game_gamename']] ?? '--';
            $one['game_bet'] = '-' . $one['game_bet'];
            $one['game_create_time'] = (string)$one['game_create_time'];
        }
        $result['list'] = $list;
        
        return $result;
    }
    
    /**
     * 获取玩家上下分记录
     * @param string $_times
     * @param string $_orderby
     * @param string $_page
     * @param string $_limit
     * @param string $_type
     * @return array
     */
    public function getPlayerTransfer(string $_times = "", string $_orderby = "", string $_page = '0', string $_limit = '0', string $_type = '') : array
    {
        //分页
        $_limit_value = $_limit ?: 10;
        $_limit_offset = ($_page = abs(intval($_page))) > 0 ? ($_page - 1) * $_limit_value : 0;
        //结果集
        $result = ['total'=> 0, 'page'=> ! $_page ? 1 : $_page, 'limit'=> $_limit_value, 'list'=> []];
        if (! ($_W_time = "") && $_times) {
            list($_ts, $_te) = explode(".", $_times);
            $_W_time = "(c.create_time>{$_ts} AND c.create_time<{$_te})";
        }
        
        if ($_type == 'normal') {
            
            $_table_user_coinlog_fields_ar = [];
            $_table_user_coinlog_fields = $this->getTableFields(MysqlTables::SCORE_LOG, ['c', ['coin_', &$_table_user_coinlog_fields_ar]], ['type','before','coin','after','create_time']);
            $fieldstrs = implode(",", $_table_user_coinlog_fields);
            if ($_orderby) {
                list($_od_f, $_od_b) = explode("|", $_orderby);
                $_od_f = in_array($_od_f, $_table_user_coinlog_fields_ar) && ($_od_f = str_replace(['coin_'], ['c.'], $_od_f)) ? $_od_f : false;
                $_od_b = strtoupper($_od_b);
                if ($_od_f === false || ! $_od_b || ! in_array($_od_b, ['DESC', 'ASC'])) {
                    $this->setErrMsg('orderby参数非法');
                    return [];
                }
                $orderby = [$_od_f, $_od_b];
            } else {
                $orderby = ['c.id', 'DESC'];
            }
            $db = $this->mysql->getDb()->where('c.agent', 0)
            ->where("(c.account_id={$this->getTokenObj()->account_id})");
            if ($_W_time) {
                $db->where($_W_time);
            }
            $db->orderBy($orderby[0], $orderby[1]);
            $rds = $db->withTotalCount()->get('score_log as c', [$_limit_offset, $_limit_value], $fieldstrs);
            
            $result['total'] = $db->getTotalCount();
            foreach ($rds as $_r) {
                //$_code_s = in_array($_r['coin_code'], ['B003']);
                $result['list'][] = [
                    'coin_befor'=> $_r['coin_before'],
                    'coin_after'=> $_r['coin_after'],
                    'coin_change'=> $_r['coin_type'] == 1 ? $_r['coin_coin'] : $_r['coin_coin'] * -1,
                    'coin_time'=> $_r['coin_create_time']
                ];
            }
            
        } elseif ($_type == 'relation') {
            
            $db = $this->mysql->getDb()->join('account as a', 'l.to_account_id=a.id', 'left')->where('l.from_account_id', $this->getTokenObj()->account_id);
            $rds = $db->withTotalCount()->get('score_relation_log as l', [$_limit_offset, $_limit_value], 'a.id,a.pusername,a.pid,l.coin,l.create_time');
            $result['total'] = $db->getTotalCount();
            foreach ($rds as $_r) {
                $result['list'][] = [
                    'account_id'=> $_r['id'],
                    'username'=> $_r['pusername'] ?: $_r['pid'],
                    'account'=> $_r['pid'],
                    'coin'=> $_r['coin'],
                    'time'=> $_r['create_time']
                ];
            }
            
        }
        
        return $result;
    }
    
    public function getPlayerProfit(string $_times = "", string $_orderby = "", string $_page = '0', string $_limit = '0')
    {
        //分页
        $_limit_value = $_limit ?: 10;
        $_limit_offset = ($_page = abs(intval($_page))) > 0 ? ($_page - 1) * $_limit_value : 0;
        //结果集
        $result = ['total'=> 0, 'page'=> ! $_page ? 1 : $_page, 'limit'=> $_limit_value, 'list'=> []];
        if (! ($_W_time = "") && $_times) {
            list($_ts, $_te) = explode(".", $_times);
            $_W_time = "(c.create_time>{$_ts} AND c.create_time<{$_te})";
        }
        $_table_user_coinlog_fields_ar = [];
        $_table_user_coinlog_fields = $this->getTableFields(MysqlTables::LOG_PROFIT_PLAYER, ['c', ['coin_', &$_table_user_coinlog_fields_ar]], ['coin','create_time']);
        $fieldstrs = implode(",", $_table_user_coinlog_fields);
        if ($_orderby) {
            list($_od_f, $_od_b) = explode("|", $_orderby);
            $_od_f = in_array($_od_f, $_table_user_coinlog_fields_ar) && ($_od_f = str_replace(['coin_'], ['c.'], $_od_f)) ? $_od_f : false;
            $_od_b = strtoupper($_od_b);
            if ($_od_f === false || ! $_od_b || ! in_array($_od_b, ['DESC', 'ASC'])) {
                $this->setErrMsg('orderby参数非法');
                return false;
            }
            $orderby = [$_od_f, $_od_b];
        } else {
            $orderby = ['c.id', 'DESC'];
        }
        $db = $this->mysql->getDb()->where('c.t', 2)
        ->where("(c.account_id={$this->getTokenObj()->account_id})");
        if ($_W_time) {
            $db->where($_W_time);
        }
        $db->orderBy($orderby[0], $orderby[1]);
        $rds = $db->withTotalCount()->get('log_profit_player as c', [$_limit_offset, $_limit_value], $fieldstrs);
        $result['total'] = $db->getTotalCount();
        foreach ($rds as $_r) {
            $result['list'][] = [
                'coin_coin'=> $_r['coin_coin'],
                'coin_time'=> $_r['coin_create_time']
            ];
        }
        
        return $result;
    }
    
    /**
     * 获取余额记录
     * @param number $id
     * @param array $account
     * @param bool $isagent
     * @return array|bool
     */
    public function getLastCoin($id = 0, $account = [], $isagent = false)
    {
        $result = ['id'=> $id, 'uid'=> $id, 'username'=> null, 'pid'=> null, 'agent'=> null, 'befor'=> 0, 'after'=> 0, 'change'=> 0];
        
        //获取账号信息
        if (! $account)
        {
            if ($isagent) {
                $account = $this->models->account_model->getAgent(null, $id)/* 获取代理 */;
            } else {
                $account = $this->models->account_model->getPlayer(null, $id)/* 获取玩家 */;
            }
        }
        
        if (($result['id'] = $result['uid'] = isset($account['account_id']) ? $account['account_id'] : null) !== null)
        {
            $result['username'] = isset($account['account_username']) ? $account['account_username'] : null;
            $result['pid'] = isset($account['account_pid']) ? $account['account_pid'] : null;
        }
        else
        {
            $this->setErrMsg('账号不存在');
            return false;
        }
        
        $_r = $this->mysql->getDb()
        ->where('account_id', $account['account_id'])
        ->orderBy('id', 'DESC')->getOne(MysqlTables::COINS_PLAYER, 'id,`before`,coin,`after`');
        
        if (isset($_r['id']))
        {
            $result['befor'] = $_r['before'];
            $result['after'] = $_r['after'];
            $result['change'] = $_r['coin'];
        }
        
        return $result;
    }
    
    public function getAgentLastCoin(string $id = '0', array $account = []) : array
    {
        $result = ['id'=> $id, 'uid'=> $id, 'username'=> null, 'pid'=> null, 'agent'=> null, 'befor'=> 0, 'after'=> 0, 'change'=> 0];
        
        //获取账号信息
        if (! $account)
        {
            $account = $this->models->account_model->getAgent(null, $id)/* 获取代理 */;
        }
        
        if (($result['id'] = $result['uid'] = isset($account['account_id']) ? $account['account_id'] : null) !== null)
        {
            $result['username'] = isset($account['account_username']) ? $account['account_username'] : null;
            $result['pid'] = isset($account['account_pid']) ? $account['account_pid'] : null;
        }
        else
        {
            $this->setErrMsg('账号不存在');
            return false;
        }
        
        $_r = $this->mysql->getDb()
        ->where('account_id', $account['account_id'])
        ->where('agent', 0, '>')
        ->orderBy('id', 'DESC')->getOne(MysqlTables::SCORE_LOG, 'id,`before`,coin,`after`');
        
        if (isset($_r['id']))
        {
            $result['befor'] = $_r['before'];
            $result['after'] = $_r['after'];
            $result['change'] = $_r['coin'];
        }
        
        return $result;
    }
    
    public function getPlayerLastCoin(string $id = '0', array $account = []) : array
    {
        $result = ['id'=> $id, 'uid'=> $id, 'username'=> null, 'pid'=> null, 'agent'=> null, 'befor'=> 0, 'after'=> 0, 'change'=> 0];
        
        //获取账号信息
        if (! $account) {
            $account = $this->models->account_model->getPlayer(null, $id)/* 获取玩家 */;
        }
        
        if (($result['id'] = $result['uid'] = isset($account['account_id']) ? $account['account_id'] : null) !== null) {
            $result['username'] = isset($account['account_username']) ? $account['account_username'] : null;
            $result['pid'] = isset($account['account_pid']) ? $account['account_pid'] : null;
        } else {
            $this->setErrMsg('账号不存在');
            return false;
        }
        
        $_r = $this->mysql->getDb()
        ->where('account_id', $account['account_id'])
        ->orderBy('id', 'DESC')->getOne(MysqlTables::COINS_PLAYER, 'id,`before`,coin,`after`');
        
        if (isset($_r['id'])) {
            $result['befor'] = $_r['before'];
            $result['after'] = $_r['after'];
            $result['change'] = $_r['coin'];
        }
        
        return $result;
    }
    
    public function postPlayerGamePool($logs = '') : bool
    {
        if (is_array($_logs = json_decode($logs, true))) {
            try {
                $_logs['create_time'] = time();
                $this->mysql->getDb()->insert(MysqlTables::GAMESERVER_GAMEPOOL, $_logs);
                if (! $this->mysql->getDb()->getInsertId()) {
                    Logger::getInstance()->log(PHP_EOL . 'DB插入记录失败' . PHP_EOL . $logs, 'queue-gpool-fail');
                    return false;
                }
                //处理池子分水
                if ($_logs['wather'] > 0) {
                    //获取入池数据
                    $wather = $_logs['wather'] < 0 ? $_logs['wather'] * -1 : $_logs['wather'];
                    //仅BB或POLY开启此逻辑
                    if (in_array(Config::getInstance()->getConf('APPTYPE'), [1])) {
                        //抽取佣金
                        if (!! ($player = $this->models->account_model->getPlayer(null, $_logs['account_id'], false, false, false))
                            && isset($player['account_ppromoters'])
                            && intval($player['account_ppromoters']) > 0
                            && $player['account_prelation_parents']
                            //祖先
                            && !! ($prelation_parents = Helper::is_json_str($player['account_prelation_parents']))
                        ) {
                            //系统参数
                            if(!! ($_syspars = $this->models->system_model->_getRedisSystemParameters()) && $_syspars['promoter_profit_switch']) {
                                $watherN = $wather;
                                //佣金
                                $commission = $wather * ($_syspars['promoter_profit_par']/100);
                                $promoter_profit_plsit = json_decode($_syspars['promoter_profit_plsit'], true);
                                //佣金分配
                                $commissions = [];
                                foreach ($promoter_profit_plsit as $pkey=> $plan) {
                                    if (isset($prelation_parents[$pkey])) {
                                        if (($c = $commission * ($plan/100)) >= '0.000001') {
                                            $commissions[] = [
                                                't'=> 1,
                                                'account_id'=> $prelation_parents[$pkey]['account_id'],
                                                'relation_account_id'=> $_logs['account_id'],
                                                'tree_depth'=> $prelation_parents[$pkey]['height'] -1,
                                                'bet'=> $wather,
                                                'coin'=> Helper::format_money($c, '%.6f'),
                                                'log_id'=> $_logs['log_id'],
                                                'create_time'=> time()
                                            ];
                                            $watherN = Helper::format_money(($watherN - $c) , '%.6f');
                                        } else {
                                            $commissions[] = [
                                                't'=> 1,
                                                'account_id'=> $prelation_parents[$pkey]['account_id'],
                                                'relation_account_id'=> $_logs['account_id'],
                                                'tree_depth'=> $prelation_parents[$pkey]['height'] - 1,
                                                'bet'=> $wather,
                                                'coin'=> Helper::format_money('0'),
                                                'log_id'=> $_logs['log_id'],
                                                'create_time'=> time()
                                            ];
                                        }
                                    }
                                }
                                //处理佣金记录
                                if ($commissions) {
                                    $wather = $watherN;
                                    //批量写入佣金记录
                                    $this->mysql->getDb()->insertMulti(MysqlTables::LOG_PROFIT_PLAYER, $commissions);
                                    //账号的pprofit_balance和pprofit_total字段值增加
                                    foreach ($commissions as $citem) {
                                        if ($citem['coin'] > Helper::format_money('0', '%.6f')) {
                                            $_c = $this->mysql->getDb()->where('id', $citem['account_id'])->getValue(MysqlTables::ACCOUNT, 'pprofit_balance');
                                            $_tc = $this->mysql->getDb()->where('id', $citem['account_id'])->getValue(MysqlTables::ACCOUNT, 'pprofit_total');
                                            if (!$_c) {
                                                $_c = '0';
                                            }
                                            if (!$_tc) {
                                                $_tc = '0';
                                            }
                                            $this->mysql->getDb()->where('id', $citem['account_id'])->update(MysqlTables::ACCOUNT, [
                                                'pprofit_balance'=> $_c + $citem['coin'],
                                                'pprofit_total'=> $_tc + $citem['coin']
                                            ]);
                                        }
                                    }
                                }
                            }
                        }
                    }
                    //进入系统抽水逻辑
                    if (!! ($_poolDatas = $this->_getPoolDatas($wather))
                        && ($_poolDatas['sys_tax'] || $_poolDatas['sys_jppool'] || $_poolDatas['sys_mainpool'])
                    ) {
                        //TAX池
                        if ($_poolDatas['sys_tax']) {
                            $insertData = [];
                            $insertData['log_id'] = $_logs['log_id'];
                            $insertData['account_id'] = $_logs['account_id'];
                            $insertData['game_id'] = $_logs['game_id'];
                            $insertData['type'] = 1;
                            $insertData['coin'] = $_poolDatas['sys_tax'];
                            $insertData['create_time'] = time();

                            $this->redis->getDb()->lpush(RedisKey::LOGS_INNER_POOL_TAX, json_encode($insertData));
//                            $this->mysql->getDb()->insert(MysqlTables::POOL_TAX, $insertData);
//                            if (! $this->mysql->getDb()->getInsertId()) {
//                                Logger::getInstance()->log(PHP_EOL . '数据入 TAX池(' . $_poolDatas['sys_tax'] . ') 失败' . PHP_EOL . $logs, 'queue-gpool-fail');
//                            }
                        }
                        //JP池
                        if ($_poolDatas['sys_jppool']) {
                            $insertData = [];
                            $insertData['log_id'] = $_logs['log_id'];
                            $insertData['account_id'] = $_logs['account_id'];
                            $insertData['game_id'] = $_logs['game_id'];
                            $insertData['type'] = 1;
                            $insertData['coin'] = $_poolDatas['sys_jppool'];
                            $insertData['create_time'] = time();
                            $this->redis->getDb()->lpush(RedisKey::LOGS_INNER_POOL_JP, json_encode($insertData));

//                            $this->mysql->getDb()->insert(MysqlTables::POOL_JP, $insertData);
//                            if (! $this->mysql->getDb()->getInsertId()) {
//                                Logger::getInstance()->log(PHP_EOL . '数据入 JP池(' . $_poolDatas['sys_jppool'] . ') 失败' . PHP_EOL . $logs, 'queue-gpool-fail');
//                            }
                        }
                        //彩池
                        if ($_poolDatas['sys_mainpool']) {
                            $insertData = [];
                            $insertData['log_id'] = $_logs['log_id'];
                            $insertData['account_id'] = $_logs['account_id'];
                            $insertData['game_id'] = $_logs['game_id'];
                            $insertData['type'] = 1;
                            $insertData['coin'] = $_poolDatas['sys_mainpool'];
                            $insertData['create_time'] = time();
                            $this->redis->getDb()->lpush(RedisKey::LOGS_INNER_POOL_NORMAL, json_encode($insertData));

//                            $this->mysql->getDb()->insert(MysqlTables::POOL_NORMAL, $insertData);
//                            if (! $this->mysql->getDb()->getInsertId()) {
//                                Logger::getInstance()->log(PHP_EOL . '数据入 彩池(' . $_poolDatas['sys_mainpool'] . ') 失败' . PHP_EOL . $logs, 'queue-gpool-fail');
//                            }
                        }
                    } else {
                        Logger::getInstance()->log(PHP_EOL . '没有任何数据进入池子' . PHP_EOL . $logs, 'queue-gpool-fail');
                    }
                    //TAX池抹除记录
                    if (isset($_poolDatas['sys_doreset']) && $_poolDatas['sys_doreset']) {
                        $insertData = [];
                        $insertData['log_id'] = 0;
                        $insertData['account_id'] = $_logs['account_id'];
                        $insertData['game_id'] = $_logs['game_id'];
                        $insertData['type'] = 2;
                        $insertData['coin'] = $_poolDatas['sys_doreset'] * -1;
                        $insertData['create_time'] = time();
                        $this->redis->getDb()->lpush(RedisKey::LOGS_INNER_POOL_TAX, json_encode($insertData));

//                        $this->mysql->getDb()->insert(MysqlTables::POOL_TAX, $insertData);
//                        if (! $this->mysql->getDb()->getInsertId()) {
//                            Logger::getInstance()->log(PHP_EOL . '更新 TAX池自动抹除(' . $_poolDatas['sys_doreset'] . ') 失败' . PHP_EOL . $logs, 'queue-gpool-fail');
//                        }
                    }
                } else {
                    Logger::getInstance()->log(PHP_EOL . 'wather字段异常' . PHP_EOL . $logs, 'queue-gpool-fail');
                }
                return true;
            } catch (\Exception $e) {
                Logger::getInstance()->log(PHP_EOL . 'DB 异常 >>>>>>>>>>>>>>>>' . $e->getMessage() . PHP_EOL . $logs, 'queue-gpool-fail');
                return false;
            }
        } else {
            Logger::getInstance()->log(PHP_EOL . '无法解析游戏完整JSON数据' . PHP_EOL . $logs, 'queue-gpool-fail');
        }
        
        return false;
    }

    //直接执行sql
    public function exeSql($sql = '') :bool
    {
        $this->mysql->getDb()->rawQuery($sql);
        return true;
    }

    /**
     * 按天记录在线玩家的输赢金币
     */
    public function postCoinsPlayerDay($account_id, $coin, $day, $type):bool
    {
        $uniqid = $day.'_'.$account_id;
        $sql = "INSERT INTO coins_player_day (uniqid,account_id,create_time,win) VALUE ('{$uniqid}',$account_id, $day, '{$coin}') ON DUPLICATE KEY UPDATE win=win+{$coin}";
        if($type == 5) {
            $sql = "INSERT INTO coins_player_day (uniqid,account_id,create_time,win,bigbang) VALUE ('{$uniqid}',$account_id, $day, '{$coin}', '{$coin}') ON DUPLICATE KEY UPDATE win=win+{$coin},bigbang=bigbang+{$coin}";
        }
        return $this->exeSql($sql);
    }
    
    public function postCoinsPlayer($logs = '') : bool
    {
        //日志名称
        $logname = 'queue-coins-player-fail';
        
        try {
            $start_time = microtime(true);
                $_logs = $logs;

                
//            if (is_array($_logs = json_decode($logs, true))) {
                $flag_player = true;
                //查找玩家
                if (! isset($logs['account_id']) || ! ($_u_tar = $this->models->account_model->getPlayer(null, intval($logs['account_id'])))) {
                    $flag_player = false;
                    Logger::getInstance()->log(PHP_EOL . '玩家不存在' . PHP_EOL . json_encode($logs), $logname);
                }
                //余额对账
//                if (! $flag_player || ! ($_u_tar['_coin'] = $this->getPlayerLastCoin(0, $_u_tar)) || Helper::format_money($_logs['before']) != Helper::format_money($_u_tar['_coin']['after'])) {
//                    Logger::getInstance()->log(PHP_EOL . '余额对账失败' . PHP_EOL . 'API :' . ($_u_tar['_coin']['after'] ?? '获取余额失败') . ' GAME:' . $_logs['before'] . PHP_EOL . $logs, $logname);
//                }
                //扩展字段
                $ext1 = $logs['ext1'] ?? ($logs['extend1'] ?? '');
                unset($logs['ext1']);
                //IP地址
                $ipaddr = $logs['ipaddr'] ?? '';
                unset($logs['ipaddr']);
                //DB落地队列数据
                /*
                $_logs['create_time'] = time();
                $this->mysql->getDb()->insert(MysqlTables::COINS_PLAYER, $_logs);
                Logger::getInstance()->log(PHP_EOL . 'postCoinsPlayer3 ' . microtime(true) .PHP_EOL, $logname);
                if (! $this->mysql->getDb()->getInsertId()) {
                    Logger::getInstance()->log(PHP_EOL . '添加数据到表 COINS_PLAYER 失败' . PHP_EOL . $logs, $logname);
                    return false;
                } else {
                */
                    //更新玩家余额(已经单进程移动到hitory队列中)
                    $this->mysql->getDb()->where('id', $logs['account_id'])->where('log_id', $logs['log_id'], '<')->update(MysqlTables::ACCOUNT, ['coin'=> $logs['after'],'log_id'=> $logs['log_id']]);
                    if (! $this->mysql->getDb()->getAffectRows()) {
                        Logger::getInstance()->log(PHP_EOL . '更新玩家余额失败' . PHP_EOL . json_encode($logs), $logname);
                    }
                    if(in_array($_logs['type'], [3,4,5,6])) {
                        $this->postCoinsPlayerDay($logs['account_id'], $logs['coin'], date('Ymd'),$_logs['type']);
                    }
                    
                    //上分，需要变动玩家账户余额，从代理账户余额减除额度并增加到玩家账户余额
                    if (intval($_logs['type']) == 1) {
                        $insertData = [];
                        $insertData['account_id'] = $_logs['account_id'];
                        $insertData['agent'] = 0;
                        $insertData['type'] = 1;
                        $insertData['before'] = $_logs['before'];
                        $insertData['coin'] = $_logs['coin'];
                        $insertData['after'] = $_logs['after'];
                        $insertData['ipaddr'] = $ipaddr;
                        $insertData['create_time'] = $_logs['game_timestamp'];
                        $insertData['log_id'] = $_logs['log_id'];
                        $this->mysql->getDb()->insert(MysqlTables::SCORE_LOG, $insertData);
                        if (! $this->mysql->getDb()->getInsertId()) {
                            Logger::getInstance()->log(PHP_EOL . '添加玩家上分数据到表 SCORE_LOG 失败' . PHP_EOL . json_encode($logs), $logname);
                        }
                        //设置玩家为VIP逻辑
                        if(
                            $flag_player
                            && !! ($_sysset = $this->models->system_model->getSystemPars('player_vipbaseline'))
                            && isset($_sysset['player_vipbaseline'])
                            && !! ($_sysset_player_vipbaseline = $_sysset['player_vipbaseline'])
                        ) {
                                //玩家目前总上分
                                $_totalPlayerCoinUp = $this->getTotalPlayerCoinUp($_logs['account_id']);
                                //只管上分
                                $addcoin = ['addcoin'=>$_totalPlayerCoinUp];
                                $this->models->account_model->putPlayer(Helper::account_format_login($_u_tar['account_pid']), $addcoin, ['addcoin']);
                                //设置VIP状态
                                $_par['vip'] = $_totalPlayerCoinUp >= $_sysset_player_vipbaseline ? 1 : 0;
                                if(!isset($_u_tar['account_vip'])) {
                                    $_u_tar['account_vip'] = 0;
                                }
                                if ($_par['vip'] != $_u_tar['account_vip']) {
                                    $_par['vip_time'] = $_logs['game_timestamp'];
                                    if (! $this->models->account_model->putPlayer(Helper::account_format_login($_u_tar['account_pid']), $_par, ['vip', 'vip_time'])) {
                                        Logger::getInstance()->log(PHP_EOL . '更新玩家VIP身份' . PHP_EOL . json_encode($logs), $logname);
                                    }
                                }
                        }
                    }
                    //下分，需要变动玩家账户余额，从玩家账户余额减除额度并增加到代理账户余额
                    elseif (intval($_logs['type']) == 2) {
                        $insertData = [];
                        $insertData['account_id'] = $_logs['account_id'];
                        $insertData['agent'] = 0;
                        $insertData['type'] = 2;
                        $insertData['before'] = $_logs['before'];
                        $insertData['coin'] = $_logs['coin'] * -1;
                        $insertData['after'] = $_logs['after'];
                        $insertData['ipaddr'] = $ipaddr;
                        $insertData['create_time'] = $_logs['game_timestamp'];
                        $insertData['log_id'] = $_logs['log_id'];
                        $this->mysql->getDb()->insert(MysqlTables::SCORE_LOG, $insertData);
                        if (! $this->mysql->getDb()->getInsertId()) {
                            Logger::getInstance()->log(PHP_EOL . '添加数据到表 SCORE_LOG 失败' . PHP_EOL . json_encode($logs), $logname);
                        }
                        //设置玩家为VIP逻辑
                        if(
                            $flag_player
                            && !! ($_sysset = $this->models->system_model->getSystemPars('player_vipbaseline'))
                            && isset($_sysset['player_vipbaseline'])
                            && !! ($_sysset_player_vipbaseline = $_sysset['player_vipbaseline'])
                        ) {
                            //玩家目前总上分
                            $_totalPlayerCoinUp = $this->getTotalPlayerCoinUp($_logs['account_id']);
                            //设置VIP状态
                            $_par['vip'] = $_totalPlayerCoinUp >= $_sysset_player_vipbaseline ? 1 : 0;
                            if(!isset($_u_tar['account_vip'])) {
                                $_u_tar['account_vip'] = 0;
                            }
                            if ($_par['vip'] != $_u_tar['account_vip']) {
                                $_par['vip_time'] = $_logs['game_timestamp'];
                                if (! $this->models->account_model->putPlayer(Helper::account_format_login($_u_tar['account_pid']), $_par, ['vip', 'vip_time'])) {
                                    Logger::getInstance()->log(PHP_EOL . '更新玩家VIP身份' . PHP_EOL . json_encode($logs), $logname);
                                }
                            }
                        }
                    }
                    //下注
                    elseif (intval($_logs['type']) == 3) {
                        //
                        if (in_array(Config::getInstance()->getConf('APPTYPE'), [1, 2])) {
//                            /**
//                             * 游戏灵魂 - 开始
//                             */
//                            if ($this->redis->getDb()->sismember(RedisKey::SOUL_S1_SET_ACCOUNTS, $_logs['account_id'])
//                                //是否属于活动账号+是否在有效期内
//                                && !! ($vt = $this->redis->getDb()->zScore(RedisKey::SOUL_S1_SSET_ACCOUNTS, $_logs['account_id']))
//                                //是否在有效期内
//                                && $vt > time()
//                            ) {
//                                //判断是否已经达到下注总额限制
//                                if($this->mysql->getDb()->where('account_id', $_logs['account_id'])->where('type', 3)->sum(MysqlTables::COINS_PLAYER, 'coin') * -1 > $this->redis->getDb()->hGet(RedisKey::SOUL_S1_HASH_ACCOUNT_ . $_logs['account_id'], 'limitbets')) {
//                                    //移除小赢概率
//                                    if ($this->models->account_model->putSoulS1Prob($_logs['account_id'], 1)) {
//                                        //取消有效资格
//                                        $this->redis->getDb()->zAdd(RedisKey::SOUL_S1_SSET_ACCOUNTS, 0, $_logs['account_id']);
//                                        $this->mysql->getDb()->where('account_id', $_logs['account_id'])->update(MysqlTables::SOUL_S1_ACCOUNT, ['available'=> 0]);
//                                    }
//                                }
//
//                                $totalbets = $this->mysql->getDb()->where('account_id', $_logs['account_id'])->where('type', 3)->sum(MysqlTables::COINS_PLAYER, 'coin') * -1;
//                                $this->redis->getDb()->hSet(RedisKey::SOUL_S1_HASH_ACCOUNT_ . $_logs['account_id'], 'totalbets', $totalbets);
//                                $this->mysql->getDb()->where('account_id', $_logs['account_id'])->update(MysqlTables::SOUL_S1_ACCOUNT, [
//                                    'totalbets'=> $totalbets
//                                ]);
//                            }
//                            //游戏灵魂 - 结束
                        }

                        //游戏数据统计 -- 下注
                        if (! $this->redis->getDb()->sismember(RedisKey::STAT_GAME_SET_ . 'num_betofplayer:' . $_logs['game_id'], $_logs['account_id'])) {
                            $this->redis->getDb()->sAdd(RedisKey::STAT_GAME_SET_ . 'num_betofplayer:' . $_logs['game_id'], $_logs['account_id']);
                            $this->redis->getDb()->incr('num_betofplayer_'.$_logs['game_id']);
                        }
                        if ($ext1 == 'fullbet' && ! $this->redis->getDb()->sismember(RedisKey::STAT_GAME_SET_ . 'num_betfullofplayer:' . $_logs['game_id'], $_logs['account_id'])) {
                            $this->redis->getDb()->sAdd(RedisKey::STAT_GAME_SET_ . 'num_betfullofplayer:' . $_logs['game_id'], $_logs['account_id']);
                            $this->redis->getDb()->incr('num_betfullofplayer_'.$_logs['game_id']);
                        }
//                        $this->mysql->getDb()->where('game_id', $_logs['game_id'])->setInc(MysqlTables::STAT_GAMES, 'amount_bet', $_logs['coin'] * -1);
                        $this->redis->getDb()->incrByFloat('amount_bet_'.$_logs['game_id'], $_logs['coin'] * -1);
                        if ($ext1 == 'fullbet') {
                            $this->redis->getDb()->incrByFloat('amount_betfull_'.$_logs['game_id'], $_logs['coin'] * -1);
//                            $this->mysql->getDb()->where('game_id', $_logs['game_id'])->setInc(MysqlTables::STAT_GAMES, 'amount_betfull', $_logs['coin'] * -1);
                        }
                    }
                    //赢钱
                    elseif (intval($_logs['type']) == 4) {
                        //
                        if (in_array(Config::getInstance()->getConf('APPTYPE'), [1, 2])) {
                            /**
                             * 游戏灵魂 - 开始
                             */
//                            if ($this->redis->getDb()->sismember(RedisKey::SOUL_S1_SET_ACCOUNTS, $_logs['account_id'])
//                                //是否属于活动账号+是否在有效期内
//                                && !! ($vt = $this->redis->getDb()->zScore(RedisKey::SOUL_S1_SSET_ACCOUNTS, $_logs['account_id']))
//                                //是否在有效期内
//                                && $vt > time()
//                            ) {
//                                //判断是否已经达到余额限制
//                                if($_logs['after'] > $this->redis->getDb()->hGet(RedisKey::SOUL_S1_HASH_ACCOUNT_ . $_logs['account_id'], 'limitbalance')) {
//                                    //移除小赢概率
//                                    if ($this->models->account_model->putSoulS1Prob($_logs['account_id'], 1)) {
//                                        //取消有效资格
//                                        $this->redis->getDb()->zAdd(RedisKey::SOUL_S1_SSET_ACCOUNTS, 0, $_logs['account_id']);
//                                        $this->mysql->getDb()->where('account_id', $_logs['account_id'])->update(MysqlTables::SOUL_S1_ACCOUNT, ['available'=> 0]);
//                                    }
//                                }
//
//                                $this->redis->getDb()->hSet(RedisKey::SOUL_S1_HASH_ACCOUNT_ . $_logs['account_id'], 'balance', $_logs['after']);
//                                $this->mysql->getDb()->where('account_id', $_logs['account_id'])->update(MysqlTables::SOUL_S1_ACCOUNT, [
//                                    'balance'=> $_logs['after']
//                                ]);
//                            }
                            //游戏灵魂 - 结束
//                            $taskClass = new NewProtection(['account_id' => $_logs['account_id']]);
//                            TaskManager::processAsync($taskClass);
                        }
                        
                        //游戏数据统计 -- 结算
//                        $this->mysql->getDb()->where('game_id', $_logs['game_id'])->setInc(MysqlTables::STAT_GAMES, 'amount_payout', $_logs['coin']);
                        $this->redis->getDb()->incrByFloat('amount_payout_'.$_logs['game_id'], $_logs['coin']);
                        if ($ext1 == 'fullbet') {
//                            $this->mysql->getDb()->where('game_id', $_logs['game_id'])->setInc(MysqlTables::STAT_GAMES, 'amount_betfullpayout', $_logs['coin']);
                            $this->redis->getDb()->incrByFloat('amount_betfullpayout_'.$_logs['game_id'], $_logs['coin']);
                        }
                    }
                    //bigbang
                    elseif (intval($_logs['type']) == 5) {
                        //
                    }
                    //红包
                    elseif (intval($_logs['type']) == 6) {
                        $insertData = [];
                        $insertData['altercoin_id'] = $_logs['altercoin_id'];
                        $insertData['account_id'] = $_logs['account_id'];
                        $insertData['coin'] = $_logs['coin'] * -1;
                        $insertData['create_time'] = $_logs['game_timestamp'];
                        $this->mysql->getDb()->insert(MysqlTables::REDBAG, $insertData);
                        if (! $this->mysql->getDb()->getInsertId()) {
                            Logger::getInstance()->log(PHP_EOL . '添加数据到表 REDBAG 失败' . PHP_EOL . json_encode($logs), $logname);
                        }
                    }
                    //代理创建账号免费红包
                    elseif (intval($_logs['type']) == 12) {
                        $insertData = [];
                        $insertData['altercoin_id'] = $_logs['altercoin_id'];
                        $insertData['account_id'] = $_logs['account_id'];
                        $insertData['coin'] = $_logs['coin'];
                        $insertData['create_time'] = $_logs['game_timestamp'];
                        $this->mysql->getDb()->insert(MysqlTables::REDBAG_ZONGDAI, $insertData);
                        if (! $this->mysql->getDb()->getInsertId()) {
                            Logger::getInstance()->log(PHP_EOL . '添加数据到表 REDBAG_ZONGDAI 失败' . PHP_EOL . json_encode($logs), $logname);
                        }
                    }
                    //总代系统红包
                    elseif (intval($_logs['type']) == 13) {
                        $insertData = [];
                        $insertData['altercoin_id'] = $_logs['altercoin_id'];
                        $insertData['account_id'] = $_logs['account_id'];
                        $insertData['coin'] = $_logs['coin'];
                        $insertData['create_time'] = $_logs['game_timestamp'];
                        $this->mysql->getDb()->insert(MysqlTables::REDBAG_ZONGDAI, $insertData);
                        if (! $this->mysql->getDb()->getInsertId()) {
                            Logger::getInstance()->log(PHP_EOL . '添加数据到表 REDBAG_ZONGDAI 失败' . PHP_EOL . json_encode($logs), $logname);
                        }
                    }
                    //第三方转入
                    elseif (intval($_logs['type']) == 7) {
                        
                    }
                    //第三方转出
                    elseif (intval($_logs['type']) == 8) {
                        
                    }
                    //推广员-收益提现
                    elseif (intval($_logs['type']) == 101) {
                        
                    }
                    //推广员-上分
                    elseif (intval($_logs['type']) == 102) {
                        $insertData = [];
                        $insertData['from_account_id'] = $_logs['account_id'];
                        $insertData['to_account_id'] = intval($ext1);
                        $insertData['coin'] = $_logs['coin'];
                        $insertData['create_time'] = $_logs['game_timestamp'];
                        $this->mysql->getDb()->insert(MysqlTables::SCORE_RELATION_LOG, $insertData);
                        if (! $this->mysql->getDb()->getInsertId()) {
                            Logger::getInstance()->log(PHP_EOL . '添加数据到表 SCORE_RELATION_LOG 失败' . PHP_EOL . json_encode($logs), $logname);
                        }
                    }
                    //推广员-下分
                    elseif (intval($_logs['type']) == 103) {
                        $insertData = [];
                        $insertData['from_account_id'] = $_logs['account_id'];
                        $insertData['to_account_id'] = intval($ext1);
                        $insertData['coin'] = $_logs['coin'];
                        $insertData['create_time'] = $_logs['game_timestamp'];
                        $this->mysql->getDb()->insert(MysqlTables::SCORE_RELATION_LOG, $insertData);
                        if (! $this->mysql->getDb()->getInsertId()) {
                            Logger::getInstance()->log(PHP_EOL . '添加数据到表 SCORE_RELATION_LOG 失败' . PHP_EOL . json_encode($logs), $logname);
                        }
                    }
//                }
                $end_time = microtime(true);
                 Logger::getInstance()->log(PHP_EOL . ' coinplayerqueue haoshi: ' . ($end_time - $start_time) . PHP_EOL, $logname);
                return true;
        } catch (\Exception $e) {
            Logger::getInstance()->log(PHP_EOL . 'DB 异常 >>>>>>>>>>>>>>>>' . $e->getMessage() . PHP_EOL . $logs, $logname);
            return false;
        }
    }

    //获取玩家赢分上线
    private function getUserMaxWinCoin($account_id) {
        $addcoin = $this->redis->getDb()->hget(RedisKey::USERS_ . $account_id, 'account_addcoin');
        if($addcoin <= 0) {
            $addcoin = 50;
        }
        if($addcoin > 50) {
            $addcoin = 50 ; //上限，50分及以上，最多赢5000分
        }
        return $addcoin*100;
    }

    //统计游戏回报率
    private function gameWinPayRate($log)
    {
        //总的回报率
        $payRateKey = 'payrate:';
        $hadStatised = $this->redis->getDb()->hget($payRateKey . $log['game_id'], 'payrate');
        if(!$hadStatised) {
            $time = time();
            $sql = [
                "insert into state_slots_payrate(game_id,win,bet,create_time) value({$log['game_id']}, {$log['win']}, {$log['bet']}, {$time});"
            ];
            $this->redis->getDb()->hset($payRateKey. $log['game_id'], 'payrate', 1);
        } else {
            //游戏的回报率统计
            $sql = [
                'update state_slots_payrate set win=win + ' . $log['win'] . ', bet=bet+'. $log['bet'] .' where game_id=' . $log['game_id'] . ";"
            ];
        }
        TaskManager::async(new MysqlQuery($sql));

        //当天的回报率
        $payRateDayKey = 'payrate_'.date('Ymd').':';
        $hadData = $this->redis->getDb()->get($payRateDayKey . $log['game_id']);
        if(!$hadData) {
            $time = strtotime(date('Y-m-d 0:0:0'));
            $sql = [
                "insert into state_slots_payrate_day(game_id,win,bet,day) value({$log['game_id']}, {$log['win']}, {$log['bet']}, {$time});"
            ];
            TaskManager::async(new MysqlQuery($sql));
            $this->redis->getDb()->set($payRateDayKey. $log['game_id'], 1);
            $expireTime = mktime(23, 59, 59, date("m"), date("d"), date("Y"));
            $this->redis->getDb()->expireAt($payRateDayKey. $log['game_id'], $expireTime);
        } else {
            //游戏的回报率统计
            $sql = [
                'update state_slots_payrate_day set win=win + ' . $log['win'] . ', bet=bet+'. $log['bet'] .' where game_id=' . $log['game_id'] . ";"
            ];
            TaskManager::async(new MysqlQuery($sql));
        }
    }

    //统计输赢列表
    private function gameWinList($account_id, $win) 
    {
        $preKey = 'gameWinList_';
        $todayKey = $preKey . date('Ymd');
        $score = $this->redis->getDb()->zScore($todayKey, $account_id);
        if(!$score) {
            $this->redis->getDb()->zAdd($todayKey, $win, $account_id);
        } else {
            $this->redis->getDb()->zIncrBy($todayKey, $win, $account_id);
        }
        $oldKey = $preKey . date('Ymd', strtotime('-30 day'));
        $total = $this->redis->getDb()->zSize($oldKey);
        if($total) {
            $this->redis->getDb()->delete($oldKey);
        }
    }

    //根据玩家输赢直接设定策略
    private function userStrategy($account_id)
    {
        $wincoin = $this->redis->getDb()->hget(RedisKey::USERS_ . $account_id, 'account_wincoin');
        $maxwinlimit = $this->getUserMaxWinCoin($account_id);
        $rate = round($wincoin/$maxwinlimit*100,2); //百分之40 就算出来40
        $time = date('Y-m-d H:i:s');

        // file_put_contents("/tmp/test.log", "{$time}  account_id: ". $account_id . " wincoin:". $wincoin." maxwinlimit:".$maxwinlimit ." rate:" . $rate ."\r\n", FILE_APPEND);
        if($rate < 40 ) {
            // 小于40% 正常
            // file_put_contents("/tmp/test.log", "{$time} account_id1: ". $account_id ."\r\n", FILE_APPEND);

            $this->redis->getDb()->set(RedisKey::USER_STRATEGY .$account_id, 3);
            $this->redis->getDb()->hset(RedisKey::USERS_ . $account_id, RedisKey::USER_STRATEGY_LIMIT, 0);
        } elseif($rate >= 40 && $rate < 60 ) {
            // 40% - 60% 小输
            // file_put_contents("/tmp/test.log", "{$time}  account_id2: ". $account_id ."\r\n", FILE_APPEND);

            $this->redis->getDb()->set(RedisKey::USER_STRATEGY .$account_id, 4);
            $this->redis->getDb()->hset(RedisKey::USERS_ . $account_id, RedisKey::USER_STRATEGY_LIMIT, 0); //限制中免费游戏和小游戏概率
            
        } elseif ($rate >= 60 && $rate<80 ) {
            //60% - 80% 大输
            // file_put_contents("/tmp/test.log", "{$time}  account_id3: ". $account_id  ."\r\n", FILE_APPEND);
            $this->redis->getDb()->set(RedisKey::USER_STRATEGY .$account_id, 5);
            if($rate > 70) {
                $this->redis->getDb()->hset(RedisKey::USERS_ . $account_id, RedisKey::USER_STRATEGY_LIMIT, 1);
            } else {
                $this->redis->getDb()->hset(RedisKey::USERS_ . $account_id, RedisKey::USER_STRATEGY_LIMIT, 0);
            }
        } elseif($rate >= 80) {
            //80% 大输，借款卡住最大值
            // file_put_contents("/tmp/test.log", "{$time}  account_id4: ". $account_id ."\r\n", FILE_APPEND);
            $this->redis->getDb()->set(RedisKey::USER_STRATEGY .$account_id, 5);
            $this->redis->getDb()->hset(RedisKey::USERS_ . $account_id, RedisKey::USER_STRATEGY_LIMIT, 1);
        }
    }
    
    //判断是否是slots游戏
    private function isSlotGame($game_id) {
        $basev = intval($game_id/100);
        if($basev == 1 || $basev==4 || $game_id ==238) {
            return true;
        }
        return false;
    }

    //借款调用
    public function canApplyLoanStrategy($account_id, $coin, $game_id)
    {
        $time = date('Y-m-d H:i');
        if(Config::getInstance()->getConf('APPTYPE') == 5) {
            return true;
        }
        if($this->isSlotGame($game_id)) {
            //大输控制最大赢分
            $max_win_coin = $this->getUserMaxWinCoin($account_id);
            $wincoin = $this->redis->getDb()->hget(RedisKey::USERS_ . $account_id, 'account_wincoin');
            if($wincoin < 0) {
                $wincoin = 0;
            }
            $diff = $max_win_coin - $wincoin;
            if($diff <= $coin) {
                // file_put_contents("/tmp/test.log", "{$time}  account_id888-4: ". $account_id . " game:". $game_id . " coin:" . $coin . " diff:".$diff."\r\n", FILE_APPEND);
                return false;
            }
            
        }
        
        return true;
    }

    /**
     * redis
     * 处理队列数据
     * 数据来源：game_log游戏日志队列
     * @param string $logs
     * @return bool
     */
    public function postPlayerGameLog($logs = '') : bool
    {
        if (is_array($_logs = json_decode($logs, true))) {
            try {
                $_logs['create_time'] = time();
                $this->mysql->getDb()->insert(MysqlTables::GAMESERVER_GAMELOG, $_logs);
                
                //发送slots输赢
                // if (Config::getInstance()->getConf('APPTYPE') == '3' && $this->redis->getDb()->hGet(RedisKey::GAME_LIST_HASH_ . $_logs['game_id'], 'type') == '1') {
                //     $this->models->curl_model->sendSlotsWin($_logs['account_id'], $_logs['game_id'], $_logs['win'] > 0 ? '1' : '0');
                // }
                
                if (! $this->mysql->getDb()->getInsertId()) {
                    Logger::getInstance()->log(PHP_EOL . 'DB插入记录失败' . PHP_EOL . $logs, 'queue-gplay-fail');
                    return false;
                }
                
                // $time = date('Y-m-d H:i:s');
                // file_put_contents("/tmp/test.log", "{$time}  game_identification: ". $_logs['game_identification'] ."\r\n", FILE_APPEND);
                if ($_logs['game_id'] < 10000 || (in_array($_logs['game_id'], [100000,90000,60000,50000]))) {
                    //累加玩家输赢情况
                    $win = $_logs['win'] - $_logs['bet'];
                    $this->redis->getDb()->hIncrByFloat(RedisKey::USERS_ . $_logs['account_id'], 'account_wincoin', $win);

                    // $this->userStrategy($_logs['account_id']); //自动调节玩家的输赢策略

                    $sql = [
                        'update '. MysqlTables::ACCOUNT . ' set wincoin=wincoin + ' . $win . ' where id=' . $_logs['account_id'] . ";"
                    ];
                    //异步执行SQL
                    TaskManager::async(new MysqlQuery($sql));
                }
                
                if($this->isSlotGame($_logs['game_id'])) {
                    $this->gameWinPayRate($_logs); //及时统计游戏的回报率
                }

                $win = $_logs['win'] - $_logs['bet'];
                $this->gameWinList($_logs['account_id'], $win); //当天输赢最大的前后50名列表

                return true;
            } catch (\Exception $e) {
                Logger::getInstance()->log(PHP_EOL . 'DB 异常 >>>>>>>>>>>>>>>>' . $e->getMessage() . PHP_EOL . $logs, 'queue-gplay-fail');
                return false;
            }
        } else {
            Logger::getInstance()->log(PHP_EOL . '无法解析完整JSON数据' . PHP_EOL . $logs, 'queue-gplay-fail');
        }
        
        return false;
    }
    
    public function postPlayerGameEvent($logs = '') : bool
    {
        if (is_array($_logs = json_decode($logs, true))) {
            try {
                $_logs['create_time'] = time();
                $this->mysql->getDb()->insert(MysqlTables::GAMESERVER_GAMEEVENT, $_logs);
                if (! $this->mysql->getDb()->getInsertId()) {
                    Logger::getInstance()->log(PHP_EOL . 'DB插入记录失败' . PHP_EOL . $logs, 'queue-gevent-fail');
                    return false;
                }
                
                return true;
            } catch (\Exception $e) {
                Logger::getInstance()->log(PHP_EOL . 'DB 异常 >>>>>>>>>>>>>>>>' . $e->getMessage() . PHP_EOL . $logs, 'queue-gevent-fail');
                return false;
            }
        } else {
            Logger::getInstance()->log(PHP_EOL . '无法解析完整JSON数据' . PHP_EOL . $logs, 'queue-gevent-fail');
        }
        
        return false;
    }
    
    /**
     * redis
     * 处理队列数据 
     * 数据来源：game_log游戏日志队列 第3方日志数据1
     * @param string $logs
     * @return bool
     */
    public function postPlayerTPGameLog($logs = '') : bool
    {
        if (
            is_array($_logs = json_decode($logs, true))
            && isset($_logs['platform_name']) && $_logs['platform_name']
        ) {
            $_tableSuffix = $_logs['platform_name'];
            unset($_logs['platform_name']);
            try {
                $this->mysql->getDb()->insert(MysqlTables::GAMESERVER_GAMELOG . $_tableSuffix, $_logs);
                if (! $this->mysql->getDb()->getInsertId()) {
                    Logger::getInstance()->log(PHP_EOL . 'DB插入记录失败' . PHP_EOL . $logs, 'queue-tpgplay-fail');
                    return false;
                }
                
                return true;
            } catch (\Exception $e) {
                Logger::getInstance()->log(PHP_EOL . 'DB 异常 >>>>>>>>>>>>>>>>' . $e->getMessage() . PHP_EOL . $logs, 'queue-tpgplay-fail');
                return false;
            }
        } else {
            Logger::getInstance()->log(PHP_EOL . '无法解析完整JSON数据' . PHP_EOL . $logs, 'queue-tpgplay-fail');
        }
        
        return false;
    }
    
    public function _entryPool(array $pool = []) : string
    {
        //添加彩池记录
        $insertData = [];
        $insertData['log_id'] = 0;
        $insertData['account_id'] = $pool['account_id'];
        $insertData['game_id'] = $pool['game_id'];
        $insertData['type'] = 2;
        $insertData['coin'] = $pool['poolnormal'] * -1;
        $insertData['create_time'] = time();
        $insertData['game_timestamp'] = $pool['game_timestamp'];
        $insertData['game_identification'] = $pool['game_identification'];
        
        $this->mysql->getDb()->insert(MysqlTables::POOL_NORMAL, $insertData);
        if (! ($event_id = $this->mysql->getDb()->getInsertId())) {
            Logger::getInstance()->log(PHP_EOL . '数据入 彩池(' . $pool['poolnormal'] . ') 失败' . PHP_EOL . json_encode($pool, JSON_UNESCAPED_UNICODE), 'pool-normal-out-fail');
            $event_id = 0;
        }
        //添加JP池记录
        $coin_pool_jp = $pool['pooljp'];
        if ($event_id && $coin_pool_jp && $coin_pool_jp > 0) {
            $insertData = [];
            $insertData['log_id'] = 0;
            $insertData['event_id'] = $event_id;
            $insertData['account_id'] = $pool['account_id'];
            $insertData['game_id'] = $pool['game_id'];
            $insertData['type'] = 2;
            $insertData['coin'] = $coin_pool_jp * -1;
            $insertData['create_time'] = time();
            $insertData['game_timestamp'] = $pool['game_timestamp'];
            $insertData['game_identification'] = $pool['game_identification'];
            
            $this->mysql->getDb()->insert(MysqlTables::POOL_JP, $insertData);
            if (! $this->mysql->getDb()->getInsertId()) {
                Logger::getInstance()->log(PHP_EOL . '数据入 JP池(' . $coin_pool_jp . ') 失败' . PHP_EOL . json_encode($pool, JSON_UNESCAPED_UNICODE), 'pool-jp-out-fail');
            }
        }
        
        return $event_id;
    }
    
    /**
     * 普通池 poolnormal
     * 借款
     * @param string $gameid    游戏ID
     * @param string $coin      借款金额
     * @param string $game_timestamp
     * @param string $game_identification
     * @return string
     */
    public function _loanPoolNormal(string $gameid = '0', string $coin = '0', string $game_timestamp = '0', string $game_identification = '0') : string
    {
        $insertData = [];
        $insertData['game_id'] = $gameid;
        $insertData['type'] = 4;
        $insertData['coin'] = $coin * -1;
        $insertData['create_time'] = time();
        $insertData['game_timestamp'] = $game_timestamp;
        $insertData['game_identification'] = $game_identification;
        $this->mysql->getDb()->insert(MysqlTables::POOL_NORMAL, $insertData);
        
        if (!! ($loan_id = $this->mysql->getDb()->getInsertId())) {
            return (string)$loan_id;
        } else {
            return '0';
        }
    }
    
    /**
     * 普通池 poolnormal
     * 还款
     * @param string $logtoken      借款token
     * @param string $gameid        游戏ID
     * @param string $coin          还款金额
     * @param string $game_timestamp
     * @param string $game_identification
     * @return bool
     */
    public function _revertPoolNormal(string $pool_eventid = '', string $gameid = '', string $coin = '0', string $game_timestamp = '', string $game_identification = '') : bool
    {
        $coin = Helper::format_money($coin);
        
        $insertData = [];
        $insertData['game_id'] = $gameid;
        $insertData['type'] = 5;
        $insertData['coin'] = $coin;
        $insertData['event_id'] = $pool_eventid;
        $insertData['create_time'] = time();
        $insertData['game_timestamp'] = $game_timestamp;
        $insertData['game_identification'] = $game_identification;
        $this->mysql->getDb()->insert(MysqlTables::POOL_NORMAL, $insertData);
        
        if ($this->mysql->getDb()->getInsertId()) {
            return true;
        } else {
            return false;
        }
    }
    
    /**
     * 下注金额入池
     * - 抽税Tax额
     * - JP池PoolJP抽水额
     * - 彩池PoolNormal抽水额
     * @param number $betcoin
     * @return array
     */
    private function _getPoolDatas($betcoin = 0) : array
    {
        $result = ['sys_tax'=> 0, 'sys_jppool'=> 0, 'sys_mainpool'=> 0, 'sys_doreset'=> 0/* 税池清零前的余额 */];
        
        //系统参数
        $_syspars = $this->models->system_model->_getRedisSystemParameters();
        
        if ($this->models->rediscli_model->getLuaSha1s('_luascript_commission') && isset($_syspars['pool_tax_par']) && isset($_syspars['pool_tax_limitup']) && isset($_syspars['pool_tax_interval']) && isset($_syspars['pool_jp_par'])) {
            list(
                $result['sys_tax'],
                $result['sys_jppool'],
                $result['sys_mainpool'],
                $result['sys_doreset'],
                $result['pool_tax_balance_last'],
                $result['pool_jp_balance_last'],
                $result['pool_normal_balance_last']
                ) = $this->models->rediscli_model->getDb()->evalSha(
                    $this->models->rediscli_model->getLuaSha1s('_luascript_commission'),
                    [
                        RedisKey::SYSTEM_BALANCE_TAX_CLOSE,
                        RedisKey::SYSTEM_BALANCE_TAX_NOW,
                        RedisKey::SYSTEM_BALANCE_TAX_LAST,
                        RedisKey::SYSTEM_BALANCE_POOLNORMAL,
                        RedisKey::SYSTEM_BALANCE_POOLJP,
                        $betcoin,
                        $_syspars['pool_tax_par'],
                        $_syspars['pool_tax_limitup'],
                        $_syspars['pool_tax_interval'],
                        ($_syspars['pool_jp_par'] ?: 0)/100
                    ],
                    5
                );
        }
        
        return $result;
    }

    /**
     * 获取单个代理或玩家的上下分记录
     * @param number $page
     * @param array $par
     * @return array|bool
     */
    public function getCoins($username, $page = 0, $par = [])
    {
        $_limit_value = 10;
        $_limit_offset = ($page = abs(intval($page))) > 0 ? ($page - 1) * $_limit_value : 0;
        $result = ['total'=> 0, 'cointotal'=> 0, 'page'=> ! $page ? 1 : $page, 'limit'=> $_limit_value, 'list'=> []];
        $curUser = $this->getTokenObj();

        $db = $this->mysql->getDb();
        // 判断$username 是代理还是玩家
        $db->where("(username='{$username}' OR pid='{$username}')");
        $account = $db->getOne(MysqlTables::ACCOUNT);
        if (empty($account)) {
            return $result;
        }
        if (!$this->models->account_model->isDescendant($curUser->account_id, $account['id'])) {
            return $result;
        }
        $parentAccount = $db->where('id', $account['parent_id'])->getOne(MysqlTables::ACCOUNT);
        if ($account['agent'] == 0) { //玩家
            // coin AS coin_change,
            $fieldstrs = "
                        `before` AS coin_befor,
                        `after` AS coin_after,
                        if(type=2, (-1)*coin, coin) as coin_change,
                        create_time AS coin_time,
                        ipaddr,
                        '{$parentAccount['username']}' AS from_username,
                        '{$account['pid']}' AS to_username
                    ";
        } else { //代理
            $fieldstrs = "
                        `before` AS coin_befor,
                        `after` AS coin_after,
                        coin AS coin_change,
                        create_time AS coin_time,
                        ipaddr,
                        '{$parentAccount['username']}' AS from_username,
                        '{$account['username']}' AS to_username
                    ";
        }
        
        $_table_user_coinlog_fields_ar = ['coin_befor', 'coin_after', 'coin_change', 'coin_time'];
        
        //orderby 排序字段
        if (isset($par['orderby']) && $par['orderby'] && $orderby = $par['orderby']) {
            list($_od_f, $_od_b) = explode("|", $orderby);
            $_od_f = in_array($_od_f, $_table_user_coinlog_fields_ar) ? $_od_f : false;
            $_od_b = strtoupper($_od_b);
            if ($_od_f === false || ! $_od_b || ! in_array($_od_b, ['DESC', 'ASC'])) {
                $this->setErrMsg('orderby参数非法');
                return false;
            }
            $orderby = [$_od_f, $_od_b];
        } else {
            $orderby = ['id', 'DESC'];
        }
        $db->where('account_id', $account['id']);
        //where 时间段
        if (isset($par['times']) && $par['times']) {
            list($_ts, $_te) = explode(".", $par['times']);
            $db->where('create_time', [$_ts, $_te], 'BETWEEN');
        }
        //在第一页返回总上下分
        if ($page == 1) {
            $db_clone1 = clone $db;
            $result['cointotal'] = $db_clone1->sum(MysqlTables::SCORE_LOG, "if(type=2, (-1)*coin, coin)");
        }
        $list = $db->orderBy($orderby[0], $orderby[1])->withTotalCount()->get(MysqlTables::SCORE_LOG, [$_limit_offset, $_limit_value], $fieldstrs);
        if (empty($list)) {
            return $result;
        }
        $result['total'] = $db->getTotalCount();
        $result['list'] = $list;
        
        return $result;
    }
    
    public function putBigbang(string $logtoken = '', string $account = '0', string $game_timestamp = '0', string $game_identification = ''): bool
    {
        $_bb_pre = $this->mysql->getDb()
        ->where('logtoken', $logtoken)
        ->where('account_id', $account)
        ->getOne(MysqlTables::COINS_BIGBANG, '*');
        if (isset($_bb_pre['logtoken']) && isset($_bb_pre['account_id'])) {
            // 更新bigbang预开奖信息为已开奖
            $this->mysql->getDb()
            ->where('status', 0)
            ->where('logtoken', $_bb_pre['logtoken'])
            ->where('id', $_bb_pre['id'])
            ->where('create_time', time() - 60, '>')
            ->update(MysqlTables::COINS_BIGBANG, [
                'status' => 1,
                'game_timestamp'=> $game_timestamp,
                'game_identification'=> $game_identification,
                'win_time' => time()
            ]);
            if (! $this->mysql->getDb()->getAffectRows()) {
                return false;
            }
            $_systemer = $this->models->account_model->getSystemer();
            // 给系统管理员减钱
            $this->mysql->getDb()
            ->where('id', $_systemer['id'])
            ->setDec(MysqlTables::ACCOUNT, 'coin', $_bb_pre['coin']);
            if (! $this->mysql->getDb()->getAffectRows()) {
                return false;
            }
        }
        
        return true;
    }
    
    public function getOpenApiAppBalance() : array
    {
        $curUser = $this->getTokenObj();
        
        $result['balance'] = (string)$this->mysql->getDb()->where('id', $curUser->account_id)->getValue(MysqlTables::ACCOUNT, 'coin');
        
        return $result;
    }
}