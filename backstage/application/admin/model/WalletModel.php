<?php
namespace app\admin\model;

use think\Model;
use think\Db;
use think\facade\Cookie;
use think\Log;

class WalletModel extends Model
{

    protected $table = "withdraw_record";

    public function __construct()
    {
        parent::__construct();
    }

    public function getRechargeList($limit = 30, $params = [])
    {
        $dbobj = Db::table('gameaccount.pay_order')->alias('a')
            ->field(['a.*', 'u.Account as account, u.nickname as nickname'])
            ->leftJoin("gameaccount.newuseraccounts u", 'u.Id=a.userId');
        $this->addMap($params, $dbobj);
        $dbobj->order('a.id desc');
        $dbobj = $dbobj->paginate($limit)->toArray();
        return $dbobj;
    }

    public function getRechargeStatistics($params = [])
    {
        $dbobj = Db::table('gameaccount.pay_order')->alias('a')
            ->field(["count(1) as total", "sum(amount) as amount"])
            ->leftJoin("gameaccount.newuseraccounts u", 'u.Id=a.userId');
        $this->addMap($params, $dbobj);
        return $dbobj->find();
    }

    public function getWithdrawList($limit = 30, $params = [])
    {
        $dbobj = Db::table('gameaccount.withdraw_record')->alias('a')
            ->leftJoin("gameaccount.newuseraccounts u", 'u.Id=a.userId');
        //			->where('a.userId',">=","11000");
        $dbobj->field(['a.*', 'u.Account as nickname']);
        $this->addMap($params, $dbobj);
        $dbobj->order('a.id desc');
        $dbobj = $dbobj->paginate($limit)->toArray();
        return $dbobj;
    }

    public function getWithdrawStatistics($params = [])
    {
        $dbobj = Db::table('gameaccount.withdraw_record')->alias('a')
            //                    ->where("userId",">=","11000")
            ->field(["count(1) as total", "sum(amount) as amount"])
            ->leftJoin("gameaccount.newuseraccounts u", 'u.Id=a.userId');
        $this->addMap($params, $dbobj);
        return $dbobj->find();

    }

    public function updateWithdrawOrder($id, $record)
    {
        return Db::table('gameaccount.withdraw_record')
            ->where('id', '=', $id)
            ->update($record);
    }

    public function getWithdrawInfo($id)
    {
        return Db::table('gameaccount.withdraw_record')
            ->where('id', '=', $id)
            ->field(['*'])
            ->find();
    }

    public function getPayInfo($where, $field = "*")
    {
        return Db::table('gameaccount.withdraw_record')
            ->alias('a')
            ->field($field)
            ->join('ym_manage.order_record_detail b', 'a.orderId = b.mer_order_no')
            ->where($where)
            ->find();
    }

    protected function addMap($map, &$dbobj)
    {
        if (isset($map["id"]) && $map['id']) {
            $dbobj->where('a.id', $map['id']);
        }
        if (isset($map["userId"]) && $map["userId"]) {
            if (is_numeric($map["userId"])) {
                $dbobj->where("a.userId", $map['userId']);
            } else {
                $dbobj->whereLike('u.Account', $map["userId"]);
            }

        }
        if (isset($map['status'])) {
            $dbobj->whereIn('a.status', $map['status']);
        }
        if (isset($map["pay_status"]) && is_numeric($map["pay_status"])) {
            $dbobj->where('a.pay_status', $map["pay_status"]);
        }
        if (isset($map['time']) && $map['time']) {
            list($start, $end) = explode(' ~ ', $map['time']);
            $dbobj->whereBetween('a.create_time', [$start, $end]);
        }

    }
}

?>
