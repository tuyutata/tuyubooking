# 独立餐厅源码追踪

| 能力 | 上游源码依据 | TuyuBooking 目标 | 状态 |
|---|---|---|---|
| 门店与区域 | ury_restaurant、ury_room | restaurant.outlet/area | designed |
| 桌台 | ury_table、ury_ordering_session | restaurant.table/order_session | designed |
| 菜单 | ury_menu、ury_menu_item、item_add_on | restaurant.menu/menu_item/modifier | designed |
| 点餐 | ury_order、ury_order_item | restaurant.order/order_item | designed |
| 后厨 | ury_kot、ury_kot_items、ury_kot_error_log | restaurant.kitchen_ticket 系列 | designed |
| 营业终端 | ury_payment_terminal、sub_pos_closing | restaurant.shift/daily_close | designed |
| 报表 | ury_daily_p_and_l、ury_cost_of_goods | 领域查询模型 | designed |
| 权限 | ury_user、role_permitted | tuyu_core.staff_role_assignment | designed |
