# 酒店及酒店餐厅集成设计

## TuyuBooking 模型

hotel.property、room_type、room、room_block、rate_plan、rate_snapshot、inventory_hold、reservation、reservation_room、stay_occupant、folio、folio_entry、housekeeping_task、pos_outlet、pos_table、menu_item、pos_order、pos_order_item、kitchen_ticket、stock_ledger_entry。

## 集成规则

- Flutter 只调用 Rust 命令和查询接口。
- 酒店餐厅保留在 hotel Schema，因为客房挂账和住客 Folio 是其核心边界。
- 共用顾客只引用 tuyu_core.customer_ref；酒店保留预订时住客资料快照。
- Kamra 的 Frappe DocType 名称保存为迁移元数据，不直接限定新表结构。
- Python、Frappe 和 React 运行时不进入安装包。
