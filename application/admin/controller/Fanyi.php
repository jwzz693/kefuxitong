<?php


namespace app\admin\controller;

use app\admin\model\Admins;
use app\admin\model\Chats;
use app\admin\model\CommentSetting;
use app\admin\model\Queue;
use app\admin\model\TplService;
use app\admin\model\Visiter;
use app\admin\model\WechatPlatform;
use app\common\lib\CurlUtils;
use app\common\lib\Lock;
use app\common\lib\Storage;
use app\common\lib\storage\StorageException;
use app\extra\push\Pusher;
use think\Db;
use think\Exception;
use think\Log;
use think\Controller;
use app\admin\iplocation\Ip;
/**
 *
 * 设置控制器.
 */
class Fanyi extends Controller
{
    public function isTrans($text,$to,$business_id){
        if($to == 'cn') return $text;
        if(strpos($text, '<img') !== false) return $text;
        if(strpos($text, '<a') !== false) return $text;
        if(strpos($text, '<video') !== false) return $text;
        if(strpos($text, '<p') !== false) return $text;
        $business = Db::table('wolive_business')->where(['id'=>$business_id])->field("auto_trans")->find();
        if($business['auto_trans']){
            $to = config('lang_trans')[$to];
            $from = 'auto';
            // 使用 MyMemory 免费翻译API
            $stream_opts = [
                "ssl" => [
                    "verify_peer"=>false,
                    "verify_peer_name"=>false,
                ],
                "http" => [
                    "timeout" => 10,
                ]
            ];
            $langpair = $from . '|' . $to;
            $query = http_build_query([
                "q" => $text,
                "langpair" => $langpair,
            ]);
            try{
                $res = file_get_contents("https://api.mymemory.translated.net/get?$query", false, stream_context_create($stream_opts));
                $res = json_decode($res, true);
                if(isset($res['responseData']['translatedText']) && $res['responseStatus'] == 200){
                    return $res['responseData']['translatedText'];
                }else{
                    return $text;
                }
            }catch (\Exception $e) {
                return $text;
            }
        }else{
            return $text;
        }
    }

}