<?php
namespace app\admin\controller;
use think\Controller;
use app\admin\controller\Parents;
use app\admin\model\AdminModel;
use app\admin\model\NewActivitysModel;


class NewActivitys extends Parents {
    
    // 活动文案列表
    public function lists() {
        $adminModel = new AdminModel;
        $agent_list = $adminModel->getList1(999);
        $this->assign('agent_list', $agent_list['list']);
        return $this->fetch();
    }

    public function getList() {
        $params = request()->param();
        $agent_id = isset($params['agent_id']) && !empty($params['agent_id'])   ? $params['agent_id']       :      0;
        $status = isset($params['status'])                                      ? intval($params['status']) : 99;
        $name = isset($params['name']) && !empty($params['name'])               ? $params['name']           :      '';
        $newActivitysModel = new NewActivitysModel;
        $result = $newActivitysModel->getActivityList($params['limit'], $agent_id, $status, $name);
		return ['code' => 0, 'count' => $result['total'], 'data' => $result['data'], 'msg' => 'ok'];
    }

    // 活动文案添加
    public function add() {
        $adminModel = new AdminModel;
        $agent_list = $adminModel->getList1(999);
        $newActivitysModel = new NewActivitysModel;
        $activityTypeList = $newActivitysModel->getActivityType();
        $this->assign('activityTypeList', $activityTypeList);
        $this->assign('agent_list', $agent_list['list']);
        return $this->fetch();
    }

    // 活动文案编辑
    public function edit() {
        $id = request()->param('id');
        $adminModel = new AdminModel;
        $agent_list = $adminModel->getList1(999);
        $newActivitysModel = new NewActivitysModel;
        $activityTypeList = $newActivitysModel->getActivityType();
        $activityInfo = $newActivitysModel->getActivityList(30,0,99,'',$id);
        $this->assign('id', $id);
        $this->assign('activityTypeList', $activityTypeList);
        $this->assign('agent_list', $agent_list['list']);
        $this->assign('activityInfo', $activityInfo);
        return $this->fetch();
    }

    // 活动文案保存
    public function saveActivity() {

        $params = request()->post();
        $file = request()->file('image');

        if (!isset($params['operator_id']) && empty($params['operator_id'])) {return $this->_error('请选择子运营商');}
        if (!isset($params['type']) && empty($params['type'])) {return $this->_error('请选择活动类型');}
        if (!isset($params['name']) && empty($params['name'])) {return $this->_error('活动名称不能为空');}
        if (!isset($params['begin_time']) && empty($params['begin_time'])) {return $this->_error('开始时间不能为空');}
        if (!isset($params['end_time']) && empty($params['end_time'])) {return $this->_error('结束时间不能为空');}
        if ($params['begin_time'] > $params['end_time']) {return $this->_error('开始时间不能大于结束时间');}

        // 如果有图片
        if (!empty($file)){
            $image = $file->validate(['ext'=>'jpg,png,gif'])->move( './uploads/activity');
		    if (!$image) {return $this->_error('上传图片失败');}
            $params['image'] = '/uploads/activity/'.str_replace("\\","/",$image->getSaveName());
        }

        $newActivitysModel = new NewActivitysModel;
        if ($newActivitysModel->saveActivity($params)) {
            return $this->_success();
        }
        return $this->_error('保存失败');
    }

    // 活动文案删除
    public function delete() {
        $params = request()->post();
        $newActivitysModel = new NewActivitysModel;
        if ($newActivitysModel->deleteActivity($params)) {
            return $this->_success();
        }
        return $this->_error('删除失败');
    }

    // 活动类型列表
    public function typelist() {
        $adminModel = new AdminModel;
        $agent_list = $adminModel->getList1(999);
        $this->assign('agent_list', $agent_list['list']);
        return $this->fetch();
    }
    
    public function getTypeList() {
        $params = request()->param();
        $newActivitysModel = new NewActivitysModel;
        $result = $newActivitysModel->getActivityTypeList($params['limit']);
		return ['code' => 0, 'count' => $result['total'], 'data' => $result['data'], 'msg' => 'ok'];
    }

    // 删除活动类型
    public function deleteType() {
        $params = request()->post();
        $newActivitysModel = new NewActivitysModel;
        if ($newActivitysModel->deleteActivityType($params)) {
            return $this->_success();
        }
        return $this->_error('删除失败');
    }

    // 编辑活动类型
    public function editType() {
        $params = request()->param();
        $newActivitysModel = new NewActivitysModel;
        $activityTypeList = $newActivitysModel->getActivityTypeList(0,$params['id']);
        $activityTypeInfo = $newActivitysModel->getActivityTypeInfo($activityTypeList['infomation_templet']);
        $this->assign('params',$params);
        $this->assign('activityTypeList',$activityTypeList);
        $this->assign('activityTypeInfo',$activityTypeInfo);
        return $this->fetch();
    }

    // 保存活动类型数据 
    public function saveActivityType() {

        $params = request()->post();
        $son_operate = 'update';

        // 公共验证类型
        if (!isset($params['id']) && empty($params['id'])) {return $this->_error('参数错误！');}
        if (!isset($params['tem']) && empty($params['tem'])) {return $this->_error('参数错误！');}
        if (!isset($params['begin_time']) && empty($params['begin_time'])) {return $this->_error('请选择开始时间');}
        if (!isset($params['end_time']) && empty($params['end_time'])) {return $this->_error('请选择结束时间');}
        if (!isset($params['win_statement_amount']) && empty($params['win_statement_amount'])) {return $this->_error('请输入彩金流水');}
        if(intval($params['win_statement_amount']) < 0) {return $this->_error('彩金流水不能小于0！');}
        if ($params['begin_time'] > $params['end_time']) {return $this->_error('开始时间不能大于结束时间');}

        // 不同类型验证不同规则 -- 子数据先不做验证
        if ($params['tem'] == 'activity_infomation_dayreward') {
            if (!isset($params['minimum_recharge_amount']) && empty($params['minimum_recharge_amount'])) {return $this->_error('请输入最低充值金额');}
            if(intval($params['win_statement_amount']) < 0) {return $this->_error('最低充值金额不能小于0！');}
        }

        if ($params['tem'] == 'activity_infomation_invite') {
            if (!isset($params['minimum_recharge_amount']) && empty($params['minimum_recharge_amount'])) {return $this->_error('请输入最低充值金额');}
            if(intval($params['win_statement_amount']) < 0) {return $this->_error('最低充值金额不能小于0！');}
            // 每日领奖 子数据 更新操作
            $son_operate = 'delete';
        }

        if ($params['tem'] == 'activity_infomation_firstcharge') {
            // 每日领奖 子数据 更新操作
            $son_operate = 'delete';
        }

        if ($params['tem'] == 'activity_infomation_daycharge') {
            // 每日领奖 子数据 更新操作
            $son_operate = 'delete';
        }

        if ($params['tem'] == 'activity_infomation_authreward') {
            if (!isset($params['minimum_recharge_amount']) && empty($params['minimum_recharge_amount'])) {return $this->_error('请输入奖励金额');}
            if(intval($params['win_statement_amount']) < 0) {return $this->_error('奖励金额不能小于0！');}
        }

        $newActivitysModel = new NewActivitysModel;
        if ($newActivitysModel->saveActivityType($params, $son_operate)) {
            return $this->_success();
        }
        return $this->_error('更新失败');

    }
}
