<?php
namespace app\api\controller;

use app\api\controller\Init;
use Workerman\Worker;
use Workerman\WebServer;
use Workerman\Autoloader;
use PHPSocketIO\SocketIO;

class Socket extends Init {
	
	public function __construct(){
		parent::__construct();
	}

	//php server.php api/socket/ServerDemo
	public function ServerDemo(){
		//echo 123;die;
		
		$io = new SocketIO(2020);
	
		//限制连接域名
		//多个域名时用空格分隔
		//$io->origins('http://ydlht.com:2020');
		//$io->origins('http://workerman.net http://www.workerman.net');

		$io->on('connection', function($socket)use($io){
			
			echo "new connection coming\n";
			
			$socket->on('login', function($msg)use($socket){
				//加入分组（一个连接可以加入多个分组）
				//$socket->join('group name');

				//离开分组（连接断开时会自动从分组中离开）
				//$socket->leave('group name');

				//向当前客户端发送事件
				$socket->emit('login msg return', $msg);
				
				//向所有客户端发送事件
				//$io->emit('login msg return', $msg);
				
				//向所有客户端发送事件，但不包括当前连接
				//$socket->broadcast->emit('event name', $data);
				
				//向某个分组的所有客户端发送事件
				//$io->to('group name')->emit('event name', $data);
				
				//获取客户端ip
				echo $socket->conn->remoteAddress."\n";
			});
			
			$socket->on('disconnect', function(){
				echo "server disconnect\n";
			});
			
			//监听Redis信息
			$this->chatMsg();

		});
		
		Worker::runAll();
	}
	
	private function chatMsg()
	{
		
		ini_set('default_socket_timeout', -1);
		set_time_limit(0);
		
		$redis = new \Redis();
		//$redis->connect('127.0.0.1', 6379);
		#$redis->connect('192.168.1.110', 6379);
		$redis->connect(getenv("REIDS_HOST"), getenv("REDIS_PORT"));
		$redis->auth(getenv("REIDS_PASSWORD"));
		$strChannel = 'sendMsgToGM';
	
		//订阅
		echo "---- {$strChannel} waiting ...----  ".$redis->ping()."<\n";
		$redis->subscribe([$strChannel], function($redis, $channel, $msg){
			echo $msg, ' _ ';
			
			$arr = json_decode($msg,true);	
			if( $arr['user_id'] && $arr['gm_id'] && $arr['msg'] ){
				$url = 'http://ydlht.com/index.php/admin/Tophp/chat.html';		
				$res = $this->_request($url,false,'post',$arr);
				echo $res, ' _ ';
			}
		});
		
	}

	public function ClientDemo(){
		$port = 2020;
		$this->assign('port', $port);
		return $this->fetch('demo');
	}
	
	private function _request($url, $https=false, $method='get', $data=null)
	{
		$ch = curl_init();
		curl_setopt($ch,CURLOPT_URL,$url); 
		curl_setopt($ch,CURLOPT_HEADER,false); 
		curl_setopt($ch,CURLOPT_RETURNTRANSFER,true);
		if($https){
			curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false);
			curl_setopt($ch, CURLOPT_SSL_VERIFYHOST, false);
		}
		if($method == 'post'){
			curl_setopt($ch, CURLOPT_POST, true);
			curl_setopt($ch, CURLOPT_POSTFIELDS, $data);
		}
		$str = curl_exec($ch);
		curl_close($ch);
		return $str;
	}


}


?>
