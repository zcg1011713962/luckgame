<?php
namespace app\admin\model;
use think\Model;
use think\Db;
use think\facade\Cookie;
use think\facade\Config;
use app\admin\model\ConfigModel;

class AdminModel extends Model
{
	private $adminid;
	private $config;

	public function __construct(){
		parent::__construct();
		$this->adminid = Cookie::get('admin_user_id');
		$this->config = ConfigModel::getSystemConfig();
	}
	
	public function getConfig($msg = 'app.GameLoginUrl'){
		$configArr = explode('.',$msg);
		// 如果系统有当前配置项，走系统配置项
		if (!empty($this->config[$configArr[1]])) {
			return $this->config[$configArr[1]];
		}
		// 否则走配置文件
		return Config::get($msg);
	}
	
	public function getAdminInfo($id = 0){
		if(!$id){
			$id = $this->adminid;
		}
		if(empty($id)){ return false; }		
		return Db::table('ym_manage.admin')->find($id);
	}
	
	public function getList($num = 10){
		$list = Db::table('ym_manage.admin')->where('isagent','0')->paginate($num);
		$page = $list->render();
		
		return array(
			'list' => $list,
			'page' => $page
		);
	}
	
	public function getCount(){
		return Db::table('ym_manage.admin')->where('isagent','0')->count();
	}
	
	public function getList1($num = 10, $type = 0){
		$list = Db::table('ym_manage.admin')->alias('a')
						->field('a.*,i.uid,ui.score')
						->leftJoin('ym_manage.agentinfo i','a.id=i.aid')
                        ->leftJoin('gameaccount.userinfo_imp ui','i.uid=ui.userId')
						->where('a.isagent','1');
						
		if (!empty($type)) {
			$list->where('a.top_agent','1');
		}

		$list = $list->paginate($num);
		$page = $list->render();
		
		return array(
			'list' => $list,
			'page' => $page
		);
	}
	
	public function getCount1(){
		return Db::table('ym_manage.admin')->where('isagent','1')->count();
	}
		
	public function doAdd($data){
		if(empty($data)){ return false; }
		if(empty($data['username'])){ return false; }
		// if(empty($data['uid'])){ return false; }
		if(empty($data['pass']) || empty($data['repass']) ){ return false; }
		if($data['pass'] != $data['repass'] ){ return false; }
		
		$salt = substr(md5(time().'dfsgre4'),5,6);
		$arr = array(
			'username' => $data['username'],
			'password' => md5($data['pass'].$salt),
			'salt' => $salt,
			// 'isagent' => $data['isagent'],
		);
		// if($data['isagent']){
		// 	$arr['id'] = $data['uid'];
		// }
                try{
		$aid = Db::table('ym_manage.admin')->insertGetId($arr);
                $this->query("set autocommit=1");
                //    print_r($aid);
                }catch(Exception $e){
                   print_r($e);
               }	
		// if($data['isagent']){
		// 	$yqcode = $this->gen_yqcode();
		// 	$ainfo = array(
		// 		'aid' => $aid,
		// 		'level' => 1,
		// 		'yqcode' => $yqcode,
		// 		'name' => '',
		// 		'wxname' => '',
		// 		'mobile' => '',
		// 		'createtime' => time(),
		// 		'pid' => 0,
		// 		'uid' => $data['uid']
		// 	);
		// 	$rs = Db::table('ym_manage.agentinfo')->where('aid',$aid)->count();
		// 	if($rs){
		// 		$rs = Db::table('ym_manage.agentinfo')->where('aid',$aid)->update($ainfo);
		// 	}else{
		// 		$rs = Db::table('ym_manage.agentinfo')->insert($ainfo);
		// 	}
		// }
		return true;
	}
	
	private function gen_code( $length = 6 ){
		$chars = array('0', '1', '2', '3', '4', '5', '6', '7', '8', '9');
		$keys = array_rand($chars, $length); 
		$password = '';
		for($i = 0; $i < $length; $i++)
		{
			$password .= $chars[$keys[$i]];
		}
		return $password;
	}
	
	private function gen_yqcode(){
		$code = $this->gen_code(6);
		$rs = Db::table('ym_manage.agentinfo')->where('yqcode',$code)->count();
		if($rs){
			return $this->gen_yqcode();
		}
		return $code;
	}
	
	public function doEdit($data){
		if(empty($data)){ return false; }
		if(empty($data['username']) || empty($data['adminid'])){ return false; }
		if(empty($data['pass']) || empty($data['repass']) ){ return false; }
		if($data['pass'] != $data['repass'] ){ return false; }
		
		$agent = Db::table('ym_manage.admin')->where('id',$data['adminid'])->find();
		if( ($agent['isagent'] == 0) && ($agent['isagent'] == 1) ){
			
			$rs = Db::table('ym_manage.agentinfo')->where('aid',$data['adminid'])->count();
			if(empty($rs)){
				$yqcode = $this->gen_yqcode();
				$ainfo = array(
					'aid' => $data['adminid'],
					'level' => 1,
					'yqcode' => $yqcode,
					'name' => '',
					'wxname' => '',
					'mobile' => '',
					'createtime' => time()
				);
				$rs = Db::table('ym_manage.agentinfo')->insert($ainfo);
			}
			
		}
		
		$salt = substr(md5(time().'dfsgre4'),5,6);
		$arr = array(
			'username' => $data['username'],
			'password' => md5($data['pass'].$salt),
			'salt' => $salt,
			'isagent' => $agent['isagent'],
		);
		$ret= Db::table('ym_manage.admin')->where('id',$data['adminid'])->update($arr);
                $this->query("set autocommit=1");
                return $ret;
	}
	
	public function doDel($data){
		if(empty($data)){ return false; }
		if(empty($data['id'])){ return false; }
		
		Db::table('ym_manage.admin')->where('id',$data['id'])->delete();
		Db::table('ym_manage.agentinfo')->where('aid',$data['id'])->delete();
                $this->query("set autocommit=1");
		return true;
	}

	public function checkUid($uid){
		if(empty($uid)){ return false; }

		return Db::table('gameaccount.newuseraccounts')->where('Id',$uid)->count();
	}
	
	public function getAgentInfo($uid){
		if(empty($uid)){ return false; }
		$info = Db::table('ym_manage.agentinfo')->where('aid',$uid)->find();
		if($info){
			if(!empty($info['pid'])){
				$info['pname'] = Db::table('ym_manage.admin')->where('id',$info['pid'])->value('username');
			}else{
				$info['pname'] = '';
			}
			
			$info['clientShow'] = $this->getAgentClientShow($uid);
		}		
		return $info;
	}
	
	private function getAgentClientShow($aid){
		
		$url = $_SERVER['SERVER_NAME'].''.url('agent/api/testClientShow',['uid'=>$aid]);
		$clientShow = $this->_request($url,true);
		return json_decode($clientShow,true);
		
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
	
}
