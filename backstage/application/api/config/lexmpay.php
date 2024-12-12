<?php

return [
    'version' => '1.0', // 版本号，如果需要同步返回JSON数据(必填)，如果直接跳转付款页面 不需要带这个参数
    'mch_id' => '', // 商户ID,
    'notify_url' => 'xxx/api/pay/lexmPay_notify', // 异步回调地址 付款成功后回调，不同服务器写不同地址
    'page_url' => '', //同步回调地址
    'collection_pay_type' => '002', // 支付商户通道编码
    'collection_key' => '', // 代收密钥
    'collection_bank_code' => 'ACB',
    'bank_code' => 'COPDS1507', // 网银通道必填，其他类型一定不能填该参数，固定哥伦比亚代付
    'payment_key' => '', // 代付密钥
    'payment_pay_type' => '1730', // 代付商户渠道编码
    'sign_type' => 'MD5', // 加密方式，固定值
    'lexmpay_getway' => 'https://payment.lexmpay.com/pay/web', // 提交支付网关
    'lexmpay_transfer' => 'https://payment.lexmpay.com/pay/transfer', // 提交代付网关
    'test_mch_id' => '', // 测试商户号 哥伦比亚
    'test_payment_key' => '', // 测试代付密钥 哥伦比亚
    'back_url'  => 'xxx/api/pay/lexmPayPayBehalf_notify' // 代付回调地址
];