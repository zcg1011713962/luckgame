<?php
namespace app\agent\controller;
use think\Controller;
use think\facade\Request;
use app\agent\controller\Parents;
use app\agent\model\GameModel;

class Game extends Parents
{
    public function lists()
    {
		$game = new GameModel;
		
		$list = $game->getList();
		$this->assign('list',$list);
		
		$count = $game->getCount();
		$this->assign('count',$count);

        return $this->fetch();
    }
	
	public function doStart(){
		$data = request()->post();
		if(empty($data)){ die('参数有误'); }
		
		if(empty($data['i'])){ die('用户参数有误'); }
		if(!isset($data['t'])){ die('封禁参数有误'); }
		
		$user = new GameModel;
		$res = $user->setStart($data);
		if($res){
			echo 'success';
		}else{
			echo '修改密码失败';
		}		
	}
	
	public function editchoushuilv(){
		$id = request()->param('id');
		if(empty($id)){ $this->error('参数有误','admin\Game\editchoushuilv'); }
				
		$game = new GameModel;
		$info = $game->getInfo($id);
		$this->assign('info',$info);
		
		return $this->fetch();			
	}
	
	public function doEditCSlv(){
		$data = request()->post();
		if(empty($data)){ die('参数有误'); }
		
		if(empty($data['lv']) || empty($data['id'])){ die('参数有误'); }
		
		$game = new GameModel;
		$res = $game->setCSlv($data);
		if($res){
			echo 'success';
		}else{
			echo '修改密码失败';
		}
	}
	
	public function editkucun(){
		$id = request()->param('id');
		if(empty($id)){ $this->error('参数有误','admin\Game\editkucun'); }
				
		$game = new GameModel;
		$info = $game->getInfo($id);
		$this->assign('info',$info);
		
		return $this->fetch();			
	}
	
	public function doEditKucun(){
		$data = request()->post();
		if(empty($data)){ die('参数有误'); }
		
		if(empty($data['kucun']) || empty($data['id'])){ die('参数有误'); }
		
		$game = new GameModel;
		$res = $game->setKucun($data);
		if($res){
			echo 'success';
		}else{
			echo '修改密码失败';
		}
	}
	
	public function onlinenum()
	{
		$id = request()->param('id');
		if(empty($id)){ $this->error('参数有误','admin\Game\onlinenum'); }
		
		$game = new GameModel;
		$info = $game->getInfo($id);
		$this->assign('info',$info);
		
		$nums = $game->getOnlineNum($id);
		
		$key = '';
		foreach($nums['key'] as $v){
			$key .= "'".$v."',";
		}
		$key = trim($key,',');
		$this->assign('key',$key);
		
		$value = $nums['value'];		
		$this->assign('value',$value);
		
	    return $this->fetch();
	}
	
}
