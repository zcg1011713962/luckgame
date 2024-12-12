<?php
namespace app\admin\controller;
use think\Db;
use think\Controller;
use think\facade\Request;
use think\facade\Config;
use app\admin\controller\Parents;
use app\admin\model\IssueModel;
use app\admin\model\ConfigModel;

class Issue extends Parents
{
     private $config;
     public function __construct(){
          parent::__construct();
          $this->config = ConfigModel::getSystemConfig();
     }

     public function lists(){
        $this->assign("breadcrumb_name","FQA列表");
        return $this->fetch(); 
     }

     public function getlists(){
        $model=  new IssueModel();
        $params = request()->param();
        $searchstr = !empty($params["searchstr"])? $params["searchstr"]:'';
	$begin_time=!empty($params["begin_time"])?$params["begin_time"]:"";
        $end_time = !empty($params["end_time"])?$params["end_time"]:"";
        $ret=$model->getFQAList($params["limit"],$searchstr,$begin_time,$end_time);
        return ["code"=>0,"count"=>$ret["total"],"data"=>$ret["data"],"msg"=>"ok"];  
     }
       public function add()
       {
            $id=input('id');
            $record=[];
            if($id>0){
                $record=IssueModel::where('id',$id)->find();
                if($record){
                   $record=$record->toArray();
                }else{
                   $record=[];
                }
            }
             $this->assign('find',$record);
	    return $this->fetch();
      }
       public function doAdd(){
	       $title= input('title');
	       $content=input('content');
	       $id=input('id');
	       if (!$title){
		       echo '请输入标题';exit();
	       }
	       if (!$content){
		       echo '请输入内容';exit();
	       }
	       $saveData = [
		       'title' => $title ,
		       'content' => $content ,
	       ];
	       if ($id > 0){
		       $model= new IssueModel;
	               $model->editFQA($id,$title,$content);
               }else{
		       $model= new IssueModel;
		       $model->doAdd($title=$title,$content=$content);

	       }
	       echo 'success';
       }
 
       public function edit()
      {
            $id=request()->param('id');
            if(empty($id)){
              $this->error('参数有误','admin\Issue\edit');
            }
            $model=new IssueModel;
            $info=$model->getFQAInfo($id);
             #print_r($info);
            $this->assign("info",$info);
            return $this->fetch();
     }
     public function doDel(){
        $id=request()->param('id');
        if(empty($id)){
              $this->error('参数有误','admin\Issue\doDel');
            
        }
        $model=new IssueModel;
        $model->delFQA($id);
        echo 'success';
 
     }
}

?>
