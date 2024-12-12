<?php
namespace app\admin\model;
use think\Model;
use think\Db;
use think\facade\Cookie;
use think\facade\Config;
use app\admin\model\ConfigModel;

class IssueModel extends Model
{
    private $key='';
    private $apiurl= '';
    public function __construct(){
           parent::__construct();
	   // 读取配置信息
          $config = ConfigModel::getSystemConfig();
	  $this->apiurl = $config['GameServiceApi'];
           
    } 
   
    public function getConfig($flag=''){
	 if(empty($flag)){ return false; }
	 return Config::get($flag);
     
    }
   
  //FQA列表查询
   public function getFQAList($limit=30,$title="",$begin_time="",$end_time=""){
         $dbobj=Db::table('ym_manage.issue')->alias('i');
         if(!empty(trim($title))){
           $dbobj=$dbobj->where('i.title','like','%'.$title.'%');
         } 
         if(trim($begin_time)!=''){
              $dbobj=$dbobj->where('i.create_at',">=",$start_time);
          }
         if(trim($end_time)!=''){
              $dbobj = $dbobj->where('i.create_at',"<=",$end_time);
          }
          $dbobj->field(['id','title','content','created_at']);
          $dbobj=$dbobj->order('id desc');
          $dbobj=$dbobj->paginate($limit)->toArray();
          return $dbobj; 

   } 

 
  // 添加FQA记录
   public function doAdd($title,$content){
       $record=array(
         "title"=>$title,
         "content"=>$content,
         "created_at"=>date("Y-m-d H:i:s"),
        );
        $id=Db::table("ym_manage.issue")->insertGetId($record);
         $this->query("set autocommit=1");
        return $id; 
   }
 
  //基于ID获取FQA
   public function getFQAInfo($id){
       $record=Db::table("ym_manage.issue")->where("id=$id")->field(["*"])->find();
      return $record; 
  }

   //修改FQA
   public function editFQA($id,$title,$content){
      if(empty($title) || empty($id)||empty($content)){
         return false;
     } 
      $record=$this->getFQAInfo($id);
      if($record == null){
         return false;
      } 
      $record["title"]=$title;
      $record["content"]=$content;
      $ret=Db::table("ym_manage.issue")
          ->where('id',$id)
          ->update($record);
      $this->query("set autocommit=1");
      return $ret; 
     
   }

   //删除FQA
   public function delFQA($id){
      Db::table("ym_manage.issue")->where("id=$id")->delete();
      $this->query("set autocommit=1");
      return true;
   }

}


?>
