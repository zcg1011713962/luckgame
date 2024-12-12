<?php
namespace app\admin\controller;
use think\Controller;
use think\Db;
use think\facade\Request;
use think\facade\Cache;
use think\facade\Cookie;
use app\admin\model\ConfigModel;

class Api extends Controller
{	
	private function _request($url, $https=false, $method='get', $data=null)
	{
		$ch = curl_init();
		curl_setopt($ch,CURLOPT_URL,$url); //设置URL
		curl_setopt($ch,CURLOPT_HEADER,false); //不返回网页URL的头信息
		curl_setopt($ch,CURLOPT_RETURNTRANSFER,true);//不直接输出返回一个字符串
		if($https){
			curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false);//服务器端的证书不验证
			curl_setopt($ch, CURLOPT_SSL_VERIFYHOST, false);//客户端证书不验证
		}
		if($method == 'post'){
			curl_setopt($ch, CURLOPT_POST, true); //设置为POST提交方式
			curl_setopt($ch, CURLOPT_POSTFIELDS, $data);//设置提交数据$data
		}
		$str = curl_exec($ch);//执行访问
		curl_close($ch);//关闭curl释放资源
		return $str;
	}
	
	private function apiReturnError($msg=''){
		$rt = array('status'=>0,'msg'=>$msg,'data'=>'');
		echo json_encode($rt);die;
	}
	private function apiReturnSuccess($msg,$data){
		$rt = array('status'=>1,'msg'=>$msg,'data'=>$data);
		echo json_encode($rt);die;
	}
	
	//http://127.0.0.1/index.php/admin/api/gonggao
	public function gonggao()
	{	
		$txt1 = Db::table('ym_manage.config')->where('flag','GONGGAO_TOP')->find();
		$txt2 = Db::table('ym_manage.config')->where('flag','GONGGAO_BOTTOM')->find();

		$data = array(
			'top' => $txt1['value'],
			'bottom' => $txt2['value']
		);
		echo json_encode($data);
	}

	//http://127.0.0.1/index.php/admin/api/news
	public function news()
	{	
		$category = Db::table('ym_manage.news_category')->select();
		foreach($category as $k=>$v){
			$category[$k]['news'] = Db::table('ym_manage.news_list')->where('cid',$v['id'])->select();
		}
		
		echo htmlspecialchars(json_encode($category));
	}

	//http://127.0.0.1/index.php/admin/api/imgs
	public function imgs(){
		$conf = file_get_contents('conf');
		echo $conf;
	}

	// public function imgs(){
	// 	$configModel = new ConfigModel;
	// 	$systemUrl = $configModel->getConfig('SYSTEMURL');
	// 	$result = Db::table('ym_manage.banner')->where('status',0)->select();
	// 	$data = [];
	// 	foreach ($result as $k => $v) {
	// 		$data[$k+1] = $systemUrl['value'].$v['image'];
	// 	}
	// 	echo json_encode($data,JSON_UNESCAPED_UNICODE);
	// 	die;
	// }

	//http:127.0.0.1/index.php/admin/api/editGameAccountAvatar
	public function editGameAccountAvatar(){
		$user = Db::table('gameaccount.newuseraccounts')->where('Robot',1)->select();
		foreach($user as $row){
			$avatar = $row['headimgurl'];
			$avatar = str_replace('yidali.youmegame.cn','www.ydl69.com',$avatar);
			Db::table('gameaccount.newuseraccounts')->where('Id',$row['Id'])->update(['headimgurl'=>$avatar]);
		}
		echo 'over';
	}
	
	
}
