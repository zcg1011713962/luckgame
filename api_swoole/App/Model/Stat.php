<?php
namespace App\Model;

use App\Model\Constants\MysqlTables;
use App\Model\Constants\RedisKey;
use EasySwoole\EasySwoole\Config;
use App\Utility\Helper;

class Stat extends Model
{
    /**
     * 获取直属代理总上分
     * @param  integer startTime
     * @param  integer $endTime
     * @return [type]
     */
    public function getDirectlyAgentTotalReload($accountId, $startTime = 0, $endTime = 0)
    {
        $db = $this->mysql->getDb();
        $db->join(MysqlTables::SCORE_LOG . ' AS s', 'a.id=s.account_id', 'LEFT');
        $db->where('a.parent_id', $accountId);
        if ($startTime && $endTime) {
            $db->where('s.create_time', [$startTime, $endTime], 'BETWEEN');
        }
        $db->where('s.coin', 0, '>');
        $rs = $db->sum(MysqlTables::ACCOUNT . ' AS a', 's.coin');
        return Helper::format_money($rs);
    }

    /**
     * 获取所有玩家的总上下分
     * @param  integer $startTime
     * @param  integer $endTime
     * @return [type]
     */
    public function getAllPlayerTotalScore($startTime = 0, $endTime = 0)
    {
        $db = $this->mysql->getDb();
        if ($startTime && $endTime) {
            $db->where('create_time', [$startTime, $endTime], 'BETWEEN');
        }
        $db->where('agent', 0);
        $db->groupBy('type');
        $rs = $db->get(MysqlTables::SCORE_LOG, null, 'type, SUM(coin) AS coin');
        $rs = array_column($rs, 'coin', 'type');
        return [
            'reload' => Helper::format_money(isset($rs[1]) && $rs[1] ? $rs[1] : 0),
            'withdraw' => Helper::format_money(isset($rs[2]) && $rs[2] ? abs($rs[2]) : 0)
        ];
    }

    /**
     * 获取总抽水
     * @param  integer $startTime
     * @param  integer $endTime
     * @return [type]
     */
    public function getTotalPoolTax($startTime = 0, $endTime = 0)
    {
        $db = $this->mysql->getDb();
        if ($startTime && $endTime) {
            $db->where('create_time', [$startTime, $endTime], 'BETWEEN');
        }
        $db->where('type', 1);
        $rs = $db->sum(MysqlTables::POOL_TAX, 'coin');
        return Helper::format_money($rs);
    }

    /**
     * 获取总赢钱
     * @param  integer $startTime
     * @param  integer $endTime
     * @return [type]
     */
    public function getTotalWin($startTime = 0, $endTime = 0)
    {
        $db = $this->mysql->getDb();
        if ($startTime && $endTime) {
            $db->where('create_time', [$startTime, $endTime], 'BETWEEN');
        }
        // 3 下注，4 赢钱，5 bigbang，6 红包
        $db->where('type', [3, 4, 5, 6], 'IN');
        $rs = $db->sum(MysqlTables::COINS_PLAYER, 'coin');
        return -1 * Helper::format_money($rs);
    }

    /**
     * 欢迎页面
     * 管理员和总代
     * @return array
     */
    public function getWelcome()
    {
        $result = [
            'today_agent_total_add_coin' => '0.0000',
            'yesterday_agent_total_add_coin' => '0.0000',
            'today_player_total_add_coin' => '0.0000',
            'yesterday_player_total_add_coin' => '0.0000',
            'today_player_total_sub_coin' => '0.0000',
            'yesterday_player_total_sub_coin' => '0.0000',
            'today_total_consume_coin' => '0.0000',
            'yesterday_total_consume_coin' => '0.0000',
            'today_total_win_coin' => '0.0000',
            'yesterday_total_win_coin' => '0.0000',
            'total_reload' => '0.0000',
            'total_withdraw' => '0.0000',
            'total_win' => '0.0000'
        ];

        $todayStartTime = strtotime(date('Y-m-d'));
        $todayEndTime = $todayStartTime + 86399;
        $yesterdayStartTime = strtotime(date('Y-m-d', strtotime('-1 day')));
        $yesterdayEndTime = $yesterdayStartTime + 86399;

        $token = $this->getTokenObj();
        $db = $this->mysql->getDb();

        // 今日直属代理的上分合计
        // 昨日直属代理的上分合计
        $result['today_agent_total_add_coin'] = $this->getDirectlyAgentTotalReload($token->account_id, $todayStartTime, $todayEndTime);
        $result['yesterday_agent_total_add_coin'] = $this->getDirectlyAgentTotalReload($token->account_id, $yesterdayStartTime, $yesterdayEndTime);

        // 今日玩家总上分
        // 昨日玩家总上分
        // 今日玩家总下分
        // 昨日玩家总下分
        $today = $this->getAllPlayerTotalScore($todayStartTime, $todayEndTime);
        $yesterday = $this->getAllPlayerTotalScore($yesterdayStartTime, $yesterdayEndTime);
        
        $result['today_player_total_add_coin'] = $today['reload'];
        $result['yesterday_player_total_add_coin'] = $yesterday['reload'];;
        $result['today_player_total_sub_coin'] = $today['withdraw'];
        $result['yesterday_player_total_sub_coin'] = $yesterday['withdraw'];

        // 今日总抽水
        // 昨日总抽水
        $result['today_total_consume_coin'] = $this->getTotalPoolTax($todayStartTime, $todayEndTime);
        $result['yesterday_total_consume_coin'] = $this->getTotalPoolTax($yesterdayStartTime, $yesterdayEndTime);

        // 今日总赢钱
        // 昨日总赢钱
        $result['today_total_win_coin'] = $this->getTotalWin($todayStartTime, $todayEndTime);
        $result['yesterday_total_win_coin'] = $this->getTotalWin($yesterdayStartTime, $yesterdayEndTime);

        // 历史总上分
        // 历史总下分
        // 历史总赢钱
        $totalScore = $this->getAllPlayerTotalScore();
        $result['total_reload'] = $totalScore['reload'];
        $result['total_withdraw'] = $totalScore['withdraw'];
        $result['total_win'] = $this->getTotalWin();
        return $result;
    }

    /**
     * 获取系统报表
     * 系统管理员专用报表
     * 分游戏数据汇总
     * @param int $startTime
     * @param int $endTime
     * @return mixed
     */
    public function getStatSysExclusiveByGameid($startTime = 0, $endTime = 0)
    {
        $db = $this->mysql->getDb();
        $fields = 'game_id, COUNT(DISTINCT account_id) AS aux, COUNT(1) AS bet_num, SUM(bet) AS bet, SUM(bet-win) as sys_win_coin, SUM(IF(win<bet,1,0)) as sys_win_num';
        $startTime && $endTime && $db->where('create_time', [$startTime, $endTime], 'BETWEEN');
        $db->groupBy('game_id');
        $db->orderBy('aux', 'DESC');
        $rs = $db->get(MysqlTables::GAMESERVER_GAMELOG, null, $fields);
        foreach ($rs as &$one) {
            $one['sys_win_ratio'] = $one['bet_num'] > 0 && $one['sys_win_num'] > 0 ? $one['sys_win_num'] / $one['bet_num'] : 0;
            $one['sys_win_coin_ratio'] = $one['bet'] > 0 && $one['sys_win_coin'] > 0 ? $one['sys_win_coin'] / $one['bet'] : 0;
        }
        
        return $rs;
    }

    //查询玩家在指定时间内evo的输赢
    private function getEvoTotalWinByAccountAndTime($account_id, $start_time, $end_time)
    {
        $db = $this->mysql->getDb();
        $db->where('account_id', $account_id);
        $db->where('create_time', [$start_time, $end_time], 'BETWEEN');
        $totalWin = $db->sum(MysqlTables::GAMESERVER_GAMELOG_EVO, 'win - bet'); //玩家的输赢
        return (-1) * $totalWin;
    }

    // 按天查询玩家的赢钱和BigBang
    // 在指定时间范围内，每天一行，
    // 不论玩家有没有游戏记录
    public function getPlayerCoinByDay($pid, $page = 0, $limitValue = 10, $startDate = 0, $endDate = 0, $orderBy = 'date DESC')
    {
        $db = $this->mysql->getDb();
        // 根据pid获取account id
        $account = $db->where('pid', $pid)->getOne(MysqlTables::ACCOUNT);
        $accountId = 0;
        if (!empty($account)) {
            $accountId = $account['id'];
        }

        $startTime = strtotime($startDate);
        $endTime = strtotime($endDate) + 86399;
        $startDay = date('Ymd', $startTime);
        $endDay   = date('Ymd', $endTime);

        $totalWin = 0;
        // 第一页计算总赢钱
        if ($page == 1) {
            $db->where('create_time', [$startDay, $endDay], 'BETWEEN');
            $db->where('account_id', $accountId);
            $rs = $db->sum(MysqlTables::COINS_PLAYER_DAY, 'win');
            $totalWin = -1 * Helper::format_money($rs);
        }
        
        $evoTotal = $this->getEvoTotalWinByAccountAndTime($account['id'], $startTime, $endTime);
        $totalWin += $evoTotal;
        $offset = ($page = abs(intval($page))) > 0 ? ($page - 1) * $limitValue : 0;

        $fields = "'date' as date, create_time, -1*win as win, bigbang";
        $db->where('create_time', [$startDay, $endDay], 'BETWEEN');
        $db->where('account_id', $accountId);
        $orderBy = $orderBy ? $orderBy : 'create_time DESC';
        list($orderByField, $orderByDirection) = explode(' ', $orderBy);
        $db->orderBy($orderByField, $orderByDirection);
        $list = $db->withTotalCount()->get(MysqlTables::COINS_PLAYER_DAY, [$offset, $limitValue], $fields);
        foreach ($list as &$one) {
            $one['date'] = date('Y-m-d', strtotime($one['create_time']));
            $one['win'] = Helper::format_money($one['win']);
            $one['bigbang'] = Helper::format_money($one['bigbang']);
            $one['evowin'] = Helper::format_money($evoTotal); //evo 输赢
        }
        $result = ['list' => $list, 'total_win' => $totalWin, 'total' => $db->getTotalCount()];
        return $result;
    }

    // 按时间段查询代理赢钱和Bigbang
    // 代理本身排最上面（如果是总代理就不会有这行，因为没有玩家）
    // 下级代理按username排序
    public function getAgentCoinByDate($username, $page = 1, $limitValue = 10, $startDate = 0, $endDate = 0, $orderBy = 'username ASC')
    {
        $offset = ($page = abs(intval($page))) > 0 ? ($page - 1) * $limitValue : 0;
        $startTime = $endTime = 0;
        $db = $this->mysql->getDb();
        if ($startDate && $endDate) {
            $startTime = strtotime($startDate);
            $endTime = strtotime($endDate) + '86399';
        }

        $totalWin = 0;
        $selfData = array();
        // 代理本身排最上面（如果是总代理就不会有这行，因为没有玩家）
        $account = $db->where('username', $username)->getOne(MysqlTables::ACCOUNT);
        if (abs(intval($account['agent'])) == 1) {
            if ($page == 1) {
                $limitValue -= 1;
                $playerData = $this->_getDirectPlayerData($account['id'], $startTime, $endTime);
                $selfData[] = [
                    'id' => $account['id'],
                    'username' => $account['username'],
                    'nickname' => $account['nickname'],
                    'win' => Helper::format_money(isset($playerData['win']) && $playerData['win'] ? $playerData['win'] : 0),
                    'bigbang' => Helper::format_money(isset($playerData['bigbang']) && $playerData['bigbang'] ? $playerData['bigbang'] : 0)
                ];
                isset($playerData['win']) && $totalWin += $playerData['win'];
            }
        }

        if ($page == 1) { // 第一页计算总赢钱
            $totalWin += $this->_getDirectAgentTotalWin($account['id'], $startTime, $endTime);
        }
        $total = $db->where('parent_id', $account['id'])->where('agent', 0, '>')->count(MysqlTables::ACCOUNT);
        $list = $this->_getDirectAgentDataList($account['id'], $startTime, $endTime, $offset, $limitValue, $orderBy);

        foreach ($list as &$one) {
            $one['win'] = Helper::format_money($one['win'] ? $one['win'] : 0);
            $one['bigbang'] = Helper::format_money($one['bigbang'] ? $one['bigbang'] : 0);
        }

        return ['list' => array_merge($selfData, $list), 'total' => $total+1, 'total_win' => Helper::format_money($totalWin)];
    }

    /**
     * 获取直属玩家赢钱和Bigbang
     */
    private function _getDirectPlayerData($accountId, $startTime, $endTime)
    {
        $db = $this->mysql->getDb();
        $joinWhere = 'a.id=c.account_id';
        $where = "";
        if ($startTime && $endTime) {
            $startDay = date('Ymd', $startTime);
            $endDay = date('Ymd', $endTime);

            $where = ' where create_time BETWEEN ' . $startDay . ' AND ' . $endDay;
        }
        $db->join("(select account_id, win, bigbang from coins_player_day {$where}) as c", $joinWhere, 'LEFT');
        $db->where('a.parent_id', $accountId);
        $fields = '-1*SUM(c.win) AS win, SUM(c.bigbang) AS bigbang';
        $rs = $db->getOne(MysqlTables::ACCOUNT . ' AS a', $fields);
        return $rs;
    }

    /**
     * 获取直属代理赢钱和Bigbang（其下所有玩家）
     */
    private function _getDirectAgentDataList($accountId, $startTime, $endTime, $offset, $limitValue, $orderBy)
    {
        $db = $this->mysql->getDb();

        $db->join(MysqlTables::ACCOUNT_TREE . ' AS t', 'a.id=t.ancestor_id', 'LEFT');
        $joinWhere = 't.descendant_id=c.account_id';
        $where = "";
        if ($startTime && $endTime) {
            $startDay = date('Ymd', $startTime);
            $endDay = date('Ymd', $endTime);
            $where = ' where create_time BETWEEN ' . $startDay . ' AND ' . $endDay;
        }
        $db->join("(select account_id, win, bigbang from coins_player_day {$where}) as c", $joinWhere, 'LEFT');
        $fields = 'a.id, a.username, a.nickname, -1*SUM(c.win) AS win, SUM(c.bigbang) AS bigbang';
        $db->groupBy('a.id');
        $orderBy = $orderBy ? $orderBy : 'username ASC';
        list($orderByField, $orderByDirection) = explode(' ', $orderBy);
        $db->orderBy($orderByField, $orderByDirection);
        $db->where('a.parent_id', $accountId);
        $db->where('a.agent', 0, '>');
        $db->where('t.descendant_agent', 0);
        $rs = $db->get(MysqlTables::ACCOUNT . ' AS a', [$offset, $limitValue], $fields);
        return $rs;
    }

    /**
     * 获取直属代理总赢钱（其下所有玩家）
     */
    private function _getDirectAgentTotalWin($accountId, $startTime, $endTime)
    {
        // $sql = "SELECT SUM(coin) AS retval FROM " . MysqlTables::COINS_PLAYER . " WHERE ";
        // if ($startTime && $endTime) {
        //     $sql .= "create_time BETWEEN {$startTime} AND {$endTime} AND ";
        // }
        // $sql .= "type IN (3,4,5,6) AND account_id IN (SELECT descendant_id from " . MysqlTables::ACCOUNT . " as a LEFT JOIN " . MysqlTables::ACCOUNT_TREE . " AS t ON a.id=t.ancestor_id WHERE a.parent_id={$accountId} AND t.descendant_agent=0)";

        $where = "";
        if($startTime && $endTime) {
            $startDay = date('Ymd', $startTime);
            $endDay = date('Ymd', $endTime);
            $where = ' where create_time BETWEEN ' . $startDay . ' AND ' . $endDay;
        }
        $sql  = "select sum(c.win) as retval from account as a ";
        $sql .= "left join account_tree as t on a.id = t.ancestor_id ";
        $sql .= "left join (select account_id,win  from coins_player_day {$where}) as c on t.descendant_id = c.account_id ";
        $sql .= "where a.parent_id={$accountId} and t.descendant_agent = 0 ";
        $rs = $this->mysql->getDb()->rawQuery($sql);
        return isset($rs['retval']) ? -1*Helper::format_money($rs['retval']) : 0;
    }

    // 代理总账明细
    public function getAgentCoinDetailByDay($username, $page = 0, $limitValue = 10, $startDate = 0, $endDate = 0, $orderBy = 'date DESC')
    {
        $db = $this->mysql->getDb();
        $account = $db->where('username', $username)->getOne(MysqlTables::ACCOUNT);
        $accounts = array();
        $data = array();
        if ($account['id'] == $this->getTokenObj()->account_id) { //明细是代理自己,统计其下直属玩家
            // 获取直属玩家id
            $accounts = $db->where('parent_id', $account['id'])->where('agent', 0)->get(MysqlTables::ACCOUNT, null, 'id');
        } else { // 其下所有代理所有玩家
            // 获取所有玩家
            $accounts = $db->where('ancestor_id', $account['id'])->where('descendant_agent', 0)->get(MysqlTables::ACCOUNT_TREE, null, 'descendant_id as id');
        }

        $offset = ($page = abs(intval($page))) > 0 ? ($page - 1) * $limitValue : 0;
        if ($accounts) {
            $rs = $this->_getPlayerDataByDate(array_column($accounts, 'id'), $offset, $limitValue, $startDate, $endDate, $orderBy);
            $total = $rs['total'];
            $list = $rs['list'];

            $totalWin = '0.00';
            // 第一页计算总赢钱
            if ($page == 1) {
                $startTime = $endTime = 0;
                if ($startDate && $endDate) {
                    $startTime = strtotime($startDate);
                    $endTime = strtotime($endDate) + 86400;
                }
                $totalWin = Helper::format_money($this->_getPlayerTotalWinByPlayerIds(array_column($accounts, 'id'), $startTime, $endTime));
            }
            $result = array('list' => array_values($list), 'total_win' => $totalWin, 'total' => $total);
            return $result;
        } else {
            $db->where('date', [$startDate, $endDate], 'BETWEEN');
            $db->groupBy('date');
            $orderBy = empty($orderBy) ? 'date desc' : $orderBy;
            list($orderByField, $orderByDirection) = explode(' ', $orderBy);
            $db->orderBy($orderByField, $orderByDirection);
            $list = $db->withTotalCount()->get(MysqlTables::ASSIST_DATELIST, [$offset, $limitValue], 'date, abs(0) as win, abs(0) as bigbang');
            $totalWin = '0.00';
            $result = ['list' => array_values($list), 'total_win' => $totalWin, 'total' => $db->getTotalCount()];
            return $result;
        }
    }

    /*
     * 按天获取玩家赢钱和Bigbang
     */
    private function _getPlayerDataByDate($playerIds, $offset, $limitValue, $startDate = 0, $endDate = 0, $orderBy = 'date desc')
    {
        $startTime = strtotime($startDate);
        $endTime = strtotime($endDate) + 86399;
        $joinTable = "(SELECT FROM_UNIXTIME(create_time,'%Y-%m-%d') AS date, -1*SUM(coin) AS win, SUM(IF(type=5,coin,0)) AS bigbang FROM " . MysqlTables::COINS_PLAYER . " WHERE create_time BETWEEN {$startTime} AND {$endTime} AND account_id IN (" . implode(',', $playerIds) . ") AND type IN (3,4,5,6) GROUP BY date)";
        $db = $this->mysql->getDb();
        // $offset = ($page = abs(intval($page))) > 0 ? ($page - 1) * $limitValue : 0;
        $fields = "d.date, win, bigbang";
        $db->join($joinTable . ' AS c', 'd.date=c.date', 'LEFT');
        $db->where('d.date', [$startDate, $endDate], 'BETWEEN');
        // $db->groupBy('d.date');
        $orderBy = $orderBy ? $orderBy : 'date DESC';
        list($orderByField, $orderByDirection) = explode(' ', $orderBy);
        $db->orderBy($orderByField, $orderByDirection);
        $rs = $db->withTotalCount()->get(MysqlTables::ASSIST_DATELIST . ' AS d', [$offset, $limitValue], $fields);
        return [
            'list' => $rs,
            'total' => $db->getTotalCount()
        ];
    }

    /**
     * 根据玩家ID获取总赢钱
     */
    private function _getPlayerTotalWinByPlayerIds($playerIds, $startTime = 0, $endTime = 0)
    {
        $db = $this->mysql->getDb();
        $playerIds && $db->where('account_id', $playerIds, 'IN');
        if ($startTime && $endTime) {
            $db->where('create_time', [$startTime, $endTime], 'BETWEEN');
        }
        // 3 下注，4 赢钱，5 bigbang，6 红包
        $db->where('type', [3, 4, 5, 6], 'IN');
        $rs = $db->sum(MysqlTables::COINS_PLAYER, 'coin');
        return -1 * Helper::format_money($rs);
    }

    // 总代报表
    // 总代直属代理，每个代理一行
    // 代理上下分是总代对该代理的上下分操作
    // 玩家上下分是代理其下各级的所有玩家在指定时间段内的数据汇总
    public function generalAgentReport($page, $limitValue, $startDate, $endDate, $field = 'username', $order = 'desc', $username = '')
    {
        $list = $agentCoinList = $playerCoinList = $agentWithdraw = $agentReload = $playerWithdraw = $playerReload = array();
        $result = ['list' => array(), 'total' => 0, 'total_add_coin' => 0.0000, 'total_sub_coin' => 0.0000, 'total_diff_coin' => 0.0000];
        $offset = ($page = abs(intval($page))) > 0 ? ($page - 1) * $limitValue : 0;
        $startTime = strtotime($startDate);
        $endTime = strtotime($endDate) + 86400;
        $field = $field ? $field : 'username';
        $order = $order ? $order : 'desc';

        $db = $this->mysql->getDb();
        $agentId = 0;
        // 获取总代ID
        if ($username) {
            $agent = $db->where('username', $username)->getOne(MysqlTables::ACCOUNT, 'id');
            $agent && $agentId = $agent['id'];
        }
        if (!$agentId) {
            $agent = $db->where('agent', 2)->where('id', 1001, '>')->getOne(MysqlTables::ACCOUNT, 'id');
            $agentId = $agent['id'];
        }
        
        // 获取总数
        $result['total'] = $this->mysql->getDb()->where('parent_id', $agentId)->count(MysqlTables::ACCOUNT);
        if ($result['total'] == 0) {
            return $result;
        }

        if ($page == 1) {
            $agentReload = $this->_getAgentReload($agentId, $startTime, $endTime);
            $agentWithdraw = $this->_getAgentWithdraw($agentId, $startTime, $endTime);
            $playerReload = $this->_getPlayerReload($agentId, $startTime, $endTime);
            $playerWithdraw = $this->_getPlayerWithdraw($agentId, $startTime, $endTime);
        }

        if (in_array($field, array('username', 'nickname', 'agent_add_coin', 'agent_sub_coin'))) {
            $agentCoinList = $this->_getAgentData("a.parent_id = {$agentId}", $startTime, $endTime, $field, $order, $offset, $limitValue);
            $agentCoinList = array_column($agentCoinList, NULL, 'id');
            $ids = implode(',', array_keys($agentCoinList));
            
            $playerCoinList = [];
            if ($ids) {
                $playerCoinList = $this->_getPlayerData("a.id IN ({$ids})", $startTime, $endTime);
                $playerCoinList = array_column($playerCoinList, NULL, 'id');
            }

            foreach ($agentCoinList as $row) {
                $row['agent_add_coin'] = Helper::format_money($row['agent_add_coin'] ? $row['agent_add_coin'] : 0);
                $row['agent_sub_coin'] = Helper::format_money($row['agent_sub_coin'] ? $row['agent_sub_coin'] : 0);
                $row['player_add_coin'] = Helper::format_money(isset($playerCoinList[$row['id']]) && $playerCoinList[$row['id']]['player_add_coin'] ? $playerCoinList[$row['id']]['player_add_coin'] : 0);
                $row['player_sub_coin'] = Helper::format_money(isset($playerCoinList[$row['id']]) && $playerCoinList[$row['id']]['player_sub_coin'] ? $playerCoinList[$row['id']]['player_sub_coin'] : 0);
                $row['player_win_coin'] = Helper::format_money(isset($playerCoinList[$row['id']]) && $playerCoinList[$row['id']]['player_win_coin'] ? $playerCoinList[$row['id']]['player_win_coin'] : 0);
                $row['bigbang'] = Helper::format_money(isset($playerCoinList[$row['id']]) && $playerCoinList[$row['id']]['bigbang'] ? $playerCoinList[$row['id']]['bigbang'] : 0);
                $list[] = $row;
            }
        } else {
            $playerCoinList = $this->_getPlayerData("a.parent_id = {$agentId}", $startTime, $endTime, $field, $order, $offset, $limitValue);
            $playerCoinList = array_column($playerCoinList, NULL, 'id');
            $ids = implode(',', array_keys($playerCoinList));

            $agentCoinList = [];
            if ($ids) {
                $agentCoinList = $this->_getAgentData("a.id IN ({$ids})", $startTime, $endTime);
                $agentCoinList = array_column($agentCoinList, NULL, 'id');
            }
            

            foreach ($playerCoinList as $row) {
                $row['player_add_coin'] = Helper::format_money($row['player_add_coin'] ? $row['player_add_coin'] : 0);
                $row['player_sub_coin'] = Helper::format_money($row['player_sub_coin'] ? $row['player_sub_coin'] : 0);
                $row['player_win_coin'] = Helper::format_money($row['player_win_coin'] ? $row['player_win_coin'] : 0);
                $row['bigbang'] = Helper::format_money($row['bigbang'] ? $row['bigbang'] : 0);
                $row['agent_add_coin'] = Helper::format_money(isset($agentCoinList[$row['id']]) && $agentCoinList[$row['id']]['agent_add_coin'] ? $agentCoinList[$row['id']]['agent_add_coin'] : 0);
                $row['agent_sub_coin'] = Helper::format_money(isset($agentCoinList[$row['id']]) && $agentCoinList[$row['id']]['agent_sub_coin'] ? $agentCoinList[$row['id']]['agent_sub_coin'] : 0);
                $row['username'] = isset($agentCoinList[$row['id']]) && $agentCoinList[$row['id']]['username'] ? $agentCoinList[$row['id']]['username'] : '';
                $row['nickname'] = isset($agentCoinList[$row['id']]) && $agentCoinList[$row['id']]['nickname'] ? $agentCoinList[$row['id']]['nickname'] : '';
                $list[] = $row;
            }
        }

        $totalAddCoin = Helper::format_money($agentReload + $playerReload);
        $totalSubCoin = Helper::format_money($agentWithdraw + $playerWithdraw);
        $totalDiffCoin = Helper::format_money($totalAddCoin - $totalSubCoin);
        $result['list'] = $list;
        $result['total_add_coin'] = $totalAddCoin;
        $result['total_sub_coin'] = $totalSubCoin;
        $result['total_diff_coin'] = $totalDiffCoin;
        return $result;
    }

    /**
     * 玩家总上分（所有下级）
     */
    private function _getPlayerReload($agentId, $startTime, $endTime)
    {
        $db = $this->mysql->getDb();
        $db->join(MysqlTables::ACCOUNT_TREE . ' AS t', 'a.id=t.ancestor_id AND t.descendant_agent=0', 'LEFT');
        $joinWhere = 't.descendant_id=s.account_id';
        if ($startTime && $endTime) {
            $joinWhere .= ' AND s.create_time BETWEEN ' . $startTime . ' AND ' . $endTime;
        }
        $joinWhere .= ' AND s.type=1';
        $db->join(MysqlTables::SCORE_LOG . ' AS s', $joinWhere, 'LEFT');
        $db->where('a.parent_id', $agentId);
        $rs = $db->sum(MysqlTables::ACCOUNT . ' AS a', 's.coin');
        return Helper::format_money($rs);
    }

    /**
     * 玩家总下分（所有下级）
     */
    private function _getPlayerWithdraw($agentId, $startTime, $endTime)
    {
        $db = $this->mysql->getDb();
        $db->join(MysqlTables::ACCOUNT_TREE . ' AS t', 'a.id=t.ancestor_id AND t.descendant_agent=0', 'LEFT');
        $joinWhere = 't.descendant_id=s.account_id';
        if ($startTime && $endTime) {
            $joinWhere .= ' AND s.create_time BETWEEN ' . $startTime . ' AND ' . $endTime;
        }
        $joinWhere .= ' AND s.type=2';
        $db->join(MysqlTables::SCORE_LOG . ' AS s', $joinWhere, 'LEFT');
        $db->where('a.parent_id', $agentId);
        $rs = $db->sum(MysqlTables::ACCOUNT . ' AS a', 's.coin');
        return Helper::format_money($rs);
    }

    /**
     * 代理总上分（直属）
     */
    private function _getAgentReload($agentId, $startTime, $endTime)
    {
        $db = $this->mysql->getDb();
        $joinWhere = 'a.id=s.account_id';
        if ($startTime && $endTime) {
            $joinWhere .= ' AND s.create_time BETWEEN ' . $startTime . ' AND ' . $endTime;
        }
        $joinWhere .= ' AND s.type=1';
        $db->join(MysqlTables::SCORE_LOG . ' AS s', $joinWhere, 'LEFT');
        $db->where('a.parent_id', $agentId);
        $db->where('a.agent', 0, '>');
        $rs = $db->sum(MysqlTables::ACCOUNT . ' AS a', 's.coin');
        return Helper::format_money($rs);
    }

    /**
     * 代理总下分（直属）
     */
    private function _getAgentWithdraw($agentId, $startTime, $endTime)
    {
        $db = $this->mysql->getDb();
        $joinWhere = 'a.id=s.account_id';
        if ($startTime && $endTime) {
            $joinWhere .= ' AND s.create_time BETWEEN ' . $startTime . ' AND ' . $endTime;
        }
        $joinWhere .= ' AND s.type=2';
        $db->join(MysqlTables::SCORE_LOG . ' AS s', $joinWhere, 'LEFT');
        $db->where('a.parent_id', $agentId);
        $db->where('a.agent', 0, '>');
        $rs = $db->sum(MysqlTables::ACCOUNT . ' AS a', 's.coin');
        return Helper::format_money($rs);
    }

    /**
     * 玩家总上分 总下分 输赢
     */
    private function _getPlayerData($where, $startTime, $endTime, $field='', $order = '', $offset = '', $limitValue = '')
    {
        $db = $this->mysql->getDb();
        $db->join(MysqlTables::ACCOUNT_TREE . ' AS t', 'a.id=t.ancestor_id AND t.descendant_agent=0', 'LEFT');
        $joinWhere = 't.descendant_id=c.account_id';
        if ($startTime && $endTime) {
            $joinWhere .= ' AND c.create_time BETWEEN ' . $startTime . ' AND ' . $endTime;
        }
        $joinWhere .= ' AND c.type IN (1, 2, 3, 4, 5, 6)';
        $db->join(MysqlTables::COINS_PLAYER . ' AS c', $joinWhere, 'LEFT');
        $db->where($where);
        $db->groupBy('a.id');
        if ($field !== '' && $order !== '') {
            $db->orderBy($field, $order);
        }
        $numRows = null;
        if ($offset !== '' && $limitValue !== '') {
            $numRows = [$offset, $limitValue];
        }
        $fields = 'a.id, SUM(IF(c.type=1, c.coin, 0)) AS player_add_coin, SUM(IF(c.type=2, abs(c.coin), 0)) AS player_sub_coin, -1*SUM(IF(c.type IN (3, 4, 5, 6), c.coin, 0)) AS player_win_coin, SUM(IF(c.type=5, c.coin, 0)) AS bigbang';
        $rs = $db->get(MysqlTables::ACCOUNT . ' AS a', $numRows, $fields);
        return $rs;
    }

    /**
     * 代理总上分 总下分
     */
    public function _getAgentData($where, $startTime, $endTime, $field='', $order = '', $offset = '', $limitValue = '')
    {
        $db = $this->mysql->getDb();
        $joinWhere = 'a.id=s.account_id';
        if ($startTime && $endTime) {
            $joinWhere .= ' AND s.create_time BETWEEN ' . $startTime . ' AND ' . $endTime;
        }
        $db->join(MysqlTables::SCORE_LOG . ' AS s', $joinWhere, 'LEFT');
        $db->where($where);
        $db->where('a.agent', 0, '>');
        $db->groupBy('a.id');
        if ($field !== '' && $order !== '') {
            $db->orderBy($field, $order);
        }
        $numRows = null;
        if ($offset !== '' && $limitValue !== '') {
            $numRows = [$offset, $limitValue];
        }
        $fields = 'a.id, a.username, a.nickname, SUM(IF(s.type=1, s.coin, 0)) AS agent_add_coin, -1*SUM(IF(s.type=2, s.coin, 0)) AS agent_sub_coin';
        $rs = $db->get(MysqlTables::ACCOUNT . ' AS a', $numRows, $fields);
        return $rs;
    }

    // 游戏记录
    public function gameRecord($pid, $page = 0, $limitValue = 10, $startTime = 0, $endTime = 0, $minCoin = 0, $maxCoin = 0, $orderBy = 'create_time desc')
    {
        $result = ['total'=> 0, 'list'=> []];
        // 根据$pid获取用户ID
        $db = $this->mysql->getDb();
        $account = $db->where('pid', $pid)->getOne(MysqlTables::ACCOUNT);
        if (empty($account)) {
            return $result;
        }
        $accountId = $account['id'];
        $offset = ($page = abs(intval($page))) > 0 ? ($page - 1) * $limitValue : 0;
        $fields = 'coin, `before`, `after`, create_time, type, game_id';
        $db->where('account_id', $accountId);
        $startTime && $endTime && $db->where('create_time', [$startTime, $endTime], 'BETWEEN');
        if ($minCoin && $maxCoin && $maxCoin >= $minCoin) {
            $db->where('coin', [$minCoin, $maxCoin], 'BETWEEN');
        }
        $orderBy = $orderBy ? $orderBy : 'create_time desc';
        list($orderByField, $orderByDirection) = explode(' ', $orderBy);
        $db->orderBy($orderByField, $orderByDirection);
        $result['list'] = $db->withTotalCount()->get(MysqlTables::COINS_PLAYER, [$offset, $limitValue], $fields);
        $result['total'] = $db->getTotalCount();
        return $result;
    }

    // 分级查询
    // 各个级别的代理的活跃状况查询
    public function levelSearch($accountId = 0, $startTime = 0, $endTime = 0)
    {
        $result = [];
        $db = $this->mysql->getDb();
        if ($accountId == 0) {
            // 获取总代账号
            $account = $db->where('agent', 2)->where('id', '1001', '<>')->getOne(MysqlTables::ACCOUNT);
        } else {
            $account = $db->where('id', $accountId)->getOne(MysqlTables::ACCOUNT);
        }
        if (empty($account)) {
            return $result;
        }

        // 获取当前代理数据
        $curData['id'] = $account['id'];
        $curData['username'] = $account['username'];
        $curData['nickname'] = $account['nickname'];
        $curData['coin'] = $account['coin'];
        $curData['parent'] = $account['agent'] == 2 ? 0 : $account['parent_id'];
        $curData['au'] = 0;
        $curData['bets'] = 0;
        $curData['win'] = 0;

        $fields = 'COUNT(DISTINCT(IF(c.type=3, account_id, \'NULL\'))) AS au, SUM(IF(c.type=3, abs(coin), 0)) AS bets, -1*SUM(coin) AS win';
        $joinWhere = 't.descendant_id=c.account_id';
        if ($startTime && $endTime) {
            $joinWhere .= ' AND c.create_time BETWEEN ' . $startTime . ' AND ' . $endTime;
        }
        $joinWhere .= ' AND c.type IN (3, 4, 5, 6)';
        $db->join(MysqlTables::COINS_PLAYER . ' AS c', $joinWhere, 'LEFT');
        $db->where('t.ancestor_id', $account['id']);
        $db->where('t.descendant_agent', 0);
        $data = $db->getOne(MysqlTables::ACCOUNT_TREE . ' AS t', $fields);
        if (empty($data)) {
            return $curData;
        }
        $curData['au'] = isset($data['au']) ? ($data['au'] - 1) : 0;
        $curData['bets'] = Helper::format_money(isset($data['bets']) ? $data['bets'] : 0);
        $curData['win'] = Helper::format_money(isset($data['win']) ? $data['win'] : 0);
        return $curData;
    }

    public function levelSearchDetail($accountId = 0, $page = 0, $limitValue = 10, $startTime = 0, $endTime = 0, $orderBy = 'username desc')
    {
        $result = ['list' => [], 'total' => 0];
        $offset = ($page = abs(intval($page))) > 0 ? ($page - 1) * $limitValue : 0;
        $db = $this->mysql->getDb();
        if ($accountId == 0) {
            // 获取总代账号
            $account = $db->where('agent', 2)->where('id', '1001', '<>')->getOne(MysqlTables::ACCOUNT);
        } else {
            $account = $db->where('id', $accountId)->getOne(MysqlTables::ACCOUNT);
        }
        if (empty($account)) {
            return $result;
        }

        $curData = [];
        if ($page == 1 && $account['agent'] == 1) {
            $limitValue -= 1;
            // 获取当前代理数据
            $curData['id'] = $account['id'];
            $curData['username'] = $account['username'];
            $curData['nickname'] = $account['nickname'];
            $curData['coin'] = $account['coin'];
            $curData['parent'] = $account['agent'] == 2 ? 0 : $account['parent_id'];
            $curData['au'] = 0;
            $curData['total_coin'] = 0;
            $curData['win'] = 0;

            $fields = 'COUNT(DISTINCT(IF(c.type=3, account_id, \'NULL\'))) AS au, SUM(IF(c.type=3, abs(c.coin), 0)) AS bets, -1*SUM(c.coin) AS win';
            $joinWhere = 'a.id=c.account_id';
            if ($startTime && $endTime) {
                $joinWhere .= ' AND c.create_time BETWEEN ' . $startTime . ' AND ' . $endTime;
            }
            $joinWhere .= ' AND c.type IN (3, 4, 5, 6)';
            $db->join(MysqlTables::COINS_PLAYER . ' AS c', $joinWhere, 'LEFT');
            $db->where('a.parent_id', $account['id']);
            $db->where('a.agent', 0);
            $data = $db->getOne(MysqlTables::ACCOUNT . ' AS a', $fields);
            if ($data) {
                $curData['au'] = isset($data['au']) ? ($data['au'] - 1 ) : 0;
                $curData['bets'] = Helper::format_money(isset($data['bets']) ? $data['bets'] : 0);
                $curData['win'] = Helper::format_money(isset($data['win']) ? $data['win'] : 0);
            }
        } else {
            if ($account['agent'] == 1) {
                $offset -= 1;
            }
        }

        $fields = "a.id, a.username, a.parent_id, a.nickname, a.coin, COUNT(DISTINCT(IF(c.type=3, c.account_id, 'NULL'))) AS au, SUM(IF(c.type=3, abs(c.coin), 0)) AS bets, -1*SUM(c.coin) AS win";
        $db->join(MysqlTables::ACCOUNT_TREE . ' as t', 'a.id=t.ancestor_id and t.descendant_agent=0', 'LEFT');
        $joinWhere = 't.descendant_id=c.account_id';
        if ($startTime && $endTime) {
            $joinWhere .= ' AND c.create_time BETWEEN ' . $startTime . ' AND ' . $endTime;
        }
        $joinWhere .= ' AND c.type IN (3, 4, 5, 6)';
        $db->join(MysqlTables::COINS_PLAYER . ' AS c', $joinWhere, 'LEFT');
        $db->where('a.parent_id', $account['id']);
        $db->where('a.agent', 0, '>');
        $db->groupBy('a.id');
        $orderBy = $orderBy ? $orderBy : 'username desc';
        list($orderByField, $orderByDirection) = explode(' ', $orderBy);
        $db->orderBy($orderByField, $orderByDirection);
        $list = $db->withTotalCount()->get(MysqlTables::ACCOUNT . ' AS a', [$offset, $limitValue], $fields);
        foreach ($list as &$one) {
            $one['au'] = $one['au'] ? ($one['au'] - 1) : 0;
            $one['bets'] = Helper::format_money($one['bets'] ? $one['bets'] : 0);
            $one['win'] = Helper::format_money($one['win'] ? $one['win'] : 0);
        }
        $curData && $list = array_merge([$curData], $list);
        $result['list'] = $list;
        $result['total'] = $db->getTotalCount();
        return $result;
    }

    /**
     * 获取BigBang累计开奖
     * @return array
     */
    public function getBigBangAcc()
    {
        $result = array();
        // 今天累计开奖
        $startTime = strtotime(date('Y-m-d'));
        $endTime = time();
        $result['today'] = $this->getBigBangByTime($startTime, $endTime);
        // 最近七天累计开奖
        $startTime = $endTime - 86400*7;
        $result['seven_day'] = $this->getBigBangByTime($startTime, $endTime);
        // 最近3个月累计开奖
        $startTime = $endTime - 86400*90;
        $result['three_month'] = $this->getBigBangByTime($startTime, $endTime);
        return $result;
    }

    /**
     * 获取Bigbang某段时间累计开奖
     * @param $startTime
     * @param $endTime
     * @return string
     */
    protected function getBigBangByTime($startTime, $endTime)
    {
        $db = $this->mysql->getDb();
        if ($startTime && $endTime) {
            $db->where('create_time', [$startTime, $endTime], 'BETWEEN');
        }
        $db->where('status', 1);
        $data = $db->sum(MysqlTables::COINS_BIGBANG, 'coin');
        return Helper::format_money($data ? $data : 0);
    }

    /**
     * 游戏配置主面板抽水和上下分数据
     */
    public function historyCoin()
    {
        $result = [
            'sys_tax' => '0.0000',
            'reload' => '0.0000',
            'withdraw' => '0.0000',
            'total_diff' => '0.0000',
            'total_win' => '0.0000'
        ];
        // 历史抽水
        $result['sys_tax'] = $this->getTotalPoolTax();
        $totalScore = $this->getAllPlayerTotalScore();
        // 历史上分
        $result['reload'] = $totalScore['reload'];
        // 历史下分
        $result['withdraw'] = $totalScore['withdraw'];
        $result['total_win'] = $this->getTotalWin();
        // 总上下分差
        $result['total_diff'] = Helper::format_money($result['reload'] - $result['withdraw']);
        return $result;
    }

    /**
     * 游戏配置主面板实时数据
     */
    public function curPondData()
    {
        $redis = $this->redis->getDb();
        $db = $this->mysql->getDb();

        // 获取当前系统设置
        $this->table_name = 'system_setting';
        $systemSetting = $db->where('skey', ['pool_tax_limitup', 'pool_jp_outline'], 'in')->get(MysqlTables::SYS_SETTING, null, 'skey, sval');
        $result = array_column($systemSetting, 'sval', 'skey');

        // 当前抽水
        $__BALANCE_TAX_LAST = $redis->get(RedisKey::SYSTEM_BALANCE_TAX_LAST);
        $__BALANCE_TAX_NOW = $redis->get(RedisKey::SYSTEM_BALANCE_TAX_NOW);
        $result['cur_tax'] = Helper::format_money($__BALANCE_TAX_LAST ? $__BALANCE_TAX_LAST : $__BALANCE_TAX_NOW);

        // 距离下一次重置
        $reset_time = $redis->ttl(RedisKey::SYSTEM_BALANCE_TAX_CLOSE);
        $result['reset_time'] = $reset_time;

        // 当前普通池水位
        $result['normal'] = Helper::format_money($redis->get(RedisKey::SYSTEM_BALANCE_POOLNORMAL));

        // 当前jp奖池水位
        $result['jackpot'] = Helper::format_money($redis->get(RedisKey::SYSTEM_BALANCE_POOLJP));

        // 累计已发放分数
        $redbag = $db->sum(MysqlTables::REDBAG, 'coin');
        $result['redbag'] = Helper::format_money($redbag ? abs($redbag) : 0);
        return $result;
    }

    /**
     * 代理列表
     * @param $keywords
     * @param $page
     * @param $limitValue
     * @param $startTime
     * @param $endTime
     * @param string $orderBy
     * @return array
     */
    public function getAgentList($keywords, $page, $limitValue, $startTime, $endTime, $orderBy = 'id desc')
    {
        $result = ['total'=> 0, 'list'=> []];
        $offset = ($page = abs(intval($page))) > 0 ? ($page - 1) * $limitValue : 0;
        $db = $this->mysql->getDb();
        $db->where('agent', [1, 2], 'in');
        $keywords && $db->where("(username like '%{$keywords}%' OR nickname like '%{$keywords}%')");
        $startTime && $endTime && $db->where('create_time', [$startTime, $endTime], 'BETWEEN');
        $fields = 'id,parent_id,parent_agent_first_id,username,nickname,coin,create_time,login_time';
        $orderBy = $orderBy ? $orderBy : 'id desc';
        list($orderByField, $orderByDirection) = explode(' ', $orderBy);
        $db->orderBy($orderByField, $orderByDirection);
        $list = $db->withTotalCount()->get(MysqlTables::ACCOUNT, [$offset, $limitValue], $fields);
        $result['total'] = $db->getTotalCount();
        if ($list) {
            $uids = array_unique(array_merge(array_column($list, 'parent_id'), array_column($list, 'parent_agent_first_id')));
            $accounts = $db->where('id', $uids, 'in')->get(MysqlTables::ACCOUNT, null, 'id, username, nickname');
            $accounts = array_column($accounts, null, 'id');
            foreach ($list as &$one) {
                $one['parent_agent'] = isset($accounts[$one['parent_id']]) ? $accounts[$one['parent_id']]['username'] : 'None';
                $one['first_agent'] = isset($accounts[$one['parent_agent_first_id']]) ? $accounts[$one['parent_agent_first_id']]['username'] : 'None';
                $one['create_time'] = $one['create_time'] ? date('Y-m-d H:i:s', $one['create_time']) : '0';
                $one['login_time'] = $one['login_time'] ? date('Y-m-d H:i:s', $one['login_time']) : '0';
            }
            $result['list'] = $list;
        }
        return $result;
    }

    public function getAgentScoreLog($keywords, $page, $limitValue, $startTime, $endTime, $orderBy = 'create_time desc')
    {
        $result = ['total'=> 0, 'list'=> []];
        $account = [];
        $db = $this->mysql->getDb();
        if ($keywords) {
            $db->where('agent', [1, 2], 'in')->where("(username='{$keywords}' OR nickname='{$keywords}')");
            $account = $db->getOne(MysqlTables::ACCOUNT, 'id');
            if (empty($account)) {
                return $result;
            }
        }
        $offset = ($page = abs(intval($page))) > 0 ? ($page - 1) * $limitValue : 0;
        $account && $db->where('account_id', $account['id']);
        if ($startTime && $endTime) {
            $db->where('create_time', [$startTime, $endTime], 'BETWEEN');
        }
        $db->where('agent', 0, '>');
        $orderBy = $orderBy ? $orderBy : 'create_time desc';
        list($orderByField, $orderByDirection) = explode(' ', $orderBy);
        $db->orderBy($orderByField, $orderByDirection);
        $fields = 'account_id, `before`, `after`, coin, create_time';
        $list = $db->withTotalCount()->get(MysqlTables::SCORE_LOG, [$offset, $limitValue], $fields);
        $result['total'] = $db->getTotalCount();
        if ($list) {
            $uids = array_unique(array_column($list, 'account_id'));
            $accounts = $db->where('id', $uids, 'in')->get(MysqlTables::ACCOUNT, null, 'id, username, nickname');
            $accounts = array_column($accounts, null, 'id');
            foreach ($list as &$one) {
                $one['username'] = isset($accounts[$one['account_id']]) ? $accounts[$one['account_id']]['username'] : '';
                $one['nickname'] = isset($accounts[$one['account_id']]) ? $accounts[$one['account_id']]['nickname'] : '';
                $one['create_time'] = $one['create_time'] ? date('Y-m-d H:i:s', $one['create_time']) : 0;
            }
            $result['list'] = $list;
        }
        return $result;
    }

    /**
     * 更新报表
     * 日
     * 系统赢钱
     * @return boolean
     */
    public function _doStatDailySyswin()
    {
        if (!! ($_date = date("Y-m-d", time()-60))) {
            $_newd['date'] = $_date;
            $db = $this->mysql->getDb();
            $_q = $db->rawQuery("SELECT SUM(IF(type=1,coin,0)) as outcoin,-1*SUM(IF(type=2,coin,0)) as incoin FROM " . MysqlTables::SCORE_LOG . " WHERE agent=2");
            $_d_s = $_q[0];

            $_newd['sysout'] = Helper::format_money(isset($_d_s['outcoin']) ? $_d_s['outcoin'] : 0);
            $_newd['sysin'] = Helper::format_money(isset($_d_s['incoin']) ? $_d_s['incoin'] : 0);

            $_q = $db->rawQuery("SELECT SUM(IF(agent=0,coin,0)) as playercoin,SUM(IF(agent=1 OR agent=2,coin,0)) as agentcoin FROM " . MysqlTables::ACCOUNT . " WHERE agent IN (0,1,2)");
            $_d_s1 = $_q[0];

            $_newd['player'] = Helper::format_money(isset($_d_s1['playercoin']) ? $_d_s1['playercoin'] : 0);
            $_newd['agent'] = Helper::format_money(isset($_d_s1['agentcoin']) ? $_d_s1['agentcoin'] : 0);

            $_newd['syswin'] = $_newd['sysout'] - $_newd['sysin'] - $_newd['player'] - $_newd['agent'];

            $db->insert(MysqlTables::STAT_SYSWIN, $_newd);

            return TRUE;
        }
        else
        {
            $this->setErrMsg('系统错误');
            return FALSE;
        }
    }

    /**
     * 更新报表
     * 30分钟
     * 玩家金币总额
     * @return boolean
     */
    public function _doStat30minCoinPlayer()
    {
        if(!! ($_date = date("Y-m-d H:i:00")))
        {
            $_newd['datetime'] = $_date;

            $db = $this->mysql->getDb();

            $_q = $db->rawQuery("SELECT SUM(coin) as playercoin FROM " . MysqlTables::ACCOUNT . " WHERE agent=0");
            $_d_s1 = $_q[0];

            $_newd['coin'] = Helper::format_money(isset($_d_s1['playercoin']) ? $_d_s1['playercoin'] : 0);

            $db->insert(MysqlTables::STAT_COIN_PLAYER, $_newd);

            return TRUE;
        }
        else
        {
            $this->setErrMsg('系统错误');
            return FALSE;
        }
    }

    /**
     * 更新报表
     * 30分钟
     * 在线玩家数
     * @return boolean
     */
    public function _doStat30minOnlinePlayer()
    {
        if(!! ($_date = date("Y-m-d H:i:00")))
        {
            $_num = $this->models->curl_model->getStatServerOnlineTotal();

            $_newd['datetime'] = $_date;
            $_newd['count'] = $_num;

            $this->mysql->getDb()->insert(MysqlTables::STAT_ONLINE_PLAYER, $_newd);
            return TRUE;
        }
        else
        {
            $this->setErrMsg('系统错误');
            return FALSE;
        }
    }

    /**
     * 更新报表
     * 5分钟
     * 在线玩家数
     * @return boolean
     */
    public function _doStat5minGameOnlinePlayer()
    {
        if(!! ($_date = date("Y-m-d H:i:00")))
        {
            $_r = $this->models->curl_model->getStatServerGameOnline('-1');

            $_ds = array();

            if(is_array($_r) && $_r && count($_r) > 0)
            {
                foreach ($_r as $_g)
                {
                    $_ds[(int)$_g['gameid']] = (int)$_g['onlinenum'];
                }

                $_newd['datetime'] = $_date;
                $_newd['counts'] = json_encode($_ds);
                $this->mysql->getDb()->insert(MysqlTables::STAT_ONLINE_GAME, $_newd);
            }

            return TRUE;
        }
        else
        {
            $this->setErrMsg('系统错误');
            return FALSE;
        }
    }

    /**
     * 更新报表
     * 5分钟
     * 彩池库存
     * @return boolean
     */
    public function _doStat5minPoolNormal()
    {
        $redis = $this->redis->getDb();
        if (!! ($date = date("Y-m-d H:i:00"))) {
            $data['datetime'] = $date;
            $data['coin'] = $redis->get(RedisKey::SYSTEM_BALANCE_POOLNORMAL);
            $this->mysql->getDb()->insert(MysqlTables::STAT_POOL_NORMAL, $data);
            return TRUE;
        } else {
            return FALSE;
        }
    }

    /**
     * 更新报表
     * 5分钟
     * JP池库存
     * @return boolean
     */
    public function _doStat5minPoolJp()
    {
        if(!! ($_date = date("Y-m-d H:i:00")))
        {
            $redis = $this->redis->getDb();
            $_system_setting = $this->models->system_model->_getRedisSystemParameters(array('pool_jp_outline'));

            $_newd['datetime'] = $_date;
            $_newd['coin'] = $redis->get(RedisKey::SYSTEM_BALANCE_POOLJP);
            $_newd['outline'] = isset($_system_setting['pool_jp_outline']) ? $_system_setting['pool_jp_outline'] : "0.00";

            $this->mysql->getDb()->insert(MysqlTables::STAT_POOL_JP, $_newd);

            return TRUE;
        }
        else
        {
            $this->setErrMsg('系统错误');
            return FALSE;
        }
    }

    /**
     * 更新报表
     * 5分钟
     * TAX池库存
     * @return boolean
     */
    public function _doStat5minPoolTax()
    {
        $redis = $this->redis->getDb();
        if(!! ($_date = date("Y-m-d H:i:00"))) {
            $_system_setting = $this->models->system_model->_getRedisSystemParameters(array('pool_tax_limitup'));

            $_newd['datetime'] = $_date;
            $_newd['coin'] = ($__TAX_LAST = $redis->get(RedisKey::SYSTEM_BALANCE_TAX_LAST)) !== FALSE ? $__TAX_LAST : $redis->get(RedisKey::SYSTEM_BALANCE_TAX_NOW);
            $_newd['limitup'] = isset($_system_setting['pool_tax_limitup']) ? $_system_setting['pool_tax_limitup'] : "0.00";

            $this->mysql->getDb()->insert(MysqlTables::STAT_POOL_TAX, $_newd);

            return TRUE;
        }
        else
        {
            $this->setErrMsg('系统错误');
            return FALSE;
        }
    }

    /**
     * 获取系统报表
     * 系统管理员专用报表
     * 大玩家
     * @param int $time
     * @param int $time2
     * @return mixed
     */
    public function getStatSysExclusiveSuperPlayer($time = 0, $time2 = 0)
    {
        $db = $this->mysql->getDb();
        $joinWhere = 'a.id=c.account_id';
        if ($time && $time2) {
            $joinWhere .= ' AND c.create_time BETWEEN ' . $time . ' AND ' . $time2;
        }
        $joinWhere .= ' AND type IN (3, 4, 5, 6)';
        $db->join(MysqlTables::COINS_PLAYER . ' AS c', $joinWhere, 'LEFT');
        $fields = 'a.nickname, a.coin, a.login_time, a.pid, -1*SUM(IF(c.type=3, c.coin, 0)) AS userbet, -1*SUM(c.coin) AS userwin';
        $db->where('a.agent', 0);
        $db->groupBy('a.id');
        $db->orderBy('userbet', 'DESC');
        $rs = $db->get(MysqlTables::ACCOUNT . ' AS a', null, $fields);
        return $rs;
    }

    /**
     * 获取系统报表
     * 系统管理员专用报表
     * 大赢家
     * @param int $time
     * @param int $time2
     * @return mixed
     */
    public function getStatSysExclusiveSuperWiner($time = 0, $time2 = 0)
    {
        $db = $this->mysql->getDb();
        $joinWhere = 'a.id=c.account_id';
        if ($time && $time2) {
            $joinWhere .= ' AND c.create_time BETWEEN ' . $time . ' AND ' . $time2;
        }
        $joinWhere .= ' AND type IN (3, 4, 5, 6)';
        $db->join(MysqlTables::COINS_PLAYER . ' AS c', $joinWhere, 'LEFT');
        $fields = 'a.nickname, a.coin, a.login_time, a.pid, -1*SUM(IF(c.type=3, c.coin, 0)) AS userbet, -1*SUM(c.coin) AS userwin';
        $db->where('a.agent', 0);
        $db->groupBy('a.id');
        $db->orderBy('userwin', 'DESC');
        $rs = $db->get(MysqlTables::ACCOUNT . ' AS a', null, $fields);
        return $rs;
    }

    /**
     * 获取系统报表
     * 日
     * 系统赢钱
     * @param string $data
     * @param string $data2
     * @param int $page
     * @return array
     */
    public function getStatDailySyswin($data = '', $data2 = '', $page = 0)
    {
        $limitValue = 20;
        $offset = ($page = abs(intval($page))) > 0 ? ($page - 1) * $limitValue : 0;

        $result = ['total'=> 0, 'list'=> []];
        $db = $this->mysql->getDb();
        if($data && $data2 && $data2 > $data) {
            $db->where('date', [$data, $data2], 'BETWEEN');
        } elseif ($data) {
            $db->where('date', $data);
        }
        $db->orderBy('id', 'desc');
        $result['list'] = $db->withTotalCount()->get(MysqlTables::STAT_SYSWIN, [$offset, $limitValue]);
        $result['total'] = $db->getTotalCount();
        return $result;
    }

    /**
     * 获取抽水
     * @param int $startTime
     * @param int $endTime
     * @return string
     */
    public function getCommission($startTime = 0, $endTime = 0)
    {
        return $this->getTotalPoolTax($startTime, $endTime);
    }

    /**
     * 获取系统报表
     * 30分钟
     * 玩家在线数
     * @param int $time
     * @param int $time2
     * @param int $page
     * @return \App\Utility\Pool\MysqlObject|mixed
     */
    public function getStat30minOnlinePlayer($time = 0, $time2 = 0, $page = 1)
    {
        $db = $this->mysql->getDb();
        $time && $time2 && $db->where('datetime', [date("Y-m-d H:i:00", $time), date("Y-m-d H:i:00", $time2)], 'BETWEEN');
        $db->orderBy('id', 'asc');
        $list = $db->get(MysqlTables::STAT_ONLINE_PLAYER, null);
        foreach ($list as &$one) {
            $one['timestamp'] = strtotime($one['datetime']);
        }
        return $list;
    }

    /**
     * 获取系统报表
     * 30分钟
     * 玩家余额存量
     * @param int $time
     * @param int $time2
     * @return \App\Utility\Pool\MysqlObject|mixed
     */
    public function getStat30minCoinPlayer($time = 0, $time2 = 0)
    {
        $db = $this->mysql->getDb();
        $time && $time2 && $db->where('datetime', [date("Y-m-d H:i:00", $time), date("Y-m-d H:i:00", $time2)], 'BETWEEN');
        $db->orderBy('id', 'asc');
        $list = $db->get(MysqlTables::STAT_COIN_PLAYER, null);
        foreach ($list as &$one) {
            $one['timestamp'] = strtotime($one['datetime']);
        }
        return $list;
    }

    /**
     * 获取系统报表
     * 5分钟
     * 普通池（彩池）存量
     * @param int $time
     * @param int $time2
     * @return \App\Utility\Pool\MysqlObject|mixed
     */
    public function getStat5minPoolNormal($time = 0, $time2 = 0)
    {
        $db = $this->mysql->getDb();
        $time && $time2 && $db->where('datetime', [date("Y-m-d H:i:00", $time), date("Y-m-d H:i:00", $time2)], 'BETWEEN');
        $db->orderBy('id', 'asc');
        $list = $db->get(MysqlTables::STAT_POOL_NORMAL, null);
        foreach ($list as &$one) {
            $one['timestamp'] = strtotime($one['datetime']);
        }
        return $list;
    }

    /**
     * 获取系统报表
     * 5分钟
     * JP池存量
     * @param int $time
     * @param int $time2
     * @return \App\Utility\Pool\MysqlObject|mixed
     */
    public function getStat5minPoolJp($time = 0, $time2 = 0)
    {
        $db = $this->mysql->getDb();
        $time && $time2 && $db->where('datetime', [date("Y-m-d H:i:00", $time), date("Y-m-d H:i:00", $time2)], 'BETWEEN');
        $db->orderBy('id', 'asc');
        $list = $db->get(MysqlTables::STAT_POOL_JP, null);
        foreach ($list as &$one) {
            $one['timestamp'] = strtotime($one['datetime']);
        }
        return $list;
    }

    /**
     * 获取系统报表
     * 5分钟
     * Tax池存量
     * @param int $time
     * @param int $time2
     * @return \App\Utility\Pool\MysqlObject|mixed
     */
    public function getStat5minPoolTax($time = 0, $time2 = 0)
    {
        $db = $this->mysql->getDb();
        $time && $time2 && $db->where('datetime', [date("Y-m-d H:i:00", $time), date("Y-m-d H:i:00", $time2)], 'BETWEEN');
        $db->orderBy('id', 'asc');
        $list = $db->get(MysqlTables::STAT_POOL_TAX, null);
        foreach ($list as &$one) {
            $one['timestamp'] = strtotime($one['datetime']);
        }
        return $list;
    }

    /**
     * 获取系统报表
     * 5分钟
     * Tax池存量
     * @param int $time
     * @param int $time2
     * @return \App\Utility\Pool\MysqlObject|mixed
     */
    public function getStat5minGameOnlinePlayer($time = 0, $time2 = 0)
    {
        $db = $this->mysql->getDb();
        $time && $time2 && $db->where('datetime', [date("Y-m-d H:i:00", $time), date("Y-m-d H:i:00", $time2)], 'BETWEEN');
        $db->orderBy('id', 'asc');
        $list = $db->get(MysqlTables::STAT_ONLINE_GAME, null);
        foreach ($list as &$one) {
            $one['timestamp'] = strtotime($one['datetime']);
        }
        return $list;
    }

    public function statDailyCount()
    {
        $db = $this->mysql->getDb();
        $redis = $this->redis->getDb();
        // 获取玩家身上总分
        //$playerCoin = $db->where('agent', 0)->sum(MysqlTables::ACCOUNT, 'coin');
        // 获取水池额度
        $last = $redis->get(RedisKey::SYSTEM_BALANCE_TAX_LAST);
        $tax = $last ? $last : $redis->get(RedisKey::SYSTEM_BALANCE_TAX_NOW);
        // 获取彩池额度
        $normal = $redis->get(RedisKey::SYSTEM_BALANCE_POOLNORMAL);
        // 获取JP池额度
        $jackpot = $redis->get(RedisKey::SYSTEM_BALANCE_POOLJP);

        $data = [
            'datetime' => time(),//strtotime(date('Y-m-d', strtotime('-1 day'))),
            'player_coin' => 0,//Helper::format_money($playerCoin),
            'tax' => Helper::format_money($tax),
            'normal' => Helper::format_money($normal),
            'jackpot' => Helper::format_money($jackpot)
        ];
        return $db->insert(MysqlTables::STAT_COUNT, $data);
    }

    /**
     * 对账
     */
    public function checkAccount()
    {
        $db = $this->mysql->getDb();
        // $today = strtotime(date('Y-m-d', strtotime('-1 day')));
        // $todayEnd = $today + 86399;
        // $yesterday = $today - 86400;
        // 获取最近两条统计数据
        $data = $db->orderBy('datetime', 'desc')->get(MysqlTables::STAT_COUNT, [1, 2]);
        if (count($data) < 2) {
            return false;
        }
        $startTime = $data[1]['datetime'];
        $endTime = $data[0]['datetime'] - 1;
        $todayData = $data[0];//$db->where('datetime', $today)->getOne(MysqlTables::STAT_COUNT);
        $yesterdayData = $data[1];//$db->where('datetime', $yesterday)->getOne(MysqlTables::STAT_COUNT);
        if (empty($todayData) || empty($yesterdayData)) {
            return false;
        }

        $yesterdayTax = intval(10000*$yesterdayData['tax']);
        $yesterdayJackpot = intval(10000*$yesterdayData['jackpot']);
        $yesterdayNormal = intval(10000*$yesterdayData['normal']);
        $todayTax = intval(10000*$todayData['tax']);
        $todayJackpot = intval(10000*$todayData['jackpot']);
        $todayNormal = intval(10000*$todayData['normal']);

        // 获取该时间段内，玩家的分数变动额
        // 玩家进分
        $addCoin = intval(10000*$db->where('create_time', [$startTime, $endTime], 'BETWEEN')->where('coin', 0, '>')->sum(MysqlTables::COINS_PLAYER, 'coin'));
        // 玩家出分
        $subCoin = intval(10000*abs($db->where('create_time', [$startTime, $endTime], 'BETWEEN')->where('coin', 0, '<')->sum(MysqlTables::COINS_PLAYER, 'coin')));

        // 今日玩家总上分
        $reload = intval(10000*$db->where('create_time', [$startTime, $endTime], 'BETWEEN')->where('type', 1)->where('agent', 0)->sum(MysqlTables::SCORE_LOG, 'coin'));

        // 今日玩家总下分
        $withdraw = intval(10000*abs($db->where('create_time', [$startTime, $endTime], 'BETWEEN')->where('type', 2)->where('agent', 0)->sum(MysqlTables::SCORE_LOG, 'coin')));

        // Bigbang开奖
        $bigbang = intval(10000*$db->where('create_time', [$startTime, $endTime], 'BETWEEN')->where('type', 5)->sum(MysqlTables::COINS_PLAYER, 'coin'));

        // 今日总押注金额
        $bets = intval(10000*abs($db->where('create_time', [$startTime, $endTime], 'BETWEEN')->where('type', 3)->sum(MysqlTables::COINS_PLAYER, 'coin')));

        // 今日中奖总金币（赢钱，Bigbang，救济红包）
        $win = intval(10000*$db->where('create_time', [$startTime, $endTime], 'BETWEEN')->where('type', [4, 5, 6], 'IN')->sum(MysqlTables::COINS_PLAYER, 'coin'));

        // 今日税池新增
        $tax = intval(10000*$db->where('create_time', [$startTime, $endTime], 'BETWEEN')->where('type', 1)->sum(MysqlTables::POOL_TAX, 'coin'));

        // 今日彩池新增
        $normal = intval(10000*$db->where('create_time', [$startTime, $endTime], 'BETWEEN')->where('type', 1)->sum(MysqlTables::POOL_NORMAL, 'coin'));

        // 今日彩池出奖
        $winNormal = intval(10000*abs($db->where('create_time', [$startTime, $endTime], 'BETWEEN')->where('type', [2, 3], 'IN')->sum(MysqlTables::POOL_NORMAL, 'coin')));

        // 今日JP池新增
        $jackpot = intval(10000*$db->where('create_time', [$startTime, $endTime], 'BETWEEN')->where('type', 1)->sum(MysqlTables::POOL_JP, 'coin'));

        // 今日JP池开奖
        $winJackpot = intval(10000*abs($db->where('create_time', [$startTime, $endTime], 'BETWEEN')->where('type', 2)->sum(MysqlTables::POOL_JP, 'coin')));

        // 水池今日抹掉记录总和
        $taxErase = intval(10000*abs($db->where('create_time', [$startTime, $endTime], 'BETWEEN')->where('type', [2, 3], 'IN')->sum(MysqlTables::POOL_TAX, 'coin')));

        // 彩池今日抹掉记录总和
        $normalErase = intval(10000*abs($db->where('create_time', [$startTime, $endTime], 'BETWEEN')->where('type', 6)->sum(MysqlTables::POOL_NORMAL, 'coin')));

        // JP池今日抹掉记录总和
        $jackpotErase = intval(10000*abs($db->where('create_time', [$startTime, $endTime], 'BETWEEN')->where('type', 3)->sum(MysqlTables::POOL_JP, 'coin')));

        // 今日BigBang出奖总额
        $bigbangTotal = intval(10000*$db->where('create_time', [$startTime, $endTime], 'BETWEEN')->where('status', 1)->sum(MysqlTables::COINS_BIGBANG, 'coin'));

        // 今日彩池借款总额
        $totalBorrow = intval(10000*abs($db->where('create_time', [$startTime, $endTime], 'BETWEEN')->where('type', 4)->sum(MysqlTables::POOL_NORMAL, 'coin')));

        // 今日彩池还款总额
        $totalRefund = intval(10000*$db->where('create_time', [$startTime, $endTime], 'BETWEEN')->where('type', 5)->sum(MysqlTables::POOL_NORMAL, 'coin'));

        // 总账
        // 昨日总盘
        $yesterdayTotal = $yesterdayTax + $yesterdayNormal + $yesterdayJackpot;
        // 今日新增
        $todayAdd = $bets - $win;
        // 今日总盘
        $todayTotal = $todayTax + $todayNormal + $todayJackpot;
        $sub = $todayTotal - $todayAdd - $yesterdayTotal;
        if ($sub != 0) {
            $db->insert(MysqlTables::STAT_ALARM, ['datetime' => $todayData['datetime'], 'desc' => "总账对账失败（{$sub}）"]);
        }

        // 总押注入账
        $sub = $bets - ($tax + $normal + $jackpot);
        if ($sub != 0) {
            $db->insert(MysqlTables::STAT_ALARM, ['datetime' => $todayData['datetime'], 'desc' => "总押注入账对账失败（{$sub}）"]);
        }

        // 总押注出账
        $sub = $addCoin - $subCoin - ($win - $bets + $reload - $withdraw);
        if ($sub != 0) {
            $db->insert(MysqlTables::STAT_ALARM, ['datetime' => $todayData['datetime'], 'desc' => "总押注出账对账失败（{$sub}）"]);
        }

        // 水池
        $sub = $todayTax - ($yesterdayTax + $tax - $taxErase);
        if ($sub != 0) {
            $db->insert(MysqlTables::STAT_ALARM, ['datetime' => $todayData['datetime'], 'desc' => "水池对账失败（{$sub}）"]);
        }

        // JP奖池
        $sub = $todayJackpot - ($yesterdayJackpot + $jackpot - $winJackpot - $jackpotErase);
        if ($sub != 0) {
            $db->insert(MysqlTables::STAT_ALARM, ['datetime' => $todayData['datetime'], 'desc' => "JP奖池对账失败（{$sub}）"]);
        }
        // 彩池
        $sub = $todayNormal - ($yesterdayNormal + $normal - $winNormal - $normalErase + $totalRefund - $totalBorrow);
        if ($sub != 0) {
            $db->insert(MysqlTables::STAT_ALARM, ['datetime' => $todayData['datetime'], 'desc' => "彩池对账失败（{$sub}）"]);
        }

        // Bigbang
        $sub = $bigbang - $bigbangTotal;
        if ($sub != 0) {
            $db->insert(MysqlTables::STAT_ALARM, ['datetime' => $todayData['datetime'], 'desc' => "Bigbang对账失败（{$sub}）"]);
        }
    }

    /**
     * 总代报表明细
     */
    public function generalAgentReportDetail($page, $limitValue, $accountId, $startDate, $endDate)
    {
        $offset = ($page = abs(intval($page))) > 0 ? ($page - 1) * $limitValue : 0;
        $db = $this->mysql->getDb();
        $total = $db->where('date', [$startDate, $endDate], 'BETWEEN')->count(MysqlTables::ASSIST_DATELIST);
        $agentData = $this->_getGeneralAgentAgentDataByDate($accountId, $startDate, $endDate, $offset, $limitValue);
        $playerData = $this->_getGeneralAgentPlayerDataByDate($accountId, $startDate, $endDate, $offset, $limitValue);
        $playerData = array_column($playerData, null, 'datetime');
        $list = [];
        foreach ($agentData as $row) {
            $row['agent_add_coin'] = Helper::format_money($row['agent_add_coin'] ? $row['agent_add_coin'] : 0);
            $row['agent_sub_coin'] = Helper::format_money($row['agent_sub_coin'] ? $row['agent_sub_coin'] : 0);
            $row['player_add_coin'] = Helper::format_money(isset($playerData[$row['date']]) && $playerData[$row['date']]['player_add_coin'] ? $playerData[$row['date']]['player_add_coin'] : 0);
            $row['player_sub_coin'] = Helper::format_money(isset($playerData[$row['date']]) && $playerData[$row['date']]['player_sub_coin'] ? $playerData[$row['date']]['player_sub_coin'] : 0);
            $row['player_win_coin'] = Helper::format_money(isset($playerData[$row['date']]) && $playerData[$row['date']]['player_win_coin'] ? $playerData[$row['date']]['player_win_coin'] : 0);
            $row['bigbang'] = Helper::format_money(isset($playerData[$row['date']]) && $playerData[$row['date']]['bigbang'] ? $playerData[$row['date']]['bigbang'] : 0);
            $list[] = $row;
        }
        $result['total'] = $total;
        $result['list'] = $list;
        return $result;
    }

    private function _getGeneralAgentPlayerDataByDate($accountId, $startDate, $endDate, $offset, $limitValue)
    {
        $startTime = strtotime($startDate);
        $endTime = strtotime($endDate) + 86400;

        $db = $this->mysql->getDb();
        $db->join(MysqlTables::ACCOUNT_TREE . ' AS t', 'a.id=t.ancestor_id AND t.descendant_agent=0', 'LEFT');
        $db->join(MysqlTables::COINS_PLAYER . ' AS c', 't.descendant_id=c.account_id', 'LEFT');
        $fields = 'FROM_UNIXTIME(c.create_time, \'%Y-%m-%d\') AS datetime, SUM(IF(c.type=1, c.coin, 0)) AS player_add_coin, -1*SUM(IF(c.type=2, c.coin, 0)) AS player_sub_coin, -1*SUM(IF(c.type IN (3, 4, 5, 6), c.coin, 0)) AS player_win_coin, SUM(IF(c.type=5, c.coin, 0)) AS bigbang';
        $db->groupBy('datetime');
        $db->orderBy('datetime', 'DESC');
        $db->where('a.parent_id', $accountId);
        $db->where('c.create_time', [$startTime, $endTime], 'BETWEEN');
        $rs = $db->get(MysqlTables::ACCOUNT . ' AS a', null, $fields);
        return $rs;
    }

    public function _getGeneralAgentAgentDataByDate($accountId, $startDate, $endDate, $offset, $limitValue)
    {
        $startTime = strtotime($startDate);
        $endTime = strtotime($endDate) + 86399;

        $sql = "SELECT d.date,b.agent_add_coin,b.agent_sub_coin FROM " . MysqlTables::ASSIST_DATELIST . " AS d LEFT JOIN (
                    SELECT FROM_UNIXTIME(c.create_time,'%Y-%m-%d') AS datetime, SUM(IF(c.type=1, c.coin, 0)) AS agent_add_coin, -1*SUM(IF(c.type=2, c.coin, 0)) AS agent_sub_coin FROM " . MysqlTables::ACCOUNT . " AS a LEFT JOIN " . MysqlTables::COINS_PLAYER . " AS c ON a.id=c.account_id WHERE (a.id={$accountId} OR a.parent_id={$accountId}) AND a.agent > 0 AND c.create_time BETWEEN {$startTime} AND {$endTime} AND agent>0 GROUP BY datetime
                    ) AS b ON d.date=b.datetime WHERE d.date >= '{$startDate}' AND d.date <= '{$endDate}' ORDER BY d.date DESC LIMIT {$offset},{$limitValue}";

        return $this->mysql->getDb()->rawQuery($sql);
    }

    /**
     * Bigbang查询
     */
    public function getBigbangList($page, $limitValue, $accountId = '', $startDate = '', $endDate = '', $orderByField = '', $orderByDirection = '')
    {
        $db = $this->mysql->getDb();
        $offset = ($page = abs(intval($page))) > 0 ? ($page - 1) * $limitValue : 0;

        $db->join(MysqlTables::ACCOUNT . ' AS a', "a.id=c.account_id", 'LEFT');
        if ($startDate && $endDate) {
            $startTime = strtotime($startDate);
            $endTime = strtotime($endDate) + 86399;
            $db->where('c.create_time', [$startTime, $endTime], 'between');
        }
        $db->where('c.type', 5);
        $accountId && $db->where('a.id', $accountId);
        $orderByField = $orderByField ? $orderByField : 'bigbang';
        $orderByDirection = $orderByDirection ? $orderByDirection : 'desc';
        $db->orderBy($orderByField, $orderByDirection);
        $db->groupBy('c.account_id');
        $select = "a.id, a.pid AS username, SUM(c.coin) AS bigbang";
        $list = $db->withTotalCount()->get(MysqlTables::COINS_PLAYER . ' AS c', [$offset, $limitValue], $select);
        $total = $db->getTotalCount();
        return ['list' => $list, 'total' => $total];
    }

    /**
     * bigbang明细查询
     */
    public function getBigbangDetail($page, $limitValue, $accountId, $startDate = '', $endDate = '', $orderByField = '', $orderByDirection = '')
    {
        $db = $this->mysql->getDb();
        $offset = ($page = abs(intval($page))) > 0 ? ($page - 1) * $limitValue : 0;

        $joinWhere = "d.date=FROM_UNIXTIME(c.create_time,'%Y-%m-%d')";
        $joinWhere .= " AND c.account_id='{$accountId}'";
        if ($startDate && $endDate) {
            $startTime = strtotime($startDate);
            $endTime = strtotime($endDate) + 86399;
            $joinWhere .= " AND c.create_time BETWEEN {$startTime} AND {$endTime}";
        }
        $joinWhere .= " AND c.type=5";

        $db->join(MysqlTables::COINS_PLAYER . ' AS c', $joinWhere, 'LEFT');
        $db->where('d.date', [$startDate, $endDate], 'BETWEEN');
        $db->groupBy('d.date');
        $orderByField = $orderByField ? $orderByField : 'date';
        $orderByDirection = $orderByDirection ? $orderByDirection : 'desc';
        $db->orderBy($orderByField, $orderByDirection);
        $select = "d.date, SUM(c.coin) AS bigbang";
        $list = $db->withTotalCount()->get(MysqlTables::ASSIST_DATELIST . ' AS d', [$offset, $limitValue], $select);
        $total = $db->getTotalCount();
        return ['list' => $list, 'total' => $total];
    }

    //代理下的玩家在evo里的输赢
    private function getAgentEvoTotalReport($agent_id, $limitValue, $offset, $page, $startTime, $endTime)
    {
        $db = $this->mysql->getDb();

        $mydb = clone $db;
        $totalWin = 0;
        // 赢钱
        $mydb->join(MysqlTables::ACCOUNT_TREE . ' AS t', 'a.id=t.ancestor_id ', 'LEFT');
        $joinWhere = 't.descendant_id=c.account_id';
        $where = "";
        if ($startTime && $endTime) {
            $startDay = date('Ymd', $startTime);
            $endDay = date('Ymd', $endTime);
            $where = " where create_time BETWEEN {$startDay} AND {$endDay}";
        }
        $mydb->join('( select account_id,win  from coins_evo_player_day '.$where.' ) AS c', $joinWhere, 'LEFT');
        // $mydb->join('( select account_id, (win - bet ) as cwin  from gameserver_gamelog_evo '.$where.' ) AS c', $joinWhere, 'LEFT');
        $fields = "a.id, a.username, -1*SUM(c.win) as coin";
        
        $mydb->where('a.parent_id', $agent_id);
        $mydb->where('a.agent', 0, '>');
        $mydb->where('t.descendant_agent', 0, '=');

        // 第一页计算总赢钱
        if ($page == 1) {
            $totalWinDb = clone $mydb;
            $totalWin = $totalWinDb->sum(MysqlTables::ACCOUNT . ' AS a', '-1 * c.win');
        }
        
        $mydb->groupBy('a.id');
        $mydb->orderBy('a.id', 'ASC');

        $list = $mydb->withTotalCount()->get(MysqlTables::ACCOUNT . ' AS a', [$offset, $limitValue], $fields);
        $total= $mydb->getTotalCount();

        $tmp = [];
        foreach($list as $v) {
            $tmp[$v['id']] = $v['coin'];
        }

        $result['list'] = $tmp;
        $result['total'] = $total;
        $result['total_win'] = $totalWin;
        return $result;

    }

    /**
     * 代理总账
     */
    public function getAgentTotalReport($page, $limitValue, $startTime, $endTime, $username)
    {
        $db = $this->mysql->getDb();
        $offset = ($page = abs(intval($page))) > 0 ? ($page - 1) * $limitValue : 0;

        $result = ['list' => [], 'total' => 0, 'total_win' => 0.00];
        $token = $this->getTokenObj();
        if ($username && !($account = $db->where('username', $username)->getOne(MysqlTables::ACCOUNT))) {
            return $result;
        }
        $parentId = isset($account) && $account ? $account['id'] : $token->account_id;
        if (!$this->models->account_model->isDescendant($token->account_id, $parentId)) {
            return $result;
        }

        $evo_data = $this->getAgentEvoTotalReport($parentId, $limitValue, $offset, $page, $startTime, $endTime);

        $totalWin = $totalLose = 0;
        // 赢钱
        $db->join(MysqlTables::ACCOUNT_TREE . ' AS t', 'a.id=t.ancestor_id ', 'LEFT');
        $joinWhere = 't.descendant_id=c.account_id';
        $where = "";
        if ($startTime && $endTime) {
            $startDay = date('Ymd', $startTime);
            $endDay = date('Ymd', $endTime);
            // $joinWhere .= " AND c.create_time BETWEEN {$startDay} AND {$endDay}";
            $where = " where create_time BETWEEN {$startDay} AND {$endDay}";
        }
        $db->join('( select account_id,win  from coins_player_day '.$where.' ) AS c', $joinWhere, 'LEFT');
        $fields = "a.id, a.username, a.nickname, a.phone, a.remark, -1*SUM(c.win) as coin";
        
        $db->where('a.parent_id', $parentId);
        $db->where('a.agent', 0, '>');
        $db->where('t.descendant_agent', 0, '=');

        // 第一页计算总赢钱
        if ($page == 1) {
            $totalWinDb = clone $db;
            $totalWin = $totalWinDb->sum(MysqlTables::ACCOUNT . ' AS a', '-1 * c.win');
        }
        
        $db->groupBy('a.id');
        $db->orderBy('a.id', 'ASC');
        $list = $db->withTotalCount()->get(MysqlTables::ACCOUNT . ' AS a', [$offset, $limitValue], $fields);
        $total= $db->getTotalCount();
        foreach ($list as $key => $value) {
            $list[$key]['evocoin'] = isset($evo_data['list'][$value['id']]) ? $evo_data['list'][$value['id']] : 0;
        }
        $result['list'] = $list;
        $result['total'] = $total;
        $result['total_win'] = $totalWin;
        $result['total_evo_win'] = $evo_data['total_win'];

        return $result;
    }

    //根据代理id，时间获取它下面的所有玩家的总账
    private function getPlayerEvoTotalReport($agent_id, $start_time, $end_time, $page = 1, $offset, $limitValue)
    {
        $db = $this->mysql->getDb();

        $mydb = clone $db;
        // 赢钱
        $joinWhere = 'a.id=c.account_id';
        if ($start_time && $end_time) {
            $joinWhere .= " AND c.create_time BETWEEN {$start_time} AND {$end_time}";
        }
        $mydb->join(MysqlTables::GAMESERVER_GAMELOG_EVO . ' AS c', $joinWhere, 'LEFT');
        $fields = "a.id, a.pid AS username, a.nickname, SUM(c.bet - c.win) AS coin";
        $mydb->where('a.parent_id', $agent_id);
        $mydb->where('a.agent', 0);

        $totalWin = 0;
        if ($page == 1) {
            $totalWinDb = clone $mydb;
            $totalWin = $totalWinDb->sum(MysqlTables::ACCOUNT . ' AS a', 'c.bet - c.win');
        }
        $mydb->groupBy('a.id');
        $mydb->orderBy('a.id', 'ASC');
        $list = $mydb->withTotalCount()->get(MysqlTables::ACCOUNT . ' AS a', [$offset, $limitValue], $fields);

        $tmp = [];
        foreach($list as $k=>$v) {
            $tmp[$v['id']] = $v['coin'];
        }
        $result = [];
        $result['total_win'] = $totalWin;
        $result['list'] = $tmp;
        echo json_encode($result);
        return $result;
    }

    /**
     * 玩家总账
     */
    public function getPlayerTotalReport($username, $page, $limitValue, $startTime, $endTime)
    {
        $db = $this->mysql->getDb();
        $offset = ($page = abs(intval($page))) > 0 ? ($page - 1) * $limitValue : 0;
        $totalWin = $totalLose = 0;
        $token = $this->getTokenObj();

        $result = ['list' => [], 'total' => 0, 'total_win' => 0.00];
        if ($username && !($account = $db->where('username', $username)->getOne(MysqlTables::ACCOUNT))) {
            return $result;
        }
        $parentId = isset($account) && $account ? $account['id'] : $token->account_id;

        $result_evo = $this->getPlayerEvoTotalReport($parentId, $startTime, $endTime, $page, $offset, $limitValue);
        $result['total_evo'] = $result_evo['total_win'];

        // 赢钱
        $joinWhere = 'a.id=c.account_id';
        if ($startTime && $endTime) {
            $joinWhere .= " AND c.create_time BETWEEN {$startTime} AND {$endTime}";
        }
        $joinWhere .= " AND c.type IN (3, 4, 5, 6)";
        $db->join(MysqlTables::COINS_PLAYER . ' AS c', $joinWhere, 'LEFT');
        $fields = "a.id, a.pid AS username, a.nickname, SUM(c.coin) AS coin";
        $db->where('a.parent_id', $parentId);
        $db->where('a.agent', 0);
        // 第一页计算总赢钱
        if ($page == 1) {
            $totalWinDb = clone $db;
            $totalWin = $totalWinDb->sum(MysqlTables::ACCOUNT . ' AS a', 'c.coin');

            if (Config::getInstance()->getConf('APPTYPE') == '1') {
                $uids_sql  = "select id from account where parent_id={$parentId} and agent=0";
                $uids_rets = $totalWinDb->rawQuery($uids_sql);
                if($uids_rets) {
                    $uids = [];
                    foreach($uids_rets as $row) {
                        $uids[] = $row['id'];
                    }
                    if(!empty($uids)) {
                        $uids_arr_str = implode(',', $uids);
                        $sql = "select sum(coin) as ccoin from coins_player 
                            where account_id in (select distinct descendant_id from account_tree where ancestor_id in (".$uids_arr_str.") and descendant_id not in (".$uids_arr_str.") ) 
                                and create_time between {$startTime} and {$endTime} and type in (3,4,5,6)";
                        $row = $totalWinDb->rawQuery($sql);

                        $childrens_coin = is_null($row[0]['ccoin']) ? 0 : $row[0]['ccoin'];
                        $totalWin += $childrens_coin;
                    }
                }
            }
        }

        

        $db->groupBy('a.id');
        $db->orderBy('a.id', 'ASC');
        $list = $db->withTotalCount()->get(MysqlTables::ACCOUNT . ' AS a', [$offset, $limitValue], $fields);
        $result['total'] = $db->getTotalCount();
        foreach($list as $k=>$v) {
            if (Config::getInstance()->getConf('APPTYPE') == '1') {
                $sql = "select sum(coin) as ccoin from coins_player 
                            where account_id in (select distinct descendant_id from account_tree where ancestor_id ={$v['id']} and descendant_id !={$v['id']} ) 
                                and create_time between {$startTime} and {$endTime} and type in (3,4,5,6)";
                $row = $db->rawQuery($sql);
                $list[$k]['ccoin'] = is_null($row[0]['ccoin']) ? 0 : $row[0]['ccoin'];

                $list[$k]['ccoin'] = (-1) * $list[$k]['ccoin'];
                $list[$k]['coin'] = (-1) * $list[$k]['coin'];

                $list[$k]['allcoin'] = number_format(($list[$k]['coin'] + $list[$k]['ccoin']), 4); 
            } else {
                $list[$k]['coin'] = (-1) * $list[$k]['coin'];
                $list[$k]['allcoin'] = number_format(($list[$k]['coin']), 4); 
                $list[$k]['evocoin'] = isset($result_evo['list'][$v['id']]) ? $result_evo['list'][$v['id']] : 0;
            }
        }

        $result['list'] = $list;
        $result['total_win'] = $totalWin * (-1);
        // file_put_contents("/tmp/debug.log", json_encode($result) . "\r\n", FILE_APPEND);
        return $result;
    }

    public function checkAccountList($page, $limitValue)
    {
        $db = $this->mysql->getDb();
        $offset = ($page = abs(intval($page))) > 0 ? ($page - 1) * $limitValue : 0;

        $db->orderBy('id', 'DESC');
        $select = "*";
        $list = $db->withTotalCount()->get(MysqlTables::STAT_ALARM, [$offset, $limitValue], $select);
        $total = $db->getTotalCount();
        return ['list' => $list, 'total' => $total];
    }

    // 游戏记录
    public function gameRecordPoly($pid, $page = 0, $limitValue = 10, $startTime = 0, $endTime = 0, $orderBy = 'create_time desc', $type=1)
    {
        $curUser = $this->getTokenObj();
        $result = ['total'=> 0, 'list'=> [], 'coin' => 0];
        // 根据$pid获取用户ID
        $db = $this->mysql->getDb();
        $db->where('pid', $pid);
        $account = $db->getOne(MysqlTables::ACCOUNT);
        if (empty($account)) {
            return $result;
        }
        if (!$this->models->account_model->isDescendant($curUser->account_id, $account['id'])) {
            return $result;
        }
        $result['coin'] = $account['coin'];
        $accountId = $account['id'];
        $offset = ($page = abs(intval($page))) > 0 ? ($page - 1) * $limitValue : 0;
        $fields = 'id, game_id, `desk_id`, `bet`, `win`, `before`, `after`, rlt, create_time,extend1';
        $db->where('account_id', $accountId);

        if ($this->getAbutmentKey('isOpenApi')) {
            if ($endTime < $startTime || $endTime - $startTime > 2592000) {
                $this->setErrMsg('时间范围错误');
                return $result;
            }
        } else {
            $startTime && $endTime && $db->where('create_time', [$startTime, $endTime], 'BETWEEN');
        }
        
        $orderBy = $orderBy ? $orderBy : 'log_id desc';
        list($orderByField, $orderByDirection) = explode(' ', $orderBy);
        $db->orderBy($orderByField, $orderByDirection);
        $table = MysqlTables::GAMESERVER_GAMELOG;
        if($type == 2) {
            $table = MysqlTables::GAMESERVER_GAMELOG_EVO;
        }
        $result['list'] = $db->withTotalCount()->get($table, [$offset, $limitValue], $fields);
        $result['total'] = $db->getTotalCount();
        return $result;
    }

    public function gameRecordDetail($logId)
    {
        $db = $this->mysql->getDb();

        return $db->where('id', $logId)->getOne(MysqlTables::GAMESERVER_GAMELOG);
    }

    /**
     * 新手策略用户列表
     */
    public function newStrategyList($page, $limitValue)
    {
        $db = $this->mysql->getDb();
        $offset = ($page = abs(intval($page))) > 0 ? ($page - 1) * $limitValue : 0;
        $fields = 'account_id, login_time, (balance-reload) as win, available';
        $db->orderBy('id', 'desc');
        $result['list'] = $db->withTotalCount()->get(MysqlTables::SOUL_S1_ACCOUNT, [$offset, $limitValue], $fields);
        $result['total'] = $db->getTotalCount();
        foreach ($result['list'] as &$one) {
            $one['status'] = $one['available'] == 1 ? 1 : 2;
            $prob = $this->models->prob_model->getUserProb($one['account_id']);
            $one['prob'] = $prob ? $prob['prob'] : 3;
        }
        return $result;
    }

    /**
     * 新手策略每小时打点数据列表
     */
    public function newStrategyCountList($page, $limitValue)
    {
        $db = $this->mysql->getDb();
        $offset = ($page = abs(intval($page))) > 0 ? ($page - 1) * $limitValue : 0;
        $fields = '*';
        $db->orderBy('id', 'desc');
        $result['list'] = $db->withTotalCount()->get(MysqlTables::STAT_SOUL_ACCOUNT, [$offset, $limitValue], $fields);
        $result['total'] = $db->getTotalCount();
        return $result;
    }

    /**
     * 新手策略每小时打点数据
     */
    public function newStrategyCount()
    {
        $db = $this->mysql->getDb();

        $rs = $db->getOne(MysqlTables::SOUL_S1_ACCOUNT, 'count(1) as total_num, sum(IF(available=1, 1, 0)) as effect_num, sum(balance - reload) as win');
        $data = [
            'datetime' => time(),
            'total_num' => $rs && $rs['total_num'] ? $rs['total_num'] : 0,
            'effect_num' => $rs && $rs['effect_num'] ? $rs['effect_num'] : 0,
            'win' => $rs && $rs['win'] ? $rs['win'] : 0
        ];
        $db->insert(MysqlTables::STAT_SOUL_ACCOUNT, $data);
    }

    public function getRedEnvelopeRecord($keywords, $page, $limitValue)
    {
        $offset = ($page - 1) * $limitValue;
        $curUser = $this->getTokenObj();
        $db = $this->mysql->getDb();
        $db->join(MysqlTables::COINS_PLAYER . ' as c', 'a.id=c.account_id', 'LEFT');
        $db->where('a.parent_id', $curUser->account_id);
        if ($keywords) {
            $db->where("(a.pid={$keywords} OR a.nickname={$keywords})");
        }
        $db->where('a.agent', 0);
        $db->where('c.type', 12);
        $db->where('c.account_id is not null');

        $db->orderBy('c.create_time', 'desc');
        $fields = 'a.id, a.pid, a.nickname, c.coin, c.create_time';
        $list = $db->withTotalCount()->get(MysqlTables::ACCOUNT . ' AS a', [$offset, $limitValue], $fields);
        $result['list'] =  $list;
        $result['total'] = $db->getTotalCount();
        return $result;
    }

    //获取总代给游戏内玩家发的红包记录
    public function getRedPacketRecord($keywords, $page, $limitValue, $startTime, $endTime)
    {
        $offset = ($page - 1) * $limitValue;
        $curUser = $this->getTokenObj();
        $db = $this->mysql->getDb();
        $db->join( MysqlTables::ACCOUNT. ' as a', 'a.id=c.account_id', 'LEFT');
        if ($keywords) {
            $db->where("(a.pid={$keywords} OR a.nickname={$keywords})");
        }
        if($startTime && $endTime) {
            $db->where("(c.create_time>={$startTime} and c.create_time<={$endTime})");
        }
        $db->orderBy('c.id', 'desc');
        $fields = 'a.id, a.pid, a.nickname, c.coin, c.create_time';
        $list = $db->withTotalCount()->get(MysqlTables::REDBAG_ZONGDAI . ' AS c', [$offset, $limitValue], $fields);
        $result['list'] =  $list;
        $result['total'] = $db->getTotalCount();
        return $result;
    }

    //设定总代给游戏内玩家发的红包
    public function setRedPacket($account_str, $coin)
    {
        $account_arr = [];
        if(strlen($account_str)) {
            $account_arr = explode(',', $account_str);
        }
        if($coin <= 0) {
            $this->setErrCode(3002);
            $this->setErrMsg('红包金额必须大于0');
            return false;
        }
        $uids = [];
        if(!empty($account_arr)) {
            $pid_str = "";
            foreach($account_arr as $v) {
                $pid_str .= "'".$v."',";
            }
            $pid_str = rtrim($pid_str, ',');
            $db = $this->mysql->getDb();
            $db->where("pid in ({$pid_str})");
            $fields = 'id';
            $list = $db->get(MysqlTables::ACCOUNT,[0, 10000], $fields);
            foreach($list as $item) {
                $uids[] = $item['id'];
            }
        }
        $data = [
            'coin' => $coin,
            'uid'  => implode(',', $uids),
        ];
        if (! $this->models->curl_model->pushRedPacketSetting($data)) {
            $this->setErrMsg($this->models->curl_model->getErrMsssage());
            return false;
        } 
        return true;
    }

    /**
     * 获取推广员一级玩家列表
     */
    public function getUserList($parentId, $keywords, $page, $limitValue)
    {
        $offset = ($page - 1) * $limitValue;
        $db = $this->mysql->getDb();
        $db->where('parent_id', $parentId);
        $db->orderBy('id', 'desc');
        $list = $db->withTotalCount()->get(MysqlTables::ACCOUNT, [$offset, $limitValue], 'id, pid, coin, create_time, pprofit_total');
        $result['list'] =  $list;
        $result['total'] = $db->getTotalCount();
        return $result;
    }

    public function getDivideRecord($pid)
    {
        $curUser = $this->getTokenObj();
        $db = $this->mysql->getDb();
        // 获取目标账号信息
        if (!($account = $db->where("(pid={$pid} OR pusername={$pid})")->getOne(MysqlTables::ACCOUNT))) {
            $this->setErrMsg('账号不存在');
            return false;
        }
        // 判断是否是当前用户的子孙
        if (!($this->models->account_model->isDescendant($curUser->account_id, $account['id']))) {
            $this->setErrMsg('账号不存在');
            return false;
        }
        $list = $db->where('relation_account_id', $account['id'])
                   ->where('t', 1)
                   ->groupBy('account_id')
                   ->orderBy('tree_depth', 'asc')
                   ->get(MysqlTables::LOG_PROFIT_PLAYER, null, 'account_id, SUM(coin) as total_coin, tree_depth');
        if ($list) {
            $accountIds = array_column($list, 'account_id');
            $accounts = $db->where('id', $accountIds, 'IN')->get(MysqlTables::ACCOUNT, null, 'id, pid, pusername');
            $accounts = array_column($accounts, null, 'id');
            foreach ($list as &$one) {
                $one['username'] = isset($accounts[$one['account_id']]) ? ($accounts[$one['account_id']]['pusername'] ?: $accounts[$one['account_id']]['pid']) : '';
            }
        }
        return $list;
    }

    public function getTotalFlows($account, $startTime, $endTime, $page, $limitValue)
    {
        $curUser = $this->getTokenObj();
        $db = $this->mysql->getDb();
        // 获取目标账号信息
        if (!($account = $db->where("(pid={$account} OR pusername={$account})")->getOne(MysqlTables::ACCOUNT))) {
            $this->setErrMsg('账号不存在');
            return false;
        }
        // 判断是否是当前用户的子孙
        if (!($this->models->account_model->isDescendant($curUser->account_id, $account['id']))) {
            $this->setErrMsg('账号不存在');
            return false;
        }
        $offset = ($page - 1) * $limitValue;
        $db = $this->mysql->getDb();
        $db->where('date', [date('Y-m-d', $startTime), date('Y-m-d', $endTime)], 'BETWEEN');
        $db->orderBy('id', 'desc');
        $list = $db->withTotalCount()->get(MysqlTables::ASSIST_DATELIST, [$offset, $limitValue], 'id, date');
        $result['total'] = $db->getTotalCount();
        if ($list) {
            $dates = array_column($list, 'date');
            $startTime = strtotime(min($dates));
            $endTime = strtotime(max($dates));
            $db->where('account_id', $account['id']);
            $db->where('create_time', [$startTime, $endTime], 'BETWEEN');
            $db->where('type', 3);
            $db->groupBy('date');
            $coinsPlayer = $db->get(MysqlTables::COINS_PLAYER, null, "FROM_UNIXTIME(create_time,'%Y-%m-%d') AS date, SUM(coin) AS coin");
            $coinsPlayer = array_column($coinsPlayer, 'coin', 'date');
            foreach ($list as &$one) {
                $one['pid'] = $account['pid'];
                $one['coin'] = isset($coinsPlayer[$one['date']]) ? $coinsPlayer[$one['date']] : 0;
            }
        }
        $result['list'] =  $list;
        return $result;
    }

    public function getTransfer($username, $page, $limitValue)
    {
        $offset = ($page - 1) * $limitValue;
        $db = $this->mysql->getDb();
        $result = ['list' => [], 'total' => 0];
        if ($username) {
            $account = $db->where('pid', $username)->getOne(MysqlTables::ACCOUNT);
            if (empty($account)) {
                return $result;
            }
            $db->where("(from_account_id={$account['id']} OR to_account_id={$account['id']})");
        }
        $db->orderBy('id', 'desc');
        $list = $db->withTotalCount()->get(MysqlTables::SCORE_RELATION_LOG, [$offset, $limitValue]);
        $result['total'] = $db->getTotalCount();
        if ($list) {
            $account_ids = array_unique(array_merge(array_column($list, 'from_account_id'), array_column($list, 'to_account_id')));
            $db->where('id', $account_ids, 'IN');
            $accounts = $db->get(MysqlTables::ACCOUNT, null, "id, pid");
            $accounts = array_column($accounts, 'pid', 'id');
            foreach ($list as &$one) {
                $one['from_pid'] = isset($accounts[$one['from_account_id']]) ? $accounts[$one['from_account_id']] : $one['from_account_id'];
                $one['to_pid'] = isset($accounts[$one['to_account_id']]) ? $accounts[$one['to_account_id']] : $one['to_account_id'];
            }
        }
        $result['list'] =  $list;
        return $result;
    }

    public function getGameStat($field, $order)
    {
        //游戏数据统计 -- 获取所有游戏列表
        /* $_games = $this->models->curl_model->getGameLists(1);
        if (is_array($_games) && count($_games) && isset($_games[0]['id'])) {
            foreach ($_games as $g) {
                $this->mysql->getDb()->where('game_id', $g['id'])->update(MysqlTables::STAT_GAMES, ['num_favorite'=> $g['collector']]);
            }
        } */
        
        $db = $this->mysql->getDb();
        $db->orderBy($field, $order);
        $list = $db->withTotalCount()->get(MysqlTables::STAT_GAMES);
        $result['list'] =  $list;
        
        $result['total'] = $db->getTotalCount();
        return $result;
    }
    
    public function getGameStat2($time_min_start, $time_min_end, $field, $order) : array
    {
        $result = ['list'=> []];
        
        if ($time_min_start == $time_min_end || $time_min_start > $time_min_end || $time_min_start != strtotime(date("Y-m-d H:i:s", $time_min_start)) || $time_min_end != strtotime(date("Y-m-d H:i:s", $time_min_end))) {
            $this->setErrMsg("时间参数错误");
            return [];
        }
        
        if (! ($s = $this->mysql->getDb()->where('time', $time_min_start)->getOne(MysqlTables::STAT_GAMES_LOG))) {
            $s = $this->mysql->getDb()->orderBy('time', 'ASC')->getOne(MysqlTables::STAT_GAMES_LOG);
        }
        if (! ($e = $this->mysql->getDb()->where('time', $time_min_end)->getOne(MysqlTables::STAT_GAMES_LOG))) {
            $e = $this->mysql->getDb()->orderBy('time', 'DESC')->getOne(MysqlTables::STAT_GAMES_LOG);
        }
        
        if (! $s && ! $e) {
            return $result;
        } elseif ($s && ! $e || $s == $e) {
            $result['list'] = json_decode($s['datas'], true);
            foreach ($result['list'] as &$d) {
                $d['amount_syswin'] = Helper::format_money($d['amount_bet'] - $d['amount_payout']);
                $d['amount_betfullsyswin'] = Helper::format_money($d['amount_betfull'] - $d['amount_betfullpayout']);
            }
        } elseif ($e && ! $s) {
            $result['list'] = json_decode($e['datas'], true);
            foreach ($result['list'] as &$d) {
                $d['amount_syswin'] = Helper::format_money($d['amount_bet'] - $d['amount_payout']);
                $d['amount_betfullsyswin'] = Helper::format_money($d['amount_betfull'] - $d['amount_betfullpayout']);
            }
        } else {
            $datas_s = json_decode($s['datas'], true);
            $datas_e = json_decode($e['datas'], true);
            foreach ($datas_s as $dk => $dv) {
                
                $result['list'][$dk]['num_betofplayer'] = $datas_e[$dk]['num_betofplayer'] - $datas_s[$dk]['num_betofplayer'];
                $result['list'][$dk]['amount_bet'] = Helper::format_money($datas_e[$dk]['amount_bet'] - $datas_s[$dk]['amount_bet']);
                $result['list'][$dk]['amount_payout'] = Helper::format_money($datas_e[$dk]['amount_payout'] - $datas_s[$dk]['amount_payout']);
                
                $result['list'][$dk]['amount_syswin'] = Helper::format_money(($datas_e[$dk]['amount_bet'] - $datas_s[$dk]['amount_bet']) - ($datas_e[$dk]['amount_payout'] - $datas_s[$dk]['amount_payout']));
                
                $result['list'][$dk]['num_betfullofplayer'] = $datas_e[$dk]['num_betfullofplayer'] - $datas_s[$dk]['num_betfullofplayer'];
                $result['list'][$dk]['amount_betfull'] = Helper::format_money($datas_e[$dk]['amount_betfull'] - $datas_s[$dk]['amount_betfull']);
                $result['list'][$dk]['amount_betfullpayout'] = Helper::format_money($datas_e[$dk]['amount_betfullpayout'] - $datas_s[$dk]['amount_betfullpayout']);
                
                $result['list'][$dk]['amount_betfullsyswin'] = Helper::format_money(($datas_e[$dk]['amount_betfull'] - $datas_s[$dk]['amount_betfull']) - ($datas_e[$dk]['amount_betfullpayout'] - $datas_s[$dk]['amount_betfullpayout']));
                
                $result['list'][$dk]['num_favorite'] = $datas_e[$dk]['num_favorite'] - $datas_s[$dk]['num_favorite'];
                
            }
        }
        
        if ($result['list']) {
            $result['list'] = $this->_arraySort($result['list'], $field, $order);
        }
        
        return $result;
    }
    
    private function _arraySort($arr = [], $keys = '', $type = 'asc')
    {
        $keysvalue = $new_array = [];
        foreach ($arr as $k => $v) {
            $keysvalue[$k] = $v[$keys];
        }
        
        if ($type == 'asc') {
            natsort($keysvalue);
        }
        
        if ($type == 'desc') {
            natsort($keysvalue);
            $keysvalue = array_reverse($keysvalue, TRUE);
        }
        
        foreach ($keysvalue as $k => $v) {
            $new_array[$k] = $arr[$k];
        }
        
        return $new_array;
    }
    
    public function getGameStat3($time_min_start, $time_min_end, $min) : array
    {
        $result = ['list'=> []];
        
        if ($time_min_start == $time_min_end || $time_min_start > $time_min_end || $time_min_start != strtotime(date("Y-m-d H:i:s", $time_min_start)) || $time_min_end != strtotime(date("Y-m-d H:i:s", $time_min_end))) {
            $this->setErrMsg("时间参数错误");
            return [];
        }
        
        $list = $this->mysql->getDb()->where('time', $time_min_start, '>=')->where('time', $time_min_end, '<=')->orderBy('time', 'ASC')->get(MysqlTables::STAT_GAMES_LOG);
        
        foreach ($list as $kk=> $d) {
            
            if ($min == '30') {
                if (date("i", $d['time']) == '30' || date("i", $d['time']) == '00') {
                    
                    $result['list'][] = [
                        'time'=> $d['time'],
                        'data'=> json_decode($d['datas'], true)
                    ];
                    
                }
            } elseif ($min == '60') {
                if (date("i", $d['time']) == '00') {
                    
                    $result['list'][] = [
                        'time'=> $d['time'],
                        'data'=> json_decode($d['datas'], true)
                    ];
                    
                }
            } elseif ($min == '1440') {
                if (date("H", $d['time']) == '00' && date("i", $d['time']) == '00') {
                    
                    $result['list'][] = [
                        'time'=> $d['time'],
                        'data'=> json_decode($d['datas'], true)
                    ];
                    
                }
            }
            
        }
        
        return $result;
    }
}