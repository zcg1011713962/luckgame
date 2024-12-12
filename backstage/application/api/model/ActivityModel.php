<?php
namespace app\api\model;
use think\Model;
use think\Db;
use think\facade\Config;
use app\admin\model\ConfigModel;

class ActivityModel extends Model {

    // 计算充值活动奖金赠送
    // return money
    public function payMentActivitySend($user_id, $activity_id, $fee) {

        $amount = 0;

        if($activity_id == 3) {
            // 检查 是否第一次充值
            $num = Db::table('ym_manage.paylog')->where('status',1)->where('uid',$user_id)->where('type',3)->field('COUNT(1) cot')['cot'];
            if ($num-1 > 0) {
                return $amount;
            }
        }

        if ($activity_id == 4) {
            // 检查 当日是否充值
            $num = Db::table('ym_manage.paylog')->where('status',1)->where('uid',$user_id)->where('type',3)->where('paytime','BETWEEN',[strtotime(date('Y-m-d')), strtotime(date('Y-m-d')) + 86399])->field('COUNT(1) cot')['cot'];
            if ($num-1 > 0) {
                return $amount;
            }
        }

        $activity_templet = Db::table('ym_manage.activity_type')->where('id',$activity_id)->where('status',0)->find();
        if (empty($activity_templet)) {
            return $amount;
        }
        $activity_info = Db::table('ym_manage.'. $activity_templet['infomation_templet'])->select();
        $value = 0;
        foreach ($activity_info as $k => $v) {
            if ($fee >= $v['min'] && $fee <= $v['max']) {
                $value = $v['value'];
            }
        }

        if ($value == 0) {
            return $amount;
        }

        if ($activity_id == 4) {
            $amount = $fee * 1 * intval($value / 100);
        } else {
            $amount = $value;
        }

        return $amount;
    }

    // 充值单号
    public function getPayMentActivityOrder($user_id, $activity_id) {
        if ($activity_id == 1) {
            $strType = 'MRLJ';
        }
        if ($activity_id == 2) {
            $strType = 'YQJJ';
        }
        if ($activity_id == 3) {
            $strType = 'SCSZ';
        }
        if ($activity_id == 4) {
            $strType = 'MRSC';
        }
        if ($activity_id == 5) {
            $strType = 'RZJL';
        }
        return $strType.'_'.$user_id.'_'.date('Ymd').str_pad(mt_rand(1, 999999), 5, '0', STR_PAD_LEFT).$activity_id;
    }

    // 充值记录
    public function payMentLog($user_id, $amount, $order, $type) {

        $insert = array(
            'uid' => $user_id,
            'fee' => $amount,
            'type' => $type,
            'osn' => $order,
            'createtime' => time(),
            'paytime' => time(),
            'status' => 1,
            'payresmsg' => '',
            'prepayresmsg' => '',
            'payendtime' => time(),
            'payscale' => 0
        );

        Db::table('ym_manage.paylog')->insert($insert);
    }
}