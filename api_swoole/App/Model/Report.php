<?php

namespace App\Model;

use App\Model\Constants\MysqlTables;
use App\Utility\Helper;

class Report extends Model
{
    /**
     * @param $account
     * @return array
     * @desc 获取玩家最近10条登录ip
     */
    public function getPlayerLast10LoginIP($account)
    {
        $db = $this->mysql->getDb();
        $token = $this->getTokenObj();
        $player = $db->where('pid', $account)->getOne(MysqlTables::ACCOUNT);
        if (empty($player)) {
            return ['list' => []];
        }

        if (!$this->models->account_model->isDescendant($token->account_id, $player['id'])) {
            return ['list' => []];
        }

        $where = [];
        $where['account_pid'] = $account;
        $where['t'] = [1,2];
        $where['ip!='] = "";
        $db->where('account_pid', $account)
            ->where('t', [1,2], 'in')
            ->where('ip', '', '<>')
            ->orderBy('create_time', 'desc');
        $list = $db->get(MysqlTables::LOG_LOGIN_PLAYER, [0, 10], 'ip, create_time');
        return ['list' => $list];
    }

    /**
     * @param int $startTime
     * @param int $endTime
     * @return array
     * @throws \EasySwoole\Mysqli\Exceptions\ConnectFail
     * @throws \EasySwoole\Mysqli\Exceptions\PrepareQueryFail
     * @throws \Throwable
     * @desc 获取游戏下注总次数列表
     */
    public function getGameBetNumsList($startTime = 0, $endTime = 0)
    {
        $db = $this->mysql->getDb();
        $startTime && $endTime && $db->where('minute', [$startTime, $endTime], 'BETWEEN');
        $list = $db->get(MysqlTables::STAT_BET_NUMS, null, 'minute, data');

        foreach ($list as &$one) {
            $one['minute'] = date('Y-m-d H:i:00', $one['minute']);
            $one['data'] = json_decode($one['data'], true);
        }

        return ['list' => $list];
    }

    /**
     * @param int $startTime
     * @param int $endTime
     * @return array
     * @throws \EasySwoole\Mysqli\Exceptions\ConnectFail
     * @throws \EasySwoole\Mysqli\Exceptions\PrepareQueryFail
     * @throws \Throwable
     * @desc 获取游戏对库存变化的列表
     */
    public function getMainpoolList($startTime = 0, $endTime = 0)
    {
        $db = $this->mysql->getDb();
        $startTime && $endTime && $db->where('dtime', [$startTime, $endTime], 'BETWEEN');
        $list = $db->get(MysqlTables::STAT_MAINPOLL, null, 'dtime, data');
        foreach ($list as &$one) {
            $one['dtime'] = date('Y-m-d', $one['dtime']);
            $one['data'] = json_decode($one['data'], true);
        }

        return ['list' => $list];
    }

    /**
     * @param int $gameId
     * @param int $startTime
     * @param int $endTime
     * @return \App\Utility\Pool\MysqlObject|array|mixed
     * @throws \EasySwoole\Mysqli\Exceptions\ConnectFail
     * @throws \EasySwoole\Mysqli\Exceptions\PrepareQueryFail
     * @throws \Throwable
     * @desc 获取游戏对库存的变化
     */
    public function getMainpool($gameId = 0, $startTime = 0, $endTime = 0)
    {
        $db = $this->mysql->getDb();
        $startTime && $endTime && $db->where('create_time', [$startTime, $endTime], 'BETWEEN');
        $gameId > 0 && $db->where('game_id', $gameId);
        $db->where('type', [1, 2], 'BETWEEN')->groupBy('game_id');
        $list = $db->get(MysqlTables::POOL_NORMAL, null, "game_id,SUM(coin) AS coin");
        if ($list) {
            $list = array_column($list, 'coin', 'game_id');
        }
        $list[0] = array_sum($list); // 总库存
        foreach ($list as &$one) {
            $one = Helper::format_money($one);
        }
        return $list;
    }

    /**
     * 获取游戏服记录的本地子库存
     */
    public function getSelfSubMainPool() 
    {
        $_games = $this->models->curl_model->getGameLists(1);
        $result = [];
        if (!empty($_games)) {
            $key_pool = 'game:waterpool:';
            $key_pool_tax = 'game:waterpool_local:';
            $key_pool_rate = 'game:waterpool_rate:';
            $redis = $this->redis->getDb();
            foreach ($_games as $g) {
                $pool      = $redis->get($key_pool . $g['id']);
                $pool_tax  = $redis->get($key_pool_tax . $g['id']);
                $pool_rate = $redis->get($key_pool_rate . $g['id']);
                $result[$g['id']] = [
                    'id'   => $g['id'],
                    'name' => $g['name'],
                    'pool' => ($pool) ? floatval($pool) : 0,
                    'tax'  => ($pool_tax) ? floatval($pool_tax) : 0,
                    'rate' => ($pool_rate) ? floatval($pool_rate/10000) : 0,
                ];
            }
        }
        return $result;
    }

    /**
     * 获取玩家输赢
     * 总代：可查看所有玩家的输赢情况
     * 代理：查看旗下直属玩家的输赢情况
     */
    public function getPlayerWin($pid = '', $isControl = '0', $startTime = 0, $endTime = 0, $page = 1, $limitValue = 10, $orderBy = 'coin DESC')
    {
        $result = ['total' => 0, 'list' => [], 'count' => ['win' => '0.0000', 'reload' => '0.0000', 'ratio' => '0%']];
        $accountId = 0;
        $accountIds = [];
        $controlIds = [];

        $db = $this->mysql->getDb();

        // 获取被控制过的玩家
        if ($isControl > 0) {
            $sql = "SELECT DISTINCT id AS id FROM ((SELECT a.id FROM " . MysqlTables::SYS_GAME_PROB . " AS p LEFT JOIN account AS a ON p.account_id=a.id WHERE a.agent=0) UNION (SELECT a.id FROM " . MysqlTables::SYS_GAME_PROB . " AS p LEFT JOIN account AS a ON p.account_id=a.parent_agent_first_id WHERE a.agent=0)) AS a";
            $control = $db->rawQuery($sql);
            if ($isControl == 1 && empty($control)) {
                return $result;
            }
            $control && $controlIds = array_column($control, 'id');
        }

        if ($this->getTokenObj()->account_agent == 1) {
            // 获取直属玩家
            $db->where('parent_id', $this->getTokenObj()->account_id);
            if ($isControl == 1 && $controlIds) { //被控制过的玩家
                $db->where('id', $controlIds, 'in');
            } else if ($isControl == 2 && $controlIds) {
                $db->where("id not in (".implode(',', $controlIds).")");
            }
            $db->where('agent', 0);
            $accounts = $db->get(MysqlTables::ACCOUNT, null, 'id');
            $accountIds = array_column($accounts, 'id');
        }

        if ($pid) {
            $db->where("(id={$pid} OR pid={$pid})");
            if ($isControl == 1 && $controlIds) { //被控制过的玩家
                $db->where('id', $controlIds, 'in');
            } else if ($isControl == 2 && $controlIds) {
                $db->where("id not in (".implode(',', $controlIds).")");
            }
            $account = $db->getOne(MysqlTables::ACCOUNT);
            if (empty($account)) {
                return $result;
            }
            $accountId = $account['id'];
            // 该玩家不属于该代理，直接返回
            if ($accountId && $accountIds && !in_array($accountId, $accountIds)) {
                return $result;
            }
        }

        // 第一页计算总数
        if ($page == 1) {
            $sql = "SELECT SUM(b.reload) AS reload,SUM(b.win) AS win FROM account AS a LEFT JOIN";
            $sql .= " (SELECT account_id AS u_id, SUM(IF(type=1, coin, 0)) as reload, -1*SUM(IF(type IN (3,4,5,6), coin, 0)) as win FROM ".MysqlTables::COINS_PLAYER." WHERE";
            if ($startTime && $endTime) {
                $sql .= " create_time BETWEEN {$startTime} AND {$endTime}";
            }
            $sql .= " GROUP BY u_id) AS b ON a.id=b.u_id WHERE";
            if ($accountId) {
                $sql .= " a.id={$accountId} AND";
            } else if ($accountIds) {
                $sql .= " a.id in (".implode(',', $accountIds).") AND";
            } else {
                if ($controlIds && $isControl == 1) {
                    $sql .= " a.id in (".implode(',', $controlIds).") AND";
                } else if ($controlIds && $isControl == 2) {
                    $sql .= " a.id not in (".implode(',', $controlIds).") AND";
                }
            }
            $sql .= " a.agent=0 LIMIT 1";
            $count = $db->rawQuery($sql)[0];
            if ($count) {
                $reload = Helper::format_money($count['reload'] ? $count['reload'] : 0);
                $win = Helper::format_money($count['win'] ? $count['win'] : 0);
                $result['count']['reload'] = $reload;
                $result['count']['win'] = $win;
                $reload > 0 && $result['count']['ratio'] = round(($win/$reload)*100, 2) . '%';
            }
        }

        $offset = ($page - 1) * $limitValue;
        $sql = "SELECT a.id,a.pid,a.nickname,a.coin,b.reload,b.win FROM account AS a LEFT JOIN";
        $sql .= " (SELECT account_id AS u_id, SUM(IF(type=1, coin, 0)) as reload, -1*SUM(IF(type IN (3,4,5,6), coin, 0)) as win FROM ".MysqlTables::COINS_PLAYER." WHERE";
        if ($startTime && $endTime) {
            $sql .= " create_time BETWEEN {$startTime} AND {$endTime}";
        }
        $sql .= " GROUP BY u_id) AS b ON a.id=b.u_id WHERE";
        if ($accountId) {
            $sql .= " a.id={$accountId} AND";
        } else if ($accountIds) {
            $sql .= " a.id in (".implode(',', $accountIds).") AND";
        } else {
            if ($controlIds && $isControl == 1) {
                $sql .= " a.id in (".implode(',', $controlIds).") AND";
            } else if ($controlIds && $isControl == 2) {
                $sql .= " a.id not in (".implode(',', $controlIds).") AND";
            }
        }
        $orderBy = $orderBy ? $orderBy : 'coin DESC';
        $sql .= " a.agent=0 ORDER BY {$orderBy} LIMIT {$offset}, {$limitValue}";
        $result['list'] = $db->rawQuery($sql);
        foreach ($result['list'] as &$one) {
            $one['coin'] = Helper::format_money($one['coin'] ? $one['coin'] : 0);
            $one['reload'] = Helper::format_money($one['reload'] ? $one['reload'] : 0);
            $one['win'] = Helper::format_money($one['win'] ? $one['win'] : 0);
            $one['ratio'] = $one['reload'] > 0 ? (round(($one['win']/$one['reload'])*100, 2) . '%') : '0%';
        }

        if ($accountId) {
            $db->where('id', $accountId);
        } else if ($accountIds) {
            $db->where('id', $accountIds, 'in');
        } else {
            if ($controlIds && $isControl == 1) {
                $db->where('id', $controlIds, 'in');
            } else if ($controlIds && $isControl == 2) {
                $db->where("id not in (".implode(',', $controlIds).")");
            }
        }
        $result['total'] = $db->count(MysqlTables::ACCOUNT);
        return $result;
    }

    /**
     * @param string $keywords
     * @param int $page
     * @param int $limitValue
     * @param string $orderBy
     * @return array
     * @throws \EasySwoole\Mysqli\Exceptions\ConnectFail
     * @throws \EasySwoole\Mysqli\Exceptions\OrderByFail
     * @throws \EasySwoole\Mysqli\Exceptions\PrepareQueryFail
     * @throws \Throwable
     * @desc 获取玩家列表
     */
    public function getAllPlayers($keywords = '', $page = 1, $limitValue = 20, $orderBy = '')
    {
        $result = ['list' => [], 'total' => 0];
        $offset = ($page - 1) * $limitValue;
        $db = $this->mysql->getDb();
        $keywords && $db->where("(id=? OR pid=?)", [$keywords, Helper::account_format_login($keywords)]);
        $db->where('agent', 0);
        $countDb = clone $db;
        $count = $countDb->count(MysqlTables::ACCOUNT);
        if ($count > 0) {
            $orderBy = empty($orderBy) ? 'id desc' : $orderBy;
            list($orderByField, $orderByDirection) = explode(' ', $orderBy);
            $db->orderBy($orderByField, $orderByDirection);
            $list = $db->get(MysqlTables::ACCOUNT, [$offset, $limitValue], 'id, pid, nickname, vip, create_time, login_time, agent, coin, online');
            $ids = array_column($list, 'id');
            $db = $this->mysql->getDb();
            $db->where('descendant_id', $ids, 'in')->groupBy('descendant_id');
            $accountBan = $db->get(MysqlTables::ACCOUNT_BAN, null, 'descendant_id, count(1) AS nums');
            $accountBan && $accountBan = array_column($accountBan, null, 'descendant_id');
            $online = $this->models->curl_model->getOnlinePlayerOne($ids);
            foreach ($list as &$one) {
                $one['online'] = $online[$one['id']] ? 1 : 0;
                $one['status_ban'] = isset($accountBan[$one['id']]) ? 1 : 0;
                $one['create_time'] = $one['create_time'] > 0 ? date('Y-m-d H:i:s', $one['create_time']) : 0;
                $one['login_time'] = $one['login_time'] > 0 ? date('Y-m-d H:i:s', $one['login_time']) : 0;
            }
            $result['list'] = $list;
            $result['total'] = $count;
        }
        return $result;
    }

    /**
     * @param int $keywords
     * @param int $page
     * @param int $limitValue
     * @param int $startTime
     * @param int $endTime
     * @param string $orderBy
     * @return array
     * @throws \EasySwoole\Mysqli\Exceptions\ConnectFail
     * @throws \EasySwoole\Mysqli\Exceptions\OrderByFail
     * @throws \EasySwoole\Mysqli\Exceptions\PrepareQueryFail
     * @throws \Throwable
     * @desc 获取玩家明细列表
     */
    public function getPlayerDetails($keywords = 0, $page = 0, $limitValue = 10, $startTime = 0, $endTime = 0, $orderBy = 'create_time desc')
    {
        $offset = ($page = abs(intval($page))) > 0 ? ($page - 1) * $limitValue : 0;
        $result = ['list'=> [], 'total'=> 0];
        $db = $this->mysql->getDb();
        $db->join(MysqlTables::ACCOUNT . ' AS a', 'c.account_id=a.id', 'LEFT');
        if ($startTime && $endTime) {
            $db->where('c.create_time', [$startTime, $endTime], 'BETWEEN');
        }
        if ($keywords) {
            $db->where("a.id={$keywords} OR a.pid={$keywords}");
        }
        list($orderByField, $orderByDirection) = explode(' ', $orderBy);
        $db->orderBy($orderByField, $orderByDirection);
        $fields = "a.id, a.pid, c.coin, c.`before`, c.`after`, c.type, c.game_id, c.create_time";
        $rs = $db->withTotalCount()->get(MysqlTables::COINS_PLAYER . ' AS c', [$offset, $limitValue], $fields);
        $result['list'] = $rs;
        $result['total'] = $db->getTotalCount();
        return $result;
    }
}