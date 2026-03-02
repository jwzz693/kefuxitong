<?php
/**
 * Created by PhpStorm.
 * User: 1609123282
 * Email: 2097984975@qq.com
 * Date: 2019/3/17
 * Time: 4:24 PM
 */
namespace app\backend\controller;

use app\backend\model\Cache;
use think\Db;
use app\Common;
use app\backend\model\Admins;

class Storage extends Base
{
    // 登录页面
    public function index()
    {
        $config = Db::name('wolive_storage')->where('id',1)->find();
        $config['config']=json_decode($config['config'],true);
        
        return $this->fetch('',['type'=>$config['type'],'config'=>$config['config']]);
    }

    public function save(){
        $type = input('type');
        $access_key = input('access_key');
        $secret_key = input('secret_key');
        $domain = input('domain');
        $bucket = input('bucket');

        if($type==1){
            $res = Db::name('wolive_storage')->where('id',1)->update(['type'=>$type]);
            if($res){
                exit(json_encode(['code'=>0,'msg'=>'修改成功']));
            }

        }else{
            $data =[];
            $data['access_key']=$access_key;
            $data['secret_key']=$secret_key;
            $data['domain']=$domain;
            $data['bucket']=$bucket;
            $res = Db::name('wolive_storage')->where('id',1)->update(['type'=>$type,'config'=>json_encode($data)]);
            if($res){
                exit(json_encode(['code'=>0,'msg'=>'修改成功']));
            }
        }
        exit(json_encode(['code'=>500,'msg'=>'修改失败']));
    }

}