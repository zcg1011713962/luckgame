<?php
namespace app\admin\controller;
use think\Controller;
use app\admin\controller\Parents;

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
