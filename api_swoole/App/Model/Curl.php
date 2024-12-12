<?php
namespace App\Model;

use App\Model\Model;
use EasySwoole\EasySwoole\Logger;
use App\Utility\Helper;
use EasySwoole\EasySwoole\Config;

class Curl extends Model
{
    protected $_game_server_host;
    protected $_game_server_port;
    protected $_timefl;
    protected $response = '';       // Contains the cURL response for debug
    protected $session;             // Contains the cURL handler for a session
    protected $url;                 // URL of the session
    protected $options = [];   // Populates curl_setopt_array
    protected $headers = [];   // Populates extra HTTP headers
    public $error_code;             // Error code returned as an int
    public $error_string;           // Error message returned as a string
    public $info;                   // Returned after request (elapsed time, etc)
    public $timenow;
    private $flag = 0;
    
    function __construct()
    {
        parent::__construct();
        
        $this->_game_server_host = Config::getInstance()->getConf('GAMESERVER.HOST');
        
        $this->_timefl = time();
        //log_message('debug', 'cURL Class Initialized');
        if (! $this->is_enabled()) {
            //log_message('error', 'cURL Class - PHP was not built with cURL enabled. Rebuild PHP with --with-curl to use cURL.');
        }
        //$url AND $this->create($url);
        $this->timenow = time();
    }
    
    public function setFlag($flag = 1)
    {
        $this->flag = $flag;
    }
    
    private function setPort()
    {
        if (
            !! ($port = $this->getTokenObj()->virtual_fromport ?? ($this->getTokenObj()->account_fromport ?? 0))
            && is_array($confList = Config::getInstance()->getConf('GAMESERVER.LIST')) && !! ($gamePort = $confList[$port] ?? 0)
        ) {
            $this->_game_server_port = $gamePort;
        } else {
            $this->_game_server_port = Config::getInstance()->getConf('GAMESERVER.PORT');
        }
    }
    
    public function __call($method, $arguments)
    {
        if (in_array($method, ['simple_get', 'simple_post', 'simple_put', 'simple_delete', 'simple_patch'])) {
            // Take off the "simple_" and past get/post/put/delete/patch to _simple_call
            $verb = str_replace('simple_', '', $method);
            array_unshift($arguments, $verb);
            return call_user_func_array([$this, '_simple_call'], $arguments);
        }
    }
    
    /* =================================================================================
     * SIMPLE METHODS
     * Using these methods you can make a quick and easy cURL call with one line.
     * ================================================================================= */
    public function _simple_call($method, $url, $params = [], $options = [])
    {
        // Get acts differently, as it doesnt accept parameters in the same way
        if ($method === 'get') {
            // If a URL is provided, create new session
            $this->create($url.($params ? '?'.http_build_query($params, null, '&') : ''));
        } else {
            // If a URL is provided, create new session
            $this->create($url);
            $this->{$method}($params);
        }
        // Add in the specific options provided
        $this->options($options);
        return $this->execute();
    }
    
    public function simple_ftp_get($url, $file_path, $username = '', $password = '')
    {
        // If there is no ftp:// or any protocol entered, add ftp://
        if ( ! preg_match('!^(ftp|sftp)://! i', $url)) {
            $url = 'ftp://' . $url;
        }
        // Use an FTP login
        if ($username != '') {
            $auth_string = $username;
            if ($password != '') {
                $auth_string .= ':' . $password;
            }
            // Add the user auth string after the protocol
            $url = str_replace('://', '://' . $auth_string . '@', $url);
        }
        // Add the filepath
        $url .= $file_path;
        $this->option(CURLOPT_BINARYTRANSFER, true);
        $this->option(CURLOPT_VERBOSE, true);
        return $this->execute();
    }
    
    /* =================================================================================
     * ADVANCED METHODS
     * Use these methods to build up more complex queries
     * ================================================================================= */
    public function post($params = [], $options = [])
    {
        // If its an array (instead of a query string) then format it correctly
        if (is_array($params)) {
            $params = http_build_query($params, null, '&');
        }
        // Add in the specific options provided
        $this->options($options);
        $this->http_method('post');
        $this->option(CURLOPT_POST, true);
        $this->option(CURLOPT_POSTFIELDS, $params);
    }
    
    public function put($params = [], $options = [])
    {
        // If its an array (instead of a query string) then format it correctly
        if (is_array($params)) {
            $params = http_build_query($params, null, '&');
        }
        // Add in the specific options provided
        $this->options($options);
        $this->http_method('put');
        $this->option(CURLOPT_POSTFIELDS, $params);
        // Override method, I think this overrides $_POST with PUT data but... we'll see eh?
        $this->option(CURLOPT_HTTPHEADER, ['X-HTTP-Method-Override: PUT']);
    }
    
    public function patch($params = [], $options = [])
    {
        // If its an array (instead of a query string) then format it correctly
        if (is_array($params)) {
            $params = http_build_query($params, null, '&');
        }
        // Add in the specific options provided
        $this->options($options);
        $this->http_method('patch');
        $this->option(CURLOPT_POSTFIELDS, $params);
        // Override method, I think this overrides $_POST with PATCH data but... we'll see eh?
        $this->option(CURLOPT_HTTPHEADER, ['X-HTTP-Method-Override: PATCH']);
    }
    
    public function delete($params, $options = [])
    {
        // If its an array (instead of a query string) then format it correctly
        if (is_array($params)) {
            $params = http_build_query($params, null, '&');
        }
        // Add in the specific options provided
        $this->options($options);
        $this->http_method('delete');
        $this->option(CURLOPT_POSTFIELDS, $params);
    }
    
    public function set_cookies($params = [])
    {
        if (is_array($params)) {
            $params = http_build_query($params, null, '&');
        }
        $this->option(CURLOPT_COOKIE, $params);
        return $this;
    }
    
    public function http_header($header, $content = null)
    {
        $this->headers[] = $content ? $header . ': ' . $content : $header;
        return $this;
    }
    
    public function http_method($method)
    {
        $this->options[CURLOPT_CUSTOMREQUEST] = strtoupper($method);
        return $this;
    }
    
    public function http_login($username = '', $password = '', $type = 'any')
    {
        $this->option(CURLOPT_HTTPAUTH, constant('CURLAUTH_' . strtoupper($type)));
        $this->option(CURLOPT_USERPWD, $username . ':' . $password);
        return $this;
    }
    
    public function proxy($url = '', $port = 80)
    {
        $this->option(CURLOPT_HTTPPROXYTUNNEL, true);
        $this->option(CURLOPT_PROXY, $url . ':' . $port);
        return $this;
    }
    
    public function proxy_login($username = '', $password = '')
    {
        $this->option(CURLOPT_PROXYUSERPWD, $username . ':' . $password);
        return $this;
    }
    
    public function ssl($verify_peer = true, $verify_host = 2, $path_to_cert = null)
    {
        if ($verify_peer) {
            $this->option(CURLOPT_SSL_VERIFYPEER, true);
            $this->option(CURLOPT_SSL_VERIFYHOST, $verify_host);
            if (isset($path_to_cert)) {
                $path_to_cert = realpath($path_to_cert);
                $this->option(CURLOPT_CAINFO, $path_to_cert);
            }
        } else {
            $this->option(CURLOPT_SSL_VERIFYPEER, false);
            $this->option(CURLOPT_SSL_VERIFYHOST, $verify_host);
        }
        return $this;
    }
    
    public function options($options = [])
    {
        // Merge options in with the rest - done as array_merge() does not overwrite numeric keys
        foreach ($options as $option_code => $option_value) {
            $this->option($option_code, $option_value);
        }
        // Set all options provided
        curl_setopt_array($this->session, $this->options);
        return $this;
    }
    
    public function option($code, $value, $prefix = 'opt')
    {
        if (is_string($code) && !is_numeric($code)) {
            $code = constant('CURL' . strtoupper($prefix) . '_' . strtoupper($code));
        }
        $this->options[$code] = $value;
        return $this;
    }
    
    // Start a session from a URL
    public function create($url)
    {
        // If no a protocol in URL, assume its a CI link
        if ( ! preg_match('!^\w+://! i', $url)) {
            //$this->_ci->load->helper('url');
            //$url = site_url($url);
        }
        $this->url = $url;
        $this->session = curl_init($this->url);
        return $this;
    }
    
    // End a session and return the results
    public function execute()
    {
        // Set two default options, and merge any extra ones in
        if ( ! isset($this->options[CURLOPT_TIMEOUT])) {
            $this->options[CURLOPT_TIMEOUT] = 30;
        }
        if ( ! isset($this->options[CURLOPT_RETURNTRANSFER])) {
            $this->options[CURLOPT_RETURNTRANSFER] = true;
        }
        if ( ! isset($this->options[CURLOPT_FAILONERROR])) {
            $this->options[CURLOPT_FAILONERROR] = true;
        }
        
        //log_message('debug', $this->_timefl.": " . $this->url);
        //log_message('debug', $this->_timefl.": METHOD " . (isset($this->options[CURLOPT_CUSTOMREQUEST]) ? $this->options[CURLOPT_CUSTOMREQUEST] : "get"));
        //log_message('debug', $this->_timefl.": DATA " . (isset($this->options[CURLOPT_POSTFIELDS]) ? $this->options[CURLOPT_POSTFIELDS] : "NO POSTFIELDS"));
        
        
        // Only set follow location if not running securely
        if ( ! ini_get('safe_mode') && ! ini_get('open_basedir')) {
            // Ok, follow location is not set already so lets set it to true
            if ( ! isset($this->options[CURLOPT_FOLLOWLOCATION])) {
                $this->options[CURLOPT_FOLLOWLOCATION] = true;
            }
        }
        if ( ! empty($this->headers)) {
            $this->option(CURLOPT_HTTPHEADER, $this->headers);
        }
        $this->options();
        // Execute the request & and hide all output
        $this->response = curl_exec($this->session);
        $this->info = curl_getinfo($this->session);
        
        if (strpos($this->url, 'getgamelist') === false && strpos($this->url, 'serverinfo')===false) {
            $_httplogstr = "[url] {$this->url} [port] {$this->_game_server_port}";
            $_httplogstr.= isset($this->options[CURLOPT_POSTFIELDS]) ? " [_post] ".$this->options[CURLOPT_POSTFIELDS] : "";
            $_httplogstr.= " [_response] {$this->response}";
            Logger::getInstance()->log($_httplogstr, '2gserver');
        }
        
        // Request failed
        if ($this->response === false) {
            $errno = curl_errno($this->session);
            $error = curl_error($this->session);
            curl_close($this->session);
            $this->set_defaults();
            $this->error_code = $errno;
            $this->error_string = $error;
            return false;
        }
        // Request successful
        else {
            curl_close($this->session);
            $this->last_response = $this->response;
            $this->set_defaults();
            return $this->last_response;
        }
    }
    
    public function is_enabled()
    {
        return function_exists('curl_init');
    }
    
    public function debug()
    {
        echo "=============================================<br/>\n";
        echo "<h2>CURL Test</h2>\n";
        echo "=============================================<br/>\n";
        echo "<h3>Response</h3>\n";
        echo "<code>" . nl2br(htmlentities($this->last_response)) . "</code><br/>\n\n";
        if ($this->error_string)
        {
            echo "=============================================<br/>\n";
            echo "<h3>Errors</h3>";
            echo "<strong>Code:</strong> " . $this->error_code . "<br/>\n";
            echo "<strong>Message:</strong> " . $this->error_string . "<br/>\n";
        }
        echo "=============================================<br/>\n";
        echo "<h3>Info</h3>";
        echo "<pre>";
        print_r($this->info);
        echo "</pre>";
    }
    
    public function debug_request()
    {
        return [
            'url' => $this->url
        ];
    }
    
    public function set_defaults()
    {
        $this->response = '';
        $this->headers = [];
        $this->options = [];
        $this->error_code = null;
        $this->error_string = '';
        $this->session = null;
    }
    
    public function getErrMsssage()
    {
        return $this->error_string;
    }
    
    /**
     * 向游戏服务器推送数据
     * bigbang 展示
     * @param array $pars
     * @return boolean
     */
    public function pushSystemSettingBigBangDis($pars = [])
    {
        $this->setPort();
        $this->timenow = time();
        
        //log_message('debug', '向GAME服务器推送数据-> SystemSettingBigBangDis '.$this->_timefl);
        
        if(
            ! isset($pars['bb_disbaseline'])
            || ! isset($pars['bb_valdown_parl'])
            || ! isset($pars['bb_valdown_time'])
            || ! isset($pars['bb_wave_val'])
            || ! ($pars['mod'] = 'disbigbang'))
        {
            $this->error_string = "CURL参数缺失";
            return false;
        }
        elseif (
            ! ($_result = $_resultO = $this->simple_get($this->_game_server_host, $pars, ['PORT'=> $this->_game_server_port, 'TIMEOUT'=> 5]))
            || ! is_array($_result = json_decode($_result, true))
            || ! isset($_result['code'])
            || (int)$_result['code'] !== 200)
        {
            $this->error_string = "游戏服无响应";
            return false;
        }
        {
            return true;
        }
        
        return false;
    }
    
    /**
     * 向游戏服务器推送bigbang预开奖信息
     * bigbang 开奖
     * @param array $data
     * @return boolean|number
     */
    public function pushBigbangPreWin($data = [])
    {
        $this->setPort();
        $this->timenow = time();
        
        //log_message('debug', '向GAME服务器推送数据-> BigbangPreWin '.$this->_timefl);
        
        if(
            ! isset($data['logtoken'])
            || ! isset($data['uid'])
            || ! isset($data['coin'])
            || ! isset($data['expiretime'])
            || ! ($data['mod'] = 'bigbangreward'))
        {
            $this->error_string = "CURL参数缺失";
            return false;
        }
        elseif (
            ! ($_result = $this->simple_get($this->_game_server_host, $data, ['PORT'=> $this->_game_server_port, 'TIMEOUT'=> 5]))
            || ! is_array($_result = json_decode($_result, true))
            || ! isset($_result['code'])
            || (int)$_result['code'] !== 200)
        {
            $this->error_string = "游戏服无响应";
            return false;
        }
        else
        {
            return time();
        }
        
        return false;
    }
    
    /**
     * 向游戏服务器推送数据
     * 游戏维护状态
     * @param array $pars
     * @return boolean
     */
    public function pushSystemSettingGameSwitch($pars = [])
    {
        $this->setPort();
        $this->timenow = time();
        
        if(
            ! isset($pars['game_switch'])
            || ! isset($pars['game_swl']))
        {
            $this->error_string = "CURL参数缺失";
            return false;
        }
        elseif (
            ! ($_result = $this->simple_post($this->_game_server_host.'?mod=gameswitch', ['msg'=> json_encode($pars, JSON_UNESCAPED_UNICODE)], ['PORT'=> $this->_game_server_port, 'TIMEOUT'=> 5]))
            || (string)$_result !== 'succ')
        {
            $this->error_string = "游戏服无响应";
            return false;
        }
        else
        {
            $this->models->rediscli_model->getDb()->set('maintain_server', ! $pars['game_switch'] ? 1 : 0);
            
            return true;
        }
        
        return false;
    }
    
    /**
     * 向游戏服务器推送数据
     * JP池 展示
     * @param array $pars
     * @return boolean
     */
    public function pushSystemSettingPoolJPDis($pars = [])
    {
        $this->setPort();
        $this->timenow = time();
        
        //log_message('debug', '向GAME服务器推送数据-> SystemSettingPoolJPDis '.$this->_timefl);
        
        if(
            ! isset($pars['pool_jp_disbaseline'])
            || ! isset($pars['pool_jp_diswave'])
            || ! isset($pars['pool_jp_disinterval'])
            || ! isset($pars['pool_jp_disdownpar'])
            || ! ($pars['mod'] = 'dispooljp'))
        {
            $this->error_string = "CURL参数缺失";
            return false;
        }
        elseif (
            ! ($_result = $_resultO = $this->simple_get($this->_game_server_host, $pars, ['PORT'=> $this->_game_server_port, 'TIMEOUT'=> 5]))
            || ! is_array($_result = json_decode($_result, true))
            || ! isset($_result['code'])
            || (int)$_result['code'] !== 200)
        {
            $this->error_string = "游戏服无响应";
            return false;
        }
        else
        {
            return true;
        }
        
        return false;
    }
    
    /**
     * 向游戏服务器推送数据
     * 红包救济 GAME端拉取后台红包设置
     * @param array $pars
     * @return boolean
     */
    public function pushSystemSettingRedbag($pars = [])
    {
        $this->setPort();
        $this->timenow = time();
        
        //log_message('debug', '向GAME服务器推送数据-> SystemSettingRedbag '.$this->_timefl);
        
        if(
            ! isset($pars['pool_rb_isopen'])
            || ! isset($pars['pool_rb_limitup'])
            || ! isset($pars['pool_rb_limitdown'])
            || ! isset($pars['pool_rb_coinless'])
            || ! isset($pars['pool_rb_7daycoindiff'])
            || ! ($pars['mod'] = 'redbagsetting'))
        {
            $this->error_string = "CURL参数缺失";
            return false;
        }
        elseif (
            ! ($_result = $_resultO = $this->simple_get($this->_game_server_host, $pars, ['PORT'=> $this->_game_server_port, 'TIMEOUT'=> 5]))
            || ! is_array($_result = json_decode($_result, true))
            || ! isset($_result['code'])
            || (int)$_result['code'] !== 200)
        {
            $this->error_string = "游戏服无响应";
            return false;
        }
        else
        {
            return true;
        }
        
        return false;
    }
    
    /**
     * 向游戏服务器推送一个将玩家踢下线60秒的操作
     * 后台将玩家踢下线60秒
     * @param array $data
     * @return boolean
     */
    public function pushPlayerOffline60Sec($data = [])
    {
        $this->setPort();
        $this->timenow = time();
        
        //log_message('debug', '向GAME服务器推送数据-> PlayerOffline60Sec '.$this->_timefl);
        
        if(
            ! isset($data['uid'])
            || ! $data['uid'])
        {
            $this->error_string = "CURL参数缺失";
            return false;
        }
        elseif (($_result = $this->simple_post($this->_game_server_host.'?mod=user&act=offline', $data, ['PORT'=> $this->_game_server_port, 'TIMEOUT'=> 5])) === false)
        {
            $this->error_string = "游戏服无响应";
            return false;
        }
        else
        {
            return true;
        }
        
        return false;
    }

    /**
     * 向游戏服务器推送一个总代发红包的操作
     * 游戏服立即向在游戏内的玩家发红包
     * @param array $data
     * @return boolean
     */
    public function pushRedPacketSetting($data = [])
    {
        $this->setPort();
        $this->timenow = time();
        
        //log_message('debug', '向GAME服务器推送数据-> PlayerOffline60Sec '.$this->_timefl);
        
        if(
            ! isset($data['coin'])
            || ! $data['coin'])
        {
            $this->error_string = "CURL参数缺失";
            return false;
        }
        elseif (($_result = $this->simple_post($this->_game_server_host.'?mod=user&act=redpacket', $data, ['PORT'=> $this->_game_server_port, 'TIMEOUT'=> 5])) === false)
        {
            $this->error_string = "游戏服无响应";
            return false;
        }
        else
        {
            return true;
        }
        
        return false;
    }
    
    /**
     * 向游戏服务推送玩家上分数据
     * 给玩家上分
     * @param number $logtoken
     * @param number $uid           玩家uid
     * @param number $coin          上分额度
     * @param string $ipaddr
     * @return boolean
     */
    public function pushPlayerCoinUp(string $logtoken = '0', string $uid = '0', string $coin = '0', string $ipaddr = '')
    {
        $this->setPort();
        $this->timenow = time();
        
        //log_message('debug', '向GAME服务器推送数据-> PlayerCoinUp '.$this->_timefl);
        
        $data = [];
        
        if(
            ! ($data['logtoken'] = $logtoken)
            || ! ($data['uid'] = $uid)
            || ! ($data['coin'] = $coin)
            || ! ($data['ipaddr'] = $ipaddr)
            || ! ($data['mod'] = 'coin')
            || ! ($data['act'] = 'add'))
        {
            $this->error_string = "CURL参数缺失";
            return false;
        }
        elseif (
            ! ($_result = $this->simple_get($this->_game_server_host, $data, ['PORT'=> $this->_game_server_port, 'TIMEOUT'=> 5]))
            || (string)$_result !== 'succ')
        {
            $this->error_string = "游戏服无响应";
            return false;
        }
        else
        {
            return true;
        }
        
        return false;
    }
    
    /**
     * 向游戏服务推送玩家下分数据
     * 给玩家下分
     * @param string $logtoken
     * @param string $uid           玩家uid
     * @param string $coin          下分额度
     * @param string $ipaddr
     * @return boolean
     */
    public function pushPlayerCoinDown(string $logtoken = '0', string $uid = '0', string $coin = '0', string $ipaddr = '')
    {
        $this->setPort();
        $this->timenow = time();
        
        //log_message('debug', '向GAME服务器推送数据-> PlayerCoinDown '.$this->_timefl);
        
        $data = [];
        
        if(
            ! ($data['logtoken'] = $logtoken)
            || ! ($data['uid'] = $uid)
            || ! ($data['coin'] = $coin*-1)
            || ! ($data['ipaddr'] = $ipaddr)
            || ! ($data['mod'] = 'coin')
            || ! ($data['act'] = 'add'))
        {
            $this->error_string = "CURL参数缺失";
            return false;
        }
        elseif (
            ! ($_result = $this->simple_get($this->_game_server_host, $data, ['PORT'=> $this->_game_server_port, 'TIMEOUT'=> 8]))
            || (string)$_result !== 'succ')
        {
            $this->error_string = "游戏服无响应";
            return false;
        }
        else
        {
            return true;
        }
        
        return false;
    }
    
    /**
     * 向游戏服务推送查询玩家是否在线
     * 指定玩家是否在线
     * @param mixed $uid       单个uid，或者uid数组
     * @return number|boolean[]
     */
    public function getOnlinePlayerOne($uid = null)
    {
        $this->setPort();
        $this->timenow = time();
        
        if(!! ($uido = $uid) && is_array($uid)) $uid = implode(",", $uid);
        
        if(
            ! ($data['uid'] = $uid)
            || ! ($data['mod'] = 'user')
            || ! ($data['act'] = 'online'))
        {
            //$this->error_string = "CURL参数缺失";
            return -1;
        }
        else
        {
            $_result = $this->simple_get($this->_game_server_host, $data, ['PORT'=> $this->_game_server_port, 'TIMEOUT'=> 5]);
            
            if(is_array($uido))
            {
                $_r = [];
                $_r_uid = $_result ? explode(",", $_result) : [];
                
                foreach ($uido as $_uid) {
                    if($_result && in_array($_uid, $_r_uid))
                    {
                        $_r[$_uid] = true;
                    }
                    else
                    {
                        $_r[$_uid] = false;
                    }
                }
                
                return $_r;
            }
            else
            {
                return $_result ? 1 : 0;
            }
        }
        
        return -1;
    }
    
    /**
     * 向游戏服务推送询问系统当前在线总数
     * @return number
     */
    public function getStatServerOnlineTotal()
    {
        $this->setPort();
        $this->timenow = time();
        
        if(! ($data['mod'] = 'serverinfo'))
        {
            $this->error_string = "CURL参数缺失";
            return -1;
        }
        else
        {
            $_result = $this->simple_get($this->_game_server_host, $data, ['PORT'=> $this->_game_server_port, 'TIMEOUT'=> 5]);
            
            if(strpos($_result, "\"onlinenum\"") && !! ($_r = Helper::is_json_str($_result)))
            {
                return $_r['onlinenum'];
            }
            else
            {
                return -1;
            }
            
        }
        
        return -1;
    }
    
    public function faceBind($userdata)
    {
        $this->setPort();
        $this->timenow = time();
        
        $data = [
            'mod' => 'bindfb',
            'uid' => $userdata['uid'], 
            'unionid' => $userdata['unionid'],
            'nickname' => $userdata['nickname'],
            'client_uuid' => $userdata['client_uuid'],
        ];

        $_result = $this->simple_get($this->_game_server_host, $data, ['PORT'=> $this->_game_server_port, 'TIMEOUT'=> 5]);
        return false;
    }

    /**
     * 向游戏服务推送询问指定游戏当前在线总数
     * @param string $gameid
     * @return boolean|boolean|mixed
     */
    public function getStatServerGameOnline($gameid = '-1')
    {
        $this->setPort();
        $this->timenow = time();
        
        if(! ($data['mod'] = 'serverinfo') || ! ($data['gameid'] = $gameid))
        {
            $this->error_string = "CURL参数缺失";
            return false;
        }
        else
        {
            $_result = $this->simple_get($this->_game_server_host, $data, ['PORT'=> $this->_game_server_port, 'TIMEOUT'=> 5]);
            
            if(strpos($_result, "\"onlinenum\"") && strpos($_result, "\"gameinfo\"") && !! ($_r = Helper::is_json_str($_result)))
            {
                return $_r['gameinfo'];
            }
            else
            {
                return false;
            }
            
        }
        
        return false;
    }
    
    /**
     * 向游戏服务推送跑马灯广告数据
     * 跑马灯
     * @param array $data
     * @return boolean
     */
    public function pushSystemsettingNoticeRolling($data = [])
    {
        $this->setPort();
        $this->timenow = time();
        $api_url = $this->_game_server_host.'?mod=apinotice';
        if (isset($data['type'])) {
            $api_url .= '&type=5';
        }
        if (
            ! ($_result = $this->simple_post($api_url, ['msg'=> json_encode($data, JSON_UNESCAPED_UNICODE)], ['PORT'=> $this->_game_server_port, 'TIMEOUT'=> 5]))
            || (string)$_result !== 'succ')
        {
            Logger::getInstance()->log('pushSystemsettingNoticeRolling:fail' , '2gserver');
            $this->error_string = "游戏服无响应";
            return false;
        }
        else
        {
            Logger::getInstance()->log('pushSystemsettingNoticeRolling:succ' , '2gserver');
            return true;
        }
        
        return false;
    }
    
    /**
     * 向游戏服务推送玩家概率
     *
     * @param array $data
     * @return boolean
     */
    public function pushPlayerProb($uids = [], $params = [])
    {
        $this->setPort();
        $this->timenow = time();
        
        //log_message('debug', '向GAME服务器推送数据-> PlayerProb '.$this->_timefl);
        
        if(
            ! ($_result = $this->simple_post($this->_game_server_host.'?mod=rewardrate&'.http_build_query($params), json_encode(['users'=> $uids]), ['PORT'=> $this->_game_server_port, 'TIMEOUT'=> 5]))
            || (string)$_result !== 'succ')
        {
            $this->error_string = "游戏服无响应";
            return false;
        }
        else
        {
            return true;
        }
        
        return false;
    }
    
    /**
     * 从游戏服务器获取游戏列表
     * 游戏概率配置
     * uniq 是否去重  1 去重 0 不去重
     * @return boolean|number
     */
    public function getGameLists($lang, $uniq = 0)
    {
        $this->setPort();
        $this->timenow = time();
        $cache_key = 'server_gamelist';
        $data_in_cache = $this->models->rediscli_model->getDb()->get($cache_key);
        if(!$data_in_cache) {
            $gamelist_jsonstr = $this->simple_get($this->_game_server_host.'?mod=getgamelist&uniq=' . $uniq . '&lang=' . $lang, [], ['PORT'=> $this->_game_server_port, 'TIMEOUT'=> 5]);
            $result = json_decode($gamelist_jsonstr, true);
            if (isset($result['data']) && $result['data'])
            {
                $this->models->rediscli_model->getDb()->setEx($cache_key, 300, $gamelist_jsonstr);
                return $result['data'];
            }
        } else {
            $result = json_decode($data_in_cache, true);
            if (isset($result['data']) && $result['data'])
            {
                return $result['data'];
            }
        }
        return [];
    }
    
    /**
     * 从游戏服务器获取游戏服务器列表
     * @return boolean|number
     */
    public function getGameServerList()
    {
        $this->setPort();
        $this->timenow = time();
        
        if(
            ! ($_result = $this->simple_get($this->_game_server_host.'?mod=getserverlist', [], ['PORT'=> $this->_game_server_port, 'TIMEOUT'=> 5])))
        {
            $this->error_string = "游戏服无响应";
            return false;
        }
        else
        {
            return json_decode($_result, true);
        }
        
        return false;
    }
    
    /**
     * 向服务器推送游戏服务器状态
     * 修改状态
     * @return boolean|mixed
     */
    public function pushGameServerList($gameserverlist = '')
    {
        $this->setPort();
        $this->timenow = time();
        
        if (
            ! ($_result = $this->simple_post($this->_game_server_host.'?mod=closeserver', ['servername'=> $gameserverlist], ['PORT'=> $this->_game_server_port, 'TIMEOUT'=> 5]))
            || (string)$_result !== 'succ')
        {
            $this->error_string = "游戏服无响应";
            return false;
        }
        else
        {
            return true;
        }
        
        return false;
    }
    
    /**
     * 从游戏服务器获取游戏列表
     * 游戏概率配置
     * @return boolean|number
     */
    public function getProb($gameId, $type)
    {
        $this->setPort();
        $this->timenow = time();
        
        $result = json_decode($this->simple_get($this->_game_server_host.'?mod=getgamerateconf&gameid=' . $gameId . '&type=' . $type, [], ['PORT'=> $this->_game_server_port, 'TIMEOUT'=> 5]), true);
        
        if (isset($result['data']) && $result['data'])
        {
            return $result['data'];
        }
        
        return false;
    }
    
    /**
     * 修改概率配置
     * 游戏概率配置
     * @return boolean
     */
    public function pushGameProb($gameId, $type, $prob)
    {
        $this->setPort();
        $this->timenow = time();
        
        $result = $this->simple_post($this->_game_server_host.'?mod=setgamerateconf&gameid=' . $gameId . '&type=' . $type, $prob, ['PORT'=> $this->_game_server_port, 'TIMEOUT'=> 5]);
        
        if ($result == 'succ')
        {
            return true;
        }
        
        return false;
    }
    
    /**
     * 向游戏服务器推送数据
     * 修改游戏状态
     * @return boolean
     */
    public function pushSystemSettingGameStatus($gameId)
    {
        $this->setPort();
        $this->timenow = time();
        
        $result = json_decode($this->simple_post($this->_game_server_host.'?mod=setgamestatus&gameid=' . $gameId, [], ['PORT'=> $this->_game_server_port, 'TIMEOUT'=> 5]), true);
        if (isset($result['id']) && $result['id']) {

            $this->models->rediscli_model->getDb()->del('server_gamelist');
            return $result['id'];   
        }
        
        return false;
    }

    public function pushGameTag($gameids, $tag)
    {
        $this->setPort();
        $this->timenow = time();
        
        $result = $this->simple_get($this->_game_server_host.'?mod=setgametag&gameids=' . $gameids . '&tag=' . $tag, [], ['PORT'=> $this->_game_server_port, 'TIMEOUT'=> 5]);
        if ($result == 'succ')
        {
            $this->models->rediscli_model->getDb()->del('server_gamelist');
            return true;
        }
        
        return false;
    }

    public function putGameSort($gameid, $type, $ord)
    {
        $this->setPort();
        $this->timenow = time();
        
        $result = $this->simple_get($this->_game_server_host.'?mod=setgameord&gameid=' . $gameid . '&ord=' . $ord . '&type=' . $type, [], ['PORT'=> $this->_game_server_port, 'TIMEOUT'=> 5]);
        if ($result == 'succ')
        {
            return true;
        }
        
        return false;
    }
    
    public function putGameLevel($gameid, $level, $type=2)
    {
        $this->setPort();
        $this->timenow = time();
        
        $result = $this->simple_get($this->_game_server_host.'?mod=setgamelevel&gameid=' . $gameid . '&level=' . $level . '&type=' . $type, [], ['PORT'=> $this->_game_server_port, 'TIMEOUT'=> 5]);
        if ($result == 'succ')
        {
            return true;
        }
        
        return false;
    }

    function __destruct()
    {
        if ($this->flag) {
            echo "<pre>";
            print_r("释放curl对象 ".time());
            echo "</pre>".PHP_EOL;
        }
    }

    /**
     * 获取多人游戏设置
     * @return boolean|number
     */
    public function getMultgamesetting($uid, $gameId)
    {
        $this->setPort();
        $this->timenow = time();
        
        if(
            ! ($_result = $this->simple_get($this->_game_server_host.'?mod=getmultgamesetting&uid='.$uid.'&gameid='.$gameId, [], ['PORT'=> $this->_game_server_port, 'TIMEOUT'=> 5])))
        {
            $this->error_string = "游戏服无响应";
            return false;
        }
        else
        {
            return json_decode($_result, true);
        }
        
        return false;
    }

    /**
     * 修改多人游戏设置
     * @return boolean|number
     */
    public function setMultgamesetting($uid, $gameId, $setting)
    {
        $this->setPort();
        $this->timenow = time();
        
        if(
            ! ($_result = $this->simple_get($this->_game_server_host.'?mod=setmultgamesetting&uid='.$uid.'&gameid='.$gameId.'&setting='.$setting, [], ['PORT'=> $this->_game_server_port, 'TIMEOUT'=> 5]))
            || (string)$_result !== 'succ')
        {
            $this->error_string = "游戏服无响应";
            return false;
        }
        else
        {
            return true;
        }
    }

    /**
     * 获取多人游戏
     * @return boolean|number
     */
    public function getMultgame()
    {
        $this->setPort();
        $this->timenow = time();
        
        if(
            ! ($_result = $this->simple_get($this->_game_server_host.'?mod=getmultgame', [], ['PORT'=> $this->_game_server_port, 'TIMEOUT'=> 5])))
        {
            $this->error_string = "游戏服无响应";
            return false;
        }
        else
        {
            return json_decode($_result, true);
        }
        
        return false;
    }
    
    public function sendSlotsWin(string $uid = '0', string $game_id = '0', string $iswin = '0') : void
    {
        $this->setPort();
        $this->timenow = time();
        
        $this->simple_get($this->_game_server_host . '?mod=slotstimes&act=add&uid=' . $uid . '&gameid=' . $game_id . '&iswin=' . $iswin, [], ['PORT'=> $this->_game_server_port, 'TIMEOUT'=> 5]);
    }

    /**
     * 通知游戏设置变化
     * @return boolean|number
     */
    public function notifyGameSetting($uids, $gameId, $setting, $type)
    {
        $this->setPort();
        $this->timenow = time();

        $url = $this->_game_server_host.'?mod=notifygamesetting&gameid=' . $gameId . '&setting=' . $setting . '&type=' . $type;

        $result = $this->simple_post($url, ['uids'=> $uids], ['PORT'=> $this->_game_server_port, 'TIMEOUT'=> 5]);

        if ((string)$result !== 'succ') {
            $this->error_string = "游戏服无响应";
            return false;
        }
        return true;
    }
}
