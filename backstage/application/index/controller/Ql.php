<?php
namespace app\index\controller;
use think\Controller;
use QL\QueryList;

class Ql extends Controller
{
    	
    public function hello()
    {
        $hj = QueryList::Query('http://127.0.0.1/kjxx/ssq/kjgg/',array(
			"kjtime"=>array(' .kjsj','html')
		));
		$data = $hj->getData(function($x){
			return $x['kjtime'];
		});
		var_dump($data);
	}
	
	public function _request($url, $https=false, $method='get', $data=null)
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

    public function hello1()
    {
		$time = time() * 1000;
		$url = 'https://127.0.0.1/v/lottery/openInfo?gameId=70';
		$res = $this->_request($url,true);
		var_dump($res);
    }
			
}
