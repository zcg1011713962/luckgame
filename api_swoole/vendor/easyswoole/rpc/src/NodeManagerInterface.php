<?php
namespace EasySwoole\Rpc;

interface NodeManagerInterface
{
    function getServiceNodes(string $serviceName,?string $version = null):array;
    function getServiceNode(string $serviceName,?string $version = null):?ServiceNode;
    function refreshServiceNode(ServiceNode $serviceNode);
    function allServiceNodes():array ;
    function offlineServiceNode(ServiceNode $serviceNode);
}