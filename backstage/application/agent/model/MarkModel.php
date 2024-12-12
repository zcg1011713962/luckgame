<?php
namespace app\agent\model;
use think\Model;
use think\Db;

class MarkModel extends Model
{
    public function getPlayerLog($num = 10 , $map = []){
        $dbobj = Db::table('gameaccount.mark')->alias('a')
            ->leftJoin('gameaccount.newuseraccounts u','u.Id=a.userId')
            ->leftJoin("(select gameid,server,name from ym_manage.game group by gameid,server,name) as g",'g.gameid=a.gameId')
            ->leftJoin('ym_manage.uidglaid u','u.uid=a.id');
            //->leftJoin("(select gameid,server,name from ym_manage.game group by gameid,server,name) as g",'g.gameid=a.gameId')
        $dbobj->field(['a.*' , 'u.Account as nickname' , 'g.name as game_name']);
        $this->addMap($map , $dbobj);
        $dbobj = $dbobj->order('a.id desc');
        $dbobj->where('a.userId' , '>=' , 11000);
        $dbobj = $dbobj->paginate($num);
        $list = $dbobj;

        $page = $list->render();

        return array(
            'list' => $list,
            'page' => $page
        );
    }

    public function getPlayerLogInfo($uid){

        $dbobj = Db::table('gameaccount.mark')->alias('a')
            ->leftJoin('gameaccount.newuseraccounts u','u.Id=a.userId')
            ->leftJoin("(select gameid,server,name,port from ym_manage.game) as g",'g.gameid=a.gameId AND g.port=a.serverId');
        $dbobj->field(['a.*' , 'u.Account as nickname' , 'g.name as game_name']);
        $dbobj = $dbobj->order('a.id desc');
        $dbobj->where('a.userId' , $uid);
        return $dbobj->select();
    }

    public function getPlayerCount($map = []){
        $dbobj = Db::table('gameaccount.mark')->alias('a')
            ->leftJoin('gameaccount.newuseraccounts u','u.Id=a.userId')
            ->leftJoin("(select gameid,server,name from ym_manage.game group by gameid,server,name) as g",'g.gameid=a.gameId')
            ->leftJoin('ym_manage.uidglaid u','u.uid=a.id');
        $dbobj->field(['a.*' , 'u.Account as nickname' , 'g.name as game_name']);
        $this->addMap($map , $dbobj);
        return $dbobj->where('a.userId' , '>=' , 11000)->count();
    }

    protected function addMap($map , &$dbobj){
        if (isset($map['id']) && $map['id']){
            $dbobj->where('a.id' , $map['id']);
        }
        if (isset($map['userId']) && $map['userId']){
            if (is_numeric($map['userId'])){
                $dbobj->where('a.userId' , $map['userId']);
            }else{
                $dbobj->whereLike('u.Account' , $map['userId']);
            }
        }
        if (isset($map['gameId']) && $map['gameId']){
            if (is_numeric($map['gameId'])){
                $dbobj->where('a.gameId' , $map['gameId']);
            }else{
                $dbobj->whereLike('g.name' , $map['gameId']);
            }
        }
        if (isset($map['time']) && $map['time']){
            list($start , $end) = explode(' ~ ' , $map['time']);
            $dbobj->whereBetween('a.balanceTime' , [$start , $end]);
        }
        if (isset($map['aid']) && $map['aid']){
            // 查询创建人为  我的子级和我自己的
            $dbobj->where('u.ChannelType' , 'in' , $map['aid']);
        }
    }

    public static function countTax($agent_id, $find_user_id = 15037, $begin_time = 0, $end_time = 0, $limit = 30) {

		// 获取游戏代理方式 ...
		$game_agent = Db::table('gameaccount.newuseraccounts')->field('Id as uid')->where('ChannelType',"{$agent_id}")->where('ChannelType','<>','abc')->where('ChannelType','>',0)->select();

		// 获取注册代理方式 ...
		$admin_agent = Db::table('ym_manage.uidglaid')->field('uid')->where('aid',"{$agent_id}")->select();

        // 合并代理用户 ...
		$user_list = array_merge($game_agent,$admin_agent);

        // 查询 mark.tax 
        //select * from mark where userId in (15078,15081) AND mark = 2 AND tax > 0
        $mark_tax_list = Db::table('gameaccount.mark m')
        ->where(['m.userId' => explode(',',implode(',',array_column($user_list,'uid','uid'))),])
        ->where('m.mark',2)->where('m.tax','>',0)
        ->leftjoin('gameaccount.newuseraccounts u', 'm.userId = u.Id')
        ->leftjoin('ym_manage.game g', 'g.gameid = m.gameId AND g.port = m.serverId')
        ->field(['m.*','u.nickname','g.name']);

        // 数据统计，数组克隆
        $mark_tax_count = $mark_tax_list->select();

        if ($find_user_id > 0) {
            $mark_tax_list->where('m.userId', $find_user_id);
        }

        if ($begin_time > 0 && $end_time > 0) {
            $mark_tax_list->where('m.balanceTime','between',[$begin_time, $end_time]);
        }

        $user_tax_total = [];
        $tax_total = 0;
        foreach ($mark_tax_count as $k => $v) {

            if (empty($user_tax_total[$v['userId']])) {
                $user_tax_total[$v['userId']] = [];
                $user_tax_total[$v['userId']]['userId'] = $v['userId'];
                $user_tax_total[$v['userId']]['total_tax'] = 0;
            }

            $tax_total += $v['tax'];
            $user_tax_total[$v['userId']]['total_tax'] += $v['tax'];
        }

        $res = $mark_tax_list->paginate($limit)->toArray();

        return ['code' => 0, 'count' => $res['total'], 'data' => $res['data'], 'user_tax_total' => $user_tax_total, 'tax_total' => $tax_total, 'msg' => 'ok'];

	}
}
