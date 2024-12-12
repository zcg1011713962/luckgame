var inputClass = '.gold-input';
if ($(inputClass).parent().find('.gold-tips').length === 0){
    $(inputClass).parent().append('<span class="gold-tips" style="color: red"></span>');
}
// 计算金额
function calcMoney(obj){
    let number = obj.val();
    let format = (number / 100).toFixed(2);
    obj.parent().find('.gold-tips').html('实际操作金额￥' + format);
}

// 小数公共方法
function showGold(score) {
	return (score / 100).toFixed(2);
}

var val = $(inputClass).val();
if (val > 0){
    calcMoney($(inputClass));
}

$(document).on('input' , inputClass , function (){
    calcMoney($(this));
})