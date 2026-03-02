<?php
/**
 * 云端更新功能已禁用（安全审计）
 */

namespace app\platform\controller;

class Update extends Base
{
    protected $noNeedLogin = [];

    public function index()
    {
        return ['code' => 1, 'msg' => '云端更新功能已禁用'];
    }

    public function update()
    {
        return ['code' => 1, 'msg' => '云端更新功能已禁用'];
    }

    public function autoUpgrade()
    {
        return ['code' => 1, 'msg' => '云端更新功能已禁用'];
    }

    public function checkVersion()
    {
        return ['code' => 1, 'msg' => '云端更新功能已禁用'];
    }

    public function restartService()
    {
        return ['code' => 1, 'msg' => '云端更新功能已禁用'];
    }

    public function upgradeLog()
    {
        return ['code' => 1, 'msg' => '云端更新功能已禁用'];
    }
}