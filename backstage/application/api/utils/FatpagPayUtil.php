<?php
namespace app\api\utils;

class FatpagPayUtil{
  //代付
  private $PAYOUT_URL="http://api.fatpag.org/apitrans";
 
  //支付
  private $PAYIN_URL = "http://api.fatpag.org/apipay";
  //支付查询 
  public  $PAYIN_QUERY_URL="http://check.fatpag.org/qpayorder";
  //代付查询
  public $PAYOUT_QUERY_URL="http://check.fatpag.org/qtransorder";
  //账户余额查询
  public $ACCOUNT_BALANCE_URL="http://check.fatpag.org/qaccount";
  private $sign_key="";

  public function setSignKey($key){
     $this->sign_key=$key;
  }

  public function getSignKey(){
       return $this->sign_key;
   }
  /***
  * params:
       mchId       商户号:     必需
       orderNo     订单号:     长度[6,22]
       amount        金额:     单位元小数点后两位
       product     产品号:     支付产品: 巴西: baxipix
       bankcode  银行代号:     小写，没有明确说明 all
       goods     物品说明:     扩展字段说明
       notifyUrl 异步通知:     支持http和https post
       returnUrl 同步通知：    支持http和https post
       sign          签名：    md5 ksort 后strtoupper 大小
  *
  */
  public function APIPay($params){
    $fields=array("mchId"=>0,"orderNo"=>1,
      "amount"=>2,
      "product"=>0,
      "bankcode"=>0,
      "goods"=>0,
      "notifyUrl"=>"",
      "returnUrl"=>"",  
     );
     foreach($fields as $key=>$val){
        if(!isset($params[$key])){
         return array("code"=>401,"msg"=>"$key is null");
        }
        $fields[$key]=$params[$key];
     }
     $orderNoLen=strlen($fields["orderNo"]);
     if($orderNoLen<6 || $orderNoLen>22){
        return array("code"=>401,"msg"=>"orderNo length must [6,22], current: $orderNoLen ");
     }  
     $fields["amount"]=sprintf("%.02f",$fields["amount"]);
     $sign=$this->PaySign($fields);
     $fields["sign"]=$sign;
     $ret=$this->post_form($this->PAYIN_URL,$fields); 
     return $ret;
  } 

  public function APIPayNotify($params){
      $ret_sign=$params["sign"];
      unset($params["sign"]);
      $sign=$this->PaySign($params);
      $flag=true;
      if($sign == $ret_sgin){
        $flag=true;
      }else{
        $flag=false;
      }
      return $flag;
  }

  //代付
  /**
   type 转账类型 固定字符 api
   mchId 商户ID  
   mchTransNo 转账订单号
   amount  转账金额
   notifyUrl 通知地址
   accountName 账户名
   accountNo 账户号
   bankCode  银行号
   remarkInfo 备注
   sign 签名
  */
  public function APITrans($params){
      $fields=array("mchId"=>"",
         "mchTransNo"=>"",
         "amount"=>"",
         "notifyUrl"=>"",
         "accountName"=>"",
         "accountNo"=>"",
         "bankCode"=>"",
         "remarkInfo"=>"",
         "type"=>'',
         );
     foreach($fields as $key=>$val){
        if(!isset($params[$key])){
         return array("code"=>401,"msg"=>"$key is null");
        }
        $fields[$key]=$params[$key];
     }
     $orderNoLen=strlen($fields["mchTransNo"]);
     if($orderNoLen<6 || $orderNoLen>22){
        return array("code"=>401,"msg"=>"orderNo length must [6,22], current: $orderNoLen ");
     }  
     $fields["amount"]=sprintf("%.02f",$fields["amount"]);
     $sign=$this->PaySign($fields);
     $fields["sign"]=$sign;
     $ret=$this->post_form($this->PAYOUT_URL,$fields); 
     return $ret;
         
  }

  
  
  public function post_form($url,$params){
     //初始init 
     $ch = curl_init(); 
      //指定URL
     curl_setopt($ch,CURLOPT_URL,$url);
     //设置请求方回结果
     curl_setopt($ch,CURLOPT_RETURNTRANSFER,1);
     //请求方式
     curl_setopt($ch,CURLOPT_CUSTOMREQUEST,'POST');
     curl_setopt($ch,CURLOPT_POSTFIELDS,http_build_query($params));
     //curl_setopt($ch,CURLOPT_POSTFIELDS,$post_data);
     curl_setopt($ch,CURLOPT_SSL_VERIFYPEER,false);
     curl_setopt($ch,CURLOPT_SSL_VERIFYHOST, false);
     //curl_setopt($ch,CURLOPT_HEADER,false);
     curl_setopt($ch,CURLOPT_HTTPHEADER, array(
      "content-type: application/x-www-form-urlencoded",
      ));
     curl_setopt($ch,CURLOPT_TIMEOUT,30);
     $response = curl_exec($ch);
     $header=array(
                                'CURL_ERROR'=>curl_error($ch),
                                'HTTP_CODE'=>curl_getinfo($ch,CURLINFO_HTTP_CODE),
                                'LAST_URL'=>curl_getinfo($ch,CURLINFO_EFFECTIVE_URL),
                                'CONTENT_TYPE'=>curl_getinfo($ch,CURLINFO_CONTENT_TYPE),
                             );
     
     curl_close($ch);
     return array("header"=>$header,"body"=>$response); 
  }

  public function PaySign($params){
      ksort($params);
      $sign_text="";
      foreach($params as $k=>$v){
          $sign_text.="$k=$v&";
      }
      $sign_text.="key=".$this->sign_key;
     
      $sign=strtoupper(md5($sign_text));
      return $sign; 
  } 
  

  public  function validateSign($signSource,$retsign){
	  $signSource=$signSource."&key=".$this->sign_key;
	  $signkey=strtoupper(md5($signSource));
	  if($signkey == $retsign){
		  return true;
	  }else{
		  return false;
	  }
  }

}

?>
