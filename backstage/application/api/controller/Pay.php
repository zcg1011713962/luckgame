<?php
namespace app\api\controller;
use app\api\controller\Init;
use app\api\controller\Curl;
use think\facade\Request;
use app\api\model\UserModel;
use app\api\model\EncnumModel;
use app\api\model\GameModel;
use think\facade\Config;
use app\api\utils\nutspayUtils;
use app\api\utils\wowpayUtils;
use app\admin\model\ConfigModel;
use think\Db;
use app\api\model\BlockpayModel;
use app\api\model\ActivityModel;

class Pay extends Init
{
	private $payScale;
	// 初始化支付/提现比例
	public function __construct() {
		$this->payScale = ConfigModel::getPayScale();
	}

	public function paymentList() {
		$list = Db::table('ym_manage.system_recharge_gift')->order('recharge_money','asc')->limit(8)->select();
		return $this->returnSuccess($list);
	}

	public function kppay() {
		// 请求
		$params = Request::param();
		// 回调
		$notify_params = Request::post();

		$userModel = new UserModel();
		$gameModel = new GameModel();

		// 请求
		if (empty($notify_params)) {
			// 需提交的数据
			$postData = [];
			// 代收
			if ($params['payType'] == 'payment') {
				$postData['merchantId'] = Config::get('fastpay.kppay.merchantId');
				$postData['channelId'] = 'QGB';
				$postData['amount'] = (floatval($params['amount'])*100/100).'.00';
				$postData['orderNo'] = 'KPPAY'.$params['uid'].date('YmdHis').str_pad(mt_rand(1, 999999), 5, '0', STR_PAD_LEFT);
				$postData['email'] = $params['payemail'];
				$postData['name'] = $params['payname'];
				$postData['mobile'] = $params['payphone'];
				$postData['payType'] = 'PIX';
				$postData['payNumber'] = $params['paynumber'];
				$postData['notifyUrl'] = Config::get('fastpay.kppay.notifyUrl').'?act=payment';
				$postData['returnUrl'] = Config::get('fastpay.kppay.notifyUrl').'?act=payment';
				$postData['sign'] = strtoupper(wowpayUtils::sign(wowpayUtils::ASCII($postData),Config::get('fastpay.kppay.key')));
				$headers = array();
				$headers[]= 'Content-Type: '. 'application/json;charset=UTF-8';
				$res = json_decode(nutspayUtils::httpsPost(Config::get('fastpay.kppay.payment_gateway'),json_encode($postData),$headers),true);
				if ($res['code'] == 1) {
					$insert = array(
						'uid' => $params['uid'],
						'fee' => $postData['amount'],
						'type' => 3,
						'osn' => $postData['orderNo'],
						'createtime' => time(),
						'paytime' => time(),
						'status' => 0,
						'payresmsg' => '',
						'prepayresmsg' => json_encode($res),
						'payendtime' => time(),
						'payscale' => $this->payScale['payment']
					);
					$gameModel->savePayLog($insert);
					return $this->returnSuccess($res);
				}
				return $this->returnError($res);
			}
			// 代付
			if ($params['payType'] == 'payout') {
				// $postData['merchantId'] = Config::get('fastpay.kppay.merchantId');
				// $postData['channelId'] = 'QGB';
				$postData['amount'] = (floatval($params['amount'])*100/100).'.00';
				$postData['orderNo'] = 'KPPAYOUT'.$params['uid'].date('YmdHis').str_pad(mt_rand(1, 999999), 5, '0', STR_PAD_LEFT);
				$postData['email'] = $params['payemail'];
				$postData['name'] = $params['payname'];
				$postData['mobile'] = $params['payphone'];
				$postData['payType'] = 'PIX_PHONE';
				$postData['cardNumber'] = $params['acc_code'];
				// $postData['notifyUrl'] = Config::get('fastpay.kppay.notifyUrl').'?act=payout';
				// $postData['sign'] = strtoupper(wowpayUtils::sign(wowpayUtils::ASCII($postData),Config::get('fastpay.kppay.key')));
				// $headers = array();
				// $headers[]= 'Content-Type: '. 'application/json;charset=UTF-8';
				// $res = json_decode(nutspayUtils::httpsPost(Config::get('fastpay.kppay.payout_gateway'),json_encode($postData),$headers),true);
				// if ($res['code'] == 1) {
				// $insert = array(
				// 	'uid' => $params['uid'],
				// 	'fee' => $postData['amount'],
				// 	'type' => 99,
				// 	'osn' => $postData['orderNo'],
				// 	'createtime' => time(),
				// 	'paytime' => time(),
				// 	'status' => 0,
				// 	'payresmsg' => '',
				// 	'prepayresmsg' => json_encode($res),
				// 	'payendtime' => time(),
				// 	'payscale' => $this->payScale['payment']
				// );
				// $gameModel->savePayLog($insert);
				// 写入数据库 在游戏内减去对应金币 先注释掉，有需要在写入数据库
				Db::table('ym_manage.user_exchange')->insert([
					'user_id' => $params['uid'] ,
					'order_number' => $postData['orderNo'] ,
					'bank_number' => $postData['cardNumber'] ,
					'real_name' => $postData['name'] ,
					'bank_open' => $postData['payType'] ,
					'money' => $postData['amount'] * $this->payScale['cash'] ,
					'pay_type' => 'kppay',
					'email' => $postData['email'],
					'phone' => $postData['mobile'],
					'status' => 0 ,
					'created_at' => date('Y-m-d H:i:s'),
				]);
				return $this->returnSuccess('提现成功，请等待审核。');
				// }
				// return $this->returnError($res);
			}
		} else { // 回调
			// 代收回调
			if ($params['act'] == 'payment') {
				// 验签
				if ($notify_params['status'] == 1) {
					$notify_sign = strtoupper($notify_params['sign']);
					unset($notify_params['sign']);
					$sign = strtoupper(wowpayUtils::sign(wowpayUtils::ASCII($notify_params),Config::get('fastpay.kppay.key')));
					$info = $userModel->getNutsPayOrderStatus($notify_params['merOrderNo']);
					if ($sign == $notify_sign) {
						if ($info && $info['status'] == 0) {
							$gameModel->editKpPayLog($notify_params,$info['uid']);
						}
					} else {
						if ($info && $info['callbacknum'] == 0) {
							$gameModel->editKpPayErrorLog($notify_params,$info['uid']);
						}
					}
					echo 'success';
				}
			}
			// 代付回调
			if ($params['act'] == 'payout') {
				// 验签
				$notify_sign = strtoupper($notify_params['sign']);
				unset($notify_params['sign']);
				$sign = strtoupper(wowpayUtils::sign(wowpayUtils::ASCII($notify_params),Config::get('fastpay.kppay.key')));
				if ($notify_sign == $sign) {
					$info = $userModel->getNutsPayOrderStatus($notify_params['merOrderNo']);
					if ($notify_params['status'] == 1) {
						if ($info && $info['status'] == 0) {
							$gameModel->editKpPayMoneyLog($notify_params,$info['uid']);
						}
						Db::table('ym_manage.user_exchange')->where('order_number', $notify_params['merOrderNo'])->update([
							'status' => 1,
							'updated_at' => date('Y-m-d H:i:s'),
						]);
					} else {
						if ($info && $info['callbacknum'] == 0) {
							$gameModel->editKpPayMoneyErrorLog($notify_params,$info['uid']);
						}
						Db::table('ym_manage.user_exchange')->where('order_number', $notify_params['merOrderNo'])->update([
							'status' => 2,
							'updated_at' => date('Y-m-d H:i:s'),
						]);
					}
				}
				echo 'success';
			}
		}
	}

	public function fastpay() {

		// 请求
		$params = Request::param();
		// 回调
		$notify_params = Request::post();

		$userModel = new UserModel();
		$gameModel = new GameModel();

		// 请求
		if (empty($notify_params)) {
			// 需提交的数据
			$postData = [];
			// 代收
			if ($params['payType'] == 'payment') {
				$postData['currency'] = Config::get('fastpay.fastpay.currency');
				$postData['mer_no'] = Config::get('fastpay.fastpay.mer_no');
				$postData['method'] = 'trade.create';
				$postData['order_amount'] = floatval($params['amount'])*100/100;
				$postData['order_no'] = 'FASTPAY'.$params['uid'].date('YmdHis').str_pad(mt_rand(1, 999999), 5, '0', STR_PAD_LEFT);
				$postData['payemail'] = $params['payemail'];
				$postData['payname'] = $params['payname'];
				$postData['payphone'] = $params['payphone'];
				$postData['paytypecode'] = Config::get('fastpay.fastpay.paytypecode');
				$postData['returnurl'] = Config::get('fastpay.fastpay.returnurl').'?act=payment';
				$postData['sign'] = wowpayUtils::signx(wowpayUtils::ASCII($postData),Config::get('fastpay.fastpay.key'));
				$headers = array();
				$headers[]= 'Content-Type: '. 'application/json;charset=UTF-8';
				$res = json_decode(nutspayUtils::httpsPost(Config::get('fastpay.fastpay.gateway'),json_encode($postData),$headers),true);
				if ($res['status'] == 'success' && $res['status_mes'] == 'success') {
					$insert = array(
						'uid' => $params['uid'],
						'fee' => $postData['order_amount'],
						'type' => 3,
						'osn' => $postData['order_no'],
						'createtime' => time(),
						'paytime' => time(),
						'status' => 0,
						'payresmsg' => '',
						'prepayresmsg' => json_encode($res),
						'payendtime' => time(),
						'payscale' => $this->payScale['payment']
					);
					$gameModel->savePayLog($insert);
					return $this->returnSuccess($res);
				}
				return $this->returnError($res);
			}
			// 代付
			if ($params['payType'] == 'payout') {
				$postData['acc_code'] = $params['acc_code'];
				$postData['acc_name'] = $params['acc_name'];
				$postData['acc_no'] = $params['acc_no'];
				// $postData['currency'] = Config::get('fastpay.fastpay.currency');
				// $postData['mer_no'] = Config::get('fastpay.fastpay.mer_no');
				// $postData['method'] = 'fund.apply';
				$postData['order_amount'] = floatval($params['amount'])*100/100;
				$postData['order_no'] = 'FASTPAYOUT'.$params['uid'].date('YmdHis').str_pad(mt_rand(1, 999999), 5, '0', STR_PAD_LEFT);
				// $postData['returnurl'] = Config::get('fastpay.fastpay.returnurl').'?act=payout';
				// $postData['sign'] = wowpayUtils::signx(wowpayUtils::ASCII($postData),Config::get('fastpay.fastpay.key'));
				// $headers = array();
				// $headers[]= 'Content-Type: '. 'application/json;charset=UTF-8';
				// $res = json_decode(nutspayUtils::httpsPost(Config::get('fastpay.fastpay.gateway'),json_encode($postData),$headers),true);
				// if ($res['status'] == 'success' && $res['status_mes'] == 'success') {
					// 写入支付日志
				// $insert = array(
				// 	'uid' => $params['uid'],
				// 	'fee' => $postData['order_amount'],
				// 	'type' => 99,
				// 	'osn' => $postData['order_no'],
				// 	'createtime' => time(),
				// 	'paytime' => 0,
				// 	'status' => 0,
				// 	'payresmsg' => '',
				// 	'prepayresmsg' => json_encode($res),
				// 	'payendtime' => time(),
				// 	'payscale' => $this->payScale['cash']
				// );
				// $gameModel->savePayLog($insert);
				// 写入数据库 在游戏内减去对应金币 先注释掉，有需要在写入数据库
				Db::table('ym_manage.user_exchange')->insert([
					'user_id' => $params['uid'] ,
					'order_number' => $postData['order_no'] ,
					'bank_number' => $postData['acc_no'] ,
					'real_name' => $postData['acc_name'] ,
					'bank_open' => $postData['acc_code'] ,
					'money' => $postData['order_amount'] * $this->payScale['cash'] ,
					'pay_type' => 'fastpay',
					'status' => 0 ,
					'created_at' => date('Y-m-d H:i:s'),
				]);
				return $this->returnSuccess('提现成功，请等待审核。');
				// }
				// return $this->returnError($res);
			}
		} else { // 回调
			// 代收回调
			if ($params['act'] == 'payment') {
				// 验签
				if ($notify_params['status'] == 'success') {
					$notify_sign = $notify_params['sign'];
					unset($notify_params['sign']);
					$sign = wowpayUtils::signx(wowpayUtils::ASCII($notify_params),Config::get('fastpay.fastpay.key'));
					$info = $userModel->getNutsPayOrderStatus($notify_params['order_no']);
					if ($sign == $notify_sign) {
						if ($info && $info['status'] == 0) {
							$gameModel->editWowPayLog($notify_params,$info['uid']);
						}
					} else {
						if ($info && $info['callbacknum'] == 0) {
							$gameModel->editWowPayErrorLog($notify_params,$info['uid']);
						}
					}
				}
			}
			// 代付回调
			if ($params['act'] == 'payout') {
				// 验签
				$info = $userModel->getNutsPayOrderStatus($notify_params['order_no']);
				if ($notify_params['result'] == 'success') {
					$notify_sign = $notify_params['sign'];
					unset($notify_params['sign']);
					$sign = wowpayUtils::signx(wowpayUtils::ASCII($notify_params),Config::get('fastpay.fastpay.key'));
					if ($sign == $notify_sign) {
						if ($info && $info['status'] == 0) {
							$gameModel->editWowPayMoneyLog($notify_params,$info['uid']);
						}
						Db::table('ym_manage.user_exchange')->where('order_number', $notify_params['order_no'])->update([
							'status' => 1,
							'updated_at' => date('Y-m-d H:i:s'),
						]);
					}
				} else {
					if ($info && $info['callbacknum'] == 0) {
						$gameModel->editWowPayMoneyErrorLog($notify_params,$info['uid']);
					}
					Db::table('ym_manage.user_exchange')->where('order_number', $notify_params['order_no'])->update([
						'status' => 2,
						'updated_at' => date('Y-m-d H:i:s'),
					]);
				}
			}
			echo 'ok';
		}
	}
	
	// nicePay 代收/代付回调
	public function nicepay_notify() {

		$params = Request::post();
		$type = request()->param('type');
		$user_id = request()->param('user_id');
		$card_number = request()->param('card_number');
		$real_name = request()->param('real_name');

		if (empty($params) || empty($type) || empty($user_id)) {
			echo 'Signature error';
			return;
		}

		//$params = json_decode($params,true);
		
		/*if ($params['status'] != 1) {
			echo 'status error';
			return;
		}*/

		$machPay = 'fc03025b3921acc20675fb43a5c5b651';
		$userModel = new UserModel();
		$gameModel = new GameModel();
		$activityModel = new ActivityModel();

		// 代收回调
		if ($type == 'payment') {
			// 验签
			$sign = md5($params['amount'].''.$params['order'].''.$params['status'].''.$machPay);
			if ($sign == $params['sign'] && $params['status'] == 1) {
				$info = $userModel->getNutsPayOrderStatus($params['order']);
				if (!$info) {
					// 保存日志
					$insert = array(
						'uid' => $user_id,
						'fee' => $params['amount'],
						'type' => 3,
						'osn' => $params['order'],
						'createtime' => time(),
						'paytime' => time(),
						'status' => 1,
						'payresmsg' => '',
						'prepayresmsg' => json_encode($params),
						'payendtime' => time(),
						'payscale' => $this->payScale['payment']
					);
					$gameModel->savePayLog($insert);
					// 增加金币
					$gameModel->editNicePayLog($params,$user_id);
					
					// 首充奖励赠送
					$amount = $activityModel->payMentActivitySend($user_id, 3, $params['amount']);
					if ($amount > 0) {
						$order = $activityModel->getPayMentActivityOrder($user_id,3);
						$activityModel->payMentLog($user_id, $amount, $order, 5);
						$params['amount'] = $amount;
						$params['order'] = $order;
						$gameModel->editNicePayLog($params,$user_id);
					}

					// 每日首充设置
					$amount = $activityModel->payMentActivitySend($user_id, 4, $params['amount']);
					if ($amount > 0) {
						$order = $activityModel->getPayMentActivityOrder($user_id,4);
						$activityModel->payMentLog($user_id, $amount, $order, 6);
						$params['amount'] = $amount;
						$params['order'] = $order;
						$gameModel->editNicePayLog($params,$user_id);
					}
				}
			}
		}

		// 代付回调
		if ($type == 'withdrawal') {
			// 验签
			$sign = md5($params['amount'].''.$params['order'].''.$params['status'].''.$machPay);
			if ($sign == $params['sign'] && $params['status'] == 1) {
				$info = $userModel->getNutsPayOrderStatus($params['order']);
				if (!$info) {
					// 保存日志
					$insert = array(
						'uid' => $user_id,
						'fee' => $params['amount'],
						'type' => 99,
						'osn' => $params['order'],
						'createtime' => time(),
						'paytime' => time(),
						'status' => 1,
						'payresmsg' => '',
						'prepayresmsg' => json_encode($params),
						'payendtime' => time(),
						'payscale' => $this->payScale['cash']
					);
					$gameModel->savePayLog($insert);

					// 写入代付日志
					$BlockPayModel = new BlockpayModel;
					$data = [];
					$data['order_number'] = $params['order'];
					$data['user_id'] = $user_id;
					$data['bank_number'] = $card_number;
					$data['money'] = $params['amount'];
					$data['created_at'] = date('Y-m-d H:i:s');
					$data['bank_open']  = $params['amount'] * $this->payScale['cash'];
					$data['status'] = 1;
					$BlockPayModel->insertUserExchange($data);
					
					// 更新代付单号
					$changeInfo = Db::table('gameaccount.score_changelog')
						->where('change_type',4)
						->where('userid', $user_id)
						->where('score_change','-'.$params['amount'])
						->order('change_time','desc')
						->field('id')
						->find();

					
					// 更新银行卡号
					$bankBindNum = Db::table('gameaccount.bankbindlist')->where('userId', $user_id)->field('COUNT(1) count')->find();
					if ($bankBindNum['count'] == 0) {
						Db::table('gameaccount.bankbindlist')->insert([
							'userId' => $user_id,
							'account' => $card_number,
							'name' => $real_name,
							'bankType' => 'bank',
						]);
					}

					if (isset($changeInfo['id'])) {
						Db::table('gameaccount.score_changelog')->update([
							'id' => $changeInfo['id'],
							'userid' => $user_id,
							'pay_sn' => $params['order']
						]);
					}
				}
			} else {
				// 增加金币
				$gameModel->editNicePayLog($params,$user_id);
			}
		}

		echo 'success';
		return;
	}

	// wowpay 代收
	public function lexmPay() {

		$get = Request::param();
		if (empty($get)) {
			return $this->returnError('Get Empty');
		}

		if (empty($get['uid']) || empty($get['amount'])) {
			return $this->returnError('Param Error');
		}

		$uid = $get['uid'];
		$trade_amount = floatval($get['amount'])*100/100;

		$usermodel = new UserModel();
		if(empty($usermodel->checkAccountUser($uid))){
			return $this->returnError('Uid Error');
		}

		// 生成订单号
		$mch_order_no = 'LEXMPAY_'.$uid.'_'.date('Ymd').str_pad(mt_rand(1, 99999999999), 10, '0', STR_PAD_LEFT);
		// 请求时间
		$order_date = date('Y-m-d H:i:s',time());
		// 商品名称
		$goods_name = 'LexmPay';
		// 提交数据
		$postData = [
			'bank_code' => Config::get('lexmpay.collection_bank_code'),
			'goods_name'=> $goods_name,
			'mch_id'=> Config::get('lexmpay.mch_id'),
			'mch_order_no'=> $mch_order_no,
			'notify_url'=> Config::get('lexmpay.notify_url'),
			'order_date'=> $order_date,
			'pay_type'=> Config::get('lexmpay.collection_pay_type'),
			'trade_amount'=> $trade_amount,
			'version'=> Config::get('lexmpay.version'),
		];

		// 加密字符串
		// $md5str = http_build_query($postData);
		$md5str = '';
		foreach ($postData as $k => $v) {
			$md5str .= $k .'='. $v . '&';
		}
		$md5str = substr($md5str,0,-1);

		// 字符串加密
		$sign = wowpayUtils::sign($md5str,Config::get('lexmpay.collection_key'));

		// 追加提交数据
		$postData['sign_type'] = Config::get('lexmpay.sign_type');
		$postData['sign'] = $sign;

		// 配置header
		$headers = array();
		$headers[]= 'Content-Type: '. 'application/x-www-form-urlencoded';

		$data = wowpayUtils::wowPaySubmit(Config::get('lexmpay.lexmpay_getway'),$postData,$headers);
		$result = json_decode($data,true);
		print_r($result);
		// if ($result['respCode'] == 'SUCCESS') {
		// 	$insert = array(
		// 		'uid' => $uid,
		// 		'fee' => $trade_amount,
		// 		'type' => 3,
		// 		'osn' => $mch_order_no,
		// 		'createtime' => time(),
		// 		'paytime' => 0,
		// 		'status' => 0,
		// 		'payresmsg' => '',
		// 		'prepayresmsg' => json_encode($result),
		// 		'payendtime' => time(),
		// 		'payscale' => $this->payScale['payment']
		// 	);
		// 	$model = new GameModel();
		// 	$model->savePayLog($insert);
		// 	return $this->returnSuccess($result); // 获取 data->payInfo URL支付地址
		// } else {
		// 	return $this->returnError($result);
		// }
	}

	// wowPay 代付回调
	public function wowPayBehalf_notify() {
		$params = Request::post();
		if (empty($params)) {
			echo 'Signature error';
			return;
		}
		$sign = $params['sign'];
		$signType = $params['signType'];
		unset($params['sign']);
		unset($params['signType']);

		$md5str = '';
		foreach ($params as $k => $v) {
			$md5str .= $k .'='. $v .'&';
		}
		$md5str = substr($md5str,0,-1);

		$flag = wowpayUtils::validateSignByKey($md5str,Config::get('wowpay.payment_key'),$sign);

		$model = new UserModel();
		$gameModel = new GameModel();
		$params['sign'] = $sign;
		$params['signType'] = $signType;
		$info = $model->getNutsPayOrderStatus($params['merTransferId']);

		if ($flag) {
			if ($info && $info['status'] == 0) {
				$gameModel->editWowPayMoneyLog($params,$info['uid']);
			}
			echo 'success';
		} else {
			if ($info && $info['callbacknum'] == 0) {
				$gameModel->editWowPayMoneyErrorLog($params,$info['uid']);
			}
			echo 'Signature error';
		}
		return;
	}

	// wowPay 代付
	public function wowPayBehalf() {

		$get = Request::param();
		if (empty($get)) {
			return $this->returnError('Get Empty');
		}

		$uid = $get['uid'];
		$transfer_amount = floatval($get['amount'])*100/100;
		$receive_name = $get['receive_name'];			// 收款银行户名
		$receive_account = $get['receive_account'];		// 收款银行账号
		// $document_type = intval($get['document_type']); // 1 身份证 2 税号
		// $remark = $get['remark'];						// 身份证 或 税号

		if (empty($uid) || $transfer_amount < 0 || empty($receive_name) || empty($receive_account)) {
			return $this->returnError('Param Error');
		}

		$usermodel = new UserModel();
		if(empty($usermodel->checkAccountUser($uid))){
			return $this->returnError('Uid Error');
		}

		// 生成订单号
		$mch_transferId = 'WOWPAY_DF_'.$uid.'_'.date('Ymd').str_pad(mt_rand(1, 99999999999), 10, '0', STR_PAD_LEFT);
		// 请求时间
		$apply_date = date('Y-m-d H:i:s',time());

		// 生成提交数据
		$postData = [
			'apply_date' => $apply_date,
			'bank_code' => Config::get('wowpay.bank_code'),
			'mch_id' => Config::get('wowpay.mch_id'),
			'mch_transferId' => $mch_transferId,
			'receive_account' => $receive_account,
			'receive_name' => $receive_name,
			'transfer_amount' => $transfer_amount * $this->payScale['cash'],
			// 'document_type' => $document_type,
			// 'remark'	 => $remark,
			'back_url' => Config::get('wowpay.back_url')
		];

		ksort($postData);

		$md5str = '';
		foreach ($postData as $k => $v) {
			$md5str .= $k .'='. $v . '&';
		}
		$md5str = substr($md5str,0,-1);

		$sign = wowpayUtils::sign($md5str,Config::get('wowpay.payment_key'));

		// 追加提交数据
		$postData['sign_type'] = Config::get('wowpay.sign_type');
		$postData['sign'] = $sign;

		// 配置header
		$headers = array();
		$headers[]= 'Content-Type: '. 'application/x-www-form-urlencoded';

		$data = wowpayUtils::wowPaySubmit(Config::get('wowpay.wowpay_transfer'),$postData,$headers);
		$result = json_decode($data,true);
		if ($result['respCode'] == 'SUCCESS') {
			// 写入支付日志
			$insert = array(
				'uid' => $uid,
				'fee' => $transfer_amount,
				'type' => 99,
				'osn' => $mch_transferId,
				'createtime' => time(),
				'paytime' => 0,
				'status' => 0,
				'payresmsg' => '',
				'prepayresmsg' => json_encode($result),
				'payendtime' => time(),
				'payscale' => $this->payScale['cash']
			);
			$model = new GameModel();
			$model->savePayLog($insert);
			// 写入数据库 在游戏内减去对应金币 先注释掉，有需要在写入数据库
			Db::table('ym_manage.user_exchange')->insert([
				'user_id' => $uid ,
				'order_number' => $mch_transferId ,
				'bank_number' => $receive_account ,
				'real_name' => $receive_name ,
				'bank_open' => $receive_name ,
				'money' => $transfer_amount * $this->payScale['cash'] ,
				'status' => 1 ,
				'created_at' => date('Y-m-d H:i:s'),
			]);
			return $this->returnSuccess($result);
		}

		return $this->returnError($result);

	}

	// wowpay 代收
	public function wowPay() {

		$get = Request::param();
		if (empty($get)) {
			return $this->returnError('Get Empty');
		}

		if (empty($get['uid']) || empty($get['amount'])) {
			return $this->returnError('Param Error');
		}

		$uid = $get['uid'];
		$trade_amount = floatval($get['amount'])*100/100;

		$usermodel = new UserModel();
		if(empty($usermodel->checkAccountUser($uid))){
			return $this->returnError('Uid Error');
		}

		// 生成订单号
		$mch_order_no = 'WOWPAY_'.$uid.'_'.date('Ymd').str_pad(mt_rand(1, 99999999999), 10, '0', STR_PAD_LEFT);
		// 请求时间
		$order_date = date('Y-m-d H:i:s',time());
		// 商品名称
		$goods_name = 'WowPay';
		// 提交数据
		$postData = [
			'goods_name'=> $goods_name,
			'mch_id'=> Config::get('wowpay.mch_id'),
			'mch_order_no'=> $mch_order_no,
			'notify_url'=> Config::get('wowpay.notify_url'),
			'order_date'=> $order_date,
			'pay_type'=> Config::get('wowpay.collection_pay_type'),
			'trade_amount'=> $trade_amount * $this->payScale['payment'],
			'version'=> Config::get('wowpay.version'),
		];

		// 加密字符串
		// $md5str = http_build_query($postData);
		$md5str = '';
		foreach ($postData as $k => $v) {
			$md5str .= $k .'='. $v . '&';
		}
		$md5str = substr($md5str,0,-1);

		// 字符串加密
		$sign = wowpayUtils::sign($md5str,Config::get('wowpay.collection_key'));

		// 追加提交数据
		$postData['sign_type'] = Config::get('wowpay.sign_type');
		$postData['sign'] = $sign;

		// 配置header
		$headers = array();
		$headers[]= 'Content-Type: '. 'application/x-www-form-urlencoded';

		$data = wowpayUtils::wowPaySubmit(Config::get('wowpay.wowpay_getway'),$postData,$headers);
		$result = json_decode($data,true);
		if ($result['respCode'] == 'SUCCESS') {
			$insert = array(
				'uid' => $uid,
				'fee' => $trade_amount,
				'type' => 3,
				'osn' => $mch_order_no,
				'createtime' => time(),
				'paytime' => 0,
				'status' => 0,
				'payresmsg' => '',
				'prepayresmsg' => json_encode($result),
				'payendtime' => time(),
				'payscale' => $this->payScale['payment']
			);
			$model = new GameModel();
			$model->savePayLog($insert);
			return $this->returnSuccess($result); // 获取 data->payInfo URL支付地址
		} else {
			return $this->returnError($result);
		}
	}

	// wowpay 代收回调
	public function wowPay_notify() {

		$params = Request::post();
		if (empty($params)) {
			echo 'Signature error';
			return;
		}
		$sign = $params['sign'];
		$signType = $params['signType'];
		unset($params['sign']);
		unset($params['signType']);

		$md5str = '';
		foreach ($params as $k => $v) {
			$md5str .= $k .'='. $v .'&';
		}
		$md5str = substr($md5str,0,-1);

		$flag = wowpayUtils::validateSignByKey($md5str,Config::get('wowpay.collection_key'),$sign);

		$params['sign'] = $sign;
		$params['signType'] = $signType;

		$model = new UserModel();
		$info = $model->getNutsPayOrderStatus($params['mchOrderNo']);

		$gameModel = new GameModel();

		if ($flag) {
			if ($info && $info['status'] == 0) {
				$gameModel->editWowPayLog($params,$info['uid']);
			}
			echo 'success';
		} else {
			if ($info && $info['callbacknum'] == 0) {
				$gameModel->editWowPayErrorLog($params,$info['uid']);
			}
			echo 'Signature error';
		}
		return;
	}

	public function nutsPayBehalf() {

		$get = Request::param();
		if (empty($get)) {
			return $this->returnError('Get Empty');
		}

		$uid = $get['uid'];
		$amount = ceil(floatval($get['amount'])*100)/100;
		$transferType = isset($get['transferType']) ? $get['transferType'] : 'CPF'; // 账号类型，如果不传默认CPF类型
		$beneficiaryAccount = $get['beneficiaryAccount']; // PIX账号
		$beneficiaryName = $get['beneficiaryName']; // 持卡人名称

		if (empty($uid) || $amount < 0 || empty($beneficiaryAccount) || empty($beneficiaryName)) {
			return $this->returnError('Param Error');
		}

		$usermodel = new UserModel();
		if(empty($usermodel->checkAccountUser($uid))){
			return $this->returnError('Uid Error');
		}

		$merchantOrderNo = 'NUTSPAY_DF_'.$uid.'_'.date('Ymd').str_pad(mt_rand(1, 99999999999), 10, '0', STR_PAD_LEFT);

		// 拼接参数
		$native = array(
			"amount" => $amount,
			"merchantOrderNo" => $merchantOrderNo,
			"transferType" => $transferType,
			"beneficiaryAccount" => $beneficiaryAccount,
			"beneficiaryName" => $beneficiaryName,
    	);

		$pay_str = json_encode(($native));
       
		// 配置header
		$headers = array();
		$headers[]= 'Content-Type: '. 'application/json;charset=UTF-8';
		$headers[]= 'merchant_key: '.Config::get('nutspay.merchant_key');

		// 生成密钥
		$data= nutspayUtils::encryptNew($pay_str, Config::get('nutspay.aes_key'), Config::get('nutspay.aes_iv'));
		$info['data']=$data;
		$data=json_encode($info);

		// 发送请求
		$ret = nutspayUtils::httpsPost(Config::get('nutspay.nutspay_behalf_getway'),$data,$headers);
		echo $ret;
		die;
	}

	// nutspay 代收
	public function nutsPay() {

		$get = Request::param();
		if (empty($get)) {
			return $this->returnError('Get Empty');
		}

		$uid = $get['uid'];
		$amount = ceil(floatval($get['amount'])*100)/100;

		if (empty($uid) || $amount < 0) {
			return $this->returnError('Param Error');
		}

		$usermodel = new UserModel();
		if(empty($usermodel->checkAccountUser($uid))){
			return $this->returnError('Uid Error');
		}

		// 生成订单号
		$outOrderNo = 'NUTSPAY_'.$uid.'_'.date('Ymd').str_pad(mt_rand(1, 99999999999), 10, '0', STR_PAD_LEFT);

		// 拼接参数
		$native = array(
			"amount" => $amount,
			"merchantOrderNo" => $outOrderNo,
			"customerName" => '',
			"customerEmail" => '',
			"customerPhone" => '',
			'notifyUrl' => Config::get('nutspay.pay_notifyurl'),
			'description' => '',
    	);

		$pay_str = json_encode(($native));
       
		// 配置header
		$headers = array();
		$headers[]= 'Content-Type: '. 'application/json;charset=UTF-8';
		$headers[]= 'merchant_key: '.Config::get('nutspay.merchant_key');

		// 生成密钥
		$data= nutspayUtils::encryptNew($pay_str, Config::get('nutspay.aes_key'), Config::get('nutspay.aes_iv'));
		$info['data']=$data;
		$data=json_encode($info);

		// 发送请求
		$ret = nutspayUtils::httpsPost(Config::get('nutspay.nustpay_getway'),$data,$headers);
		$retinfo=json_decode($ret,true);
		$code=$retinfo['code'];
		
		if($code=='0'){
			//存记录
			$insert = array(
				'uid' => $uid,
				'fee' => $amount,
				'type' => 3,
				'osn' => $outOrderNo,
				'createtime' => time(),
				'paytime' => 0,
				'status' => 0,
				'payresmsg' => '',
				'prepayresmsg' => json_encode($retinfo['data']),
				'payendtime' => time()
			);
			$model = new GameModel();
			$model->savePayLog($insert);
			return $this->returnSuccess($retinfo['data']);
		}
		else{
			return $this->returnError($ret);
		}
	}
	
	// nutspay 代收回调
	public function nutspay_notify() {

		$oriContent = file_get_contents('php://input');
		if (empty($oriContent)) {
			echo 'false';
			return;
		}
		$data=json_decode($oriContent,true);
		$returnArray=$data['data'];
		$sign=$data['signature'];
    	$lsign = md5(Config::get('nutspay.merchant_key').json_encode($returnArray).Config::get('nutspay.aes_key'));
		if($lsign != $sign){
			echo 'false1';
		  	return;
		}

		// $orderNo=$returnArray['merchantOrderNo'];
		// $mchId=$returnArray['memberid'];
		// $totalAmount=(int)$returnArray['amount'];
		// $outChannelNo=$returnArray['orderNo'];
		// $returnCode=$returnArray['status'];

		if($returnArray['status'] == 'SUCCESS') {
			$model = new UserModel();
			$info = $model->getNutsPayOrderStatus($returnArray['merchantOrderNo']);
			if ($info && $info['status'] == 0) {
				$gameModel = new GameModel();
				$gameModel->editNutsPayLog($returnArray,$info['uid']);
			}
		}

		echo json_encode(['code' => 200]);
	}

	// http://ydlht.com/index.php/api/pay/pay/uid/1000/fee/0.01/type/1
	public function pay(){

		$get = Request::param();
		if(empty($get)){
			return $this->returnError('Get Empty');
		}

		$uid = $get['uid'];
		$fee = $get['fee'];
		$type = $get['type'];
		if( empty($uid) || empty($fee) || empty($type) || ($fee<0) || !in_array($type,[1,2]) ){
			return $this->returnError('Param Error');
		}

		$usermodel = new UserModel();
		$checkUid = $usermodel->checkAccountUser($uid);
		if( empty($checkUid)  ){
			return $this->returnError('Uid Error');
		}
		
		//验证 一分钟支付一次
		$checkPay = $usermodel->checkUserCanPay($uid);
		if( $checkPay ){

			//新增订单
			$data = $this->calcToPay($uid, $fee, $type);
			if(is_array($data)){
				$this->assign('result',$data);
				return $this->fetch();
			}else{
				return $this->returnError('Pay Error');
			}
			
		}else{

			//判断是否上一笔订单 否则返回error
			$data = $usermodel->getUserPayInfo($uid, $fee, $type);
			if(is_array($data)){
				$this->assign('result',$data);
				return $this->fetch();
			}else{
				return $this->returnError('1min Error');
			}
			
		}

	}

	// http://ydlht.com/index.php/api/pay/pay/uid/1000/fee/0.01/type/1
	public function pay_bak(){
		die('Closed');

		$get = Request::param();
		if(empty($get)){
			return $this->returnError('Get Empty');
		}

		$uid = $get['uid'];
		$fee = $get['fee'];
		$type = $get['type'];
		if( empty($uid) || empty($fee) || empty($type) || ($fee<0) || !in_array($type,[1,2]) ){
			return $this->returnError('Param Error');
		}

		$usermodel = new UserModel();
		$checkUid = $usermodel->checkAccountUser($uid);
		if( empty($checkUid)  ){
			return $this->returnError('Uid Error');
		}

		$post = $this->calcToPay($uid, $fee, $type);
		$this->assign('post',$post);

		return $this->fetch();
	}

	/**
	 * type 1：微信支付；2：支付宝
	 */
	private function calcToPay($orderuid, $price, $type){
		$this->init();
		$time = time();
		
		$goodsname = "意大利娱乐充值";
		$orderid = 'YDL'.date("YmdHis",$time).mt_rand(100,999);  
		
		$token = "G1QK0PZD8AQA76I0BVBMP7SWUFPIG8HK";  
		$identification = "7X10GKKZ27CYMZ7M";   
		
		$thisurl = $this->testapi_url;
		$return_url = $thisurl."/index.php/api/pay/returnUrl";
		$notify_url = $thisurl."/index.php/api/pay/notifyUrl";
		
		$price = $price*100; 
		$key = md5($goodsname. $identification. $notify_url. $orderid. $orderuid. $price. $return_url. $token. $type  );
		$returndata['price'] = $price;
		$returndata['type'] = $type;
		$returndata['orderuid'] =$orderuid;
		$returndata['goodsname'] = $goodsname;
		$returndata['orderid'] = $orderid;
		$returndata['identification'] = $identification;
		$returndata['notify_url'] = $notify_url;
		$returndata['return_url'] = $return_url;
		$returndata['key'] = $key; 
		//var_dump($returndata);die;

		$curl = new Curl();
		$result = $curl->_request('https://data.020zf.com/index.php?s=/api/pp/index_show.html',true,'post',$returndata);
		//var_dump($result);
		//string(267) "{"code":200,"data":{"qrcode":"wxp:\/\/f2f0Pq7X3q7m4abBZlEHN_EMmSHJ2iqw_D4T","type":"1","actual_price":1,"bill_no":"20190826499710153","end_time":1566789629,"return_url":"http:\/\/yidaliadmin.game.cn\/index.php\/api\/pay\/returnUrl","orderid":"YDL1566789329194"}}"
		$result = json_decode($result,true);
		if($result['code'] != '200'){
			return 'Pay Param Error:'.$result['code'];
		}

		//存记录
		$insert = array(
			'uid' => $orderuid,
			'fee' => $price/100,
			'type' => $type,
			'osn' => $orderid,
			'createtime' => $time,
			'paytime' => 0,
			'status' => 0,
			'payresmsg' => '',
			'prepayresmsg' => json_encode($result['data']),
			'payendtime' => $result['data']['end_time']
		);
		$model = new GameModel();
		$model->savePayLog($insert);

		return $result['data'];
	}

	//同步通知
	public function returnUrl(){
		return $this->fetch('returnUrl');
	}

	//异步通知
	public function notifyUrl(){
		$token = "G1QK0PZD8AQA76I0BVBMP7SWUFPIG8HK"; 

		$post = Request::param();
		if(empty($post)){
			return false;
		}
	
		$bill_no = $post["bill_no"];                  //一个24位字符串，是此订单在020ZF服务器上的唯一编号
		$orderid = $post["orderid"];                  //是您在发起付款接口传入的您的自定义订单号
		$price = $post["price"];                      //单位：分。是您在发起付款接口传入的订单价格
		$actual_price = $post["actual_price"];        //单位：分。一定存在。表示用户实际支付的金额。
		$orderuid = $post["orderuid"];                //如果您在发起付款接口带入此参数，我们会原封不动传回。
		$key = $post["key"];                       
		
		$notify_key = md5($actual_price.$bill_no.$orderid.$orderuid.$price.$token);
		if($key == $notify_key){
			
			//修改记录
			$model = new GameModel();
			$rs = $model->editPayLog($post);
			if($rs){
				echo "success";	  
			}
			
		}
	}

	//获取订单状态
	public function orderStatus(){
		$post = Request::param();
		if(empty($post)){
			return false;
		}

		$ordersn = $post['ordersn'];
		$model = new UserModel();
		$info = $model->getOrderStatus($ordersn);
		echo $info;
	}
	
}
