<?php
namespace app\admin\model;
use think\Model;
use think\Db;
use think\facade\Cookie;
use think\facade\Config;

class MarkModel extends Model
{
    public function getPlayerLog($num = 10 , $map = []){

        $dbobj = Db::table('gameaccount.mark')->alias('a')
            ->leftJoin('gameaccount.newuseraccounts u','u.Id=a.userId')
			->leftJoin('ym_manage.game g', 'g.gameid = a.gameId AND g.port = a.serverId');
            //->leftJoin("(select gameid,server,name,port from ym_manage.game) as g",'g.gameid=a.gameId AND g.port=a.serverId');
        $dbobj->field(['a.*' , 'u.Account as nickname' , 'g.name as game_name']);
        $this->addMap($map , $dbobj);
        $dbobj = $dbobj->order('a.id desc');
//        $dbobj->where('a.userId' , '>=' , 11000);
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
			->leftJoin('ym_manage.game g', 'g.gameid = a.gameId AND g.port = a.serverId');
            //->leftJoin("(select gameid,server,name from ym_manage.game group by gameid) as g",'g.gameid=a.gameId');
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
    }

    public static function gameTransferMoneyLog($page = 1, $limit = 30, $begin_time = 0, $end_time = 0, $state = 99, $searchstr = '', $type = 0) {
        $where = [];
        $where[] = ['e.type','=',1];
        if (!empty($begin_time)) {
            $where[] = ['e.timeStamp','>=',$begin_time];
        }
        if (!empty($end_time)) {
            $where[] = ['e.timeStamp','<=',$end_time];
        }
        if ($state != 99) {
            $where[] = ['scl.state','=',$state];
        }
        if (!empty($searchstr)) {
            $where[] = ['na.Id|na.Account|nas.Id|nas.Account','like',"%{$searchstr}%"];
        }

        $rs = Db::table('gameaccount.email e')->field('e.otherId, e.userid, e.sendid, e.timeStamp, scl.sendcoin, scl.nickname, scl.commission, scl.state, na.nickname othernickname')
                ->join('gameaccount.sendcoinlog scl','e.otherId = scl.id')
                ->join('gameaccount.newuseraccounts na', 'scl.userid = na.Id')
                ->join('gameaccount.newuseraccounts nas', 'scl.getcoinuserid = nas.Id')
                ->where($where)
                //->where('scl.type',$type)
                ->order('e.timeStamp','desc')->paginate($limit)->toArray();
        return $rs;
    }
}