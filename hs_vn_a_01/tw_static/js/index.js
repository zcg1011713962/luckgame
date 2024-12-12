function getURLParameter(name) {
	return decodeURIComponent((new RegExp('[?|&]' + name + '=' + '([^&;]+?)(&|#|;|$)').exec(location.search) || [, ""])[1].replace(/\+/g, '%20')) || null; //构造一个含有目标参数的正则表达式对象
}

function setBody(){
	var html = document.getElementsByTagName("html")[0];
	var body = document.getElementsByTagName("body")[0];
	html.style.width ='100%';
	html.style.height ='100%';
	body.style.width ='100%';
	body.style.height ='100%';
}

function joinroom() { 
	var tmpurl = window.location.href;
	var ar = tmpurl.split("?");
	var param = ar[1];
	var urlHeader = ""
	var url = urlHeader + "?" + param + '';
	openAppByIframe(url);
}

var is_weixin = function () {
    var ua = navigator.userAgent.toLowerCase();
    if (ua.match(/MicroMessenger/i) == "micromessenger") {
        return true;
    } else {
        return false;
    }
}

function is_huawei(){
    var u = navigator.userAgent;
    var isHuawei = u.match(/huawei/i) == "huawei";
    var isHonor = u.match(/honor/i) == "honor";
    return isHuawei || isHonor;
}

function is_android(){
    var u = navigator.userAgent;
    var isAndroid = u.indexOf('Android') > -1 || u.indexOf('Adr') > -1;    
    return isAndroid;
}
function is_ios(){
    var u = navigator.userAgent;
    var isiOS = !!u.match(/\(i[^;]+;( U;)? CPU.+Mac OS X/); 
    return isiOS;
}
function ios_ver(){
    var str= navigator.userAgent.toLowerCase();
    var vnum=str.match(/os\s+(\d+)/i)[1]-0;
    return vnum;
}

function openApp(url) {
	openAppByIframe(url);
}

function openHtml(url) {
	window.location.href = url;
}

function openAppByIframe(url) {
	if(is_ios()){
		setTimeout(function() {
			openHtml(url);
		}, 500);
	} else {
		if(navigator.userAgent.toLowerCase().indexOf("chrome") == -1){
	        var iframe = document.createElement("iframe");
			iframe.style.display = "none";
			iframe.src = decodeURI(url);
			document.body.appendChild(iframe);
			setTimeout(function() {
				document.body.removeChild(iframe);
			}, 500);
		} else {
			setTimeout(function() {
				window.open(url,'_blank');
			}, 500);
		}

    }
}		




