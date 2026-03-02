<?php


namespace app\backend\controller;

use app\backend\model\Business;
use think\Db;
use app\Common;
use think\Cookie;
use think\Loader;

/**
 *
 * 后台页面控制器.
 */
class Busines extends Base
{

    public function index()
    {
        if ($this->request->isAjax()) {
            return Business::getList();
        }
        return $this->fetch();
    }

    public function add()
    {
        if ($this->request->isAjax()) {
            $post = $this->request->post();
            $post['expire_time'] = strtotime($post['expire_time']);
            $validate = Loader::validate('App');
            if(!$validate->scene('insert')->check($post)) $this->error($validate->getError());
            $business = Business::get(['business_name' => $post['business_name']]);
            if ($business) $this->error('商户名称已存在');
            if(Business::addBusiness($post)) $this->success('操作成功！');
            $this->error('操作失败！');
        }
        return $this->fetch();
    }
	public function backlogin()
    {
		$id = $this->request->get('id');
	    $common = new Common();
        $expire = 7 * 24 * 60 * 60;
		$business = Business::where(['id' => $id])->find();
		//var_dump('<pre>',$business);die;
        $service_token = $common->cpEncode($business['business_name'], AIKF_SALT, $expire);
        Cookie::set('service_token', $service_token, $expire);
		$ismoblie = $common->isMobile();
        if ($ismoblie) {
            $this->success('登录成功', url("mobile/admin/index"));
        } else {
            $this->success('登录成功', url("service/Index/home"));
        }
    }
    public function edit()
    {
        if ($this->request->isAjax()) {
            $post = $this->request->post();
            if(Business::editBusiness($post)) $this->success('操作成功！');
            $this->error('修改失败！');
        }
        $id = $this->request->get('id');
        $business = Business::where(['id' => $id])->find();
        $this->assign('business', $business);
        return $this->fetch();
    }
    public function see()
    {
        
        $id = $this->request->get('id');
        $business = Business::where(['id' => $id])->find();
        $this->assign('business', $business);
        return $this->fetch();
    }
    public function is_delete()
    {
        $post = $this->request->post();
        $result = Business::where('id', $post['id'])->update(['is_delete' => $post['is_delete']]);
        if ($result) $this->success('操作成功！');
        $this->error('操作失败！');
    }
    public function is_qiangzhi()
    {
        $post = $this->request->post();
        $result = Business::where('id', $post['id'])->update(['is_qiangzhi' => $post['is_qiangzhi']]);
        if ($result) $this->success('操作成功！');
        $this->error('操作失败！');
    }
    public function shenhe()
    {
      
        $post = $this->request->post();
        $business = Business::where(['id' => $post['id']])->find();
       
        $result = Business::where('id', $post['id'])->update(['is_shenhe' => 2,'shenhetime' => date("Y/m/d")]);
        if ($result) $this->success('操作成功！');
        $this->error('操作失败！');
    }
        public function bushenhe()
    {
      
        $post = $this->request->post();
        $business = Business::where(['id' => $post['id']])->find();
      
        $result = Business::where('id', $post['id'])->update(['is_shenhe' => 0]);
        if ($result) $this->success('操作成功！');
        $this->error('操作失败！');
    }
    public function remove()
    {
        $id = $this->request->get('id');
        if (Business::destroy(['id' => $id])) {
            Db::name('wolive_service')->where('business_id', $id)->delete();
            Db::name('wolive_question')->where('business_id', $id)->delete();
            Db::name('wolive_robot')->where('business_id', $id)->delete();
            Db::name('wolive_group')->where('business_id', $id)->delete();
            Db::name('wolive_visiter')->where('business_id', $id)->delete();
            Db::name('wolive_visiter_vgroup')->where('business_id', $id)->delete();
            Db::name('wolive_vgroup')->where('business_id', $id)->delete();
            Db::name('wolive_queue')->where('business_id', $id)->delete();
            Db::name('wolive_option')->where('business_id', $id)->delete();
            $this->success('操作成功！');
        }
        $this->error('操作失败！');
    }

    public function clear()
    {
        $id = $this->request->get('id');
        if (Db::name('wolive_chats')->where('business_id', $id)->delete()) {
            $this->success('操作成功！');
        }
        $this->error('操作失败！');
    }
}