# URY 独立餐厅本地化规则

## 原则

- URY fork 是门店、区域、桌台、菜单、点餐、后厨和日结功能基线。
- 复用 URY 已有 i18n 结构和英文键，不改变订单、KOT、桌台或营业终端逻辑。
- 中文及其他系统语言默认简体中文，英文系统显示英文。
- upstream/ury 保持只读，中文进入 TuyuBooking Flutter 本地化资源和适配层。

## 核心术语

| 上游术语 | 简体中文 |
|---|---|
| Restaurant | 门店 |
| Room / Area | 就餐区域 |
| Table | 桌台 |
| Menu | 菜单 |
| Menu Item | 菜品 |
| Add-on / Modifier | 加料与规格 |
| Ordering Session | 点餐会话 |
| Order | 订单 |
| KOT | 厨房单 |
| Payment Terminal | 收银终端 |
| POS Closing | 营业日结 |
