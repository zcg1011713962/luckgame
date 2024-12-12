<?php
namespace EasySwoole\Socket\AbstractInterface;

use EasySwoole\Socket\Bean\Caller;
use EasySwoole\Socket\Bean\Response;

interface ParserInterface
{
    public function decode($raw,$client):?Caller;

    public function encode(Response $response,$client):?string ;
}