<?php
namespace app\api\controller;
use app\api\controller\Init;
use app\api\controller\Curl;
use think\Request;
use app\api\model\KefuModel;

class Kefu extends Init
{
	/**
	 * 客服列表
	 * http://127.0.0.1/api/kefu/lists
	 */
	public function lists(){
		$model = new KefuModel();
		$data = $model->getLists();
		echo $this->returnSuccess($data);
	}

	/**
	 * 外接客服列表
	 * http://127.0.0.1/api/kefu/wlists
	 */
	public function wlists(){
		$model = new KefuModel();
		$data = $model->getwLists();
		echo $this->returnSuccess($data);
	}
	
	/**
	 * 接收消息
	 */
	public function receiveMsg(){
		
	}
	
	/**
	 * 发送消息
	 */
	public function sendMsg(){
		
	}
	
}
