<?php
namespace app\admin\controller;
use app\admin\model\MarkModel;
class PlayerGameLog extends Parents
{
    public function lists($type = 1 , $game_id = 0)
    {
        $user = new MarkModel();
		$num = 20;//每页显示数
        $map = input('map' , []);
        if ($game_id > 0){
            $map['gameId'] = $game_id;
        }
        $map = array_filter($map);
        if (!isset($_GET['page'])){
            session('mark_search_param' , null);
        }
        if ($_POST){
            session('mark_search_param' , $map);
        }else{
            $map = $map ? $map : session('mark_search_param');
        }
        $res = $user->getPlayerLog($num , $map);
        $this->assign('list',$res['list']);
        $this->assign('page',$res['page']);
        $count = $user->getPlayerCount($map);
        $this->assign('count',$count);
        $this->assign('map',$map);
        $this->assign('type',$type);

		return $this->fetch();
    }

    public function getUserInfo()
    {
        $uid = request()->param('uid');
        $user = new MarkModel();
        $res = $user->getPlayerLogInfo($uid);
        $this->assign('list',$res);
		return $this->fetch();
    }

    public function gametransfermoneyloglist() {
        $params = request()->param();
        $this->assign('state',[0 => '未领', 1 => '已收到']);
        return $this->fetch();
    }

    public function getgametransfermoneyloglist() {
        $params = request()->param();
        $begin_time = !empty($params['begin_time']) ? $params['begin_time'] : '';
        $end_time = !empty($params['end_time']) ? $params['end_time'] : '';
        $type = isset($params['type']) ? intval($params['type']) : 0;
        $state = isset($params['state']) ? $params['state'] : 99;
        $searchstr = !empty($params['searchstr']) ? $params['searchstr'] : '';
        $list = MarkModel::gameTransferMoneyLog($params['page'], $params['limit'], $begin_time, $end_time, $state, $searchstr, $type);
        return ['code' => 0, 'count' => $list['total'], 'data' => $list['data'], 'msg' => 'ok'];
    }
}
