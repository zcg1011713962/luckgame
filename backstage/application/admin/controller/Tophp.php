<?php
namespace app\admin\controller;
use think\Controller;
use think\Db;
use think\facade\Request;
use think\facade\Cache;
use think\facade\Cookie;
use think\facade\Config;

class Tophp extends Controller
{	
	private $db;
	private $db_laba;
	private $db_account;
	public function __construct(){
		parent::__construct();
		
		$db_host = Config::get('database.hostname');
		$db_user = Config::get('database.username');
		$db_pwd = Config::get('database.password');
		$db_port = Config::get('database.hostport');
		$this->db = Db::connect('mysql://'.$db_user.':'.$db_pwd.'@'.$db_host.':'.$db_port.'/game#utf8');
		$this->db_laba = Db::connect('mysql://'.$db_user.':'.$db_pwd.'@'.$db_host.':'.$db_port.'/game#utf8');
		$this->db_account = Db::connect('mysql://'.$db_user.':'.$db_pwd.'@'.$db_host.':'.$db_port.'/game#utf8');
	}
	
	public function onlinenum()
	{
		$data = Request::param();
		if(empty($data)){ die('参数有误'); }
		if(isset($data['server_id']) && empty($data['server_id'])){ die('参数有误'); }
		if( !!!isset($data['online_num']) ){ die('参数有误'); }
		
		$game = $this->db->table('game')->where('port',$data['server_id'])->find();
		if(!$game){ die('游戏不存在'); }
		
		$insert_data = array(
			'gid' => $game['id'],
			'gport' => $data['server_id'],
			'num' => $data['online_num'],
			'createtime' => time()
		);
		
		$this->db->table('game_onlinenum')->insert($insert_data);
		
	    echo 'do over';
	}
	
	public function kucunlog(){
		
		$db = $this->db_laba;
		
		$games = $db->table('gambling_game_list')->select();
		$time = date('Y-m-d H:i:s',time());
		foreach($games as $vo){
			$insert_data = array(
				'gameid' => $vo['nGameID'],
				'shuiwei' => $vo['nGamblingWaterLevelGold'],
				'kucun' => $vo['nGamblingBalanceGold'],
				'jiangchi' => $vo['nGamblingWinPool'],
				'createtime' => $time
			);
			
			$this->db->table('kucunlog')->insert($insert_data);
		}
		echo 'do over';
	}
	
	public function monipay(){
		$data = request()->get();
		if(empty($data)){ die('参数有误'); }
		
		if(empty($data['money'])){ die('金额有误'); }
		if(empty($data['id'])){ die('用户有误'); }
		
		$user = $this->db_account->table('newuseraccounts')->where('Id',$data['id'])->find();
		if(!$user){ die('用户未找到'); }
		
		$this->assign('account',$user['Account']);
		$this->assign('fee',$data['money']);
		
		return $this->fetch();
	}
	
	public function chat()
	{
		$data = Request::param();
		if(empty($data)){ die('参数有误'); }
		if(empty($data['user_id']) || empty($data['gm_id']) || empty($data['msg'])){ die('参数有误'); }
				
		$game = $this->db->table('game')->where('port',$data['gameport'])->find();
		if(!$game){ die('游戏不存在'); }
		
		$insert_data = array(
			'kfid' => $data['gm_id'],
			'uid' => $data['user_id'],
			'uname' => $data['user_name'],
			'msg' => $data['msg'],
			'createtime' => time(),
			'type' => 1 //1user send 2kefu send
		);
		
		$this->db->table('kefu_msg')->insert($insert_data);
		
	    echo 'do over';
	}
	
	
}
