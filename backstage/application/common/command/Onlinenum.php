<?php
namespace app\common\command;

use think\console\Command;
use think\console\Input;
use think\console\input\Argument;
use think\console\input\Option;
use think\console\Output;

class Onlinenum extends Command {
	
	protected function configure()
    {
        $this->setName('onlinenum')->setDescription('在线人数 niuxp');
    }

    protected function execute(Input $input, Output $output)
    {
		ini_set('default_socket_timeout', -1);
		set_time_limit(0);
		$output->writeln("starting");    
		
		$redis = new \Redis();
		$redis->connect('127.0.0.1', 6479);
		//$redis->connect('192.168.1.110', 6379);
		$redis->auth(getenv("REDIS_PASSWORD"));
		$strChannel = 'OnlineUserMsg';

		//订阅
		$output->writeln("---- {$strChannel} waiting ...----  ".$redis->ping()."<\n");
		$redis->subscribe([$strChannel], function($redis, $channel, $msg){
			print_r($msg);echo ' _ ';
			
			$arr = json_decode($msg,true);	
			if( isset($arr['server_id']) && isset($arr['online_num']) ){
				$url = 'http://127.0.0.1/index.php/admin/Tophp/onlinenum.html';		
				echo $this->_request($url,false,'post',$arr);
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
