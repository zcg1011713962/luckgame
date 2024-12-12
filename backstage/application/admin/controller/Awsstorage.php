<?php
namespace app\admin\controller;
ini_set('memory_limit', '512M');
use think\Controller;
use think\facade\Log;
use think\facade\Request;
use app\admin\controller\Parents;
use app\admin\model\ConfigModel;
use app\admin\utils\awsFileUtils;

class Awsstorage extends Parents
{


	public function index(){
		return   $this->fetch();
	}

	public function  uploadFile(){
		$param=request()->param();
		$file=request()->file("image");
		if(empty($file)){
			$this->error("上传文件错误","/admin/Aswstorage/uploadFile");
		}
		$filename=$file->getInfo()['name'];
		$image=$file->validate(['ext'=>'zip'])->move("./uploads/aws_storage");
		if(!$image){
			return $this->_error("上传文件失败");
		}
		$param["filename"]=$filename;
		$filename=preg_replace("/.zip/i","",$filename);
		$param['image']="uploads/aws_storage/".str_replace("\\","/",$image->getSaveName());
		flush();
		$zip = new \ZipArchive;
                $urls=array();
		if($zip->open($param["image"])==true){
			popen("rm -rf ./uploads/aws_storage/.$filename","r");
			$zip->extractTo("./uploads/aws_storage/");
		        popen("nohup php /app/think  aws_upload  $filename >/dev/null &","r");
		}
               return array("code"=>200,"msg"=>"success","data"=>array("uploadfile"=>$param["filename"],"cdnhost"=>"https://d2fn985pj3dhdw.cloudfront.net/downloads/$filename"));
	}
  
     public function redis(){
         return $this->fetch();
     }

     public function redisupload(){
	   $param=request()->param();
	   $file=request()->file("image");
	   if(empty($file)){
	       $this->error("上传文件错误","/admin/Aswstorage/uploadFile");
            }
	    $image=$file->validate(['ext'=>'txt'])->move("./uploads/aws_storage");
	    $param['image']="uploads/aws_storage/".str_replace("\\","/",$image->getSaveName());
	    $filename="/app/public/".$param["image"];
	    $param["filename"]=$filename;
            flush();
            popen("nohup php /app/think  database_init  $filename >/dev/null &","r");
            return array("code"=>200,"msg"=>"success","data"=>array("uploadfile"=>$param["filename"],"cdnhost"=>"upload redis success"));
                 

     } 
     
} 
?>
