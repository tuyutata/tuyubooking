# 旅行团活动集成设计

## TuyuBooking 模型

Voyant原生Drizzle模型直接运行在`tuyubooking.module_voyant`中。TuyuBooking不再定义平行的`tour.product`、`tour.booking`等业务模型；Rust只负责统一进程生命周期、途遇管理员断言、模块状态和跨模块平台事件。

## 集成规则

- 生产入口为固定Fork中的`templates/operator`，依赖Voyant products、availability、bookings、travel-composer、pricing、finance和transactions等原生包。
- Tuyu模式保留TypeScript/Node业务实现，并通过Nitro构建本地Node.js 24服务端产物。
- 迁移器强制数据库名为`tuyubooking`、Schema为`module_voyant`、角色为`tuyu_voyant_app`，禁止业务表进入`public`。
- Node只监听回环端口`58445`，局域网通过TLS代理的`58444`入口访问。
- 途遇管理员使用60秒一次性断言换取Better Auth技术管理员会话；员工仍使用Voyant原生账户。
- 跨模块数据不得直接联表，通过后续模块API、事件和`tuyu_core`只读索引衔接。
