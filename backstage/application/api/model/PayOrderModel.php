<?php
namespace app\api\model;

use think\Model;
use think\Db;
use think\facade\Config;

class PayOrderModel extends Model
{

    public function getInfo($where, $field = "*")
    {
        return Db::table('ym_manage.order_record_detail')
            ->field($field)
            ->where($where)
            ->find();
    }

    public function getOrder($order_id)
    {
        return Db::table('ym_manage.order_record_detail')
            ->where("order_id", "=", $order_id)
            ->field(["order_id", "notify_url", "uid", "product_id", "mer_order_no", "order_status"])
            ->find();
    }

    public function addPayOrder($params)
    {
        try {
            Db::table('ym_manage.order_record_detail')->insert($params);
            $this->query("set autocommit=1");
            return true;
        } catch (exception $e) {
            return false;
        }
    }

    public function updateOrder($params)
    {
        try {
            $ret = Db::table('ym_manage.order_record_detail')
                ->where("order_id", "=", $params["order_id"])
                ->field(["order_id"])
                ->find();
            if ($ret) {
                $dbobj = Db::table('ym_manage.order_record_detail')
                    ->where("order_id", "=", $params["order_id"])
                    ->update($params);
                $this->query("set autocommit=1");
            }
            return true;
        } catch (exception $e) {
            return false;
        }
    }


}

?>
