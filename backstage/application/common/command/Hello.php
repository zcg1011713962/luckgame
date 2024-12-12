<?php
namespace app\common\command;

use think\console\Command;
use think\console\Input;
use think\console\input\Argument;
use think\console\input\Option;
use think\console\Output;

class Hello extends Command {
	
	protected function configure()
    {
        $this->setName('crontab')->setDescription('计划任务 niuxp');
    }

    protected function execute(Input $input, Output $output)
    {
		$url = 'http://127.0.0.1/.php';
    	
		set_time_limit(0);
		$output->writeln("start");    
		$i = 0;
		
		while(true){
			sleep(60);
			$output->writeln("... [".$i."]"); 
			$rs = $this->_request($url);
			$output->writeln(json_encode($rs));    
			$i++;
		}
		
        
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