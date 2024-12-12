<?php
namespace app\agent\controller;
use think\Db;
use think\facade\Cookie;
use think\facade\Request;
use app\agent\model\UserModel;
use app\agent\model\AdminModel;
use app\agent\model\MarkModel;

class User extends Parents
{
    public function lists()
    {
		$user = new UserModel;
		$num = 10;//每页显示数
		
		$model = new AdminModel();
		//上级代理
		$a1 = $model->getAgId();
		$a23 = $model->get3ji_ids();
		$agents_ids = trim($a1.','.$a23, ',');
		$agents = $model->get3ji_list($agents_ids);
		$this->assign('agents',$agents);
		
		if( Request::isPost() ){
			$post = Request::post();
			$this->assign('searchstr',$post['searchstr']);
			$this->assign('starttime',$post['starttime']);
			$this->assign('endtime',  $post['endtime']);
			$this->assign('searchaid',$post['searchaid']);
			
			$res = $user->getUserList($num,$post,$agents_ids);
		}else{			
			$this->assign('searchstr','');
			$this->assign('starttime','');
			$this->assign('endtime',  '');
			$this->assign('searchaid','');
			
			$res = $user->getUserList($num,'',$agents_ids);
		}

		// 统计税收总额，按用户分
		$model = new AdminModel;
		$aid = $model->getAgId();
		$user_tax_total = MarkModel::countTax($aid);
		$res = json_decode(json_encode($res),true);

		foreach ($res['list']['data'] as $k => $v) {
			$res['list']['data'][$k]['user_tax_total'] = 0;
			if (!empty($user_tax_total['user_tax_total'][$v['uid']])) {
				$res['list']['data'][$k]['user_tax_total'] = $user_tax_total['user_tax_total'][$v['uid']]['total_tax'];
			}
		}

		$this->assign('list',$res['list']['data']);
		$this->assign('count',$res['count']);
		$this->assign('page',$res['page']);
		return $this->fetch();
    }
	
	public function dels()
	{
	    return $this->fetch();
	}
	
	public function rechargelist()
	{
		$this->assign('page','');
	    return $this->fetch();
	}
	
	public function add()
	{
	    return $this->fetch();
	}
	
	public function editinfo()
	{
	    return $this->fetch();
	}
	
	public function editpwd()
	{
		$id = request()->param('id');
		if(empty($id)){ $this->error('参数有误','admin\User\editpwd'); }
		
		$user = new UserModel;
		$info = $user->getUserInfo($id);
		$this->assign('info',$info);
		
	    return $this->fetch();
	}
	
	public function doeditpwd()
	{
		$data = request()->post();
		if(empty($data)){ die('参数有误'); }
		
		if(empty($data['username']) || empty($data['uid']) ){ die('用户参数有误'); }
		if(empty($data['newpass']) || empty($data['repass']) ){ die('密码参数有误'); }
		if($data['newpass'] != $data['repass']){ die('两次密码确认有误'); }
		
		$user = new UserModel;
		$res = $user->setUserPwd($data);
		if($res){
			echo 'success';
		}else{
			echo '修改密码失败';
		}
	}
	
	public function recharge(){
		
		$user = new UserModel;
		$num = 10;//每页显示数
		
		$res = $user->rechargeLogs($num);
		$this->assign('list',$res['list']);
		$this->assign('page',$res['page']);
		
		$count = $user->rechargeLogsCount();
		$this->assign('count',$count);
		
		$res1 = $user->rechargeLogs1($num);
		$this->assign('list1',$res1['list']);
		$this->assign('page1',$res1['page']);
		
		$count1 = $user->rechargeLogsCount1();
		$this->assign('count1',$count1);
		
		//获取实际金币房卡数值
		$model = new AdminModel;
		$aid = $model->getAgId();
		$agentinfo = $model->getAgentDetail($aid);
		if(empty($agentinfo['uid'])){ $this->error('转出代理 未绑定UID'); }		
		$info = $user->getUserInfo($agentinfo['uid']);
		$realnum = $info ? $model->getRealNum($info['Account']) : [];
		$realnum['score'] = empty($realnum['score']) ? 0 : $realnum['score'];
		$realnum['diamond'] = empty($realnum['diamond']) ? 0 : $realnum['diamond'];
		$this->assign('realnum',$realnum);
		
		return $this->fetch();
	}
	
	public function doRecharge(){
		$data = request()->post();
		if(empty($data)){ die('参数有误'); }
		
		if(empty($data['account'])){ die('用户参数有误'); }
		if(empty($data['fee'])){ die('金额参数有误'); }
		if(empty($data['type'])){ die('充值类型有误'); }
		
		$agent = new AdminModel;
		$fromaid = $agent->getAgId();
		$fromagentinfo = $agent->getAgentDetail($fromaid);		
		if(empty($fromagentinfo['uid'])){ die('转出代理 未绑定UID'); }
		
		$fromaid = $fromagentinfo['uid'];
		$toaid = $data['account'];
		if($toaid == $fromaid){ die('不可转移给自己'); }
		
		$user = new UserModel;
		$frominfo = $user->getUserInfo($fromaid);
		if(empty($frominfo['Account'])){ die('转出账号有误'); }
		//获取实际金币房卡数值
		$realnum = $agent->getRealNum($frominfo['Account']);
		if($data['type'] == '金币'){
			if($realnum['score'] < ($data['fee']*100) ){
				die('金币不足');
			}
		}elseif($data['type'] == '房卡'){ 
			if($realnum['diamond'] < ($data['fee']*1) ){
				die('房卡不足');
			}
			if($realnum['diamond'] <= ($data['fee']*1 + 10) ){
				die('房卡剩余不能少于10');
			}
		}
		
		$toinfo = $user->getUserInfo($toaid);
		if(empty($toinfo['Account'])){ die('转入账号有误'); }
		
		if($data['type'] == '金币'){
			$res = $user->insertScore($frominfo['Account'],-$data['fee']);
			if(!$res){				
				echo '充值失败:'.json_encode($res);die;
			}	
			$res = $user->insertScore($toinfo['Account'],$data['fee']);
		}elseif($data['type'] == '房卡'){ 
			$res = $user->insertDiamond($frominfo['Account'],-$data['fee']);
			if(!$res){
				echo '充值失败:'.json_encode($res);die;
			}	
			$res = $user->insertDiamond($toinfo['Account'],$data['fee']);
		}else{
			$res = false;
		}
		
		if($res){
			echo 'success';die;
		}else{
			echo '充值失败:'.json_encode($res);die;
		}		
	}


    public function addscore()
    {
        $id = request()->param('id');
        if(empty($id)){ $this->error('参数有误','admin\User\editpwd'); }

        $user = new UserModel();
        $info = $user->getUserInfo($id);
        $this->assign('info',$info);
        $this->assign('do',$info);

        return $this->fetch();
    }

    protected function getLoginUid(){
        return Cookie::get('agent_user_id');
    }

    public function doAddscore()
    {
        $data = request()->post();
        if(empty($data)){ die('参数有误'); }

        if(empty($data['username']) || empty($data['uid']) ){ die('用户参数有误'); }
        //if(empty($data['score']) || empty($data['addscore']) ){ die('金币参数有误'); }
        if( empty($data['addscore']) ){ die('金币参数有误'); }

        $user = new UserModel;
        // 检查代理本身有金币是否充足
        $agentId = $this->getLoginUid();
        $agentFind = Db::table('ym_manage.agentinfo')->where('aid' , $agentId)->find();
        if (!$agentFind){
            die('代理不存在');
        }
        $userFind = Db::table('gameaccount.newuseraccounts')->where('Id' , $agentFind['uid'])->find();
        if (!$userFind){
            die('代理玩家不存在');
        }
        $impFind = Db::table('gameaccount.userinfo_imp')->where('userId' , $agentFind['uid'])->find();
        if (!$impFind){
            die('代理金币不存在');
        }
        if ($impFind['score'] < $data['addscore']){
            die('代理金币不足');
        }
        $res = $user->setUserScore($data,1);
        if($res){
            // 给代理也扣除一下
            $data['username'] = $userFind['Account'];
            if(!$res = $user->setUserScore($data,2 , true)){
                echo '代理金币扣除失败:'.json_encode($res);
                exit();
            };
            echo 'success';
        }else{
            echo '金币增加失败:'.json_encode($res);
        }
    }

    public function delscore()
    {
        $id = request()->param('id');
        if(empty($id)){ $this->error('参数有误','admin\User\editpwd'); }

        $user = new UserModel;
        $info = $user->getUserInfo($id);
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


        $user = new UserModel;
        // 检查代理本身有金币是否充足
        $agentId = $this->getLoginUid();
        $agentFind = Db::table('ym_manage.agentinfo')->where('aid' , $agentId)->find();
        if (!$agentFind){
            die('代理不存在');
        }
        $userFind = Db::table('gameaccount.newuseraccounts')->where('Id' , $agentFind['uid'])->find();
        if (!$userFind){
            die('代理玩家不存在');
        }
        $impFind = Db::table('gameaccount.userinfo_imp')->where('userId' , $agentFind['uid'])->find();
        if (!$impFind){
            die('代理金币不存在');
        }
        $res = $user->setUserScore($data,2);
        if($res){
            // 给代理也扣除一下
            $data['username'] = $userFind['Account'];
            if(!$res = $user->setUserScore($data,1)){
                echo '代理金币增加失败:'.json_encode($res);
                exit();
            };
            echo 'success';
        }else{
            echo '金币减少失败:'.json_encode($res);
        }
    }
}
