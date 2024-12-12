<?php
namespace App\Model;

use App\Model\Model;

class ModelAssemble extends Model
{
    function __destruct()
    {
        $this->__destructModels();
    }
}