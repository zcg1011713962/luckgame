<?php
namespace app\agent\controller;
use think\Controller;
use app\agent\controller\Parents;

class Order extends Parents
{
    public function lists()
    {
        return $this->fetch();
    }
	
	public function add()
	{
	    return $this->fetch();
	}
	
	public function info()
	{
	    return $this->fetch();
	}	
}
