<?php
namespace app\admin\controller;
use think\facade\Request;
use app\admin\controller\Parents;
use app\admin\model\AgentModel;

class Agent extends Parents
{
    	
	public function addscore()
	{
		$id = request()->param('id');
		if(empty($id)){ $this->error('参数有误','admin\User\editpwd'); }
		
		$user = new AgentModel;
		$info = $user->getUserInfo($id);
        if (!$info){
            $this->error('没有这个玩家');
        }
		$this->assign('info',$info);
		
	    return $this->fetch();
	}
	
	public function doAddscore()
	{
		$data = request()->post();
		if(empty($data)){ die('参数有误'); }
		
		if(empty($data['username']) || empty($data['uid']) ){ die('用户参数有误'); }
		//if(empty($data['score']) || empty($data['addscore']) ){ die('金币参数有误'); }
		if( empty($data['addscore']) ){ die('金币参数有误'); }
				
		$user = new AgentModel;
		$res = $user->setUserScore($data,1);
		if($res){
			echo 'success';
		}else{
			echo '金币增加失败:'.json_encode($res);
		}
	}
	
	public function delscore()
	{
		$id = request()->param('id');
		if(empty($id)){ $this->error('参数有误','admin\User\editpwd'); }
		
		$user = new AgentModel;
		$info = $user->getUserInfo($id);
        if (!$info){
            $this->error('没有这个玩家');
        }
		$this->assign('info',$info);
		
	    return $this->fetch();
	}
	
	public function doDelscore()
	{
		$data = request()->post();
		if(empty($data)){ die('参数有误'); }
		
		if(empty($data['username']) || empty($data['uid']) ){ die('用户参数有误'); }
		//if(empty($data['score']) || empty($data['addscore']) ){ die('金币参数有误'); }
		if( empty($data['addscore']) ){ die('金币参数有误'); }
				
		$user = new AgentModel;
		$res = $user->setUserScore($data,2);
		if($res){
			echo 'success';
		}else{
			echo '金币减少失败:'.json_encode($res);
		}
	}

	public function lists()
    {
		$data = request()->post();
				
		if(empty($data['starttime']) || empty($data['endtime']) ){ 
			//$_time = strtotime("-1 day");
			$_time = strtotime("now");
			$starttime = 0;//date('Y-m-d',$_time).' 00:00:00';
			$endtime   = date('Y-m-d',$_time).' 23:59:59';
			$this->assign('starttime','');
			$this->assign('endtime','');
		}else{
			$starttime = $data['starttime'];
			$endtime   = $data['endtime'];
			$this->assign('starttime',$starttime);
			$this->assign('endtime',$endtime);
		}
		
		$starttime = strtotime($starttime);
		$endtime   = strtotime($endtime);
		
		if($starttime >= $endtime){ 
			echo '时间有误<br/>';
			echo '开始时间：'.$starttime.'---'.date('Y-m-d H:i:s',$starttime).'<br/>';
			echo '结束时间：'.$endtime.'---'.date('Y-m-d H:i:s',$endtime);
			die;
		}	
		
		$model = new AdminModel();
		$num = 100;
		$res = $model->getList($num,$starttime,$endtime);
		//var_dump($res['list']);
		
		$this->assign('list',$res['list']);
		$this->assign('page',$res['page']);

		$aid = $model->getAgId();
		$url = $_SERVER['SERVER_NAME'].''.url('api/testClientShow',['uid'=>$aid]);
		$clientShow = $this->_request($url,true);
		$clientShow = json_decode($clientShow, true);
		if($clientShow && $clientShow['status'] == '1'){
			$clientShow = $clientShow['data'];
			$this->assign('isShow',1);
			$this->assign('clientShow',$clientShow);
		}else{
			$this->assign('isShow',0);
		}
						
        return $this->fetch();
    }
	
	public function add()
	{
		//上级代理
		$model = new AdminModel();
		$a1 = $model->getAgId();
		$a23 = $model->get3ji_ids();
		$agents_ids = trim($a1.','.$a23, ',');
		//$agents = $model->get3ji_list($agents_ids);	
		$agents = $model->get3ji_list($a1);	
		$this->assign('agents',$agents);
		
	    return $this->fetch();
	}
	
	public function zhuanyi()
	{
	    return $this->fetch();
	}
	
	public function editinfo()
	{
		$model = new AdminModel();
		$ad = $model->getAdminInfo();
		$info = $model->getAgentDetail();
		$info['account'] = $ad['username'];
		$this->assign('info',$info);
	    return $this->fetch();
	}
	
	public function editpwd()
	{
	    return $this->fetch();
	}
	
	public function doEditInfo(){
		$data = request()->post();
		if(empty($data)){ die('参数有误'); }
		
		if( empty($data['name']) && empty($data['wxname']) && empty($data['mobile']) ){ die('修改信息不能全为空'); }
		
		$user = new AdminModel;
		$res = $user->doEditInfo($data);
		if($res){
			echo 'success';
		}else{
			echo '修改信息失败';
		}		
	}
		
	public function doEditPwd(){
		$data = request()->post();
		if(empty($data)){ die('参数有误'); }
		
		if( empty($data['nowpwd']) ){ die('信息有误'); }
		if(empty($data['newpwd']) || empty($data['renewpwd'])){ die('信息有误'); }
		if( $data['newpwd'] != $data['renewpwd'] ){ die('两次密码不一致'); }
		
		$user = new AdminModel;
		$res = $user->doEditPwd($data);
		if($res){
			echo 'success';
		}else{
			echo '修改密码失败';
		}		
	}
	
	public function doAdd(){
		$data = request()->post();
		if(empty($data)){ die('参数有误'); }
		
		$model = new AdminModel;
		
		if(empty($data['username'])){ die('昵称不能为空'); }		
		$checkUsername = $model->checkUsername($data['username']);
		if(!$checkUsername){ die('昵称有误或已存在'); }
		
		if(empty($data['level'])){ die('代理等级未选择'); }		
		if(empty($data['pid'])){ $data['pid'] = $model->getAgId(); }
		if(empty($data['repass'])){ die('密码不能为空'); }
		if(empty($data['uid'])){ die('玩家ID不能为空'); }
		
		if($data['level'] != 2){
			die('代理等级有误');
		}
		
		$res = $model->doAdd($data);
		if($res){
			echo 'success';
		}else{
			echo '新增代理失败';
		}		
	}
	
	public function doZhuanyi(){
		die('已关闭');
		
		$data = request()->post();
		if(empty($data)){ die('参数有误'); }
		
		if(empty($data['aid'])){ die('代理ID有误'); }
		if(empty($data['fee'])){ die('金额参数有误'); }
		if(empty($data['type'])){ die('充值类型有误'); }
		
		$agent = new AdminModel;
		$fromaid = $agent->getAgId();
		$toaid = $data['aid'];		
		if($toaid == $fromaid){ die('不可转移给自己'); }
		
		$fromagentinfo = $agent->getAgentDetail($fromaid);		
		if(empty($fromagentinfo['uid'])){ die('转出代理 未绑定UID'); }
		$toagentinfo = $agent->getAgentDetail($toaid);		
		if(empty($toagentinfo['uid'])){ die('转至代理不存在 或 未绑定UID'); }
		//die($fromagentinfo['uid'].'-'.$toagentinfo['uid']);
		
		$user = new UserModel;
		$frominfo = $user->getUserInfo($fromagentinfo['uid']);
		$toinfo = $user->getUserInfo($toagentinfo['uid']);
		//die(json_encode($frominfo).'-'.json_encode($toinfo));
		
		if($data['type'] == '金币'){
			$res = $user->insertScore($frominfo['Account'],-$data['fee']);
			$res = $user->insertScore($toinfo['Account'],$data['fee']);
		}elseif($data['type'] == '房卡'){ 
			$res = $user->insertDiamond($frominfo['Account'],-$data['fee']);
			$res = $user->insertDiamond($toinfo['Account'],$data['fee']);
		}else{
			$res = false;
		}
				
		if($res){
			echo 'success';
		}else{
			echo '充值失败:'.json_encode($res);
		}		
	}

	public function commission()
    {
		$data = request()->post();
				
		if(empty($data['starttime']) || empty($data['endtime']) ){ 
			//$_time = strtotime("-1 day");
			$_time = strtotime("now");
			$starttime = date('Y-m-d',$_time).' 00:00:00';
			$endtime   = date('Y-m-d',$_time).' 23:59:59';
			$this->assign('starttime','');
			$this->assign('endtime','');
		}else{
			$starttime = $data['starttime'];
			$endtime   = $data['endtime'];
			$this->assign('starttime',$starttime);
			$this->assign('endtime',$endtime);
		}
		
		$starttime = strtotime($starttime);
		$endtime   = strtotime($endtime);
		
		if($starttime >= $endtime){ 
			echo '时间有误<br/>';
			echo '开始时间：'.$starttime.'---'.date('Y-m-d H:i:s',$starttime).'<br/>';
			echo '结束时间：'.$endtime.'---'.date('Y-m-d H:i:s',$endtime);
			die;
		}	
		
		$model = new AdminModel();
		$num = 10;
		$res = $model->getCommissionList($num,$starttime,$endtime);
		
		$this->assign('list',$res['list']);
		$this->assign('page',$res['page']);
						
        return $this->fetch();
    }
	
}
