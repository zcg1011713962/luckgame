<?php
namespace app\agent\model;
use think\Model;
use think\Db;
use think\facade\Cookie;

class LogsModel extends Model
{
	
	public function yxx1($num = 10){
		
		$list = Db::table('game_log.yu_xia_xie_table_log')
					->order('id desc')
					->paginate($num);
		
		$page = $list->render();
		
		return array(
			'list' => $list,
			'page' => $page
		);
	}
	
	public function yxx1count($search = ''){
		
		return Db::table('game_log.yu_xia_xie_table_log')->count();
		
	}
	
	public function yxx2($num = 10){
		
		$list = Db::table('game_log.yu_xia_xie_club_table_log')
					->order('id desc')
					->paginate($num);
		
		$page = $list->render();
		
		return array(
			'list' => $list,
			'page' => $page
		);
	}
	
	public function yxx2count($search = ''){
		
		return Db::table('game_log.yu_xia_xie_club_table_log')->count();
		
	}
	
	
}