<?php
namespace app\agent\model;
use think\Model;
use think\Db;

class StatisticsModel extends Model
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
	
	public function getUserList($num = 10, $search = '',$agents_ids = '',$type = 1){
		if($agents_ids == ''){ return false; }
		if(!in_array($type,[1,2])){ $type = 1; }
		
		if( empty($search['searchaid']) ) {
			$uaidglb = Db::table('ym_manage.uidglaid')->field('uid')
							->where('aid','in',$agents_ids)
							->select();
		}else{
			$uaidglb = Db::table('ym_manage.uidglaid')->field('uid')
							->where('aid',$search['searchaid'])
							->select();
		}
		$uids = '';
		foreach($uaidglb as $k => $v){
			$uids .= $v['uid'].',';
		}
		$uids = rtrim($uids,',');
		
		if(!empty($uids)){
			if($type == '2'){
				$table = 'ym_manage.fkrechargelog';
			}else{
				$table = 'ym_manage.rechargelog';
			}
			
			$dbobj = Db::table($table)->alias('l')
							->field('l.*,g.aid,d.username')
							->leftJoin('ym_manage.uidglaid g','l.userid=g.uid')
							->leftJoin('ym_manage.admin d','g.aid=d.id')
							->where('l.userid','in',$uids);
			$dbobj1 = Db::table($table)->alias('l')
							->field('l.*,g.aid,d.username')
							->leftJoin('ym_manage.uidglaid g','l.userid=g.uid')
							->leftJoin('ym_manage.admin d','g.aid=d.id')
							->where('l.userid','in',$uids);
			
			if( !empty($search['starttime']) && !empty($search['endtime']) ){
				$starttime = strtotime($search['starttime']);
				$endtime = strtotime($search['endtime']);
				$dbobj = $dbobj->where('l.createtime','>=', $starttime)->where('l.createtime','<', $endtime);
				$dbobj1 = $dbobj1->where('l.createtime','>=', $starttime)->where('l.createtime','<', $endtime);
			}
			if( !empty($search['searchstr']) ) {
				$dbobj = $dbobj->where('l.userid', $search['searchstr']);
				$dbobj1 = $dbobj1->where('l.userid', $search['searchstr']);
			}
			$count = $dbobj1->where('l.type','1')->sum('czfee');
			$list = $dbobj->order('l.createtime desc')->paginate($num);
			
		}else{
			$count = 0;
			$list = [];
		}
		if(empty($list)){
			$page = '';
		}else{
			$page = $list->render();
		}
		
		
		return array(
			'list' => $list,
			'count' => $count,
			'page' => $page
		);
	}
	
	public function getUserList_new($num = 10, $search = '',$agents_ids = '',$type = 1,$a1=''){
		if($a1 == ''){ return false; }
		if(!in_array($type,[1,2])){ $type = 1; }
				
		if($type == '2'){
			$table = 'ym_manage.fkrechargelog';
		}else{
			$table = 'ym_manage.rechargelog';
		}
		
		$dbobj = Db::table($table)->alias('l')
						->field('l.*,g.aid,d.username')
						->leftJoin('ym_manage.uidglaid g','l.userid=g.uid')
						->leftJoin('ym_manage.admin d','g.aid=d.id')
						->where('l.adminid',$a1);
		$dbobj1 = Db::table($table)->alias('l')
						->field('l.*,g.aid,d.username')
						->leftJoin('ym_manage.uidglaid g','l.userid=g.uid')
						->leftJoin('ym_manage.admin d','g.aid=d.id')
						->where('l.adminid',$a1);
		
		if( !empty($search['starttime']) && !empty($search['endtime']) ){
			$starttime = strtotime($search['starttime']);
			$endtime = strtotime($search['endtime']);
			$dbobj = $dbobj->where('l.createtime','>=', $starttime)->where('l.createtime','<', $endtime);
			$dbobj1 = $dbobj1->where('l.createtime','>=', $starttime)->where('l.createtime','<', $endtime);
		}
		if( !empty($search['searchstr']) ) {
			$dbobj = $dbobj->where('l.userid', $search['searchstr']);
			$dbobj1 = $dbobj1->where('l.userid', $search['searchstr']);
		}
		$count = $dbobj1->where('l.type','1')->sum('czfee');
		$list = $dbobj->order('l.createtime desc')->paginate($num);
		
		if(empty($list)){
			$page = '';
		}else{
			$page = $list->render();
		}
		
		
		return array(
			'list' => $list,
			'count' => $count,
			'page' => $page
		);
	}
	
	public function getOneUserStat($uid,$search=''){
		
	}
	
	public function getRecharge($num = 10, $search = '',$agents_ids = ''){
		if($agents_ids == ''){ return false; }
		
		$uaidglb = Db::table('ym_manage.uidglaid')->field('uid')->where('aid','in',$agents_ids)->order('createtime desc')->select();//paginate($num);			
		
		if(!empty($uaidglb)){
			$list = [];
			foreach($uaidglb as $k=>$v){
				$_uid = $v['uid'];
				if( !empty($search['starttime']) && !empty($search['endtime']) ){
					$starttime = strtotime($search['starttime']);
					$endtime = strtotime($search['endtime']);
					$score = Db::table('ym_manage.rechargelog')->where('userid',$_uid)->where('type','1')
									->where('createtime','>=', $starttime)->where('createtime','<', $endtime)
									->sum('czfee');
					$diamond = Db::table('ym_manage.fkrechargelog')->where('userid',$_uid)->where('type','1')
									->where('createtime','>=', $starttime)->where('createtime','<', $endtime)
									->sum('czfee');
				}else{
					$score = Db::table('ym_manage.rechargelog')->where('userid',$_uid)->where('type','1')->sum('czfee');
					$diamond = Db::table('ym_manage.fkrechargelog')->where('userid',$_uid)->where('type','1')->sum('czfee');
				}
				
				$_arr = [];
				$_arr['uid'] = $_uid;
				$_arr['score'] = $score;
				$_arr['diamond'] = $diamond;
				$nickname = Db::table('gameaccount.newuseraccounts')->where('Id',$_uid)->column('nickname');
				$_arr['nickname'] = $nickname ? $nickname[0] : '';
				$list[] = $_arr;				
			}
			
		}else{
			$list = [];
		}
				
		//$page = $list->render();
		$page = '';
		
		$scoretotal = 0;
		$diamondtotal = 0;
		foreach($list as $k=>$v){
			if(empty($v['score']) && empty($v['diamond'])){
				unset($list[$k]);
			}else{
				$scoretotal += $v['score'];
				$diamondtotal += $v['diamond'];
			}
			
		}
		
		return array(
			'list' => $list,
			'scoretotal' => $scoretotal,
			'diamondtotal' => $diamondtotal,
			'page' => $page
		);
	}
			
	public function getCZTotalfee(){
		$num1 = Db::table('ym_manage.rechargelog')->where('type',1)->sum('czfee');
		$num2 = Db::table('ym_manage.rechargelog')->where('type',0)->sum('czfee');
		
		return array(
			'addfee' => $num1,
			'delfee' => $num2,
			'totalfee' => $num1 - $num2
		);
	}
	
	public function getCZfeeByWhere($starttime,$endtime){
		if(empty($starttime)){ return false; }
		if(empty($endtime)){ return false; }
		
		$num1 = Db::table('ym_manage.rechargelog')
					->where('type',1)
					->where('createtime','>=',$starttime)
					->where('createtime','<=',$endtime)
					->sum('czfee');
		$num2 = Db::table('ym_manage.rechargelog')
					->where('type',0)
					->where('createtime','>=',$starttime)
					->where('createtime','<=',$endtime)
					->sum('czfee');
		return array(
			'addfee' => $num1,
			'delfee' => $num2,
			'totalfee' => $num1 - $num2
		);
		
	}
	
	public function getKClists(){
		$info = Db::table('ym_manage.game')->order('port asc')->select();
		foreach($info as $k => $v){
			$kucun = Db::table('ym_manage.kucunlog')->where('gameid',$v['gameid'])->order('id desc')->limit(1)->find();
			$info[$k]['kucun'] = !empty($kucun) ? '['.$kucun['createtime'].']  '.$kucun['kucun'] : 0;
		}
		return $info;
	}
	
	public function searchKC($id){
		if(empty($id)){return false;}
		
		$info = Db::table('ym_manage.game')->find($id);
		if($info){
			$kucun = Db::table('ym_manage.kucunlog')->where('gameid',$info['gameid'])->order('id desc')->limit(1)->find();
			return !empty($kucun) ? '['.$kucun['createtime'].']  '.$kucun['kucun'] : 0;
		}
		return false;
	}
	
	public function getKCByWhere($starttime,$endtime){
		if(empty($starttime)){ return false; }
		if(empty($endtime)){ return false; }
		$starttime = date('Y-m-d',$starttime);
		$endtime = date('Y-m-d',$endtime);
		
		$num1 = Db::table('ym_manage.kucunlog')
					->where('createtime','like',$starttime.'%')
					->order('id desc')
					->limit(1)
					->find();
		$num2 = Db::table('ym_manage.kucunlog')
					->where('createtime','like',$endtime.'%')
					->order('id desc')
					->limit(1)
					->find();
		//return $num1['kucun'].'-'.$num2['kucun'];
		if(empty($num1) || empty($num2)){ return false; }
		return array(
			'num1' => $num1['kucun'],
			'num2' => $num2['kucun'],
			'res' => $num2['kucun'] - $num1['kucun']
		);
		
	}
	
}