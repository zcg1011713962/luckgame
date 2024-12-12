<?php
namespace app\admin\controller;
use think\Controller;
use app\admin\controller\Parents;
use app\admin\model\AdminModel;
use app\agent\model\MarkModel;

class Admin extends Parents
{
    public function lists()
    {
		$model = new AdminModel();
		$num = 10;
		$res = $model->getList($num);
		$this->assign('list',$res['list']);
		$this->assign('page',$res['page']);
		
		$count = $model->getCount();
		$this->assign('count',$count);
		
        return $this->fetch();
    }
	public function lists1()
	{
		$model = new AdminModel();
		$num = 10;
		$res = $model->getList1($num);
		$res = json_decode(json_encode($res),true);
		foreach ($res['list']['data'] as $k => $v) {
			$res['list']['data'][$k]['user_tax_total'] = MarkModel::countTax($v['id'])['tax_total'];
		}

		$this->assign('list',$res['list']['data']);
		$this->assign('page',$res['page']);
		
		$count = $model->getCount1();
		$this->assign('count',$count);
		
	    return $this->fetch();
	}
	
	public function add()
	{
	    return $this->fetch();
	}
	
	public function doAdd(){
		$data = request()->post();
		if(empty($data)){ die('参数有误'); }
		
		if(empty($data['username'])){ die('账号不能为空'); }
		// if(empty($data['uid'])){ die('玩家ID不能为空'); }
		if(empty($data['pass']) || empty($data['repass'])){ die('密码有误'); }
		// if( isset($data['isdaili']) && ($data['isdaili']=='on') ){
		// 	$data['isagent'] = 1; 
		// }else{
		// 	$data['isagent'] = 0;
		// }

		// if( isset($data['top_agent']) && ($data['top_agent']=='on') ){
		// 	$data['top_agent'] = 1; 
		// }else{
		// 	$data['top_agent'] = 0;
		// }
		
		$user = new AdminModel;

		// $check = $user->checkUid($data['uid']);
		// if(!$check){
		// 	echo '玩家ID填写有误';die;
		// }

		$res = $user->doAdd($data);
		if($res){
			echo 'success';
		}else{
			echo '新增管理员失败';
		}		
	}
		
	public function edit()
	{
		$id = request()->param('id');
		if(empty($id)){ $this->error('参数有误','admin\Admin\edit'); }
		
		$user = new AdminModel;
		$info = $user->getAdminInfo($id);
		$this->assign('info',$info);
		
		return $this->fetch();
	}
	
	public function doEdit(){
		$data = request()->post();
		if(empty($data)){ die('参数有误'); }
		
		if(empty($data['username']) || empty($data['adminid'])){ die('账号不能为空'); }
		if(empty($data['pass']) || empty($data['repass'])){ die('密码有误'); }
		// if( isset($data['isdaili']) && ($data['isdaili']=='on') ){
		// 	$data['isagent'] = 1; 
		// }else{
		// 	$data['isagent'] = 0;
		// }
		// if( isset($data['top_agent']) && ($data['top_agent']=='on') ){
		// 	$data['top_agent'] = 1; 
		// }else{
		// 	$data['top_agent'] = 0;
		// }
		
		$user = new AdminModel;
		$res = $user->doEdit($data);
		if($res){
			echo 'success';
		}else{
			echo '编辑管理员失败';
		}		
	}
	
	public function doDel(){
		$data = request()->post();
		if(empty($data)){ die('参数有误'); }
		
		if(empty($data['id'])){ die('参数有误'); }
		
		$user = new AdminModel;
		$res = $user->doDel($data);
		if($res){
			echo 'success';
		}else{
			echo '编辑管理员失败';
		}		
	}
	
	public function agentInfo(){
		$data = request()->param();
		if(empty($data)){ die('参数有误'); }		
		if(empty($data['id'])){ die('参数有误'); }
		
		$user = new AdminModel;
		$info = $user->getAgentInfo($data['id']);
		//var_dump($info);
		$this->assign('info',$info);
		
		return $this->fetch('agentinfo');
	}
	
}
