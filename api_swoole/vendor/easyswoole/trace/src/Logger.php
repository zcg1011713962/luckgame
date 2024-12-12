<?php
namespace EasySwoole\Trace;

use EasySwoole\Trace\AbstractInterface\LoggerInterface;

class Logger implements LoggerInterface
{
    private $logDir;

    function __construct(string $logDir = null)
    {
        if(empty($logDir)){
            $logDir = getcwd();
        }
        $this->logDir = $logDir;
    }

    public function log(string $str, $logCategory = null,int $timestamp = null, bool $modeHour = false):?string
    {
        // TODO: Implement log() method.
        if($timestamp == null){
            $timestamp = time();
        }
        $date = date('Y-m-d h:i:s',$timestamp);
        $filePrefix = $logCategory.'-'.($modeHour ? date('Y-m-d-H',$timestamp) : date('Y-m-d',$timestamp));
        $filePath = $this->logDir."/{$filePrefix}.log";
        $str = "[$date][{$logCategory}]{$str}";
        file_put_contents($filePath,"{$str}\n",FILE_APPEND|LOCK_EX);
        return $str;
    }

    public function console(string $str, $category = null, $saveLog = true):?string
    {
        // TODO: Implement console() method.
        $time = time();
        $date = date('Y-m-d h:i:s',$time);
        $final = "[{$date}][{$category}]{$str}";
        if($saveLog){
            $this->log($str,$category,$time);
        }
        echo $final."\n";
        return $final;
    }
}