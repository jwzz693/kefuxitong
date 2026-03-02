<?php

namespace app\service\model;

use think\Model;

class PaymentMethod extends Model
{
    protected $table = 'wolive_payment_method';
    protected $autoWriteTimestamp = false;
}
