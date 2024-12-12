<?php
function _request($url, $https=false, $method='get', $data=null)
	{
		$ch = curl_init();
		curl_setopt($ch,CURLOPT_URL,$url); //����URL
		curl_setopt($ch,CURLOPT_HEADER,false); //��������ҳURL��ͷ��Ϣ
		curl_setopt($ch,CURLOPT_RETURNTRANSFER,true);//��ֱ���������һ���ַ���
		if($https){
			curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false);//�������˵�֤�鲻��֤
			curl_setopt($ch, CURLOPT_SSL_VERIFYHOST, false);//�ͻ���֤�鲻��֤
		}
		if($method == 'post'){
			curl_setopt($ch, CURLOPT_POST, true); //����ΪPOST�ύ��ʽ
			curl_setopt($ch, CURLOPT_POSTFIELDS, $data);//�����ύ����$data
		}
		$str = curl_exec($ch);//ִ�з���
		curl_close($ch);//�ر�curl�ͷ���Դ
		return $str;
	}

$set = include(__DIR__."/../application/admin/config/app.php");
$setval = $set['YxxUpd_API'];
$apiurl = $setval;

/*
	$act = "queryOnlineNum";
	$time = strtotime('now');
	$key = 'dkl4234908fjfsn93d';
	$sign = $act.$time.$key;
	$md5sign = md5($sign);
	$url = $apiurl.":13851"."/manage/game?act=".$act."&time=".$time."&sign=".$md5sign;
	echo $url.'<br/>';
	$res = _request($url);
	echo $res.'<hr/>';

	$url1 = $apiurl.":13850"."/manage/game?act=".$act."&time=".$time."&sign=".$md5sign;
	echo $url1.'<br/>';
	$res1 = _request($url1);
	echo $res1.'<hr/>';
		
	$key = '42dfcb34fb02d8cd';
	$sign = $act.$time.$key;
	$md5sign = md5($sign);
	$url2 = $apiurl.":13000"."/Activity/gameuse?act=".$act."&time=".$time."&sign=".$md5sign;
	echo $url2.'<br/>';
	$res2 = _request($url2);
	echo $res2.'<hr/>';
	
	$num = 0;
	$num1 = 0;
	$num2 = 0;
	$res = json_decode($res,true);
	$res1 = json_decode($res1,true);
	$res2 = json_decode($res2,true);
	if(isset($res) && ($res['status'] == '1')){
		$num = $res['result']['online_num'];
	}
	if(isset($res1) && ($res1['status'] == '1')){
		$num1 = $res1['result']['online_num'];
	}
	if(isset($res2) && ($res2['status'] == '1')){
		$num2 = $res2['result']['online_num'];
	}
*/	
	$act = "queryOnlineNum";
	$time = strtotime('now');
	$key = 'dkl4234908fjfsn93d';
	$sign = $act.$time.$key;
	$md5sign = md5($sign);
	$url = $apiurl.":13900"."/manage/game?act=".$act."&time=".$time."&sign=".$md5sign;
	echo $url.'<br/>';
	$res = _request($url);
	echo $res.'<hr/>';
	
	$num = 0;
	$res = json_decode($res,true);
	if(isset($res) && ($res['status'] == '1')){
		$num = $res['result']['online_num'];
	}
		
	$arr = array(
		'gameport' => '13850',
		'num' => $num
	);
	var_dump($arr);
	echo '<br/>';
	$thisurl = 'http://127.0.0.1';
	$aaaaa = _request($thisurl.'/index.php/admin/Tophp/onlinenum.html',true,'post',$arr);
	echo $aaaaa;
