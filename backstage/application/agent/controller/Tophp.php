<?php
namespace app\agent\controller;
use think\Controller;
use think\Db;
use think\facade\Request;
use think\facade\Cache;
use think\facade\Cookie;

class Tophp extends Controller
{	
	private $db;
	public function __construct(){
		parent::__construct();
		$this->db = Db::connect('mysql://root:@127.0.0.1:3406/ym_manage#utf8');
	}
	
	public function onlinenum()
	{
		$data = Request::post();
		if(empty($data)){ die('参数有误'); }
		if(isset($data['gameport']) && empty($data['gameport'])){ die('参数有误'); }
		if(isset($data['num']) && empty($data['num'])){ die('参数有误'); }
		
		$game = $this->db->table('game')->where('port',$data['gameport'])->find();
		if(!$game){ die('游戏不存在'); }
		
		$insert_data = array(
			'gid' => $game['id'],
			'gport' => $data['gameport'],
			'num' => $data['num'],
			'createtime' => time()
		);
		
		$this->db->table('game_onlinenum')->insert($insert_data);
		
	    echo 'do over';
	}
	
	public function kucunlog(){
		$db = Db::connect('mysql://root:@127.0.0.1:3406/la_ba#utf8');
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
			
			Db::connect('mysql://root:@127.0.0.1:3406/ym_manage#utf8')->table('kucunlog')->insert($insert_data);
		}
		echo 'do over';
	}
	
	public function monipay(){
		$data = request()->get();
		if(empty($data)){ die('参数有误'); }
		
		if(empty($data['money'])){ die('金额有误'); }
		if(empty($data['id'])){ die('用户有误'); }
		
		$user = Db::connect('mysql://root:@127.0.0.1:3406/gameaccount#utf8')->table('newuseraccounts')->where('Id',$data['id'])->find();
		if(!$user){ die('用户未找到'); }
		
		$this->assign('account',$user['Account']);
		$this->assign('fee',$data['money']);
		
		return $this->fetch();
	}
	
	
}
