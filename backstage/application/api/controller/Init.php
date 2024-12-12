<?php
namespace app\api\controller;
use think\Controller;
use think\Request;
use think\facade\Config;
use app\admin\model\ConfigModel;

class Init extends Controller
{
    
	protected $uid;
	protected $testapi_url;
	private $signkey;
	private $signkey_nongfu;
	protected $isencrypt;
	private $config;

	protected function init(){
		$this->testapi_url = Config::get('testapiurl');
		$this->config = ConfigModel::getSystemConfig();
		$this->signkey = $this->config['SignKey'];
		$this->signkey_nongfu = $this->config['SignKey_nongfu'];
		$this->isencrypt = config('isencrypt');
	}
	
	//签名算法
	protected function makeSignature($args)	
	{
		var_dump($args);echo '<hr/>';
		$key = $this->signkey;
		if(isset($args['sign'])){
			unset($args['sign']);
		}
		ksort($args);
		$stringA = '';
		$stringSignTemp = '';
		foreach($args as $k => $v) {
				$stringA .= $k . '=' . $v . '&';
		}
		$stringSignTemp =  $stringA.'key='.$key;
		$signature  = strtoupper(md5($stringSignTemp));
		$newString = $stringA.'signature='.$signature;
		$newSign = md5($newString);
		var_dump($newString);echo '<hr/>';
		var_dump($newSign);echo '<hr/>';die;
		return $newSign;
	}

	protected function makeSignature_nongfu($args)	
	{
		$key = $this->signkey_nongfu;		
		ksort($args);
		$stringA = '';
		$stringSignTemp = '';
		foreach($args as $k => $v) {
				$stringA .= $k . '=' . $v . '&';
		}
		$stringSignTemp =  $stringA.'key='.$key;
		$signature  = strtoupper(md5($stringSignTemp));		
		return $signature;
	}
	
	protected function returnError($msg = ''){
		$rs = array('code' => 0, 'msg' => $msg, 'data' => array());
		return json_encode($rs);
	}
	protected function returnSuccess($data = ''){
		$rs = array('code' => 1, 'msg' => 'success', 'data' => $data);
		return json_encode($rs);
	}
	
	protected function returnError1($msg = ''){
		$rs = array('status' => 1, 'msg' => $msg, 'data' => array());
		return json_encode($rs);
	}
	protected function returnSuccess1($data = ''){
		$rs = array('status' => 0, 'msg' => 'success', 'data' => $data);
		return json_encode($rs);
	}

	protected function ydlApiEnc($data){
		$key = '54544jh2fd12uy54';//16位
		$methon = 'AES-128-CBC';
		$iv = '6551fs45rcxsbghy';//16位

		$res = base64_encode(openssl_encrypt($data, $methon, $key, 1, $iv));//加密		
		return $res;
	}

	protected function ydlApiDec($data,$iv = '6551fs45rcxsbghy'){
		$key = "54544jh2fd12uy54";
		$methon = 'AES-128-CBC';
		$decrypted = openssl_decrypt($data, $methon, $key, 0, $iv); // 解密
		return $decrypted;
	}
	
}
