<?php

namespace app\service2\controller;

use app\service\model\MarqueeAd as MarqueeAdModel;
use think\Db;

/**
 * 流动广告管理控制器
 */
class MarqueeAd extends Base
{
    /**
     * 流动广告列表页面
     */
    public function index()
    {
        if ($this->request->isAjax()) {
            $login = $_SESSION['Msg'];
            $list = MarqueeAdModel::where('business_id', $login['business_id'])
                ->order('sort desc, id desc')
                ->select();
            return json(['code' => 0, 'data' => $list]);
        }
        return $this->fetch();
    }

    /**
     * 添加流动广告
     */
    public function add()
    {
        $login = $_SESSION['Msg'];
        $post = $this->request->post();
        if (empty($post['content'])) {
            return json(['code' => 1, 'msg' => '广告内容不能为空']);
        }
        $data = [
            'business_id' => $login['business_id'],
            'content' => trim($post['content']),
            'link_url' => isset($post['link_url']) ? trim($post['link_url']) : '',
            'bg_color' => isset($post['bg_color']) ? trim($post['bg_color']) : 'linear-gradient(90deg, #667eea 0%, #764ba2 100%)',
            'text_color' => isset($post['text_color']) ? trim($post['text_color']) : '#ffffff',
            'speed' => isset($post['speed']) ? intval($post['speed']) : 30,
            'duration' => isset($post['duration']) ? intval($post['duration']) : 30,
            'sort' => isset($post['sort']) ? intval($post['sort']) : 0,
            'status' => isset($post['status']) ? intval($post['status']) : 1,
            'is_global' => isset($post['is_global']) ? intval($post['is_global']) : 0,
            'rotate_interval' => isset($post['rotate_interval']) ? intval($post['rotate_interval']) : 10,
        ];
        $res = MarqueeAdModel::create($data);
        if ($res) {
            return json(['code' => 0, 'msg' => '添加成功', 'data' => $res]);
        }
        return json(['code' => 1, 'msg' => '添加失败']);
    }

    /**
     * 编辑流动广告
     */
    public function edit()
    {
        $login = $_SESSION['Msg'];
        $post = $this->request->post();
        if (empty($post['id'])) {
            return json(['code' => 1, 'msg' => '参数错误']);
        }
        $item = MarqueeAdModel::get(['id' => $post['id'], 'business_id' => $login['business_id']]);
        if (!$item) {
            return json(['code' => 1, 'msg' => '记录不存在']);
        }
        $data = [];
        if (isset($post['content'])) $data['content'] = trim($post['content']);
        if (isset($post['link_url'])) $data['link_url'] = trim($post['link_url']);
        if (isset($post['bg_color'])) $data['bg_color'] = trim($post['bg_color']);
        if (isset($post['text_color'])) $data['text_color'] = trim($post['text_color']);
        if (isset($post['speed'])) $data['speed'] = intval($post['speed']);
        if (isset($post['duration'])) $data['duration'] = intval($post['duration']);
        if (isset($post['sort'])) $data['sort'] = intval($post['sort']);
        if (isset($post['status'])) $data['status'] = intval($post['status']);
        if (isset($post['is_global'])) $data['is_global'] = intval($post['is_global']);
        if (isset($post['rotate_interval'])) $data['rotate_interval'] = intval($post['rotate_interval']);
        $res = $item->save($data);
        if ($res !== false) {
            return json(['code' => 0, 'msg' => '修改成功']);
        }
        return json(['code' => 1, 'msg' => '修改失败']);
    }

    /**
     * 删除流动广告
     */
    public function remove()
    {
        $login = $_SESSION['Msg'];
        $id = $this->request->post('id');
        $item = MarqueeAdModel::get(['id' => $id, 'business_id' => $login['business_id']]);
        if (!$item) {
            return json(['code' => 1, 'msg' => '记录不存在']);
        }
        if ($item->delete()) {
            return json(['code' => 0, 'msg' => '删除成功']);
        }
        return json(['code' => 1, 'msg' => '删除失败']);
    }

    /**
     * 获取启用的流动广告列表（用于推送选择）
     */
    public function getActive()
    {
        $login = $_SESSION['Msg'];
        $list = MarqueeAdModel::where('business_id', $login['business_id'])
            ->where('status', 1)
            ->order('sort desc, id desc')
            ->select();
        return json(['code' => 0, 'data' => $list]);
    }
}
