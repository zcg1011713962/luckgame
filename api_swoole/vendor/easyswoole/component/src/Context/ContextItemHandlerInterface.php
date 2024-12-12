<?php
namespace EasySwoole\Component\Context;

interface ContextItemHandlerInterface
{
    function onContextCreate();
    function onDestroy($context);
}