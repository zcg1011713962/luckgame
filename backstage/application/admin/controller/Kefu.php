<?php
namespace app\admin\controller;
use think\Db;
use think\Controller;
use think\facade\Request;
use think\facade\Config;
use app\admin\controller\Parents;
use app\admin\model\KefuModel;
use app\admin\model\ConfigModel;

class Kefu extends Parents
{
	private $config;
	public function __construct() {
		parent::__construct();
		$this->config = ConfigModel::getSystemConfig();
	}
    public function lists()
    {
		$model = new KefuModel();
		$num = 10;
		$res = $model->getList($num);
		$this->assign('list',$res['list']);
		$this->assign('page',$res['page']);
		
		$count = $model->getCount();
		$this->assign('count',$count);
		
        return $this->fetch();
    }

	public function wlists() {
		$model = new KefuModel();
		$num = 10;
		$res = $model->getList($num,1);
		$this->assign('list',$res['list']);
		$this->assign('page',$res['page']);
		$count = $model->getCount(1);
		$this->assign('count',$count);
		return $this->fetch();
	}
		
	public function add()
	{
	    return $this->fetch();
	}

	public function wadd() {
		return $this->fetch();
	}
	
	public function doAdd(){
		$data = request()->post();
		if(empty($data)){ die('参数有误'); }
		
		if(empty($data['username'])){ die('账号不能为空'); }
		if(empty($data['uid'])){ die('玩家ID不能为空'); }
		if(empty($data['pass']) ){ die('密码有误'); }
		if( isset($data['isdaili']) && ($data['isdaili']=='on') ){
			$data['isagent'] = 1; 
		}else{
			$data['isagent'] = 0;
		}
		
		$user = new KefuModel;
		
		$res = $user->doAdd($data);
		if($res){
			echo 'success';
		}else{
			echo '新增失败';
		}		
	}

	public function dowAdd() {
		$params = request()->post();
		$file = request()->file('avatar');
		if (empty($params['customer_url'])) {return $this->_error('客服外链地址不能为空');}
		if (empty($params['username'])) {return $this->_error('客服昵称不能为空');}
		$image = $file->validate(['ext'=>'jpg,png,gif'])->move( './uploads');
		if (!$image) {return $this->_error('上传图片失败');}
		$params['isagent'] = isset($params['isdaili']) && ($params['isdaili']=='on') ? 1 : 0;
		$url = '/uploads/';
        $saveName = str_replace("\\","/",$image->getSaveName());

		$customer = new KefuModel;
		if ($customer->dowAdd($params, $url.$saveName)) {
                        $customer->query("SET AUTOCOMMIT=1");
			return $this->_success();
		}

		return $this->_error('添加失败');
		
	}
		
	public function edit()
	{
		$id = request()->param('id');
		if(empty($id)){ $this->error('参数有误','admin\Kefu\edit'); }
		
		$user = new KefuModel;
		$info = $user->getAdminInfo($id);
		$this->assign('info',$info);
		
		return $this->fetch();
	}

	public function wedit()
	{
		$id = request()->param('id');
		if(empty($id)){ $this->error('参数有误','admin\Kefu\edit'); }
		
		$user = new KefuModel;
		$info = $user->getAdminInfo($id);
		$this->assign('info',$info);
		
		return $this->fetch();
	}
	
	public function doEdit(){
		$data = request()->post();
		if(empty($data)){ die('参数有误'); }
		
		if(empty($data['username']) || empty($data['adminid'])){ die('账号不能为空'); }
		if(empty($data['pass']) ){ die('密码有误'); }
		if( isset($data['isdaili']) && ($data['isdaili']=='on') ){
			$data['isagent'] = 1; 
		}else{
			$data['isagent'] = 0;
		}
		
		$user = new KefuModel;
		$res = $user->doEdit($data);
		if($res){
                      $user->query("SET AUTOCOMMIT=1");
			echo 'success';
		}else{
			echo '编辑失败';
		}		
	}
	
	public function dowEdit() {

		$params = request()->post();
		$file = request()->file('avatar');
		$url = '';
		$saveName = '';
		if (empty($params['customer_url'])) {return $this->_error('客服外链地址不能为空');}
		if (empty($params['username'])) {return $this->_error('客服昵称不能为空');}
		if (empty($params['adminid'])) {return $this->_error('账号不能为空');}
		if ($file) {
			$image = $file->validate(['ext'=>'jpg,png,gif'])->move( './uploads');
			if (!$image) {return $this->_error('上传图片失败');}
			$url = '/uploads/';
			$saveName = str_replace("\\","/",$image->getSaveName());
		}
		$params['isagent'] = isset($params['isdaili']) && ($params['isdaili']=='on') ? 1 : 0;

		$customer = new KefuModel;
		if ($customer->dowEdit($params, $url.$saveName)) {
			return $this->_success();
		}

		return $this->_error('修改失败');
	}
	
	public function doDel(){
		$data = request()->post();
		if(empty($data)){ die('参数有误'); }
		
		if(empty($data['id'])){ die('参数有误'); }
		
		$user = new KefuModel;
		$res = $user->doDel($data);
		if($res){
			echo 'success';
		}else{
			echo '编辑管理员失败';
		}		
	}

	public function addscore()
	{
		$id = request()->param('id');
		if(empty($id)){ $this->error('参数有误','admin\User\editpwd'); }
		
		$user = new KefuModel;
		$info = $user->getAdminInfo($id);
		$this->assign('info',$info);
		
	    return $this->fetch();
	}
	
	public function doAddscore()
	{
		$data = request()->post();
		if(empty($data)){ die('参数有误'); }
		
		if(empty($data['account']) || empty($data['uid']) ){ die('用户参数有误'); }
		if( empty($data['addscore']) ){ die('金币参数有误'); }
				
		$user = new KefuModel;
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
		
		$user = new KefuModel;
		$info = $user->getAdminInfo($id);
		$this->assign('info',$info);
		
	    return $this->fetch();
	}
	
	public function doDelscore()
	{
		$data = request()->post();
		if(empty($data)){ die('参数有误'); }
		
		if(empty($data['account']) || empty($data['uid']) ){ die('用户参数有误'); }
		if( empty($data['addscore']) ){ die('金币参数有误'); }
				
		$user = new KefuModel;
		$res = $user->setUserScore($data,2);
		if($res){
			echo 'success';
		}else{
			echo '金币减少失败:'.json_encode($res);
		}
	}
	
}
