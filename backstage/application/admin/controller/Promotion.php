<?php
namespace app\admin\controller;
use think\facade\Request;
use app\admin\controller\Parents;
use app\admin\model\UserModel;
use app\admin\model\AdminModel;
use app\admin\model\PromoterModel;
use app\admin\model\ConfigModel;

class Promotion extends Parents{
   
   
    
   //推广码列表
   public function codelists($robot=0){
       $userModel = new UserModel();
       $this->assign('robot' , $robot);
       $this->assign('breadcrumb_name' , "推荐码列表");      
       $limit =  isset($params['limit']) && !empty($params['limit']) ? intval($params['limit']) : 30;
       $res=$userModel->getInviteCodeList($limit);
       $this->assign('count',$res['total']);
       return $this->fetch();
   }
   public function getcodelists($robot=0){
      $params     = request()->param();
      $limit =  isset($params['limit']) && !empty($params['limit']) ? intval($params['limit']) : 30;
        $searchstr = !empty($params['searchstr']) ? $params['searchstr'] : '';
	$begin_time=!empty($params["begin_time"])?$params["begin_time"]:"";
        $end_time = !empty($params["end_time"])?$params["end_time"]:"";
        $invite_code = !empty($params["invite_code"])?$params["invite_code"]:"";
        
      $userModel = new UserModel();
      $res=$userModel->getInviteCodeList($limit,$searchstr,$robot,$begin_time,$end_time,$invite_code);
        return ['code'=>0,'count'=>$res["total"],"numbers"=>$res["numbers"],"golds"=>$res["golds"],'data'=>$res["data"],"msg"=>"ok"];      
   }    
  
   public function userlists($robot=0){
        

   }
 
}

?>
