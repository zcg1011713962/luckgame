<?php
namespace app\admin\model;
use think\Model;
use think\Db;
use think\facade\Cookie;
use think\facade\Config;
use app\admin\model\ConfigModel;

class FeedbackModel extends Model
{
    private $key='';
    private $apiurl= '';
    public function __construct(){
           parent::__construct();
	  $this->adminid = Cookie::get('admin_user_id');
	   // 读取配置信息
          $config = ConfigModel::getSystemConfig();
	  $this->apiurl = $config['GameServiceApi'];
           
    } 
   
    public function getConfig($flag=''){
	 if(empty($flag)){ return false; }
	 return Config::get($flag);
     
    }
   
   //FeedBack列表查询
   public function getList($limit=30,$searchstr="",$begin_time="",$end_time=""){
         $dbobj=Db::table('ym_manage.feedback')->alias('i')
               ->leftJoin("gameaccount.newuseraccounts u",'i.user_id=u.Id');
         if(!empty(trim($searchstr))){
           $dbobj=$dbobj->where('i.content','like','%'.$searchstr.'%');
         } 
         if(trim($begin_time)!=''){
              $dbobj=$dbobj->where('i.created_at',">=",$begin_time);
          }
         if(trim($end_time)!=''){
              $dbobj = $dbobj->where('i.created_at',"<=",$end_time);
          }
          $dbobj->field(['i.id','i.status','i.content','i.created_at','i.resolve_content',"i.resolve_time","i.resolve_uid",'u.nickname']);
          $dbobj->where("i.is_delete","=","0"); 
         $dbobj=$dbobj->order('i.id desc');
          $dbobj=$dbobj->paginate($limit)->toArray();
          return $dbobj; 

   } 
 
  //基于ID获取FQA
   public function getFeedBackInfo($id){
       $dbobj=Db::table('ym_manage.feedback')->alias('i')
               ->leftJoin("gameaccount.newuseraccounts u",'i.user_id=u.Id');
     $dbobj->field(['i.id','i.content','i.created_at','i.status','i.resolve_content',"i.resolve_time","i.resolve_uid",'u.nickname']);
      $record=$dbobj->where("i.id","=",$id)->where("i.is_delete=0")->find();
      return $record; 
  }
   public function delFeedback($id){
       if(empty($id)){
           return false;
        }
      $record=$this->getFeedBackinfo($id);
      if($record == null){
         return false;
      }
      $record=array("id"=>$id,"is_delete"=>1);
      $ret=Db::table("ym_manage.feedback")->where('id','=',$id)
           ->update($record);
      $this->query("set autocommit=1");
      return $ret; 
       
   }
   //修改FQA
   public function editFeedback($id,$content){
      if( empty($id)||empty($content)){
         return false;
     } 
      $record=$this->getFeedBackinfo($id);
     if($record == null){
         return false;
      }
      $record=array("id"=>$id); 
      $record["resolve_content"]=$content;
      $record["resolve_uid"]=$this->adminid;
      $record["resolve_time"] = date("Y-m-d H:i:s");
      $record["status"]=1;
      $ret=Db::table("ym_manage.feedback")
          ->where('id',"=",$id)
          ->update($record);
      $this->query("set autocommit=1");
      return $ret; 
     
   }


}


?>
