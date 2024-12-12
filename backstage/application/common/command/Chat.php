<?php
namespace app\common\command;

use think\console\Command;
use think\console\Input;
use think\console\input\Argument;
use think\console\input\Option;
use think\console\Output;

class Chat extends Command {
	
	protected function configure()
    {
        $this->setName('chat')->setDescription('客服聊天 niuxp');
    }

    protected function execute(Input $input, Output $output)
    {
		
		ini_set('default_socket_timeout', -1);
		set_time_limit(0);
		$output->writeln("starting");    
		
		$redis = new \Redis();
		$redis->connect('127.0.0.1', 6479);
		//$redis->connect('192.168.1.110', 6379);
		$redis->auth("REDIS_PASSWORD");
		$strChannel = 'sendMsgToGM';

		//订阅
		$output->writeln("---- {$strChannel} waiting ...----  ".$redis->ping()."<\n");
		$redis->subscribe([$strChannel], function($redis, $channel, $msg){
			print_r($msg);echo ' _ ';
			
			$arr = json_decode($msg,true);	
			if( $arr['user_id'] && $arr['gm_id'] && $arr['msg'] ){
			//	$url = 'http://yidaliadmin.youmegame.cn/index.php/admin/Tophp/chat.html';		
			        $admin_host=getenv("ADMIN_HOST");
                                if(empty($admin_host)){
                                    $admin_host="127.0.0.1";
                                 }
                         	$url = "http://$admin_host/index.php/admin/Tophp/chat.html";		
				$res = $this->_request($url,false,'post',$arr);
				print_r($res);echo ' _ ';
			}
		});
		
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
