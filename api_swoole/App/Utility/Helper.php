<?php
namespace App\Utility;

use EasySwoole\Utility\File;
use App\Utility\Ip\BaseStation;

class Helper
{
    const HTTP_GET = 'get';
    const HTTP_POST = 'post';
    const HTTP_PUT = 'put';
    const HTTP_DELETE = 'delete';
    
    static function account_format_login($account = '') : string
    {
        if(! $account) return "";
        
        return (string)(is_numeric($_a = preg_replace('/\D/', '', $account)) &&  (strlen($_a) === 12 || strlen($_a) === 11 || strlen($_a) === 10) ? $_a : "");
    }
    
    static function account_format_display($account = '') : string
    {
        // return (string)(is_numeric($_a = preg_replace('/\D/', '', $account)) && (strlen($_a) === 12 || strlen($_a) === 10) ? rtrim(chunk_split($_a, 4, "-"), "-") : "0000-0000-0000");
        return (string)(is_numeric($_a = preg_replace('/\D/', '', $account)) &&  (strlen($_a) === 12 || strlen($_a) === 10) ? $_a : "000000000000");
    }
    
    static function format_money($money = 0, $format='%.5f') : string
    {
        return substr(sprintf($format, $money), 0, -1);
    }
    
    static function array_insert(&$array = null, $data = null, $key = false) : void
    {
        $data = (array)$data;
        $offset = $key === false ? false : array_search($key, array_keys($array));
        $offset	= $offset ? $offset : false;
        
        if($offset)
        {
            $array = array_merge(array_slice($array, 0, $offset), $data, array_slice($array, $offset));
        }
        else
        {
            $array = array_merge($array, $data);
        }
    }
    
    static function is_json_str($json_str = '')
    {
        $data = json_decode($json_str, true);
        
        if (json_last_error() === JSON_ERROR_NONE) {
            if (! is_null($data) && (is_object($data) || is_array($data))) {
                return $data;
            }
        }
        
        return false;
    }
    
    /**
     * 获取真实类名
     * @param string $_modelDirectory
     * @param string $_modelName
     * @return string
     */
    static function getModelClassName(string $_modelDirectory = '', string $_modelName = '') : string
    {
        $class = '';
        
        (
            ! empty($files = File::scanDirectory(EASYSWOOLE_ROOT . '/App/Model/' . ($_modelDirectory ? $_modelDirectory . '/' : '')))
            && ! empty($files = $files['files'] ?? [])
        )
        || $files = [];
        
        if ($files) {
            foreach ($files as $f) {
                (! empty($f = substr($f, strrpos($f, '/')+1)) &&  ! empty($f = substr($f, 0, strrpos($f, '.')))) || $f = "";
                if ($f) {
                    if (strtolower($f) === strtolower($_modelName)) {
                        $class = '\\App\\Model\\' . ($_modelDirectory ? $_modelDirectory . '\\' : '') . $f;
                        break;
                    }
                }
            }
        }
        
        return $class;
    }
    
    static function reFieldPre($in = [], $pre = '', $separator = '_') : array
    {
        $result = [];
        
        foreach ($in as $key => $value) {
            $result[$pre.$separator.$key] = ! is_null($value) ? $value : '';
        }
        
        return $result;
    }
    
    static function arrayFilterHoldByKeypre($in, $keypre = '') : array
    {
        foreach ($in as $key => $value) {
            if(strpos($key, $keypre) === false)
            {
                unset($in[$key]);
            }
        }
        
        return $in;
    }
    
    static function arrayPopByKey(&$in, $key = '')
    {
        if (isset($in[$key])) {
            $r = $in[$key];
            unset($in[$key]);
            
            return $r;
        } else {
            return null;
        }
    }
    
    static function is_string_regular($str = '')
    {
        $pregs = '/select|insert|update|CR|document|LF|eval|delete|script|alert|\'|\/\*|\#|\--|\ --|\/|\*|\-|\+|\=|\~|\*@|\*!|\$|\%|\^|\&|\(|\)|\/|\/\/|\.\.\/|\.\/|union|into|load_file|outfile/';
        
        $check= preg_match($pregs,$str);
        
        if($check == 1)
        {
            return false;
        }
        else
        {
            return true;
        }
    }
    
    static function isPlayerUsername(string $str = '') : bool
    {
        return preg_match('/^[A-Za-z0-9\@]{6,12}$/i', $str) && ! is_numeric($str) ? true : false;
    }
    
    static function isEmail(string $email = '') : bool
    {
        return filter_var($email, FILTER_VALIDATE_EMAIL) && self::strlen_real($email) <= 40;
    }
    
    static function strlen_real($str = '')
    {
        $i = 0;
        $count = 0;
        $len = strlen($str);
        while ($i < $len) {
            $chr = ord($str[$i]);
            $count++;
            $i++;
            if ($i >= $len) {
                break;
            }
            if ($chr & 0x80) {
                $chr <<= 1;
                while ($chr & 0x80) {
                    $i++;
                    $chr <<= 1;
                }
            }
        }
        
        return $count;
    }
    
    static function array_pergids(&$pergids, $agent = 2)
    {
        if(! is_string($pergids) || ! preg_match('/^[0-9\|]*$/', $pergids)) return false;
        
        $_rgs = [];
        $_gids = explode("|", $pergids);
        $pergids = [];
        
        foreach ($_gids as $gid) {
            if (! in_array(abs(intval($gid)), $agent == 2 ? [5,6,7] : ($agent == 1 ? [8,9,10,11] : []))) {
                $_rgs = false;
                break;
            } else {
                $_rgs[] = $pergids[] = abs(intval($gid));
            }
        }
        
        return $_rgs;
    }
    
    static function bb_randStr($length = 32)
    {
        mt_srand();
        return substr(str_shuffle("abcdefghijkmnpqrstuvwxyzABCDEFGHIJKMNPQRSTUVWXYZ23456789"), 0, $length);
    }

    static function getRegion($ip)
    {
        if(empty($ip)) {
            return '';
        }
        $city = new BaseStation(dirname(__DIR__) . '/Utility/Ip/ipipfree.ipdb');
        $rs = $city->find($ip, 'CN');
        return $rs ? $rs[0] : '';
    }
    
    static function getRegion2($ip)
    {
        $city = new BaseStation(dirname(__DIR__) . '/Utility/Ip/ipipfree.ipdb');
        $rs = $city->find($ip, 'CN');
        return $rs ? ($rs[0] ?? '') . '@' . ($rs[1] ?? '') : '';
    }

    /**
     * 判断是否是public IPv4 IP或者是合法的Public IPv6 IP地址
     */
    static function checkIp($ip)
    {
        return filter_var($ip, FILTER_VALIDATE_IP);
    }

    static function padString($source) {
        $paddingChar = ' ';

		$size = 16;
		$x = strlen($source) % $size;
		$padLength = $size - $x;
		for ($i = 0; $i< $padLength; $i++) {
			$source .= $paddingChar;
		}
		return $source;
    }

    static function encrypt($key, $iv, $str){
        $str= self::padString($str);
        $encrypted = openssl_encrypt($str, 'AES-128-CBC', $key, OPENSSL_RAW_DATA, $iv);
        return base64_encode($encrypted);
    }

    static function decrypt($key, $iv, $code) {
        $code = str_replace(array('-','_'),array('+','/'),$code);
        $code = base64_decode($code);
        $decrypted = openssl_decrypt($code, 'AES-128-CBC', $key, OPENSSL_NO_PADDING, $iv);
        return utf8_encode(trim($decrypted));
    }

    //RSA 公钥
    public static function generateRSAPubKey($publicKey) {
        $begin_public = "-----BEGIN PUBLIC KEY-----\n";
        $end_public = "-----END PUBLIC KEY-----\n";
        $pubKey = $begin_public.chunk_split($publicKey, 64, "\n").$end_public;
        return $pubKey;
    }

    //RSA
    public static function generateRSAPriKey($privateKey){
        $begin_private = "-----BEGIN RSA PRIVATE KEY-----\n";
        $end_private = "-----END RSA PRIVATE KEY-----\n";
        $priKey = $begin_private.chunk_split($privateKey, 64, "\n").$end_private;
        return $priKey;
    }

    //sign
    public static function signRSA($content,$privateKey){
        $priKey = openssl_get_privatekey(RSA::generatePriKey($privateKey));
        openssl_sign($content, $sign, $priKey,OPENSSL_ALGO_SHA256);
        openssl_free_key($priKey);
        $sign = base64_encode($sign);
        return $sign;
    }

    //verify
    public static function doCheckRSA($content, $sign, $publicKey){
        if($sign == null){
            return false;
        }
        if($publicKey == null){
            return false;
        }
        try{
            $pubKey = openssl_get_publickey(RSA::generatePubKey($publicKey));
            $result = openssl_verify($content,base64_decode($sign),$pubKey,OPENSSL_ALGO_SHA256);
            openssl_free_key($pubKey);
            return $result;
        }catch (Exception $e){
            $e->getMessage();
            return false;
        }
    }
}