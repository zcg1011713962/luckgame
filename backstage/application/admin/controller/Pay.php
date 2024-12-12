<?php
namespace app\admin\controller;
use think\Controller;
use think\Db;
use think\facade\Request;
use app\admin\controller\Parents;
use app\admin\model\PayModel;

class Pay extends Parents {
    public function CashSuccessList() {
        $params = request()->param();
        $postParams = request()->post();
        $payCashList = PayModel::getPayCashList($params, $postParams);
        $this->assign('postParams',$postParams);
        $this->assign('payCashList',$payCashList);
        return $this->fetch();
    }
}
