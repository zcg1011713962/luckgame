<?php
namespace EasySwoole\Component\Tests;

use EasySwoole\Component\Context\ContextItemHandlerInterface;
use EasySwoole\Utility\Random;

class ContextContextItemHandler implements ContextItemHandlerInterface
{

    function onContextCreate()
    {
        // TODO: Implement onContextCreate() method.
        $stdClass = new \stdClass();
        $stdClass->text = 'handler';
        return $stdClass;
    }

    function onDestroy($context)
    {
        // TODO: Implement onDestroy() method.
        $context->destroy = true;
    }
}