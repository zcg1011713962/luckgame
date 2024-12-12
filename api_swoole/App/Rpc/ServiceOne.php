<?php
namespace App\Rpc;

class ServiceOne extends AbstractService
{
    function a1(){
        $this->getResponse()->setMessage('测试方法');
    }
}