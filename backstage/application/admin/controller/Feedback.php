<?php
namespace app\admin\controller;
use think\Db;
use think\Controller;
use think\facade\Request;
use think\facade\Config;
use app\admin\controller\Parents;
use app\admin\model\FeedbackModel;
use app\admin\model\ConfigModel;

class Feedback extends Parents
{
   
   private $config;
   public function __construct(){
        parent::__construct();
        //$this->config = ConfigModel::getSystemConfig();

   }
   
   public  function lists(){
      $this->assign("breadcrumb_name","意见反馈列表");
      return $this->fetch();
   }

   public function getlists(){
      $model = new FeedbackModel();
      $params = request()->param();
      $userId = !empty($params["user_id"])?$params["user_id"]:"";
      $searchstr=!empty($params["searchstr"])?$params["searchstr"]:"";
     // $status=!empty($params["status"])?$param["status"]:"-1";
      $begin_time=!empty($params["begin_time"])?$params["begin_time"]:"";
      $end_time = !empty($params["end_time"])?$params["end_time"]:"";
       $ret=$model->getList($params["limit"],$searchstr,$begin_time,$end_time);
        return ["code"=>0,"count"=>$ret["total"],"data"=>$ret["data"],"msg"=>"ok"];  
       

   }

   public function edit(){
        $id=request()->param('id');
        if(empty($id)){
           $this->error('参数有误','admin\Feedback\edit'); 
        }
        $model=new FeedbackModel();
        $info=$model->getFeedbackInfo($id);
        $this->assign("info",$info);
        return $this->fetch();
   }

   public function doEdit(){
       $id=request()->param("id");
       $content=request()->param("resolve_content");
       $model = new FeedbackModel;
       $ret=$model->editFeedback($id,$content);
        
       if($ret){
         echo 'success';
       }else{
          echo 'error';
       }
   }   

   public function doDel(){
        $id=request()->param('id');
        if(empty($id)){
           $this->error('参数有误','admin\Feedback\doDel'); 
        }
        $model=new FeedbackModel();
        $ret=$model->delFeedback($id);
      if($ret){
         return "success";
       }else{
          return "error";
      } 
   } 

}
 
?>
