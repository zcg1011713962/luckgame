<?php
namespace app\agent\controller;
use app\agent\model\MarkModel;
use app\agent\model\AdminModel;

class PlayerGameLog extends Parents
{
    public function lists($type = 1)
    {
        $user = new MarkModel();
		$num = 20;//每页显示数
        $map = input('map' , []);
        $map = array_filter($map);
        if (!isset($_GET['page'])){
            session('mark_search_param' , null);
        }
        if ($_POST){
            session('mark_search_param' , $map);
        }else{
            $map = session('mark_search_param');
        }
        $model = new AdminModel();
        //上级代理
        $a1 = $model->getAgId();
        $a23 = $model->get3ji_ids();
        $agents_ids = trim($a1.','.$a23, ',');
        $map['aid'] = $agents_ids;
        $res = $user->getPlayerLog($num , $map);
        $this->assign('list',$res['list']);
        $this->assign('page',$res['page']);
        $count = $user->getPlayerCount($map);
        $this->assign('count',$count);
        $this->assign('map',$map);
        $this->assign('type',$type);

		return $this->fetch();
    }

    public function getUserInfo() {
        $uid = request()->param('uid');
        $user = new MarkModel();
        $res = $user->getPlayerLogInfo($uid);
        $this->assign('list',$res);
		return $this->fetch();
    }

    public function tax_list() {
        return $this->fetch();
    }
}
