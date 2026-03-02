<?php

namespace app\weixin\controller;

use app\extra\push\Pusher;
use app\weixin\model\Admins;

class Chat extends Base
{
    
  public function index()
  {

      return $this->fetch();
  }

  public function talk()
  {   
      
  	  $login =$_SESSION['Msg'];
      $get =$this->request->get();
      $channel=htmlspecialchars($get['channel']);
      $avatar =htmlspecialchars($get['avatar']);
      $data =Admins::table('wolive_visiter')->where("channel",$channel)->find();
      
      $business =Admins::table('wolive_business')->where('id',$login['business_id'])->find();
      
      $this->assign("atype",$business['audio_state']);
      $this->assign("data",$data);
      $this->assign("avatar",$avatar);
      $this->assign('se',$login);
      $this->assign("img",$login['avatar']);
      return $this->fetch();
  }

    public function checkchats(){
        $cids=[];
        $login = $_SESSION['Msg'];
        $service_id =$login['service_id'];
        $post = $this->request->post();
        $data =Admins::table('wolive_chats')->where(['service_id'=>$service_id,'visiter_id'=>$post['visiter_id'],'business_id'=>$login['business_id']])->order('timestamp desc')->select();
        foreach ($data as $v) {
            if($v['direction'] == 'to_service'){
                if(!$v['is_read']){
                    Admins::table('wolive_chats')->where('cid', $v['cid'])->update(['is_read' => 1]);
                    $cids[]=$v['cid'];
                }
            }
        }
        if(!empty($cids)){
            if (!ahost) {
                $http_type = ((isset($_SERVER['HTTPS']) && $_SERVER['HTTPS'] == 'on') || (isset($_SERVER['HTTP_X_FORWARDED_PROTO']) && $_SERVER['HTTP_X_FORWARDED_PROTO'] == 'https')) ? 'https://' : 'http://';

                $domain = $http_type . $_SERVER['HTTP_HOST'];
            } else {
                $domain = ahost;
            }

            $sarr = parse_url($domain);


            if ($sarr['scheme'] == 'https') {
                $state = true;
            } else {
                $state = false;
            }

            $app_key = app_key;
            $app_secret = app_secret;
            $app_id = app_id;
            $options = array(
                'encrypted' => $state
            );
            $host = $domain;
            $port = aport;

            $pusher = new Pusher(
                $app_key,
                $app_secret,
                $app_id,
                $options,
                $host,
                $port
            );
            $channel = bin2hex($post['visiter_id'] . '/' . $login['business_id']);
            $pusher->trigger("cu" . $channel, 'check-event', array('message' => $cids));
        }
        reset($data);
        $data =['code'=>0,];
        return $data;
    }
  public function chatdata(){
      $cids=[];
     $login = $_SESSION['Msg'];
     $service_id =$login['service_id'];
     $post = $this->request->post();
        
     

        if($post["hid"] == ''){
            
         $data =Admins::table('wolive_chats')->where(['service_id'=>$service_id,'visiter_id'=>$post['visiter_id'],'business_id'=>$login['business_id']])->order('timestamp desc')->limit(10)->select();

         $vdata =Admins::table('wolive_visiter')->where('visiter_id',$post['visiter_id'])->where('business_id',$login['business_id'])->find();

         $sdata =Admins::table('wolive_service')->where('service_id',$service_id)->find();

             foreach ($data as $v) {

                if($v['direction'] == 'to_service'){
                     $v['avatar'] =$vdata['avatar'];
                    if(!$v['is_read']){
                        Admins::table('wolive_chats')->where('cid', $v['cid'])->update(['is_read' => 1]);
                        $cids[]=$v['cid'];
                    }
                }else{
                    
                     $v['avatar'] =$sdata['avatar'];
                }
               
            }

            reset($data);
         
    
        }else{

          
            $data =Admins::table('wolive_chats')->where(['service_id'=>$service_id,'visiter_id'=>$post['visiter_id'],'business_id'=>$login['business_id']])->where('cid','<',$post['hid'])->order('timestamp desc')->limit(10)->select();

            $vdata =Admins::table('wolive_visiter')->where('visiter_id',$post['visiter_id'])->where('business_id',$login['business_id'])->find();

            $sdata =Admins::table('wolive_service')->where('service_id',$service_id)->find();


              foreach ($data as $v) {

                if($v['direction'] == 'to_service'){
                     $v['avatar'] =$vdata['avatar'];
                    if(!$v['is_read']){
                        Admins::table('wolive_chats')->where('cid', $v['cid'])->update(['is_read' => 1]);
                        $cids[]=$v['cid'];
                    }
                }else{
                     $v['avatar'] =$sdata['avatar'];
                }
               
            }

            reset($data);
     
        }
      if(!empty($cids)){
          if (!ahost) {
              $http_type = ((isset($_SERVER['HTTPS']) && $_SERVER['HTTPS'] == 'on') || (isset($_SERVER['HTTP_X_FORWARDED_PROTO']) && $_SERVER['HTTP_X_FORWARDED_PROTO'] == 'https')) ? 'https://' : 'http://';

              $domain = $http_type . $_SERVER['HTTP_HOST'];
          } else {
              $domain = ahost;
          }

          $sarr = parse_url($domain);


          if ($sarr['scheme'] == 'https') {
              $state = true;
          } else {
              $state = false;
          }

          $app_key = app_key;
          $app_secret = app_secret;
          $app_id = app_id;
          $options = array(
              'encrypted' => $state
          );
          $host = $domain;
          $port = aport;

          $pusher = new Pusher(
              $app_key,
              $app_secret,
              $app_id,
              $options,
              $host,
              $port
          );
          $channel = bin2hex($post['visiter_id'] . '/' . $login['business_id']);
          $pusher->trigger("cu" . $channel, 'check-event', array('message' => $cids));
      }
        $result = array_reverse($data);

        $data =['code'=>0,'data'=>$result];
        return $data;

  }

}
