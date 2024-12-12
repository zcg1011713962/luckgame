<?php
namespace app\api\controller;

class Curl {
	
	private $isHttps;
	private $apikey;
	
	public function __construct($isHttps = false,$apikey = ''){
		
		$this->isHttps = ($isHttps === true) ? true : false;
		$this->apikey = $apikey ? $apikey : 'niuxp';
		
	}
	
	public function niuxp_get($url){
		
		$ch = curl_init();
		curl_setopt($ch, CURLOPT_URL,$url);
		curl_setopt($ch, CURLOPT_CUSTOMREQUEST, "GET");
		curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
		curl_setopt($ch, CURLOPT_HTTPHEADER, array(
			'APIKEY: '.$this->apikey                                                                   
		)); 
		if($this->isHttps){
			curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false);
			curl_setopt($ch, CURLOPT_SSL_VERIFYHOST, false);
		}
		$result = curl_exec($ch);
		return $result;
	}

	public function niuxp_post($url, $data_string){

		$ch = curl_init();
		curl_setopt($ch, CURLOPT_URL,$url);                                                                   
		curl_setopt($ch, CURLOPT_CUSTOMREQUEST, "POST"); 
		curl_setopt($ch, CURLOPT_FAILONERROR, true);
		
		curl_setopt($ch, CURLOPT_POST, true);
		curl_setopt($ch, CURLOPT_POSTFIELDS, $data_string);                                                                  
		curl_setopt($ch, CURLOPT_RETURNTRANSFER, true); 
		curl_setopt($ch, CURLOPT_HTTPHEADER, array(   
			'APIKEY: '.$this->apikey,
		    'Content-Type: application/json', 
		    'Content-Length: ' . strlen($data_string)
		));                                                                                                                   
		if($this->isHttps){
			curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false);
			curl_setopt($ch, CURLOPT_SSL_VERIFYHOST, false);
		}
		$result = curl_exec($ch);
		return $result;
	}

	public function niuxp_put($url, $data_string){

		$ch = curl_init();
		curl_setopt($ch, CURLOPT_URL,$url);   
		curl_setopt($ch, CURLOPT_CUSTOMREQUEST, "PUT"); 
		curl_setopt($ch, CURLOPT_FAILONERROR, true);  

		curl_setopt($ch, CURLOPT_POST, true);
		curl_setopt($ch, CURLOPT_POSTFIELDS, $data_string);                                                                  
		curl_setopt($ch, CURLOPT_RETURNTRANSFER, true); 
		curl_setopt($ch, CURLOPT_HTTPHEADER, array(
			'APIKEY: '.$this->apikey,
		    'Content-Type: application/json',
		    'Content-Length: ' . strlen($data_string)
		));                                                                                                                   
		if($this->isHttps){
			curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false);
			curl_setopt($ch, CURLOPT_SSL_VERIFYHOST, false);
		}
		$result = curl_exec($ch);
		return $result;
	}

	public function niuxp_delete($url, $data_string){

		$ch = curl_init();
		curl_setopt($ch, CURLOPT_URL,$url);   
		curl_setopt($ch, CURLOPT_CUSTOMREQUEST, "DELETE"); 
		curl_setopt($ch, CURLOPT_FAILONERROR, true);   

		curl_setopt($ch, CURLOPT_POST, true);
		curl_setopt($ch, CURLOPT_POSTFIELDS, $data_string);                                                                  
		curl_setopt($ch, CURLOPT_RETURNTRANSFER, true); 
		curl_setopt($ch, CURLOPT_HTTPHEADER, array(
			'APIKEY: '.$this->apikey,
		    'Content-Type: application/json', 
		    'Content-Length: ' . strlen($data_string)
		));                                                                                                                   
		if($this->isHttps){
			curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false);
			curl_setopt($ch, CURLOPT_SSL_VERIFYHOST, false);
		}
		$result = curl_exec($ch);
		return $result;
	}

	/**
	 * 备份
	 */
	public function _request($url, $https=false, $method='get', $data=null)
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


	/**
	 * 备份
	 */
	public function _request_jz($url, $https=false, $method='get', $data=null)
	{
		$ch = curl_init();
		curl_setopt($ch,CURLOPT_URL,$url); 
		curl_setopt($ch,CURLOPT_HEADER,false); 
		curl_setopt($ch,CURLOPT_RETURNTRANSFER,true);
		curl_setopt($ch,CURLOPT_HTTPHEADER, array(
		    'Content-Type: application/x-www-form-urlencoded'
		));    
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

}


?>