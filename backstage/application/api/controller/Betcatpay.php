<?php
namespace app\api\controller;
use app\api\controller\Init;
use app\api\controller\Curl;
use think\facade\Request;
use think\facade\Log;
use app\api\model\UserModel;
use app\api\model\EncnumModel;
use app\api\model\PayOrderModel;
use app\api\utils\betcatpayUtils;
//betcatpay 支付
class BetcatPay extends Init{
 
   
   public function __construct(){
      parent::__construct();
      $this->payment_appId=getenv("APPID_BETCAT_PAYMENT");
      $this->payout_appId = getenv("APPID_BETCAT_PAYOUT");
      $this->payment_secretKey=getenv("SECRET_BETCAT_PAYMENT");
      $this->payout_secretKey=getenv("SECRET_BETCAT_PAYOUT");
      $this->apiurl=getenv("BETCAT_HOST");
      $this->returnUrl=getenv("NOTIFY_BETCAT_PAYMENT");
      $this->paymentNotify=getenv("NOTIFY_BETCAT_PAYMENT");
      $this->notifyUrl=getenv("NOTIFY_BETCAT_PAYOUT");
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
           $this->error("参数错误","/api/BetcatPay/createPaymentOrder");
        }            
        if(empty($params["currency"])){
           $params["currency"]="BRL";
        }
      /*
        if(empty($params["returnUrl"])){
           $params["returnUrl"]=$this->returnUrl;
        }*/
       $param=array(
            "currency"=>$params["currency"],
            "appId"=>$this->payment_appId,
            "merOrderNo"=>$params["orderId"],
            "amount"=>$params["amount"],
            "returnUrl"=>$this->paymentNotify,
            "notifyUrl"=>$this->paymentNotify,
        );
            //"returnUrl"=>$params["returnUrl"],
        if(isset($params["remark"])){
          $param["attach"]=$params["remark"];
        }
        if(isset($params["devedor"])){
           $param["devedor"]=$params["devedor"];
        }
        $model= new PayOrderModel;
        $sign=$this->payUtil->createSign($this->payment_secretKey,$param);
        $param["sign"]=$sign;
        $url=$this->apiurl."api/v1/payment/order/create";
        $data=$this->payUtil->httpPost($url,$param);
        $record=array("order_id"=>md5("betcatpay".$param["merOrderNo"]),
               "mer_order_no"=>$param["merOrderNo"],
               "amount"=>$param["amount"],
               "order_type"=>0,
               "request_detail"=>json_encode($param),
               "response_detail"=>$data["body"],
               "channel_type"=>"betcatpay",
               "uid"=>$params["uid"],
               "notify_url"=>$params["returnUrl"],
               "product_id"=>$params["product_id"],
        );
        Log::info("payment create order params: ".json_encode($param)."\t orderInfo: ".$data["body"]);     
        $result=json_decode($data["body"],true); 
        if($result["code"] !=0){
           $record["order_status"]=-4;
           $record["msg"]=$result["error"];
            $model->addPayOrder($record);
           return json_encode(array("code"=>$result["code"],"msg"=>"fail","error"=>$result["error"]));
        }
        $record["pay_order_no"]=$result["data"]["orderNo"];
        $record["pay_url"]=$result["data"]["params"]["url"];
        $model->addPayOrder($record);
        return json_encode(array("code"=>200,"msg"=>"success","data"=>$result["data"]));
   }

   //查询代收订单
   public function queryPaymentOrder(){
       $this->getPayUtil();
       $param=request()->param();
       if(empty($param["merOrderNo"]) && empty($param["orderNo"])){
           $this->error("参数错误","/api/BetcatPay/queryPaymentOrder");
       }  
       $param["appId"]=$this->payment_appId;
       $sign=$this->payUtil->createSign($this->payment_secretKey,$param);
       $param["sign"]=$sign;
       $url=$this->apiurl."api/v1/payment/order/query";
       $data=$this->payUtil->httpGet($url,$param);
       Log::info("query payemt order info: ".$data["body"]);
       $result=json_decode($data["body"],true);
       if($result["code"]!=0){
          return json_encode(array("code"=>$result["code"],"msg"=>"fail","error"=>$result["error"]));
       }
       else{
          return json_encode(array("code"=>200,"msg"=>"success","data"=>$result["data"]));
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
          ||empty($params["extra"]["document"]
          ||empty($params["orderId"])
          )
        ){
           $this->error("参数错误 ".json_encode($params),"/api/BetcatPay/createPayoutOrder");
        }
        $param=array(
           "amount"=>$params["amount"],
           "merOrderNo"=>$params["orderId"],
           "currency"=>$params["currency"],
           "notifyUrl"=>$this->notifyUrl,
           "extra"=>$params["extra"],
           "appId"=>$this->payout_appId,
       );
       if(isset($params["remark"])){
          $this->param["attach"]=$params["remark"];
       }
       //if(empty($params["returnUrl"])){
       //   $params["returnUrl"]=$this->notifyUrl;
       // }
       $sign=$this->payUtil->createSign($this->payout_secretKey,$param);
       $param["sign"]=$sign;
       $url=$this->apiurl."api/v1/payout/order/create";
       $data=$this->payUtil->httpPost($url,$param);
       $result=json_decode($data["body"],true);
       Log::info($data);
       $model= new PayOrderModel;
       $record=array("order_id"=>md5("betcatpay".$param["merOrderNo"]),
               "mer_order_no"=>$param["merOrderNo"],
               "amount"=>$param["amount"],
               "order_type"=>1,
               "request_detail"=>json_encode($param),
               "response_detail"=>$data["body"],
               "channel_type"=>"betcatpay",
               "uid"=>$params["uid"],
               "notify_url"=>$params["returnUrl"],
        );

       if($result["code"]!=0){
           $record["order_status"]=-4;
           $record["msg"]=$result["error"];
           $model->addPayOrder($record);
          return json_encode(array("code"=>$result["code"],"msg"=>"fail","error"=>$result["error"]));
       }else{
        $result["order_status"]=$result["data"]["orderStatus"];
        $record["pay_order_no"]=$result["data"]["orderNo"];
   
        $model->addPayOrder($record);
          return json_encode(array("code"=>200,"msg"=>"success","data"=>$result["data"]));
       }
   }
         
   //查询代付订单
   public function queryPayoutOrder(){
       $this->getPayUtil();
       $param=request()->param();
       if(empty($param["merOrderNo"]) && empty($param["orderNo"])){
           $this->error("参数错误","/api/BetcatPay/queryPayoutOrder");
       }  
       $param["appId"]=$this->payout_appId;
       $sign=$this->payUtil->createSign($this->payout_secretKey,$param);
       $param["sign"]=$sign;
        
       $url=$this->apiurl."api/v1/payout/order/query";
       $data=$this->payUtil->httpGet($url,$param);
       Log::info("query payout order info: ".$data["body"]);
       $result=json_decode($data["body"],true);
       if($result["code"]!=0){
         return json_encode(array("code"=>$result["code"],"msg"=>"fail","error"=>$result["error"]));
       }
       else{
         return json_encode(array("code"=>200,"msg"=>"success","data"=>$result["data"]));
       }
   }

   //账户余额查询
   public function queryAccountBalance(){
        $this->getPayUtil();
        $appId=request()->param("appId");
        $secretKey=request()->param("secretKey");
        if(empty($appId)){
           $appId=$this->payment_appId;
           $secretKey=$this->payment_secretKey;
        }else{
           if(empty($secretKey)){
            return json_encode(array("code"=>400,"msg"=>"fail","error"=>"参数错误"));
           }
        }
        $params=array("appId"=>$appId);
        $sign=$this->payUtil->createSign($secretKey,$params);
        $params["sign"]=$sign;
        $url=$this->apiurl."api/v1/merchant/balance";
        $data=$this->payUtil->httpGet($url,$params);
        $result=json_decode($data["body"],true);
        Log::info("query balance info: ".$data["body"]);
        $result=json_decode($data["body"],true);
        if($result["code"]!=0){
          return json_encode(array("code"=>$result["code"],"msg"=>"fail","error"=>$result["error"]));
        }
        else{
          return json_encode(array("code"=>200,"msg"=>"success","data"=>$result["data"]));
        }
   }

   private  function getPayUtil(){
       if(empty($this->payUtil)){
          $this->payUtil= new betcatPayUtils;
      }
      return $this->payUtil;
   }
}
?>
