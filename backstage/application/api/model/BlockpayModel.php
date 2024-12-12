<?php
namespace app\api\model;
use think\Model;
use think\Db;
use think\facade\Config;

class BlockpayModel extends Model {

    public function addPayLog($uid, $params) {
        Db::table('ym_manage.paylog')->insert([
            'uid' => $uid,
            'fee' => $params['amount'],
            'osn' => $params['hash'],
            'osnjz' => $params['accept_address'],
            'createtime' => time(),
            'paytime' => time(),
            'status' => 1,
            'payresmsg' => json_encode($params),
            'prepayresmsg' => $params['pay_address']
        ]); 
    }

    public function searchUser($key,$hash) {
        return Db::table('gameaccount.newuseraccounts')->field('Id,Account')->where([
            $key => $hash
        ])->find();
    }

    public function searchPaymentLog($uid) {
        return Db::table('ym_manage.paylog pl')->field('pl.fee,gn.Id,gn.Account,gn.nickname,FROM_UNIXTIME(pl.paytime) paytimeformat, pl.osn')
                ->join('gameaccount.newuseraccounts gn', 'pl.uid = gn.Id')
                ->where('pl.uid',$uid)
                ->order('paytime','desc')
                ->select();
    }

    public function insertUserExchange($data) {
        return Db::table('ym_manage.user_exchange')->strict(false)->insert($data);
    }
} 