<?php
namespace app\admin\model;
use think\Model;
use think\Db;
use think\facade\Cookie;
use think\facade\Config;

class UserExchangeModel extends Model
{
    public $table = 'user_exchange';
    public function getExchangeLog($num = 10 , $map = []){
        $dbobj = Db::table('ym_manage.user_exchange')->alias('a')
            ->leftJoin('gameaccount.newuseraccounts u','u.Id=a.user_id')
            ->leftJoin('ym_manage.admin d','d.id=a.created_uid');
        $dbobj->field(['a.*' , 'u.Account as nickname' , 'd.username as admin_username']);
        $this->addMap($map , $dbobj);
        $dbobj = $dbobj->order('a.id desc');
//        $dbobj->where('a.user_id' , '>=' , 11000);
        $dbobj = $dbobj->paginate($num);
        $list = $dbobj;
        $page = $list->render();

        return array(
            'list' => $list,
            'page' => $page
        );
    }

    public function getExchangeCount($map = []){
        $dbobj = Db::table('ym_manage.user_exchange')->alias('a')
            ->leftJoin('gameaccount.newuseraccounts u','u.Id=a.user_id');
        $dbobj->field(['a.*' , 'u.Account as nickname']);
        $this->addMap($map , $dbobj);
        return $dbobj->count();
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
        if (isset($map['status']) && is_numeric($map['status'])){
            $dbobj->where('a.status' , $map['status']);
        }
        if (isset($map['time']) && $map['time']){
            list($start , $end) = explode(' ~ ' , $map['time']);
            $dbobj->whereBetween('a.balanceTime' , [$start , $end]);
        }
    }
}
