<?php
namespace app\chat\controller;
use think\Controller;
use think\Db;
use think\facade\Request;
use think\facade\Cache;
use think\facade\Cookie;
use think\facade\Config;

class Login extends Controller
{	
	private $db;
	public function __construct(){
		parent::__construct();
		$db_host = Config::get('database.hostname');
		$db_user = Config::get('database.username');
		$db_pwd = Config::get('database.password');
		$db_port = Config::get('database.hostport');
		$this->db = Db::connect('mysql://'.$db_user.':'.$db_pwd.'@'.$db_host.':'.$db_port.'/ym_manage#utf8');
		//$this->db = Db::connect('mysql://root:@127.0.0.1:3306/ym_manage#utf8');
	}
	
	public function login()
	{
		$ht_name = Config::get('app.HT_NAME');
		$this->assign('ht_name',$ht_name);
		
	    return $this->fetch();
	}
	
	public function doLogin()
	{
		$data = Request::post();
		if(empty($data)){ die('参数有误'); }
		if(isset($data['username']) && empty($data['username'])){ die('参数有误'); }
		if(isset($data['password']) && empty($data['password'])){ die('参数有误'); }
		
		$username = $data['username'];
		$password = $data['password'];
	       	
		$res = $this->db->table('kefu_list')->where('account',$username)->where('password',$password)->where('isclose','0')->find();
		if(empty($res)){ die('登录失败'); }
		// 存登录状态 2小时过期
		Cookie::set('chat_user_id',$res['id'],3600*2);			
		Cache::store('redis')->set('chat_user_'.$res['id'],'login',3600*2);
                #$response->Response::create("success","text")->header('Location', '/chat/index/index');
	        $this->success("success");
                #die("success");
                #$response->send();
	}
	
}
