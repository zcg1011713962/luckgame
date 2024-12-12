<?php
namespace App\Model;

use App\Model\Model;
use App\Model\Constants\RedisKey;
use App\Model\Constants\MysqlTables;
use App\Utility\EncryptString;
use EasySwoole\Core\Component\Logger;
use App\Utility\Helper;
use EasySwoole\Utility\Random;
use EasySwoole\EasySwoole\Config;

class System extends Model
{
    /**
     * 设置系统参数
     * @param string $parstr
     * @return boolean
     */
    public function putSystemPars($parstr = '')
    {
        $result = false;
        $_datas = [];

        $encryptString = new EncryptString();

        if (!($_parstr = $encryptString->decode($parstr))) {
            $this->setErrMsg('参数非法');
            return false;
        }

        $_parstr = array_filter(explode("[@par@]", $_parstr));
        $db = $this->mysql->getDb();
        $db->startTransaction();
        $_doUSS = [];

        foreach ($_parstr as $_par) {
            list($_key, $_val) = explode("[@kv@]", $_par);

            $_datas[$_key] = $_val;

            if($_key) {
                $_doUSS[] = "{$_key} 》 {$_val}";
                $db->where('skey', $_key)->update(MysqlTables::SYS_SETTING, ['sval'=> $_val, 'update_time'=> time()]);
            }
        }

        if ($db->getAffectRows()) {
            //向游戏服务器推送数据
            $curlModel = $this->models->curl_model;

            if(
                (isset($_datas['bb_disbaseline'])/* 表示正在设置bigbang显示参数 */ && ! $curlModel->pushSystemSettingBigBangDis($_datas))/* 向游戏服推送数据 */
                || (isset($_datas['pool_rb_isopen'])/* 表示正在设置救济红包参数 */ && ! $curlModel->pushSystemSettingRedbag($_datas))/* 向游戏服推送数据 */
                || (isset($_datas['pool_jp_disbaseline'])/* 表示正在设置JP池显示参数 */ && ! $curlModel->pushSystemSettingPoolJPDis($_datas))/* 向游戏服推送数据 */
                || (isset($_datas['game_switch'])/* 【游戏】 开关，1=正常，0=游戏维护中 */ && ! $curlModel->pushSystemSettingGameSwitch($_datas))/* 向游戏服推送数据 */
            )
            {
                //回滚更新操作
                $db->rollback();
                return false;
            }
            else
            {
                $db->commit();

                if (isset($_datas['pool_tax_interval'])/* 表示正在设置系统抽税参数，点击设定按钮需要重置抽税参数 */) {
                    $redis = $this->redis->getDb();

                    $redis->del(RedisKey::SYSTEM_BALANCE_TAX_CLOSE);
                    $redis->del(RedisKey::SYSTEM_BALANCE_TAX_LAST);
                }

                /**
                 * 缓存数据到redis
                 */
                $this->_resetRedisSystemParameters();
                $result = true;
            }
        }
        else
        {
            $db->rollback();
            return false;
        }

        return $result;
    }

    /**
     * 获取系统参数
     * @param string $keystr 使用|符号将需要的参数分隔，如:key1|key2|key3
     * @return unknown[][]
     */
    public function getSystemPars($keystr = '')
    {
        $result = [];
        
        $_keys = array_filter(explode("|", $keystr));
        
        $_Q = $this->mysql->getDb();
        if ($_keys) $_Q->whereIn('skey', $_keys);
        $vs = $_Q->orderBy('skey', 'ASC')->get(MysqlTables::SYS_SETTING, null, 'skey,sval');
        
        foreach ($vs as $_v) {
            $result[$_v['skey']] = $_v['sval'];
        }
        
        /* while (! empty($_v = $query->unbuffered_row('array')))
        {
            $result[$_v['skey']] = $_v['sval'];
        } */
        
        return $result;
    }
    
    /**
     * redis
     * 获取系统参数redis缓存
     * @param array $parameters
     * @return array|array|mixed[]|mixed
     */
    public function _getRedisSystemParameters($parameters = [])
    {
        //如果$parameters不为空，表示检查特定键名，此变量表示是否全部通过检测
        $_foreachKF = true;
        $_inkey_pars = [];
        
        $_pars = null;
        
        if (($_pars = $this->redis->getDb()->get(RedisKey::SYSTEM_SETTING)) === false || ! $_pars) {
            return [];
        }
        
        if (($_pars = Helper::is_json_str($_pars)) === false) {
            return [];
        }
        
        if ($parameters) {
            foreach ($parameters as $_key) {
                if (! isset($_pars[$_key])) {
                    $_foreachKF = false;
                    break;
                } else {
                    $_inkey_pars[$_key] = $_pars[$_key];
                }
            }
        }
        
        return ! $_foreachKF ? [] : ($_inkey_pars ? $_inkey_pars : $_pars);
    }
    
    /**
     * redis
     * 重置系统参数到redis缓存
     * @return bool
     */
    public function _resetRedisSystemParameters() : bool
    {
        //游戏数据统计 -- 获取所有游戏列表
        $_games = $this->models->curl_model->getGameLists(1);
        if (is_array($_games) && count($_games) && isset($_games[0]['id'])) {
            foreach ($_games as $g) {
                //将游戏列表缓存到redis
                $this->redis->getDb()->hMSet(RedisKey::GAME_LIST_HASH_ . $g['id'], [
                    'type' => $g['type'],
                    'name' => $g['name'],
                    'id' => $g['id'],
                    'status' => $g['status'],
                    'ord' => $g['ord'] ?? '0',
                    'collector' => $g['collector'] ?? '0',
                    'tag' => $g['tag']
                ]);
                
                if (! $this->mysql->getDb()->where('game_id', $g['id'])->has(MysqlTables::STAT_GAMES)) {
                    $this->mysql->getDb()->insert(MysqlTables::STAT_GAMES, [
                        'game_id'=> $g['id'],
                        'num_favorite'=> $g['collector'] ?? '0'
                    ]);
                } else {
                    $this->mysql->getDb()->where('game_id', $g['id'])->update(MysqlTables::STAT_GAMES, ['num_favorite'=> $g['collector'] ?? '0']);
                }
            }
        }
        
        //获取系统参数数组
        $_settings = $this->getSystemPars();
        if (
            $this->models->rediscli_model->getDb()->set(RedisKey::SYSTEM_SETTING, json_encode($_settings, JSON_UNESCAPED_UNICODE|JSON_UNESCAPED_SLASHES))/* 将系统配置缓存到redis */ &&
            $this->redis->getDb()->set(RedisKey::OPENAPI_GAMEURL, Config::getInstance()->getConf('OPENAPIGAMEURL'))/* 设置OpenApiGameUrl */) {
                return true;
        }
        
        return false;
    }
    
    /**
     * 玩家获取当前客户端公告
     * @param number $uid
     * @param string $reset
     * @return string
     */
    public function getRedisCliNotice($uid = 0, $reset = false)
    {
        $notice = "";
        
        if (! $reset && ($_r_notice = $this->redis->getDb()->get(RedisKey::SYSTEM_CLIENT_NOTICE_.($uid ?: $this->getTokenObj()->account_parent_id))) !== false) {
            return $_r_notice;
        }
        
        $_sql = "
                SELECT
                    content as CONTENT
                FROM
                    sys_clientnotice
                WHERE
                    uid=".($uid ?: $this->getTokenObj()->account_parent_id)."
                ";
        //查询数据
        $_r = $this->mysql->getDb()->rawQuery($_sql);
        
        $notice = isset($_r[0]['CONTENT']) ? $_r[0]['CONTENT'] : '';
        
        //redis更新缓存
        $this->redis->getDb()->set(RedisKey::SYSTEM_CLIENT_NOTICE_.($uid ?: $this->getTokenObj()->account_parent_id), $notice);
        
        return $notice;
    }

    /**
     * 添加客户端公告
     * @param $content
     * @return array|bool
     */
    public function postNoticeClient($content)
    {
        $db = $this->mysql->getDb();
        $inserData = [
            'uid' => $this->getTokenObj()->account_id,
            'content'=> $content,
            'create_time'=> time()
        ];
        $db->insert(MysqlTables::SYS_CLIENTNOTICE, $inserData);
        if (! ($lastId = $db->getInsertId())) {
            return false;
        }

        //更新redis缓存
        $this->getRedisCliNotice($this->getTokenObj()->account_id, true);

        return ['id'=> $lastId];
    }

    /**
     * 编辑客户端公告
     * @param $id
     * @param $content
     * @return array|bool
     */
    public function putNoticeClient($id, $content)
    {
        $db = $this->mysql->getDb();
        $db->where('id', $id)->where('uid', $this->getTokenObj()->account_id);
        $db->update(MysqlTables::SYS_CLIENTNOTICE, ['content'=> $content, 'create_time'=> time()]);
        if ($db->getAffectRows()) {
            //更新redis缓存
            $this->getRedisCliNotice($this->getTokenObj()->account_id, true);
            return ['id'=> $id];
        }

        return false;
    }

    /**
     * 获取客户端公告
     * @return \EasySwoole\Mysqli\Mysqli|mixed|null
     */
    public function getNoticeClient()
    {
        $db = $this->mysql->getDb();
        $db->where('uid', $this->getTokenObj()->account_id);
        return $db->getOne(MysqlTables::SYS_CLIENTNOTICE);
    }

    /**
     * 添加跑马灯
     * @param $start_time
     * @param $counts
     * @param $interval
     * @param $content
     * @param $contenten
     * @return array
     */
    public function postMarquee($start_time, $counts, $interval, $content, $contenten)
    {
        $time = time();
        if ($start_time <= $time) {
            return false;
        }
        $insertData = [
            'start_time' => $start_time,
            'counts'=> $counts,
            'interval'=> $interval,
            'content'=> $content,
            'contenten'=> $contenten,
            'status' => 0,
            'next_time' => $start_time,
            'create_time'=> $time
        ];
        $db = $this->mysql->getDb();
        $db->insert(MysqlTables::SYS_ROLLINGNOTICE, $insertData);
        if (!($lastId = $db->getInsertId())) {
            return false;
        }
        return ['id' => $lastId];
    }

    /**
     * 撤回跑马灯
     * @param $id
     * @return array|bool
     */
    public function putMarquee($id)
    {
        $info = $this->getMarquee($id);
        // 进行中的状态才能撤回
        if ($info['status'] == 0 && $info['start_time'] + (($info['counts'] - 1) * $info['interval'] * 60) > time()) {
            $db = $this->mysql->getDb();
            $db->where('id', $id)->update(MysqlTables::SYS_ROLLINGNOTICE, ['status' => 1, 'revoke_time' => time()]);
            return $db->getAffectRows() ? ['id'=> $id] : false;
        } else {
            return false;
        }
    }

    /**
     * 获取跑马灯详情
     * @param $id
     * @return array
     */
    public function getMarquee($id)
    {
        $db = $this->mysql->getDb();
        return $db->where('id', $id)->getOne(MysqlTables::SYS_ROLLINGNOTICE);
    }

    /**
     * 发送跑马灯
     */
    public function sendMarquee($time)
    {
        $db = $this->mysql->getDb();
        $db->where('next_time', $time);
        $db->where('status', 0);
        $list = $db->get(MysqlTables::SYS_ROLLINGNOTICE, null);

        foreach ($list as $row) {
            $data = [
                'data' => [$row['content'], $row['contenten']]
            ];
            $curlModel = $this->models->curl_model;
            // 发送到游戏服
            $res = $curlModel->pushSystemsettingNoticeRolling($data);
            // 更新下次发送时间
            if (($row['next_time'] - $row['start_time']) < (($row['counts'] - 1) * $row['interval'] * 60)) {
                $db->where('id', $row['id']);
                $db->update(MysqlTables::SYS_ROLLINGNOTICE, ['next_time' => ($row['next_time'] + $row['interval'] * 60)]);
            }
        }
    }

    /**
     * 获取跑马灯列表
     * @param $page
     * @param $status
     * @return array
     */
    public function getMarquees($page, $status = 'all')
    {
        $limitValue = 10;
        $offset = ($page = abs(intval($page))) > 0 ? ($page - 1) * $limitValue : 0;

        $result = ['total'=> 0, 'list'=> []];
        $db = $this->mysql->getDb();

        if ($status == 'open') { //生效中
            $db->where('status', 0);
            $time = time();
            $db->where("start_time", [($time-(`counts`-1)*`interval`*60), $time], 'BETWEEN');
        } else if ($status == 'cancel') {
            $db->where('status', 1);
        }
        $db->orderBy('start_time', 'desc');
        $result['list'] = $db->withTotalCount()->get(MysqlTables::SYS_ROLLINGNOTICE, [$offset, $limitValue]);
        $result['total'] = $db->getTotalCount();
        return $result;
    }

    /**
     * 添加Bigbang预开奖信息
     * @param $account
     * @param $coin
     * @return bool
     */
    public function postBigbang($account, $coin)
    {
        if (!($player = $this->models->account_model->getPlayer($account, 0, false))) {
            return false;
        }

        $db = $this->mysql->getDb();

        $time = time();
        $logtoken = "[bb]".substr(md5(Helper::bb_randStr().time()."[bb]".Helper::bb_randStr()), 0, 28);

        $insertData = [
            'logtoken' => $logtoken, //logtokenforbigbangpre 可搜索定位
            'account_id'=> $player['account_id'],
            'coin'=> $coin,
            'create_time'=> $time,
            'request_time' => 0,
            'win_time' => 0,
            'status' => 0
        ];

        $db->insert(MysqlTables::COINS_BIGBANG, $insertData);
        if (($lastId = $db->getInsertId()) > 0) {
            $curlModel = $this->models->curl_model;
            $data = array(
                'logtoken' => $logtoken,
                'uid' => $player['account_id'],
                'coin' => $coin,
                'expiretime' => 60 // 过期时间，创建时间+60秒
            );
            if (($request_time = $curlModel->pushBigbangPreWin($data)) !== false) {
                $db->where('id', $lastId)->update(MysqlTables::COINS_BIGBANG, ['request_time' => $request_time]);
            } else {
                $db->where('id', $lastId)->update(MysqlTables::COINS_BIGBANG, ['status' => -2]);
            }
            return true;
        }
        return false;
    }

    /**
     * 获取bigbang开奖历史
     * @param $page
     * @param int $limitValue
     * @param string $time
     * @param string $account
     * @param string $orderBy
     * @return array
     */
    public function getBigbangs($page, $limitValue = 10, $time = '', $account = '', $orderBy = 'create_time DESC')
    {
        $offset = ($page = abs(intval($page))) > 0 ? ($page - 1) * $limitValue : 0;
        $result = ['total'=> 0, 'list'=> []];
        $db = $this->mysql->getDb();
        $db->join(MysqlTables::ACCOUNT . ' AS a', 'b.account_id=a.id', 'LEFT');
        $db->join(MysqlTables::ACCOUNT . ' AS a1', 'a.parent_agent_first_id=a1.id', 'LEFT');
        if ($account) {
            $account = Helper::account_format_login($account);
            if (!$account) {
                return $result;
            }
            $db->where('a.pid', $account);
        }
        if ($time) {
            list($startTime, $endTime) = explode(".", $time);
            $db->where('b.create_time', [$startTime, $endTime], 'BETWEEN');
        }
        $orderBy = empty($orderBy) ? 'b.create_time desc' : $orderBy;
        list($orderByField, $orderByDirection) = explode(' ', $orderBy);
        $db->orderBy($orderByField, $orderByDirection);
        $fields = 'b.id, b.create_time, a.pid, a1.username AS firstagent_username, a1.nickname AS firstagent_nickname, b.coin, b.status';
        $result['list'] = $db->withTotalCount()->get(MysqlTables::COINS_BIGBANG . ' AS b', [$offset, $limitValue], $fields);
        $result['total'] = $db->getTotalCount();
        // 开奖失败ID,超过添加时间一分钟视为开奖失败
        $failId = [];
        $time = time();
        foreach ($result['list'] as &$one) {
            $one['pid'] = Helper::account_format_display($one['pid']);
            if ($one['status'] == 0 && ($time - $one['create_time']) > 70) {
                $one['status'] = -1;
                $failId[] = $one['id'];
            }
        }
        // 将开奖失败的ID标记为失败
        if ($failId) {
            $db->where('id', $failId, 'IN');
            $db->update(MysqlTables::COINS_BIGBANG, ['status' => -1]);
        }
        return $result;
    }

    /**
     * 获取jackpot开奖历史
     * @param $page
     * @param int $limitValue
     * @param string $time
     * @param string $account
     * @param string $orderBy
     * @return array
     */
    public function getJackpots($page, $limitValue = 10, $time = '', $account = '', $orderBy = 'time DESC')
    {
        $offset = ($page = abs(intval($page))) > 0 ? ($page - 1) * $limitValue : 0;
        $result = ['total'=> 0, 'list'=> []];
        $db = $this->mysql->getDb();
        $db->join(MysqlTables::ACCOUNT . ' AS a', 'c.account_id=a.id', 'LEFT');
        if ($time) {
            list($startTime, $endTime) = explode(".", $time);
            $db->where('c.create_time', [$startTime, $endTime], 'BETWEEN');
        }
        if ($account) {
            $db->where('a.pid', $account);
        }
        $db->where('c.type', 2);
        $orderBy = empty($orderBy) ? 'c.create_time DESC' : $orderBy;
        list($orderByField, $orderByDirection) = explode(' ', $orderBy);
        $db->orderBy($orderByField, $orderByDirection);
        $fields = 'c.create_time, c.coin, a.pid';
        $result['list'] = $db->withTotalCount()->get(MysqlTables::POOL_JP . ' AS c', [$offset, $limitValue], $fields);
        $result['total'] = $db->getTotalCount();
        return $result;
    }

    /**
     * 获取救济红包历史
     * @param $page
     * @param int $limitValue
     * @param string $time
     * @param string $account
     * @param string $orderBy
     * @return array
     */
    public function getRedbags($page, $limitValue = 10, $time = '', $account = '', $orderBy = 'create_time DESC')
    {
        $offset = ($page = abs(intval($page))) > 0 ? ($page - 1) * $limitValue : 0;
        $result = ['total'=> 0, 'list'=> []];
        $db = $this->mysql->getDb();
        $db->join(MysqlTables::ACCOUNT . ' AS a', 'c.account_id=a.id', 'LEFT');
        if ($time) {
            list($startTime, $endTime) = explode(".", $time);
            $db->where('c.create_time', [$startTime, $endTime], 'BETWEEN');
        }
        if ($account) {
            $db->where('a.pid', $account);
        }
        $orderBy = empty($orderBy) ? 'c.create_time DESC' : $orderBy;
        list($orderByField, $orderByDirection) = explode(' ', $orderBy);
        $db->orderBy($orderByField, $orderByDirection);
        $fields = 'c.create_time, c.coin, a.pid';
        $result['list'] = $db->withTotalCount()->get(MysqlTables::REDBAG . ' AS c', [$offset, $limitValue], $fields);
        $result['total'] = $db->getTotalCount();
        return $result;
    }

    public function getGames($lang)
    {
        $curlModel = $this->models->curl_model;
        $list = $curlModel->getGameLists($lang);
        if ($list) {
            return ['total'=> count($list), 'list'=> $list];
        }
        return false;
    }

    public function getProbByGameId($gameId, $type)
    {
        $curlModel = $this->models->curl_model;
        $probStr = $curlModel->getProb($gameId, $type);
        if ($probStr) {
            return ['prob' => $probStr];
        }
        return false;
    }

    public function putProb($gameId, $type, $prob)
    {
        $curlModel = $this->models->curl_model;
        $result = $curlModel->pushGameProb($gameId, $type, $prob);
        return $result;
    }

    // 修改游戏状态
    public function putGameStatus($gameId)
    {
        $curlModel = $this->models->curl_model;
        $result = $curlModel->pushSystemSettingGameStatus($gameId);
        return $result;
    }

    public function _redisBalancePoolnormalFlush()
    {
        $redis = $this->redis->getDb();

        //当前PoolNormal池余额
        $_balance = $redis->get(RedisKey::SYSTEM_BALANCE_POOLNORMAL);

        if($redis->sAdd(RedisKey::SYSTEM_BALANCE_POOLNORMAL_HISSET, $_balance."@".time()))
        {
            $db = $this->mysql->getDb();
            $db->insert(MysqlTables::POOL_NORMAL_RESET, ['balance'=> $_balance, 'create_time'=> time()]);

            $redis->set(RedisKey::SYSTEM_BALANCE_POOLNORMAL, Helper::format_money(0));

            return true;
        }

        return false;
    }

    public function _redisBalancePooljpFlush()
    {
        $redis = $this->redis->getDb();

        //当前PoolJP池余额
        $_balance = $redis->get(RedisKey::SYSTEM_BALANCE_POOLJP);

        if($this->ci->ci_redis->sAddOne(RedisKey::SYSTEM_BALANCE_POOLJP_HISSET, $_balance."@".time()))
        {
            $db = $this->mysql->getDb();
            $db->insert(MysqlTables::POOL_JP_RESET, ['balance'=> $_balance, 'create_time'=> time()]);

            $redis->set(RedisKey::SYSTEM_BALANCE_POOLJP, Helper::format_money(0));

            return true;
        }

        return false;
    }

    public function _redisBalancePooltaxFlush()
    {
        $redis = $this->redis->getDb();

        //当前PoolTax池余额
        $_balance = $redis->get(RedisKey::SYSTEM_BALANCE_TAX_LAST);
        $_balance = $_balance && $_balance > 0 ? $_balance : $redis->get(RedisKey::SYSTEM_BALANCE_TAX_NOW);

        if($redis->sAdd(RedisKey::SYSTEM_BALANCE_POOLTAX_HISSET, $_balance."@".time()))
        {
            $db = $this->mysql->getDb();
            $db->insert(MysqlTables::POOL_TAX_RESET, ['balance'=> $_balance, 'create_time'=> time()]);

            $redis->del(RedisKey::SYSTEM_BALANCE_TAX_CLOSE);
            $redis->del(RedisKey::SYSTEM_BALANCE_TAX_LAST);
            $redis->set(RedisKey::SYSTEM_BALANCE_TAX_NOW, "0.0000");

            return true;
        }

        return false;
    }

    public function postAgentApiLogs($data = [])
    {
        unset($data['token']);
        $db = $this->mysql->getDb();
        $db->insert(MysqlTables::LOG_API_BACKOFFICE, $data);

        return $db->getInsertId();
    }
    
    public function _importAccount(string $parstrings = '') : bool
    {
        $total = 0;
        
        if (! $parstrings) {
            if (! file_exists(EASYSWOOLE_ROOT . '/d_user.data')) {
                echo PHP_EOL.'[×] >>> d_user.data文件不存在'.PHP_EOL.PHP_EOL;
                return false;
            }
            
            $datas = file(EASYSWOOLE_ROOT . '/d_user.data');
        } else {
            $datas[] = $parstrings;
        }
        
        foreach ($datas as $line) {
            if (strpos($line, ',') === false) {
                echo PHP_EOL.'[×] >>> 格式错误：'.$line.PHP_EOL.PHP_EOL;
            } else {
                $user = [];
                $line = trim($line);
                $line = str_replace(PHP_EOL, '', $line);
                $user = explode(',', $line);
                if (! is_array($user) || count($user) != 2 || ! is_numeric($user[0]) || ! is_numeric($user[1])) {
                    echo PHP_EOL.'[×] >>> 格式错误2：'.$line.PHP_EOL.PHP_EOL;
                } else {
                    list($_account_id, $_account_coin) = $user;
                    if ($this->mysql->getDb()->where('id', $_account_id)->has(MysqlTables::ACCOUNT)) {
                        echo PHP_EOL.'[×] >>> 无需重复导入，已退出'.PHP_EOL.PHP_EOL;
                        break;
                    } else {
                        $this->models->account_model->postAssignPlayer(md5(Random::character(60)), '导入账号' . $_account_id, $_account_id, $_account_coin);
                        $total++;
                    }
                }
            }
        }
        
        echo PHP_EOL.'[√] >>> 账号导入成功，总数：'.$total.PHP_EOL.PHP_EOL;
        
        return true;
    }

    private function getEvoGameId($game_name) {
        $game_ids = [
            'baccarat' => 30201,
            'baccarat' => 30206, //龙虎
            'rou' => 30209, //轮盘
            'blackjack' => 30210, //21点
        ];
        return isset($game_ids[$game_name]) ? $game_ids[$game_name] : '30201';
    }
    
    public function getCurlEvolutionGameHistoryToDB() : void
    {
        $lastTime = $this->mysql->getDb()->orderBy('create_time', 'DESC')->getValue(MysqlTables::CI_EVOLUTION_GAME_HISTORY, 'create_time');
        
        if (! $lastTime) {
            $lastTime = strtotime(date("Y-m-d") . ' 00:00:00') . '.' . '000';
        } else {
            $lastTime = $lastTime + 1;
        }
        
        if (($n = floor((time() - $lastTime) / (3600 * 24))) > 0) {
            $lastTime = strtotime(date("Y-m-d") . ' 00:00:00') . '.' . '000';
        }
        $lastTime = $lastTime - 1800; //往前半个小时
        
        list($t1, $t2) = explode('.', $lastTime);
        $startDate = date('Y-m-d\TH:i:s', $t1) . '.' . $t2 . 'Z';
        
        $hUrl = Config::getInstance()->getConf('EVOLUTION.HOST2') . '/api/gamehistory/v1/casino/games?startDate=' . $startDate;
        $hResult = $this->models->curl_model->simple_get($hUrl,[],['USERPWD'=> Config::getInstance()->getConf('EVOLUTION.KEY') . ':' . Config::getInstance()->getConf('EVOLUTION.TOKEN')]);

        file_put_contents('/tmp/evo_hitory_'.date('Ymd').'.log', $hResult."\r\n", FILE_APPEND);
        $hResult = Helper::is_json_str($hResult);

        if (isset($hResult['data']) && is_array($hResult['data'])) {
            foreach ($hResult['data'] as $_data) {
                if (isset($_data['games']) && is_array($_data['games'])) {
                    foreach ($_data['games'] as $_game) {
                        if (isset($_game['participants']) && is_array($_game['participants'])) {
                            foreach ($_game['participants'] as $_participant) {
                                $newData = [];
                                $newData['account_pid'] = $_participant['playerId'];
                                $__date = new \DateTime($_game['settledAt']);
                                $__fm1 = $__date->format('Y-m-d H:i:s u');
                                list($__s1, $__s2, $__ms) = explode(' ', $__fm1);
                                $__s = strtotime($__s1 . ' ' . $__s2);
                                $newData['create_time'] = $__s . '.' . $__ms;
                                $newData['datas'] = json_encode($_game, JSON_UNESCAPED_UNICODE|JSON_UNESCAPED_SLASHES);
                                
                                $this->mysql->getDb()->insert(MysqlTables::CI_EVOLUTION_GAME_HISTORY, $newData);

                                //对方evo不区分环境，拿到的数据有可能是其他环境的数据，不入进去
                                $account_id = $this->mysql->getDb()->where('pid', $_participant['playerId'])->getValue(MysqlTables::ACCOUNT, 'id');
                                if($account_id) {
                                    $ret_id = $this->mysql->getDb()->where('account_id',$account_id)->where('game_id_evo',$_game['id'])->count(MysqlTables::GAMESERVER_GAMELOG_EVO);
                                    if(!$ret_id) {
                                        $bet = 0;
                                        $win = 0;
                                        foreach ($_participant['bets'] as $k => $v) {
                                            $bet += $v['stake'];
                                            $win += $v['payout'];
                                        }
                                        $game_log = [
                                            'create_time' => $__s + 28800, //时区问题加8小时
                                            'account_id' => $account_id,
                                            'bet' => $bet,
                                            'win' => $win,
                                            'desk_id' => 0,
                                            'game_id' => $this->getEvoGameId($_game['gameType']),
                                            'extend1' => $_game['table']['name'],
                                            'game_id_evo'=>$_game['id'],
                                        ];
                                        $this->mysql->getDb()->insert(MysqlTables::GAMESERVER_GAMELOG_EVO, $game_log);

                                        //按天记录数据
                                        $date = date('Ymd', $game_log['create_time']);
                                        $this->postCoinsPlayerDay($account_id, ($win - $bet), $date);
                                    }                                    
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    /**
     * 按天记录在线玩家的输赢金币
     */
    public function postCoinsPlayerDay($account_id, $coin, $day):bool
    {
        $uniqid = $day.'_'.$account_id;
        $sql = "INSERT INTO coins_evo_player_day (uniqid,account_id,create_time,win) VALUE ('{$uniqid}',$account_id, $day, '{$coin}') ON DUPLICATE KEY UPDATE win=win+{$coin}";
        $this->mysql->getDb()->rawQuery($sql);
        return true;
    }
    
    private function _putl1Prob(string $account_id = '', string $sec = '1') : bool
    {
        $params = array(
            'st_p' => time(),
            't_p' => 2,
            'vt_p' => $sec,
            'v_p' => 1
        );
        
        if (! $this->models->curl_model->pushPlayerProb(array($account_id), $params)) {
            return false;
        }
        else {
            $key = RedisKey::PROB_SET_UID_ . $account_id;
            $this->redis->getDb()->setex($key, $sec, 3);
        }
        
        return true;
    }
    
    public function _import2Account(string $agent_id = '0', string $initCoin = '2000') : bool
    {
        if (!! ($accounts = $this->mysql->getDb()->where('extent1', 'acc2')->get(MysqlTables::ACCOUNT, null, 'id,parent_id,pid,coin'))) {
            $r = true;
            $agentAccount = $this->models->account_model->getAgent(null, $agent_id, false, true, false);
            $doProb = false;
            foreach ($accounts as $acc2) {
                if ($acc2['coin'] < $initCoin) {
                    if (! $this->models->finance_model->postPlayerCoinUp($acc2['pid'], Helper::format_money($initCoin - $acc2['coin']), '127.0.0.1', $agentAccount)) {
                        $r = false;
                        break;
                    } else {
                        //添加大赢概率
                        if (! $doProb && $this->_putl1Prob($acc2['parent_id'], 24 * 3600)) {
                            $doProb = true;
                            //进入
                            $key = RedisKey::PROB_SET_UID_ . $acc2['parent_id'];
                            $this->redis->getDb()->setex($key, 24 * 3600, 1);
                        }
                    }
                }
            }
            if (! $r) {
                return false;
            }
        } else {
            for ($i = 1000; $i < 9999; $i++) {
                $this->models->account_model->postAssignPlayer2(1, md5('Aa1111'), '', $initCoin, $agent_id, 'test' . $i, 'acc2');
            }
        }
        
        return true;
    }
    
    public function _import3Account(string $agent_id = '0', string $initCoin = '2000') : bool
    {
        if (!! ($accounts = $this->mysql->getDb()->where('extent1', 'acc2')->get(MysqlTables::ACCOUNT, null, 'id,parent_id,pid,username,coin'))) {
            $r = true;
            $agentAccount = $this->models->account_model->getAgent(null, $agent_id, false, true, false);
            $doProb = false;
            foreach ($accounts as $acc2) {

                if ($acc2['coin'] < $initCoin) {
                    if (! $this->models->finance_model->postPlayerCoinUp($acc2['pid'], Helper::format_money($initCoin - $acc2['coin']), '127.0.0.1', $agentAccount)) {
                        $r = false;
                        break;
                    } else {
                        //添加大赢概率
                        if (! $doProb && $this->_putl1Prob($acc2['parent_id'], 24 * 3600)) {
                            $doProb = true;
                            //进入
                            $key = RedisKey::PROB_SET_UID_ . $acc2['parent_id'];
                            $this->redis->getDb()->setex($key, 24 * 3600, 1);
                        }
                    }
                }
            }
            if (! $r) {
                return false;
            }
        } else {
            for ($i = 1; $i < 999; $i++) {
                $ii = sprintf("%04d", $i);
                $this->models->account_model->postAssignPlayer2(1, md5('123456'), '', $initCoin, $agent_id, 'demo' . $ii, 'acc2');
            }
        }
        
        return true;
    }

    public function _reset3Account(string $agent_id = '0', string $initCoin = '2000', string $password='123456') : bool
    {
        if (!! ($accounts = $this->mysql->getDb()->where('extent1', 'acc2')->get(MysqlTables::ACCOUNT, null, 'id,parent_id,pid,username,coin'))) {
            foreach ($accounts as $acc2) {
                $this->models->account_model->putPlayer(Helper::account_format_login($acc2['pid']), ['password'=>md5($password)]); //恢复一下密码为123456
            }
            return true;
        }

        return false;
    }

    /**
     * 获取操作日志
     * @param array $pars
     * @return array
     */
    public function getAgentApiLogs($pars = [])
    {
        $_limit_value = 20;
        $_limit_offset = ($pars['page'] = abs(intval($pars['page']))) > 0 ? ($pars['page'] - 1) * $_limit_value : 0;

        $result = array('total'=> 0, 'page'=> ! $pars['page'] ? 1 : $pars['page'], 'limit'=> $_limit_value, 'list'=> array());

        $db = $this->mysql->getDb();
        $fields = "log.*,a.username as account_username,a.nickname as account_nickname,v.username as account_v_username,v.nickname as account_v_nickname";
        $db->join(MysqlTables::ACCOUNT . ' AS a', "log.account_id=a.id", "left");
        $db->join(MysqlTables::ACCOUNT_CHILD_AGENT . ' AS v', "log.account_vid=v.vid", "left");

        // 只获取当前登录用户的操作日志
        $db->where('log.account_id', $this->getTokenObj()->account_id);

        //agent筛选
        if(isset($pars['agent']))
        {
            $db->where('log.account_agent', $pars['agent']);
        }

        //username筛选
        if(isset($pars['username']))
        {
            $db->where("(a.username like '%{$pars['username']}%' OR v.username like '%{$pars['username']}%')");
        }

        //nickname筛选
        if(isset($pars['nickname']))
        {
            $db->where("(a.nickname like '%{$pars['nickname']}%' OR v.nickname like '%{$pars['nickname']}%)'");
        }

        //ip筛选
        if(isset($pars['ip']))
        {
            $db->whereLike('log.ip', $pars['ip']);
        }

        //os筛选
        if(isset($pars['os']))
        {
            $db->whereLike('log.os', $pars['os']);
        }

        //browser筛选
        if(isset($pars['browser']))
        {
            $db->whereLike('log.browser', $pars['browser']);
        }

        //t筛选
        if(isset($pars['t']))
        {
            $db->whereLike('log.t', $pars['t']);
        }

        //detail筛选
        if(isset($pars['detail']))
        {
            $db->whereLike('log.detail', $pars['detail']);
        }

        //时间筛选
        if(isset($pars['time']) && isset($pars['time2']) && is_numeric($pars['time']) && is_numeric($pars['time2']) && $pars['time2'] > $pars['time'])
        {
            $db->where('log.create_time', [$pars['time'], $pars['time2']], 'BETWEEN');
        }

        if($pars['orderby'])
        {
            list($_od_f, $_od_b) = explode("|", $pars['orderby']);

            if(! $_od_b || ! in_array($_od_b, array('DESC', 'ASC')))
            {
                $this->setErrMsg('orderby参数非法');
                return false;
            }

            $orderby = "log.".$_od_f." ".$_od_b;
        }

        $orderBy = empty($pars['orderby']) ? 'log.id desc' : $orderby;
        list($orderByField, $orderByDirection) = explode(' ', $orderBy);
        $db->orderBy($orderByField, $orderByDirection);
        $result['list'] = $db->withTotalCount()->get(MysqlTables::LOG_API_BACKOFFICE . ' AS log', [$_limit_offset, $_limit_value], $fields);
        
        if (isset($pars['lan']) && $pars['lan'] == 2) {
            foreach ($result['list'] as &$item) {
                $item['t'] = $item['t2'];
                $item['detail'] = $item['detail2'];
            }
        }
        
        $result['total'] = $db->getTotalCount();

        // 取最新1000条
        $result['total'] = $result['total'] >= 1000 ? 1000 : $result['total'];

        return $result;
    }

    /**
     * 税池清空日志
     * @param int $page
     * @param int $limitValue
     * @return array
     */
    public function emptyTaxLog($page, $limitValue = 10)
    {
        $offset = ($page = abs(intval($page))) > 0 ? ($page - 1) * $limitValue : 0;
        $result = ['total'=> 0, 'list'=> []];
        $db = $this->mysql->getDb();
        $list = $db->orderBy('create_time', 'desc')->withTotalCount()->get(MysqlTables::POOL_TAX_RESET, [$offset, $limitValue]);
        $result['list'] = $list;
        $result['total'] = $db->getTotalCount();
        return $result;
    }

    public function setMultgamesetting($username, $gameId, $setting)
    {
        $db = $this->mysql->getDb();

        $set = json_decode($setting, true);

        if (isset($set['chips'])) { //设定下注额，只能针对直属代理
            $type = 2;
            $account = $db->where("username='{$username}' OR pid='{$username}'")->where('parent_id', $this->getTokenObj()->account_id)->getOne(MysqlTables::ACCOUNT);
            if (empty($account)) {
                $this->setErrCode(4001);
                $this->setErrMsg('代理不存在或者非直属代理', true);
                return false;
            }
        } elseif (isset($set['state'])) { //关闭子游戏，针对直属代理和玩家
            $type = 1;
            $account = $db->where("username='{$username}' OR pid='{$username}'")->where('parent_id', $this->getTokenObj()->account_id)->getOne(MysqlTables::ACCOUNT);
            if (empty($account)) {
                $this->setErrCode(4001);
                $this->setErrMsg('代理不存在或者非直属代理或玩家', true);
                return false;
            }
        }
        
        $uids = [];
        if ($account['agent'] == 0) { //玩家
            $account['online'] == 1 && $uids[] = $account['id'];
            $redisKey = RedisKey::BET_MIN_MAX . $account['id'];
            $this->gameSetting($redisKey, $gameId, $setting);
        } else { //代理
            // 获取该代理的直属玩家
            $players = $db->where('parent_id', $account['id'])->where('agent', 0)->get(MysqlTables::ACCOUNT, null, 'id, online, pid');
            $redis = $this->redis->getDb();
            foreach ($players as $row) {
                if ($row['online'] == 1) {
                    $uids[] = $row['id'];
                }
                $redisKey = RedisKey::BET_MIN_MAX . $row['id'];
                $this->gameSetting($redisKey, $gameId, $setting);
            }

            // 保存该代理设置
            $this->gameSetting(RedisKey::BET_MIN_MAX . $account['id'], $gameId, $setting);
        }

        if ($uids) {
            $this->models->curl_model->notifyGameSetting(implode(',', $uids), $gameId, $setting, $type);
        }

        return true;
    }

    private function gameSetting($redisKey, $gameId, $setting)
    {
        $redis = $this->redis->getDb();
        if ($set = $redis->hGet($redisKey, $gameId)) {
            $set = json_decode($set, true);
            $setting = json_decode($setting, true);
            foreach ($setting as $key => $value) {
                $set[$key] = $value;
            }
            $setting = json_encode($set);
        }
        $redis->hSet($redisKey, $gameId, $setting);
    }

    public function getMultgamesetting($username, $gameId)
    {
        $db = $this->mysql->getDb();

        // 判断是否直属代理
        $account = $db->where("username='{$username}' OR pid='{$username}'")->where('parent_id', $this->getTokenObj()->account_id)->getOne(MysqlTables::ACCOUNT);
        if (empty($account)) {
            $this->setErrCode(4001);
            $this->setErrMsg('代理不存在或者非直属代理或玩家', true);
            return false;
        }

        $redis = $this->redis->getDb();
        $redisKey = RedisKey::BET_MIN_MAX . $account['id'];
        $data = $redis->hGet($redisKey, $gameId);
        $result = $data ? json_decode($data, true) : [];

        return $result;
    }

    public function getRegions()
    {
        $db = $this->mysql->getDb();

        return $db->get(MysqlTables::REGION);
    }

    public function postAccountSetting($data)
    {
        $db = $this->mysql->getDb();

        $accountId = $this->getTokenObj()->account_id;

        if ($db->where('account_id', $accountId)->get(MysqlTables::ACCOUNT_SETTING)) {
            $rs = $db->where('account_id', $accountId)->update(MysqlTables::ACCOUNT_SETTING, $data);
        } else {
            $data['account_id'] = $accountId;
            $rs = $db->insert(MysqlTables::ACCOUNT_SETTING, $data);
        }

        if ($rs === true) {
            return true;
        }

        return false;
    }

    public function getAccountSetting()
    {
        $db = $this->mysql->getDb();

        $accountId = $this->getTokenObj()->account_id;

        $rs = $db->where('account_id', $accountId)->getOne(MysqlTables::ACCOUNT_SETTING);

        return $rs ? $rs : [];
    }
}