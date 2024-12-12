<?php
namespace app\chat\controller;
use think\Controller;
use think\facade\Request;
use app\chat\controller\Parents;
use app\chat\model\UserModel;
use app\chat\model\AdminModel;
use app\admin\model\ConfigModel;

class User extends Parents
{
    public function lists()
    {
		$user = new UserModel;
					
		$list = $user->getUserList();
    
		$this->assign('list',$list);

		$admin = new AdminModel;
		$kfid = $admin->getAgId();
		$this->assign('kfid',$kfid);

		// $gameServer = $admin->getConfig('app.gameServer');
		$gameServer = ConfigModel::getSystemConfig()['GameServiceApi'];
		$this->assign('gameServer',$gameServer);
		
		return $this->fetch();
    }
	
	public function openMsgList(){
		$uid = Request::post('uid');
		if(empty($uid)){ die(); }
		
		$user = new UserModel;					
		$list = $user->getMsgList($uid);
		
		$str = '';
		foreach($list as $row){
			$align = '';
			if($row['type'] == '1'){ 
				$align = ' style="text-align:left;" '; 
				$uid='['.$row['uid'].']';
				$name=$row['uname']; 
			}
			if($row['type'] == '2'){ 
				$align = ' style="text-align:right;" ';
				$uid='';
				$name=$row['kfname']; 
			}
			$str .= '<li '.$align.'>['.date('Y-m-d H:i:s',$row['createtime']).']'.$uid.' '.$name.':<br/> '.$row['msg'].'</li>';
		}
		echo $str;
	}
	public function closeLeft(){
		$uid = Request::post('uid');
		if(empty($uid)){ die; }
		$user = new UserModel;					
		echo $user->closeLeft($uid);
	}
	
	public function sendMsg(){
		$data = Request::post();
		if(empty($data)){ die; }
		if(empty($data['uid'])){ die; }
		if(empty($data['msg'])){ die; }
		
		$user = new UserModel;
		$list = $user->sendMsg($data['uid'],$data['msg']);
		if($list){ echo $data['uid'];die; }
	}

	public function zhuanyi(){
		$user = new UserModel;
		
		$info = $user->myinfo();
		$this->assign('info',$info);
						
		return $this->fetch();
	}
	
	public function doRecharge(){
		$data = request()->post();
		if(empty($data)){ die('参数有误'); }
		
		if(empty($data['account'])){ die('用户参数有误'); }
		if(empty($data['fee'])){ die('金额参数有误'); }
		if($data['fee'] < 0){ die('金额不能为负'); }
		if(empty($data['type'])){ die('充值类型有误'); }
		
		$user = new UserModel;
		$info = $user->getUserInfo($data['account']);
		
		if($data['type'] == '金币'){
			$res = $user->insertScore($info['Account'],$data['fee']);
		}else{
			$res = false;
		}
		
		
		if($res){
			echo 'success';
		}else{
			echo '充值失败:'.json_encode($res);
		}		
	}

	public function zylogs(){
		
		$user = new UserModel;
		$num = 10;//每页显示数
		
		$res = $user->rechargeLogs1($num);
		$this->assign('list',$res['list']);
		$this->assign('page',$res['page']);
		
		$count = $user->rechargeLogsCount1();
		$this->assign('count',$count);
						
		return $this->fetch();
	}
	public function mylogs(){
		
		$user = new UserModel;
		$num = 10;//每页显示数
		
		$res = $user->rechargeLogs($num);
		$this->assign('list',$res['list']);
		$this->assign('page',$res['page']);
		
		$count = $user->rechargeLogsCount();
		$this->assign('count',$count);
						
		return $this->fetch();
	}
	
}
