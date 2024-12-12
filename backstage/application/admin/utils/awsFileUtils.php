<?php
namespace app\admin\utils;
//require 'vendor/autoload.php';
use Aws\S3\S3Client;
use Aws\Credentials\Credentials;
use Aws\Exception\MultipartUploadException;
use Aws\S3\MultipartUploader;
use Aws\CloudFront\CloudFrontClient;
use think\Log;

class awsFileUtils{

         public static  function getDirFiles($dir){
                $files=[];
                if(is_dir($dir)) { // 判断目录是否存在
                        $handle = opendir($dir);
                        while (($file = readdir($handle)) !== false) {
                                if ($file != "." && $file != "..") {
                                        $path = $dir . "/" . $file;
                                        if (is_dir($path)) { // 如果是目录，递归调用
                                                $files = array_merge($files, awsFileUtils::getDirFiles($path));
                                        } else { // 如果是文件，添加到结果数组中
                                                $files[] = $path;
                                        }
                                }
                        }

                        closedir($handle); // 关闭目录句柄
                }

                return $files;

        }

	public static function uploadFile($file,$filename,$mine=''){
		try{
	   $s3Client= new S3Client([
			   "version"=>"latest",
			   "region"=>"sa-east-1",
			   "credentials"=>['key'=>getenv("AWS_S3_KEY"),
			   "secret"=>getenv("AWS_S3_SECRET")]]
			   );
			$ret1=$s3Client->putObject([
					"Key"=>$filename,
					"Bucket"=>"pic-game",
					"ACL"=>"public-read",
					"Body"=>fopen($file,"r"), 
			]);
			$result=array("code"=>200,"message"=>urldecode($ret1["ObjectURL"]));
			return $result;
		}catch(Exception $e){
			Log::error($e->getMessage());
			return array("code"=>400,"message"=>$e->getMessage());
		}
	}
        //刷新CDN paths为数组
        public static function createInvalidation($distributionId,$paths){
          $quantity=1;
          $cloudFrontClient = new CloudFrontClient([
			   "version"=>"latest",
			   "region"=>"sa-east-1",
			   "credentials"=>['key'=>getenv("AWS_S3_KEY"),
			   "secret"=>getenv("AWS_S3_SECRET")],
                           'http'=>['verify'=>false]
                         ]);
	  try{
		  $callerReference='backend_'.time();
		  $cloudFrontClient->createInvalidation([
                'DistributionId' => $distributionId,
                'InvalidationBatch' => [
                    'CallerReference' => $callerReference,
                    'Paths' => [
                        'Items' => $paths,
                        'Quantity' => $quantity
                    ],
                ]
		  ]);

             return true;
           }catch(AwsException $e){
             return false;
           }  
        } 
} 

?>
