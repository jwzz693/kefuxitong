<?php
/**
 * Created by PhpStorm.
 * User: Andy
 * Date: 2020/4/10
 * Time: 11:21
 */
namespace app\service\model;

use think\Model;

class Msg extends Model
{
    protected $table = 'wolive_msg';
    protected $autoWriteTimestamp = false;

    public static function getList()
    {
        $where = ['services' => $_SESSION['Msg']['business_id']];
        $limit = input('get.limit');
        
        if ($grouptruename = input('get.truename')) $where['truename'] = $grouptruename;
        if ($contact = input('get.contact')) $where['contact'] = $contact;
        if ($contact = input('get.contact')) $where['contact'] = $contact;
        $list = self::order('id', 'asc')->where($where)->paginate($limit)->each(function ($item) {

        });
        return ['code' => 0, 'data' => $list->items(), 'count' => $list->total(), 'limit' => $limit];
    }

    public function setCreateTimeAttr()
    {
        return date('Y-m-d H:i:s');
    }

    public function getCreateTimeAttr()
    {
        return date('Y-m-d H:i:s');
    }
}