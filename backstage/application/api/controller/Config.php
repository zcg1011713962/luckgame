<?php
namespace app\api\controller;
use think\Db;
use think\Controller;
use think\facade\Cache;
use app\api\controller\Init;
use think\facade\Request;
use app\admin\model\ConfigModel;

class Config extends Init {
   
    public function getIcon() {
        $iconList = json_decode(ConfigModel::getIcon(),true);
        return $this->returnSuccess($iconList);
    }

    public function getPaymentScale() {
        $paymentScale = configModel::getPayScale();
        return $this->returnSuccess($paymentScale);
    }
	
	public function getPayChannel() {
		$payChannel = Db::table('ym_manage.config')->where('name','WithdrawalChannel')->find();
		return $this->returnSuccess($payChannel);
	}
	
	public function getTreasureBox() {
		$beginTime = strtotime(date('Y-m-d'));
		$endTime = $beginTime + 86399;
		$userId = intval(input('get.id'));
		if (empty($userId)) {
			return $this->returnError('UserId cannot be empty.');
		}
		$userList = Db::table('gameaccount.newuseraccounts')->where('ChannelType', $userId)->column('id');
		if (count($userList) == 0) {
			return $this->returnSuccess([
				'TreasureBoxNum' => 0
			]);
		}
		$payTotal = Db::table('ym_manage.paylog')->where([
			'status' => 2,
			'type' => 3
		])->where('uid','in',$userList)->whereTime('paytime','between', [$beginTime, $endTime])->sum('fee');
		
		$TreasureBoxPrice = Db::table('ym_manage.system_treasure_box')->value('recharge_money');
		
		return $this->returnSuccess([
			'TreasureBoxNum' => intval($payTotal / $TreasureBoxPrice)
		]);
		die;
	}
	
	
	public function addTreasureBoxGold() {
		
		$beginTime = strtotime(date('Y-m-d'));
		$endTime = $beginTime + 86399;
		
		if (!empty(Cache::store('redis')->get($endTime))) {
			return $this->returnError('Do not repeatedly call data');
		}
		
		$sql = "SELECT
					T1.uid,
					u.id,
					T1.total,
					u.ChannelType,
					SUM(T1.total) AS count_price
				FROM
					(
						SELECT
							pl.uid,
							sum(pl.fee) AS total
						FROM
							ym_manage.paylog pl
						WHERE pl.paytime >= {$beginTime} AND pl.paytime <= {$endTime} AND pl.type = 3 AND pl.`status` = 2
						GROUP BY
							uid
					) T1
				INNER JOIN gameaccount.newuseraccounts AS u ON T1.uid = u.Id
				WHERE
					u.ChannelType <> 1
				AND u.ChannelType <> 'abc'
				AND u.ChannelType IS NOT NULL
				GROUP BY u.ChannelType ";
		$res = Db::query($sql);
		
		$TreasureBoxInfo = Db::table('ym_manage.system_treasure_box')->field('box_money,recharge_money')->find();
		
		foreach ($res as $k => $v) {
			$res[$k]['addGold'] = intval($v['count_price'] / $TreasureBoxInfo['recharge_money']) * $TreasureBoxInfo['box_money'];
		}
		Cache::store('redis')->set($endTime,1);
		return $this->returnSuccess($res);
	}
}