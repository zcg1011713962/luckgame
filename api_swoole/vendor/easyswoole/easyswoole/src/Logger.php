<?php
namespace EasySwoole\EasySwoole;

use EasySwoole\Component\Singleton;
use EasySwoole\EasySwoole\Console\ConsoleService;
use EasySwoole\Trace\AbstractInterface\LoggerInterface;
use EasySwoole\Trace\Bean\Location;

class Logger implements LoggerInterface
{
    private $logger;
    use Singleton;

    function __construct(LoggerInterface $logger)
    {
        $this->logger = $logger;
    }
    
    public function log(string $str, $logCategory = null, int $timestamp = null, bool $modeHour = false):?string
    {
        // TODO: Implement log() method.
        if($logCategory == null){
            $logCategory = 'default';
        }
        $str = $this->logger->log($str,$logCategory,$timestamp,$modeHour);
        if(Config::getInstance()->getConf('CONSOLE.PUSH_LOG')){
            ConsoleService::getInstance()->push($str);
        }
        return $str;
    }

    public function logWithLocation(string $str,$logCategory = null,int $timestamp = null):?string
    {
        $location = $this->getLocation();
        $str = "[file:{$location->getFile()}][line:{$location->getLine()}]{$str}";
        return $this->log($str,$logCategory);
    }

    public function console(string $str, $category = null, $saveLog = true):?string
    {
        // TODO: Implement console() method.
        if($category == null){
            $category = 'default';
        }
        $final = $this->logger->console($str,$category,false);
        if($saveLog){
            $this->log($str,$category);
        }
        return $final;
    }

    public function consoleWithLocation(string $str, $category = null, $saveLog = true):?string
    {
        // TODO: Implement console() method.
        $location = $this->getLocation();
        $str = "[file:{$location->getFile()}][line:{$location->getLine()}]{$str}";
        return $this->console($str,$category,$saveLog);
    }

    private function getLocation():Location
    {
        $location = new Location();
        $debugTrace = debug_backtrace();
        array_shift($debugTrace);
        $caller = array_shift($debugTrace);
        $location->setLine($caller['line']);
        $location->setFile($caller['file']);
        return $location;
    }
}