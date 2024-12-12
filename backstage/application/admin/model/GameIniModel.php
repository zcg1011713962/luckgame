<?php
namespace app\admin\model;
use think\Model;
use think\Db;
use think\facade\Cookie;
use think\facade\Config;
use think\facade\Log;
use app\admin\utils\gameUtils;
use app\admin\model\ConfigModel;


class  GameIniModel extends Model
{
    protected $table="game_ini_field";
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
   
    public  function  getIniFields($limit=30,$searchstr='',$parent_id=-1){
        $dbobj = Db::table("ym_manage.game_ini_field");
        $dbobj=$dbobj->where('status=1')->order('id');
        if($parent_id>-1){
          $dbobj=$dbobj->where("parent_id","=",$parent_id);
        }
        if(!empty($searchstr) && strlen($searchstr)>0){
          $dbobj=$dbobj->where('name|remark','like','%'.$searchstr.'%');
        }

        $dbobj->field(['id','parent_id','name','remark']);
        $dbobj=$dbobj->paginate($limit)->toArray();
        return $dbobj;
    }
    public function getIniField($id){
        $dbobj=Db::table("ym_manage.game_ini_field")
              ->where('id',"=",$id);
        $dbobj->field(["id","parent_id","name","remark","status"]);
        $ret=$dbobj->find();
         return $ret;
   }

    public function addIniField($record){
        if(empty($record["name"])|| empty($record["remark"])){
          return false;
        }
        $flag=true;
        $params=array("parent_id"=>$record["parent_id"]?$record["parent_id"]:0,
           "name"=>$record["name"],
           "remark"=>$record["remark"]
         );
 
        //检测是否存在
        $dbobj=Db::table("ym_manage.game_ini_field")
              ->where('parent_id',"=",$params["parent_id"])
              ->where('name',"=",$params["name"]);
        $dbobj->field(["id","parent_id","name","remark","status"]);
        $ret=$dbobj->find();
        if($ret){ //存在
           $params["status"]=1;
           $dbobj=Db::table("ym_manage.game_ini_field");
           $flag=$dbobj->where("id","=",$ret["id"])->update($params);
        }else{
            $flag=$dbobj->insert($params);
        }
        $this->query("set autocommit=1");
        return $flag;
    }

    public function  updateIniField($record){
        $dbobj=Db::table("ym_manage.game_ini_field")
              ->where("id","=",$record["id"]);
        $ret=$dbobj->find();
        if($ret){
          $dbobj=Db::table("ym_manage.game_ini_field")
              ->where("id","=",$record["id"]);
          $record["status"]=1;
          $ret=$dbobj->update($record);
          $this->query("set autocommit=1");
        }else{
          $ret=false;
        } 
        return $ret;
    }

     public  function getGameIniConfig($gameid){
        $dbobj=Db::table("ym_manage.game_ini_record")->alias("r")
              ->leftJoin("ym_manage.game_ini_field f","r.field_id=f.id")
              ->where("r.game_id","=",$gameid)
              ->where("r.status=1");
        $dbobj->field(["r.id","r.game_id","r.field_id","r.value",'f.name','f.remark','f.parent_id']);
        $ret=$dbobj->select(); 
        return $ret;
     }

     public function delField($id){
        $dbobj=Db::table("ym_manage.game_ini_field")
              ->where("id","=",$id);
        $ret=$dbobj->find();
        if($ret){
            $dbobj=Db::table("ym_manage.game_ini_field")
              ->where("id","=",$id);
          $dbobj->update(array("status"=>2));
           $this->query("set autocommit=1");
         }else{
          return false;
        }

         return true;
     }
     public function addGameIniConfig($record){
        if(empty($record["game_id"]) || empty($record["field_id"]) || empty($record["value"])){
          return false;
        }
        $params=array("game_id"=>$record["game_id"],
            "field_id"=>$record["field_id"],
            "value"=>$record["value"]
        );
        //检测是否已经添加
        $dbobj=Db::table("ym_manage.game_ini_record")
              ->where("game_id","=",$params["game_id"])
              ->where("field_id","=",$params["field_id"]);
         $ret=$dbobj->field(["id","game_id","field_id"])->find();
        $flag=true; 
       if($ret){ //update
          $params["status"]=1;
        $dbobj=Db::table("ym_manage.game_ini_record")
              ->where("id","=",$ret["id"]);
          $flag=$dbobj->update($params);
        }else{
          $flag=Db::table("ym_manage.game_ini_record")->insert($params);
        }
        $this->query("set autocommit=1");
        return $flag;
        
     }

    public function getGameInfo($game_id){
       $dbobj=Db::table("la_ba.gambling_game_list")
             ->where("nGameId","=",$game_id)
             ->field(['nGameID as game_id','strGameName as name']);
       return $dbobj->find();
    }
    public function getIniGameId(){
       $dbobj=Db::table("ym_manage.game_ini_record")
             ->where("status=1")
             ->field(["game_id"])->find();
        return $dbobj;
    }

    public function delGameIniConfig($id){
        $dbobj=Db::table("ym_manage.game_ini_record")
              ->where("id","=",$id);
         $params=array("id"=>$id,"status"=>2);
         $flag=$dbobj->update($params);
         $this->query("set autocommit=1");
       return $flag;
    }
    public function getGameLists($limit=30,$searchstr=''){
       $dbobj=Db::table("la_ba.gambling_game_list")
             ->field(['nGameID as game_id','strGameName as name']);
       $dbobj=$dbobj->paginate($limit)->toArray();
       
       return $dbobj;
    }  

    public function getActivityLists($limit=30, $searchstr=''){
       $dbobj=Db::table('ym_manage.activity_page_config')
            ->where("status",">=","0");
       if(!empty($searchstr)){
         $dbobj=$dbobj->where('id|title','like',"%$searchstr%");
       }          
 
       $dbobj->field(['id','status','show_location','show_type','title','order','pic_group','game_address','start_time','end_time']);
 
        $dbobj=$dbobj->paginate($limit)->toArray();
       return  $dbobj;
       
    }  

    public function getActivity($id){
        $dbobj=Db::table('ym_manage.activity_page_config');
        $dbobj=$dbobj->where("id","=",$id)
             ->where("status",">=",0);
        $dbobj->field(["*"]);
        return $dbobj->find(); 
   }   
    public function saveActivity($record){
        $dbobj=Db::table('ym_manage.activity_page_config');
        if(isset($record["id"])){
           $dbobj=$dbobj->where("id","=",$record["id"]);
           $dbobj->update($record);
        }else{
           $dbobj->insert($record);
         }
         $this->query("set autocommit=1");
         return true;
    } 

    public function deleteActivity($id){
      $record=array("status"=>-1);
      $dbobj=Db::table('ym_manage.activity_page_config')
            ->where("id","=",$id)->update($record);
         $this->query("set autocommit=1");
         return true;
   }

   public function getLanguageList(){
       $dbobj=Db::table("ym_manage.language_detail")
             ->field(["id","code","name","remark"]);
      return $dbobj->select();
   }
   
   public function getLanguageInfo($id){
       $dbobj=Db::table("ym_manage.language_detail")
             ->where("id","=",$id)
             ->field(["id","name","code"]);
       return $dbobj->find(); 
   }
  
   public function getAcitivityLanguageInfo($id){
      return Db::table("ym_manage.activity_language_detail")
             ->where("id","=",$id)
             ->field(["id","title","activity_id","language_id","language","pic_url"])->find();
   }
   public function getActivityLanguage($limit=30,$activity_id){
       $dbobj=Db::table("ym_manage.activity_language_detail")
             ->where("activity_id","=",$activity_id)
             ->where("status=1")
             ->field(["id","activity_id","title","language_id","language","pic_url"]);
        $dbobj=$dbobj->paginate($limit)->toArray();
        return $dbobj;
       
   }
  
   public function saveActivityLanguage($record){
	   $dbobj=Db::table("ym_manage.activity_language_detail");
	   $flag=false;
           $record["status"]=1; 
	   if(isset($record["id"])){
		   $dbobj=$dbobj->where("id","=",$record["id"]);
        	   $dbobj->update($record);
	   }else{     
		   $dbobj->insert($record);
	   }
          $this->query("set autocommit=1");
          return true;
   }

   public  function deleteActivityLanguague($id){
        $record=array("id"=>$id,"status"=>2);
        $dbobj=Db::table("ym_manage.activity_language_detail")
              ->where("id","=",$id)
              ->update($record);
        $this->query("set autocommit=1");
        return true;
   }
       
}
?>
