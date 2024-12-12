<?php
namespace app\admin\controller;
use think\Controller;
use app\admin\controller\Parents;
use think\Db;
use app\admin\model\AdminModel;

class Config1 extends Parents
{

	private $apiurl = '';
	public function __construct(){
		parent::__construct();
		$admin = new AdminModel();
		$this->apiurl = $admin->getConfig('app.YxxUpd_API');
	}
	
	public function yxxfkc(){
		
		$act = "tablequery";
		$param = "";
		$url = $this->gen_yxx_api_url($act,$param);		
		$res = $this->_request($url);
		//var_dump($res);
		//$res = '{"status":1,"result":[{"table_id":"0","tableKey":"541385","ju_shu":15,"round_num":15}]}';
		
		$res = json_decode($res,true);
		if( isset($res['status']) && $res['status'] == '1'){
			$list = $res['result'];
		}else{
			echo '查询失败<br/>';
			$list = [];
		}
		$this->assign('list',$list);
		
		return $this->fetch();
	}
	
	public function yxxfkcSet(){
		$table_id = input('param.tid');
		$table_key = input('param.tkey');
		$this->assign('tableid',$table_id);
		$this->assign('tablekey',$table_key);
		
		$act = "tabletype";
		$param = "&table_id=".$table_id;
		$url = $this->gen_yxx_api_url($act,$param);
		$res = $this->_request($url);
		//var_dump($res);
		//$res = '{"status":1,"result":{"is_table_type":1,"bet_time":33,"bet_data":[{"bet_type":1,"bet_res":2,"bet_gold":500,"userId":3125,"seatId":2},{"bet_type":1,"bet_res":3,"bet_gold":500,"userId":3125,"seatId":2},{"bet_type":1,"bet_res":6,"bet_gold":500,"userId":3125,"seatId":2},{"bet_type":1,"bet_res":5,"bet_gold":500,"userId":3125,"seatId":2},{"bet_type":1,"bet_res":3,"bet_gold":500,"userId":3124,"seatId":1},{"bet_type":1,"bet_res":5,"bet_gold":500,"userId":3124,"seatId":1},{"bet_type":1,"bet_res":2,"bet_gold":500,"userId":3124,"seatId":1}],"nuo_bet_data":[{"bet_type":5,"bet_res":[5,2],"bet_gold":712,"userId":3124,"seatId":1}]}}';
		
		//连串bet_type2  bet_res数组[4,5]
		//string(227) "{"status":1,"result":{"is_table_type":1,"bet_time":6,"bet_data":[{"bet_type":2,"bet_res":[4,5],"bet_gold":200,"userId":3170,"seatId":1},{"bet_type":2,"bet_res":[1,5],"bet_gold":200,"userId":3170,"seatId":1}],"nuo_bet_data":[]}}"
		
		$res = json_decode($res,true);
		if( isset($res['status']) && $res['status'] == '1'){
			$list = $res['result'];
			//print_r($list);
		}else{
			echo '查询失败<br/>';
			$list = [];
		}
		$this->assign('list',$list);
		
		return $this->fetch('yxxfkcset');
	}
	
	public function ajaxYxxfkcSet(){
		$data = request()->post();
		$table_id = $data['tid'];
		
		$act = "tabletype";
		$param = "&table_id=".$table_id;
		$url = $this->gen_yxx_api_url($act,$param);			
		$res = $this->_request($url);
		//var_dump($res);
		//$res = '{"status":1,"result":{"is_table_type":1,"bet_time":30,"bet_data":[{"bet_type":1,"bet_res":2,"bet_gold":500,"userId":3125,"seatId":2},{"bet_type":1,"bet_res":3,"bet_gold":500,"userId":3125,"seatId":2},{"bet_type":1,"bet_res":6,"bet_gold":500,"userId":3125,"seatId":2},{"bet_type":1,"bet_res":5,"bet_gold":500,"userId":3125,"seatId":2},{"bet_type":1,"bet_res":3,"bet_gold":500,"userId":3124,"seatId":1},{"bet_type":1,"bet_res":5,"bet_gold":500,"userId":3124,"seatId":1},{"bet_type":1,"bet_res":2,"bet_gold":500,"userId":3124,"seatId":1}],"nuo_bet_data":[{"bet_type":5,"bet_res":[5,2],"bet_gold":712,"userId":3124,"seatId":1}]}}';
		
		$res = json_decode($res,true);
		if( !isset($res['status']) || $res['status'] != '1'){
			die('error');
		}
		
		$res = $res['result'];
		
		$result = array();
		$result['changetype'] = ($res['is_table_type'] === 1) ? '允许' : '禁止';
		$result['daojishi'] = $res['bet_time'];
		
		$betdata = '<table class="layui-table">					  
					  <thead>
						<tr>
						  <th>座位号</th>
						  <th>用户ID</th>
						  <th>类型</th>
						  <th>押位置</th>
						  <th>金币数</th>
						</tr> 
					  </thead>
					  <tbody>';
					
		foreach( $res['bet_data'] as $k=>$v ){
			$betdata .= '<tr>
						  <td>'.$v['seatId'].'</td><td>'.$v['userId'].'</td>';
			
			switch ($v['bet_type']){
				case 1:
				  $betdata .= '<td>单压</td><td>'.$v['bet_res'].'</td>';
				  break;  
				case 2:
				  $betdata .= '<td>连串</td><td>'.implode(',',$v['bet_res']).'</td>';
				  break;
				case 3:
				  $betdata .= '<td>豹子</td><td>'.$v['bet_res'].'</td>';
				  break;
				default:
				  $betdata .= '<td>'.$v['bet_type'].'</td><td>'.$v['bet_res'].'</td>';
			}
			$betdata .= '<td>'.$v['bet_gold'].'</td>';							
		}
		$betdata .= '</tbody></table>';
		$result['betdata'] = $betdata;
		
		$nuobetdata = '<table class="layui-table">					  
					  <thead>
						<tr>
						  <th>座位号</th>
						  <th>用户ID</th>
						  <th>类型</th>
						  <th>开始位置</th>
						  <th>结束位置</th>
						  <th>金币数</th>
						</tr> 
					  </thead>
					  <tbody>';
						
		foreach( $res['nuo_bet_data'] as $k=>$v ){
			$nuobetdata .= '<tr>';
			$nuobetdata .= '<td>'.$v['seatId'].'</td>';
			$nuobetdata .= '<td>'.$v['userId'].'</td>';
			$nuobetdata .= '<td>挪</td>';
			$nuobetdata .= '<td>'.$v['bet_res'][0].'</td>';
			$nuobetdata .= '<td>'.$v['bet_res'][1].'</td>';
			$nuobetdata .= '<td>'.$v['bet_gold'].'</td>';			
			$nuobetdata .= '</tr>';
		}
		$nuobetdata .= '</tbody></table>';
		$result['nuobetdata'] = $nuobetdata;
		
		echo json_encode($result);
		
	}
	
	public function ajaxyxxfkcsetzjl(){
		$data = request()->post();
		$table_id = $data['tid'];
		$zjl = $data['city'];
		
		$act = "tableResUpdate";
		$param = "&table_id=".$table_id."&res_win=".$zjl;
		$url = $this->gen_yxx_api_url($act,$param);
		$res = $this->_request($url);
		$res = json_decode($res,true);
		if(isset($res) && ($res['status'] == '1') ){
			echo '操作成功';
		}else{
			echo '操作失败';
		}
	}
	
	private function gen_yxx_api_url($act,$param){
			
		$time = strtotime('now');
		$key = 'dkl4234908fjfsn93d';
		$sign = $act.$time.$key;
		$md5sign = md5($sign);
		$url = $this->apiurl.":13851"."/manage/game?act=".$act."&time=".$time."&sign=".$md5sign.$param;
		return $url;
	}
	
}
