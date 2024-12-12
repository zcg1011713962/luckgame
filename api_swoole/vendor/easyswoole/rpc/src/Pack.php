<?php
namespace EasySwoole\Rpc;

class Pack
{
    public static function pack(string $data):string
    {
        return pack('N', strlen($data)).$data;
    }

    public static function unpack(string $data):string
    {
        return substr($data,'4');
    }
}