<?php


namespace app\admin\controller;

use app\admin\model\Admins;
use app\admin\model\WechatPlatform;
use app\admin\model\WechatService;
use think\Db;
use think\Paginator;
use app\Common;
use think\File;
/**
 *
 * 后台页面控制器.
 */
class Index extends Base
{

    /**
     * 后台首页.
     *
     * @return mixed
     */
    public function index()
    {
        $this->redirect('service/index/index');
    }

    /**
     * 后台对话页面.
     *
     * @return mixed
     */
    public function chats()
    {
        $login = $_SESSION['Msg'];
        $res = Admins::table('wolive_business')->where('id', $login['business_id'])->find();
        $this->assign("type", $res['video_state']);
        $this->assign('atype', $res['audio_state']);
        $this->assign("title", "客户咨询");
        $this->assign('part', '客户咨询');
        return $this->fetch();
    }


    /**
     * 常用语页面.
     *
     * @return mixed
     */
    public function custom()
    {
        $login = $_SESSION['Msg'];
        $data = Admins::table("wolive_sentence")->where('service_id', $login['service_id'])->paginate(9);
        $page = $data->render();
        $this->assign('page', $page);
        $this->assign('lister', $data);
        $this->assign('title', "问候语设置");
        $this->assign('part', "设置");

        return $this->fetch();
    }


    /**
     * 生成前台文件页面.
     *
     * @return mixed
     */
    public function front()
    {
        $http_type = ((isset($_SERVER['HTTPS']) && strtolower($_SERVER['HTTPS']) == 'on') || (isset($_SERVER['HTTP_X_FORWARDED_PROTO']) && $_SERVER['HTTP_X_FORWARDED_PROTO'] == 'https')) ? 'https://' : 'http://';

        $web = $http_type . $_SERVER['HTTP_HOST'];
        $action = $web.request()->root();

        $login = $_SESSION['Msg'];
        $class = Admins::table('wolive_group')->where('business_id', $login['business_id'])->select();

        $this->assign('class', $class);
        $this->assign('business', $login['business_id']);
        $this->assign('web', $web);
        $this->assign('login', $login);
        $this->assign('action', $action);
        $this->assign("title", "接入方法");
        $this->assign("part", "接入方法");
        return $this->fetch();
    }


    /**
     * 所有聊天记录页面。
     * [history description]
     * @return [type] [description]
     */
    public function history()
    {
        $visiter_id = $this->request->param('visiter_id');
        $this->assign('visiter_id',$visiter_id);
        return $this->fetch();
    }
  
    public function exportfilter($outhtml){
        $http_type = ((isset($_SERVER['HTTPS']) && $_SERVER['HTTPS'] == 'on') || (isset($_SERVER['HTTP_X_FORWARDED_PROTO']) && $_SERVER['HTTP_X_FORWARDED_PROTO'] == 'https')) ? 'https://' : 'http://';
        $weburl=  $http_type . $_SERVER['HTTP_HOST'];
   
        $outhtml=preg_replace("/&#xe6dc;/", "", $outhtml);
        $outhtml=preg_replace("/<div.+?>/", "", $outhtml);
        $outhtml=preg_replace("/<\/div>/", "", $outhtml);
        $outhtml=preg_replace("/<img src=\"(.+?)\".+?>/", "<img src=\"".$weburl."$1\">", $outhtml);
        $outhtml=preg_replace("/<i.+?>(.+?)<\/i>/", "$1", $outhtml);
        $outhtml=preg_replace("/<audio src=\"(.+?)\"><\/audio>/", "<a href=\"".$weburl."$1\" target=_blank>音频 </a>", $outhtml);
        return $outhtml;
    }
    
    /**
     * 后台导出聊天记录
     * [history description]
     * @return [type] [description]
     */
    public function export()
    {
        $visiter_id = $this->request->param('visiter_id');
        $hid = $this->request->param('hid');
        $savename=date("Y-m-d H:m:s",time())."访客".$visiter_id."保存的聊天记录".".html";
        header("Content-Type: application/force-download");
        header("Content-Disposition: attachment; filename=".basename($savename));
       
        $login = $_SESSION['Msg'];
        $visitername="";
      
        if ($hid == '') {
            $data = Admins::table('wolive_chats')->where('visiter_id', $visiter_id)->where('business_id', $login['business_id'])->order('timestamp asc,cid asc')->limit(10000)->select();
            $vdata = Admins::table('wolive_visiter')->where('visiter_id', $visiter_id)->where('business_id', $login['business_id'])->find();
            
            foreach ($data as $v) {
                
                if ($v['direction'] == 'to_service') {
                    $v['avatar'] = $vdata['avatar'];
                    $v['name'] = $vdata['visiter_name'];
                    $visitername=$vdata['visiter_name'];
                } else {
                    $sdata = Admins::table('wolive_service')->where('service_id', $v['service_id'])->find();
                    $v['avatar'] = $sdata['avatar'];
                    $v['name'] = $sdata['nick_name'];
                }
                $v['infotime'] =date("Y-m-d H:i:s",$v['timestamp']);
                $v['content'] =$this->exportfilter($v['content']);
                
            }
            reset($data);
        } else {
            
            $data = Admins::table('wolive_chats')->where('visiter_id', $visiter_id)->where('business_id', $login['business_id'])->where('cid', '<', $hid)->order('timestamp asc,cid asc')->limit(10000)->select();
            $vdata = Admins::table('wolive_visiter')->where('visiter_id', $visiter_id)->where('business_id', $login['business_id'])->find();
            
            foreach ($data as $v) {
                
                if ($v['direction'] == 'to_service') {
                    $v['avatar'] = $vdata['avatar'];
                    $v['name'] = $vdata['visiter_name'];
                    $visitername=$vdata['visiter_name'];
                } else {
                    $sdata = Admins::table('wolive_service')->where('service_id', $v['service_id'])->find();
                    $v['avatar'] = $sdata['avatar'];
                    $v['name'] = $sdata['nick_name'];
                    
                }
                $v['infotime'] =date("Y-m-d H:i:s",$v['timestamp']);
                $v['content'] =$this->exportfilter($v['content']);
            }
            reset($data);
        }
        $this->assign('visitername',$visitername);
        $this->assign('list',$data);
        $this->assign('visiter_id',$visiter_id);
        $this->assign('hid',$hid);
        return $this->fetch();

    }

    /**
     * 留言页面.
     *
     * @return mixed
     */
    public function message()
    {
        $login = $_SESSION['Msg'];
        $post = $this->request->get();
        $userAdmin = Admins::table('wolive_message');
        $pageParam = ['query' => []];
        unset($post['page']);
        if ($post) {
            $pushtime = $post['pushtime'];

            if ($pushtime) {
                if ($pushtime == 1) {
                    $timetoday = date("Y-m-d", time());
                    $userAdmin->where('timestamp', 'like', $timetoday . "%");
                    $this->assign('pushtime', $pushtime);
                    $pageParam['query']['timestamp'] = $pushtime;
                } elseif ($pushtime == 7) {
                    $timechou = strtotime("-1 week");
                    $times = date("Y-m-d", $timechou);
                    $userAdmin->where('timestamp', ">", $times);
                    $this->assign('pushtime', $pushtime);
                    $pageParam['query']['timestamp'] = $pushtime;
                }
            }
        }

        $data = $userAdmin->where('business_id', $login['business_id'])->paginate(8, false, $pageParam);
        $page = $data->render();
        $this->assign('page', $page);
        $this->assign('msgdata', $data);
        $this->assign('title', "留言查看");
        $this->assign('part', "留言查看");

        return $this->fetch();
    }

    /**
     * 转接客服页面
     * @return [type] [description]
     */
    public function service()
    {

        $get = $_GET;

        $visiter_id = $_GET['visiter_id'];

        $login = $_SESSION['Msg'];

        $business_id = $login['business_id'];

        $res = Admins::table('wolive_service')->where('business_id', "{$business_id}")->where('service_id', '<>', $login['service_id'])->select();

        $this->assign('service', $res);
        $this->assign('visiter_id', $visiter_id);
        $this->assign('name', $get['name']);

        return $this->fetch();
    }

    public function servicejson()
    {
        $get = $_GET;

        $visiter_id = $_GET['visiter_id'];

        $login = $_SESSION['Msg'];

        $business_id = $login['business_id'];

        $res = Admins::table('wolive_service')->where('business_id', "{$business_id}")->where('service_id', '<>', $login['service_id'])->select();

        return json(['code'=>0,'data'=>['visiter_id'=>$visiter_id,'name'=>$get['name'],'service'=>$res]]);
    }

    /**
     * 常见问题编辑页面
     * [editer description]
     * @return [type] [description]
     */
    public function editer()
    {
        $login = $_SESSION['Msg'];
        if ($login['level'] == 'service') {
            $this->redirect('admin/index/index');
        }

        $get = $this->request->get();

        $res = Admins::table('wolive_question')
            ->where('qid', $get['qid'])
            ->order('sort desc')
            ->find();

        $this->assign('question', $res['question']);
        $this->assign('keyword',$res['keyword']);
        $this->assign('answer', $res['answer']);
        $this->assign('qid', $get['qid']);
        $this->assign('sort', $res['sort']);
        $this->assign('status', $res['status']);

        return $this->fetch();
    }
    /**
     * 常见问题编辑页面
     * [editer description]
     * @return [type] [description]
     */
    public function custom_editer()
    {
        $login = $_SESSION['Msg'];
        if ($login['level'] == 'service') {
            $this->redirect('admin/index/index');
        }

        $get = $this->request->get();
        $id=isset($get['id'])?$get['id']:0;

        $res = Admins::table('wolive_question')
            ->where('id', $get['id'])
            ->order('sort desc')
            ->find();

        $this->assign('question', $res['question']);
        $this->assign('keyword',$res['keyword']);
        $this->assign('answer', $res['answer_read']);
        $this->assign('qid', $get['qid']);
        $this->assign('sort', $res['sort']);
        $this->assign('status', $res['status']);

        return $this->fetch();
    }


    /**
     * 编辑tab页面
     * [editertab description]
     * @return [type] [description]
     */
    public function editertab()
    {

        $login = $_SESSION['Msg'];
        if ($login['level'] == 'service') {
            $this->redirect('admin/index/index');
        }

        $get = $this->request->get();

        $res = Admins::table('wolive_tablist')->where('tid', $get['tid'])->find();

        $this->assign('title', $res['title']);
        $this->assign('content', $res['content_read']);
        $this->assign('tid', $get['tid']);

        return $this->fetch();
    }

    public function editercustom()
    {
        $login = $_SESSION['Msg'];
        $get = $this->request->get();
$content='';
        $sid=0;
        if($get['sid']>0){
            $res = Admins::table('wolive_sentence')
                ->where('sid', $get['sid'])
                ->where('service_id',$login['service_id'])
                ->find();
            $content=$res['content'];
            $sid=$res['sid'];
        }
        $this->assign('content', $content);
        $this->assign('sid', $sid);

        return $this->fetch();
    }

    /**
     * 设置页面
     * [set description]
     */
    public function set()
    {

        $this->assign('user', $_SESSION['Msg']);
        $this->assign('title', '系统设置');
        $this->assign('part', '系统设置');
        return $this->fetch();
    }


    public function setup()
    {

        $login = $_SESSION['Msg'];
        if ($login['level'] == 'service') {
            $this->redirect('admin/index/index');
        }
        $res = Admins::table("wolive_business")->where('id', $login['business_id'])->find();

        $this->assign('video', $res['video_state']);
        $this->assign('audio', $res['audio_state']);
        $this->assign('voice', $res['voice_state']);
        $this->assign('voice_addr', $res['voice_address']);
        $this->assign('template', $res['template_state']);
        $this->assign('method', $res['distribution_rule']);
        $this->assign('push_url',$res['push_url']);
        $this->assign('title', '通用设置');
        $this->assign('part', '设置');

        return $this->fetch();
    }

    /**
     * tab面版页面。
     * [tablist description]
     * @return [type] [description]
     */
    public function tablist()
    {


        if ($_SESSION['Msg']['level'] == 'service') {
            $this->redirect('admin/index/index');
        }

        $business_id = $_SESSION['Msg']['business_id'];

        $res = Admins::table('wolive_tablist')->where('business_id', $business_id)->select();

        $this->assign('tablist', $res);

        $this->assign('title', '编辑前端tab面版');
        $this->assign('part', '设置');

        return $this->fetch();
    }


    /**
     *
     * [replylist description]
     * @return [type] [description]
     */
    public function replylist()
    {

        $id = $_SESSION['Msg']['service_id'];
        $res = Admins::table('wolive_reply')->where('service_id', $id)->paginate(8);
        $page = $res->render();
        $this->assign('page', $page);
        $this->assign('replyword', $res);

        return $this->fetch();
    }

    public function template()
    {
        $common = new Common();
        if ($this->request->isPost()) {
            $post = $this->request->post();
            $post['business_id'] = $_SESSION['Msg']['business_id'];
            $post=$common->deep_array_map_trim($post);
            $res = WechatPlatform::edit($post);

            $arr = $res!== false ? ['code' => 0, 'msg' => '成功']: ['code' => 1, 'msg' => '失败'];
            return $arr;
        } else {
            $template = WechatPlatform::get(['business_id'=>$_SESSION['Msg']['business_id']]);

            $protocol=$common->isHTTPS()?'https://':'http://';
            $this->assign('template',$template);
            $this->assign('protocol',$protocol);
            $this->assign('title', '公众号与模板消息设置');
            $this->assign('part', "设置");
            return $this->fetch();
        }
    }

    public function qrcode()
    {
        $qrcode = WechatService::get()->qrcode;
//        fangke
        $result = $qrcode->temporary('kefu_'.$_SESSION['Msg']['service_id'], 6 * 24 * 3600);

        $ticket = $result->ticket;// 或者 $result['ticket']
        $url = $qrcode->url($ticket);
        return json(['code'=>0,'data'=>$url]);
    }

    public function test(){

    }
}