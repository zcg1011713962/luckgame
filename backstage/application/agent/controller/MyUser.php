<?php
namespace app\agent\controller;
use think\Controller;
use think\facade\Cookie;
use think\facade\Request;
use app\agent\controller\Parents;
use app\agent\model\UserModel;
use app\agent\model\AdminModel;
use app\admin\model\ConfigModel;
use app\agent\model\GameModel;
use app\agent\model\MarkModel;

class MyUser extends Parents
{
	private $config;

	public function __construct() {
		parent::__construct();
		$this->config = ConfigModel::getSystemConfig();
	}

    public function lists()
    {
		$user = new UserModel;
		$num = 10;//每页显示数
        $createdUid = $this->getLoginUid();
        $map = [
            'ChannelType' => $createdUid
        ];

		if(Request::isPost() ){
			$post = Request::post();
			$this->assign('searchstr',$post['searchstr']);
			$res = $user->getMyUserList($num,array_merge($map , $post));
		}else{
			$this->assign('searchstr','');
			$res = $user->getMyUserList($num,$map);
		}

		// 统计税收总额，按用户分
		$model = new AdminModel;
		$aid = $model->getAgId();
		$user_tax_total = MarkModel::countTax($aid);
		$res = json_decode(json_encode($res),true);

		foreach ($res['list']['data'] as $k => $v) {
			$res['list']['data'][$k]['user_tax_total'] = 0;
			if (!empty($user_tax_total['user_tax_total'][$v['Id']])) {
				$res['list']['data'][$k]['user_tax_total'] = $user_tax_total['user_tax_total'][$v['Id']]['total_tax'];
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

    protected function getLoginUid(){
        return Cookie::get('agent_user_id');
    }
	
	public function doeditpwd()
	{
		$data = request()->post();
		if(empty($data)){ die('参数有误'); }
		
		if(empty($data['username']) || empty($data['uid']) ){ die('用户参数有误'); }
		if(empty($data['newpass']) || empty($data['repass']) ){ die('密码参数有误'); }
		if($data['newpass'] != $data['repass']){ die('两次密码确认有误'); }
		$user = new UserModel;
        $info = $user->getUserInfo($data['id']);
        if ($info['ChannelType'] != $this->getLoginUid()){
            echo '你没有权限修改';exit;
        }
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
		$realnum = $model->getRealNum($info['Account']);
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

    public function doCanLogin(){
        $data = request()->post();
        if(empty($data)){ die('参数有误'); }

        if(empty($data['i'])){ die('用户参数有误'); }
        if(!isset($data['t'])){ die('封禁参数有误'); }

        $user = new UserModel;
        $info = $user->getUserInfo($data['i']);
        if ($info['ChannelType'] != $this->getLoginUid()){
            echo '你没有权限修改';exit;
        }
        $res = $user->setUserFeng($data);
        if($res){
            echo 'success';
        }else{
            echo '封禁操作失败:'.json_encode($res);
        }
    }

    public function addUser(){
        $post = $this->request->post();
        $account = $post['account'];
        if (!$account){
            echo '必须输入账号';exit();
        }
        $nickname = $post['nickname'];
        if (!$nickname){
            echo '必须输入昵称';exit();
        }
        $password = $post['pass'];
        if (!$password){
            echo '必须输入密码';exit();
        }
        $createdUid = $this->getLoginUid();
        $time = time();
        $sign = 'register' . $account . $password . $time . $this->config['PrivateKey'];
        $sign = md5($sign);
        $url = $this->config['GameServiceApi']."/ml_api?act=register&accountname=" . $account . "&nickname=" . $nickname . "&pwd=" . $password . "&time=" . $time . "&agc=" . $createdUid . "&sign=" . $sign;
        $res = $this->_request($url , false , 'get' , null , 2);
        $res = json_decode($res , true);
        echo $res ? ($res['status'] == 0 ? 1 : $res['msg']) : '调用失败';
    }

	public function gameLineList() {
		$gameModel = new GameModel;
		$onlinecount = $gameModel->getOnlineNums();
		$this->assign('gameUserOnline',$onlinecount['user_list']);
		$this->assign('count',$onlinecount['count']);
		return $this->fetch();
	}
	
}
