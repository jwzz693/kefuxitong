<?php


namespace app\service\controller;

use app\service\model\Sentence;
use app\service\model\WechatPlatform;
use think\Db;
use app\service\model\Service;

/**
 *
 * 后台页面控制器.
 */
class Settingnow extends Base
{
    
    public function del(){
          $login = $_SESSION['Msg'];
             $imgurl = $_POST['img'];
                         $b = 0;
                         for ($i=0; $i<=5; $i++)
            {
            $b = $b + 1;
     /*       if($post['img['.$i."]"] != null){
        
             $xinpost =   $xinpost+['img'.$b=>$post['img['.$i."]"]];
            }*/
         //   echo $login['business_id'];
           $x =    Db::table('wolive_business')->where(['img'.$b =>  $_POST['img'],'id' => $login['business_id']])->select();
     
            if(!empty($x)){
    
                    $xinpost =array();
                     $xinpost =   $xinpost+['img'.$b=>null];
             Db::table('wolive_business')->where(['id' => $login['business_id']])->update($xinpost);   
              $this->success("保存成功");
           }
            }
          
    }
    public function index()
    {
        $login = $_SESSION['Msg'];
        $template = WechatPlatform::get(['business_id' => $login['business_id']]);
        if ($this->request->isAjax()) {
          
            $post = $this->request->post();
         //   var_dump($post);
           /* if(empty($post['aboutus'])){
                $this->error('添加失败/缺少关于我们参数！');
              }
               if(empty($post['image[0]'])){
                           $post['image[0]'] = null;
              }
               if(empty($post['image[1]'])){
                         $post['image[1]'] = null;
              }
                if(empty($post['image[2]'])){
                  $post['image[2]'] = null;
              }
              if(empty($post['image[3]'])){
              $post['image[3]'] = null;
              }
              if(empty($post['image[4]'])){
              $post['image[4]'] = null;
              }
              if(empty($post['image[5]'])){
              $post['image[5]'] = null;
              }*/
            /*$update = ['aboutus' => $post['aboutus'],'img1' => $post['image[0]'],'img2' => $post['image[1]'],'img3' => $post['image[2]'],'img4' => $post['image[3]']];*/
            //var_dump($post);
       /*     $img = $_POST['img'];*/
          /* $i=array();
            $num = 0;
            foreach ( $post as $post_now){
                $num++;
               var_dump($post_now['img['.$i."]"]);
            }
            var_dump($i);*/
            $xinpost=array();
            $b = 0;
            for ($i=0; $i<=5; $i++)
            {
            $b = $b + 1;
            if($post['img['.$i."]"] != null){
        
             $xinpost =   $xinpost+['img'.$b=>$post['img['.$i."]"]];
            }
            }
            for ($i=2; $i<=6; $i++)
            {
             $xinpost =   $xinpost+['imgurl'.$i=>$post['imgurl'.$i.""]];
            }
              $xinpost =   $xinpost+['aboutus'=>$post["aboutus"]];
         //   var_dump($xinpost);
             Db::table('wolive_business')->where(['id' => $login['business_id']])->update($xinpost);
         
            $this->success("保存成功");
        }
        $business = Db::table('wolive_business')->where(['id' => $login['business_id']])->find();
        $this->assign('business', $business);
        $this->assign('template', $template);
        $this->assign('login', $login);
        return $this->fetch();
    }

    public function sentence()
    {
        if ($this->request->isAjax()) return Sentence::getList();
        return $this->fetch();
    }
    
    /*
    上传
    */
    
    public function upload()
    {
    //异步上传，post提交过来的image是字符串
    
    //接收post传来的base64
    $base64Str = $_POST['img'];
    //post的数据里面，加号会被替换为空格，需要重新替换回来，如果不是post的数据，则注释掉这一行
    $base64Image = str_replace(' ', '+', $base64Str);
    //匹配出图片的格式
    if (preg_match('/^(data:\s*image\/(\w+);base64,)/', $base64Image, $result)){
    	//获取后缀
        $type = $result[2];
        //设置保存路径
        $filePath = "./upload/images/";
        if(!file_exists($filePath)){
            mkdir($filePath, 0755);
        }
        //设置文件名
        $fileName = uniqid() . rand(0000,9999);
        //设置图片路径
        $newFile = $filePath.$fileName.".{$type}";
        //存放图片
        if (file_put_contents($newFile, base64_decode(str_replace($result[1], '', $base64Image)))){
                //返回文件路径
            die("/upload/images/".$fileName.".{$type}");
        }else{
            die("error");
        }
    }else{
        die("error");
    }
    }
    /**
     * description:
     * date: 2021/9/29 12:20
     * @return mixed
     * @throws \think\exception\DbException
     */
    public function sentence_add()
    {
        if ($this->request->isAjax()) {
            $post = $this->request->post();
            $check = Sentence::get(['service_id' => $_SESSION['Msg']['service_id'], 'lang' => $post['lang']]);
            if ($check) $this->error('该语言已存在问候语！');
            $post['service_id'] = $_SESSION['Msg']['service_id'];
            $post['content'] = $this->request->post('content', '', '\app\Common::clearXSS');
            $res = Sentence::insert($post);
            if ($res) $this->success('添加成功');
            $this->error('添加失败！');
        }
        return $this->fetch();
    }

    /**
     * description:
     * date: 2021/9/29 12:12
     * @return mixed
     * @throws \think\exception\DbException
     */
    public function sentence_edit()
    {
        if ($this->request->isAjax()) {
            $post = $this->request->post();
            $post['content'] = $this->request->post('content', '', '\app\Common::clearXSS');
            $res = Sentence::where("sid", $post['id'])->where('service_id', $_SESSION['Msg']['service_id'])->field(true)->update($post);
            if ($res) $this->success('修改成功');
            $this->error('修改失败！');
        }
        $id = $this->request->get('id');
        $robot = Sentence::get(['sid' => $id]);
        $this->assign('sentence', $robot);
        return $this->fetch();
    }

    public function sentence_remove()
    {
        $id = $this->request->get('id');
        if (Sentence::destroy(['sid' => $id])) $this->success('操作成功！');
        $this->error('操作失败！');
    }

    public function access()
    {
        $http_type = ((isset($_SERVER['HTTPS']) && strtolower($_SERVER['HTTPS']) == 'on') || (isset($_SERVER['HTTP_X_FORWARDED_PROTO']) && $_SERVER['HTTP_X_FORWARDED_PROTO'] == 'https')) ? 'https://' : 'http://';
        $web = $http_type . $_SERVER['HTTP_HOST'];
        $action = $web . request()->root();
        $login = $_SESSION['Msg'];
        $class = Db::table('wolive_group')->where('business_id', $login['business_id'])->select();
        $business = Db::table('wolive_business')->where('id', $login['business_id'])->find();
        $this->assign('class', $class);
        $this->assign('business', $login['business_id']);
        $this->assign('web', $web);
        $this->assign('login', $login);
        $this->assign('business', $business);
        $this->assign('action', $action);
        $this->assign("title", "接入方法");
        $this->assign("part", "接入方法");
        return $this->fetch();
    }

    public function course()
    {
        $this->assign("service", Service::getService());
        $this->assign("domain", $this->request->domain());
        $this->assign("business_id", $_SESSION['Msg']['business_id']);
        return $this->fetch();
    }
}