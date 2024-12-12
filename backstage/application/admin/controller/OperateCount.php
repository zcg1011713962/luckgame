<?php
namespace app\admin\controller;
use think\facade\Request;
use app\admin\controller\Parents;
use app\admin\model\AdminModel;
use app\admin\model\OperateCountModel;
use app\admin\model\MemberModel;

class OperateCount extends Parents {

    public function agent_count_table() {
        return $this->fetch();
    }

    public function getAgentCountTable() {
        $params = request()->param();
        $begin_time = isset($params['begin_time']) && !empty($params['begin_time']) ? date('Y-m-d',strtotime($params['begin_time'])) : date('Y-m-d');
        $end_time = isset($params['end_time']) && !empty($params['end_time']) ? date('Y-m-d',strtotime($params['end_time'])) : date('Y-m-d');
        $operateCountModel = new OperateCountModel;
        $result = $operateCountModel->getAgentCountTable($begin_time, $end_time);
        return ['code' => 0, 'data' => $result['data'], 'count' => $result['count'], 'total' => count($result['data']), 'msg' => 'ok'];
    }

    public function platform_integration_count_table() {
        return $this->fetch();
    }

    public function getPlatformIntergrationCountTable() {
        $params = request()->param();
        $begin_time = isset($params['begin_time']) && !empty($params['begin_time']) ? date('Y-m-d',strtotime($params['begin_time'])) : date('Y-m-d');
        $end_time = isset($params['end_time']) && !empty($params['end_time']) ? date('Y-m-d',strtotime($params['end_time'])) : date('Y-m-d');
        $operateCountModel = new OperateCountModel;
        $result = $operateCountModel->getPlatformIntergrationCountTable($begin_time, $end_time);
        return ['code' => 0, 'data' => $result['data'], 'total' => count($result['data']), 'msg' => 'ok'];
    }

    public function game_total() {
        $memberModel = new MemberModel;
        $gameList = $memberModel->getGameList('gameid,name');
        $this->assign('game_list', $gameList);
        return $this->fetch();
    }

    public function getGameTotal() {
        $params = request()->param();
        $begin_time = isset($params['begin_time']) && !empty($params['begin_time']) ? date('Y-m-d',strtotime($params['begin_time'])) : date('Y-m-d');
        $end_time = isset($params['end_time']) && !empty($params['end_time']) ? date('Y-m-d',strtotime($params['end_time'])) : date('Y-m-d');
        $game_id = isset($params['game_id']) && !empty($params['game_id']) ? intval($params['game_id']) : 0;
        $operateCountModel = new OperateCountModel;
        $result = $operateCountModel->getGameTotal($begin_time, $end_time, $game_id);
        return ['code' => 0, 'data' => $result['data'], 'total' => count($result['data']), 'count' => $result['count'], 'msg' => 'ok'];
    }

    public function platform_operate_total() {
        return $this->fetch();
    }

    public function getPlatformOperateTotal() {
        $params = request()->param();
        $begin_time = isset($params['begin_time']) && !empty($params['begin_time']) ? date('Y-m-d',strtotime($params['begin_time'])) : date('Y-m-d');
        $end_time = isset($params['end_time']) && !empty($params['end_time']) ? date('Y-m-d',strtotime($params['end_time'])) : date('Y-m-d');
        $operateCountModel = new OperateCountModel;
        $result = $operateCountModel->getPlatformOperateTotal($begin_time, $end_time);
        return ['code' => 0, 'data' => $result['data'], 'total' => count($result['data']), 'count' => $result['count'], 'msg' => 'ok'];
    }

    public function color_total() {
        return $this->fetch();
    }

    public function getColorTotal() {
        $begin_time = isset($params['begin_time']) && !empty($params['begin_time']) ? date('Y-m-d',strtotime($params['begin_time'])) : '';
        $end_time = isset($params['end_time']) && !empty($params['end_time']) ? date('Y-m-d',strtotime($params['end_time'])) : '';
        $operateCountModel = new OperateCountModel;
        $result = $operateCountModel->getColorTotal($begin_time, $end_time);
        return ['code' => 0, 'data' => $result['data'], 'count' => $result['count'], 'msg' => 'ok'];
    }
}