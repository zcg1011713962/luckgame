<?php
namespace app\agent\model;
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
		$this->adminid = $this->getAgId();
		$this->config = ConfigModel::getSystemConfig();
	}
	private function _request($url, $https=false, $method='get', $data=null)
	{
		$ch = curl_init();
		curl_setopt($ch,CURLOPT_URL,$url); 
		curl_setopt($ch,CURLOPT_HEADER,false); 
		curl_setopt($ch,CURLOPT_RETURNTRANSFER,true);
		if($https){
			curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false);
			curl_setopt($ch, CURLOPT_SSL_VERIFYHOST, false);
		}
		if($method == 'post'){
			curl_setopt($ch, CURLOPT_POST, true);
			curl_setopt($ch, CURLOPT_POSTFIELDS, $data);
		}
		$str = curl_exec($ch);
		curl_close($ch);
		return $str;
	}
	
	public function getAgId(){
		return Cookie::get('agent_user_id');
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
	public function getAgentDetail($id = 0){
		if(!$id){
			$id = $this->adminid;
		}
		if(empty($id)){ return false; }		
		return Db::table('ym_manage.agentinfo')->where('aid',$id)->find();
	}
	
	public function getRealNum($account){
		
		$act = "scorequery";
		$time = strtotime('now');
		$key = $this->getConfig('app.PrivateKey');				
		$sign = $act.$account.$time.$key;
		$md5sign = md5($sign);
		$_url = $this->getConfig('app.GameServiceApi');
		$url = $_url."/Activity/gameuse?act=".$act."&accountname=".$account."&time=".$time."&sign=".$md5sign;
		$res = $this->_request($url);
		$res = json_decode($res,true);
		if(isset($res) && ($res['status'] == '0')){
			return $res['data'];
		}else{
			//return 'error:'.$res['msg'];
			return false;
		}
	}
	
	public function get3ji_list($ids){
		if(empty($ids)){ return false; }
		$list = Db::table('ym_manage.agentinfo')->alias('ag')
						->field('ag.*,ad.username')
						->leftJoin('ym_manage.admin ad','ag.aid=ad.id')
						->where('ag.aid','in',$ids)
						->select();
		return $list;
	}
	
	public function get3ji_ids(){
		$id = $this->getAgId();
		if(empty($id)){ return false; }
		$ids = '';
		
		$two = Db::table('ym_manage.agentinfo')->field('aid')->where('pid',$id)->select();
		if($two){
			$two_ids = '';
			foreach($two as $_two){
				$two_ids .= $_two['aid'].',';
			}
			$two_ids = rtrim($two_ids,',');
			$ids = $two_ids;
			
			$three = Db::table('ym_manage.agentinfo')->field('aid')->where('pid','in',$two_ids)->select();
			if($three){
				$three_ids = '';
				foreach($three as $_three){
					$three_ids .= $_three['aid'].',';
				}
				$three_ids = rtrim($three_ids,',');
				$ids .= ','.$three_ids;

				$four = Db::table('ym_manage.agentinfo')->field('aid')->where('pid','in',$three_ids)->select();
				if($four){
					$four_ids = '';
					foreach($four as $_four){
						$four_ids .= $_four['aid'].',';
					}
					$four_ids = rtrim($four_ids,',');
					$ids .= ','.$four_ids;
				}
			}
		}
		
		return trim($ids,',');
	}
	
	public function getList($num = 10,$starttime,$endtime){
		$ids = $this->get3ji_ids();
		//echo $ids,'<br/>';
		if(empty($starttime) || empty($endtime)){
			$starttime = strtotime($starttime);
			$endtime = strtotime($endtime);
			$list = Db::table('ym_manage.agentinfo')->alias('ag')
							->field('ag.*,ad.username,pad.username pname,i.score')
							->leftJoin('ym_manage.admin ad','ag.aid=ad.id')
							->leftJoin('ym_manage.admin pad','ag.pid=pad.id')
                            ->leftJoin('gameaccount.userinfo_imp i','ag.uid=i.userId')
							->where('ag.aid','in',$ids)
							//->fetchSql(true)
							->paginate($num);
		}else{
			$list = Db::table('ym_manage.agentinfo')->alias('ag')
							->field('ag.*,ad.username,pad.username pname,i.score')
							->leftJoin('ym_manage.admin ad','ag.aid=ad.id')
							->leftJoin('ym_manage.admin pad','ag.pid=pad.id')
                            ->leftJoin('gameaccount.userinfo_imp i','ag.uid=i.userId')
							->where('ag.aid','in',$ids)							
							->where('createtime','>',$starttime)
							->where('createtime','<',$endtime)
							//->fetchSql(true)
							->paginate($num);
		}
		//var_dump($list);die;
		$page = $list->render();
		
		return array(
			'list' => $list,
			'page' => $page
		);
	}
	
	public function getCount(){
		return Db::table('ym_manage.admin')->count();
	}
	
	public function doEditInfo($data){
		if(empty($data)){ return false; }
		
		$id = $this->adminid;
		if(empty($id)){ return false; }		
		
		return Db::table('ym_manage.agentinfo')->where('aid',$id)->update($data);
	}
	
	public function doEditPwd($data){
		if(empty($data)){ return false; }
		if( empty($data['nowpwd']) ){ return false; }
		if(empty($data['newpwd']) || empty($data['renewpwd']) ){ return false; }
		if($data['newpwd'] != $data['renewpwd'] ){ return false; }
		
		$id = $this->adminid;
		if(empty($id)){ return false; }	
		
		$admin = $this->getAdminInfo();
		if(md5($data['nowpwd'].$admin['salt']) != $admin['password']){
			return false;
		}
		
		$salt = substr(md5(time().'dfsgre4'),5,6);
		$arr = array(			
			'password' => md5($data['newpwd'].$salt),
			'salt' => $salt
		);
		return Db::table('ym_manage.admin')->where('id',$id)->update($arr);
	}
	
	public function checkUsername($name){
		if(empty($name)){ return false; }
		$count = Db::table('ym_manage.admin')->where('username',$name)->count();
		if($count){
			return false;
		}else{
			return true;
		}
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
	
	public function gen_yqcode(){
		$code = $this->gen_code(6);
		$rs = Db::table('ym_manage.agentinfo')->where('yqcode',$code)->count();
		if($rs){
			return $this->gen_yqcode();
		}
		return $code;
	}
	
	public function doAdd($data){
		if(empty($data)){ return false; }
		
		$salt = substr(md5(time().'dfsgre4'),5,6);
		$arr = array(
			'id' => $data['uid'],
			'username' => $data['username'],
			'password' => md5($data['repass'].$salt),
			'salt' => $salt,
			'isagent' => 1,
            'top_agent' => $data['pid'] == 0 ? 1 : 0,
		);
		//$aid = Db::table('ym_manage.admin')->insertGetId($arr);
		Db::table('ym_manage.admin')->insert($arr);
		$aid = $data['uid'];
		$yqcode = $this->gen_yqcode();

		$level = $data['level'];
		if($level == 2){
			$pinfo = Db::table('ym_manage.agentinfo')->where('aid',$data['pid'])->find();
			if($pinfo){
				$level = $pinfo['level'] + 1;
			}
		}
		$ainfo = array(
			'aid' => $aid,
			'level' => $level,
			'yqcode' => $yqcode,
			'name' => '',
			'wxname' => '',
			'mobile' => $data['mobile'],
			'createtime' => time(),
			'pid' => $data['pid'],
			'uid' => $aid
		);
		$rs = Db::table('ym_manage.agentinfo')->insert($ainfo);

        $rs = Db::table('ym_manage.uidglaid')->insert([
            'uid' => $aid,
            'aid' => $aid,
            'createtime' => time()
        ]);
		
		return true;
	}

	public function getCommissionList($num = 10,$starttime,$endtime){
		$ids = $this->getAgId();
		if(empty($starttime) || empty($endtime)){
			$starttime = strtotime($starttime);
			$endtime = strtotime($endtime);
			$list = Db::table('ym_manage.fanyong_log')->alias('ag')							
							->where('ag.aid','in',$ids)
							->paginate($num);
		}else{
			$list = Db::table('ym_manage.fanyong_log')->alias('ag')							
							->where('ag.aid','in',$ids)							
							->where('createtime','>',$starttime)
							->where('createtime','<',$endtime)
							->paginate($num);
		}
		
		$page = $list->render();
		
		return array(
			'list' => $list,
			'page' => $page
		);
	}

	public function getCommissionList_Api($uid='',$starttime='',$endtime=''){
		if(empty($uid)){
			$ids = $this->getAgId();
		}else{
			$ids = $uid;
		}

		if(empty($starttime) || empty($endtime)){
			$starttime = strtotime($starttime);
			$endtime = strtotime($endtime);
			$list = Db::table('ym_manage.fanyong_log')->alias('ag')							
							->where('ag.aid','in',$ids)
							->sum('addfee');
		}else{
			$list = Db::table('ym_manage.fanyong_log')->alias('ag')							
							->where('ag.aid','in',$ids)							
							->where('createtime','>',$starttime)
							->where('createtime','<',$endtime)
							->sum('addfee');
		}		
		return $list;
	}

	public function get3ji_api_infos($id = null){
		if(empty($id)){
			$id = $this->getAgId();
		}		
		if(empty($id)){ return false; }
		
		$rs = ['num1'=>0,'num2'=>0,'num3'=>0,'ids1'=>'','ids2'=>'','ids3'=>''];
		
		$two = Db::table('ym_manage.agentinfo')->field('aid')->where('pid',$id)->select();
		if($two){
			$two_ids = '';
			foreach($two as $_two){
				$two_ids .= $_two['aid'].',';
			}
			$two_ids = rtrim($two_ids,',');
			$rs['num1'] = count($two);
			$rs['ids1'] = $two_ids;
			
			$three = Db::table('ym_manage.agentinfo')->field('aid')->where('pid','in',$two_ids)->select();
			if($three){
				$three_ids = '';
				foreach($three as $_three){
					$three_ids .= $_three['aid'].',';
				}
				$three_ids = rtrim($three_ids,',');
				$rs['num2'] = count($three);
				$rs['ids2'] = $three_ids;

				$four = Db::table('ym_manage.agentinfo')->field('aid')->where('pid','in',$three_ids)->select();
				if($four){
					$four_ids = '';
					foreach($four as $_four){
						$four_ids .= $_four['aid'].',';
					}
					$four_ids = rtrim($four_ids,',');
					$rs['num3'] = count($four);
					$rs['ids3'] = $four_ids;
				}
			}
		}
		
		return $rs;
	}

    /**
     * 查询全部代理
     * @return array|\PDOStatement|string|\think\Collection|\think\model\Collection
     * @throws \think\db\exception\DataNotFoundException
     * @throws \think\db\exception\ModelNotFoundException
     * @throws \think\exception\DbException
     */
	public function getAgentList()
    {
        $list = Db::table('ym_manage.agentinfo')->alias('ag')
            ->field('ag.*,ad.username')
            ->leftJoin('ym_manage.admin ad','ag.aid=ad.id')
            ->select();
        return $list;
    }
	
}