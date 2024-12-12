<?php
namespace app\admin\controller;
use think\Controller;
use think\Db;
use think\facade\Log;
use think\facade\Request;
use app\admin\controller\Parents;
use app\admin\model\GameIniModel;
use app\admin\model\ConfigModel;
use app\admin\utils\awsFileUtils;
class Games extends Parents
{
   //添加game ini field
   public function  saveGameIniField(){
      $params= request()->post();
      #$validate = new gameIniValidate()
      //check params   
   }

    public  function fieldlists(){
      $this->assign("breadcrumb_name","游戏配置字典管理");
       $model= new GameIniModel;
       $rootFields=$model->getIniFields(100,"",0);
       $this->assign("root_fields",$rootFields["data"]);

      return $this->fetch(); 
    } 

    public function getfieldlists(){
       $param=request()->param();
     
       $model=new GameIniModel;
       $searchstr=!empty($param["searchstr"])?$param["searchstr"]:'';
       $parent_id=isset($param["parent_id"])?$param["parent_id"]:'-1';
       $ret=$model->getIniFields($param["limit"],$searchstr,$parent_id);
       return ["code"=>0,"count"=>$ret["total"],"data"=>$ret["data"],"msg"=>"ok"];        
    }

    public function editfield(){
       $params=request()->param();
       $model= new GameIniModel;
       $rootFields=$model->getIniFields(100,"",0);
       $this->assign("root_fields",$rootFields["data"]);
       if(isset($params["id"]) && $params["id"] >0){
         $field=$model->getIniField($params["id"]);
         $this->assign("field",$field);
       }else{
         $this->assign("field",array("parent_id"=>0));
        }
       return $this->fetch();        
    }
    public function doEditField(){
      $param=request()->param();
      if(empty($param["name"]) || empty($param["remark"])){
        $this->error("参数错误","/admin/games/doEditField");
      }
      $parent_id=$param["parent_id"];
      $name=$param["name"];
      $remark=$param["remark"];
      $field=array("id"=>$param["id"],"name"=>$name,"remark"=>$remark,"parent_id"=>$parent_id);
      $model= new GameIniModel;
      $flag=$model->addIniField($field);
      if($flag){
         echo "success";
      }else{
         echo "fail";
      }
    }
    public function dodelfield(){
      $param=request()->param();
      if(empty($param["id"])){
         $this->error('参数有误','admin\games\doDelField');
       }else{
        echo "success";
      }
      $model=new GameIniModel;
      $model->delField($param["id"]);
     echo "success"; 
     
    }

    public function gamelists(){
       $this->assign("breadcrumb_name","游戏配置列表");
       return $this->fetch(); 
   }

   public function getgamelists(){
       $param=request()->param();
       $model=new GameIniModel;
       $searchstr=!empty($param["searchstr"])?$param["searchstr"]:'';
       $ret=$model->getGameLists($param["limit"],$searchstr);
       $ids=$model->getIniGameId();
       foreach($ret["data"] as $k=>$v){
         $ret["data"][$k]["status"]=0;
       } 
       return ["code"=>0,"count"=>$ret["total"],"data"=>$ret["data"],"msg"=>"ok"];        
   }
  
   public function getgameini(){
      $param=request()->param();
      if(empty($param["game_id"])){
        $this->error("参数错误","/admin/games/getgameini");
      }
       $model= new GameIniModel;
       $record=$model->getGameIniConfig($param["game_id"]);
      $rootFields=$model->getIniFields(100,"",0);
        
      
   }
   
   public function  getChildFields(){
     $params=request()->param();
     if(empty($params["parent_id"])){
        $params["parent_id"]=0;
     }
     $model=new GameIniModel();
     $fields=$model->getIniFields(1000,"",$params["parent_id"]);
     return $fields["data"];
   }

   public function getreviewgameini(){
        $params=request()->param();
        if(empty($params["game_id"])){
            $this->error("参数错误","/admin/games/getReivewGameIni");
        }
        $model = new GameIniModel();
        $fields=$model->getIniFields(100,"",0);
        $fields=$fields["data"];
        $ini_items=$model->getGameIniConfig($params["game_id"]);
        $texts=array();
        foreach($fields as $parent_id=>$item){
           $texts[$item["id"]]=array("name"=>$item["name"],"items"=>array());
        }  
        foreach($ini_items as $k=>$item){
           $parent_id=$item["parent_id"];
           $field_name=$item["name"];
           $value=$item["value"];
           $texts[$parent_id]["items"][]=$field_name." = $value";
        }
        $text="";
        foreach($texts as $key=>$item){
          $text.="[".$item["name"]."]\n";
          foreach($item["items"] as $val){
             $text.=$val."\n";
          }
        }
        return $text;
             
       
   }


    public function editgameini()
    {
        $param = request()->param();
        if (empty($param["game_id"])) {
            $this->error("参数错误", "/admin/games/editgameini");
        }
        $model = new GameIniModel();
        $game = $model->getGameInfo($param["game_id"]);

        $rootFields = $model->getIniFields(100, "", 0);
        $this->assign("root_fields", $rootFields["data"]);

        $fields = $model->getIniFields(1000, "", -1);
        $dict = $this->field2Dict($fields["data"]);
        $this->assign("fields", json_encode($dict));
        $this->assign("game", $game);

        $record = $model->getGameIniConfig($param["game_id"]);
        $fieldnodes = array();
        foreach ($rootFields["data"] as $val) {
            $fieldnodes[$val["id"]] = $val;
        }
        foreach ($record as $key => $item) {
            $record[$key]["parent_name"] = $fieldnodes[$item["parent_id"]]["name"];
        }
        $this->assign("game_ini", $record);

        if(request()->isAjax()){
            return ["code"=>0,"data"=>$record,"msg"=>"ok"];
        }

        return $this->fetch();
    }

    public function doEditGameini()
    {
        $param = request()->param();
        if (empty($param["game_id"]) || empty($param["field_id"]) || empty($param["field_value"])) {
            $this->error("参数错误", "/admin/games/doeditgameini");
        }
        $model = new  GameIniModel;
        $record = array("game_id" => $param["game_id"], "field_id" => $param["field_id"], "value" => $param["field_value"]);
        $flag = $model->addGameIniConfig($record);
        if ($flag) {
            return "success";
        } else {
            return "fail";
        }
    }

   public function delGameIni(){
      $param=request()->param();
      if(empty($param["id"] )){

         $this->error("参数错误","/admin/games/delGameIni");
       }
        $model= new GameIniModel;
       $flag=$model->delGameIniConfig($param["id"]);
     if($flag){
         return  "success";
       }else{
         return "fail";
      }
   }
   
 
    public  function activitylists(){
      $this->assign("breadcrumb_name","活动管理");

      return $this->fetch(); 
    } 

   public function getactivitylists(){
      $param=request()->param();
      $model = new GameIniModel;
       $searchstr=!empty($param["searchstr"])?$param["searchstr"]:'';
       $ret=$model->getActivityLists($param["limit"],$searchstr);
       return ["code"=>0,"count"=>$ret["total"],"data"=>$ret["data"],"msg"=>"ok"];        
      #return ["code"=>0,"count"=>0,"data"=>null,"msg"=>"ok"];        
   }
   
   public function  addactivity(){
      return $this->fetch();
   }

   public function editactivity(){
      $params=request()->param();
      if(!isset($params["id"]) ||empty($params["id"])){
          $this->error("参数错误","/admin/games/editactivity");
      }
      $model = new GameIniModel();
      $record=$model->getActivity($params["id"]);
      $this->assign("record",$record);
      return $this->fetch();
   }

   public function delactivity(){
       $params=request()->param();
       do{
          if(empty($params["id"])){
             $this->error("参数错误","/admin/games/delactivity");
          }
          $model=new GameIniModel();
          $model->deleteActivity($params["id"]);

       }while(false);
       return array("code"=>200,"msg"=>"success");   
   }

 
   public function saveactivity(){
      $flag=false;
      $params=request()->param();
      do{
        if(empty($params["title"])
           ||empty($params["game_address"])
           ||empty($params["start_time"])
           ||empty($params["end_time"])
           ){
          $this->error("参数错误","/admin/games/saveactibity");
        }
        $fields=array("id","show_location","status","title","start_time","end_time",
          "order","game_address","time_display","show_type");
        $record=array();
        foreach($fields as $field){
            if(isset($params[$field])){
               $record[$field]=$params[$field];
            }
        }
        if(empty($record["id"])){
          unset($record["id"]);
        }
        $model = new GameIniModel();
        $flag=$model->saveActivity($record);

      }while(false);
       return array("code"=>200,"msg"=>"success");   
   }

   public function activitylanguagelist(){
      $param=request()->param();
      if(empty($param["id"])){
         $this->error("参数错误","/admin/games/activitylanguagelist");
      } 
       $this->assign("breadcrumb_name","活动配置"); 
      //$model= new GameIniModel();
      //$record=$model->getActivityLanguage($activity_id=$param["id"]);
      $this->assign("activity_id",$param["id"]);
     return $this->fetch();
 
   }
   public function getactivitylanguagelist(){
      $param=request()->param();
      if(empty($param["id"])){
         $this->error("参数错误","/admin/games/activitylanguagelist");
      }
      $model= new GameIniModel();
      $ret=$model->getActivityLanguage($param["limit"],$param["id"]);
      // $this->assign("activity_id",$param["id"]);
       return ["code"=>0,"count"=>$ret["total"],"data"=>$ret["data"],"msg"=>"ok"];        
      //return ["code"=>0,"count"=>$ret["total"],"data"=>$ret["data"],"msg"=>"ok"];        
   }

   public function addactivitylanguage(){
       $param=request()->param();
       if(empty($param["id"])){
         $this->error("参数错误","/admin/games/addactivitylanguage");
      }
      $model=new GameIniModel;
      $language = $model->getLanguageList();
      $this->assign("activity_id",$param["id"]);
      $this->assign("languages",$language);
      return $this->fetch();
   }

   public function delactivitylanguage(){
       $param=request()->param();
       if(empty($param["id"])){
         $this->error("参数错误","/admin/games/addactivitylanguage");
      }
      $model=new GameIniModel;
      $model->deleteActivityLanguague($param["id"]);
      return ["code"=>200,"msg"=>"success"]; 
   }
   
   public function saveactivitylanguage(){
      $param=request()->param();
      $file = request()->file('image');
      if(!empty($file)){
         $image=$file->validate(['ext'=>'jpg,png,gif'])->move('./uploads/activity');
          
         if(!$image){return $this->_error("上传图片失败");}
         $param['image']='uploads/activity/'.str_replace("\\","/",$image->getSaveName());
         //上传到aws s3
         $filename="activity/".date("Ymd")."/".basename($file->getInfo()['name']);
         $img=awsFileUtils::uploadFile($param["image"],$filename);

         if($img["code"] == 200){
           $param["pic_url"]=preg_replace("/pic-game.s3.sa-east-1.amazonaws.com/i","d2fn985pj3dhdw.cloudfront.net",$img["message"]);
         } 
        
      }
      $model=new GameIniModel;
      $language=$model->getLanguageInfo($param["language_id"]);
      $record=array("pic_url"=>$param["pic_url"],
        "language_id"=>$param["language_id"],
         "title"=>$param["title"],
         "language"=>$language["name"],
         "pic_url"=>$param["pic_url"],
        "activity_id"=>$param["activity_id"],
      );
      if(!empty($param["id"])){
         $record["id"]=$param["id"];
      }
      Log::info("add activity language: ".json_encode($language)."\t".json_encode($record)); 
      $model->saveActivityLanguage($record);

      return array("code"=>200,"msg"=>"success");   
    

   }

   public function editactivitylanguage(){
       $param=request()->param();
       if(empty($param["id"])){
         $this->error("参数错误","/admin/games/editactivitylanguage");
      }
      $model=new GameIniModel;
      $language = $model->getLanguageList();
      $record=$model->getAcitivityLanguageInfo($param["id"]);
      $this->assign("activity_id",$record["activity_id"]);
      $this->assign("languages",$language);
      $this->assign("record",$record);
      return $this->fetch();
   }

   private function field2Dict($fields){
      $dict=array();
      foreach($fields as $item){
          if($item["parent_id"] ==0 ){
             if(!isset($dict[$item["id"]])){
                 $dict[$item["id"]]=array("id"=>$item["id"],"name"=>$item["name"],"remark"=>$item["remark"],"childnodes"=>array());
              }else{
                 $dict[$item["id"]]["id"]=$item["id"];
                 $dict[$item["id"]]["name"]=$item["name"];
                 $dict[$item["id"]]["remark"]=$item["remark"];
              }
             
	  }else{
		  if(!isset($dict[$item["parent_id"]])){
			  $dict[$item["parent_id"]]=array("id"=>$item["parent_id"],"name"=>"","remark"=>"","childnodes"=>array());
		  } 
		  $dict[$item["parent_id"]]["childnodes"][$item["id"]]=$item;
	  }
      }
      return $dict;
   }

   
}

?>
