<?php
namespace app\admin\controller;
use think\Controller;
use app\admin\controller\Parents;
use app\admin\model\StatisticsModel;

class Statistics extends Parents
{
    public function recharge()
    {
		$model = new StatisticsModel();
		$fees = $model->getCZTotalfee();
		$this->assign('fees',$fees);
		
		$this->assign('searchfee',0);
        return $this->fetch();
    }
	
	public function doSearchCZfee(){
		$return = array('status'=>0,'msg'=>'');
		
		$data = request()->post();
		if(empty($data)){ 
			$return['msg'] = '参数有误';
			echo json_encode($return);die;
		}
		
		if(empty($data['starttime']) || empty($data['endtime']) ){ 
			$return['msg'] = '参数有误';
			echo json_encode($return);die;
		}
		
		$starttime = strtotime($data['starttime']);
		$endtime = strtotime($data['endtime']);
		//$return['msg'] = $starttime.'--'.$endtime;echo json_encode($return);die;
			
		if($starttime >= $endtime){ 
			$return['msg'] = '时间有误';
			echo json_encode($return);die;
		}
		
		$user = new StatisticsModel;
		$res = $user->getCZfeeByWhere($starttime,$endtime);
		if($res){
			$return['status'] = 1;
			$return['msg'] = $res['addfee'].' - '.$res['delfee'].' = '.$res['totalfee'];
			echo json_encode($return);die;
		}else{
			$return['msg'] = '修改密码失败';
			echo json_encode($return);die;
		}
	}
	
	public function kucun()
	{
		$model = new StatisticsModel();
		$list = $model->getKClists();
		$this->assign('list',$list);
		
	    return $this->fetch();
	}
	
	public function searchKC()
	{
		$id = request()->param('id');
		if(empty($id)){ $this->error('参数有误','admin\Statistics\searchKC'); }
		
		$model = new StatisticsModel();
		$kucun = $model->searchKC($id);
		$this->assign('kucun',$kucun);
		
		$this->assign('searchfee',0);
	    return $this->fetch();
	}
	
	public function dosearchKC(){
		$return = array('status'=>0,'msg'=>'');
		
		$data = request()->post();
		if(empty($data)){ 
			$return['msg'] = '参数有误';
			echo json_encode($return);die;
		}
		
		if(empty($data['starttime']) || empty($data['endtime']) ){ 
			$return['msg'] = '参数有误';
			echo json_encode($return);die;
		}
		
		$starttime = strtotime($data['starttime']);
		$endtime = strtotime($data['endtime']);
		//$return['msg'] = $starttime.'--'.$endtime;echo json_encode($return);die;
			
		if($starttime >= $endtime){ 
			$return['msg'] = '时间有误';
			echo json_encode($return);die;
		}
		
		$user = new StatisticsModel;
		$res = $user->getKCByWhere($starttime,$endtime);
		if($res){
			$return['status'] = 1;
			$return['msg'] = json_encode($res);
			echo json_encode($return);die;
		}else{
			$return['msg'] = '查询失败';
			echo json_encode($return);die;
		}
	}
	
}
