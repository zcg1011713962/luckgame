<?php
namespace app\chat\controller;
use think\Controller;
use think\facade\Cache;
use think\facade\Cookie;

class Parents extends Controller
{

    public function __construct()
    {
		parent::__construct();
		$res = $this->checkLogin();
		if(!$res){
			$this->redirect('login/login');
		}
    }
	
	private function checkLogin()
	{
		$uid = Cookie::get('chat_user_id');
		if(!$uid){
			return false;
		}
		$login = Cache::store('redis')->get('chat_user_'.$uid);
		if($login == 'login'){
			return true;
		}
		return false;
	}
	
	public function logout()
	{
		$uid = Cookie::get('chat_user_id');		
		if(!$uid){
			return false;
		}
		Cache::store('redis')->rm('chat_user_'.$uid);
		Cookie::delete('chat_user_id');
		$this->redirect('login/login');
	}
	
	protected function _request($url, $https=false, $method='get', $data=null)
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
