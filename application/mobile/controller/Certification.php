<?php


namespace app\mobile\controller;

use app\mobile\model\Sentence;
use think\Db;
use app\mobile\model\User;

/**
 *
 * 后台页面控制器.
 */
class Certification extends Mbase
{
    public function index()
    {
        $login = $_SESSION['Msg'];
      
        $business = Db::table('wolive_business')->where(['id' => $login['business_id']])->find();
        if ($this->request->isAjax()) {
        if($business['is_shenhe'] == 1) $this->error("您已上传过信息,无法修改");
        $post = $this->request->post();
        if(empty($post['img[0]']))    $this->error("请先上传身份证正面");
        if(empty($post['img[1]']))    $this->error("请先上传身份证反面");
        if(empty($post['img[2]']))    $this->error("请先上传营业执照");
        if(empty($post['img[3]']))    $this->error("请先上传支付宝/微信收款码");
        if(empty($post['zfb']))    $this->error("请先填写支付宝/微信");
        if(empty($post['maill']))    $this->error("请先填写邮箱");
        if(empty($post['phone']))    $this->error("请先填写手机号");
        if(empty($post['name']))    $this->error("请先填写姓名");
        if(empty($post['age']))    $this->error("请先填写年龄");
        $xinpost = [
           'certificationleft' => $post['img[0]'],
           'certificationright' =>  $post['img[1]'],
           'businesslicence'=>  $post['img[2]'],
           'busszfbimg' =>  $post['img[3]'],
           'busszfb' => $post['zfb'],
           'bussmaill' => $post['maill'],
           'bussphone' => $post['phone'],
           'bussname' => $post['name'],
           'bussage' => $post['age'],
           'is_shenhe' => 1
           ];
         Db::table('wolive_business')->where(['id' => $login['business_id']])->update($xinpost);
             $this->success("保存成功");
        }
        
        $this->assign('business', $business);
         $this->assign('bussstatus', $business['is_shenhe']);
           $this->assign('shenhetime', $business['shenhetime']);
       
    //    var_dump($business);
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
    
    
   
}