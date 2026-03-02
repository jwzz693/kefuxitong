<?php


namespace app\service\controller;

use app\service\model\Msg;
use app\service\model\Phone;
use app\service\model\Vgroup;
use think\Db;

/**
 *
 * 后台页面控制器.
 */
class Vgroups extends Base
{

    public function index()
    {
        if ($this->request->isAjax()) return Vgroup::getList();
        return $this->fetch();
    }
    public function msglist()
    {

        if ($this->request->isAjax()) return Msg::getList();
        return $this->fetch();
    }
        public function phonelist()
    {
        if ($this->request->isAjax()) return Phone::getList();
        return $this->fetch();
    }
    public function removemsg()
    {
        $id = $this->request->get('id');
        if (Msg::destroy(['id' => $id])) $this->success('操作成功！');
        $this->error('操作失败！');
    }
        public function removemsgall()
    {
   
        $delete = Db::table('wolive_msg')->where(['services' => $_SESSION['Msg']['business_id']])->delete(true);
        $this->success('操作成功！');
    }
            public function removephoneall()
    {
   
        $delete = Db::table('phone_msg')->where(['services' => $_SESSION['Msg']['business_id']])->delete(true);
        $this->success('操作成功！');
    }
    /**
     * @return mixed
     * @throws \think\exception\DbException
     */
    public function edit()
    {
        if ($this->request->isAjax()) {
            $post = $this->request->post();
            if(mb_strlen($post['group_name'],'UTF8') > 20) $this->error('分组名不能多于12个字符');
            $group = Vgroup::where('group_name',$post['group_name'])->where('business_id',$_SESSION['Msg']['business_id'])->where('id','<>',$post['id'])->find();
            if ($group) $this->error('该组名称已存在');
            $res = Vgroup::where("id", $post['id'])->field(true)->update($post);
            if ($res) $this->success('修改成功');
            $this->error('修改失败！');
        }
        $id = $this->request->get('id');
        $group = Vgroup::get(['id' => $id]);
        $this->assign('group', $group);
        return $this->fetch();
    }

    /**
     * @return mixed
     * @throws \think\exception\DbException
     */
    public function add()
    {
        if ($this->request->isAjax()) {
            $post = $this->request->post();
            $post['business_id'] = $_SESSION['Msg']['business_id'];
            $post['service_id'] = $_SESSION['Msg']['service_id'];
            $post['create_time'] = date('Y-m-d H:i:s');
            if(mb_strlen($post['group_name'],'UTF8') > 20) $this->error('分组名不能多于12个字符');
            $group = Vgroup::get(['group_name'=>$post['group_name'],'business_id'=>$_SESSION['Msg']['business_id']]);
            if ($group) $this->error('该组名称已存在');
            $res = Vgroup::insert($post);
            if ($res) $this->success('添加成功');
            $this->error('添加失败！');
        }
        return $this->fetch();
    }

    public function remove()
    {
        $id = $this->request->get('id');
        $check = Db::name('wolive_queue')->where(['groupid'=>$id])->find();
        if($check) $this->error('该分组下有用户，不能删除');
        if (Vgroup::destroy(['id' => $id])) $this->success('操作成功！');
        $this->error('操作失败！');
    }
    
    
       public function removemsg_phone()
    {
        $id = $this->request->get('id');
        if (Phone::destroy(['id' => $id])) $this->success('操作成功！');
        $this->error('操作失败！');
    }
    /**
     * @return mixed
     * @throws \think\exception\DbException
     */
    public function edit_phone()
    {
        if ($this->request->isAjax()) {
            $post = $this->request->post();
            if(mb_strlen($post['group_name'],'UTF8') > 20) $this->error('分组名不能多于12个字符');
            $group = Vgroup::get(['group_name'=>$post['group_name']]);
            if ($group) $this->error('该组名称已存在');
            $res = Vgroup::where("id", $post['id'])->field(true)->update($post);
            if ($res) $this->success('修改成功');
            $this->error('修改失败！');
        }
        $id = $this->request->get('id');
        $group = Vgroup::get(['id' => $id]);
        $this->assign('group', $group);
        return $this->fetch();
    }

    /**
     * @return mixed
     * @throws \think\exception\DbException
     */
    public function add_phone()
    {
        if ($this->request->isAjax()) {
            $post = $this->request->post();
            $post['business_id'] = $_SESSION['Msg']['business_id'];
            $post['service_id'] = $_SESSION['Msg']['service_id'];
            $post['create_time'] = date('Y-m-d H:i:s');
            if(mb_strlen($post['group_name'],'UTF8') > 20) $this->error('分组名不能多于12个字符');
            $group = Vgroup::get(['group_name'=>$post['group_name']]);
            if ($group) $this->error('该组名称已存在');
            $res = Vgroup::insert($post);
            if ($res) $this->success('添加成功');
            $this->error('添加失败！');
        }
        return $this->fetch();
    }

    public function remove_phone()
    {
        $id = $this->request->get('id');
        $check = Db::name('phone_msg')->where(['groupid'=>$id])->find();
        if($check) $this->error('该分组下有用户，不能删除');
        if (Vgroup::destroy(['id' => $id])) $this->success('操作成功！');
        $this->error('操作失败！');
    }
}