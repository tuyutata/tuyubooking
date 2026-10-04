# Kamra 酒店及酒店餐厅本地化规则

## 原则

- Kamra fork 是酒店、房态、房价、预订、客账、房务和酒店餐厅功能基线。
- 中文只改变显示文本，不改变 DocType 语义、状态机、校验、金额或库存计算。
- 英文系统保留上游英文，中文及其他系统语言默认简体中文。
- upstream/kamra 保持只读，中文进入 TuyuBooking Flutter 本地化资源和适配层。

## 核心术语

| 上游术语 | 简体中文 |
|---|---|
| Property | 酒店 |
| Room Type | 房型 |
| Room | 客房 |
| Room Block | 锁房 |
| Rate Plan | 房价方案 |
| Reservation | 预订 |
| Stay Occupant | 入住人 |
| Folio | 客账 |
| Housekeeping | 房务 |
| Point of Sale | 酒店餐厅收银 |
| Kitchen Ticket | 厨房单 |
| Stock Ledger | 库存流水 |
