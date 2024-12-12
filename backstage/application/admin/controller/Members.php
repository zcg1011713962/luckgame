<?php
namespace app\admin\controller;
use think\facade\Request;
use app\admin\controller\Parents;
use app\admin\model\AdminModel;
use app\admin\model\MemberModel;

class Members extends Parents {

    public function lists() {
        return $this->fetch();
    }

    public function getList() {

        $params = request()->param();
        $limit =  isset($params['limit']) && !empty($params['limit']) ? intval($params['limit']) : 30;
        $agent_id = isset($params['agent_id']) && !empty($params['agent_id']) ? intval($params['agent_id']) : 0;
        $where_column = isset($params['where_column']) && !empty($params['where_column']) ? $params['where_column'] : 0;
        $column_value = isset($params['column_value']) && !empty($params['column_value']) ? $params['column_value'] : 0;
        $role = isset($params['role']) && !empty($params['role']) ? intval($params['role']) : 0;
        $status = isset($params['status']) && !empty($params['status']) ? intval($params['status']) : 0;
        $channel_id = isset($params['channel_id']) && !empty($params['channel_id']) ? intval($params['channel_id']) : 0;
        $login_begin_time = isset($params['login_begin_time']) && !empty($params['login_begin_time']) ? $params['login_begin_time'] : 0;
        $login_end_time = isset($params['login_end_time']) && !empty($params['login_end_time']) ? $params['login_end_time'] : 0;
        $reg_begin_time = isset($params['reg_begin_time']) && !empty($params['reg_begin_time']) ? $params['reg_begin_time'] : 0;
        $reg_end_time = isset($params['reg_end_time']) && !empty($params['reg_end_time']) ? $params['reg_end_time'] : 0;
        $gold_where_id = isset($params['gold_where_id']) && !empty($params['gold_where_id']) ? $params['gold_where_id'] : 0;
        $gold_begin_value = isset($params['gold_begin_value']) && !empty($params['gold_begin_value']) ? intval($params['gold_begin_value']) : 0;
        $gold_end_value = isset($params['gold_end_value']) && !empty($params['gold_end_value']) ? intval($params['gold_end_value']) : 0;

        $memberModel = new MemberModel;
        $result = $memberModel->MemberList($limit, $agent_id, $where_column, $column_value, $role, $status, $channel_id, $login_begin_time, $login_end_time, $reg_begin_time, $reg_end_time, $gold_where_id, $gold_begin_value, $gold_end_value);
		return ['code' => 0, 'count' => $result['total'], 'data' => $result['data'], 'msg' => 'ok'];

    }

    public function info() {
        $id = request()->param('id');
        $memberModel = new MemberModel;
        $result = $memberModel->getInfo($id);
        $this->assign('data', $result);
        return $this->fetch();
    }

    public function pay_list() {
        return $this->fetch();
    }

    public function getPayList() {

        $params = request()->param();
        $limit =  isset($params['limit']) && !empty($params['limit']) ? intval($params['limit']) : 30;
        $agent_id = isset($params['agent_id']) && !empty($params['agent_id']) ? intval($params['agent_id']) : 0;
        $pay_type = isset($params['pay_type']) && !empty($params['pay_type']) ? intval($params['pay_type']) : 0;
        $uid = isset($params['uid']) && !empty($params['uid']) ? intval($params['uid']) : 0;
        $pay_sn = isset($params['pay_sn']) && !empty($params['pay_sn']) ? $params['pay_sn'] : 0;
        $order_begin_time = isset($params['order_begin_time']) && !empty($params['order_begin_time']) ? $params['order_begin_time'] : 0;
        $order_end_time = isset($params['order_end_time']) && !empty($params['order_end_time']) ? $params['order_end_time'] : 0;
        
        $memberModel = new MemberModel;
        $result = $memberModel->MemberPayList($limit, $agent_id, $pay_type, $uid, $pay_sn, $order_begin_time, $order_end_time);
		return ['code' => 0, 'count' => $result['total'], 'data' => $result['data'], 'msg' => 'ok'];
    }

    public function betting_list() {
        $memberModel = new MemberModel;
        $gameList = $memberModel->getGameList('gameid,name');
        $this->assign('game_list', $gameList);
        return $this->fetch();
    }

    public function getBettingList() {

        $params = request()->param();
        $limit =  isset($params['limit']) && !empty($params['limit']) ? intval($params['limit']) : 30;
        $agent_id = isset($params['agent_id']) && !empty($params['agent_id']) ? intval($params['agent_id']) : 0;
        $game_id = isset($params['game_id']) && !empty($params['game_id']) ? intval($params['game_id']) : 0;
        $uid = isset($params['uid']) && !empty($params['uid']) ? intval($params['uid']) : 0;
        $mark_id = isset($params['mark_id']) && !empty($params['mark_id']) ? intval($params['mark_id']) : 0;
        $mark_begin_time = isset($params['mark_begin_time']) && !empty($params['mark_begin_time']) ? $params['mark_begin_time'] : 0;
        $mark_end_time = isset($params['mark_end_time']) && !empty($params['mark_end_time']) ? $params['mark_end_time'] : 0;
        
        $memberModel = new MemberModel;
        $result = $memberModel->MemberBettingList($limit, $agent_id, $game_id, $uid, $mark_id, $mark_begin_time, $mark_end_time);
		return ['code' => 0, 'count' => $result['total'], 'data' => $result['data'], 'msg' => 'ok'];
    }
}
