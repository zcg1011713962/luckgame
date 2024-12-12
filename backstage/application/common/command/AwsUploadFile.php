<?php
namespace app\common\command;
use think\console\Command;
use think\facade\Log;
use think\console\Input;
use think\console\input\Argument;
use think\console\input\Option;
use think\console\Output;
use app\admin\utils\awsFileUtils;

class AwsUploadFile extends Command{
     
  protected function configure()
  {
     $this->setName("awsUpload")
          ->addArgument("filename",Argument::REQUIRED,"the dir path upload to aws s3")
          ->setDescription("awsUpload tp5 cli mode");    
  } 
 
  protected function execute(Input $input, Output $output){
      ini_set('default_socket_timeout',-1);
      set_time_limit(0);
      $output->writeln("starting");
      $filename=$input->getArgument("filename");
      popen("cd /app/public/","r");
     $files=awsFileUtils::getDirFiles("/app/public/uploads/aws_storage/$filename");
      $output->writeln($files);
      $urls=array();
      foreach($files as $file){
              $output->writeln($file);
	      $s3key=preg_replace("/\/app\/public\/uploads\/aws_storage/i","downloads",$file);
	      $ret=awsFileUtils::uploadFile($file,$s3key);
	      Log::info(json_encode($ret));
	      if($ret["code"]==200){
		      $urls[]=preg_replace("/pic-game.s3.sa-east-1.amazonaws.com/i","d2fn985pj3dhdw.cloudfront.net",$ret["message"]);
	      }
              $output->writeln(json_encode($ret));

      } 
      $output->writeln($filename); 
      $output->writeln("start ref cdn");
      $output->writeln("/downloads/$filename/*");
      awsFileUtils::createInvalidation("E1PPO5MDVZFHQL",["/downloads/$filename/*"]);
      $output->writeln("end"); 
  }
  
} 
 
?>
