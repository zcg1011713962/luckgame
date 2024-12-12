<?php
namespace app\api\controller;
use app\api\controller\Init;
use app\api\controller\Curl;
use think\facade\Request;
use app\api\model\UserModel;
use app\api\model\EncnumModel;
use app\api\model\GameModel;

//金钻支付
//https://saas.jzpay.vip

class Payjz extends Init
{

	private $merchantId = 'ccfaeef69bddade20dcbac2947960da6';
	private $secretKey = 'e65a28c289f2844165a065e001b5a6e4';
	private $apiurl = 'https://api.jzpay.vip/jzpay_exapi/v1/order/createOrder';
	

	protected function makeSignature_jz($args)
	{
		$key = $this->secretKey;
		if(isset($args['signature'])){
			unset($args['signature']);
		}
		ksort($args);
		$stringA = [];
		foreach($args as $k => $v) {
				$stringA[] = $k . '=' . $v;				
		}
		//var_dump($stringA);echo '<hr/>';
		$stringA = implode('&',$stringA);
		//var_dump($stringA);echo '<hr/>';
		$signature  = strtoupper(hash_hmac("sha256", $stringA, $key));		
		return $signature;
	}

	protected function pinjie($args)
	{
		ksort($args);
		$stringA = [];
		foreach($args as $k => $v) {
				$stringA[] = $k . '=' . $v;				
		}
		$stringA = implode('&',$stringA);		
		return $stringA;
	}

	// http://ydlht.com/index.php/api/payjz/pay/uid/1000/fee/0.01/type/1
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

	public function getIp()
	{	
		if ($_SERVER["REMOTE_ADDR"] && strcasecmp($_SERVER["REMOTE_ADDR"], "unknown")) {
			$ip = $_SERVER["REMOTE_ADDR"];
		} else {
			if (isset ($_SERVER['REMOTE_ADDR']) && $_SERVER['REMOTE_ADDR'] && strcasecmp($_SERVER['REMOTE_ADDR'],
					"unknown")
			) {
				$ip = $_SERVER['REMOTE_ADDR'];
			} else {
				$ip = "unknown";
			}
		}
		
		return ($ip);
	}

	/**
	 * type 1：微信支付；2：支付宝
	 */
	private function calcToPay($orderuid, $price, $type){
		$this->init();
		$time = time();
		
		$goodsname = "yidali";
		$orderid = 'YDL'.date("YmdHis",$time).mt_rand(100,999);  
		
		$merchantId = $this->merchantId;
		
		$thisurl = $this->testapi_url;
		$notify_url = $thisurl."/index.php/api/pay/notifyUrl";
		
		$returndata['merchantId'] = $merchantId;
		$returndata['timestamp'] = strval($time*1000);
		$returndata['signatureMethod'] = 'HmacSHA256';
		$returndata['signatureVersion'] = 1;		
		$returndata['jUserId'] = $orderuid;
		$returndata['jUserIp'] = $this->getIp();//'125.37.27.179';
		$returndata['jOrderId'] = $orderid;
		$returndata['orderType'] = 1;
		if($type == 2){ $returndata['payWay'] = 'AliPay'; }
		if($type == 1){ $returndata['payWay'] = 'WechatPay'; }
		$returndata['amount'] = round($price,2);
		$returndata['currency'] = 'CNY';		
		$returndata['jExtra'] = $goodsname;
		$returndata['notifyUrl'] = $notify_url;
		//var_dump($returndata);echo '<hr/>';
		$returndata['signature'] = $this->makeSignature_jz($returndata); 
		//var_dump($returndata['signature']);echo '<hr/>';

		$curl = new Curl();
		//echo $this->apiurl;echo '<hr/>';
		//var_dump($returndata);echo '<hr/>';
		$post = $this->pinjie($returndata);
		//var_dump($post);echo '<hr/>';
		$result = $curl->_request_jz($this->apiurl,true,'post',$post);
		var_dump($result);die;
		//string(267) "{"code":0,"message":"成功","data":{"orderId":"P64853114579548569651","orderType":1,"paymentUrl":"https://pay5.i2605.com/entrance/P64853114579548569651/237ec3405fe5e47dc2a16cdf487c6c0d"},"signature":"DCFCE8E06343AF7CFCDF4EF178E049D51C80EA110F68490C4FA5F301C09FF468"}"
		$result = json_decode($result,true);
		if($result['code'] != '0'){
			return 'Pay Param Error:'.$result['code'].'--'.$result['message'];
		}

		//存记录
		$insert = array(
			'uid' => $orderuid,
			'fee' => round($price,2),
			'type' => $type,
			'osn' => $orderid,
			'osnjz' => $result['data']['orderId'],
			'createtime' => $time,
			'paytime' => 0,
			'status' => 0,
			'payresmsg' => '',
			'prepayresmsg' => json_encode($result['data']),
			'payendtime' => $time+60
		);
		$model = new GameModel();
		$model->savePayLog($insert);

		return $result['data']['paymentUrl'];
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
