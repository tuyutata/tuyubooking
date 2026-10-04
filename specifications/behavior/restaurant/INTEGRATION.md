# 独立餐厅集成设计

## TuyuBooking 模型

restaurant.outlet、area、table、menu、menu_item、modifier、shift、order_session、order、order_item、kitchen_ticket、kitchen_ticket_item、stock_ledger_entry、daily_close。

## 集成规则

- URY 的餐厅、房间、桌台、菜单、订单和 KOT DocType 迁移为 Rust 聚合。
- ERPNext 的通用 Company、Item 和 Invoice 不作为运行时依赖。
- 必要会计语义由订单、日结和审计模型承载，不复制整套 ERP。
- Python、TypeScript、Frappe 和 ERPNext 运行时不进入安装包。
