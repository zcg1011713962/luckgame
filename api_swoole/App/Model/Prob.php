<?php

namespace App\Model;

use App\Model\Constants\MysqlTables;
use App\Model\Constants\RedisKey;
use App\Utility\Helper;

class Prob extends Model
{
    private $_key_prob_uid = RedisKey::PROB_SET_UID_;
    private $_key_prob_agent = RedisKey::PROB_SET_AGENT_;

    /**
     * 获取概率控制列表
     * @param int $page
     * @param string $keyword
     * @return array
     */
    public function getProbs($page = 0, $keyword = '')
    {
        $limitValue = 10;
        $offset = ($page = abs(intval($page))) > 0 ? ($page - 1) * $limitValue : 0;

        $result = array('total'=> 0, 'page'=> ! $page ? 1 : $page, 'limit'=> $limitValue, 'list'=> array());

        $endTime = time();
        $startTime = $endTime - 86400*7;
        $db = $this->mysql->getDb();
        $db->join(MysqlTables::ACCOUNT . ' AS a', 'p.account_id=a.id', 'left');
        $fields = 'p.id,p.account_id, p.prob, p.status, p.duration, p.create_time, (CONVERT(p.duration,SIGNED)*60+CONVERT(p.create_time,SIGNED)-CONVERT(unix_timestamp(now()),SIGNED)) as remain_time, a.nickname, a.username, a.pid';
        $keyword && $db->where("a.username like '%{$keyword}%' or a.pid like '%{$keyword}%' or a.nickname like '%{$keyword}%'");
        $db->orderBy('p.status', 'asc');
        $db->orderBy('remain_time', 'desc');
        $db->orderBy('create_time', 'desc');
        $list = $db->withTotalCount()->get(MysqlTables::SYS_GAME_PROB . ' AS p', [$offset, $limitValue], $fields);
        $result['total'] = $db->getTotalCount();

        if ($list) {
            $accountIds = array_unique(array_column($list, 'account_id'));

            $db->join(MysqlTables::ACCOUNT_TREE . ' AS t', 'a.id=t.ancestor_id', 'left');
            $db->join(MysqlTables::COINS_PLAYER . ' AS c', "t.descendant_id=c.account_id AND c.create_time BETWEEN {$startTime} AND {$endTime}", 'LEFT');
            $fields = "a.id, a.agent, SUM(IF(c.type=1, c.coin, 0)) AS add_coin, -1*SUM(IF(c.type=2, c.coin, 0)) AS sub_coin";
            $db->where('a.id', $accountIds, 'in');
            $data = $db->groupBy('a.id')->get(MysqlTables::ACCOUNT . ' AS a', null, $fields);
            $data = array_column($data, NULL, 'id');
            foreach ($list as &$one) {
                if (isset($data[$one['account_id']])) {
                    $one['add_coin'] = $data[$one['account_id']]['add_coin'];
                    $one['sub_coin'] = $data[$one['account_id']]['sub_coin'];
                }
            }
        }
        $result['list'] = $list;
        return $result;
    }

    /**
     * 添加概率控制
     * @param $accountId 用户ID
     * @param $prob 概率
     * @param $duration 有效时长（分钟）
     * @return array|bool
     */
    public function postProb($accountId, $prob, $duration)
    {
        $time = time();
        $db = $this->mysql->getDb();
        $db->startTransaction();

        $db->where('account_id', $accountId)->where('status', 0)->update(MysqlTables::SYS_GAME_PROB, ['status' => 1]);

        $data = array(
            'account_id' => $accountId,
            'prob' => $prob,
            'duration' => $duration,
            'status' => 0,
            'operator' => $this->getTokenObj()->account_id,
            'create_time'=> $time
        );
        $db->insert(MysqlTables::SYS_GAME_PROB, $data);
        if (!$lastId = $db->getInsertId()) {
            $db->rollback();
            $this->setErrMsg('数据库操作prob');
            return FALSE;
        }

        // 将概率信息推送到服务器
        $account = $db->where('id', $accountId)->getOne(MysqlTables::ACCOUNT);
        $redis = $this->redis->getDb();
        $expire = $duration * 60;
        $key = $this->_key_prob_agent . $accountId;
        $redis->setex($key, $expire, $prob);
        if ($account['agent'] == 1) {
            $accounts = $db->where('parent_agent_first_id', $accountId)->where('agent', 0)->get(MysqlTables::ACCOUNT, null, 'id');
            $ids = array_column($accounts, 'id');
            $limit = 2000;
            $params = array(
                'st_p' => $time,
                't_p' => 2,
                'vt_p' => $expire,
                'v_p' => $prob
            );
            // 每次只能传输2000个uid
            $offset = 0;
            while(1) {
                $uids = array_slice($ids, $offset, $limit);
                if ($uids) {
                    if (!$this->models->curl_model->pushPlayerProb($uids, $params)) {
                        $db->rollback();
                        $this->setErrMsg('游戏服务器操作失败');
                        return FALSE;
                    }
                } else {
                    break;
                }
                $offset += $limit;
            }
            foreach ($accounts as $row) {
                $key = $this->_key_prob_agent . $row['id'];
                $redis->setex($key, $expire, $prob);
            }
        } else {
            $params = array(
                'st_p' => $time,
                't_p' => 1,
                'vt_p' => $expire,
                'v_p' => $prob
            );
            if (!$this->models->curl_model->pushPlayerProb(array($accountId), $params)) {
                $db->rollback();
                $this->setErrMsg('游戏服务器操作失败');
                return FALSE;
            }
            $key = $this->_key_prob_uid . $accountId;
            $redis->setex($key, $expire, $prob);
        }

        $db->commit();
        return array('id' => $lastId);
    }

    public function pushProbByUids($agentId, $uids)
    {
        if (empty($uids)) {
            return FALSE;
        }
        $db = $this->mysql->getDb();
        $prob = $db->where('account_id', $agentId)->orderBy('create_time', 'desc')->getOne(MysqlTables::SYS_GAME_PROB);
        $time = time();
        if (empty($prob) || ($expire = $prob['duration']*60 + $prob['create_time'] - $time) <= 0) {
            return FALSE;
        }
        $params = array(
            'st_p' => $time,
            't_p' => 2,
            'vt_p' => $expire,
            'v_p' => $prob['prob']
        );

        $redis = $this->redis->getDb();

        if (!$this->models->curl_model->pushPlayerProb($uids, $params)) {
            return FALSE;
        }
        foreach ($uids as $row) {
            $key = $this->_key_prob_agent . $row;
            $redis->setex($key, $expire, $prob['prob']);
        }
    }

    /**
     * 批量添加概率控制
     * @param $type
     * @param $prob
     * @param $duration
     * @param string $keyword
     * @param int $vip
     * @return array
     */
    public function postBatchProb($type, $prob, $duration, $keyword = '', $vip = 0)
    {
        $db = $this->mysql->getDb();
        // 获取总代账号
        $account = $db->where('agent', 2)->where('id', '1001', '<>')->getOne(MysqlTables::ACCOUNT);

        $result = array('rows' => 0);
        $redis = $this->redis->getDb();
        $time = time();
        $db->startTransaction();
        $expire = $duration * 60;
        $insertFields = ['account_id', 'prob', 'duration', 'status', 'operator', 'create_time'];
        if ($type == 'proxy') {
            $db->where('parent_id', $account['id'])->where('agent', 1);
            $keyword && $db->where("(username like '%{$keyword}%' or nickname like '%{$keyword}%')");
            $proxys = $db->get(MysqlTables::ACCOUNT, null, 'id');
            $set = array();
            foreach ($proxys as $row) {
                $set[] = [$row['id'], $prob, $duration, 0, $this->getTokenObj()->account_id, $time];
            }
            if ($set) {
                $proxyIds = array_column($proxys, 'id');
                $db->where('account_id', $proxyIds, 'in')->where('status', 0)->update(MysqlTables::SYS_GAME_PROB, ['status' => 1]);

                $result['rows'] = $db->insertMulti(MysqlTables::SYS_GAME_PROB, $set, $insertFields);
                if ($result['rows'] > 0) {
                    // 获取所有玩家
                    $accounts = $db->where('parent_agent_first_id', array_column($proxys, 'id'), 'in')->where('agent', 0)->get(MysqlTables::ACCOUNT, null, 'id');
                    $ids = array_column($accounts, 'id');
                    $limit = 2000;
                    $params = array(
                        'st_p' => $time,
                        't_p' => 2,
                        'vt_p' => $expire,
                        'v_p' => $prob
                    );
                    // 每次只能传输2000个uid
                    $offset = 0;
                    while(1) {
                        $uids = array_slice($ids, $offset, $limit);
                        if ($uids) {
                            if (!$this->models->curl_model->pushPlayerProb($uids, $params)) {
                                $db->rollback();
                                $this->setErrMsg('游戏服务器操作失败');
                                return FALSE;
                            }
                        } else {
                            break;
                        }
                        $offset += $limit;
                    }
                    foreach ($proxys as $row) {
                        $key = $this->_key_prob_agent . $row['id'];
                        $redis->setex($key, $expire, $prob);
                    }
                    foreach ($accounts as $row) {
                        $key = $this->_key_prob_agent . $row['id'];
                        $redis->setex($key, $expire, $prob);
                    }
                } else {
                    $db->rollback();
                    $this->setErrMsg('数据库操作prob');
                    return FALSE;
                }
            }
        } else {
            if ($keyword) { //必须传筛选条件
                // 获取总代的一级代理
                $firstProxy = $db->where('parent_id', $account['id'])->get(MysqlTables::ACCOUNT, null, 'id');
                if ($firstProxy) {
                    $firstProxyIds = array_unique(array_column($firstProxy, 'id'));
                    $db->where('parent_agent_first_id', $firstProxyIds, 'in');
                    $db->where('agent', 0);
                    $db->where("pid like '%{$keyword}%'");
                    $vip && $db->where('vip', $vip);
                    $players = $db->get(MysqlTables::ACCOUNT, null, 'id');
                    $set = array();
                    foreach ($players as $row) {
                        $set[] = [$row['id'], $prob, $duration, 0, $this->getTokenObj()->account_id, $time];
                    }
                    if ($set) {
                        $playerIds = array_column($players, 'id');
                        $db->where('account_id', $playerIds, 'in')->where('status', 0)->update(MysqlTables::SYS_GAME_PROB, ['status' => 1]);

                        $result['rows'] = $db->insertMulti(MysqlTables::SYS_GAME_PROB, $set, $insertFields);
                        if ($result['rows'] > 0) {
                            $ids = array_column($players, 'id');
                            $limit = 2000;
                            $params = array(
                                'st_p' => $time,
                                't_p' => 1,
                                'vt_p' => $expire,
                                'v_p' => $prob
                            );
                            // 每次只能传输2000个uid
                            $offset = 0;
                            while(1) {
                                $uids = array_slice($ids, $offset, $limit);
                                if ($uids) {
                                    if (!$this->models->curl_model->pushPlayerProb($uids, $params)) {
                                        $db->rollback();
                                        $this->setErrMsg('游戏服务器操作失败');
                                        return FALSE;
                                    }
                                } else {
                                    break;
                                }
                                $offset += $limit;
                            }
                            foreach ($players as $row) {
                                $key = $this->_key_prob_uid . $row['id'];
                                $redis->setex($key, $expire, $prob);
                            }
                        } else {
                            $db->rollback();
                            $this->setErrMsg('数据库操作prob');
                            return FALSE;
                        }
                    }
                }
            }
        }
        $db->commit();
        return $result;
    }

    public function getProxys($page, $keyword='', $orderBy = 'username DESC')
    {
        $limitValue = 10;
        $offset = ($page = abs(intval($page))) > 0 ? ($page - 1) * $limitValue : 0;

        $result = array('total'=> 0, 'page'=> ! $page ? 1 : $page, 'limit'=> $limitValue, 'list'=> array(), 'total_win' => '0.00');

        // 获取总代账号
        $db = $this->mysql->getDb();
        $account = $db->where('agent', 2)->where('id', '1001', '<>')->getOne(MysqlTables::ACCOUNT);

        $endTime = time();
        $startTime = $endTime - 86400*7;
        $db->join(MysqlTables::ACCOUNT_TREE . ' AS t', 'a.id=t.ancestor_id AND t.descendant_agent=0', 'LEFT');
        $db->join(MysqlTables::COINS_PLAYER . ' AS c', "t.descendant_id=c.account_id AND c.create_time BETWEEN {$startTime} AND {$endTime}", 'LEFT');
        $db->where('a.parent_id', $account['id']);
        $db->where('a.agent', 1);
        $keyword && $db->where("(a.username like '%{$keyword}%' or a.nickname like '%{$keyword}%')");
        // 第一页计算总赢钱
        if ($page == 1) {
            $totalDb = clone($db);
            $fields = "-1*SUM(IF(c.type IN (3, 4, 5, 6), c.coin, 0)) AS win";
            $data = $totalDb->getOne(MysqlTables::ACCOUNT . ' AS a', $fields);
            $result['total_win'] = Helper::format_money($data['win'] ? $data['win'] : 0);
        }
        $fields = "a.id, a.username, a.nickname, SUM(IF(c.type=1, c.coin, 0)) AS add_coin, -1*SUM(IF(c.type=2, c.coin, 0)) AS sub_coin, -1*SUM(IF(c.type IN (3, 4, 5, 6), c.coin, 0)) AS win";
        $db->groupBy('a.id');
        $orderBy = empty($orderBy) ? 'username desc' : $orderBy;
        list($orderByField, $orderByDirection) = explode(' ', $orderBy);
        $db->orderBy($orderByField, $orderByDirection);
        $list = $db->withTotalCount()->get(MysqlTables::ACCOUNT . ' AS a', [$offset, $limitValue], $fields);
        $result['total'] = $db->getTotalCount();
        foreach ($list as &$one) {
            $prob = $this->getUserProb($one['id']);
            $one['cur_prob'] = $prob ? $prob['prob'] : 3;
        }
        $result['list'] = $list;
        return $result;
    }

    public function getPlayers($page, $keyword, $vip = 0, $orderBy='win DESC')
    {
        $limitValue = 10;
        $offset = ($page = abs(intval($page))) > 0 ? ($page - 1) * $limitValue : 0;

        $result = array('total'=> 0, 'page'=> ! $page ? 1 : $page, 'limit'=> $limitValue, 'list'=> array(), 'total_win' => '0.00');

        // 获取总代账号
        $db = $this->mysql->getDb();
        $account = $db->where('agent', 2)->where('id', '1001', '<>')->getOne(MysqlTables::ACCOUNT);

        $firstProxy = $db->where('parent_id', $account['id'])->get(MysqlTables::ACCOUNT, null, 'id');
        if ($firstProxy) {
            $firstProxyIds = array_column($firstProxy, 'id');
            $endTime = time();
            $startTime = $endTime - 86400*7;
            $db->join(MysqlTables::COINS_PLAYER . ' AS c', "t.descendant_id=c.account_id AND c.create_time BETWEEN {$startTime} AND {$endTime}", 'LEFT');
            $db->where('a.parent_agent_first_id', $firstProxyIds)->where('a.agent', 0);
            $vip && $db->where('a.vip', $vip);
            $db->where("a.pid like '%{$keyword}%'");

            // 第一页计算总赢钱
            if ($page == 1) {
                $totalDb = clone $db;
                $fields = "-1*SUM(IF(c.type IN (3, 4, 5, 6), c.coin, 0)) AS win";
                $data = $totalDb->getOne(MysqlTables::ACCOUNT . ' AS a', $fields);
                $result['total_win'] = Helper::format_money($data['win'] ? $data['win'] : 0);
            }

            $fields = "a.id, a.pid, a.nickname, SUM(IF(c.type=1, c.coin, 0)) AS add_coin, -1*SUM(IF(c.type=2, c.coin, 0)) AS sub_coin, -1*SUM(IF(c.type IN (3, 4, 5, 6), c.coin, 0)) AS win";
            $db->groupBy('a.id');
            $orderBy = empty($orderBy) ? 'win desc' : $orderBy;
            list($orderByField, $orderByDirection) = explode(' ', $orderBy);
            $db->orderBy($orderByField, $orderByDirection);
            $list = $db->withTotalCount()->get(MysqlTables::ACCOUNT . ' AS a', [$offset, $limitValue], $fields);
            $result['total'] = $db->getTotalCount();
            foreach ($list as &$one) {
                $one['pid'] = Helper::account_format_display($one['pid']);
                $prob = $this->getUserProb($one['id']);
                $one['cur_prob'] = $prob ? $prob['prob'] : 3;
            }
            $result['list'] = $list;
        }
        return $result;
    }

    /**
     * 获取用户概率
     * @param $uid
     * @return array
     */
    public function getUserProb($uid)
    {
        $redis = $this->redis->getDb();
        $key = $this->_key_prob_uid . $uid;
        if ($prob = $redis->get($key)) {
            return ['prob' => $prob, 'expire' => $redis->ttl($key)];
        }
        $key = $this->_key_prob_agent . $uid;
        if ($prob = $redis->get($key)) {
            return ['prob' => $prob, 'expire' => $redis->ttl($key)];
        }
        
        return [];
    }
}