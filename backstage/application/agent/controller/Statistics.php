<?php
namespace app\agent\controller;
use think\Controller;
use app\agent\controller\Parents;
use app\agent\model\StatisticsModel;
use app\agent\model\UserModel;
use app\agent\model\AdminModel;
use think\facade\Request;

class Statistics extends Parents
{
    public function recharge()
    {
		$stat = new StatisticsModel();
		$num = 10;
		
		$model = new AdminModel();
		$a1 = $model->getAgId();
		$a23 = $model->get3ji_ids();
		$agents_ids = trim($a1.','.$a23, ',');
		
		if( Request::isPost() ){
			$post = Request::post();
			$this->assign('starttime',$post['starttime']);
			$this->assign('endtime',  $post['endtime']);
			
			$res = $stat->getRecharge($num,$post,$agents_ids);
		}else{			
			$this->assign('starttime','');
			$this->assign('endtime',  '');
			
			$res = $stat->getRecharge($num,'',$agents_ids);
		}
		$this->assign('list',$res['list']);
		$this->assign('scoretotal',$res['scoretotal']);
		$this->assign('diamondtotal',$res['diamondtotal']);
		$this->assign('page',$res['page']);		
        return $this->fetch();
    }
	public function rechargelog()
	{
		$stat = new StatisticsModel();
		$num = 10;
		
		$type = Request::param('type');
				
		//上级代理
		$model = new AdminModel();
		$a1 = $model->getAgId();
		$a23 = $model->get3ji_ids();
		$agents_ids = trim($a1.','.$a23, ',');
		//$agents = $model->get3ji_list($agents_ids);	
		$agents = $model->get3ji_list($a1);
		$this->assign('agents',$agents);
		
		if( Request::isPost() ){
			$post = Request::post();
			$this->assign('searchstr',$post['searchstr']);
			$this->assign('starttime',$post['starttime']);
			$this->assign('endtime',  $post['endtime']);
			$this->assign('searchaid',$post['searchaid']);
			
			$res = $stat->getUserList_new($num,$post,$agents_ids,$type,$a1);
		}else{			
			$this->assign('searchstr','');
			$this->assign('starttime','');
			$this->assign('endtime',  '');
			$this->assign('searchaid','');
			
			$res = $stat->getUserList_new($num,'',$agents_ids,$type,$a1);
		}
		$this->assign('list',$res['list']);
		$this->assign('count',$res['count']);
		$this->assign('page',$res['page']);
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
