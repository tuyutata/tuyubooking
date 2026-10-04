# 旅行团活动源码追踪

| 能力 | 上游源码依据 | TuyuBooking运行目标 | 状态 |
|---|---|---|---|
| 产品 | packages/products/src/schema-core.ts | Voyant原生模型，module_voyant | integrated |
| 团期与资源政策 | catalog-policy-departures.ts | Voyant原生模型，module_voyant | integrated |
| 名额 | packages/availability/src/schema.ts | Voyant原生模型，module_voyant | integrated |
| 预订 | bookings/schema-core.ts、schema-items.ts | Voyant原生模型，module_voyant | integrated |
| 状态操作 | bookings/schema-operations.ts | Voyant原生服务和审计 | integrated |
| 行程 | travel-composer/src/schema.ts | Voyant原生模型，module_voyant | integrated |
| 价格财务 | pricing、finance/src/schema.ts | Voyant原生模型，module_voyant | integrated |
| 本地服务端 | templates/operator、TanStack Start、Hono | Node.js 24/Nitro，回环58445 | integrated |
| 管理员桥接 | Better Auth、tuyu-admin bridge | 一次性断言与tuyu_core审计 | integrated |
| PostgreSQL迁移 | templates/operator/migrations | 54项迁移、323张module_voyant表 | verified |
