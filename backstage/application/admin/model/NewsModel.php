<?php
namespace app\admin\model;
use think\Model;
use think\Db;
use think\facade\Cookie;
use think\facade\Config;
use think\facade\Log;
use app\admin\model\ConfigModel;

class NewsModel extends Model
{
	private $key = '';
	private $apiurl = '';
	public function __construct(){
		parent::__construct();

		// 读取配置信息
		$config = ConfigModel::getSystemConfig();
		$this->apiurl = $config['GameServiceApi'];
		$this->key = $config['PrivateKey'];
		// $this->apiurl = Config::get('app.Recharge_API');
	}
	public function getConfig($flag = ''){
		if(empty($flag)){ return false; }
		return Config::get($flag);
	}
	
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
	
	public function getGongGaoList(){
		$info = Db::table('ym_manage.news_list')->order('id desc')->select();
		return $info;
	}
	
	public function getGongGaoCount(){
		return Db::table('ym_manage.news_list')->count();		
	}
	public function getGongGaoInfo($id){
		if(empty($id)){ return false; }
		return Db::table('ym_manage.news_list')->where('id',$id)->find();
	}
	
	public function doAddGongGao($data){
		if(empty($data)){ return false; }
		if(empty($data['cid'])){ die('请选择分类'); }
		if(empty($data['title'])){ die('标题不能为空'); }
		if(empty($data['content'])){ die('内容不能为空'); }
		
		$time = time();
		$arr = array(
			'cid' => $data['cid'],
			'title' => $data['title'],
			'content' => $data['content'],
			'createtime' => $time,
			'updatetime' => $time
		);
		$res = Db::table('ym_manage.news_list')->insertGetId($arr);
		if($res){
			return true;
		}
		return false;
	}
	
	public function doEditGongGao($data){
		if(empty($data)){ return false; }
		if(empty($data['cid'])){ die('请选择分类'); }
		if(empty($data['title'])){ die('标题不能为空'); }
		if(empty($data['content'])){ die('内容不能为空'); }
		if(empty($data['ggid'])){ die('文章ID有误'); }
		
		$time = time();
		$arr = array(
			'cid' => $data['cid'],
			'title' => $data['title'],
			'content' => $data['content'],
			'updatetime' => $time
		);
		$res = Db::table('ym_manage.news_list')->where('id',$data['ggid'])->update($arr);
		if($res){
			return true;
		}
		return false;
	}
	
	public function doGongGaoDel($data){
		if(empty($data)){ return false; }
		if(empty($data['id'])){ die('文章ID有误'); }
		$res = Db::table('ym_manage.news_list')->where('id',$data['id'])->delete();
		if($res){
				return true;
		}
		return false;
	}
	
	public function getcategoryList(){
		$info = Db::table('ym_manage.news_category')->select();
		return $info;
	}
	
	public function getcategoryCount(){
		return Db::table('ym_manage.news_category')->count();		
	}
	public function getcategoryInfo($id){
		if(empty($id)){ return false; }
		return Db::table('ym_manage.news_category')->where('id',$id)->find();
	}
	
	public function doAddcategory($data){
		if(empty($data)){ return false; }
		if(empty($data['gonggao'])){ die('分类名称不能为空'); }
		
		$arr = array(
			'name' => $data['gonggao']
		);
		$res = Db::table('ym_manage.news_category')->insertGetId($arr);
		if($res){			
				return true;
		}
		return false;
	}
	
	public function doEditcategory($data){
		if(empty($data)){ return false; }
		if(empty($data['gonggao'])){ die('分类名称不能为空'); }
		if(empty($data['ggid'])){ die('分类ID有误'); }
		
		$arr = array(
			'name' => $data['gonggao']
		);
		$res = Db::table('ym_manage.news_category')->where('id',$data['ggid'])->update($arr);
		if($res){
				return true;
		}
		return false;
	}
	
	public function docategoryDel($data){
		if(empty($data)){ return false; }
		if(empty($data['id'])){ die('分类ID有误'); }
		$res = Db::table('ym_manage.news_category')->where('id',$data['id'])->delete();
		if($res){			
				return true;
		}
		return false;
	}
	

		
}