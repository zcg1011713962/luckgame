<?php
namespace app\api\utils;

class nutspayUtils {
    static public function encryptNew($str, $key, $iv) {
		return base64_encode(openssl_encrypt($str, 'AES-128-CBC', (($key)), OPENSSL_RAW_DATA, $iv));
	}

	static public function httpsPost($url, $paramStr,$headers){
		$curl = curl_init();
		curl_setopt_array($curl, array(
			CURLOPT_URL => $url,
		  	CURLOPT_RETURNTRANSFER => 1,
		  	CURLOPT_TIMEOUT => 30,
		  	CURLOPT_SSL_VERIFYPEER => false,
		  	CURLOPT_SSL_VERIFYHOST => false,
		  	CURLOPT_HTTP_VERSION => CURL_HTTP_VERSION_1_1,
		  	CURLOPT_CUSTOMREQUEST => "POST",
		  	CURLOPT_POSTFIELDS => $paramStr,
		  	CURLOPT_HTTPHEADER => $headers,
		));
		$response = curl_exec($curl);
		$err = curl_error($curl);
		curl_close($curl);
		if ($err) {
		  return $err;
		}
		return $response;
	}
}