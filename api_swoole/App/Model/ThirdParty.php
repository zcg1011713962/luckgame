<?php
namespace App\Model;

use App\Model\Model;
use EasySwoole\EasySwoole\Logger;
use App\Utility\Helper;
use EasySwoole\EasySwoole\Config;

//第3方登录验证用
class ThirdParty extends Model
{
    function __construct()
    {
        parent::__construct();
        
        if (! $this->is_enabled()) {
            //log_message('error', 'cURL Class - PHP was not built with cURL enabled. Rebuild PHP with --with-curl to use cURL.');
        }
    }

    protected static $supported_algs = array(
        'HS256' => array('hash_hmac', 'SHA256'),
        'HS512' => array('hash_hmac', 'SHA512'),
        'HS384' => array('hash_hmac', 'SHA384'),
        'RS256' => array('openssl', 'SHA256'),
        'RS384' => array('openssl', 'SHA384'),
        'RS512' => array('openssl', 'SHA512'),
    );

    public function is_enabled()
    {
        return function_exists('curl_init');
    }

    /**
    * google注册用户验证token和email
    google 验证：
    https://oauth2.googleapis.com/tokeninfo?id_token=eyJhbGciOiJSUzI1NiIsImtpZCI6Ijc4M2VjMDMxYzU5ZTExZjI1N2QwZWMxNTcxNGVmNjA3Y2U2YTJhNmYiLCJ0eXAiOiJKV1QifQ.eyJpc3MiOiJodHRwczovL2FjY291bnRzLmdvb2dsZS5jb20iLCJhenAiOiI2ODczNzc2OTE0NzItaHA4cGNlY3RnY2dxMjM5YTg1MTk5bDdxY2NpaDU5ZnUuYXBwcy5nb29nbGV1c2VyY29udGVudC5jb20iLCJhdWQiOiI2ODczNzc2OTE0NzItN2FrNGNrcGJtaDZqbDNlcWl1bnJramRiMXZocW9mcWUuYXBwcy5nb29nbGV1c2VyY29udGVudC5jb20iLCJzdWIiOiIxMDY1ODc0NjQwMDIzMzAyMDI0ODciLCJlbWFpbCI6Imxvbmcuamlhbm1pbi5manV0QGdtYWlsLmNvbSIsImVtYWlsX3ZlcmlmaWVkIjp0cnVlLCJuYW1lIjoibG9uZyBNUiIsInBpY3R1cmUiOiJodHRwczovL2xoNC5nb29nbGV1c2VyY29udGVudC5jb20vLXRMbjBMVEduY1c0L0FBQUFBQUFBQUFJL0FBQUFBQUFBQUFBL0FNWnV1Y25uQlk2dFphaXM2M1lrY29Lb1ZBSGtTTVpUZ3cvczk2LWMvcGhvdG8uanBnIiwiZ2l2ZW5fbmFtZSI6ImxvbmciLCJmYW1pbHlfbmFtZSI6Ik1SIiwibG9jYWxlIjoiZW4iLCJpYXQiOjE2MTA2OTkyMTcsImV4cCI6MTYxMDcwMjgxN30.AVuG9iC_bgufevxY0ypLtJETSbjbaV5NKvAhqLohGDeA-9Y6ZXoYy4qZtE8rzxtBXcV8fRFHMb4dYTwEoCDH24lnG6k4NYpwXQ7_dZkUOAssuYBN5ZLQxXhE9YeW6fNl-Ts0tcbg9HOuSjvP6EtC-i_MU36Er78ZTCZNV5ty0zdRgfoVfvx-YAKCQF6Ewt8DURrHRQjmL35GZRU-hcEQXwfKVmCKUWz2B22fTVFCz05GcLdqQwXTfwGAoVNtM_gAxokWgel_ZUaEVRi0YCmu2bVD6hVksKn1ZfOA6PXsL98YKAdXS67lfPg9gyhu3_D23sOl7dyFrRLphxpNGtGA6Q
    
    google 验证成功返回：
    {
      "iss": "https://accounts.google.com",
      "azp": "687377691472-hp8pcectgcgq239a85199l7qccih59fu.apps.googleusercontent.com",
      "aud": "687377691472-7ak4ckpbmh6jl3eqiunrkjdb1vhqofqe.apps.googleusercontent.com",
      "sub": "106587464002330202487",
      "email": "long.jianmin.fjut@gmail.com",
      "email_verified": "true",
      "name": "long MR",
      "picture": "https://lh4.googleusercontent.com/-tLn0LTGncW4/AAAAAAAAAAI/AAAAAAAAAAA/AMZuucnnBY6tZais63YkcoKoVAHkSMZTgw/s96-c/photo.jpg",
      "given_name": "long",
      "family_name": "MR",
      "locale": "en",
      "iat": "1610699217",
      "exp": "1610702817",
      "alg": "RS256",
      "kid": "783ec031c59e11f257d0ec15714ef607ce6a2a6f",
      "typ": "JWT"
    }
    */
    public function check_google_code($email='', $id_token='') {
        // return true; //TODO 服务器不能科学上网，只能先默认通过
        if (empty($id_token) || empty($email)) {
            $this->setErrMsg('参数不能为空');
            return false;
        }
        $url = 'https://oauth2.googleapis.com/tokeninfo?id_token=' . $id_token;
        $res = $this->models->curl_model->simple_get($url);
        $res = json_decode($res, true);
        if ($res && isset($res['email']) && $res['email'] == $email) {
            return true;
        }
        $this->setErrMsg('验证失败');
        return false;
    }

    /**
     * Verify a signature with the message, key and method. Not all methods
     * are symmetric, so we must have a separate verify and sign method.
     *
     * @param string            $msg        The original message (header and body)
     * @param string            $signature  The original signature
     * @param string|resource   $key        For HS*, a string key works. for RS*, must be a resource of an openssl public key
     * @param string            $alg        The algorithm
     *
     * @return bool
     *
     * @throws DomainException Invalid Algorithm or OpenSSL failure
     */
    protected static function verify($msg, $signature, $key, $alg)
    {
        if (empty(static::$supported_algs[$alg])) {
            throw new DomainException('Algorithm not supported');
        }

        list($function, $algorithm) = static::$supported_algs[$alg];
        switch($function) {
            case 'openssl':
                $success = openssl_verify($msg, $signature, $key, $algorithm);
                if ($success === 1) {
                    return true;
                } elseif ($success === 0) {
                    return false;
                }
                // returns 1 on success, 0 on failure, -1 on error.
                throw new \Exception(
                    'OpenSSL error: ' . openssl_error_string()
                );
            case 'hash_hmac':
            default:
                $hash = hash_hmac($algorithm, $msg, $key, true);
                if (function_exists('hash_equals')) {
                    return hash_equals($signature, $hash);
                }
                $len = min(static::safeStrlen($signature), static::safeStrlen($hash));

                $status = 0;
                for ($i = 0; $i < $len; $i++) {
                    $status |= (ord($signature[$i]) ^ ord($hash[$i]));
                }
                $status |= (static::safeStrlen($signature) ^ static::safeStrlen($hash));

                return ($status === 0);
        }
    }

    //苹果验证identityToken
    function get_login_info($userID, $identityToken){
        $token = explode('.', $identityToken);
        $jwt_header = json_decode( base64_decode($token[0]), TRUE);
        $jwt_data = json_decode( base64_decode($token[1]), TRUE);
        $jwt_sign = $token[2];
        if($userID !== $jwt_data['sub']){
            $this->setErrMsg('用户ID与token不对应');
            return false;
        }
        if($jwt_data['exp'] < time() ){
            $this->setErrMsg('token已过期，请重新登录');
            return false;
        }

        $url = 'https://appleid.apple.com/auth/keys';
        $applekeys = $this->models->curl_model->simple_get($url);
        $applekeys = json_decode($applekeys, true);
        if( !$applekeys ){
            $this->setErrMsg('请求苹果服务器失败');
            return false;
        }
        
        $the_apple_key = [];
        foreach($applekeys['keys'] as $key){
            if($key['kid'] == $jwt_header['kid'] ){
                $the_apple_key = $key;
            }
        }
        unset($key);
        
        $pem = self::createPemFromModulusAndExponent($the_apple_key['n'], $the_apple_key['e']);
        $pKey = openssl_pkey_get_public($pem);
        if( $pKey === FALSE ){
            $this->setErrMsg('生成苹果pem失败');
            return false;
        }
        $publicKeyDetails = openssl_pkey_get_details($pKey);
        
        $pub_key = $publicKeyDetails['key'];
        $alg = $jwt_header['alg'];

        $ok = self::verify("$token[0].$token[1]", static::urlsafeB64Decode($jwt_sign), $pub_key, $alg);
        if( !$ok ){
            $this->setErrMsg('苹果登录签名校验失败');
            return false;
        }
        
        return true;
    }

    /**
     * Decode a string with URL-safe Base64.
     *
     * @param string $input A Base64 encoded string
     *
     * @return string A decoded string
     */
    protected static function urlsafeB64Decode($input)
    {
        $remainder = strlen($input) % 4;
        if ($remainder) {
            $padlen = 4 - $remainder;
            $input .= str_repeat('=', $padlen);
        }
        return base64_decode(strtr($input, '-_', '+/'));
    }

    /**
     *
     * Create a public key represented in PEM format from RSA modulus and exponent information
     *
     * @param string $n the RSA modulus encoded in Base64
     * @param string $e the RSA exponent encoded in Base64
     * @return string the RSA public key represented in PEM format
     */
    protected static function createPemFromModulusAndExponent($n, $e)
    {
        $modulus = static::urlsafeB64Decode($n);
        $publicExponent = static::urlsafeB64Decode($e);
        
        $components = array(
            'modulus' => pack('Ca*a*', 2, self::encodeLength(strlen($modulus)), $modulus),
            'publicExponent' => pack('Ca*a*', 2, self::encodeLength(strlen($publicExponent)), $publicExponent)
        );

        $RSAPublicKey = pack(
            'Ca*a*a*',
            48,
            self::encodeLength(strlen($components['modulus']) + strlen($components['publicExponent'])),
            $components['modulus'],
            $components['publicExponent']
        );

        // sequence(oid(1.2.840.113549.1.1.1), null)) = rsaEncryption.
        $rsaOID = pack('H*', '300d06092a864886f70d0101010500'); // hex version of MA0GCSqGSIb3DQEBAQUA
        $RSAPublicKey = chr(0) . $RSAPublicKey;
        $RSAPublicKey = chr(3) . self::encodeLength(strlen($RSAPublicKey)) . $RSAPublicKey;

        $RSAPublicKey = pack(
            'Ca*a*',
            48,
            self::encodeLength(strlen($rsaOID . $RSAPublicKey)),
            $rsaOID . $RSAPublicKey
        );

        $RSAPublicKey = "-----BEGIN PUBLIC KEY-----\r\n" .
            chunk_split(base64_encode($RSAPublicKey), 64) .
            '-----END PUBLIC KEY-----';

        return $RSAPublicKey;
    }

    /**
     * DER-encode the length
     *
     * DER supports lengths up to (2**8)**127, however, we'll only support lengths up to (2**8)**4.  See
     * {@link http://itu.int/ITU-T/studygroups/com17/languages/X.690-0207.pdf#p=13 X.690 paragraph 8.1.3} for more information.
     *
     * @access private
     * @param int $length
     * @return string
     */
    protected static function encodeLength($length)
    {
        if ($length <= 0x7F) {
            return chr($length);
        }

        $temp = ltrim(pack('N', $length), chr(0));
        return pack('Ca*', 0x80 | strlen($temp), $temp);
    }

    /**
     * Get the number of bytes in cryptographic strings.
     *
     * @param string
     *
     * @return int
     */
    protected static function safeStrlen($str)
    {
        if (function_exists('mb_strlen')) {
            return mb_strlen($str, '8bit');
        }
        return strlen($str);
    }

    /**
    * apple token校验
    */
    public function check_apple_code($user_id, $id_token) {
        return $this->get_login_info($user_id, $id_token);
    }
    
    /**
    * facebook token校验
    */
    public function check_fb_code($id, $id_token) {
        // return true;
        if (empty($id_token) || empty($id)) {
            $this->setErrMsg('参数不能为空');
            return false;
        }
        $url = 'https://graph.facebook.com/v9.0/'.$id.'/?access_token=' . $id_token;
        $res = $this->models->curl_model->simple_get($url);
        $res = json_decode($res, true);
        if ($res && isset($res['id']) && $res['id'] == $id) {
            return true;
        }
        $this->setErrMsg('验证失败');
        return false;
    }
}