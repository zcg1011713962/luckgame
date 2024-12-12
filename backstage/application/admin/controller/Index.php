<?php
namespace app\admin\controller;
use think\Controller;
use app\admin\controller\Parents;
use app\admin\model\AdminModel;
use app\admin\model\UserModel;
use app\admin\model\GameModel;
use app\admin\model\ConfigModel;
use app\agent\model\MarkModel;

class Index extends Parents
{
    public function index()
    {
		$model = new AdminModel;
		$admin = $model->getAdminInfo();
		$this->assign('username',$admin['username']);
		
		$ht_name =  ConfigModel::getSystemConfig()['SystemTitle']; //$model->getConfig('app.HT_NAME');
		$this->assign('ht_name',$ht_name);
        return $this->fetch();
    }
	
	public function welcome()
	{
		
		$adminmodel = new AdminModel;
		$admin = $adminmodel->getAdminInfo();
		$this->assign('username',$admin['username']);
		
		$model = new UserModel;
		$usercount = $model->getUserCount();
		$this->assign('usercount',$usercount);
                $usercount = $model->getMachineUserCount();
                $this->assign('machineUserCount',$usercount);
		$registercount = $model->totalRegisterNum();
		$this->assign('registercount',$registercount);
                $registercountweek = $model->totalWeekRegisterNum();
                $this->assign('registercountweek',$registercountweek);	
		
		$game = new GameModel;
		$gamecount = $game->getCount();
		$this->assign('gamecount',$gamecount);

		$logincount = $game->totalLoginNum();
		$this->assign('logincount',$logincount);
		
		
		$onlinecount = $game->getOnlineNum(0);
		$this->assign('onlinecount',$onlinecount['gameOnLineNumAll']);
	
		$betcount = $game->totalBetNum();
		$this->assign('betcount',$betcount);
		$betweekcount = $game->totalWeekBetNum();
		$this->assign('betweekcount',$betweekcount);

		$paycount = $game->totalPayNum();
		$this->assign('paycount',$paycount);
		$payweekcount = $game->totalWeekPayNum();
		$this->assign('payweekcount',$payweekcount);

		$paypricecount = $game->totalPayPrice();
		$this->assign('paypricecount',$paypricecount);
		$paypriceweekcount = $game->totalWeekPayPrice();
		$this->assign('paypriceweekcount',$paypriceweekcount);

		$taxList = json_decode(json_encode($adminmodel->getList1(100000000)),true);
		$taxcount = 0;
		foreach ($taxList['list']['data'] as $k => $v) {
			$taxcount += MarkModel::countTax($v['id'])['tax_total'];
		}
		$this->assign('taxcount',$taxcount);
		
	    return $this->fetch();
	}
	
	public function unicode()
	{
	    return $this->fetch();
	}
	
}
