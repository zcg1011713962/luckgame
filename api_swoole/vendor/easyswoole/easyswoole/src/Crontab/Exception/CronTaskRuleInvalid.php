<?php
namespace EasySwoole\EasySwoole\Crontab\Exception;

use Throwable;

class CronTaskRuleInvalid extends CrontabException
{
    protected $taskName;
    protected $taskRule;

    function __construct(string $taskName = "", $taskRule = "", Throwable $previous = null)
    {
        $this->taskName = $taskName;
        $this->taskRule = $taskRule;
        parent::__construct("the cron task {$taskName} rule {$taskRule} is invalid", 0, $previous);
    }

    function getTaskName()
    {
        return $this->taskName;
    }

    function getTaskRule()
    {
        return $this->taskRule;
    }
}