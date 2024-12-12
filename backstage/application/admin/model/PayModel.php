<?php
namespace app\admin\model;
use think\Model;
use think\Db;
use think\facade\Cookie;
use think\facade\Config;
use app\admin\model\ConfigModel;

class PayModel extends Model {
	public static function getPayCashList($params, $postParams = []) {
        $field = ['gc_user.nickname','pl.uid','pl.fee','pl.payscale','ue.order_number','ue.id','ue.bank_number','ue.real_name','ue.money','ue.created_at'];
        $sql = Db::table('ym_manage.paylog pl')->field($field)
                ->join('ym_manage.user_exchange ue','pl.osn = ue.order_number')
                ->join('gameaccount.newuseraccounts gc_user','pl.uid = gc_user.Id')
                ->where([
                    ['pl.type','=', $params['type']],
                    ['pl.status','=',$params['status']]
                ]);
        // 条件筛选
        if (!empty($postParams['value'])) {
            $sql->where('ue.id|gc_user.nickname|ue.order_number|ue.bank_number|ue.real_name','like',"%{$postParams['value']}%");
        }
        if (!empty($postParams['searchtime'])) {
            $timeInfo = explode('~',$postParams['searchtime']);
            $sql->where('ue.created_at',['>=', $timeInfo[0]],['<=', $timeInfo[1], 'AND']);
        }

        // 排序规则
        $sql->order('ue.created_at','desc');
        
        // echo $sql->buildSql();
        return $sql->select();
    }
}