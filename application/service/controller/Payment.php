<?php

namespace app\service\controller;

use app\service\model\PaymentMethod;
use think\Db;

/**
 * 支付方式管理控制器
 */
class Payment extends Base
{
    /**
     * 支付方式列表页面
     */
    public function index()
    {
        if ($this->request->isAjax()) {
            $login = $_SESSION['Msg'];
            $list = PaymentMethod::where('business_id', $login['business_id'])
                ->order('sort desc, id desc')
                ->select();
            return json(['code' => 0, 'data' => $list]);
        }
        return $this->fetch();
    }

    /**
     * 添加支付方式
     */
    public function add()
    {
        $login = $_SESSION['Msg'];
        $post = $this->request->post();
        if (empty($post['method_name'])) {
            return json(['code' => 1, 'msg' => '支付方式名称不能为空']);
        }
        $data = [
            'business_id' => $login['business_id'],
            'method_name' => trim($post['method_name']),
            'account_info' => isset($post['account_info']) ? trim($post['account_info']) : '',
            'qrcode_url' => isset($post['qrcode_url']) ? trim($post['qrcode_url']) : '',
            'payment_link' => isset($post['payment_link']) ? trim($post['payment_link']) : '',
            'sort' => isset($post['sort']) ? intval($post['sort']) : 0,
            'status' => isset($post['status']) ? intval($post['status']) : 1,
        ];
        $res = PaymentMethod::create($data);
        if ($res) {
            return json(['code' => 0, 'msg' => '添加成功', 'data' => $res]);
        }
        return json(['code' => 1, 'msg' => '添加失败']);
    }

    /**
     * 编辑支付方式
     */
    public function edit()
    {
        $login = $_SESSION['Msg'];
        $post = $this->request->post();
        if (empty($post['id'])) {
            return json(['code' => 1, 'msg' => '参数错误']);
        }
        $item = PaymentMethod::get(['id' => $post['id'], 'business_id' => $login['business_id']]);
        if (!$item) {
            return json(['code' => 1, 'msg' => '记录不存在']);
        }
        $data = [];
        if (isset($post['method_name'])) $data['method_name'] = trim($post['method_name']);
        if (isset($post['account_info'])) $data['account_info'] = trim($post['account_info']);
        if (isset($post['qrcode_url'])) $data['qrcode_url'] = trim($post['qrcode_url']);
        if (isset($post['payment_link'])) $data['payment_link'] = trim($post['payment_link']);
        if (isset($post['sort'])) $data['sort'] = intval($post['sort']);
        if (isset($post['status'])) $data['status'] = intval($post['status']);
        $res = $item->save($data);
        if ($res !== false) {
            return json(['code' => 0, 'msg' => '修改成功']);
        }
        return json(['code' => 1, 'msg' => '修改失败']);
    }

    /**
     * 删除支付方式
     */
    public function remove()
    {
        $login = $_SESSION['Msg'];
        $id = $this->request->post('id');
        $item = PaymentMethod::get(['id' => $id, 'business_id' => $login['business_id']]);
        if (!$item) {
            return json(['code' => 1, 'msg' => '记录不存在']);
        }
        if ($item->delete()) {
            return json(['code' => 0, 'msg' => '删除成功']);
        }
        return json(['code' => 1, 'msg' => '删除失败']);
    }

    /**
     * 上传收款码图片
     */
    public function uploadQrcode()
    {
        $file = $this->request->file('file');
        if ($file) {
            $newpath = ROOT_PATH . "/public/upload/images/{$_SESSION['Msg']['business_id']}/payment/";
            $info = $file->validate(['ext' => 'jpg,png,gif,jpeg'])->move($newpath, time());
            if ($info) {
                $imgname = $info->getFilename();
                $imgpath = "/upload/images/{$_SESSION['Msg']['business_id']}/payment/" . $imgname;
                return json(['code' => 1, 'msg' => '上传成功', 'data' => $imgpath]);
            }
        }
        return json(['code' => 0, 'msg' => '上传失败']);
    }

    /**
     * 获取启用的支付方式列表（用于推送选择）
     */
    public function getActive()
    {
        $login = $_SESSION['Msg'];
        $list = PaymentMethod::where('business_id', $login['business_id'])
            ->where('status', 1)
            ->order('sort desc, id desc')
            ->select();
        return json(['code' => 0, 'data' => $list]);
    }
}
