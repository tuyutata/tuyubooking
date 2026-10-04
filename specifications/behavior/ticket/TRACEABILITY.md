# 票务源码追踪

| 能力 | 上游源码依据 | TuyuBooking运行目标 | 状态 |
|---|---|---|---|
| 活动 | Event.php | Hi.Events原生模型，module_hi_events | integrated |
| 票种价格 | Product.php、ProductPrice.php | Hi.Events原生模型，module_hi_events | integrated |
| 容量 | CapacityAssignment.php | Hi.Events原生服务与PostgreSQL锁 | integrated |
| 订单参与者 | Order.php、OrderItem.php、Attendee.php | Hi.Events原生模型 | integrated |
| 验票 | CheckInList.php、AttendeeCheckIn.php | Hi.Events原生服务 | integrated |
| 优惠候补 | PromoCode.php、WaitlistEntry.php | Hi.Events原生服务 | integrated |
| 退款审计 | OrderRefund.php、OrderAuditLog.php | Hi.Events原生服务 | integrated |
| 本地运行时 | Laravel、React SSR | PHP 8.4、Nginx、Node，HTTPS 58446 | integrated |
| 管理员桥接 | JWTAuth、tuyu_core | 一次性断言与逐请求审计 | integrated |
| PostgreSQL基线 | schema.sql | 31张module_hi_events表，public为0 | verified |
