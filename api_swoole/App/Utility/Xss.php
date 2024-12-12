<?php
namespace App\Utility;

class Xss
{
    function remove_invisible_characters($str, $url_encoded = true)
    {
        $non_displayables = [];
        if ($url_encoded) {
            $non_displayables[] = '/%0[0-8bcef]/';
            $non_displayables[] = '/%1[0-9a-f]/';
        }
        $non_displayables[] = '/[\\x00-\\x08\\x0B\\x0C\\x0E-\\x1F\\x7F]+/S';
        do {
            $str = preg_replace($non_displayables, '', $str, -1, $count);
        } while ($count);
        return $str;
    }
    
    function _convert_attribute($match)
    {
        return str_replace(array('>', '<', '\\'), array('>', '<', '\\\\'), $match[0]);
    }
    
    function _decode_entity($match)
    {
        $str = $match[0];
        if (stristr($str, '&') === false) {
            return $str;
        }
        $str = html_entity_decode($str, ENT_COMPAT, 'UTF-8');
        $str = preg_replace('~&#x(0*[0-9a-f]{2,5})~ei', 'chr(hexdec("\\1"))', $str);
        return preg_replace('~&#([0-9]{2,4})~e', 'chr(\\1)', $str);
    }
    
    function _compact_exploded_words($matches)
    {
        return preg_replace('/\s+/s', '', $matches[1]).$matches[2];
    }
    
    function _filter_attributes($str)
    {
        $out = '';
        if (preg_match_all('#\s*[a-z\-]+\s*=\s*(\042|\047)([^\\1]*?)\\1#is', $str, $matches)) {
            foreach ($matches[0] as $match) {
                $out .= preg_replace("#/\*.*?\*/#s", '', $match);
            }
        }
        return $out;
    }
    
    function _js_link_removal($match)
    {
        return str_replace(
            $match[1],
            preg_replace(
                '#href=.*?(alert\(|alert&\#40;|javascript\:|livescript\:|mocha\:|charset\=|window\.|document\.|\.cookie|<script|<xss|data\s*:)#si',
                '',
                $this->_filter_attributes(str_replace(array('<', '>'), '', $match[1]))
            ),
            $match[0]
        );
    }
    
    function _js_img_removal($match)
    {
        return str_replace(
            $match[1],
            preg_replace(
                '#src=.*?(alert\(|alert&\#40;|javascript\:|livescript\:|mocha\:|charset\=|window\.|document\.|\.cookie|<script|<xss|base64\s*,)#si',
                '',
                $this->_filter_attributes(str_replace(array('<', '>'), '', $match[1]))
            ),
            $match[0]
        );
    }
    
    function _sanitize_naughty_html($matches)
    {
        $str = '<'.$matches[1].$matches[2].$matches[3];
        $str .= str_replace(array('>', '<'), array('>', '<'),
            $matches[4]);
        return $str;
    }
    
    function xss_clean($str, $is_image = false)
    {
        if (is_array($str)) {
            while (list($key) = each($str)) {
                $str[$key] = $this->xss_clean($str[$key]);
            }
            return $str;
        }
        $str = $this->remove_invisible_characters($str);
        $hash = md5(time() + mt_rand(0, 1999999999));
        $str = preg_replace('|\&([a-z\_0-9\-]+)\=([a-z\_0-9\-]+)|i', $hash."\\1=\\2", $str);
        $str = preg_replace('#(&\#?[0-9a-z]{2,})([\x00-\x20])*;?#i', "\\1;\\2", $str);
        $str = preg_replace('#(&\#x?)([0-9A-F]+);?#i',"\\1\\2;",$str);
        $str = str_replace($hash, '&', $str);
        $str = rawurldecode($str);
        $str = preg_replace_callback("/[a-z]+=([\'\"]).*?\\1/si", array($this, '_convert_attribute'), $str);
        $str = preg_replace_callback("/<\w+.*?(?=>|<|$)/si", array($this, '_decode_entity'), $str);
        $str = $this->remove_invisible_characters($str);
        if (strpos($str, "\t") !== false) {
            $str = str_replace("\t", ' ', $str);
        }
        $converted_string = $str;
        $_never_allowed_str = array(
            'document.cookie'   => '[removed]',
            'document.write'    => '[removed]',
            '.parentNode'       => '[removed]',
            '.innerHTML'        => '[removed]',
            'window.location'   => '[removed]',
            '-moz-binding'      => '[removed]',
            '<!--'               => '<!--',
            '-->'                => '-->',
            '<![CDATA['          => '<![CDATA[',
            '<comment>'           => '<comment>'
        );
        $str = str_replace(array_keys($_never_allowed_str), $_never_allowed_str, $str);
        $_never_allowed_regex = array(
            'javascript\s*:',
            'expression\s*(\(|&\#40;)',
            'vbscript\s*:',
            'Redirect\s+302',
            "([\"'])?data\s*:[^\\1]*?base64[^\\1]*?,[^\\1]*?\\1?"
        );
        foreach ($_never_allowed_regex as $regex) {
            $str = preg_replace('#'.$regex.'#is', '[removed]', $str);
        }
        if ($is_image === true) {
            $str = preg_replace('/<\?(php)/i', "<?\\1", $str);
        } else {
            $str = str_replace(array('<?', '?'.'>'),  array('<?', '?>'), $str);
        }
        $words = array(
            'javascript', 'expression', 'vbscript', 'script', 'base64',
            'applet', 'alert', 'document', 'write', 'cookie', 'window'
        );
        foreach ($words as $word) {
            $temp = '';
            
            for ($i = 0, $wordlen = strlen($word); $i < $wordlen; $i++) {
                $temp .= substr($word, $i, 1)."\s*";
            }
            
            $str = preg_replace_callback('#('.substr($temp, 0, -3).')(\W)#is', array($this, '_compact_exploded_words'), $str);
        }
        do {
            $original = $str;
            if (preg_match("/<a/i", $str)) {
                $str = preg_replace_callback("#<a\s+([^>]*?)(>|$)#si", array($this, '_js_link_removal'), $str);
            }
            if (preg_match("/<img/i", $str)) {
                $str = preg_replace_callback("#<img\s+([^>]*?)(\s?/?>|$)#si", array($this, '_js_img_removal'), $str);
            }
            if (preg_match("/script/i", $str) OR preg_match("/xss/i", $str)) {
                $str = preg_replace("#<(/*)(script|xss)(.*?)\>#si", '[removed]', $str);
            }
        } while ($original != $str);
        unset($original);
        $evil_attributes = array('on\w*', 'style', 'xmlns', 'formaction');
        if ($is_image === true) {
            unset($evil_attributes[array_search('xmlns', $evil_attributes)]);
        }
        do {
            $count = 0;
            $attribs = [];
            preg_match_all('/('.implode('|', $evil_attributes).')\s*=\s*(\042|\047)([^\\2]*?)(\\2)/is', $str, $matches, PREG_SET_ORDER);
            foreach ($matches as $attr) {
                $attribs[] = preg_quote($attr[0], '/');
            }
            preg_match_all('/('.implode('|', $evil_attributes).')\s*=\s*([^\s>]*)/is', $str, $matches, PREG_SET_ORDER);
            foreach ($matches as $attr) {
                $attribs[] = preg_quote($attr[0], '/');
            }
            if (count($attribs) > 0) {
                $str = preg_replace('/(<?)(\/?[^><]+?)([^A-Za-z<>\-])(.*?)('.implode('|', $attribs).')(.*?)([\s><]?)([><]*)/i', '$1$2 $4$6$7$8', $str, -1, $count);
            }
        } while ($count);
        $naughty = 'alert|applet|audio|basefont|base|behavior|bgsound|blink|body|embed|expression|form|frameset|frame|head|html|ilayer|iframe|input|isindex|layer|link|meta|object|plaintext|style|script|textarea|title|video|xml|xss';
        $str = preg_replace_callback('#<(/*\s*)('.$naughty.')([^><]*)([><]*)#is', array($this, '_sanitize_naughty_html'), $str);
        $str = preg_replace('#(alert|cmd|passthru|eval|exec|expression|system|fopen|fsockopen|file|file_get_contents|readfile|unlink)(\s*)\((.*?)\)#si', "\\1\\2(\\3)", $str);
        $str = str_replace(array_keys($_never_allowed_str), $_never_allowed_str, $str);
        foreach ($_never_allowed_regex as $regex) {
            $str = preg_replace('#'.$regex.'#is', '[removed]', $str);
        }
        if ($is_image === true) {
            return ($str == $converted_string) ? true: false;
        }
        return $str;
    }
}