<?php
namespace app\api\controller;

use app\api\controller\Init;
use app\api\controller\Curl;
use think\Request;
use think\Db;
use app\api\model\ActivityModel;
use app\api\model\GameModel;

class Index extends Init
{
	/**
	 * index
	 */
	public function index(){
		echo 'api/index/index';
	}

	public function getActivity() {
		$result = Db::table('ym_manage.activitys')->field('id,title')->order('id' , 'desc')->select();
		return $this->returnSuccess1($result);
	}

	public function getNewAcitity() {
		$result = Db::table('ym_manage.activity a')
					->join('ym_manage.activity_type at','a.type = at.id')
					->group('a.type')
					->order('a.sort','desc')
					->field('a.id, at.name as type, a.name, at.id as type_id')
					->select();
		return $this->returnSuccess1($result);
	}

	public function getActivityInfo() {
		$action = request()->param('action');
		$activityTablePreFix = 'activity_infomation_';
		try {
			return  $this->returnSuccess1(Db::table('ym_manage.'.$activityTablePreFix.$action)->select());
		} catch(\Exception $e) {
			return $this->returnError1();
		}
	}

	public function paymentList() {
		$id = request()->post('id');
		$result = Db::table('ym_manage.paylog')
				->where('type',3)
				->where('uid', $id)
				->order('createtime','desc')
				->select();
		return $this->returnSuccess1($result);
	}

	public function outPaymentList() {
		$id = request()->post('id');
		$result = Db::table('ym_manage.user_exchange')
				->where('user_id',$id)
				->order('created_at','desc')
				->select();
		return $this->returnSuccess1($result);
	}

	public function payLog() {
		$id = request()->post('id');
		$result = Db::table('ym_manage.paylog pay')
					->join('gameaccount.score_changelog sc', 'pay.osn = sc.pay_sn')
					->where('pay.type','in','3,99')
					->where('pay.uid', $id)
					->order('pay.paytime','desc')
					->field("pay.uid, FROM_UNIXTIME(paytime) paytime, pay.fee, sc.score_current, (CASE pay.type WHEN 3 THEN 'recharge' WHEN 99 THEN 'withdraw' ELSE '' END) typename")
					->select();
		return $this->returnSuccess1($result);
	}

	public function getPlayerSerial() {
		$id = request()->post('id');
		$result = Db::table('gameaccount.mark')->where('userId',$id)->field('SUM(winCoin) winCoin, SUM(useCoin) useCoin')->find();
		if ($result['useCoin'] >= 500) {
			return $this->returnSuccess1($result);
		} else {
			return $this->returnError1('Still need 500.00 turnover to withdraw');
		}
	}

	public function activityAmount() {

		$user_id = request()->post('user_id');
		$amount  = request()->post('amount');

		$gameModel = new GameModel();
		$activityModel = new ActivityModel();

		$num = Db::table('ym_manage.paylog')->where('status',1)->where('uid',$user_id)->where('type',8)->where('paytime','BETWEEN',[strtotime(date('Y-m-d')), strtotime(date('Y-m-d')) + 86399])->field('COUNT(1) cot')['cot'];
		if ($num > 0) {
			return $this->returnError1('今日已签到');
		}

		$order = $activityModel->getPayMentActivityOrder($user_id,1);
		$activityModel->payMentLog($user_id, $amount, $order, 8);
		$gameModel->editNicePayLog([
			'amount' => $amount,
			'order' => $order
		],$user_id);
		return $this->returnSuccess1();
	}
	
}
