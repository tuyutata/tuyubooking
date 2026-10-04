# 票务集成设计

## 数据与运行模型

Hi.Events原生Laravel模型直接运行在tuyubooking.module_hi_events中。PHP 8.4、Nginx、Composer vendor、Node和React SSR产物全部预构建进入同一个TuyuBooking安装包。

## 集成规则

- 唯一数据库为tuyubooking，运行角色为tuyu_hi_events_app。
- 队列、缓存和会话使用PostgreSQL，不启动Redis、MySQL、SQLite或第二数据库。
- macOS/Linux使用PHP-FPM，Windows使用PHP-CGI，Nginx提供回环FastCGI网关。
- 票务局域网入口为HTTPS 58446，内部端口58447、58448和58449不对外暴露。
- 途遇管理员通过60秒一次性断言换取本地技术SUPERADMIN JWT，每个技术请求重新检查tuyu_core会话映射。
- 商家员工继续使用Hi.Events原生账户、角色和权限。
- Hi.Events额外署名条款继续保留在许可证、适用界面和输出中。
