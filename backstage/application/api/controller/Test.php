<?php
namespace app\api\controller;
use app\api\controller\Init;
use app\api\controller\Curl;
use think\Request;
use app\api\model\UserModel;
use app\api\model\EncnumModel;

class Test extends Init
{
	public function id2token(){
		//初始化
		$this->init();
	
		$data = array(
			'uid' => '3149',
			'to' => '2' // 2 3 4 5
		);
		$data['sign'] = $this->makeSignature($data);
		$data = json_encode($data);
		$url = $this->testapi_url.'/index.php/api/user/id2token.html';
		$curl = new Curl();
		$rrr1 = $curl->_request($url,true,'post',array('data'=>$data));
		echo $rrr1;
	}
	
	public function userinfo(){
		//初始化
		$this->init();
	
		$data = array(
			'token' => '20484ee9ba8cc4ee510731a19470f2e5'
		);
		$data['sign'] = $this->makeSignature($data);
		$data = json_encode($data);
		$url = $this->testapi_url.'/index.php/api/user/userinfo.html';
		$curl = new Curl();
		$rrr1 = $curl->_request($url,true,'post',array('data'=>$data));
		echo $rrr1;
	}
	
	public function encFromType(){
		$obj = new EncnumModel(8);
		for($i=1;$i<=5;$i++){
			$e_txt = $obj->encode($i);
			echo $e_txt.'<br/>';
			echo $obj->decode($e_txt);
			echo '<hr/>';
		}
		
		$rs = $obj->decode('ABCDEFG');
		var_dump($rs);
	}
	
	/**
	 * FSimXizk  2
	 * FiXziJzV  3
	 * Fmyzxyij  4
	 * FXmimSJq  5
	 */
	public function turnScore(){
		//初始化
		$this->init();

		$data = array(
			'id' => '5',
			'fromtype' => 'FSimXizk',
			'num' => '100'
		);
		$data['sign'] = $this->makeSignature($data);
		$data = json_encode($data);
		$url = $this->testapi_url.'/index.php/api/user/turnScore.html';
		$curl = new Curl();
		$rrr1 = $curl->_request($url,true,'post',array('data'=>$data));
		echo $rrr1;
	}
			
	
}
