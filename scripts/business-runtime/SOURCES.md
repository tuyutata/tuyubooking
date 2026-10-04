# TuyuBooking macOS离线业务运行件方案

## 1. 边界

本方案定义`runtime/business/macos`离线业务运行包的可信来源、固定版本、构建输入、校验和、许可证和晋级条件。依赖下载和源码构建只允许发生在现有控制台的隔离构建阶段；商家安装和运行阶段禁止联网安装。`build_frappe_assets.sh`在构建阶段生成浏览器资源并清除包管理器依赖和版本控制元数据。

商家电脑不得依赖Homebrew、系统Python、系统Node、系统PHP、系统Nginx、Docker或Podman。安装包必须携带所有运行文件，并由TuyuBooking主进程统一启动和停止。

## 2. 固定基础运行时

| 组件 | 固定版本 | 官方来源 | 来源验证 | 许可证 |
| --- | --- | --- | --- | --- |
| Python | 3.14.3 | `https://www.python.org/ftp/python/3.14.3/Python-3.14.3.tgz` | SHA-256必须与`runtime.lock.json`一致 | PSF License Version 2及内含第三方许可证 |
| Node.js | 25.2.1 | `runtime.lock.json`中的官方Node归档 | 实际下载和组装均读取产品锁中的来源、SHA-256及解压根 | MIT及Node发行包内第三方许可证 |
| Yarn | 1.22.22 | `runtime.lock.json`中的官方npm归档 | 只作本任务资源构建工具，验真后执行，不封入运行包 | BSD-2-Clause |
| PHP | 8.4.24 | `https://www.php.net/distributions/php-8.4.24.tar.xz` | SHA-256必须匹配PHP官方发布页 | PHP License 3.01及内含第三方许可证 |
| Nginx | 1.30.4 stable | `https://nginx.org/download/nginx-1.30.4.tar.gz` | 必须先验证官方PGP签名，再在可信构建机计算并锁定SHA-256 | Nginx BSD-2-Clause-style许可证 |

Python在可信构建机从官方源码构建为可搬移目录，不直接复制系统安装。PHP必须从官方源码构建CLI和PHP-FPM，并启用Hi.Events经`composer check-platform-reqs`确认的全部扩展。Nginx必须包含本地FastCGI网关所需模块。Node.js使用固定的macOS运行件。

## 3. 上游构建输入

- Frappe、ERPNext、HRMS、Kamra、URY只使用`runtime.lock.json`固定提交，Python依赖解析结果必须转成带哈希的离线wheelhouse；运行包内不得执行`pip install`联网解析。
- Frappe浏览器资源由`build_frappe_assets.sh`从冻结Yarn锁文件生成。`air-datepicker`固定为同一上游提交`ed37b94d95c68d8544357e330be0c89d044a3eea`的GitHub HTTPS源码归档，避免安装包外的Git仓库上下文依赖。
- Kamra和URY只共享不可变的Frappe源码与浏览器资源。酒店站点、餐厅站点、配置、日志、进程、员工账户和业务数据保持独立。
- Voyant只使用固定提交`ea7f1b1f858650ebcf3e66ae215d82d1ff09424f`和仓库`pnpm-lock.yaml`，必须执行冻结锁文件构建，输出operator服务入口、迁移入口和迁移journal。
- Hi.Events只使用固定提交`048243e2a99a65c8e77fc6f3cb44de158169855e`。后端必须使用`composer.lock`执行无开发依赖、优化autoload构建；前端必须使用`yarn.lock`冻结安装并生成React SSR入口。
- 所有生成物必须在构建完成后断网执行迁移预检、模块导入、版本检查和启动冒烟测试。

## 4. 唯一目录结构

```text
runtime/business/macos/
├── python/bin/python3
├── bench/
│   ├── apps/
│   └── sites/assets/assets.json
├── node/bin/node
├── voyant/operator/.output/server/index.mjs
├── voyant/operator/.output/migration/migrate.mjs
├── voyant/operator/.output/migrations/meta/_journal.json
├── php/bin/php
├── php/sbin/php-fpm
├── nginx/sbin/nginx
├── hi_events/backend/vendor/autoload.php
├── hi_events/frontend/dist/server/entry.server.js
├── licenses/
├── sbom.spdx.json
└── bundle.manifest.json
```

`scripts/business-runtime/materialize.sh`只接受上述根目录，不接受分散的`runtime/python`、`runtime/node`或系统路径。

## 5. 完整性和许可证

`bundle.manifest.json`必须记录每个文件的相对路径、SHA-256、大小、来源组件和可执行标记。控制台还必须为最终离线包生成一个总SHA-256，并在签名后才允许进入macOS安装包。

`licenses`必须包含Python、Node.js、PHP、Nginx以及所有Python、Composer、npm、pnpm、yarn依赖的原始许可证和第三方声明。`sbom.spdx.json`必须覆盖运行时、原生动态库和上游依赖，不允许只记录四个顶层运行时。

## 6. 晋级门禁

离线包只有同时满足以下条件才能交给第11步联调：

1. 所有来源版本和来源哈希满足`macos.sources.plan.json`。
2. 所有Mach-O可执行文件均为ARM64，且不得动态链接到Homebrew或构建机临时目录。
3. Python 3.14.3、PHP 8.4.24和Nginx 1.30.4保持既有输入；Node需与构建时读取的中央版本逐字匹配。
4. Frappe所需Python模块、Hi.Events PHP扩展和全部上游生产入口存在。
5. 断网状态下完成模块导入、数据库迁移预检和进程启动冒烟测试。
6. SBOM、许可证、逐文件SHA-256和离线包签名全部存在。
7. 运行配置只允许本机HTTPS入口和本机PostgreSQL，不引入Redis、MySQL、SQLite、Docker或Podman。
8. Frappe `assets.json`及登录、Desk、ERPNext、HRMS资源存在，且`bench/apps`不包含`.git`或`node_modules`。

任一条件不满足时，TuyuBooking构建器必须拒绝生成安装包，不得回退到系统运行时或在线安装。

## 2026-08-26 macOS 已验证来源策略

- Kamra、URY、Voyant、Hi.Events 均从仓库中固定的 fork 源码构建，TuyuBooking 不重新实现其业务功能。
- 第三方语言运行时和依赖只允许在编译、CI、Release 阶段按锁定版本获取；商家启动和运行阶段的网络安装被禁止。
- Node/Yarn输入已改为中央工具引用，当前尚未重新编译、组装或启动产品验证；之前运行结果不能证明新工具运行包通过。runtime.lock中的四项运行验收标记已设为false。
- Release 产物包含哈希清单和重定位后的本机依赖，严格校验拒绝 Homebrew、构建临时目录及其他非系统绝对 Mach-O 路径。
- 对上游源码的当前改动仅限运行兼容：Frappe PostgreSQL Unix Socket 优先级，以及 Hi.Events 生产 SSR 对 Vite 的动态开发期加载；未修改上游核心业务逻辑。

## 2026-08-27 构建与物化补充合同

- Voyant Nitro CLI 必须通过 `nitro.config.ts` 将主服务直接输出到绝对的 `TUYU_VOYANT_OUTPUT_DIR`；构建入口在开始和结束时清理导入源码侧 `.output`。
- 业务运行时进入 App 时统一使用 `rsync -a --delete` 复制目录内容，复制后再次验证 Frappe `assets.json`、Voyant Node 入口、Hi.Events 服务端入口、许可证、SBOM 和文件清单。
- macOS CocoaPods 与全部嵌入原生运行时统一使用 26.0 部署目标。
- 完整 macOS Release 已通过静态包验证和真实签名 App 冷启动、HTTPS、重启、数据库持久化烟雾测试。

## 2026-08-27 局域网 HTTPS 员工入口合同

- 四个上游业务服务只监听回环地址；员工设备不得直接访问模块内部端口或 PostgreSQL。
- 管理员登录后可显式启用唯一的 `58460` 局域网 HTTPS 网关，默认状态为停用。
- 网关固定提供 `/hotel`、`/restaurant`、`/tour`、`/ticket` 四条路径，并支持 HTTPS、WSS、重定向和 Cookie Path 转换。
- 网关 TLS 服务密钥只属于当前安装实例，与 sr25519 管理员身份无关；员工设备通过 mDNS 自动发现主机并在首次无凭据连接后固定证书，不使用连接二维码。
- 员工登录继续由 Kamra、URY、Voyant 和 Hi.Events 各自原有账户体系负责，本步骤不复制或统一员工账户。

## 2026-08-27 mDNS 自动发现补充

- TuyuBooking 桌面主机通过 `_tuyubooking._tcp.local` 广播安装实例 ID、商家名称、HTTPS 端口和协议版本。
- iOS、iPadOS 与 Android 员工模式自动发现同一局域网主机，不使用连接二维码。
- 移动端首次连接保存 TLS 证书 DER 的 SHA-256 指纹，后续证书变化立即拒绝连接。
- 移动端不启动 PostgreSQL、Rust FFI 或 Kamra、URY、Voyant、Hi.Events 本机运行时。
- 本步骤只提供发现、信任和模块入口，不改变或复制四个上游系统的员工账户。

## 2026-08-27 员工认证适配补充

- Kamra 与 URY 分别保留各自 Frappe Cookie 会话，不合并站点或员工身份。
- Voyant 使用 Better Auth 邮箱密码 Cookie 会话，Hi.Events 使用原生 JWT 会话。
- 员工密码不持久化，Cookie 和 JWT 只存在于员工 App 当前进程的模块会话中。
- 所有认证请求通过主机统一局域网 HTTPS 网关及证书固定校验，不直接访问上游内部端口。
- 四个上游源码的账户、岗位和权限逻辑保持不变。

## 2026-08-27 URY 餐厅员工前端补充

- TuyuBooking Flutter 餐厅前端调用 URY 现有 `getPosProfile`、`getRestaurantMenu`、`getMenuCourses`、Frappe Resource/List 和 `sync_order` 接口。
- 堂食与外带订单最终均由 URY `POS Invoice` 持久化，TuyuBooking 不建立第二套订单数据库。
- 规格和加料来自 URY Item 自定义字段并使用实时菜单价格，不在 Flutter 中维护重复商品配置。
- 写请求使用当前 Frappe Cookie 会话及 `frappe.sessions.get_csrf_token` 返回的 CSRF 令牌，不关闭上游安全校验。
- 本步骤未修改 URY 上游源码、数据表、角色权限和订单规则。

## 2026-08-27 URY 订单与收银补充

- 占用桌台通过 URY `get_order_invoice` 加载原 POS Invoice，更新继续使用 `sync_order` 的订单编号和修改时间并发保护。
- 订单中心使用 URY `getPosInvoice` 与 `getPosInvoiceItems`，不建立 TuyuBooking 订单副本。
- 支付方式读取 POS Profile 原生 `payments` 子表，拆分支付按 URY `make_invoice` 的 `mode_of_payment` 与 `amount` 结构提交。
- 收银前必须通过 ERPNext `check_opening_entry`，TuyuBooking 不绕过 POS Opening、清单、日结或员工角色门禁。
- 本步骤只接通上游已配置支付方式，不实现或声明任何外部支付渠道。

## 2026-08-27 Kamra 酒店员工前台接入

- TuyuBooking Flutter 酒店前台调用 Kamra 已有 `my_properties`、`front_desk_snapshot`、`availability_calendar`、`booking_options`、`guest_search`、`reservation_detail`、`create_booking`、`check_in`、`check_out` 与 `set_housekeeping_status` 合同。
- Kamra 继续拥有物业、客房、库存、价格、住客、预订和权限数据；TuyuBooking 不分叉或重写这些业务规则。
- 本步骤只增加 TuyuBooking 自有员工界面和薄适配层，不修改 `upstream/kamra` 中的上游功能逻辑。

## 2026-08-27 Voyant 旅行团活动员工端接入

- TuyuBooking Flutter 旅行团运营页使用 Voyant 原生 `/v1/admin/products`、`/v1/availability/slots`、`/v1/admin/bookings`、`/v1/bookings/:id/items` 和 `/v1/bookings/:id/travelers` 合同。
- 预订确认与取消继续调用 `/v1/admin/bookings/:id/confirm` 和 `/v1/admin/bookings/:id/cancel`；`HTTP 202` 保留为 Voyant 等待审批状态。
- Voyant 继续拥有产品、团期、人数、预订、旅客、租户和权限数据；TuyuBooking 不建立业务副本或绕过 Better Auth 员工权限。
- 本步骤不修改 `upstream/voyant` 上游源码，不新增产品编辑、支付、资源调度或虚构签到逻辑。

## 2026-08-27 Hi.Events 票务员工端接入

- TuyuBooking Flutter 票务核销页使用 Hi.Events 原生 `/events`、`/events/:id/check_in_stats`、`/events/:id/attendees` 与 `/events/:id/attendees/:public_id/check_in` 合同。
- 票券二维码中的 `A-` 短 ID 先通过当前活动参与者查询解析为上游 `public_id`，再提交 `check_in` 或 `check_out`；不把票面 ID 当作内部数据库主键。
- iOS/Android 业务扫码使用 `mobile_scanner`，桌面业务扫码复用 `flutter_lite_camera` 与 `zxing2`；扫码数据只存在于当前进程。
- Hi.Events 继续拥有活动、订单、参与者、票券、付款与核销数据，本步骤不修改 `upstream/hi_events` 上游源码。
