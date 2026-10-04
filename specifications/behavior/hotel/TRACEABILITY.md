# 酒店及酒店餐厅源码追踪

| 能力 | 上游源码依据 | TuyuBooking 目标 | 状态 |
|---|---|---|---|
| 酒店与房型 | property、room_type、room DocType | hotel.property/room_type/room | designed |
| 房态与锁房 | reservation、room_block、sellable_unit | hotel.inventory_hold/reservation_room | designed |
| 房价 | rate_plan、season、hurdle_rate、rate_guardrail | hotel.rate_plan/rate_snapshot | designed |
| 预订与入住 | reservation、stay_occupant、group_booking | hotel.reservation/stay_occupant | designed |
| 账单 | folio、folio_charge、folio_payment、security_deposit | hotel.folio/folio_entry | designed |
| 房务 | housekeeping_task、service_ticket、lost_and_found_item | hotel.housekeeping_task/service_task | designed |
| 酒店餐厅 | pos_outlet、pos_order、pos_order_item、pos_table_reservation | hotel.pos 系列 | designed |
| 餐饮库存 | ingredient、ingredient_stock、stock_ledger_entry | hotel.menu_item/stock_ledger_entry | designed |
| 测试 | test_reservation.py、test_pos_order.py、test_folio.py | test/behavior 迁移场景 | identified |
