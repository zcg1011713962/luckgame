<?php
namespace app\api\controller;
use app\api\controller\Init;
use app\api\controller\Curl;
use think\facade\Request;
use think\facade\Log;
use app\api\model\UserModel;
use app\api\model\EncnumModel;
use app\api\model\PayOrderModel;
use app\api\utils\FatpagPayUtil;
//betcatpay 支付
class FatpagPay extends Init{
 
   
   public function __construct(){
      parent::__construct();
      $this->secretkey=getenv("SECRET_FATPAG");
      $this->mchId=getenv("MCHID_FATPAG");
      $this->paymentNotify=getenv("NOTIFY_FATPAG_PAYMENT"); 
      $this->payoutNotify=getenv("NOTIFY_FATPAG_PAYOUT"); 
   }  
   private $payUtil=null;
   //创建代收订单
   /*
      orderId 订单ID 
      amount 金额 0.00
      currency 币种 BRL  
      reutrnUrl 同步通知地址
      remark 备注信息
      devedor 指定支付人
        cpf 信息必需
        nome 名字必需 
      uid 用户ID
      product_id 商品ID
  */
   public function createPaymentOrder(){
       //$this->payUtil=new betcatpayUtils;
       $this->getPayUtil();
       $params=request()->param();
       //获取订单号
       if(empty($params["orderId"]) ||
           empty($params["amount"])
         ){
           $this->error("参数错误","/api/fatpagpay/createPaymentOrder");
        }            
        if(empty($params["currency"])){
           $params["currency"]="BRL";
        }
       $param=array(
            "mchId"=>$this->mchId,
            "orderNo"=>$params["orderId"],
            "amount"=>$params["amount"],
            "returnUrl"=>$this->paymentNotify,
            "notifyUrl"=>$this->paymentNotify,
            "goods"=>$params["goods"],
            "bankcode"=>"all",
            "product"=>"baxipix",
        );
            //"returnUrl"=>$params["returnUrl"],
        $model= new PayOrderModel;
        $data=$this->payUtil->APIPay($param);
         $record=array("order_id"=>md5("fatpag".$param["orderNo"]),
               "mer_order_no"=>$param["orderNo"],
               "amount"=>$param["amount"],
               "order_type"=>0,
               "request_detail"=>json_encode($param),
               "response_detail"=>$data["body"],
               "channel_type"=>"fatpag",
               "uid"=>$params["uid"],
               "notify_url"=>$params["returnUrl"],
               "product_id"=>$params["product_id"],
        );
        Log::info("payment create order params: ".json_encode($param)."\t orderInfo: ".$data["body"]);     
        $result=json_decode($data["body"],true); 
        if($result["retCode"]!="SUCCESS" ){
           $record["order_status"]=-4;
           $record["msg"]=$result["retMsg"];
            $model->addPayOrder($record);
           return json_encode(array("code"=>$result["code"],"msg"=>"fail","error"=>$result["retMsg"]));
        }
        $record["pay_order_no"]=$result["platOrder"];
        $record["pay_url"]=$result["payUrl"];
        $model->addPayOrder($record);
        $ret=array(
          "orderStatus"=>1,
          "amount"=>$param["amount"],
          "attach"=>$params["remark"],
          "orderNo"=>$result["platOrder"],
          "merOrderNo"=>$result["orderNo"],
          "createTime"=>time()."000",
          "updateTime"=>time()."000",
          "currency"=> $params["currency"],
          "sign"=>$result["sign"],
          "params"=>array(
            "qrcode"=>$result["code"],
            "url"=>$result["payUrl"],
           ),
         );
        return json_encode(array("code"=>200,"msg"=>"success","data"=>$ret));
   }

   //查询代收订单
   public function queryPaymentOrder(){
       $this->getPayUtil();
       $params=request()->param();
       if(empty($params["merOrderNo"]) ){
           $this->error("参数错误","/api/fatpagpay/queryPaymentOrder");
       }  
       $param=array("orderNo"=>$params["merOrderNo"]);  
       $param["mchId"]=$this->mchId;
       $sign=$this->payUtil->paySign($params);
       $param["sign"]=$sign;
        $url=$this->payUtil->PAYIN_QUERY_URL;
        $data=$this->payUtil->post_form($url,$params);
        $result=json_decode($data["body"],true);
        Log::info("query payin order  info: ".$data["body"]);
        $result=json_decode($data["body"],true);
        if($result["retCode"]!="SUCCESS"){
           return json_encode(array("code"=>400,"msg"=>"fail","error"=>$result["retMsg"]));
        }
        else{
         return json_encode(array("code"=>200,"msg"=>"success","data"=>array("mchId"=>$result["mchId"],"merOrderNo"=>$result["orderNo"],"amount"=>$result["amount"],"orderStatus"=>$result["status"])));
       }
   }

   //代付订单
   /*
    
   */
   public function createPayoutOrder(){
       $this->getPayUtil();
       $params=request()->param();
       if(empty($params["currency"])){
          $params["currency"]="BRL";
       } 
       if(empty($params["amount"])||empty($params["extra"])
          ||empty($params["extra"]["bankCode"])
          ||empty($params["extra"]["accountNo"])
          ||empty($params["extra"]["accountName"])
          ||empty($params["orderId"])
          || empty($params["remarkInfo"])
        ){
           $this->error("参数错误 ".json_encode($params),"/api/fatpagpay/createPayoutOrder");
        }
        $param=array(
           "type"=>"api",
           "amount"=>$params["amount"],
           "mchTransNo"=>$params["orderId"],
           "notifyUrl"=>$this->payoutNotify,
           "extra"=>$params["extra"],
           "mchId"=>$this->mchId,
           "accoutName"=>$params["extra"]["accountName"],
           "accountNo"=>$params["extra"]["accountNo"],
           "bankCode"=>$params["extra"]["bankCode"],
           "remarkInfo"=>$params["remarkInfo"],
       );
       $data=$this->payUtil->APITrans($param);
       $result=json_decode($data["body"],true);
       Log::info($data);
       $model= new PayOrderModel;
       $record=array("order_id"=>md5("fatpag".$param["mchTransNo"]),
               "mer_order_no"=>$param["mchTransNo"],
               "amount"=>$param["amount"],
               "order_type"=>1,
              
               "request_detail"=>json_encode($param),
               "response_detail"=>$data["body"],
               "channel_type"=>"fatpag",
               "uid"=>$params["uid"],
               "notify_url"=>$params["returnUrl"],
        );

       if($result["retCode"]!="SUCCESS"){
           $record["order_status"]=-4;
           $record["msg"]=$result["error"];
           $model->addPayOrder($record);
          return json_encode(array("code"=>$result["code"],"msg"=>"fail","error"=>$result["retMsg"]));
       }else{
        $record["order_status"]=$result["status"];
        $record["pay_order_no"]=$result["platOrder"];
        $ret=array(
           "orderStatus"=>$result["status"],
           "orderNo"=>$result["platOrder"],
           "merOrderNo"=>$result["mchTransNo"],
           "amount"=>$params["amount"],
           "curreny"=>$params["currency"],
           "createTime"=>time()."000",
           "updateTime"=>time()."000",
           "sign"=>$this->payUtil->PaySign($param),
        );   
        $model->addPayOrder($record);
          return json_encode(array("code"=>200,"msg"=>"success","data"=>$ret));
       }
   }
         
   //查询代付订单
   public function queryPayoutOrder(){
       $this->getPayUtil();
       $params=request()->param();
       if(empty($params["merOrderNo"]) ){
           $this->error("参数错误","/api/fatpagpay/queryPayoutOrder");
       }  
       $param=array("mchTransNo"=>$params["merOrderNo"]);  
       $param["mchId"]=$this->mchId;
       $sign=$this->payUtil->paySign($params);
       $param["sign"]=$sign;
        $url=$this->payUtil->PAYOUT_QUERY_URL;
        $data=$this->payUtil->post_form($url,$params);
        $result=json_decode($data["body"],true);
        Log::info("query payout order  info: ".$data["body"]);
        $result=json_decode($data["body"],true);
        if($result["retCode"]!="SUCCESS"){
           return json_encode(array("code"=>400,"msg"=>"fail","error"=>$result["retMsg"]));
        }
        else{
         return json_encode(array("code"=>200,"msg"=>"success","data"=>array("mchId"=>$result["mchId"],"merOrderNo"=>$result["mchTransNo"],"amount"=>$result["amount"],"orderStatus"=>$result["status"])));
       }
   }

   //账户余额查询
   public function queryAccountBalance(){
        $this->getPayUtil();
        $appId=request()->param("mchId");
        if(empty($appId)){
           $appId=$this->mchId;
        }
        $params=array("mchId"=>$appId);
        $sign=$this->payUtil->paySign($params);
        $params["sign"]=$sign;
        $url=$this->payUtil->ACCOUNT_BALANCE_URL;
        $data=$this->payUtil->post_form($url,$params);
        $result=json_decode($data["body"],true);
        Log::info("query balance info: ".$data["body"]);
        $result=json_decode($data["body"],true);
        // echo $data["body"]."\n";
         
        if($result["retCode"]!="SUCCESS"){
          return json_encode(array("code"=>400,"msg"=>"fail","error"=>$result["retMsg"]));
        }
        else{
          return json_encode(array("code"=>200,"msg"=>"success","data"=>array("mchId"=>$appId,"balance"=>$result["balance"])));
        }
        
   }

   private  function getPayUtil(){
      if(empty($this->payUtil)){
          $this->payUtil= new FatpagPayUtil;
          
      }
      $this->payUtil->setSignKey($this->secretkey);
      return $this->payUtil;
   }
}
?>
