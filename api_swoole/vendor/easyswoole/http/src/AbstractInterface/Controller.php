<?php
namespace EasySwoole\Http\AbstractInterface;

use EasySwoole\Http\Message\Status;
use EasySwoole\Http\Request;
use EasySwoole\Http\Response;
use EasySwoole\Http\Session\SessionDriver;
use EasySwoole\Validate\Validate;

// ================== Models ==================
use App\Model\ModelObject;
use App\Model\Account;
use App\Model\System;
use App\Model\Finance;
use App\Model\RedisCli;
use App\Model\Curl;
use App\Model\Stat;
use App\Model\Report;
use App\Model\Prob;
use App\Model\Platform;
use App\Model\Activity;
use App\Utility\Helper;
use EasySwoole\EasySwoole\Logger;
use EasySwoole\EasySwoole\ServerManager;

/**
 * ================== Models ==================
 * @property RedisCli $rediscli_model
 * @property Account $account_model
 * @property System $system_model
 * @property Finance $finance_model
 * @property Curl $curl_model
 * @property Stat $stat_model
 * @property Report $report_model
 * @property Prob $prob_model
 * @property Platform $platform_model
 * @property Activity $activity_model
 */

abstract class Controller
{
    private $request;
    private $response;
    private $actionName;
    private $session;
    private $sessionDriver = SessionDriver::class;
    private $allowMethods = [];
    private $defaultProperties = [];
    
    /**
     * HTTP请求参数
     * @var array
     */
    protected $Pars = [];
    /**
     * Controller DB变量集合
     * @var object
     */
    protected $dbs = null;
    /**
     * Controller 共享变量
     * @var array
     */
    protected $vars = null;
    /**
     * Controller Model实例集合
     * @var object
     */
    protected $models = null;
    /**
     * 是否输出json数据日志
     * @var bool
     */
    protected $outLog = true;
    
    function __construct()
    {
        //支持在子类控制器中以private，protected来修饰某个方法不可见
        $list = [];
        $ref = new \ReflectionClass(static::class);
        $public = $ref->getMethods(\ReflectionMethod::IS_PUBLIC);
        foreach ($public as $item) {
            array_push($list, $item->getName());
        }
        $this->allowMethods = array_diff($list,
            [
                '__hook', '__destruct',
                '__clone', '__construct', '__call',
                '__callStatic', '__get', '__set',
                '__isset', '__unset', '__sleep',
                '__wakeup', '__toString', '__invoke',
                '__set_state', '__clone', '__debugInfo'
            ]
        );
        //获取，生成属性默认值
        $ref = new \ReflectionClass(static::class);
        $properties = $ref->getProperties();
        foreach ($properties as $property) {
            //不重置静态变量
            if (($property->isPublic() || $property->isProtected()) && !$property->isStatic()) {
                $name = $property->getName();
                $this->defaultProperties[$name] = $this->$name;
            }
        }
    }

    abstract function index();
    
    public function __get(string $name = '')
    {
        //创建Model实例
        $_modelName = $_modelDirectory = "";
        if (substr_count($name, '_model') === 1) {
            $_modelName = substr($name, 0, strpos($name, '_model'));
            if (substr_count($_modelName, '_') === 1) {
                list($_modelDirectory, $_modelName) = explode("_", $_modelName);
                $_modelDirectory = ucfirst($_modelDirectory);
                $_modelName = ucfirst($_modelName);
            } elseif (substr_count($_modelName, '_') === 0) {
                $_modelName = ucfirst($_modelName);
            } else {
                return null;
            }
            //模型对象存在
            if (isset($this->models->{$name})) {
                return $this->models->{$name};
            }
            //需要动态创建模型对象
            else {
                if (! is_object($this->dbs)) {
                    $this->dbs = (object)$this->dbs;
                }
                if (! is_array($this->vars)) {
                    $this->vars = (array)$this->vars;
                }
                if (! is_object($this->models)) {
                    $this->models = new ModelObject($this->dbs, $this->vars);
                    $this->models->setModels($this->models);
                }
                try {
                    $this->modelClass = '\\App\\Model\\' . ($_modelDirectory ? $_modelDirectory . '\\' : '') . $_modelName;
                    $this->models->{$name} = new $this->modelClass();
                } catch (\Throwable $throwable) {
                    $this->modelClass = Helper::getModelClassName($_modelDirectory, $_modelName);
                    $this->models->{$name} = new $this->modelClass();
                }
                $this->models->{$name}->setModels($this->models);
                return $this->models->{$name};
            }
        }
        
        return null;
    }
    
    protected function gc()
    {
        // TODO: Implement gc() method.
        if ($this->session instanceof SessionDriver) {
            $this->session->writeClose();
            $this->session = null;
        }
        
        //恢复默认值
        foreach ($this->defaultProperties as $property => $value) {
            $this->$property = $value;
        }
    }

    protected function actionNotFound(?string $action): void
    {
        $this->response()->write("
   _________  ____________  __
  / ___/ __ \/ ___/ ___/ / / /
 (__  ) /_/ / /  / /  / /_/ / 
/____/\____/_/  /_/   \__, /  
                     /____/
");
        $this->response()->withStatus(Status::CODE_NOT_FOUND);
    }

    protected function afterAction(?string $actionName): void
    {
    }

    protected function onException(\Throwable $throwable): void
    {
        throw $throwable;
    }

    protected function onRequest(?string $action, ?string $method): ?bool
    {
        return true;
    }

    protected function getActionName(): ?string
    {
        return $this->actionName;
    }

    public function __hook(?string $actionName, Request $request, Response $response):? string
    {
        $method = strtolower($request->getMethod());
        //区分请求类型 GET POST PUT
        $actionNameFinal = $actionName && $method !== 'get' ? "{$actionName}_{$method}" : $actionName;
        $forwardPath = null;
        $this->request = $request;
        $this->response = $response;
        $this->actionName = $actionNameFinal;
        
        try {
            if ($this->onRequest($actionNameFinal, $method) !== false) {
                if (in_array($actionNameFinal, $this->allowMethods)) {
                    $forwardPath = $this->$actionNameFinal();
                } else {
                    $forwardPath = $this->actionNotFound($actionNameFinal);
                }
            }
        } catch (\Throwable $throwable) {
            //若没有重构onException，直接抛出给上层
            $this->onException($throwable);
        } finally {
            try {
                $this->afterAction($actionNameFinal);
            } catch (\Throwable $throwable) {
                $this->onException($throwable);
            } finally {
                try {
                    $this->gc();
                } catch (\Throwable $throwable) {
                    $this->onException($throwable);
                }
            }
        }
        if (is_string($forwardPath)) {
            return $forwardPath;
        }
        return null;
    }

    protected function request(): Request
    {
        return $this->request;
    }

    protected function response(): Response
    {
        return $this->response;
    }
    
    protected function getIpAddr(string $headerName = 'x-real-ip') : string
    {
        $server = ServerManager::getInstance()->getSwooleServer();
        $client = $server->getClientInfo($this->request()->getSwooleRequest()->fd);
        $clientAddress = $client['remote_ip'] ?? '0.0.0.0';
        $xri = $this->request()->getHeader($headerName);
        $xff = $this->request()->getHeader('x-forwarded-for');
        if ($clientAddress === '127.0.0.1') {
            if (!empty($xri)) {
                $clientAddress = $xri[0] ?? '0.0.0.0';
            } elseif (! empty($xff) && isset($xff[0])) {
                $list = explode(',', $xff[0]);
                if (isset($list[0])) $clientAddress = $list[0] ?? '0.0.0.0';
            }
        }

        $clientAddress = substr_count($clientAddress, ':') == 1 && ($sindex = strpos($clientAddress, ':')) > 6 ? 
        substr($clientAddress, 0, $sindex) 
        : (substr_count($clientAddress, ':') ? '0.0.0.0' : $clientAddress);

        return $clientAddress;
    }

    protected function writeJson($statusCode = 0, $msg = null, $result = null, $rover = false)
    {
        if (! $this->response()->isEndResponse()) {
            if ($statusCode === 200) {
                $data = [
                    "errcode"=> 0,
                    "error"=> isset($this->vars['ApiErr']['ErrMsg'][0]) && $this->vars['ApiErr']['ErrMsg'][0] ? $this->vars['ApiErr']['ErrMsg'][0] : (is_string($msg) ? $msg : ''),
                    "data"=> is_array($msg) && ! $result && ! $rover ? $msg : $result
                ];
            } else {
                $_err_code = 0;
                $_err_msg = "";
                $_err_msg_cover = false;
                $_err_data = [];
                
                if (!! ($_di_apierr = $rover ? (isset($this->vars['ApiErr']) ? $this->vars['ApiErr'] : null) : null)) {
                    $_err_code = isset($_di_apierr['ErrCode']) && is_numeric($_di_apierr['ErrCode']) ? $_di_apierr['ErrCode'] : "0";
                    
                    list($_err_msg, $_err_msg_cover) = isset($_di_apierr['ErrMsg']) && is_array($_di_apierr['ErrMsg']) && count($_di_apierr['ErrMsg']) === 2 ? $_di_apierr['ErrMsg'] : ['', false];
                    $_err_msg = $_err_msg_cover ? $_err_msg : (($msg ? $msg."，" : "") . $_err_msg);
                    
                    $_err_data = isset($_di_apierr['ErrData']) && is_array($_di_apierr['ErrData']) ? $_di_apierr['ErrData'] : [];
                }
                
                $data = [
                    "errcode"=> $_err_code ?: $statusCode,
                    "error"=> $_err_msg ?: $msg,
                    "data"=> $_err_data ?: ($result ?: [])
                ];
            }
        }
        
        if (isset($data)) {
            if ($this->outLog) {
                Logger::getInstance()->log(PHP_EOL . 'METHOD   > ' . $this->request()->getUri() . PHP_EOL .'REQUEST  > '.json_encode($this->request()->getRequestParam(), JSON_UNESCAPED_UNICODE) . PHP_EOL . 'RESPONSE > ' . json_encode($data, JSON_UNESCAPED_UNICODE) . PHP_EOL, 'api-rr', null, true);
            }
            $this->response()->write(json_encode($data, JSON_UNESCAPED_UNICODE|JSON_UNESCAPED_SLASHES));
            $this->response()->withHeader('Content-type', 'application/json;charset=utf-8');
            $this->response()->withStatus($statusCode);
            return true;
        } else {
            trigger_error("response has end");
            return false;
        }
    }
    
    protected function json(): ?array
    {
        return json_decode($this->request()->getBody()->__toString(), true);
    }
    
    private function badRequest()
    {
        $this->writeJson(500 , 'request error ...', []);
        return false;
    }
    
    protected function colationPars(...$args)
    {
        if (! $args) {

            return $this->badRequest();
        }
        
        // 'get(请求类型)', [(规则)], false(验证token)
        if (is_string($args[0]) && in_array(strtolower($args[0]), [Helper::HTTP_GET, Helper::HTTP_POST, Helper::HTTP_PUT, Helper::HTTP_DELETE])) {
            $pkeys = isset($args[1]) && is_array($args[1]) ? $args[1] : [];
            $authToken = isset($args[2]) && is_bool($args[2]) ? $args[2] : false;
        }
        //[(规则)], false(验证token)
        elseif (is_array($args[0]) && ! isset($args[0][0])) {
            if (
                count($this->allowMethods) == 1
                || (!empty($_lastaction = end($this->allowMethods)) && substr($_lastaction, strripos($_lastaction, '_')+1) === strtolower($this->request()->getMethod()))
            ) {
                $pkeys = $args[0];
                $authToken = isset($args[1]) && is_bool($args[1]) ? $args[1] : false;
            } else {
                return $this->badRequest();
            }
        }
        //[(多请求类型)(规则)]
        elseif (is_array($args[0]) && isset($args[0][0])) {
            foreach ($args[0] as $rule) {
                if ($rule[0] === strtolower($this->request()->getMethod())) {
                    $pkeys = isset($rule[1]) ? $rule[1] : [];
                    $authToken = isset($rule[2]) ? $rule[2] : false;
                    break;
                }
            }
        }
        //false(验证token)
        elseif (is_bool($args[0])) {
            $pkeys = [];
            $authToken = $args[0];
        } else {
            return $this->badRequest();
        }
        
        $err_code = 0;
        $err_msg = '';
        $err_data = [];
        $r = [];
        
        $_reqOpen = strpos(strtolower($this->request->getUri()->__toString()), '/open/');
        if ($authToken || $_reqOpen) {
            //开放平台入口
            if ($_reqOpen) {
                //加入验证
                $_pkeys['appid'] = [true, 'abs', function($f){ return $f > 0; }];
                $_pkeys['timestamp'] = [true, 'str', function($f){ return $f > 0 && strtotime(date('Y-m-d H:i:s', $f)) === (int)$f; }];
                $_pkeys['sign'] = [true, 'str', function($f){ return preg_match('/^[a-z0-9]{32}$/i', $f) ? true : false; }];
                $pkeys = array_merge($_pkeys, $pkeys);
            }
            //默认入口
            else {
                //加入token验证
                if ($pkeys) {
                    $pkeys = array_merge(['token'=> [true, 'str', function($f){ return preg_match('/^[a-z0-9]{32}$/i', $f) ? true : false; }]], $pkeys);
                } else {
                    $pkeys['token'] = [true, 'str', function($f){ return preg_match('/^[a-z0-9]{32}$/i', $f) ? true : false; }];
                }
            }
        }
        
        if (! $pkeys || ! is_array($pkeys)) return $r;
        
        foreach ($pkeys as $key => $val) {
            if (is_numeric($key)) {
                if (($_p = $this->request()->getRequestParam($val)) === null) {
                    $err_code = 2001;
                    $err_msg = sprintf('缺少必要参数 %s', $val);
                    $err_data = ['field'=> $key];
                    break;
                } elseif ($_p === '') {
                    $err_code = 2002;
                    $err_msg = sprintf('参数 %s 不能为空', $val);
                    $err_data = ['field'=> $key];
                    break;
                }
                
                $r[$val] = $_p;
            } else {
                if (($_p = $this->request()->getRequestParam($key)) === null && $val[0] === true) {
                    $err_code = 2001;
                    $err_msg = sprintf('缺少必要参数 %s', $key);
                    $err_data = ['field'=> $key];
                    break;
                } elseif ($_p !== null) {
                    if (isset($val[1]) && $val[1] === 'int') {
                        $_p = intval($_p);
                    } elseif (isset($val[1]) && $val[1] === 'abs') {
                        $_p = abs(intval($_p));
                    } elseif (isset($val[1]) && $val[1] === 'float') {
                        $_p = substr(sprintf("%.5f", $_p),0,-1);
                    } elseif (isset($val[1]) && $val[1] === 'str') {
                        $_xss = new \App\Utility\Xss();
                        $_p = $_xss->xss_clean($_p);
                    } elseif (isset($val[1]) && $val[1] === 'stro') {
                        $_p = (string)$_p;
                    } elseif (isset($val[1]) && $val[1] === 'coin') {
                        $_p = \App\Utility\Helper::format_money($_p);
                    }
                    
                    if (isset($val[2]) && $val[2] && is_bool(($_fr = $val[2]($_p))) && $_fr === false) {
                        $err_code = 2003;
                        $err_msg = sprintf('参数 %s 值非法', $key);
                        $err_data = ['field'=> $key];
                        break;
                    } elseif (isset($val[2]) && $val[2] && is_array(($_fr = $val[2]($_p))) && $_fr[0] === false) {
                        $err_code = 2003;
                        $err_msg = sprintf($_fr[1], $key);
                        $err_data = ['field'=> $key];
                        break;
                    }
                    
                    $r[$key] = $_p;
                } else {
                    $r[$key] = null;
                }
            }
        }
        
        if ($err_msg) {
            $this->writeJson($err_code , $err_msg, $err_data);
            return false;
        }
        
        //开放平台
        if ($_reqOpen) {
            if (time() - (int)$r['timestamp'] > 600) {
                $this->writeJson(1001 , 'timestamp已过期');
                return false;
            }
            if (! ($appKey = $this->account_model->getAppKeyByAppID($r['appid']))) {
                $this->writeJson(1001 , 'appid无效');
                return false;
            }
            $sign = $r['sign'];
            unset($r['sign']);
            ksort($r);
            $_sign = md5(implode("", $r) . $appKey);
            if ($sign !== $_sign) {
                $this->writeJson(1001 , 'sign无效');
                return false;
            }
            if (! ($_token = $this->account_model->getAccountByAppID($r['appid']))) {
                $this->writeJson(1001 , 'appid无效');
                return false;
            } else {
                //如果是代理子账号，则需要追加主账号数据
                if (isset($_token['virtual_parent_id']) && $_token['virtual_parent_id']) {
                    if (!! ($parentAgent = $this->account_model->getAgent(null, $_token['virtual_parent_id']))) {
                        $_token = array_merge($_token, $parentAgent);
                    }
                }
                //如果是代理身份，则需要获取最新的coin值
                if ($_token['account_agent'] > 0) {
                    //是否被禁用了账号
                    if ($this->account_model->checkAccountBan($_token['account_id'])) {
                        $this->writeJson(1001 , 'token无效');
                        return false;
                    }
                    $_token['account_coin'] = $this->account_model->getCoinFieldValue($_token['account_id']);
                }
                $this->dbs->token = $_token;
            }
            unset($r['appid']);
            unset($r['sign']);
            unset($r['timestamp']);
            $r['api_unique_identification'] = time();
            //格式化账号格式
            /* if (isset($r['account']) && $r['account']) {
                $r['account'] = Helper::account_format_login($r['account']);
            } */
        }
        //默认
        elseif (isset($r['token']) && $r['token']) {
            if (! ($_token = $this->account_model->getAccountByToken($r['token']))) {
                $this->writeJson(1001 , 'token无效');
                return false;
            } else {
                //如果是代理子账号，则需要追加主账号数据
                if (isset($_token['virtual_parent_id']) && $_token['virtual_parent_id']) {
                    if (!! ($parentAgent = $this->account_model->getAgent(null, $_token['virtual_parent_id']))) {
                        $_token = array_merge($_token, $parentAgent);
                    }
                }
                //如果是代理身份，则需要获取最新的coin值
                if ($_token['account_agent'] > 0) {
                    //是否被禁用了账号
                    if ($this->account_model->checkAccountBan($_token['account_id'])) {
                        $this->writeJson(1001 , 'token无效');
                        return false;
                    }
                    $_token['account_coin'] = $this->account_model->getCoinFieldValue($_token['account_id']);
                }
                $this->dbs->token = $_token;
            }
        }
        
        return !! ($this->Pars = $r);
    }

    protected function xml($options = LIBXML_NOERROR, string $className = 'SimpleXMLElement')
    {
        //禁止引用外部xml实体
        libxml_disable_entity_loader(true);
        return simplexml_load_string($this->request()->getBody()->__toString(), $className, $options);
    }

    protected function validate(Validate $validate)
    {
        return $validate->validate($this->request()->getRequestParam());
    }

    protected function session(\SessionHandlerInterface $sessionHandler = null): SessionDriver
    {
        if ($this->session == null) {
            $class = $this->sessionDriver;
            $this->session = new $class($this->request, $this->response, $sessionHandler);
        }
        return $this->session;
    }

    protected function sessionDriver(string $sessionDriver): Controller
    {
        $this->sessionDriver = $sessionDriver;
        return $this;
    }
}