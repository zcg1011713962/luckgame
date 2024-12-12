<?php
namespace app\admin\controller;
use think\facade\Request;
use app\admin\controller\Parents;
use app\admin\model\AgentModel;
use app\admin\model\AdminModel;
use app\admin\model\PromoterModel;

class Agents extends Parents {

    // 顶级代理列表
    public function toplists() {
        $adminModel = new AdminModel;
        return $this->fetch();
    }

    // 顶级代理数据列表
    public function getList() {
        $params     = request()->param();
        $agent_id   = isset($params['agent_id']) && !empty($params['agent_id'])   ? $params['agent_id']       :      0;
        $uid        = isset($params['uid'])                                      ? intval($params['uid'])          :      0;
        $begin_time = isset($params['begin_time']) && !empty($params['begin_time']) ? $params['begin_time']           :      '';
        $end_time = isset($params['end_time']) && !empty($params['end_time']) ? $params['end_time']           :      '';
        $promoterModel = new PromoterModel;
        $result = $promoterModel->topAgentList($params['limit'], $agent_id, $uid, $begin_time, $end_time);
		return ['code' => 0, 'count' => $result['total'], 'data' => $result['data'], 'msg' => 'ok'];
    }

    // 代理列表
    public function lists() {
        return $this->fetch();
    }

    // 代理数据列表
    public function getLists() {

        $params     = request()->param();
        $agent_id   = isset($params['agent_id']) && !empty($params['agent_id']) ? intval($params['agent_id']) : 0;
        $level_id   = isset($params['level_id']) && !empty($params['level_id']) ? intval($params['level_id']) : 0;
        $uid = isset($params['uid']) && !empty($params['uid']) ? intval($params['uid']) : 0;
        $pid = isset($params['pid']) && !empty($params['pid']) ? intval($params['pid']) : 0;
        $commission_no_from = isset($params['cnf']) && !empty($params['cnf']) ? intval($params['cnf']) : 0;
        $commission_no_to = isset($params['cnt']) && !empty($params['cnt']) ? intval($params['cnt']) : 0;
        $commission_yes_from = isset($params['cyf']) && !empty($params['cyf']) ? intval($params['cyf']) : 0;
        $commission_yes_to = isset($params['cyt']) && !empty($params['cyt']) ? intval($params['cyt']) : 0;

        // $agentModel = new AgentModel;
        // $result = $agentModel->AgentList($params['limit'], $agent_id, $level_id, $subordinate_to, $uid, $pid, $commission_no_from, $commission_no_to, $commission_yes_from, $commission_yes_to);

        $promoterModel = new PromoterModel;
        $result = $promoterModel->AgentList($params['limit'], $agent_id, $level_id, $uid, $pid, $commission_no_from, $commission_no_to, $commission_yes_from, $commission_yes_to);


		return ['code' => 0, 'count' => $result['total'], 'data' => $result['data'], 'msg' => 'ok'];

    }

    // 代理详情数据列表
    public function getInfo() {
        $id = request()->param('id');
        $promoterModel = new PromoterModel;
        return $promoterModel->AgentInfo($id);
    }

    // 代理详情
    public function info() {
        $id = request()->param('id');
        $this->assign('id', $id);
        return $this->fetch();
    }

    // 代理详情-每日数据
    public function daylists() {
        $id = request()->param('id');
        $time = date('Y-m-d');
        $this->assign('id', $id);
        $this->assign('time', $time);
        return $this->fetch();
    }

    // 每日数据列表
    public function getDayLists() {

        $params     = request()->param();
        $limit      =  isset($params['limit']) && !empty($params['limit']) ? intval($params['limit']) : 30;
        $diff_id   = isset($params['diff_id']) && !empty($params['diff_id']) ? intval($params['diff_id']) : 0;
        $begin_time = isset($params['begin_time']) && !empty($params['begin_time']) ? $params['begin_time'] : date('Y-m-d');
        $end_time = isset($params['end_time']) && !empty($params['end_time']) ? $params['end_time'] : date('Y-m-d'). ' 23:59:59';
        $uid = isset($params['uid']) && !empty($params['uid']) ? intval($params['uid']) : 0;
        $pid = isset($params['pid']) && !empty($params['pid']) ? intval($params['pid']) : 0;
        $commission_no_from = isset($params['cnf']) && !empty($params['cnf']) ? intval($params['cnf']) : 0;
        $commission_no_to = isset($params['cnt']) && !empty($params['cnt']) ? intval($params['cnt']) : 0;
        $commission_yes_from = isset($params['cyf']) && !empty($params['cyf']) ? intval($params['cyf']) : 0;
        $commission_yes_to = isset($params['cyt']) && !empty($params['cyt']) ? intval($params['cyt']) : 0;

        // $agentModel = new AgentModel;
        // $result = $agentModel->DayAgentList($limit, $agent_id, $diff_id, $uid, $pid, $commission_no_from, $commission_no_to, $commission_yes_from, $commission_yes_to, $begin_time, $end_time);

        $promoterModel = new PromoterModel;
        $result = $promoterModel->DayAgentList($limit, $diff_id, $uid, $pid, $commission_no_from, $commission_no_to, $commission_yes_from, $commission_yes_to, $begin_time, $end_time);

		return ['code' => 0, 'count' => $result['total'], 'data' => $result['data'], 'msg' => 'ok'];
    }

    public function addAgent()
    {
        if ($this->request->isGet()) {
            //上级代理
            $model = new \app\agent\model\AdminModel();
            //$agents = $model->get3ji_list($agents_ids);
            $agents = $model->getAgentList();
            $this->assign('agents',$agents);
            return $this->fetch('add');
        } else {
            $data = request()->post();
            if(empty($data)){
                $this->error('参数有误');
            }

            $model = new \app\agent\model\AdminModel;

            if(empty($data['username'])){
                $this->error('昵称不能为空');
            }

            $checkUsername = $model->checkUsername($data['username']);
            if(!$checkUsername){
                $this->error('昵称有误或已存在');
            }

            if(empty($data['mobile'])){
                $this->error('手机号不能为空');
            }

            if(empty($data['repass'])){
                $this->error('密码不能为空');
            }
            if(empty($data['uid'])){
                $this->error('玩家ID不能为空');
            }

            if ($data['pid'] == 0) {
                $data['level'] = 1;
            } else {
                $data['level'] = 2;
            }

            $res = $model->doAdd($data);
            $model->query("set autocommit=1");
            if($res){
                
                $this->success('代理等级有误');
            }else{
                $this->error('新增代理失败');
            }

        }

    }

}
