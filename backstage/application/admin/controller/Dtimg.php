<?php
namespace app\admin\controller;
use app\admin\controller\Parents;
use think\Db;
use think\facade\Config;
use think\facade\Log;

class Dtimg extends Parents
{
	
    public function index()
    {	
		$conf = file_get_contents('conf');
		//var_dump($conf);
		if($conf){
			$list = json_decode($conf,true);			
		}else{
			$list = array(
				'1'=> 'https://img10.360buyimg.com/img/jfs/t1/83007/20/13309/249190/5da824bbEdef08493/5cec46741445645a.gif',
				'2'=> 'https://img10.360buyimg.com/img/jfs/t1/83007/20/13309/249190/5da824bbEdef08493/5cec46741445645a.gif',
				'3'=> 'https://img10.360buyimg.com/img/jfs/t1/83007/20/13309/249190/5da824bbEdef08493/5cec46741445645a.gif',
				'4'=> 'https://img10.360buyimg.com/img/jfs/t1/83007/20/13309/249190/5da824bbEdef08493/5cec46741445645a.gif',
				'5'=> 'https://img10.360buyimg.com/img/jfs/t1/83007/20/13309/249190/5da824bbEdef08493/5cec46741445645a.gif'
			);
		}
		
		
		$this->assign('list',$list);
				
        return $this->fetch();
    }
	
	public function nandu_save(){
		$data = request()->post();
		//var_dump($data);die;
		$_data = [];
		foreach($data as $k => $v){
			$_k = substr($k,3);
			$_data[$_k] = $v;
		}
		//var_dump($_data);die;
		file_put_contents('conf',json_encode($_data));
		$this->redirect('index');
	}
	
	public function upload(){
		$file = request()->file('file');
		$info = $file->validate(['ext'=>'jpg,png,gif'])->move( 'uploads/dtimg');
		if($info){				
			$path = str_replace('\\','/',$info->getSaveName());			
			$msg = 'http://'.$_SERVER['HTTP_HOST'].'/uploads/dtimg/'.$path;
		}else{
			$msg = '';
		}

		echo json_encode(['msg'=>$msg]);
	}

	//http://ydlht.com/index.php/admin/dtimg/imgs
	public function imgs(){
		$conf = file_get_contents('conf');
		echo $conf;
	}

}
