<?php

return [
    'merchant_key' => '+', // 商户merchant_key
    'aes_key' => '', // 商户 aes_key
    'aes_iv' => '', // 商户 aes_iv
    'nustpay_getway' => 'https://pay.nutspay.net/gateway/payment/init', // 代收提交网关
    'pay_notifyurl' => 'https://yidaliadmin.youmegame.cn/api/pay/nutspay_notify', // 代收成功后回调地址
    'nutspay_behalf_getway' => 'https://pay.nutspay.net/gateway/payout/init', // 代付提交网关
    'pay_behalf_notifyurl' => 'https://yidaliadmin.youmegame.cn/api/pay/nutspay_behalf_notify' // 代付回调
];