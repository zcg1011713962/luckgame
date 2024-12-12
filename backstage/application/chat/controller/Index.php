<?php
namespace app\chat\controller;
use think\Controller;
use app\chat\controller\Parents;
use app\chat\model\AdminModel;
use app\chat\model\UserModel;
use app\chat\model\GameModel;
use think\Loader;

class Index extends Parents
{
    public function index()
    {
		$model = new AdminModel;
		$admin = $model->getAdminInfo();
		$this->assign('username',$admin['name']);
		
		$ht_name = $model->getConfig('app.HT_NAME');
		$this->assign('ht_name',$ht_name);
		
        return $this->fetch();
    }
	
	public function welcome()
	{
	    return $this->fetch();
	}
	
}
