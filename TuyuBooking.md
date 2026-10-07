# 途遇商家端技术文档

## 当前工作目录归属（第8步，2026-10-06）

本产品全部测试、编译临时数据和产物归 `/Users/rhett/tuyubooking/target`。多平台先使用声明中的完整平台身份，再在平台内按build、ci、release、publish、test、tmp隔离。独立入口与控制台调用消费同一产品流程；控制台仅创建任务、调用与跟踪，不准备产品专用版本、依赖或步骤。下载半包、工具编译候选、工程视图、Runner步骤临时状态和测试夹具均属于当前产品工作区；永久工具与依赖原件继续归原件库。整个根target不进入Git、源码快照、程序摘要或打包输入。准确流程短锁、活跃任务保护、成功产物保护和原清理规则继续适用。

第8、9步完成目录与路径实现、根文档迁移及测试源码维护，未运行测试、门禁、编译或安装。本文唯一原件位于/Users/rhett/tuyubooking/TuyuBooking.md；产品接口及流程直接以本仓实际代码和声明为准，业务字典库与其检查已撤销，不另建登记副本。历史验收事实不表示本轮改造已经通过验收，统一测试在第10步进行。根技术文档由本仓门禁按原文、JSON解码值及既有补丁快照扫描机密，仅报告路径；文档迁出不减少资料安全检查。


## 正式软件版本

主机和分机分别拥有自己的平台 Release Tag 与版本序列；共同使用的 `app/pubspec.yaml`
只提供首版 `1.0.0+1` 种子。没有已发布正式 Release 的身份首次成功发布
为 `v1.0.0`。失败不占号，后续版本只按相同产品和平台的成功正式 Release 递增；
安装包显示其自身版本，不读取另一产品或平台的版本。

## 聊天功能的唯一产品归属

**聊天客户端的逻辑功能只能在 TataChatSDK 中实现；聊天服务端的逻辑功能只能在 TataChatServer 中实现。公民、途遇及其他产品只依赖使用。**

TuyuBooking 涉及聊天时只作为依赖使用方；本条不代表尚未接入聊天的产品已经具备聊天能力。

- 消息、会话、群组、加密、协议、传输、同步、重试、聊天存储、附件、通话及聊天界面行为，按客户端与服务端职责分别归 TataChatSDK 和 TataChatServer；新增功能、缺陷修复和平台差异也必须在所属塔塔聊天产品内完成。
- 消费产品只提供产品入口、身份与业务权益结果、服务地址及授权、主题和公开接口要求的平台配置；只通过公开接口接入，禁止复制、重写、包装成另一套聊天内核或维护产品专属聊天实现。CitizenServe、TuyuServe 的产品身份与权益授权不包含聊天数据面的实现职责。
- 本机开发直接依赖仓库路径；公民、途遇等产品的正式版本依赖塔塔聊天正式 Release；第三方市场分发使用公开市场版本。依赖使用不以公开市场发布为前置条件，也不改变实现归属。

主机与分机受控缓存分别固定为 `tuyubooking/target/<host-platform|client-platform>/<build|ci|release|publish>/`。Flutter视图、Node/Python依赖展开、业务运行时、Cargo、Xcode、临时文件、日志和候选均写所属流程目录；四个流程互不清理，启动不建立缓存。

当前依赖边界：TuyuBooking 的锁文件和产品脚本自行决定依赖、版本、来源及工具；控制台不做产品依赖或工具门禁。唯一 `rely/` 只保存产品主动取得的离线原件。

本机 Build 由 Worker 创建任务、清空准确产品平台缓存后直接启动产品入口；后续工具、依赖和编译条件均归产品流程。Android产品函数把本轮Flutter配置选出的SDK和调用方JDK传给同一次Gradle调用，本机未提供JDK时使用Android Studio随包JBR，不增加Worker前置检查。移动端成功后安装，macOS 成功软件进入 `<产品根>/target/<平台>/`，其余平台只记录编译结果。

TuyuBooking 是多平台产品。主机四个平台和分机四个平台必须分别使用`<产品根>/target/<平台>/<流程>/`，每个平台的依赖展开、工具可写状态、编译物、日志与临时文件互不共用。源码可以共同只读，但Flutter生成状态不得写回共同`app/`后再被不同平台覆盖。Build不执行`flutter analyze`或`flutter test`；分析与测试只属于产品单独定义的质量流程。

Android 工具、SDK、NDK 与版本均由 TuyuBooking 产品流程自行选择和校验；Worker 不读取、不注入、不验真，也不以工具状态阻塞 Build。

本文是途遇商家端（TuyuBooking）唯一技术事实文档。

商家端七个上游源码目录由完整商家产品仓直接持有，固定来源仓库与导入提交记录在 `tuyubooking.sources.json`。控制台保存、提交和推送只操作完整商家产品仓tuyutata/tuyubooking，上游目录不再拥有独立 gitlink、工作树或提交入口。后续同步指定上游版本时使用 Git subtree 导入，再连同产品改动一起通过塔塔控制台保存。Voyant 完整功能和现有集成保持不变。

CMake 只使用塔塔工具库的唯一 3.31.6 对象。Worker 在真实 Build 任务已显示后，把该对象的绝对入口同时注入 `CMAKE_COMMAND` 和 PATH 首位；不扫描产品，不在任务前执行工具门禁。TuyuBooking Android 仅把该入口写入本平台缓存工程的 `cmake.dir`，不得回落到 Homebrew 或用户 Android SDK 中的其他版本。

主机 Node 与 Yarn 由产品 Action 自行选择和使用，构建中间物写入产品任务缓存。塔塔工具登记只是可选来源，不形成路径或版本门禁。

Gradle、Java 与 CitizenSDK 宿主准备属于 TuyuBooking 产品实现。商家分机 Android 保留调用方显式传入的 `JAVA_HOME`；公开Build入口按本仓声明要求调用方交付准确Java与Gradle执行器，缺失或版本不符立即失败；编译命令和失败条件归本产品scripts。

工具适配第2项的代码、接线回归、文档和残留收口已完成，整包和手机安装验收未执行。下一项拟进行主机启动链路的代码与测试收口，重点为数据库就绪、模块按选择启动、失败状态及停用保留数据；不改写上游业务。确认前不实施下一项，也不启动真实商家实例或自动编译安装。

第2项工具适配收口不触发主机或分机整包构建，不重新打包控制台，不安装手机应用。验收范围是Android插件接线、Apple引擎副本权限、取消等待、并发隔离与已结束任务生成物清理；测试结果及未执行的实机验收以现有任务卡为准。后续启动和业务联调必须另行确认，不以本项回归通过代替。

Flutter 及 Android/Apple 工程配置由商家产品流程负责。控制台不复制产品源码；本机Build在准确主机/分机及平台缓存内建立只读符号链接工程视图，保留原绝对目录层级以解析CitizenSDK等相对路径依赖，`.dart_tool`、插件登记、Pods、Gradle、Flutter build与平台临时配置全部生成在该缓存视图或本任务缓存中。

主机和分机 Action 自行决定 Flutter、Dart、Gradle、Java、AGP 与 Kotlin；远端 Action 若选择读取塔塔工具登记，该选择仍属于产品流程，不是 Worker 前置门禁。安装身份、签名和产品入口由产品继续负责。

商家分机Android当前统一使用Gradle9.1.0、AGP9.0.1与KGP2.2.20，并保持内置Kotlin和新DSL。根buildscript在同一依赖图声明AGP与KGP，settings不再另行解析AGP而暴露其自带KGP2.2.10；应用脚本显式导入JDK类型，避免AGP的`java`扩展遮蔽包名。版本仍由产品Gradle执行，控制台不新增检查或阻塞。

## marketplace

### 途遇商城技术文档

#### 1. 模块定位

途遇商城是 TuyuBooking 内部的 B2B 厂家发现和采购模块，不是独立部署产品，也不是由 TuyuServe 托管业务的中心化商城。

#### 2. 边界与功能

- 使用者是酒店、餐厅、旅行社、景区和活动商家的采购人员。
- 供应方是自行部署 TuyuFactory 的生产厂家。
- TuyuBooking 是采购单、收货和采购成本权威。
- TuyuFactory 是商品、报价、库存、销售单和发货权威。
- 功能包括厂家发现、商品搜索、实时询价、采购单、厂家确认、发货、收货、取消、退货和售后。

#### 3. 查询和订单

TuyuBooking 从 TuyuServe 读取厂家和商品公开摘要，再直接访问目标 TuyuFactory 的公开 HTTPS API，确认实时价格、库存、起订量和交期。缓存摘要不能形成最终采购承诺。

TuyuBooking 创建采购订单，TuyuFactory 创建对应销售订单。双方通过全局交易 ID、幂等键、实例签名和状态事件关联，不跨数据库联表，不使用分布式数据库事务。

采购状态使用 `DRAFT`、`QUOTED`、`SUBMITTED`、`ACCEPTED`、`REJECTED`、`FULFILLING`、`SHIPPED`、`RECEIVED`、`CANCELLED`。每次状态变化保存对方签名凭证和协议版本。

#### 4. 安全和状态

- 所有通信使用 HTTPS。
- 人员授权使用途遇号绑定的 sr25519 签名账户。
- 系统通信使用经所有者授权的 sr25519 实例密钥。
- 请求必须包含时间、有效期、请求 ID、幂等键和载荷摘要。
- 当前不实现任何支付方式。
- 当前只完成技术设计，代码目录尚未创建。

## 产品总览

### 途遇商家端技术文档

#### 1. 产品定义

- 中文名称：途遇商家端
- 英文名称：TuyuBooking
- 产品目录：tuyubooking
- 产品形态：一个产品、一套 Flutter 工程、六个平台、两种运行模式
- 主机平台：`macOS`、`LinuxARM`、`LinuxAMD`、`Windows`
- 员工平台：`iOS`、`Android`；iPhone/iPad 归入 iOS，Android 手机/平板归入 Android
- 主机运行位置：商家自己的常开电脑或服务器

TuyuBooking 不部署在 Cloudflare。商家业务数据、子系统运行时和 PostgreSQL 均运行在商家
自己的桌面主机上。iOS（iPhone/iPad）与 Android（手机/平板）员工端不携带数据库和业务运行时，只通过局域网
HTTPS 连接当前商家的 TuyuBooking 主机。

TuyuBooking 是商家的唯一核心系统。TuyuLove 旅行用户通过它购买商家服务；商家员工前期通过
上游浏览器界面工作，后期使用同一 TuyuBooking Flutter 工程构建的 iOS（iPhone/iPad）或 Android（手机/平板）员工端
完成收银、点菜、接单、查房、签到和检票；商家通过内部“途遇商城”向独立部署 TuyuFactory
的厂家采购。不存在独立 BookStaff 产品、代码工程或发布体系。与途遇旅行、服务端和厂家端直接
相关的跨产品边界由本文共同记录，不再依赖途遇体系汇总文档。

#### 2. 总体架构

TuyuBooking 由统一 Flutter 应用、Rust 主机内核、固定 Fork 子系统、局域网 HTTPS Gateway、
Staff API、途遇商城采购模块和一个 PostgreSQL 数据库组成。Flutter 工程按目标平台组合能力：
四个桌面主机平台启用主机控制和 Rust FFI，两个移动平台启用员工界面和 HTTPS 客户端。

商家只在一台主机安装完整TuyuBooking。当前员工使用不同电脑或平板通过浏览器访问商家主机；
四个上游系统真实可用且 Staff API 稳定后，在现有 Flutter 工程完善 iOS（iPhone/iPad）和 Android（手机/平板）
构建目标及员工页面。主机必须在营业期间保持运行。

所有商家按设备平台下载同一 TuyuBooking 产品的对应安装包。桌面主机安装包包含全部已发布
模块载荷，用户可以启用一个或多个子系统；未启用子系统不初始化 Schema、不启动运行时。
手机/平板员工安装包不包含 PostgreSQL、Rust 主机内核或四个上游运行时。

#### 3. 业务子系统

| 子系统 | 固定Fork | 业务权威 |
|---|---|---|
| 酒店及酒店餐厅 | Kamra PMS | 房间、房价、入住、酒店餐厅和房账 |
| 独立餐厅 | URY | 菜单、桌台、POS、厨房和餐厅订单 |
| 旅行团及活动 | Voyant | 行程、团期、名额和旅行预订 |
| 票务 | Hi.Events | 活动、票种、订单、二维码和检票 |

四个 tuyutata组织Fork 以 Git subtree 源码快照进入完整商家产品仓，并在来源清单固定导入 Commit。业务修改直接随TuyuBooking保存；TuyuBooking Rust 核心不重新实现上游已有业务。

#### 4. 单数据库架构

安装包只提供一个PostgreSQL服务，只创建一个tuyubooking数据库：

| Schema | 职责 |
|---|---|
| tuyu_core | 安装实例、平台账户、模块状态、事件、幂等和统一索引 |
| module_kamra | 独立酒店站点；Kamra酒店及酒店餐厅业务和员工数据 |
| module_ury | 独立餐厅站点；ERPNext、HRMS、URY餐厅业务和员工数据 |
| module_voyant | Voyant业务和员工数据 |
| module_hi_events | Hi.Events业务和员工数据 |

每个子系统使用独立数据库角色。Kamra与URY只共享安装包内不可变的Frappe源码和前端资源，不共享站点、Schema、运行进程、日志、员工账户或业务数据。禁止业务数据进入public Schema，禁止模块创建独立数据库，禁止MariaDB、MySQL和SQLite业务数据库。

子系统不得直接跨Schema联表。跨模块订单和客户关联通过TuyuBooking模块API、事件和tuyu_core只读索引处理。

#### 5. 账户边界

TuyuBooking 只有管理员和员工两类账户。管理员不设置角色层级，所有启用管理员都能管理整个
商家端和全部已启用子系统；员工继续使用各 Fork 原有账户、岗位、角色和权限。管理员只保存
不可变的 32 字节 sr25519 公钥、可选姓名和本机状态，TuyuBooking 不保存私钥，也不使用途遇号
注册或登录。首次安装没有管理员时，由应用相机扫描 `QR_V1/k=5` 公钥二维码写入第一名管理员；
完成初始化后，只有已登录的启用管理员才能新增、删除、改名或改变其他管理员状态。

管理员总数上限为 99，系统始终至少保留 1 名启用管理员。公钥就是管理员身份，不提供修改或
替换公钥的功能；新增和删除是不同身份生命周期。删除物理移除管理员记录但保留审计，停用保留
记录并禁止登录；管理员停用或删除本人后当前会话立即失效。日常登录由主机显示一次性挑战
二维码，途遇旅行或公民钱包扫码并在用户设备本地签名，主机使用已保存公钥验签并创建内存会话。

酒店员工、餐厅员工、旅行社员工和票务员工不属于系统管理员。员工账户、岗位、角色和权限
继续使用各 Fork 原有实现。

#### 6. 员工访问

负责人通过 TuyuBooking 桌面主机端管理主机、模块、备份和系统管理员。普通员工前期通过浏览器、
后期通过 TuyuBooking iOS（iPhone/iPad）或 Android（手机/平板）端访问局域网 HTTPS 入口：

    https://tuyubooking.local

员工可访问的唯一网络入口是TuyuBooking LAN Gateway。数据库、Supervisor和子系统内部端口不向局域网公开。公网访问默认关闭。

员工设备需要完成设备配对并信任商家主机证书，之后仍需使用对应子系统员工账户登录。

手机/平板员工模式属于 TuyuBooking 同一 Flutter 工程，不是独立软件。它不保存权威业务数据、不直接
访问 PostgreSQL，也不直接调用 Kamra、URY、Voyant 或 Hi.Events 内部端口。TuyuBooking 未完成
四个上游真实运行和统一 Staff API 之前，不启用平板员工业务页面。

##### 6.1 途遇商城和厂家边界

途遇商城是TuyuBooking内部B2B采购模块。它从TuyuServe发现厂家及商品摘要，再向厂家自行部署的
TuyuFactory实时确认价格、库存、起订量和交期。TuyuBooking保存采购订单、收货和采购成本；
TuyuFactory保存商品、报价、销售订单和发货。双方通过HTTPS、幂等键和sr25519实例签名协作，
不共享数据库事务，TuyuServe不保存双方权威订单。

##### 6.2 当前可用性口径

固定Fork、PostgreSQL迁移、模块契约和桌面壳编译成功只表示源码接入完成，不等于商家可用。
只有安装包内完整业务运行件能够启动、登录、执行核心业务、重启后保留数据并正确停止，模块
才可标记为真实可用。当前首要任务是完成四个上游系统的实际运行闭环，不提前开发员工端。

#### 7. 模块协议

`modules/`采用无子目录的平铺结构。每个业务模块提供`<module>.module.toml`，
Frappe框架配置和数据库基线分别使用`frappe.framework.toml`与`frappe.schema.sql`。
业务模块清单声明：

- 固定Fork和Commit
- 运行时与构建入口
- 简体中文和英文
- 本机 sr25519 系统管理员入口
- 上游原生员工认证
- 局域网HTTPS访问约束
- 唯一数据库与独立Schema
- 订单权威和事件协议
- 当前PostgreSQL迁移状态

Kamra、URY、Voyant和Hi.Events当前均为postgresql_runtime。postgresql_runtime表示本地源码、单数据库方言、运行入口和契约已经接通，正式主机安装包由既有发布流程按 `macOS`、`LinuxARM`、`LinuxAMD`、`Windows` 分平台构建与回归；这不改变移动员工端只携带客户端能力的边界。

#### 8. 本地化

系统只支持简体中文和英文。中文及未支持语言默认显示简体中文，英文系统显示英文。上游缺少中文时在对应tuyutata组织Fork中增加翻译资源，不删除英文。

#### 9. 运行与安装约束

- 一个安装包包含全部已发布模块载荷。
- 上述完整载荷规则只适用于 `macOS`、`LinuxARM`、`LinuxAMD`、`Windows` 四个主机安装包。
- `iOS`（iPhone/iPad）与 `Android`（手机/平板）安装包只包含 Flutter 员工界面、配对、认证和 HTTPS 客户端。
- 不使用Docker、Podman、OCI、虚拟机、WSL或Linux Guest。
- 用户只启用需要的模块。
- 禁用模块保留Schema和数据，不自动删除。
- 数据库、模块、配置和版本由TuyuBooking统一备份和恢复。
- 本机主机端开发只编译 macOS，发布流程由现有 tataconsole 塔塔控制台负责其他平台。

#### 10. Cloudflare边界

Cloudflare不运行TuyuBooking、Fork子系统或商家数据库。员工局域网访问不经过Cloudflare。聊天逻辑功能归TataChatSDK与TataChatServer；TuyuServe中的游记和公开服务属于其他产品边界，不得成为商家业务数据库。

#### 11. 当前排除项

- 公民链和支付
- Docker及容器运行
- 多数据库兼容
- 商家员工权限重建
- Rust重写Fork业务
- 将商家数据库托管到Cloudflare
- 本窗口负责CI、Release和发布流程

#### Step 3: Frappe and Kamra PostgreSQL runtime (2026-08-25)

TuyuBooking uses the `tuyutata/frappe` fork pinned to Frappe `v16.25.0` and the `tuyutata/kamra-pms` fork. Both customizations live on `codex/tuyubooking-postgresql-schema`; the immutable commits are recorded in `tuyubooking.sources.json`.

The merchant runtime has one PostgreSQL service and one application database named `tuyubooking`. Platform-owned data uses `tuyu_core`; Kamra uses `module_kamra` through role `tuyu_kamra_app`. Tuyu mode creates and drops only its module schema and role. It must never create or drop the `tuyubooking` database.

Tuyu mode is enabled only with `tuyu_single_database=true`, `tuyu_postgres_backend=true`, `db_type=postgres`, `db_name=tuyubooking`, and `db_schema=module_kamra`. Its secure PostgreSQL `search_path` is `module_kamra, pg_catalog`.

Redis is not a TuyuBooking runtime service. Cache, background jobs, advisory locks and realtime publication use PostgreSQL tables, advisory locks and `NOTIFY`. Upstream Redis/RQ behavior remains available only for non-Tuyu Frappe deployments.

Kamra retains upstream hotel and hotel-restaurant behavior. The Tuyu fork changes only integration boundaries: PostgreSQL SQL compatibility, optional Payments dependency and default Simplified Chinese language. Staff accounts and permissions remain Kamra/Frappe native; the Tuyu account controls platform owner and system-administrator access outside the business subsystem.

Step 3 validation passed: Python syntax checks, 28 native Rust tests, 1 module-contract test, 1 source-intake test, 3 Frappe/PostgreSQL contract tests, 9 Flutter tests, and a real temporary PostgreSQL schema execution test. No Docker, Podman, VM, Linux Guest, MariaDB, MySQL or Redis service is introduced.

#### Step 4: Kamra local runtime orchestration (2026-08-25)

TuyuBooking now starts the merchant runtime in this order: embedded PostgreSQL cluster, the single `tuyubooking` application database, native migrations, Kamra/Frappe provisioning, PostgreSQL job consumer, and the Kamra HTTPS endpoint. Startup is considered ready only after both PostgreSQL and the business HTTPS port are available. Shutdown stops Kamra before PostgreSQL.

The previous use of the PostgreSQL system database `postgres` for application tables has been removed. `postgres` is used only as the unavoidable PostgreSQL maintenance database while checking or creating the one application database named `tuyubooking`.

Kamra runtime data is stored under the operating system application-support directory. The installation directory contains immutable runtime code tuyu. Database credentials and the initial Kamra administrator secret are generated separately and kept in device secure storage; the protected supervisor configuration is written with owner-only permissions on Unix systems.

The business runtime is an offline release artifact containing locked Python 3.14, Frappe commit `2ff1805e7aca5b4098b22d435bb84d4f841c8ed4`, and Kamra commit `40b508698f94fd598f8827a7cd0cca33393fad46`. Packaging never invokes an online package installer. The release pipeline must provide this prebuilt platform artifact through `TUYU_BUSINESS_RUNTIME_SOURCE`; merchant computers never need Python, Bench, pip or network dependency installation.

The Kamra supervisor creates the Frappe site in application data, enables `tuyu_single_database` and `tuyu_postgres_backend`, installs/migrates Kamra, generates a local TLS identity, serves Frappe through Gunicorn TLS, and restarts the web or PostgreSQL-job child if it exits. No plaintext TCP endpoint is exposed to the LAN.

The macOS, LinuxARM (`aarch64/arm64`) and Windows (`x86_64`) packaging contracts now embed and validate the same business runtime layout. Windows remains static-contract only in local development. No release package was materialized in this task because the repository does not contain the CI-owned offline macOS business runtime artifact; no network download was performed.

Step 4 validation passed: Python and shell syntax, 30 native Rust tests including real PostgreSQL database creation, 1 module-contract test, 1 source-intake test, 4 Frappe/Kamra runtime tests, and 9 Flutter tests.

#### 途遇号与商家实例身份模型（第 5 步历史记录，现已由本机管理员模型取代）

本节只记录历史实现，不再定义当前登录权限。当前权威模型以“账户边界”章节及
“2026-08-27 本机管理员初始化与生命周期”章节为准；TuyuBooking 不再使用途遇号注册或登录。

- 途遇号是跨产品统一主体，一个途遇号可绑定多个 sr25519 签名账户。
- 私钥仅保存在用户设备安全存储中；TuyuServe 只保存途遇号、公开账户、密钥版本、设备标识及撤销状态。
- 一个途遇号可拥有或管理多个 TuyuBooking 商家实例；一个商家实例只有一个所有者途遇号，并可授权多个管理员途遇号。
- 商家所有者角色为 `MERCHANT_OWNER`，授权管理员角色为 `MERCHANT_ADMIN`。所有者不可通过管理员授权接口删除或降级。
- TuyuBooking 登录由客户端先选择本机 sr25519 账户，再申请绑定账户、设备、商家实例和角色的挑战；签名始终在本机完成。
- 正常商家管理会话必须绑定 `tuyu_id`、`signer_id`、`account_id`、`key_revision`、`device_id`、`merchant_instance_id` 和 `merchant_role`。
- 会话有效期为 8 小时。创建会话时重新检查签名账户和商家授权，挑战只能消费一次。
- TuyuBooking 本地 PostgreSQL 保存已验证管理员缓存、签名会话和管理员审计；审计能够定位实际使用的 sr25519 签名账户与设备。
- 酒店、餐厅、活动和票务员工仍使用本商家实例内的本地账户及上游原生权限，不使用途遇号，也不跨实例共享。
- 商家实例注册、管理员授权和撤销接口分别为 `/v1/merchant-instances/register`、`/v1/merchant-instances/grants`、`/v1/merchant-instances/grants/revoke`。
- 第 5 步未修改 Frappe、Kamra、URY、Voyant 或 Hi.Events 的上游业务功能。

##### 第 5 步验证结果

- TuyuServe D1 单一基线结构加载通过。
- TuyuServe：5 个测试文件、15 项测试通过；严格 TypeScript 类型检查通过。
- TuyuBooking Native：31 项 Rust/PostgreSQL 测试通过。
- TuyuBooking Desktop：9 项 Flutter 测试通过。
- 模块、源码接入及 Frappe/PostgreSQL 契约测试全部通过。

#### 途遇管理员到本地业务系统的安全桥接（第 6 步）

TuyuBooking Native 为当前已验证的途遇号所有者或管理员创建 256 位随机、60 秒有效、只能消费一次的本地管理员断言。明文令牌只通过 FFI 返回桌面端，并放入 HTTPS 地址的 URL Fragment；Fragment 不会随首个页面请求发送给服务器，也不会进入普通访问日志。PostgreSQL 只保存令牌的 SHA-256 摘要。

Kamra 的 /tuyu_admin 落地页从 Fragment 读取令牌，通过带 CSRF 保护的 HTTPS POST 交给 kamra.tuyu_admin_bridge.consume。消费操作使用 PostgreSQL 条件更新同时检查未使用、未撤销、断言未过期和途遇管理员会话未过期，因此重放、过期、撤销及其他本地数据库生成的令牌都会被拒绝。

断言消费成功后，Kamra 通过 Frappe 标准 LoginManager 建立本地管理会话，并使用唯一技术用户 tuyu-system-administrator@localhost 承载 System Manager 权限。途遇号不会被复制成 Frappe 员工账户；商家员工仍由 Frappe/Kamra 原生 User、Role 和权限功能管理并且只属于当前商家实例。

tuyu_core.upstream_administrator_session 把 Frappe Session ID 映射回途遇号、sr25519 signer、account、device、merchant instance 和角色。每次技术管理员请求都检查映射未撤销且未超过原途遇会话有效期；写请求记录到 administrator_bridge_audit。

本步新增三张表：administrator_assertion、upstream_administrator_session、administrator_bridge_audit。唯一 PostgreSQL 基线由 78 张表增加到 81 张表，没有增加数据库、Redis、容器或中心化业务服务。

##### 第 6 步验证结果

- Native：32 项测试通过，包括真实 PostgreSQL 迁移、幂等、失败回滚、管理员身份与断言随机性。
- Flutter：11 项测试通过，包括仅 HTTPS、令牌只放 Fragment、统一四模块登录。
- Frappe/PostgreSQL：5 项契约测试通过。
- 模块契约：1 项通过。
- 源码接入契约：1 项通过。
- Python 语法及缩进检查通过。
- 行为与迁移脚本通过，数据库基线为 81 张表。
- 本机没有打包后的完整 Frappe/Kamra 业务运行时，因此本步完成源码级、数据库级和接口契约验证；安装包内真实浏览器端到端验证仍属于发布环境验证流程。

#### 第 7 步：URY独立餐厅运行时（2026-08-25）

独立餐厅子系统已接入统一的本地Frappe 16运行时。TuyuBooking离线业务运行时固定包含Frappe、ERPNext、HRMS、Kamra和URY五个App；安装或升级时按ERPNext、HRMS、Kamra、URY顺序幂等安装到同一个站点。已存在的商家站点会自动补装缺失App，不创建第二个站点、数据库或Python环境。

ERPNext 与 HRMS 均固定到 `tuyubooking.sources.json` 登记的 tuyutata组织Fork version-16 提交。两者作为 Git subtree 源码载荷和 GPL-3.0 源码载荷进入同一个 TuyuBooking 安装包。URY 同样以来源清单登记的提交为准。

URY原有查询报表及生产SQL已直接迁移为PostgreSQL语法，包括日期序列、营业日边界、时间分组、字符串聚合和空值函数。未保留MariaDB/MySQL兼容分支。URY默认语言为简体中文，英文继续受支持；上游餐厅员工、岗位和权限模型保持不变。

途遇号所有者或系统管理员从统一桌面端进入餐厅时，复用第6步的一次性管理员断言，并通过白名单目标`ury`进入Frappe `/pos`。令牌仍只在本地HTTPS URL Fragment中传递、60秒有效且只能消费一次。酒店入口使用`kamra`目标，二者共享同一技术管理员会话桥接和审计规则。

第7步验证通过：Frappe/PostgreSQL 7项、源码接入1项、模块契约1项、Flutter 12项；URY、Kamra与本地业务运行时Python编译及离线物化脚本语法检查通过。当前仓库不含由发布流程生成的完整离线Python运行时制品，因此本机未执行真实Frappe全栈启动测试。

#### 第 8 步：Voyant旅行团活动运行时（2026-08-25）

旅行团及活动子系统直接运行固定提交`2c81ee68011e8e324a1ad41ce009d12b20907e56`中的Voyant operator应用。Voyant继续负责旅行产品、资源、名额、行程、预订、参与人、合同和财务等业务，TuyuBooking Rust核心不复制这些业务逻辑。

TuyuBooking使用Voyant现有React 19、TanStack Start、Hono、Drizzle和Better Auth技术栈，并增加本地Node.js 24/Nitro运行模式。商家电脑只运行预构建Node产物，不需要pnpm、npm、Cloudflare、Docker、Podman或在线安装依赖。Cloudflare构建模式保留给上游，但TuyuBooking运行时不使用它。

Voyant连接唯一的`tuyubooking`数据库，业务对象只写入`module_voyant` Schema，运行角色为`tuyu_voyant_app`。迁移器在Tuyu模式下强制校验数据库名称、设置安全`search_path`、隔离Drizzle迁移表并转换上游对`public` Schema的显式引用；禁止创建第二数据库或向`public`写入业务表。

Native监督器先执行预构建Voyant迁移器，再启动仅监听`127.0.0.1:59445`的Node进程。局域网入口由同一安装包内的TLS反向代理暴露为`https://<merchant-host>:58444`，复用商家本地证书；数据库和Node内部端口不向局域网公开。运行时就绪要求酒店/餐厅入口`58443`与Voyant入口`58444`同时可用。

途遇号所有者或系统管理员通过已有60秒一次性断言进入Voyant `/tuyu_admin`。令牌仅位于URL Fragment，页面立即清除Fragment并以HTTPS POST原子消费；Better Auth技术管理员会话通过`tuyu_core.upstream_administrator_session`映射到实际途遇号、sr25519 signer、设备和商家实例。旅行社员工继续使用Voyant原生Better Auth账户、团队和权限。

Voyant默认语言调整为简体中文并保留英文，核心管理员导航和认证文本已增加中文。尚未翻译的上游扩展文本回退英文，不改变业务规则。

第8步验证通过：Voyant契约4项、模块契约1项、源码接入1项、Frappe/PostgreSQL回归7项、Native 32项、Flutter 13项和完整TypeScript类型检查。真实临时PostgreSQL执行54个Voyant迁移，生成323张`module_voyant`业务表，`public`业务表为0；预构建Node服务实际启动并通过管理员入口及安全响应头检查。未在本步骤制作macOS、Linux或Windows发布安装包。

#### 第 9 步：Hi.Events票务运行时与旧旅行团脚手架清理（2026-08-25）

- 票务子系统直接运行`tuyutata/Hi.Events`固定提交`048243e2a99a65c8e77fc6f3cb44de158169855e`，TuyuBooking不复制票务业务逻辑。
- Hi.Events仅连接统一数据库`tuyubooking`的`module_hi_events` Schema，运行角色为`tuyu_hi_events_app`；缓存、队列和会话均使用PostgreSQL。
- 本地运行时由TuyuBooking主进程统一托管PHP 8.4、Nginx、Node SSR、队列与调度进程，不要求商家安装Docker、Podman或独立数据库。
- 对外入口固定为`https://127.0.0.1:58446`；内部Nginx HTTPS、FastCGI与前端SSR HTTPS端口分别为59448、59447、59449。FastCGI是PHP进程协议，不是HTTP入口。
- 途遇号系统管理员使用一次性管理员断言换取Hi.Events技术`SUPERADMIN`会话；断言只在URL fragment中传递，服务端原子消费并持续校验映射会话。Hi.Events原生员工账户、岗位与权限保持不变。
- Hi.Events界面语言限制为简体中文和英文，默认及不支持语言回退为简体中文。
- 已彻底删除早期Rust旅行团领域、服务、仓储和迁移脚手架；Voyant继续作为旅行团及活动数据唯一权威，Rust只保留通用子系统访问编排。
- 验证结果：Hi.Events契约5项、TuyuBooking Native 29项、模块契约1项、源码接入1项、Frappe/PostgreSQL 7项、Voyant 4项、Flutter 15项全部通过；真实临时PostgreSQL验证`module_hi_events`创建31张表且`public` Schema为0张业务表。
- 本机没有PHP/Composer及完整离线发布运行件，因此未执行Laravel全部103个迁移和完整PHP/Nginx/SSR启动；该项由既有三平台发布流程完成。

#### 第 10 步：上游业务唯一权威与Native核心收缩（2026-08-25）

- Kamra、URY、Voyant、Hi.Events分别成为酒店及酒店餐厅、独立餐厅、旅行团活动、票务业务的唯一实现和数据权威；Native不再复制这些系统的业务模型、库存、订单、状态机或仓储逻辑。
- 已删除`host/src/hotel`、`host/src/restaurant`、`host/src/ticket`、对应Application Service、Repository、容量模型及`migrations/hotel`、`migrations/restaurant`、`migrations/ticket`；第9步已删除的旅行团Rust脚手架继续保持不存在。
- `ApplicationServices`仍提供hotel、restaurant、tour、ticket四个固定入口，但全部统一为`ModuleAccessService`，职责仅为验证途遇号管理员会话并返回上游模块访问上下文。
- Native PostgreSQL迁移基线仅剩`0001_tuyu_core`，包含17张平台表；各上游子系统继续在同一`tuyubooking`数据库内维护自己的Schema和迁移。
- Native继续负责途遇身份会话、系统管理员断言、命令幂等、审计、统一PostgreSQL生命周期、子系统发现和进程编排。
- 自动化契约禁止旧业务目录、服务、仓储、容量模型和业务迁移重新出现。
- 验证结果：Rust格式检查、迁移行为脚本、Native 20项测试、源码接入1项测试、Hi.Events 5项契约全部通过；真实PostgreSQL确认1个Native迁移、1个Native Schema和17张`tuyu_core`表。

#### 第 11A 步：macOS离线业务运行件来源方案（2026-08-25）

- 第11步全栈联调因`runtime/business/macos`不存在而停止；本步骤没有下载、构建或引入任何二进制。
- 离线包唯一根目录确定为`runtime/business/macos`，不得使用分散的runtime目录、Homebrew或商家电脑系统运行时。
- Node运行时版本、来源与SHA-256只由受控工具库登记；其它基础运行时依实际runtime.lock和来源清单核验，不在本次Node接线中改动。
- Frappe系列使用带哈希的离线wheelhouse；Voyant、Hi.Events后端和前端分别使用仓库固定的pnpm、Composer、Yarn锁文件生成生产产物。
- 离线包晋级前必须具备逐文件SHA-256、最终包签名、SPDX SBOM、完整第三方许可证、ARM64和动态链接检查以及断网冒烟测试。
- 详细方案位于`scripts/business-runtime/SOURCES.md`，机器可读来源计划位于`scripts/business-runtime/macos.sources.plan.json`。
- 第11步仍未完成，只有现有塔塔控制台构建流程提供满足门禁的离线包后才能继续真实全栈联调。

#### 第 11 步阶段结果：macOS应用编译（2026-08-25）

- TuyuBooking桌面端从准确平台缓存内的只读Flutter工程视图执行macOS Build，源码仍来自唯一产品工程；业务运行件由产品流程按自身要求处理。
- 本机Flutter 3.44.4在通用架构构建时会把`arm64 x86_64`同时传给只接受单架构的`lipo -verify_arch`；项目Release配置已按本机开发约束固定为`ARCHS = arm64`和`ONLY_ACTIVE_ARCH = YES`，未修改Flutter SDK。
- 编译参数使用 `TUYU_SERVE_URL=https://serve.tuyulove.com`，满足客户端仅允许 HTTPS 服务端地址并只保留现行途遇域名。
- 该阶段的旧产品目录产物已经删除；现行主机端本机成功产物固定为
  `/Users/rhett/tuyubooking/target/host-macos/TuyuBookingHost.app`。
- 本阶段只完成途遇商家端桌面App编译；Kamra、URY、Voyant、Hi.Events真实运行集成仍属于后续任务，不在本次编译结果中虚假声明完成。

#### 正式 GitHub Release 合同（2026-08-25）

- macOS、Linux、Windows 使用三个完全独立的 Release Tag、运行记录和资产：
  `tuyubooking-host-macos.zip`、`TuyuBookingHost-LinuxARM.deb`、
  `TuyuBookingHost-LinuxAMD.deb`、`tuyubooking-host-windows.zip`。
- 当时已实现的平台固定为 `macOS`、`LinuxARM`、`Windows`；架构分别为 Apple `arm64`、Linux `aarch64/arm64`、Windows `x86_64`，Runner 分别固定为
  `macos-15`、`ubuntu-24.04-arm`、`windows-2025`，并在脚本中同时核验运行机和最终产物架构。
- 每个平台只接受本平台最新成功 CI 锁定的准确 `main` 提交，重新执行 Rust workspace 测试、
  原生 Release 构建和 Flutter 桌面 Release 构建；服务地址固定为 HTTPS 正式入口。
- 每个 Tag 固定包含平台主资产、`release-manifest.json` 和 `SHA256SUMS`。TUYU 全部产品统一
  不使用 GitHub Artifact Attestation；主资产由 GitHub Release `sha256:` 摘要、文件尺寸、
  本地流式 SHA-256、源码 SHA 与双重清单共同验真；同名 Tag 或 Release 禁止覆盖。
- GitHub 只生成正式不可变资产，不执行平台生产发布。三个平台后续分别由本机 TataConsole 的
  独立发布器消费，不共享记录、状态、资产或回滚锚点。

#### 正式安装包发布与下载合同（2026-08-25）

- macOS、Linux、Windows 发布动作分别由 TataConsole 固定原生发布器执行；每次事务只
  下载和验真一次准确 GitHub Release，只使用一次 Touch ID 和一次 QR_V1 冷签。
- 安装包正文保存到 Cloudflare R2，D1 的 `software_releases` 只保存每个平台唯一的
  `version_tag` 当前指针，禁止把安装包 BLOB 写入 D1。
- `version_tag` 就是该平台唯一对外软件版本和下一次 QR_V1 的上一版本；R2 object key 与 D1
  写入结果只是本次原生事务的内部发布回执，禁止另建 deployment 版本体系。
- 三个平台完全独立，稳定状态下每个平台只保留一个正式 R2 对象，总数最多三个。新包上传、
  D1 指针原子切换和正式域名公开下载校验全部成功后才删除该平台旧包。
- 任一步失败都恢复该平台旧 D1 指针并删除新包；发布记录只允许成功或失败，不生成第三状态。
- 下载入口固定为 `https://download.tuyulove.com/macos`、`/linux`、`/windows`，内容由
  TuyuServe 从 R2 流式返回，支持 HEAD、Range、ETag，禁止客户端取得 R2 凭据。

#### 2026-08-25 independent business runtime correction

Step 2 supersedes every earlier statement that Kamra and URY share one Frappe site or the `module_kamra` Schema.

| Business module | Site/process | Schema | Role | HTTPS port |
| --- | --- | --- | --- | --- |
| Hotel/Kamra | `hotel.localhost` | `module_kamra` | `tuyu_kamra_app` | `58443` |
| Restaurant/URY | `restaurant.localhost` | `module_ury` | `tuyu_ury_app` | `58450` |
| Tour/Voyant | independent Node process group | `module_voyant` | `tuyu_voyant_app` | `58444` |
| Ticket/Hi.Events | independent PHP/Node process group | `module_hi_events` | `tuyu_hi_events_app` | `58446` |

The single installer may package shared immutable language and framework resources. Mutable sites, runtime working copies, configurations, logs, processes, employee accounts, migrations and business data are isolated. `BusinessRuntimeManager` records `PAYLOAD_MISSING` or `FAILED` per module without converting an otherwise healthy core into a global startup failure. The desktop shell consumes explicit module origins and no longer calculates ports from the Kamra address.

Current verification truth: fork source and PostgreSQL contract are verified; packaged runtime and macOS end-to-end behavior remain pending.

##### Step 2 verification record

- Native Rust: 21 tests passed, including real local PostgreSQL migrations, administrator identity audit, four unique module boundaries and per-module missing-payload isolation.
- Module contracts: 16 tests passed across module registry, Kamra/URY, Voyant and Hi.Events.
- Flutter desktop: 14 tests passed.
- Business-runtime Python sources compile successfully without writing cache artifacts.
- macOS and LinuxARM (`aarch64/arm64`) shell packaging contracts pass syntax validation.
- Windows was not executed on real hardware, in accordance with the confirmed test scope.

These results verify the framework and static integration contracts tuyu. They do not change `runtime = pending` or `e2e = pending` for any upstream module.

#### 2026-08-26 第3步：macOS四子系统真实运行件

- macOS本地业务运行件由源码生成，包含Python 3.14.3、受控唯一Node、PHP 8.4.24、Nginx 1.30.4和OpenSSL 3.6.3；商家电脑运行时不下载依赖。
- 酒店使用独立`hotel.localhost`站点、`module_kamra` Schema与`tuyu_kamra_app`角色；餐厅使用独立`restaurant.localhost`站点、`module_ury` Schema与`tuyu_ury_app`角色。
- Kamra与URY只共享安装包内只读的Frappe App源码和浏览器资源。两个站点目录、配置、日志、迁移状态、进程、员工账户及业务数据均位于各自模块数据目录。
- Frappe、ERPNext、HRMS浏览器资源在可信构建阶段按锁文件生成；Kamra与URY使用各自Fork已提交的公开资源。安装包要求存在`bench/sites/assets/assets.json`，缺失时模块拒绝启动，不允许运行时联网补装。
- Frappe构建依赖、`.git`元数据和中间CSS在物化前清除。固定的`air-datepicker`版本改用同一Commit的GitHub HTTPS源码归档，不改变上游功能。
- Frappe静态资源和动态应用由同一个Gunicorn TLS进程、同一个HTTPS端口提供，不增加内部HTTP端口。PostgreSQL后台队列保留Frappe的立即执行、提交后入队和异步入队语义，调度参数不会传给业务函数。
- Voyant使用独立`module_voyant` Schema与本地workerd进程组；Hi.Events使用独立`module_hi_events` Schema与PHP-FPM、Nginx、SSR及队列进程组。四个模块都只暴露各自HTTPS入口。
- 本步验证覆盖真实单PostgreSQL数据库迁移、四Schema隔离、Frappe站点启动、Voyant迁移和服务、Hi.Events完整迁移和服务、TLS入口、运行件搬移以及Native/Flutter/脚本测试。Windows真机不在本机测试范围，完整业务交易流程仍需后续逐模块验收。

#### 2026-08-26 第4步：四子系统核心业务闭环验收

- Kamra验收直接执行上游住宿预订、价格、库存冲突与取消流程，并通过真实`Property`、`POS Outlet`、`Menu Item`和`POS Order`模型完成酒店餐厅菜单及餐饮订单。
- URY验收直接执行上游真实数据库P0/P1开班、检查表、KOT与交班流程，并通过真实`URY Restaurant`、`URY Room`、`URY Table`、`URY Menu`和`POS Invoice`完成独立餐厅点餐。
- Voyant验收直接执行上游Hono产品、行程、档期、名额和预订路由的PostgreSQL集成测试，数据库连接固定到`tuyu_voyant_app`和`module_voyant`。
- Hi.Events验收通过上游`CreateOrganizerHandler`、`CreateEventHandler`、`CreateProductHandler`及公开订单API完成活动、免费票种、订单和参与者闭环，不接入外部支付。
- 四套验收只调用上游业务模型、处理器或公开路由，不创建替代业务表，不修改上游业务逻辑。所有数据只进入各模块Schema，验收结束后删除临时数据库和运行目录。
- Voyant Cloud邮件、短信、跨币种汇率、语义检索和云PDF仍属于可选扩展，不是本地核心业务验收的依赖。

#### 第 4 步执行结果：四个上游子系统真实业务验收（2026-08-26）

状态：已完成。

##### 单数据库与 schema 边界

- 唯一业务数据库：`tuyubooking`，编码 `UTF8`，排序规则与字符分类均为 `C`。
- 酒店及酒店餐厅：`module_kamra`，所有 959 张表归 `tuyu_kamra_app` 所有。
- 独立餐厅：`module_ury`，所有 930 张表归 `tuyu_ury_app` 所有。
- 旅行团：`module_voyant`，所有 323 张表归 `tuyu_voyant_app` 所有。
- 票务：`module_hi_events`，所有 61 张表归 `tuyu_hi_events_app` 所有。
- 共享扩展位于 `tuyu_core`；`pg_trgm` 安装在 `tuyu_core`，不污染 `public`。
- `public` 中业务表数量为 0，`PUBLIC` 及四个模块角色均无 `public.CREATE` 权限。
- 每个模块角色仅拥有自身 schema 的 `USAGE`，对另外三个业务 schema 均无 `USAGE`。

##### 真实业务流程

- Kamra：真实执行房价、周末价格、儿童计费、房型互斥、取消费与信用券流程；随后创建酒店、酒店餐厅出口、菜单项和 POS 订单，结果通过。
- URY：真实收银员完成开班检查、POS Opening、检查单恢复与完成、KOT 可见性、关班发票查询；随后创建菜单、桌台和 POS Invoice，服务端覆盖客户端伪造的 cashier/owner/waiter，结果通过，订单总额为 136。
- Voyant：逐项执行产品、默认行程、班期、按选项单位库存、预留与 on-hold allocation、受 capability guard 保护的非员工状态变更，共 6 个场景，结果通过。
- Hi.Events：使用真实 Organizer/Event/Product handler 创建活动与免费票，通过当前 `/public/events/` 路由创建订单、会话和参会人；订单状态为 `COMPLETED`，结果通过，不触发支付。

##### PostgreSQL 兼容修复

- HRMS 员工预支款补丁将数值真值条件改为显式 `!= 0`，保持原状态规则不变。
- Kamra 的 `DATE_ADD`、`DATE_SUB` 全部改为等价 PostgreSQL 日期区间表达式；测试清理按外键顺序先删押金再删预订；取消信用券测试按实时取消费构造有效预付款。
- Frappe PostgreSQL 实时通知对超过 63 字节的频道名使用确定性 SHA-256 短频道映射，原始 room 仍保留在载荷中。
- ERPNext POS 关班使用 Frappe `CombineDatetime` 数据库映射，不再生成 MariaDB 专用 `TIMESTAMP(date,time)`。
- URY 在 `after_migrate` 幂等恢复跨应用 `Custom DocPerm`；修复 Sub POS Closing 的参数化状态条件；验收夹具使用 ERPNext 官方基础夹具并动态创建当前会计年度。
- Voyant 补齐迁移登记、产品字段对齐和 schema 对象所有权转移，关联序列由表所有权统一管理。
- Hi.Events 固定应用搜索路径为 `module_hi_events,tuyu_core,pg_catalog`，生产依赖下的独立 Laravel 验收入口不依赖 PHPUnit/Pest。

##### 自动化验证

- `test/frappe_postgresql`：15 项测试通过。
- `test/voyant_postgresql`：5 项测试通过。
- `test/hi_events_postgresql`：6 项测试通过。
- 14 个修改过的 Python 文件通过 AST 语法检查；Hi.Events 验收与数据库配置通过 PHP 语法检查；Voyant 验收入口通过 Node 语法检查。
- `scripts/business-runtime/runtime.lock.json` 的 `macos_runtime.e2e_verified` 保持为 `true`。
- 本机仅使用 macOS 原生进程完成验收；未引入 Docker、Podman、Linux Guest 或虚拟机依赖。

#### 第 5 步：统一桌面运行入口与独立故障边界（2026-08-26）

状态：已完成。

- Flutter 桌面首页固定呈现酒店及酒店餐厅、独立餐厅、旅行团活动、活动票务四个入口，不提供模块下载安装或产品拆包。
- Native FFI 合同升级为版本 2，新增全量运行快照查询和指定模块重启；请求只携带稳定模块标识，不传递数据库密码或业务凭据。
- `BusinessRuntimeManager` 只停止并重新启动目标模块进程组，共享 PostgreSQL 和其他三个模块保持运行；模块数据、schema、角色、日志和 HTTPS 端口不发生迁移。
- 每五秒刷新一次模块子进程与其已配置 HTTPS 监听端口状态。监听不可达时模块进入 `DEGRADED`、停止向 Flutter 暴露入口；恢复后自动回到 `READY`。
- `PAYLOAD_MISSING` 与 `DISABLED` 不伪装成可重启故障；`FAILED`、`DEGRADED` 与 `STOPPED` 可从统一桌面入口单独重启。
- 本步骤不修改四个上游业务逻辑，不增加 HTTP 服务、Docker、Podman、Linux Guest、虚拟机、第二数据库或 TuyuFactory。

##### 第 5 步验证记录

- Native Rust 23 项测试全部通过，覆盖真实 PostgreSQL、四模块独立状态、单模块重启及 FFI 版本 2 合同。
- Flutter 桌面 15 项测试全部通过，覆盖四入口统一呈现、故障模块独立重启、中英文和 HTTPS 管理入口约束。
- Rust 格式检查、Dart 格式化和中英文 ARB JSON 校验通过。
- 本机使用 `arm64` 从源码完成 macOS Release 编译；现行主机端产物直接覆盖
  `/Users/rhett/tuyubooking/target/host-macos/TuyuBookingHost.app`，不在产品目录保留编译输出。
- 本机未执行 Linux 或 Windows 真机构建；未引入 Docker、Podman、Linux Guest、虚拟机或第二数据库。

#### 2026-08-26 macOS 完整 Release 实现结果

##### 已落地架构

- 一个 `tuyubooking.app`、一个 Rust 原生运行时、一个 PostgreSQL 17.11 实例、四个独立业务子系统。
- 酒店及酒店餐厅使用 Kamra，独立餐厅使用 URY，旅行团活动使用 Voyant，票务使用 Hi.Events。
- 上游源码在 Release 阶段构建并封装，途遇只维护统一启动、身份交接、数据库隔离、HTTPS 和打包兼容层，不重写上游预订、房间、菜单、活动或票务业务逻辑。
- 数据库使用 `tuyu_core`、`module_kamra`、`module_ury`、`module_voyant`、`module_hi_events` 五个 Schema；业务模块使用各自数据库角色。
- PostgreSQL 禁止 TCP 监听，仅通过权限为 `0700` 的短 Unix Socket `/tmp/tuyubooking-pg-<pid>` 访问，规避 macOS Socket 路径长度限制。
- Kamra 和 URY 的 Frappe PostgreSQL 主连接及途遇队列/缓存后端均优先使用同一个 Unix Socket。
- 商家运行时禁止网络安装和依赖下载；Python 子进程设置 `PYTHONDONTWRITEBYTECODE=1`，不得改写签名安装目录。

##### 固定运行时

- Python 3.14.3
- Node.js版本以受控工具库唯一登记为准；本轮尚未完成新运行包验收。
- PHP 8.4.24
- Nginx 1.30.4
- PostgreSQL 17.11

这些运行时及其原生依赖在 Release 阶段完成源码构建、重定位、资源清单和嵌套签名。严格校验拒绝 Homebrew 路径、构建临时目录和其他非系统绝对 Mach-O 依赖。

##### 安全与服务边界

- TuyuBooking 使用 Hardened Runtime 直接分发配置，不启用 App Sandbox，因为 PostgreSQL 需要 System V IPC；数据库仍只监听私有 Unix Socket。
- 本机开发包使用 ad-hoc 签名和仅限本机验证的 `disable-library-validation`；正式发布仍需 Developer ID 签名与公证。
- TuyuServe 的唯一编译来源为 `https://serve.tuyulove.com`，仅负责途遇号身份、设备签名校验、商家控制关系和发布控制面，不托管商家本地业务运行时。
- 四个本机业务入口均为 HTTPS；Hi.Events 生产 SSR 不静态加载仅构建期需要的 Vite。

##### 启动与验证基线

- 上游子进程崩溃仍立即失败；考虑 ERPNext 首次 DocType 迁移，单模块首次启动等待上限为 600 秒。
- 完整打包烟雾测试总上限为 900 秒，超时会保留并打印各模块现场日志。
- Flutter 测试：29 项通过。
- Rust 测试：24 项通过。
- 严格 macOS 包校验：通过。
- 真实签名应用验证：四模块冷启动、四个 HTTPS 入口、Hi.Events 单模块重启、整套停止与重启、PostgreSQL 数据持久化全部通过。
- 启动后的 sealed resource 再校验：通过，运行时没有改写 `.app`。
- 当前真实最低系统版本：macOS 26.0。

#### 2026-08-26 塔塔控制台本机 macOS 编译入口

- `塔塔控制台 -> 途遇 -> 商家端 -> 编译 macOS` 必须调用 `scripts/macos/build_release.sh`，不得以裸 `flutter build macos` 和独立 Rust 编译代替完整打包。
- 该入口固定将 `https://serve.tuyulove.com` 编译为 TuyuServe 来源，随后完成运行时源码构建、Flutter 与 Rust 测试、四子系统封装、签名、严格包校验、真实 HTTPS 冒烟测试、重启及持久化验证。
- 完整流程在 TataConsole 单次 `tuyubooking/target/host-macos/` 内构建并验收，成功后覆盖
  `/Users/rhett/tuyubooking/target/host-macos/TuyuBookingHost.app`；相邻“启动”按钮只打开该最新成功产物。缺少原生动态库、PostgreSQL、业务运行时或资源清单的 Flutter 空壳不属于有效产物。
- 塔塔控制台冷启动只读取软件流程的本地 SQLite 镜像后开放本机动作；GitHub 记录仅由页面显式刷新和远端任务闭合更新，不得让远端请求占住串行 Worker 通道并锁住 TuyuBooking 本机编译入口。
- 完整源码构建的详细输出写入单次临时日志，塔塔控制台只接收 30 秒心跳和有界结果摘要；失败保留末尾 200 行、成功保留末尾 80 行，任务退出时清理临时日志，避免海量编译输出压垮原生塔塔控制台。
- TuyuBooking 不生成、保存、读取或使用用户 sr25519 私钥，也不存在桌面端设备签名器。私钥只保存在途遇旅行，用户扫码后在本地签名；商家端只接收签名凭证、验证挑战并建立内存会话。
- PostgreSQL、Kamra 和 URY 的机器内部引导凭据不是用户账户，由程序在应用数据目录内部自动生成并保护，不使用 macOS Keychain、不显示给商家，也不得写入日志或错误界面。登录会话不跨应用重启持久化。
- 本机无开发描述文件时，Xcode 内层构建显式清空 App entitlement，仅负责生成 Flutter 嵌套签名结构；最终整包签名统一使用不含受限共享权限的 `Release.entitlements`，严格包校验会拒绝意外携带 `keychain-access-groups` 的产物，避免临时签名被 macOS AMFI 强制终止。
- 每个业务模块监督器在 macOS/Linux 使用独立进程组；停止、重启、失败和冒烟退出先发送 `SIGTERM`，给监督器 12 秒逐个停止并回收 Gunicorn、Nitro、PHP-FPM、Nginx、Node、队列和 HTTPS 代理，超时后才以 `SIGKILL` 兜底，避免会自行建立进程组的 PHP-FPM 成为孤儿进程。打包冒烟失败会同时返回四个模块各自的状态和错误，不再只报告笼统的统一运行时未就绪。
- macOS 正式商家数据使用系统标准 `Application Support` 目录。Frappe 集成层解析不可变 App 源码软链接后再构造 `PYTHONPATH`，Hi.Events 集成层为 Nginx 与 PHP-FPM 的文件路径生成带引号配置；Release 冷启动冒烟固定使用含空格的临时目录，同时验证酒店、餐厅、旅行团和票务在真实 macOS 路径语义下均可启动。
- 桌面 App 通过 Flutter `AppLifecycleListener.onExitRequested` 接管可取消的系统退出请求，先等待统一运行时停止 PostgreSQL 和全部模块监督器，再允许 macOS、Windows 或 Linux 主进程退出；`onDetach` 与 Widget 销毁仅作为幂等兜底，不得依赖未等待的异步回调完成桌面清理。

#### 2026-08-26 PostgreSQL 热启动与扫码私钥边界修正

- `PostgresRuntime.initialize` 在检查 `PG_VERSION` 前恢复数据、日志和进程级 Unix Socket 目录，已有数据库不再跳过 Socket 初始化；Unix Socket 目录权限固定为 `0700`。
- macOS/Linux 的内嵌 PostgreSQL 禁止 TCP 监听，并只在上述私有 Unix Socket 内使用操作系统账户边界认证。Windows 的回环 TCP 认证保持独立内部凭据方案。
- 桌面端删除本地 sr25519 私钥签名器。`AuthController` 只接受由途遇旅行产生的外部签名证明，TuyuBooking 只验证证明并把已验证会话交给 Native。
- TuyuBooking 只持久化非秘密的设备标识和商家端安装实例标识；服务端会话保留在内存中，应用退出后必须重新扫码。
- Native 已建立二维码挑战和外部签名证明验证边界。初始化和后续登录统一由主机显示 `TUYU v1` 挑战二维码，手机钱包扫码并使用本地 sr25519 私钥签名，再由主机应用相机扫描响应二维码。管理员扫码流程不使用 USB、蓝牙或局域网 HTTPS 回传。

#### 2026-08-27 本机管理员初始化与生命周期

- 首次安装不注册途遇号。主机生成一次性 `TUYU v1` 初始化挑战，手机钱包签名后返回包含签名者公钥的响应二维码；本机验签成功后写入第一名管理员并立即建立内存会话。
- 管理员数据仅包含不可变公钥、可选姓名、`active`/`disabled` 状态和本机审计字段。数据库触发器拒绝修改公钥或所属安装实例，Native 和 FFI 均不存在公钥修改接口。
- 初始化完成后，新增、改名、停用、启用和删除都要求当前启用管理员会话。所有管理员权限相等，最多 99 名，并始终至少保留 1 名启用管理员。
- 删除会物理移除管理员记录，但目标公钥指纹、操作者公钥指纹、动作和时间继续保存在审计表；停用保留管理员记录但禁止登录。
- 管理员停用或删除本人时，只有另有启用管理员才允许操作，提交成功后当前会话立即失效。
- 初始化响应必须匹配当前挑战的请求编号和过期时间，并通过 `TUYU v1` 结构校验与 sr25519 验签；未知字段、错误请求、过期挑战、非规范公钥和无效签名全部拒绝。
- 账户始终只有两类：本机 sr25519 管理员和四个上游系统原有员工账户。本步骤不修改 Kamra、URY、Voyant、Hi.Events 的员工、岗位、角色或业务权限。
- 管理员策略、数据库访问、会话、扫码验签和断言的唯一实现已归属
  `tuyuserve/account/`；途遇商家端只保留调用该模块的薄适配和 FFI，不保留第二套实现。
- 本机管理员记录继续保存在本商家的 `tuyu_core`，会话继续只存在于本机进程；代码归属调整不把
  本机管理员上传到 TuyuServe，也不允许云端账户权限覆盖本机权限。

#### 2026-08-27 三桌面端统一管理员界面（第 2 步）

##### 实现范围

- 同一套 Flutter + Rust 途遇商家端代码在该历史步骤覆盖 `macOS`、`LinuxARM`、`Windows`，对应架构为 Apple `arm64`、Linux `aarch64/arm64`、Windows `x86_64`；平台不拆成多套业务源码。控制台层按完整tuyubooking产品内host/client实际平台建立三维流程身份。
- 三个平台均接入本机管理员初始化、二维码签名登录、管理员列表、新增、姓名修改、启停和删除界面。
- 首次初始化和管理员登录使用同一光学往返模型：主机显示挑战二维码，手机或公民钱包签名后显示响应二维码，再由主机摄像头识别并在本机验签。
- 途遇商家端不生成、不保存、不读取管理员私钥，也不使用 USB、蓝牙或局域网回传签名。
- 管理员公钥不可修改；已登录管理员可以新增、启停、删除管理员以及修改管理员姓名。管理员最多 99 个，至少保留 1 个有效管理员。
- 删除早期途遇号远程认证、服务端登录令牌和本机安全存储会话路径；管理员身份与会话只由本机 Rust 核心验证和管理。

##### 跨平台扫码技术

- `flutter_lite_camera` 提供 macOS、Linux、Windows 原生摄像头枚举、纹理预览和 RGB 帧读取；Flutter 只维护一套扫码界面。
- `zxing2` 在本机完成二维码生成和 RGB 帧解码，二维码内容不发送到外部服务。
- macOS 声明摄像头用途和沙箱摄像头权限；Linux 使用 V4L2；Windows 使用 Media Foundation。
- 相机插件及二维码库随各平台安装包统一编译和打包，商家无需单独安装运行时服务。

##### 构建边界

- 本机开发环境只编译和启动 macOS 版本。
- LinuxARM（`aarch64/arm64`）与 Windows（`x86_64`）使用相同 Dart/Rust 接口、平台工程配置和契约测试，由各自平台的 CI/Release 环境产出安装包。
- 第 2 步不执行 Release 构建，也不在 macOS 上伪造 Linux 或 Windows 真机编译。
- 第 2 步 Flutter 测试共 38 项通过，覆盖管理员初始化、二维码登录、管理员生命周期、中英文、三桌面相机边界和既有四子系统契约。

#### 2026-08-28 管理员初始化同屏扫码界面

- 初始化页在挑战生成后同时显示两个等宽区域：左侧为 `TUYU v1` 初始化挑战二维码，右侧为自动启动的本机摄像头，不再要求用户点击按钮打开第二个扫描弹窗。
- 手机钱包扫描左侧挑战并在手机本地完成 sr25519 签名，随后把响应二维码展示给右侧摄像头；主机识别后立即停止摄像头并交由 Native 完成本机验签和第一名管理员写入。
- 摄像头帧与二维码内容只在 TuyuBooking 当前进程内处理，不保存、不上传，也不通过局域网、USB 或蓝牙回传。途遇商家端不生成、读取或保存管理员私钥。
- 桌面扫码弹窗和初始化内嵌扫码共用同一个 `DesktopQrScannerPane` 设备实现，避免重复管理摄像头；`macOS`、`LinuxARM`、`Windows` 继续使用同一 Flutter 代码，对应机器架构仍由各平台构建字段表达。
- 初始化文案遵循设备语言主显示、另一种语言小字号辅助显示；中文和英文均说明请求扫描、响应扫描及私钥边界。

#### 2026-08-27 本机管理员统一接管四子系统（第 3 步）

##### 最终身份边界

- TuyuBooking 不再通过途遇号、TuyuServe 身份会话、设备身份或商家角色创建上游管理员凭证。
- 当前已验证的本机管理员 UUID 与 sr25519 公钥指纹，是 Kamra、URY、Voyant、Hi.Events 管理员桥的全部身份依据。
- 四个上游系统继续保留自己的员工、岗位和业务权限体系；管理员桥只提供途遇商家端系统管理员进入上游管理界面的技术入口，不要求商家另建四套管理员。
- 管理员断言为 256 位随机令牌，数据库只保存 SHA-256 摘要，有效期 60 秒且只能消费一次；原始令牌只放在本机 HTTPS 页面 URL Fragment 中。
- 上游会话每次访问都联查本机管理员仍为 `active`。管理员被停用时，在同一 PostgreSQL 事务内撤销其未消费断言和全部上游会话；删除管理员时由外键级联清除短期凭证。

##### 开发期数据库规则

- 项目尚未发布，不建立升级兼容迁移，不保留早期管理员桥字段。
- 数据库只有一个最终结构脚本 `host/database/tuyu_core.sql`，通过 `schema_state` 只登记当前 `tuyu_core` 基线；禁止版本化增量脚本。
- 管理员桥表直接使用 `installation_id`、`administrator_id`、`administrator_public_key_fingerprint` 和本机会话有效期，彻底移除该桥中的 `tuyu_id`、`signer_id`、`device_id`、`merchant_role` 等早期字段。

##### 上游适配

- Kamra 与 URY 共用 Frappe 管理员桥，但保持两个独立站点、Schema、员工账户和业务数据。
- Voyant TypeScript 桥和 Hi.Events PHP 桥使用相同的一次性消费与有效管理员校验规则。
- 修改只发生在途遇适配层，不改变上游房间、菜单、旅行团、票务、订单或员工权限逻辑。

##### 验证结果

- Native Rust 测试 39 项全部通过。
- Flutter 测试 38 项全部通过。
- 唯一初始化脚本校验和、真实本机 PostgreSQL 执行、管理员停用撤销、二维码登录和三套上游桥静态契约全部通过。
- 本步骤未执行 Release 构建。

#### 2026-08-27 Voyant 受控编译目录修正

- Voyant 的 Nitro 服务端、迁移入口和迁移资源统一编译到 调用方提供的规范源码外绝对工作目录 `TUYUBOOKING_WORK_DIR/voyant`。
- TuyuBooking 产品源码目录不再创建 `upstream/voyant/templates/operator/.output`；业务运行时只从受控工作目录读取 Voyant 产物并封装进最终 App。
- `build_macos.sh` 缺少 `TUYU_VOYANT_OUTPUT_DIR` 时立即失败，禁止回退到产品目录。
- 最终安装包内部继续使用 `voyant/operator/.output` 运行时布局；这是 App 包内路径，不是源码编译目录。

#### 2026-08-27 macOS 受控 Release 构建完成

- 塔塔控制台主机端产物路径为
  `/Users/rhett/tuyubooking/target/host-macos/TuyuBookingHost.app`；产品目录不保存编译目录，TataConsole 临时工作目录在任务结束后清理。
- Voyant 的 Nitro Node 服务、迁移程序和迁移文件由 `TUYU_VOYANT_OUTPUT_DIR` 直接写入 TataConsole 受控工作目录；导入源码目录禁止产生或保留 `.output`。
- macOS Runner、CocoaPods、PostgreSQL、Python 及业务运行时统一声明 macOS 26.0 最低版本，避免生成依赖仍使用模板默认 10.15。
- Frappe、ERPNext、HRMS、Kamra、URY 及生成资产通过确定性的 `rsync -a --delete` 物化到 App；`assets.json`、上游运行时、许可证、SBOM 和清单继续逐项强制验证。
- macOS 与 Linux 安装包验证均不再要求 `tuyubooking_sr25519_sign`。途遇商家端只验证扫码签名，不生成、读取、保存管理员私钥，也不提供本地私钥签名 FFI。
- 打包烟雾测试以同一 `installation.id` 在完全停止和重新启动前后保持一致来验证 PostgreSQL 持久化，不再以错误的“安装记录数增加”作为依据。
- 完整 TataConsole Release 已通过 Flutter 测试、Rust workspace 测试、ARM64/动态依赖/清单/代码签名静态验证，以及签名 App 冷启动、四模块局域 HTTPS、模块重启和 PostgreSQL 持久化烟雾测试。
- 最终 App 已由塔塔控制台发布并启动。
#### 2026-08-27 第 5 步：局域网 HTTPS 员工接入网关

TuyuBooking 三个桌面主机端现在通过同一 Native Runtime 管理一个默认停用的局域网 HTTPS 网关。管理员扫码签名登录后可以启用或停用网关；启用时只发布当前运行正常的酒店、餐厅、旅行团和票务路径，停用后不监听局域网端口。四个上游子系统和 PostgreSQL 继续只允许本机访问。

员工手机和平板通过 `_tuyubooking._tcp.local` 自动发现同一局域网内的主机，不使用连接二维码。第一次连接只访问无凭据状态接口并记录主机实例 ID 与证书 SHA-256 指纹，后续证书变化时拒绝连接。TLS 服务私钥是安装实例的 HTTPS 密钥，不属于任何管理员身份。

本步骤不建立统一员工账户。浏览器及后续同一 Flutter 工程生成的 iOS（iPhone/iPad）与 Android（手机/平板）员工模式，仍使用 Kamra、URY、Voyant、Hi.Events 原有员工账户和权限。网关只统一安全入口、路由和连接发现，不改变四个上游系统的业务权威。

#### 2026-08-27 第 6 步：手机和平板员工模式基础框架

同一 TuyuBooking Flutter 工程新增 iOS（iPhone/iPad）与 Android（手机/平板）目标。移动端不构造 FFI、PostgreSQL 或四个本机业务运行时；移动端作为完整 TuyuBooking Mobile 使用正式 CitizenSDK，并同时提供商家业务入口；桌面端继续作为商家唯一主机运行完整系统。

主机通过 `_tuyubooking._tcp.local` 广播安装实例 ID、商家名称、HTTPS 端口和协议版本。员工设备与主机位于同一局域网时自动发现：只有一台主机时自动连接，发现多台主机时由员工选择。

首次连接只访问 `/tuyu/status`，使用 TLS 证书 DER 的 SHA-256 指纹与状态响应共同确认实例后保存本机信任；后续证书发生变化时直接拒绝连接。移动端不使用二维码连接局域网主机；移动端使用 CitizenSDK 钱包完成 sr25519 本地签名，并可为桌面主机管理员登录提供光学二维码响应。

当前员工模式已完成主机发现、证书固定、可信主机保存和酒店、餐厅、旅行团活动、票务四个模块入口。Kamra、URY、Voyant、Hi.Events 的员工账户适配与业务操作前端属于下一步，本步骤不伪造统一登录接口，也不复制上游员工账户。

#### 2026-08-27 第 7 步：上游员工账户登录适配

TuyuBooking 员工模式直接适配四个上游系统的原生账户协议，不创建统一员工账户：Kamra 和 URY 分别使用各自 Frappe 站点的 `/api/method/login` Cookie 会话，Voyant 使用 Better Auth 邮箱密码 Cookie 会话，Hi.Events 使用其原生 JWT 会话。四类会话按业务模块隔离，密码不写入磁盘、不记录日志，App 关闭或员工退出后释放会话。

全部认证请求只通过已经完成证书 SHA-256 固定的商家主机局域网 HTTPS 网关发送。TuyuBooking 不修改四个上游系统的员工、岗位和权限数据，也不把员工账户上传到 TuyuServe。

员工发现、模块选择、登录和会话页面统一同时显示中文与英文。设备语言为中文时中文作为大字主文案、英文作为小字辅助文案；设备语言为英文时顺序相反。商家名称、员工姓名等业务数据保持原值，不进行机器翻译。

本步骤完成账户认证与安全会话基础。酒店前台、餐厅点餐收银、旅行团操作和票务核销等统一 Flutter 业务页面按后续模块步骤接入，并复用本步骤建立的原生上游权限。

#### 2026-08-27 第 8 步：餐厅员工点餐基础功能

TuyuBooking 员工模式新增自有 Flutter 餐厅前端，通过第 7 步建立的 URY Frappe 员工会话调用 URY 原生接口。启动时读取员工可用 POS Profile、默认顾客、菜单分类、实时菜品、房间和桌台；支持外带、堂食、桌台、用餐人数、菜品规格、加料、备注、数量、购物车和订单提交。

Flutter 不计算最终业务价格、不创建独立订单表，也不复制 URY 权限。订单通过 `ury.ury.doctype.ury_order.ury_order.sync_order` 提交，URY 服务端继续校验默认顾客、员工角色、分店、房间、桌台、POS Profile、订单状态和并发版本，并由原有 POS Invoice 作为订单权威。

菜品规格和加料读取 Item 文档现有的 `custom_pos_item_variants` 与 `custom_pos_add_on_items`，并使用实时菜单中的上游价格。员工 Cookie、CSRF 和购物车仅存在于当前 App 进程；Frappe CSRF 校验保持启用。

手机使用菜单加底部购物车入口，平板和宽屏使用订单上下文、菜单、购物车三栏布局。所有 TuyuBooking 自有操作文案继续按设备语言使用中文/英文大字主显示与另一语言小字辅助显示；菜品、房间和桌台名称保持商家原文。

#### 2026-08-27 第 9 步：餐厅订单与收银闭环

餐厅员工前端可以进入占用桌台并通过 URY `get_order_invoice` 加载原 POS Invoice，继续加菜时携带订单编号和 `modified` 时间再次调用 `sync_order`。并发修改、已结账订单、跨员工桌台权限和房间权限仍由 URY 服务端拒绝，Flutter 不覆盖上游判断。

订单中心通过 URY `getPosInvoice` 展示草稿、未结账和最近支付订单，并通过 `getPosInvoiceItems` 恢复订单行。订单保存后才能收银，有未保存修改时禁止直接结账。

收银页面读取当前 POS Profile `payments` 子表，只显示商家已配置的支付方式，支持多个支付方式拆分金额。Flutter 不实现银行卡、微信、支付宝或公民币渠道本身，只把 `{mode_of_payment, amount}` 交给 URY `make_invoice`；支付渠道的实际处理仍属于商家配置和上游业务。

每次结账前调用 ERPNext `check_opening_entry` 验证当前员工 POS Opening。没有开班、金额不足、权限不足或订单状态冲突时失败关闭，不调用 `make_invoice`，也不绕过 URY 的开班、清单、日结和角色门禁。

#### 2026-08-27 第 10 步：Kamra 酒店员工前台基础能力

酒店员工会话进入 TuyuBooking 自有 Flutter 前台界面，继续使用 Kamra 原生员工账户、Cookie、CSRF 与权限。物业、今日抵达、今日离店、在住、实时房态、房价、客房清洁状态均通过 Kamra 现有白名单接口读取，TuyuBooking 不复制酒店库存或订单数据库。

新建预订、办理入住、办理退房和更新客房清洁状态全部提交给 Kamra，由 Kamra 执行最终权限、库存及状态流转校验。员工界面同时显示中文和英文；设备语言为中文时中文为主、英文为辅，设备语言为英文时英文为主、中文为辅。

本步骤不修改 Kamra 上游业务逻辑，不建立第二套酒店员工账户、价格规则或预订状态机。

#### 2026-08-27 第 11 步：Voyant 旅行团活动员工端

旅行团活动员工会话进入 TuyuBooking 自有 Flutter 运营界面，继续使用 Voyant Better Auth 原生员工会话、租户范围和权限。旅行产品、近期团期、可售人数、预订、预订项目和旅客资料均通过 Voyant 现有合同读取，TuyuBooking 不建立旅行团业务数据库。

员工端可以筛选团期与预订、查看预订详情和旅客名单，并按 Voyant 原生 `bookings:write` 权限提交确认或取消。`HTTP 202` 明确显示为等待审批，不得作为已完成状态；`401`、`403`、`409` 和 `422` 分别保持会话、权限及业务冲突边界。

本步骤不修改 Voyant 上游源码，不虚构统一团员签到，不加入产品编辑、复杂预订创建、支付、退款或资源调度。上述管理功能继续由 Voyant 原有浏览器界面提供。

#### 2026-08-27 第 12 步：Hi.Events 票务员工端

票务员工会话进入 TuyuBooking 自有 Flutter 核销界面，继续使用 Hi.Events 原生 JWT 员工会话和事件授权。活动、活动核销统计、参与者、票券及签到状态均从 Hi.Events 实时读取，TuyuBooking 不建立第二套票务或核销数据库。

员工可以选择活动、搜索参与者、查看票券详情，并通过手工操作或摄像头扫描 Hi.Events 原生票券二维码执行签到和签出。票面短 ID 必须先通过原生参与者查询解析为 `public_id`，最终调用 Hi.Events `check_in` 合同；取消票、未付款票、重复签到、权限不足及状态冲突均保持上游判断。

iOS 和 Android 使用 `mobile_scanner` 扫描业务票券，macOS、Linux 和 Windows 继续使用现有 `flutter_lite_camera` 与 `zxing2`。业务票券二维码只承载票券标识，不用于员工登录或局域网主机连接。本步骤不修改 `upstream/hi_events` 上游源码。

#### 2026-08-27 统一途遇 Logo 来源

本产品使用的应用图标、启动 Logo、页面 Logo 或网站 Logo 均来自 `/Users/rhett/tuyuserve/logo/`。产品目录中的资源是平台打包副本，不是独立真源；必须通过该目录的生成器更新，并通过统一资产清单测试。

#### 2026-08-27 第 13.1 步：真实产品源码编译边界

TuyuBooking 本机 Release 不复制源码，直接读取产品根目录下的 `app/`、`host/`、`scripts/` 和 `upstream/`。Flutter Build、Rust Target、Xcode DerivedData、PostgreSQL和四业务运行时的生成结果进入 `tuyubooking/target/host-macos/release/`，主机端最终成功安装包固定为 `tuyubooking/target/host-macos/TuyuBookingHost.app`。

TataConsole 动作已删除全部途遇 Flutter 源码快照入口，并在本机动作结束时清理 Flutter 工具缓存。Release 路径守卫拒绝产品根目录之外的源码和任何 `TATA_CONSOLE_CACHE_DIR/source` 回退。中文主显示、英文主显示和 macOS Release 路径契约共 7 项测试通过，Shell 语法通过；本步骤未执行完整 Release 编译。

#### 2026-08-27 第 13.2A 步：餐厅提交命名冲突修复

- 修复 `app/lib/mobile/restaurant/restaurant_cart_page.dart` 中提交按钮双语标签常量与 `_submit(BuildContext)` 提交方法同名造成的 Dart 编译冲突。
- 仅将标签常量重命名为 `_submitLabel`，保留提交方法、餐厅购物车流程、URY 上游业务逻辑和接口行为不变。
- 定向静态分析通过：`flutter analyze lib/features/employee_restaurant/restaurant_cart_page.dart` 无问题。
- 餐厅员工端定向测试通过：`flutter test test/features/employee_restaurant` 共 4 项测试通过。
- 2026-08-28 从塔塔控制台完成单次 macOS 完整 Release：76 项 Flutter 测试通过，Bundle、冷启动、局域网 HTTPS、重启与持久化验收通过；该产物现归档到主机端身份 `tuyubooking/target/host-macos/TuyuBookingHost.app`。默认 `1280 × 720`、最小 `1000 × 680` 的初始化窗口完整显示双语标题、管理员姓名、`224 × 224` 请求二维码与内嵌摄像头，无溢出。
- 管理员初始化页使用居中的“设置管理员 / Set up administrator”标题，不显示钱包说明长句。外层身份交换卡片最大宽度为 `700px`，请求二维码和签名摄像头外围卡片在桌面宽屏下固定为 `1:1`，内部扫码区继续保持 `224 × 224`。macOS 系统显示名称统一为 `TuyuBooking`，内部可执行文件名保持 `tuyubooking`。
- 本步骤未重复执行完整 macOS Release；完整编译必须在下一步骤经确认后仅执行一次。

#### 2026-08-27 第 13.2D 步：上游源码版本锁统一

- `tuyubooking.sources.json` 升级为 schema 3，以七个 tuyutata组织fork 的固定 Git commit 作为唯一版本真源。
- ERPNext、Frappe、HRMS 的锁定提交已与当时导入版本统一；Kamra、URY、Voyant、Hi.Events 保持各自固定提交。
- 删除归档导入阶段遗留的 `archive_sha256`、`tree_sha256`、`file_count` 字段，只维护来源仓库与导入提交这一套版本身份。
- `scripts/business-runtime/runtime.lock.json` 与来源清单使用同一组 Frappe Runtime提交，业务运行时不再持有第二套旧提交值。
- 来源门禁失败信息包含具体模块名，便于一次定位实际 HEAD 与固定 commit 的漂移；不修改任何上游业务功能逻辑。

#### 2026-08-27 第 13.2F 步：旧开发数据清理与安全启动诊断

- 已永久删除本机旧开发数据目录 `~/Library/Application Support/com.tuyulove.tuyubooking`，不为开发期旧数据库增加兼容或迁移逻辑。
- 现有正式包能够重新创建 PostgreSQL 17 唯一数据库，并完成 Kamra、URY、Voyant、Hi.Events 对应业务运行时的首次数据构建和 HTTPS 监听。
- 原生启动错误不再丢失错误类别：结构摘要不一致、初始化 SQL 失败和普通本地数据服务失败分别返回安全的中英文文案，但不暴露结构名称、数据库错误详情或凭据。
- Frappe 首次建站失败不再把包含数据库密码和管理员密码的完整命令参数写入日志；Release 冷启动门禁会扫描日志并拒绝任何敏感参数标记。
- 真实首次启动仍发现同步业务启动完成后界面未进入管理员初始化页；该状态同步问题不属于本步骤获批文件范围，将在下一步骤独立修复。

#### 2026-08-27 第 13.2G 步：按商家配置启动业务系统

- TuyuBooking 安装包继续包含 Kamra、URY、Voyant、Hi.Events，但安装包可用模块与本机启用模块已彻底分离。
- 首次管理员初始化后必须选择至少一个业务系统；核心 PostgreSQL 只保存酒店、餐厅、旅行团活动和票务四个布尔启用值。
- 每次启动只读取并启动本机已启用系统。未启用系统不创建进程、不监听端口、不初始化上游结构，也不进入员工局域网 HTTPS 路由。
- 业务系统首次初始化改为后台状态机，核心 PostgreSQL 就绪后立即进入管理员初始化、登录或主界面，不再串行等待所有上游 HTTPS 服务。
- 管理员后续只能启用或停用业务系统。停用只停止进程并关闭入口，系统不存在业务模块数据删除接口或界面。
- Flutter 主机端每两秒刷新启用模块状态；启动中不阻塞主界面，单个模块失败只将该模块标为失败。
- 本步骤不修改 Kamra、URY、Voyant、Hi.Events 的业务逻辑、员工账户、订单或业务数据。

#### 途遇账户签名协议 TUYU v1（2026-08-28）

- TuyuBooking 将复用 `tuyuserve/account` 中的途遇账户签名协议，不另建本机私有协议。
- 本机管理员登录使用 `LOCAL_ADMINISTRATOR_LOGIN`，授权依据仍是当前安装实例数据库保存的管理员公钥；私钥不进入、不保存于途遇商家端。
- 当前运行时仍使用旧 `QR_V1`，本阶段不混合解析 TUYU v1。下一实施步骤将一次性替换本机挑战、响应、验证和固定烟测账户。
- 管理员、员工和途遇服务端账户可使用相同账户公钥二维码格式，但必须通过 operation、audience 和 target 隔离签名，禁止跨场景重放。

#### TUYU v1 本机管理员登录切换完成（2026-08-28）

- TuyuBooking 本机管理员登录已从旧 `QR_V1` 完整切换为“途遇账户签名协议” `TUYU v1`，不保留兼容解析。
- 主机只生成绑定 `tuyubooking` audience、安装实例 target、毫秒级过期时间和 32 字节随机 nonce 的单次挑战；手机本地使用 sr25519 签名后，以响应二维码返回公钥和签名。
- 挑战不再预选第一名管理员。主机验签成功后，才根据响应公钥查询当前安装实例中的已启用管理员，因此任意已启用管理员均可登录。
- 登录挑战在首次响应时原子消费，错误、过期或重复响应均不能复用。TuyuBooking 不生成、读取、传输或保存管理员私钥。
- Flutter 与原生 FFI 合同版本提升为 `7`；二维码 JSON 使用小写 `0x` 十六进制，不再使用 Base64 登录字段。

#### TUYU v1 多管理员与篡改防护门禁（2026-08-28）

- 本机登录挑战不绑定管理员顺序。第二名及之后的任意已启用管理员均可使用自己的 sr25519 公钥和签名登录，已停用管理员始终拒绝。
- operation、audience、target、nonce、挑战 ID、到期时间和协议版本全部进入验证边界；任何二维码中间人篡改都会导致摘要或挑战匹配失败。
- Flutter 在调用原生 FFI 前先验证响应挑战 ID 与到期时间必须等于当前界面保存的挑战，原生层仍执行完整的独立验签和单次消费。
- 公钥和签名只接受固定长度的小写 `0x` 十六进制，未知字段、错误版本和非规范编码直接拒绝。

#### 2026-08-28 本机首次启动与签名初始化修复

- 首次安装不再接受公钥二维码直接登记首位管理员。主机先生成 `TUYU v1` 挑战，手机钱包本地完成 sr25519 签名，主机验证签名响应后才在同一 PostgreSQL 事务中登记首位管理员并创建会话。
- 初始化挑战与普通登录挑战在本机内存中具有不同用途；初始化响应不能登录，登录响应不能初始化，挑战在第一次提交时消费且不能重放。
- 核心 PostgreSQL 就绪后立即进入管理员初始化或登录页面。干净安装在管理员完成初始化并选择模块前，酒店、餐厅、旅行团和票务四个业务运行时全部保持停用。
- macOS 打包烟雾测试不再内嵌测试私钥或绕过初始化，只验证正式 App 内核心 PostgreSQL、安装实例持久性和首次安装零模块状态；签名初始化与模块启动由外部协议测试和 Native Runtime 测试验证。
- 原生 FFI 合同版本提升为 `8`，初始化输入只接受标准 `TUYU v1 kind=2` 签名响应和可选管理员姓名。

#### 2026-08-28 PostgreSQL 账户连接生命周期修复

- TuyuBooking 原生 FFI 只创建一个与桌面 App 同生命周期的 Tokio 多线程运行时；该运行时持续驱动唯一 PostgreSQL 连接，禁止启动完成后销毁 Reactor、继续保留失效客户端。
- 管理员状态、首次初始化、扫码登录、管理员维护、模块配置和员工网关账户断言全部复用该持久运行时，不再为每个 FFI 调用临时创建运行时。
- 停止顺序固定为停止员工网关、停止业务运行时与 PostgreSQL、最后释放 Tokio 运行时，避免子进程或连接驱动残留。
- macOS 正式安装包冷启动门禁在两次启动中均读取零管理员状态并生成标准 `TUYU v1` 初始化挑战；数据库进程存在但账户接口返回 `storage_unavailable` 时必须判定构建失败。

#### 2026-08-28 七端统一主题与桌面管理员签名界面

- 该历史步骤已实现的 `macOS`、`LinuxARM`、`Windows` 三个桌面主机端统一采用 1280×720 默认窗口和 1000×680 最小窗口；macOS 首次居中并保存用户后续窗口框架。
- 管理员初始化和登录共用同一个 Flutter 光学签名界面：左侧 224×224 TUYU 挑战二维码，右侧 224×224 本机摄像头。登录不再打开独立扫码弹窗。
- 初始化只比登录多一个可选管理员姓名字段。主界面文案精简为两步操作和一行私钥提示，设备语言为主文案，另一语言以小字号辅助。
- `macOS`、`LinuxARM`、`LinuxAMD`、`Windows`、`iOS`、`Android` 共用日出橙、途遇陶红、海湾青和沙滩米白主题。iPhone/iPad 属于 iOS，Android 手机/平板属于 Android；移动端包含钱包初始化、经营模式选择、管理员签名和员工业务功能，桌面端继续承担商家主机初始化与本机业务运行时。
- 摄像头帧与二维码仍只在当前进程处理，不保存、不上传；TUYU v1、sr25519、管理员数据库、员工账户及上游系统均未改变。

#### 2026-08-29 跨产品交易边界归并

- TuyuBooking 是酒店、餐厅、旅行社、景区和活动商家的唯一核心系统。三个桌面端以主机模式运行
  PostgreSQL 和业务运行时，四类手机/平板端只通过局域网 HTTPS Staff API 操作同一商家主机。
- TuyuLove 只能通过商家公开 HTTPS 端点查询实时报价和提交预订；TuyuServe 只保存签名摘要，
  不保存商家权威订单、库存、员工或业务数据库。
- 途遇商城是 TuyuBooking 内部 B2B 采购模块，不是独立产品或中心商城。它从 TuyuServe 搜索厂家
  摘要后，必须直接向 TuyuFactory 确认批发价、库存、起订量和交期。
- 采购方订单、收货、退货和采购成本归 TuyuBooking；厂家报价、销售订单、库存预留、发货和售后
  归 TuyuFactory。双方不共享数据库事务，写请求必须包含请求标识、幂等键、双方实例、有效期、
  载荷摘要与实例签名，状态按 `DRAFT → QUOTED → SUBMITTED → ACCEPTED → FULFILLING → SHIPPED → RECEIVED`
  推进，并允许从提交阶段进入 `REJECTED` 或 `CANCELLED`。
- 上游替换必须保持外部协议稳定，并通过行为等价、完整数据导出导入和恢复测试；不得直接删除
  仍承担权威业务的实现。

#### 2026-08-29 桌面端、移动端与共享源码目录重组

TuyuBooking 保持一个 Flutter 工程，产品工程目录由 desktop/ 更名为 app/。app/lib/desktop/ 只承载 `macOS`、`LinuxARM`、`LinuxAMD`、`Windows` 主机界面，app/lib/mobile/ 只承载 `iOS`（iPhone/iPad）与 `Android`（手机/平板）功能，app/lib/shared/ 只承载两端共同使用的二维码、安全网络、双语显示和基础类型。

原 lib/l10n/ 已由含义明确的 app/lib/shared/localization/ 取代。中英文资源位于 resources/，Flutter 生成文件位于 generated/，设备语言继续决定主文案，另一种语言以小字号辅助显示。l10n.yaml 仅保留为 Flutter 工具要求的配置文件名，不再作为源码目录名。

桌面本机 Rust 核心由 native/ 更名为 host/；唯一数据库结构归入 host/database/，PostgreSQL运行时由产品声明的固定官方归档提供，源码目录不保存原件或发行包。业务模块适配由 subsystems/ 更名为 modules/，四个上游及其框架依赖源码由 imported/ 更名为 upstream/，行为、领域和样例规格统一归入 specifications/。

本次只重组既有源码和测试，不创建空的钱包、设置或管理员移动端占位目录，不实现或复制 CitizenSDK 钱包能力。移动端通过正式 CitizenSDK 依赖使用钱包、sr25519 签名和公民链能力。

#### 2026-08-29 目录重组路径修复

目录重组后的桌面员工局域网网关管理功能归入 app/lib/desktop/infrastructure/lan_service/，移动端 employee_access/ 只保留上游员工登录、会话和权限适配。移动端不再引用桌面 Native、FFI 或桌面应用入口。

桌面端和移动端共同使用 app/lib/shared/localization/locale_policy.dart 决定中文、英文主语言，消除了移动端对 desktop_app.dart 的反向依赖。测试、打包脚本和 TataConsole 契约统一使用 app、host、upstream 新路径；PostgreSQL物化、编译和临时产物只位于所属Build工作目录，产品源码不保留host/runtime原件目录。

#### 2026-08-29 上游源码路径同步

TuyuBooking完整产品仓的七个上游源码路径已由 `tuyubooking/imported/` 统一改为 `tuyubooking/upstream/`。2026-09-09 起这些目录改由完整商家产品仓直接持有，原子模块 Git 元数据不再属于产品工作树。

源码接入测试从 upstream/ 校验固定提交、许可证和必要文件。Rust 集成测试只允许使用 TuyuBooking 自己安装包内的 PostgreSQL，不得跨产品复用 TuyuFactory 运行时。

## CitizenSDK 正式依赖边界

- 途遇商家移动端正式声明与锁统一依赖crcfrcn/citizensdk根(.)的固定Git提交3e53f18354e1b21c75d7e4543f2102ba8163c575，正式编译和发布不消费邻仓源码或历史产物。
- 本机、CI与Release统一消费`https://github.com/crcfrcn/citizensdk.git`，根路径为`.`，准确提交为`3e53f18354e1b21c75d7e4543f2102ba8163c575`；声明与锁固定同一提交。宿主禁止`pubspec_overrides.yaml`与邻仓path依赖，工程准备器在本轮外部工作目录取得并验真Git原件，再通过SDK公开入口生成Pub消费视图。
- CitizenSDK 面向其他第三方时通过 `pub.dev` 发布；第三方发布渠道不改变途遇产品自身采用固定 Git 提交的正式依赖策略。
- 主机端与分机端均使用同一完整 `CitizenSdk`，提供钱包、签名、交易和内置公民链轻节点能力；不按桌面或移动平台限制 SDK 功能。PostgreSQL 与上游业务进程仍只属于主机端。
- Android 宿主使用 `FlutterFragmentActivity`，最低 API 为 24；iOS 最低版本为 16.0，并声明 Face ID 使用说明。
- 当前步骤只完成依赖声明和移动端宿主接入，不启动钱包、不重复实现 SDK 已提供的钱包功能，也不改变途遇商家移动端当前业务入口。
- `pubspec.lock` 的正式版本必须在不加载本地覆盖文件的 Release 环境中由固定 Git 提交解析生成；禁止把本地路径解析结果作为正式发布锁文件。

## 途遇商家移动端经营模式选择

- CitizenSDK 完成钱包创建后，途遇商家移动端进入经营模式选择流程；经营模式支持酒店、餐厅、旅行社、票务四类并允许多选。
- 选择结果保存在移动端应用支持目录的 `mobile_business_modes.json` 中，使用稳定模式编码和版本字段，不保存钱包、私钥或签名材料。
- 经营模式页面遵循统一双语策略：设备为中文时中文为主、英文为辅助；设备为英文时英文为主、中文为辅助。
- 当前步骤没有改变移动端启动入口。正式 SDK 可用后，由钱包就绪结果决定是否进入经营模式选择，避免在 SDK 之外重复实现钱包状态。

## 2026-08-29 Frappe PostCSS 临时路径约束

- Frappe 固定依赖的 `@frappe/esbuild-plugin-postcss2 0.1.3` 会把入口样式源目录的相对路径直接拼入插件临时目录；macOS 将同一文件解析到不同文件系统根时，相对路径中的 `..` 会逃逸临时目录并尝试创建 `/private/tataconsole`。
- TuyuBooking 不修改 Frappe、ERPNext、HRMS 或业务上游源码。可信构建在 Yarn 严格按锁文件安装依赖后，只修改一次可丢弃的 PostCSS 插件构建副本，使每个入口样式使用插件临时目录内的唯一目录。
- 补丁要求固定旧实现准确匹配一次；插件升级或实现漂移时立即停止构建，禁止静默套用不兼容补丁。回归测试固定检查临时路径约束、版本漂移门禁和构建适配边界。

## 2026-08-29 TataConsole 受控路径修复

- TuyuBooking 主机端本机完整编译只接受
  `/Users/rhett/tuyubooking/target/host-macos/build`，源码、生成物和最终 App 的边界不变。
- TataConsole Worker 已删除旧的小写 `tataconsole` 路径残留，构造阶段、任务预检、工作目录和 TuyuBooking Release 门禁统一使用权威 `TataConsole` 大小写。
- 本次修复不放宽 TuyuBooking 的受控目录门禁；路径来源在 Worker 侧修正，避免把 macOS 大小写不敏感行为当成跨平台合同。

## 2026-08-30 核心数据库首次初始化原子性

- `tuyu_core.sql` 只描述唯一核心数据库结构，不再自行执行 `BEGIN` 或 `COMMIT`。TuyuBooking Rust 存储层统一控制 `BEGIN → 执行核心结构 → 写入 schema_state → COMMIT`，结构与完成标记属于同一原子事务。
- 初始化任一步失败都执行 `ROLLBACK`，禁止留下“核心表已经存在但 schema_state 标记缺失”的半初始化数据库；不增加迁移、兼容或按表跳过逻辑。
- 当前开发机在修复前形成的半初始化应用数据不属于商家生产数据，修复验证时整体重置后重新首次初始化。正式安装的数据结构仍通过唯一 SHA-256 完整匹配，任何结构漂移继续拒绝启动。

## 2026-08-30 macOS本机构建

- TataConsole 为本机 TuyuBooking 任务注入唯一受控缓存，复用 Flutter、Xcode DerivedData、Cargo、PostgreSQL runtime、Frappe、Voyant、Hi.Events 资产及 npm、Yarn、pip 下载缓存。
- Kamra、URY、Voyant、Hi.Events 源码始终从仓库读取，只把生成资产和指纹写入缓存。最终业务运行时仍在本轮受控工作目录重新组装，不把源码复制到 `tatatest/target` 的缓存槽。
- 缓存命中不跳过 `tuyubooking.app` 的重新组装、嵌套 Mach-O 签名、清单生成、签名核验与烟雾验收。
- CI 与 Release 不设置 `TUYU_LOCAL_BUILD`，固定执行全量编译和全量发布。

## GitHub CI 增量缓存（第 7.3 步）

途遇商家端 Linux、macOS、Windows CI 按平台和架构隔离缓存。Flutter、Dart、Rust 与 Node 可再生成状态进入统一 CI 缓存，安装包和桌面 Runner 等最终候选产物保存缓存前清除。

## Release 全量构建（第 7.4 步）

正式 Release 固定从干净源码执行全量构建，显式关闭 Rust 增量编译及工具链内置缓存，不读取CI作业缓存且不复用本机编译中间物。版本、签名、校验、产物和发布流程保持原有产品合同。
最新成功 CI 解析器作为可复用 Workflow 调用 Job 只传入 `ci_title`，不得声明 `env`；`CARGO_INCREMENTAL: "0"` 只属于实际 Release 构建 Job。

## 双仓统一流程最终收口（第 7.5 步）

本产品执行统一流程规则：本机编译中间物只进入本轮塔塔缓存库的build目录并按终态规则清理；GitHub CI 的作业过程数据只进入该次Runner任务空间；正式Release从干净编译状态执行。源码不进入塔塔缓存库、塔塔依赖库或塔塔产物库。

## Voyant DMC 数据库类型边界（2026-08-30）

- Voyant DMC 的数据库回调统一使用 `@voyantjs/db` 导出的 `AnyDrizzleDb`，同时覆盖本机直接 PostgreSQL 与 Neon 两类正式运行适配器。
- Catalog 索引与预订快照继续使用同一数据库实例；模板层不得把该边界重新收窄为 `NeonDatabase`，也不得通过不安全类型转换绕过检查。
- TuyuBooking 源码接入测试固定校验导入类型、函数参数和退役类型零残留；DMC 定向 TypeScript 检查必须通过后才能保存 Voyant 提交。

## TuyuBooking Flutter 源码根目录契约

- tuyubooking/app 是途遇商家桌面端与移动端共享的唯一 Flutter 源码根目录。
- `iOS`、`Android`、`macOS`、`LinuxARM`、`LinuxAMD`、`Windows` 的编译、CI、Release 流程不得引用或重新创建 tuyubooking/desktop。
- `tatatest/target/tuyubooking-host/<platform>` 与 `tatatest/target/tuyubooking-client/<platform>` 只保存各自通过验证的最新正式产物，不保存任务记录、编译状态或产品源码。
- 路径契约由 tataconsole/console/worker.test.mjs 自动检查，防止桌面流程重新产生旧目录引用。

## 移动端构建与签名基线

- iOS Bundle ID 与 Android Application ID 统一固定为 `com.tuyulove.tuyubooking`。
- 一个 iOS 安装包同时支持 iPhone 和 iPad，一个 Android 安装包同时支持手机和平板。
- Android Release 禁止使用 debug 签名；产品源码不保存正式证书、私钥、密码或 Keystore。
- 本地构建和 CI 可以生成未签名验证产物，正式签名只允许由 Release 流程注入并验证。
- 移动端必须进入 `TuyuBookingMobileApp`，不得启动桌面端 PostgreSQL 和上游业务服务。
- `test/mobile/mobile_release_contract_test.dart` 锁定应用标识、设备范围、签名边界、移动入口及 CitizenSDK 固定提交依赖。
- `app/pubspec.yaml`与`app/pubspec.lock`统一消费CitizenSDK根包提交`3e53f18354e1b21c75d7e4543f2102ba8163c575`；离线源码只来自该已保存提交的登记Git原件，原生安装件必须使用同一来源。

## TuyuBooking 移动端 CI

- iOS 与 Android CI 由完整TuyuBooking产品本仓工作流登记，并分别使用产品专用工作流和脚本。
- 两个平台只从 tuyubooking/app 读取 Flutter 源码，不共享 TuyuLove 或其他产品的任务身份。
- iOS CI 在 macOS Runner 上执行无正式签名的编译验证，Android CI 使用 Java 17 及固定 Android SDK 和 NDK 契约。
- 两个平台统一使用 CI 成功和失败双槽缓存，不创建正式版本、GitHub Release 或应用商店产物。

## TuyuBooking 移动端正式 Release

- iOS 与 Android Release 均绑定对应平台最近一次准确成功的 CI，并从该源码提交执行全量构建。
- 两个平台统一使用全量 Release 构建，关闭增量构建且禁止读取 CI 缓存。
- iOS 固定验证 com.tuyulove.tuyubooking，使用 TuyuBooking 专属描述文件和 Apple Distribution 证书签名。
- Android 使用 TuyuBooking 专属正式 Keystore 签署 APK 和 AAB，并在发布前复核签名及应用标识。
- iOS 正式资产为 `tuyubooking-client-ios.ipa`，Android 正式资产为包含 APK 与 AAB 的
  `tuyubooking-client-android.zip`；包内固定为 `tuyubooking-client.apk` 与
  `tuyubooking-client.aab`，与本机原生发布器按完整产品身份读取的文件名一致。
- 两个平台均生成 release-manifest.json 与 SHA256SUMS；任何证书、密钥、签名或标识异常均失败关闭。

## 塔塔控制台主机端与分机端矩阵

- `tuyubooking-host` 的正式平台闭集为 `macOS`、`Windows`、`LinuxARM`、`LinuxAMD`；
  `tuyubooking-client` 的正式平台闭集为 `iOS`、`Android`、`macOS`、`Windows`。
- 两个产品的Build、CI和Release均覆盖各自四个平台；TataConsole为已接入身份实现Publish，并只启动产物库中的macOS成功产物。
- iOS与Android本机编译读取完整商家仓app与声明锁定Git提交的CitizenSDK输入；只有生成状态、工具缓存和本轮 CitizenSDK 原生产物进入准确产品平台的`cache/`任务目录，最终产物写入受控目标目录。
- 主机与分机的布局、批量任务、版本状态和发布协调均按同一产品的准确平台身份闭合，不存在旧身份回退。
- 主机、分机每行均按编译、启动、CI、Release、发布排列；除启动外均使用平台聚合弹窗。
  “全部编译”只并行启动本机四端任务，不申请 GitHub 令牌；CI、Release 的“全部”保持现有远端
  批次；“全部发布”只建立本产品四平台的逐端授权队列。弹窗子按钮按全局最长文案等宽，全部按钮跨满两列。
  每个平台单独预检、扫码授权和提交，提交取得该端任务 ID 后才准备下一端；取消、预检或提交
  失败停止剩余授权，已经启动的任务独立运行，不撤销也不共用签名。
- 分机端的 iOS、Android 进入原生商店发布器；macOS、Windows 进入桌面下载发布器，不能仅按
  `tuyubooking-client` 产品名把四个平台全部送入商店发布。
- 主机端 Linux 发布预检将 GitHub 显示名 `LinuxARM`、`LinuxAMD` 精确规范为路由平台
  `linux-arm`、`linux-amd`；正式 Release 与 Workflow 记录必须同时命中当前产品和规范平台。
  主机端与分机端即使同为 macOS 或 Windows，也使用不同路由、Tag 和发布状态键。
- 途遇商家移动端登记 App Store 与 Google Play 正式发布身份 com.tuyulove.tuyubooking。

## 2026-08-30 桌面首次初始化路线图界面

- macOS、Linux 和 Windows 桌面主机端的首次管理员初始化与经营模式选择统一采用墨绿色“旅行路线图工作台”界面，不修改桌面运行时、TUYU v1、sr25519 验签或业务模块配置合同。
- 页面背景由 Flutter CustomPainter 绘制坐标网格、等高线、旅行路线与节点，不增加背景位图。视觉令牌只作用于首次初始化和经营模式选择，不改变其他商家工作区页面。
- 初始化流程固定显示 01 设置管理员和 02 经营模式。左侧签名二维码与右侧摄像头保持相同正方形尺寸，签名响应仍只通过本机摄像头识别。
- 经营模式继续支持酒店、餐厅、旅行团和票务多选，至少选择一项。界面只改变表现形式，保存仍调用 RuntimeController.configureBusinessModules，未启用模块仍不启动且不占用运行资源。
- 页面 Logo 只读取 tuyubooking/app/tuyu_logo.png。该文件是 tuyuserve/logo 权威源生成的产品副本，禁止在页面中重新绘制、着色、裁剪或建立独立 Logo 真源。
- 设备语言继续决定中英文主次层级，另一语言以小字号辅助显示；模块勾选同时使用图标、边框和颜色表达，不能只依赖颜色。

## 2026-09-02 途遇商家移动端本机 CitizenSDK 接入

- TataConsole 将 `tuyubooking-client` 的 iOS 与 Android Build 登记为真实本机产品动作；任务直接读取 `/Users/rhett/tuyubooking/app`，禁止把产品源码复制到受控目录。
- 本机、CI与Release统一消费`https://github.com/crcfrcn/citizensdk.git`，根路径为`.`，准确提交为`3e53f18354e1b21c75d7e4543f2102ba8163c575`；声明与锁固定同一提交。宿主禁止`pubspec_overrides.yaml`与邻仓path依赖，工程准备器在本轮外部工作目录取得并验真Git原件，再通过SDK公开入口生成Pub消费视图。
- 每次本机移动端任务都独立调用 CitizenSDK 原生构建器。Android 只生成并嵌入 ARM64 `libcitizensdk.so` 与 `libcitizensdk_jni.so`；iOS 生成包含设备、模拟器和 macOS 技术切片的 XCFramework，并只把设备 ARM64 Framework 嵌入本轮 App。
- Android 本机入口在调用 CitizenSDK 前校验 调用方交付且已验真的 `ANDROID_HOME`。
  目录必须为绝对路径且含可执行 `platform-tools/adb`，不满足时立即失败；通过后仅向当前任务及子进程
  导出 `ANDROID_HOME`，不改全局环境、不在沙箱内下载 SDK。Flutter 生成任务独占的 `android/local.properties`
  后，入口只在该副本写入 `cmake.dir`，绑定 调用方同轮交付的 CMake；产品源码和 CitizenSDK 源码均不写入。
- CitizenSDK工作目录固定为调用方本轮工作根内的`sdk-native/`，只从本产品锁定Git来源物化源码；SDK Cargo目录与主产品Cargo目录独立。不同产品、不同平台任务不共享最终原生库；成功和失败结束时都删除本轮工作目录。
- iOS 通过任务独占的 CocoaPods 插件视图接入：许可证、Podspec、Swift 文件和 XCFramework 均为指向 CitizenSDK完整仓源码或本轮受控产物的符号链接，不复制源码，也不向 CitizenSDK源码根写入生成物。所有 Pod 的最低 iOS 版本统一为 16.0。
- Android根工程、子工程与Flutter插件输出由产品入口设置BUILD_DIR及本轮Gradle初始化脚本，使用产品声明的Gradle9.1.0执行同一Release工程，禁止在源码树建立build目录或符号链接。
- Android 的原生 Flutter 插件由受控 Flutter Gradle 插件按宿主类型接线。应用模块的 Release 插件依赖必须进入 `releaseImplementation`，使 `citizen_sdk`、`jni`、`jni_flutter` 和 `mobile_scanner` 的 runtime JAR 成为 R8 输入；library/add-to-app 模块仍使用 `releaseApi` 向最终宿主传递。产品工程不维护第二份插件项目清单。
- 本机验收必须检查 iOS App 内存在且只嵌入 ARM64 `CitizenSDK.framework`；Android APK 的 CitizenSDK 原生闭集必须精确为上述两个 `arm64-v8a` 库，并拒绝旧 `libsmoldot`。
- 2026-09-02 真实验证：Android 与 iOS 均通过零问题分析和 90 项产品测试；Release APK 与无签名设备 App ZIP 已分别生成到受控 `android.apk` 和 `ios.app.zip`，源码树中的 Flutter、Gradle、CocoaPods、Xcode 生成状态已清理。

## 2026-08-30 Build与Start严格分离

- 本机 Build 只读取已登记产品目录中的源码，生成产物和任务记录；禁止复制产品源码到 TataConsole 受控目录。
- 产品Build不启动、停止或安装产品；TataConsole Start只消费同产品、同平台最近一次成功Build的准确产物。
- 产品只实现Build、CI和Release；Start与Publish只属于TataConsole。
- Start 必须核验仓库、产品、平台、源码 Git SHA、产物路径与 SHA-256；任一身份不一致即拒绝启动。
- 受控`tatatest/target`只保存通过验证的正式成功产物及必要校验清单；一次性工作数据进入`work`，下载依赖原件进入`cache`，源码不复制。

## 塔塔控制台主机端与分机端产品合同（2026-09-02）

- TuyuBooking 继续使用一个完整产品仓和一个 Flutter 工程；控制台只登记 `tuyubooking`。
  主机平台为 `host-macos`、`host-windows`、`host-linux-arm`、`host-linux-amd`，
  分机平台为 `client-ios`、`client-android`、`client-macos`、`client-windows`。
- Flutter 官方 `ios/`、`android/`、`macos/`、`linux/`、`windows/` 目录不改名；同一 `linux/` 工程按不同目标分别产出 LinuxARM 与 LinuxAMD。`arm64`、`aarch64`、`amd64`、`x86_64`、ABI、Runner 和 target triple 只属于类型明确的机器字段。
- 本文早期带日期的“三个桌面端”“五平台”“七端”等内容只记录当时实现或验收快照，不再定义当前产品范围，也不能用于删除、禁用或合并六个平台中的任何一个。
- 同一完整产品内，各平台拥有独立动作、远端路由、Tag、资产、版本状态、发布指针、任务记录和产物空间。
  不保留拆分产品身份；源码仅位于完整 `/Users/rhett/tuyubooking`，不迁移旧仓历史或资产。

## 控制台受控工作根接线（2026-09-03，开发中）

- 商家主机和分机属于同一完整产品，八个本机平台分别使用
  `tuyubooking/target/<host-或client-平台>/<流程>/`，同一app源码不等于共享可写工程。
  永久产物产品根为 `target/tuyubooking`；macOS最终产物在验真后分别提交至host-macos、client-macos平台目录。
- 主机与分机均接入控制台现有 Flutter 入口配置生成器，先核验归属和完整清单，再生成本端
  pubspec、锁文件、本地化及平台工具配置。业务源码和资源逐文件只读引用，目录不链接回主仓；
  本地化、Pods、Gradle、ephemeral 和插件注册状态只在本端生成，退出不删除共享源码状态。
- 每个产品/平台使用永久固定缓存目录。新任务创建后直接清空该目录的全部内容，再启动产品入口；
  不使用 `.owner`、隔离区或兼容目录，也不扫描产品源码和上游系统。
- 本机编译直接执行产品入口；控制台不增加沙箱、工具、依赖或源码门禁。
  Flutter、Dart、CocoaPods 及工具临时状态属于本任务；仅 Flutter 编译在保护和配置准备成功后
  设置 BOT=true 抑制遥测，不设置 CI，也不把本机编译连接到 GitHub CI/Release。
- 普通路径依赖递归形成本端配置，原生插件资源与许可证按实际依赖只读引用。商家 CitizenSDK
  保持既有独占插件准备器，覆盖和本端锁文件使用同一准确 CitizenSDK完整仓源码绝对路径；
  只重定位锁定路径，不改变版本或其它记录。缺失、重复、结构或路径不符时先拒绝，
  源码锁文件不改，分机既有 --enforce-lockfile 不放宽。
- macOS Podfile 为内容不变的本端普通配置，其 File.realpath(__FILE__) 必须定位本端 macos 目录；
  entitlement、业务运行件与构建日志也留在当前任务根。分机真实控制台入口仍是 flow.sh 对应 case，
  不调用 build_client_release.sh；main_client.dart、Flutter 编译目标与 TuyuBookingClient.app 合同不变。
- 控制台 Node 入口采用相同边界：递归真实目录、独立可写工具配置和逐文件只读业务引用，
  不通过整目录链接把框架或依赖工具生成状态写回共享源码。此处仅约束控制台接线，不修改商家业务。
- 已有实盘事实只覆盖配置阶段：两端 macOS 配置生成与正常/部分写入失败均完成本任务内容清理、
  源码及其它端；Podfile 的真实 Ruby 路径回读确认属于本任务。主机已验证官方 gen-l10n、
  Dart 离线 Pub 和 Flutter 插件配置生成，锁定依赖未变，生成内容均按本任务清理。
  插件注册、原生环境和 Swift Package 配置属于本端；未以此宣称 CocoaPods 安装或产品编译通过。
  macOS config-only 会继续处理 CocoaPods，不能作为无产品执行的配置检查入口。
- 受控`cache/`与`target/`现为平级独立目录并只允许小写仓库分类；旧target内工作目录、原根级产品目录与旧平铺工作目录均已删除。已有产物按准确产品平台保留；控制台安装版已更新并正常启动；完整商家产品编译
  不属于此次接线验收，不能据此认定成功。具体命令与验收证据记录在当前任务卡。
- 本节不修改另一线程的 CitizenSDK 准备、签名、Podfile 接入及产品验真职责；CI/Release 的
  Runner 路径行为保持不变，产品原生接入状态以下方专属章节的实际证据为准。

## TuyuBooking macOS 本机 CitizenSDK 接入现状（2026-09-03）

- 本机、CI与Release统一消费`https://github.com/crcfrcn/citizensdk.git`，根路径为`.`，准确提交为`3e53f18354e1b21c75d7e4543f2102ba8163c575`；声明与锁固定同一提交。宿主禁止`pubspec_overrides.yaml`与邻仓path依赖，工程准备器在本轮外部工作目录取得并验真Git原件，再通过SDK公开入口生成Pub消费视图。
- SDK 的 `darwin/citizen_sdk.podspec` 消费固定名称 `CitizenSDK.xcframework`，原生构建入口是 SDK 自有的 `scripts/build-native.sh`。源码检出不包含该生成物，不能把源码目录缺少 XCFramework 直接判断为 SDK 功能未实现，也不能要求向 CitizenSDK完整仓源码树写入二进制。
- 现有 iOS Podfile 通过 `CITIZENSDK_IOS_PLUGIN_ROOT` 接收当前任务的插件链接视图，把 SDK 源码和本轮外部原生产物接入同一个 CocoaPods 插件。
- macOS 的 `build_release.sh` 与 `build_client_release.sh` 共用现有 Podfile 中的准备、链接和清理实现。两者先解析 Flutter 实际依赖，调用 SDK 自有 `build-native.sh apple`，检查唯一 macOS 切片（架构 arm64）并真实 typecheck `import CitizenSDK`，再执行 CocoaPods 与宿主构建。主机的业务运行时和 PostgreSQL 构建在该预检之后。
- SDK 每轮在当前受控任务的 `citizensdk/macos-*` 下生成独占工作目录、XCFramework 和 `macos-plugin` 链接视图；许可证、pubspec、Podspec、Swift 源码只建立符号链接。成功或失败退出只清理本轮 SDK 目录，以及仍指向本轮视图的插件链接，不删除共享 `.dart_tool` 或整个 `.symlinks`。
- 最终主机和分机 App 均要求嵌入 macOS 的 `CitizenSDK.framework`（架构 arm64）并完成签名；分机继续拒绝 PostgreSQL、业务运行时和 `libtuyubooking_native.dylib`。完成实际构建之前不将该接入实现标记为安装包验收通过。
- 主机打包的 Flutter 测试门禁已前移到业务运行时和 PostgreSQL 构建之前，桌面窗口测试使用现有动态显示名和产品名配置，不再要求固定名称 `TuyuBooking`。
- 后续修复仅消费 SDK 已有原生构建入口，原生产物与插件链接视图按主机、分机当前受控任务分别隔离；不得复制产品源码、修改 SDK 公共命名、限制主机 SDK 能力或改造控制台流程。
- 两个 macOS 产品的完整安装包、实际启动与运行边界验收仍未完成，不能以 Dart 测试通过替代原生链接或启动成功。

### macOS CitizenSDK 接入验收边界（2026-09-03）

- 本轮已验证当前解析的本地 CitizenSDK 可以通过自身 `scripts/build-native.sh apple` 生成 XCFramework，macOS 切片（架构 arm64）与真实 Swift `import CitizenSDK` 检查通过。原生框架构建成功不等于 Flutter 插件接入完成。
- 当前 macOS 插件视图把 `darwin/Sources` 整体设置为目录软链接。真实 CocoaPods 生成结果没有包含 Swift 桥接源码，`citizen_sdk` 成为 `PBXAggregateTarget`，最终 Runner 无法 `import citizen_sdk`。因此，当前 macOS 主机、分机打包接入仍未完成验收，不得标记为可用安装包。
- 待确认修正：插件视图使用真实目录及逐文件源码软链接，不复制或修改 SDK 源码；在现有 Podfile 内检查 CocoaPods 实际收集的 Swift 文件与插件编译目标，使缺失桥接源码在业务运行时构建之前失败。
- 主机、分机继续共用现有 Podfile 接入逻辑，不增加产品包装类，不更改 `CitizenSdk` 命名，不修改 CitizenSDK 产品或控制台流程。
- 测试需要覆盖 CocoaPods 实际源码收集与编译目标，而不能仅验证软链接存在。上述修正尚未执行，需用户确认。

- macOS 启动验收统一从应用 `Contents/Info.plist` 读取 `CFBundleExecutable` 和 `CFBundleIdentifier`，同时支持二进制与 XML plist，不再硬编码可执行文件名和容器标识。可执行文件名允许空格，但拒绝目录路径、空值和空字符；应用标识必须为安全的标识字符串。元数据缺失、非法或目标文件不可执行时，在创建临时目录和启动进程之前明确失败。验收临时数据按应用标识隔离，并在结束后删除。
- macOS 主机已生成应用通过冷启动、HTTPS、重启和持久化验收；该次验收复用已有应用，没有重复完整编译主机。分机各平台构建状态以现有任务卡的最新实际执行记录为准，静态检查或组件测试通过不等于安装包构建成功。
- 分机初始化页面直接导入 `client/domain/business_mode.dart` 中已有的 `BusinessMode`，不依赖其他库的间接导入，也不复制类型定义。SDK 等待与启动失败重试状态通过实际渲染 `ClientInitializationPage` 的组件测试覆盖；测试使用空的注入 SDK，不创建钱包、不调用轻节点，也不接触钱包机密。分机票务条件分支和共享平台错误文案保持业务语义不变，并通过完整 Flutter 静态检查。
- 本机分机 Android 构建由Worker传递受控 Android SDK的`ANDROID_HOME`和唯一CMake 3.31.6的`CMAKE_COMMAND`；只做路径注入，不执行产品前版本校验。CitizenSDK Gradle从受控版本登记获得3.31.6，TuyuBooking的任务工程`android/local.properties`把`cmake.dir`指向同一对象；不修改CitizenSDK源码，不写产品源码中的`local.properties`，不尝试安装另一版本。
- macOS CitizenSDK 插件视图测试夹具显式以 UTF-8 读取含中文的 Podfile，不再依赖 Ruby 默认外部编码。四个真实 Ruby 校验场景统一在 `LANG=C`、`LC_ALL=C` 和 `-EUS-ASCII` 下运行；缺少 XCFramework、错误 Swift 源码和任务目录越界分别断言准确拒绝原因，禁止用任意非零退出码掩盖编码异常。此修复仅涉及产品测试夹具，不修改 CitizenSdk 或 Podfile 的接入实现。
- 四平台任务的固定缓存从注册、清理、日志到子进程均按产品平台隔离；禁止再把任一平台的`.dart_tool`、插件登记、local.properties、Generated.xcconfig或ephemeral状态写回共享`app/`。不同平台必须同时准备和编译，不能用产品级队列掩盖路径越界。

## 本机移动编译后安装的实施边界（2026-09-03）

- 途遇商家分机端（`tuyubooking-client`）的 iOS、Android 继续使用原有独立 build 任务；仓库、产品、平台、流程模型、按钮、状态及并行调度不变，不新增安装流程或全局串行队列。
- 受控源码已扩展独立原生请求及 Android 签名、保存、安装和身份版本回读链路。每任务的路径、占有关系、响应与取消独立；只在唯一合适设备时自动安装，零台或多台明确失败，不增加设备选择界面。
- iOS 受控源码已实现实际 prepare/install 执行链，使用现有工程的 Apple Team 与标准 Xcode 描述文件和本机签名配置，不新增配置体系；缺失、歧义或不适配时明确失败。本机校验签名、Team 和描述文件，设备只回读 Bundle ID、版本和构建号，不声称可以回读设备中的证书。受控原生定向测试已通过，但真实签名安装验收尚未完成，不能据代码落地宣告设备安装成功。
- 安装失败保留有效受控产物，不自动卸载、清数据、降级或更换签名；本步没有手动仅安装重试入口，再次点击编译仍执行编译。安装后不自动启动，CI、Release 与应用商店发布不变。
- 本次仅覆盖分机端的 iOS、Android 编译后安装，不改变主机或分机的桌面流程，不修改 CitizenSdk 或业务功能；尚未进行本次真实签名与手机安装验收。
- 第2步只读核对确认：现有 Android Release 已保持未签名候选，无需改动；iOS 沿用现有 Team 与分机应用标识，本机存在匹配且未过期的安装描述文件及可用签名身份。目标设备注册匹配和实际签名安装仍须后续获准验收，不因配置检查通过而认为已安装。
- 本次受控测试通过不代表实际运行的控制台已更新，也不代表已完成设备签名或安装。具体测试、门禁阻塞与清理证据见现有任务卡；自动安装总体任务仍未完成。

### macOS业务运行时依赖下载（2026-09-03）

现有 `scripts/business-runtime/build_macos.sh` 的 `fetch_locked` 优先复用通过SHA256校验的缓存；未命中时仅使用HTTPS下载。下载采用额外最多3次重试（包含连接重置等错误）、2秒重试间隔、30秒连接超时和300秒单次传输超时。关闭进度条但保留错误输出。最终下载失败或摘要不符时清理对应半包，不提升为有效缓存；不会因此重启整个产品构建或影响其它平台任务。


### Frappe资源依赖受控镜像接线（2026-09-03）

资源脚本scripts/business-runtime/build_frappe_assets.sh新增调用受控prepareYarnDependencyEnvironment，对Frappe、ERPNext、HRMS的明确锁文件统一准备归档镜像。Yarn使用本任务生成的配置和本产品平台独占缓存，继续保持frozen-lockfile，不改上游业务逻辑。已有Frappe锁文件489个resolved条目中488个提供SHA-512；剩余无强归档摘要条目未被伪造摘要或删除，仍交还上游处理并明确提示。

npm 用户配置与全局配置重复问题已经修复，解析器离线安装和相关公共消费者测试已通过。仍未执行 TuyuBooking 完整资源构建，本次未启动产品编译或重启控制台。

### 固定运行时归档受控接入

PostgreSQL 的 macOS、LinuxARM、LinuxAMD 打包脚本通过受控 `archiveForActiveTask` 使用锁定 URL 与 SHA256。商家业务运行时的 Python、Nginx 固定归档通过 `materializeDependencyArchive` 写入当前任务目录；全局唯一原件在构建成功或失败后均保留。业务工作目录由受控任务身份确定，不再使用用户 Library 缓存作为下载归属，也不再清理 Voyant 原始源码目录。

Hi.Events 的 Composer 安装器、Python 包解析、pnpm 安装和其它生命周期下载并未因此全部完成统一。pnpm 的原生预载参数与项目隔离问题已修复，并通过真实离线消费测试；Voyant 安装已使用公共 store。只有归档清单全部覆盖时才启用离线安装，未覆盖来源仍明确报告，不能把它们计为已缓存。产品完整编译、安装及启动未在本次执行。

Voyant 与 Kamra、URY、Hi.Events 同为商家业务模块，保留来源清单、许可证、独立 schema 与运行集成。四个目录由TuyuBooking完整产品仓直接跟踪，控制台保存和推送只提交tuyubooking；不再单独提交、拉取或推送 Voyant，也不触发子仓钩子或申请子仓令牌。上游同步通过指定前缀的 Git subtree 导入，并在来源清单更新准确提交。

Hi.Events 前端使用公共 Yarn 镜像，避免另起一套前端归档下载缓存。商家Android本机任务调用产品工程自己的Gradle Wrapper；调用方未提供 `JAVA_HOME` 时使用本机 Android Studio 随包 JBR，避免 `/usr/bin/java` 占位程序被误当成真实 Java。产品自己的 Gradle 仍决定全部版本与来源；任务先从塔塔依赖库恢复已有 Wrapper、Maven 与 Google 原件，缺少时由产品正常下载，退出时把已经完整落盘的原件自动保存，下一次及其它产品直接复用同一摘要。半包、锁、daemon、日志与编译物不进入依赖库。流程不检查Gradle或Java版本，也不以工具验真阻断产品Build。

### 固定依赖消费者补充（2026-09-04）

Windows PostgreSQL、Android Gradle、Voyant pnpm 与 Hi.Events Yarn 的选择和准备均由产品流程负责；塔塔只提供任务缓存位置及产品主动调用的依赖原件服务，不在启动产品前预取或验真。

### 商家分机四端共同构建阻塞修复（2026-09-04）

旧产品沙箱、受控 Gradle 摘要和 Worker 工具准备已经删除。当前 Worker 只显示任务、清空准确固定缓存、启动产品入口；后续分析、工具与包依赖完全由产品流程负责。

### 合同测试源码身份与 Python 缓存修复（2026-09-04）

合同测试共用 app/test/shared/source_paths.dart，从TUYUBOOKING_ROOT直接定位完整商家产品根。仅直接在原 app 目录运行时允许验证后的本地入口；受控任务缺少源码身份时明确失败，不猜测父目录。主机、分机、跨平台静态合同读取原产品文件；SDK视图检查验真当前锁定Git来源和本任务Pub实际解析路径。yaml 3.1.3 从已锁定传递依赖提升为直接测试依赖，版本及摘要保持不变。

测试增加四端工作目录与原源码身份隔离、缺失/相对源码根拒绝、带空格及单双引号 SDK 路径解析。未修改业务功能、平台模型，不复制源码，不增加受控源码树，也不跳过失败测试。

Python 安装保留受控已验真 wheel 约束，同时取消 PIP_NO_CACHE_DIR/UV_NO_CACHE。pip/uv 可写缓存明确位于当前任务 cache/package-managers/pip 与 uv，pip 显式传 --cache-dir。没有将可写缓存混入 shared 原件库；这不表示尚未锁定的传递依赖已完全纳入不可变原件缓存。

此前回归为 123 通过、1 项缓存合同失败，静态分析另有未使用导入；本轮已修复这两项，后续实际测试和四端构建结果仍须分别记录，不能据代码修改宣称安装成功。

### Native build integration correction (2026-09-04)

Apple platforms use the existing CocoaPods bridge, with Flutter Swift Package Manager disabled and old generated-package project references removed. The macOS client must run its complete packaging adapter to prepare CitizenSdk and apply the client product identity.

Android keeps the Dart override on original CitizenSdk source. Gradle's writable plugin configuration is generated under the current task's `dependencies/citizensdk/android`; source files remain references to the original SDK and outputs stay in the current task. This satisfies Gradle 9 without granting source-tree write access.

The iOS executable built successfully on 2026-09-04 but device installation had not yet succeeded. The managed installer now selects the signed CoreDevice executable rather than Xcode's unsigned launcher. Windows still requires a real Windows/MSVC executor; generating only Dart assets is not successful Windows compilation.

### Android native-only task configuration

The task-owned CitizenSdk Android project contains native inputs and required assets only. It must not generate another Dart SDK package, lib directory or test tree. Dart dependencies and lockfile identity continue to point to the original SDK. This prevents duplicate analyzer contexts without excluding first-party source from analysis.

### Approved local build scope and dependency inputs (2026-09-04)

Local host/client actions now declare explicit dependency input files independently of the broad product source ownership root. Client actions prepare the app Pub lock and Android wrapper where applicable, not host upstream locks. Host macOS additionally prepares host Cargo and selected runtime frontend locks. Host Windows/Linux checks prepare app Pub and host Cargo inputs only. The SDK's existing preparation adapters remain responsible for SDK-native inputs.

Windows/Linux local actions compile the Flutter entrypoint using kernel_snapshot_program on the macOS toolchain; host actions additionally cargo-check tuyubooking-native's library using the host toolchain. These actions do not link target-native plugins or create foreign installers. The recorded scope is local-common-code-compilation, with targetNativeBuild=false and the actual nonempty kernel's SHA256. macOS application packaging and mobile build/install behavior remain separate and unchanged by this scope correction.

### Kernel proof reader correction

The local compilation proof now resolves app.dill from kernel_snapshot_program.stamp under the current task's .dart_tool/flutter_build build-ID directory. It no longer assumes Flutter's public output list contains internal intermediates. It requires exactly one stamped, nonempty, task-owned regular kernel, rejects symlinks and ambiguous candidates, and hashes the actual bytes. No foreign native linking or installer generation is added.

Kernel evidence-reader verification: after installing the corrected executor, client Windows and host Windows/LinuxARM/LinuxAMD local compilation checks all completed successfully on 2026-09-04. Each success retains the explicitly limited common-code scope; no Windows/Linux installer was constructed on macOS.

### 2026-09-04 主机 macOS 固定归档登记

主机 macOS 的显式依赖输入增加 scripts/business-runtime/macos.sources.plan.json。Python 3.14.3、Nginx 1.30.4 是当前 build_macos.sh 实际下载的固定运行时归档，登记预取；Nginx 哈希采用现有构建脚本及 runtime.lock.json 的一致锁值。本机已提供的 Node、PHP 不因该清单而重复下载。此项修复沙箱内首次下载被拒绝的问题，不改变源码保护和其它产品/平台依赖边界。

商家分机移动端继续使用控制台统一签名及安装：iOS 修正未签名候选状态判断；Android 对 USB 短暂断连有限等待，不把编译成功等同于安装成功。

Android 首次安装状态由统一安装器同时检查 `pm path` 退出码、标准输出和错误输出：仅退出码 1 且两个输出均为空时表示尚未安装；退出码 0 必须返回有效安装路径及唯一 base.apk。设备故障、异常输出和不安全路径均失败。已有应用必须通过产品身份、证书和防降级检查，安装后必须回读准确版本与证书；不能通过卸载或清理商家数据规避失败。

分机端编译安装结果只适用于该次任务的源码和工具链。历史安装成功不等于新版 Flutter 工具链已通过，也不等于主机服务或员工业务联调已完成。实际任务号、设备验收及回归测试结果仅记录于当前任务卡。

### 2026-09-04 主机 Python 依赖预取补全

主机 macOS 在基础 Python、Nginx 归档之外，还会解析 Frappe、ERPNext、HRMS、Kamra、URY 的 pyproject.toml。五个清单现已进入主机 macOS 显式依赖输入，由 Worker 使用与打包运行时一致的 Python 3.14.3 前置缓存固定 wheel，解决运行时构建已进入沙箱后才请求共享缓存导致的 EPERM。MariaDB 驱动继续按产品 PostgreSQL-only 策略排除。

主机 macOS 的前置依赖闭包同时覆盖 Voyant pnpm 锁和 Hi.Events Composer 锁。Worker 预取固定 pnpm 本体、带强完整性的 pnpm 包归档及固定 Composer 本体；Composer 依赖缺少 SHA-256 的事实仍如实登记为 unmanaged，不将下载后自算摘要冒充供应链锁。

### 主机核心就绪与异步生命周期（2026-09-04）

主机状态快照不得把数据库就绪写成固定成功。ApplicationRuntime 使用现有数据库连接查询当前安装记录；连接锁等待和只读查询共同受 2 秒超时限制。连接失败、安装记录缺失或超时均不能返回成功快照，FFI 只暴露中英文安全错误，不暴露内部连接信息。该检查不增加数据库账户、数据库实例或部署服务。

核心数据库可用即可进入初始化、管理员登录及模块选择流程，不等待所有业务模块就绪。继续使用已有持久化模块选择，只启动启用模块；停用不删除数据。已启用模块缺失、失败、停止或异常停用属于业务降级；数据库健康检查失败属于核心失败，界面回到启动错误页，不把核心失败当成可用的业务降级。

Flutter 原生网关按顺序把 FFI 调用交给后台 isolate，原生指针在同一后台调用中分配、读取和释放，不跨 isolate 传递。Rust 继续复用进程级互斥状态及既有 Tokio 执行器。生命周期控制器等待已发出的调用后停止，重复停止共用完成结果，过期响应和已销毁控制器不得重新发布就绪状态。模块选择提交时生成不可变集合，停用模块不能通过重启操作隐式启用。

本节描述源码行为，不表示已完成新版安装包、真实数据库故障恢复或主机与分机现场联调；本次验证结果及尚未执行项目以任务卡为准。

主机启动测试使用受控独占工作目录，缺少的测试依赖原件通过既有受控依赖协调器验真保存；任务清理不得删除可复用的全局原件。测试缓存副本合并完成后方可调整该副本目录的写权限，不跟随链接或改写原缓存。工具链更新导致的任务内依赖解析变化不能冒充产品锁文件已经更新，也不能以定向测试通过代替冻结发布验证。

### 分机固定主机与员工登录边界（第4项定向回归完成）

保存的主机记录是重连依据；只有记录文件不存在才进入首次唯一主机发现，损坏记录不能触发自动换主机。首次连接必须在记录保存成功后才向业务页面发布 profile。连接中的重复启动共用完成结果，页面销毁后忽略网络返回，不再通知界面或启动后续保存。员工身份和权限仍使用上游系统，未增加途遇账户注册、主机绑定或扫码连接流程。

本项实现目标为：TLS 握手阶段强制固定证书指纹，不因系统信任其它证书而跳过；首次发现仍属于首次信任，不代表实名商家认证。状态查询与员工请求禁止自动重定向；模块请求不能通过路径越界访问另一业务入口。状态响应限制 64 KiB/8 秒，员工文本响应限制 8 MiB/12 秒，计时覆盖连接及响应读取。员工登录防止重复提交，密码提交后清空输入框，离开页面后返回的会话立即释放，不落盘保存员工密码。

代理设置与证书回调使用独立赋值，已修正 Dart 表达式结合错误并完成定向回归。网络测试采用受控传输替身，未对真实 TLS 网络、上游部署或手机安装进行现场验收；不得把本项结果解释为真实商家联调或发布验收完成。具体命令与结果记录在当前任务卡。

整体回归应同时覆盖业务行为与主机/分机源码边界。首次连接的正确时序是取得经过验证的局部主机资料、持久化成功、再向业务界面发布 profile；源码合同应约束这一时序，而非固定局部变量名或要求提前发布 profile。既有合同中的过时文本断言已改为持久化完成后才发布状态的顺序约束，保存失败不得发布 profile 的运行行为继续由连接行为测试覆盖，不倒退生产逻辑。整体回归结果记录在任务卡；当前工具链的隔离测试通过不代表原始依赖锁文件的正式发布验证、整包编译安装或现场联调通过。

### 安装显示名称与初始化边界

系统安装显示名称遵循设备语言：中文为“途遇商家端”，英文为“TuyuBooking”，其他未支持语言回退英文。用户可见名称不得附加主机、分机、Host、Client 或设备类型后缀。主机与分机继续使用各自的 Bundle ID、内部可执行文件身份和数据空间；这些技术标识不是用户可见的软件名称。Apple 使用 InfoPlist.xcstrings 提供 en、zh-Hans、zh-Hant 名称；Android application label 引用 app_name，语言资源从现有 ARB 生成到构建目录；Windows 提供中英文名称资源；两个 Linux 架构使用本地化 Desktop Entry Name。Apple 未本地化名称须与物理包名匹配，不能把底层技术包名误作用户品牌名。macOS 两个产品打包入口已经先确定最终交付包名、更新基础名称，再执行外层签名；完整、增量和分机三种路径的独立包装及签名测试通过。Windows 原生入口使用系统语言资源设置窗口和任务栏名称，并仅更新指向本程序实际可执行文件的已有快捷方式，不改物理文件名、不创建额外快捷方式或安装器、不修改其他软件。Windows 真机显示和正式安装包验收未执行。Android 名称资源使用 GenerateAppNameResources 类型化任务和 DirectoryProperty 输出，通过 androidComponents.onVariants / addGeneratedSourceDirectory 接入各变体，未加入兼容开关；重复变量声明已删除。四产品的独立 AGP 9.0.1 原生验证均已通过：Debug 和 Release 资源消费自动触发生成任务，AAPT2 编译及链接后的资源表包含正确中英文名称，输入不变时生成任务为 UP-TO-DATE。上述验证针对名称任务及资源链路，不代表完整应用编译、安装或真机显示验收。

商家主机现有扫码初始化页面和流程保持不变。本轮名称调整不修改初始化页面、钱包、管理员、员工账户和业务数据库。分机钱包入口调整仅限分机；移动端不显示自身的“分机”身份标签，桌面打开后的业务页面可显示主机或分机功能标识。

商家相关 Flutter 合同测试目前为 16 项通过。macOS 已执行真实包装脚本的最终包装片段，验证基础名称、两种语言资源、独立标识和最终代码签名，三种路径均通过；该测试使用最小测试包，不代替整包业务构建或已安装 Finder 显示验收。Android 独立原生验证揭示了 SourceSet Provider 接线错误，Flutter 静态合同通过不能替代该原生验证。具体证据和状态见现有任务卡。

### Android 自适应启动图标

Android application 的 icon 与 roundIcon 统一引用 @drawable/app_icon。既有 drawable/app_icon.xml 提供位图入口，drawable-v26/app_icon.xml 提供系统原生自适应图标，app_icon_background.xml 使用正式 Logo 左上角底色并铺满裁切区域。完整前景按 108dp 图层中的居中 66dp 布局，不裁剪或重绘标识；圆形及其他系统图标形状由启动器裁切。安装名称、初始化页面和钱包功能不随本次图标调整变化。

唯一生成来源为 tuyuserve/logo，原始 AI、PNG 和既有平台位图保持不变。generate_assets.py --android-only 仅生成已登记的四产品 Android XML 并更新 manifest.json；不会批量重写其他平台图标。原生 XML 以 android_resources 记录路径和摘要；商家工程路径使用 tuyubooking/app。厂家前景继续使用其既有 prepareLogo 任务生成的 drawable/tuyu_logo。

长期验收包括权威源与衍生清单一致、四产品普通及圆形图标引用一致、标识位于裁切安全区域，以及最终安装包在实际启动器中的显示。资源测试不能替代整包编译、安装和真机视觉验收；本项不修改控制台流程或 CitizenSdk。

### 分机钱包初始化入口

分机由产品 Flutter 页面显示正式途遇 Logo、产品名称、中英文辅助文字及创建/导入入口，窄屏和横屏通过可滚动的限宽页面承载。页面不显示主机/分机品牌后缀，不增加助记词或派生密码输入。创建和导入直接调用 CitizenSdk.wallet.create/importWallet，秘密输入、可选派生密码与安全操作属于 SDK；调用完成后回读 getProfile，只有钱包公开资料已经提交才进入后续业务流程。商家主机现有扫码初始化完全不变。

取消和认证取消依据 CitizenSdkErrorCode 分类，留在入口而不当作操作失败。真实失败仅显示产品通用提示，不直接显示 SDK 原始异常；操作中防止重复点击，更换 SDK 后丢弃旧会话的异步结果。商家未有钱包时不提前加载业务模式；厂家未有钱包时不开放业务界面，钱包就绪后才首次启动原有主机连接。钱包不代替上游员工账户及权限。

本实现的源合同和语法解析不能代替 Flutter 组件、完整类型分析或原生钱包验证。完整验收需覆盖两种语言及手机/平板/桌面尺寸、创建/导入成功、取消、失败重试、重复点击与 SDK 会话更换，不得把源合同通过当作实际钱包初始化成功。

分机入口现已增加实际 Flutter 组件测试，使用真实产品页面及 CitizenSdk 公开门面，测试传输只提供公开状态。取消错误夹具必须携带当前 sessionId/requestSequence；缺失时 SDK 正确拒绝为解码错误，禁止放宽此校验来通过测试。相关错误夹具已补齐当前会话和请求身份，现有入口组件及相关源合同测试通过。成功创建/导入后的业务跳转、已有钱包、回读失败和SDK恢复已经通过实际Flutter页面及公开门面的夹具测试；原生安全界面和真机安装仍属于独立验收；具体运行结果见本产品现有任务记录，不能据入口测试通过声明完整钱包初始化已验收。

### 2026-09-05 本机移动构建准备修复

- 本机、CI与Release统一消费`https://github.com/crcfrcn/citizensdk.git`，根路径为`.`，准确提交为`3e53f18354e1b21c75d7e4543f2102ba8163c575`；声明与锁固定同一提交。宿主禁止`pubspec_overrides.yaml`与邻仓path依赖，工程准备器在本轮外部工作目录取得并验真Git原件，再通过SDK公开入口生成Pub消费视图。

受控缓存删除针对待清理子树中的真实目录恢复当前用户写入和遍历权限，不修改普通文件、不跟随符号链接，不删除永久缓存根。缓存校验与清理同时失败时保留两个原因；新缓存提交后，旧缓存清理失败不再触发删除新缓存的回滚。仍保留成功和失败各一个槽位及原有产品平台隔离模型。

本次仅修改控制台源码，未运行测试、重新编译控制台或重试手机安装。已运行的控制台安装包仍须更新后才能使用本次修复；不能据此声明 iOS、Android 已编译安装成功。

### 2026-09-05 两项本机构建阻塞的针对性回归结果

新增测试夹具使用限于同步读取的逻辑路径映射，真实文件仍只在受控测试目录内；没有移动实际SDK、修改生产源码保护或放宽target目录限制。商家与厂家主机各4个平台、分机各4个平台共16个组合通过本地覆盖规划测试。另验证缺失覆盖、错误SDK路径被拒绝，正式Git声明与锁文件保持不变。只读缓存清理、符号链接隔离、新槽提交后清理失败不回滚、两类错误同时保留的测试通过。针对性测试汇总18项通过、0失败，夹具由测试钩子清理；这不等于全套流程测试或实机验收通过。控制台换包与两台手机安装仍需独立确认结果。

### 2026-09-05 控制台应用修复后的安装尝试

控制台更新任务 ea3624f3-a76e-4799-b1cd-ed0b9e0fd07c 成功并完成重启，原缓存清理和正式锁检查不再阻塞本次商家移动任务。iOS、Android均进入平台构建脚本后失败：iOS共用SDK检查错误要求CITIZENSDK_GRADLE；Android的rustup未选中工具链，无法读取Rust sysroot。新版本尚未安装至两台手机。本次只完成既定两项修复的针对性回归和控制台换包，不宣称移动安装验收完成。

### 2026-09-05 SDK平台工具接入修复

商家Android公开Build入口消费本仓声明的准确Java与Gradle回执，不搜索Android Studio或系统执行器。商家与厂家分别在各自scripts准备工程、生成离线Gradle初始化并执行本产品编译；调用方只提供资源与源码外工作根。

旧的真实Gradle准入门禁测试已经删除；现行回归只锁定平台缓存隔离、产品Wrapper入口、全局依赖唯一对象和Worker不串行任务。测试结果不是手机安装验收。

### 2026-09-05 移动安装验收尚未完成

本机Build不再执行`flutter analyze`或`flutter test`，两者的退出码不能阻止编译。Android不再以控制台指定Gradle路径为准入条件；产品Wrapper和真实编译器自行返回结果。移动安装仍必须以真实Build成功和设备回读为准。

### 移动构建的静态检查与 Android 工程隔离

构造器保持公开调用参数不变，使用 Dart 3.12 初始化形式；钱包组件测试直接声明 path_provider_platform_interface，不依赖传递依赖。正式 Git 声明和锁文件不改成本地路径。

CitizenSdk 独立 Android 构建在当前任务 citizensdk/work/gradle-project 中生成根工程及 native 工程入口，原 Gradle 脚本和全部源码仍从 citizensdk 只读加载。工程配置、Gradle/Kotlin/CMake 状态和产物不得写入 SDK 源码；不同任务不共享可写工程。钱包 API、主机扫码初始化及产品流程模型不变。

验收必须同时覆盖 Gradle 实际解析出的 native.projectDir 与 CocoaPods 的真实 framework 复制。仅生成 Gradle 入口或静态合同测试通过不足以证明目录隔离成功；rsync --server 必须实时传递协议输入输出，禁止作为等待完成后才返回输出的普通命令包装。真实设备构建、签名、安装仍分别判定，构建中止不能记为安装成功。

### 2026-09-07 商家分机四端编译依赖边界

商家分机按平台读取自己的 `app/pubspec.lock`，macOS 另读取 `app/macos/Podfile.lock`；CitizenSDK 的 Cargo 闭包归 CitizenSDK 产品所有。Worker 不解析这些锁、不授予依赖权限、不在产品启动前准备闭包。Windows 本机动作仍由产品决定其准确编译范围。

Android 分机的锁定 `jni_flutter` 模块以 Android 35 编译，受控 SDK 同时提供准确的 API35 与产品主编译使用的 API36；构建不得调用 SDK Manager 临时补包或写受控 SDK。macOS 分机没有引用 Asset Catalog 自动生成的 Swift 资源常量，打包入口在 `xcodebuild` 明确关闭该项生成，避免 `actool` 在隔离派生目录创建无业务用途的源码；资源目录本身及应用图标仍照常编译。

Pub、Cargo 与 CocoaPods 依赖均由产品入口按自身锁文件处理。产品需要离线原件时主动调用唯一 `rely` 服务：已有即复用，缺失最多下载三次后原子入库；Worker 不预载，也不强制离线模式。

CitizenSDK 的 ZXing-C++ 3.1.1 已按全局依赖处理：产品入口请求准确URL与SHA-256，`rely/objects`命中后直接展开到本平台固定缓存；首次缺失才下载并原子保存。Worker不交接、不扫描该依赖。Android与iOS分别使用各自产品平台缓存，任何一端都不能占用或清理另一端目录。

AGP 9 的商家分机 Android Release 要求 Flutter 插件项目以 `releaseImplementation` 进入应用运行时类路径。应用的 `minifyEnabled` 不得复制给 `jni`、`jni_flutter`、`mobile_scanner`、`citizen_sdk` 等 Android library 插件，否则各插件会在最终应用分析前先被自身 R8 裁空。library 插件保留完整 runtime JAR，由应用的 `minifyReleaseWithR8` 统一收缩；正式依赖版本、业务入口和包身份不变。

### 2026-09-10 四项本机构建修复

商家主机 macOS 的 Python 依赖完全由产品脚本读取各应用 `pyproject.toml` 并交给 pip 解析。产品脚本不再调用控制台 Python 依赖扫描器、不接收受控约束文件，也不因清单没有表达完整传递闭包而被控制台拒绝；pip 与 uv 的可写数据仍只进入该产品 macOS 固定缓存。

商家分机 Android 的 Flutter/Pub 状态在独立缓存工程视图中生成，CitizenSDK 与宿主 Gradle 均直接使用产品源码根的普通可执行 `app/android/gradlew`。这是只读工具入口，不改变源码；Gradle 用户目录、Flutter build、CitizenSDK work/output 等可写结果仍只进入 Android 固定缓存。macOS 分机在进入产品打包器前复用现有 ZXing 3.1.1 准备器，把唯一 rely 原件展开到 macOS 固定缓存后交给 CitizenSDK Apple 构建。iOS 和 macOS 不再遗漏该全局原件。

以上是途遇现有独立缓存工程视图内的产品接线，不代表控制台获得产品工具或依赖管理权。控制台仍只负责创建任务、清空准确缓存目录和启动产品入口。

### 2026-09-10 统一缓存工程视图

途遇商家主机与分机继续共用真实 `tuyubooking/app` 源码，但分别使用 `tuyubooking/target/host-<平台>/build/` 和 `tuyubooking/target/client-<平台>/build/`，可写目录绝不共享。工程视图由产品自己的公开入口装配，SDK布局由锁定版本SDK的公开入口装配；产品 macOS 打包器仍从本产品真实脚本路径读取产品和业务运行时源码，CitizenSDK 原生脚本也从自己的真实脚本路径定位 Swift/C/Rust 输入。

分机 Android 的 Flutter/Pub 阶段在准确缓存工程生成 `local.properties`、插件清单和 Dart 状态，Gradle 阶段固定进入 `/Users/rhett/tuyubooking/app/android/` 真实根并执行产品 Wrapper。产品设置从当前缓存 Flutter 根读取生成状态，Gradle 项目缓存、用户目录和全部输出继续定向到该分机 Android 固定缓存；不再执行跨根 `settings.gradle.kts` 链接，也不使用 `-p` 建立第二种根解释。

Gradle 9.1加载受控 Flutter 插件 included-build 时，受控对象只开放该插件工程目录自身的所有者写位，文件内容继续只读验真；插件 `build` 由任务级初始化脚本导向分机 Android 缓存。产品 Gradle命令关闭 Problems Report，真实源码根只承担构建输入，不再生成 `android/build/reports`。

### 2026-09-11 商家分机 Android CitizenSDK 接入配置

商家分机 Android 产品流程在 CitizenSDK 原生双库完成后，于当前任务的 `dependencies/citizensdk/android/build.gradle` 生成唯一 Gradle 接入配置。该配置只通过 `CITIZENSDK_SOURCE_DIR` 加载 CitizenSDK 的真实 `android/build.gradle`；业务源码、Gradle脚本和资源保持原件只读。宿主 `settings.gradle.kts` 因而获得 Gradle 9.1 所需的可写插件 `projectDir`，CitizenSDK 插件构建目录、原生库和宿主输出仍分别留在本次 Android 缓存。

该准备发生在可见 Build 任务已经启动后的 TuyuBooking 产品入口中。Worker 不创建该投影、不检查 CitizenSDK 是否允许接入，也不因配置尚未生成而拒绝创建产品任务；产品脚本或 Gradle 的实际退出码仍是本次 Build 的失败事实。

真实任务 `619027796` 已生成上述单文件投影并完成 CitizenSDK Core/JNI/AAR，旧的“CitizenSdk Android task configuration has not been prepared”没有再出现。宿主 Gradle 随后因产品 Kotlin 2.2.10 低于当前 Flutter 最低 2.2.20 而停止；本轮没有绕过产品校验，没有生成 APK，也没有安装手机。
## 2026-09-11 本机生成状态清理

商家端产品源码不再保留 Flutter Linux/Windows ephemeral、旧 `target/.work` 插件链接、IDE 状态、PluginRegistrant 或 `.kotlin` 状态；本机 Build 只能在本产品调用方提供的规范源码外工作目录 生成这些内容。Gradle Wrapper保留为产品工具入口；本机pubspec_overrides.yaml已取消，所有环境只消费统一Git来源。
### Build与Start物理归属（2026-09-12）

本产品Build、CI和Release唯一实现位于产品scripts目录；TataConsole只按固定身份调用。Start由TataConsole启动产物库中的macOS成功产物，产品不实现Start。

- tuyubooking-host：
  - `tuyubooking.host-macos.build` → `tataconsole/console/tuyubooking/host-macos/build.sh`
  - `tuyubooking.host-windows.build` → `tataconsole/console/tuyubooking/host-windows/build.sh`
  - `tuyubooking.host-linux-arm.build` → `tataconsole/console/tuyubooking/host-linux-arm/build.mjs`
  - `tuyubooking.host-linux-amd.build` → `tataconsole/console/tuyubooking/host-linux-amd/build.mjs`
  - `tuyubooking.host-macos.start` → `tataconsole/console/tuyubooking/host-macos/start.sh`

- tuyubooking-client：
  - `tuyubooking.client-ios.build` → `tataconsole/console/tuyubooking/client-ios/build.sh`
  - `tuyubooking.client-android.build` → `tataconsole/console/tuyubooking/client-android/build.sh`
  - `tuyubooking.client-macos.build` → `tataconsole/console/tuyubooking/client-macos/build.sh`
  - `tuyubooking.client-windows.build` → `tataconsole/console/tuyubooking/client-windows/build.sh`
  - `tuyubooking.client-macos.start` → `tataconsole/console/tuyubooking/client-macos/start.sh`

## CI与Release入口归属

本产品CI与Release由所属仓当前`scripts/flows.json`的remote_routes及各平台Workflow声明定位，完整执行入口为本仓`scripts/flow.mjs`。控制台读取当前声明、创建原有真实任务、获取准确仓权限并跟踪原Run；旧控制台CI/Release Shell与Swift执行文件已删除，不作为入口。

## CitizenSDK统一边界复查（2026-09-15）

TuyuBooking Flutter主机与分机已直接依赖同一完整CitizenSDK，并通过`CitizenSdk.open()`、`wallet.create`、
`wallet.importWallet`等公开接口取得钱包、签名、交易和轻节点能力；没有产品侧SDK包装层，这一客户端边界正确。

服务端边界仍有偏差：`host/src/public_api.rs`直接依赖`schnorrkel`验证旅客与安装实例签名；本机管理员又经
路径依赖调用`tuyuserve/account`中的自建签名摘要和验签。TuyuBooking可以继续拥有报价、预订、安装实例、
挑战消费和授权规则，但密码学签名与验签实现必须由CitizenSDK提供的正式跨语言公开能力承担。当前只完成
设计审计和旧Cargo锁修复，尚未改写这些运行路径；不得宣称服务端CitizenSDK边界已经闭合。

## 独立 GitHub CI 与 Release 工作流

本产品每个实际产品、平台、流程身份使用下列独立文件，主 Job 为 `flow`；CI 验证源码，Release 生成正式产物，发布由塔塔控制台的独立 Publish 流程负责。

- `.github/workflows/tuyubooking-client-android-ci.yml`
- `.github/workflows/tuyubooking-client-android-release.yml`
- `.github/workflows/tuyubooking-client-ios-ci.yml`
- `.github/workflows/tuyubooking-client-ios-release.yml`
- `.github/workflows/tuyubooking-client-macos-ci.yml`
- `.github/workflows/tuyubooking-client-macos-release.yml`
- `.github/workflows/tuyubooking-client-windows-ci.yml`
- `.github/workflows/tuyubooking-client-windows-release.yml`
- `.github/workflows/tuyubooking-host-linux-amd-ci.yml`
- `.github/workflows/tuyubooking-host-linux-amd-release.yml`
- `.github/workflows/tuyubooking-host-linux-arm-ci.yml`
- `.github/workflows/tuyubooking-host-linux-arm-release.yml`
- `.github/workflows/tuyubooking-host-macos-ci.yml`
- `.github/workflows/tuyubooking-host-macos-release.yml`
- `.github/workflows/tuyubooking-host-windows-ci.yml`
- `.github/workflows/tuyubooking-host-windows-release.yml`

## 平台输入与源码外工程

tuyubooking/app/scripts/project.mjs为本产品唯一工程装配入口，project.test.mjs验证路径与隔离。create和verify明确接收source-root、work-root及platform；调用方可指定当前任务内output，默认按源码绝对路径装配，输出不得覆盖或进入源码。Flutter、Xcode、Gradle的可写配置保存在输出工程，源文件不被工具回写。

平台声明以Runner.pbxproj、Runner.xcscheme、ProjectWorkspace/Workspace声明等文件直接保存于ios或macos目录；单文件测试、单一macOS图标资源及菜单包装层归并。工程入口仅在本次工作根重建Xcode所需固定结构，原平台声明与资源正文保持。Android扁平Manifest、资源限定文件及MainActivity由同一入口还原原逻辑路径。Android Wrapper来自调用方明确指定的固定FLUTTER_ROOT原件，输出使用既定Gradle9.1.0；缺工具、缺输入、目标已存在或来源链接越界均失败。

页面Logo唯一源码路径为tuyubooking/app/tuyu_logo.png。CI和Release各自创建独立工作工程，后续签名只读取该工程产物；本机Build传入当前任务目录，产品不识别目录来源。SDK锁定Git依赖通过SDK自有公开Flutter工程入口提供本轮可写Pub视图。

商家client的application/domain/presentation和host的initialization/module_management单文件层已合并；模块名与业务行为保持。host/src/subsystems.rs、host/tests/support.rs直接承载原模块；五个测试crate在根保存lib.rs并显式声明Cargo目标。specifications/domains以领域名.md、fixtures以领域名.json保存，Frappe许可证为licenses/frappe-LICENSE。

Release工程路径先独立赋值，创建成功后才导出；工程创建失败必须保留退出码并立即停止。工程测试实际执行该赋值片段的成功与失败分支，不调用真实签名或发布。

Android的TUYUBOOKING_BUILD_DIR由本机调用方明确指定本轮源码外输出目录；Gradle产物和APK收口必须使用同一目录。产品既有独立运行默认值不变。本机App和适用的SDK原生步骤复用调用方已验真的Gradle可执行文件，执行失败必须传回，不经Wrapper重复下载工具。

## 上游系统目录保护边界

`tuyubooking/upstream/`保留已固定上游源码、官方必需结构、版权、许可及消费引用；PostgreSQL原件按现有固定官方归档进入唯一依赖库，产品打包只在源码外物化。自有代码目录整合不对这些上游系统实施迁出、删除或扁平化；上游内部单目录不计入本次自有代码整改的未完成项。

原生安装件装配到本次Pub实际解析的SDK视图。Apple框架来自同一锁定SDK的原生构建；Android双库及工作目录由本次回执提供；桌面只消费同版安装前缀。SDK Git原件、宿主声明与锁均保持只读，失败清理只处理本轮占有的目录。


商家四个主机CI从完整产品根读取Cargo和平台检查脚本，Pub锁定解析后调用app/scripts/project.mjs native把同一SDK原生件装入当前视图。主机Release及macOS/Windows/Linux独立完整打包器沿同一SDK入口，Rust/Postgres/Debian生成物写当前任务目录；原业务Runtime、包格式、架构、CI锚点及签名检查保留。source_paths.dart的显式来源直接指向完整商家产品根，不再拼接已退役聚合仓包装层。资源回收75失败保留现场，禁止外层继续删除工作目录。


### 主机与分机SDK原生准备的同一输入
四个分机CI与四个主机CI均通过app/scripts/project.mjs的prepareNativeProject消费正式声明与锁中的同一Git提交，不读取邻仓。原生安装件进入本轮Pub实际解析的SDK视图；SDK资源释放失败时返回75并保留准确任务工作目录，外层finally不得继续删除。已有平台、业务、包格式与签名检查继续执行。

本产品正式Release主flow Job实际创建GitHub版本，contents权限准确为当前仓write；辅助Job与其它权限保持原登记。源提交、成功CI、版本及资产验真不放宽，不派发发布。
## 完整产品组织与执行合同

所有者：`tuyubooking`，正式源码根 `/Users/rhett/tuyubooking`；本说明属于该完整产品。组件不会拆成独立仓库或目录产品。所有执行身份统一为 `产品.平台.流程`，单平台仅在控制台显示和物理目录中省略平台层。

真实平台目标：`host-macos`、`host-windows`、`host-linux-arm`、`host-linux-amd`、`client-ios`、`client-android`、`client-macos`、`client-windows`。

推送门禁唯一源码位于 `/Users/rhett/tuyubooking/.github/tatagate/`，GitHub入口 `/Users/rhett/tuyubooking/.github/workflows/tatagate.yml`。控制台先从本仓已保存提交执行这份门禁，通过后推送准确SHA；GitHub main push再执行同一提交的门禁，控制台核对所属仓、Workflow、main、SHA、Run和attempt，只有success并再次回查main一致才完成推送。失败、取消、超时或身份漂移均不得显示成功，不自动重试或派发CI/Release。

技术文档由所属完整产品仓根唯一持有；私有规则和任务库由控制台私仓持有，公开产品不读取它们。公开门禁不依赖私仓资料、安装包源码、其它本机产品或个人账号；必要链真源先锁定公开main的实际SHA后只读该SHA。本机开发跨产品验收仍比较三仓已保存快照与各端真实镜像。


### 门禁与开发审查职责

准确中文注释按开发阶段逐项复核，不以保留源码每文件包含汉字作为仓库门禁的开发凭证。初始完整内容、生成文件和上游原件保持原文；真实第一方临时注释、机密、源码输出、Workflow、依赖和适用测试仍由本仓同提交门禁验真。公民门禁只把scripts中的Node命令行结果报告识别为CLI输出；本仓实际执行测试的准确协议拒绝断言不属于新运行协议，字符串、注释、模板和未登记测试中的同文不豁免。保存及推送仍逐仓独立授权，并以本机门禁和同SHA的GitHub门禁双成功为唯一终态。


### 固定产物产品目录

控制台预先维护固定`target/tuyubooking`产品根；平台产物仍只在真实编译和验真成功后提交。目录不保存日志、测试、临时源码、中间物或占位文件。主机与分机启动按钮仅显示文字分别为“启动主机”“启动分机”，现有动作与脚本绑定保持。

机密扫描只排除内容严格为省略号且BEGIN/END类型匹配的完整PEM占位文本。Voyant的两个既有签名测试仅在准确文件路径允许各自已核实的公开/合成AWS访问标识，其它路径、同文件其它强特征、混入密钥正文或PEM类型漂移仍失败；不豁免上游或测试目录，错误只报告路径。候选来自原Git扫描，以NUL分隔并逐文件回读，候选读取失败即失败。

Windows保留PostgreSQL17.11的citext扩展与EnterpriseDB PLDebugger SQL原文，原有注释仅在准确两条路径且完整SHA-256一致时作为上游注释保留。citext与官方REL_17_11原字节一致，PLDebugger与官方1dd9a9abfc65e6e905f61ff2731f871500f9b82a仅原Windows换行差异；源文任意字节或路径漂移均失败，不豁免整份运行时目录。

## 产品介绍与开源许可

根目录 `README.md` 仅提供本产品简明介绍，不承载技术方案、任务记录或验收结论。独立自有代码采用根 `LICENSE` 的MIT；上游代码、衍生修改、依赖及组合分发遵循各自原许可、版权、例外与附加要求。
Frappe为MIT，ERPNext/HRMS为GPL，Kamra/URY为AGPL，Voyant为Apache；Hi.Events保留AGPL及网页页脚、邮件的署名和链接要求。准确源码与许可路径由现有sources清单登记，MIT不覆盖这些要求。


### 组织重构后的TLS最终合同

公网TLS统一由Cloudflare Edge承载；商家主机与分机的局域网连接保持严格HTTPS/WSS。本机反向代理只接受准确模块的HTTPS loopback来源，不允许用户信息、查询、片段、路径越界或明文来源；上游请求和WebSocket升级均使用受信模块证书，并强制验证证书与主机名。缺少、损坏、过期或不匹配的证书必须失败，禁止关闭验证或退回HTTP。

Hi.Events的Nginx、SSR及SSR到API的本机HTTP语义连接全部使用HTTPS；Nginx对SSR验证证书，Node通过显式受信证书验证API。Voyant编译为官方node_middleware入口，由本产品的tuyu_voyant_https.mjs提供本机HTTPS及受保护的WebSocket升级。两个模块的外层代理也验证受信证书。员工网关只加载同一安装数据根中准确模块的公开证书，绝不读取或转发模块私钥。

安装TLS身份已存在时必须保留：证书或私钥缺失、损坏、配对不一致直接失败，不重建另一身份。首次生成仅限本地私有数据目录；不会把LAN身份当成公网Edge证书，也不会把私钥或其摘要写进代码、任务、日志或测试结果。

商家所有公开来源以tuyutata准确fork及固定提交为准；模块注册校验同时核对准确仓库、完整小写40位提交和所属upstream路径。主机Rust账户依赖由准确HTTPS Git提交取得，不再读取相邻产品工作树。

来源清单的必需上游README原文按准确提交保留，不作为第一方技术文档副本。Voyant来源清单、模块及运行锁统一到现有源码所消费的ea7f1b1f858650ebcf3e66ae215d82d1ff09424f；不会改取最新上游或把来源核对当作业务验收完成。


### 本机Build代码所有权

本产品的scripts/flows.json声明自身平台、准确工具版本、原始锁以及既有CI/Release入口；scripts/build.mjs独立实现requirements、prepare、build三个阶段，拥有工程准备、编译命令、候选验真和失败条件。产品只消费调用方交付的公开资源回执，按本仓原始锁取得依赖，所有生成状态进入规范源码外工作目录。平台或资源身份不符、版本错误、缺锁、链接越界、归档摘要错误、旧工程复用或编译器失败均立即失败。

来源一致性：Frappe框架模块、源码清单与运行锁统一为既有efe1520babc9ed31be11a38fbad34c62188deb8d，Voyant统一为既有ea7f1b1f858650ebcf3e66ae215d82d1ff09424f；来源接入回归逐项核对固定提交与模块仓库，不把ERPNext/HRMS依赖误认为URY主源码。清单必需的五份上游README保留官方原文，属于上游源码说明，不增加第一方技术文档副本。

PostgreSQL原件清理边界：Windows 17.11-1官方归档的URL、340719294字节及SHA-256由scripts/windows-x86_64/postgresql.runtime.lock.json固定。与官方归档完全一致的1518份代码、SQL、测试和文档由唯一依赖原件保全；唯一已改过的PostgreSQL测试工具完整保存在scripts/windows-x86_64/PostgreSQL-Test-Utils.pm并由既有打包器交付。52份既有法律资料完整移到licenses根的postgresql__文件，依照既有macOS许可锁分组并由postgresql-MANIFEST.sha256逐字节验真；源目录和旧清单退出源码消费，来源事实与原始清单保全于唯一任务卡，不保存第二运行时副本。

PostgreSQL集成测试必须显式接收TUYU_POSTGRES_BIN，要求完整且无链接的源码外bin目录，禁止按平台回到旧发行件目录；Windows源码验真入口接收同样的物化目录，独立验证PE32+、x86-64、导入闭包、PostgreSQL版本及最终完整摘要清单，禁止搜索LLVM、写版本临时文件或把原件验证当真实运行成功。

业务模块与员工网关的就绪探针使用本安装的 Python TLS 客户端，连接本机 127.0.0.1，按准确模块 tls/localhost.crt 和配置主机名完成 TLS 1.3 握手。仅TCP监听、明文响应、错主机名、缺失或损坏证书均不得进入 Ready；探针两秒超时后终止并回收。该就绪状态只证明受信 TLS 接口可连接，真实业务登录与页面验收仍按各模块执行。

员工网关 HTTPS 与 WSS 转发统一要求 TLS 1.3、受信 CA 与主机名校验。既有运行时回归以真实 TLS 后端和 TLS 网关执行 WSS 升级、握手摘要及掩码帧往返，并验证不可信证书、错主机名和明文上游不能得到 101；测试只使用系统临时身份，不输出私钥。

Windows PostgreSQL运行时在写入完整MANIFEST.sha256后，用显式Node调用所属verify-source.mjs，完成真实PE架构、DLL依赖闭包与清单全量校验；验真失败禁止输出交付成功。


macOS PostgreSQL固定为17.11。所属scripts/macos/postgres-dependencies.mjs从现有许可锁导出六份官方源码归档及三份Readline官方context补丁：krb5、ICU、Readline、lz4、zstd和PostgreSQL进入唯一依赖原件库；Gettext、OpenSSL、Perl、Tcl、Bison、Flex与M4作为工具从工具库交付，不在依赖库保存第二份工具归档。原件物化、源码解包、静态库编译和PostgreSQL生成都位于本产品本轮源码外缓存，产物库只接收最终编译验真的完整产品包。

postgres-runtime.mjs要求调用方明确交付规范绝对工具路径、同一Xcode SDK、固定原件目录及新工作根；缺项、链接越界、摘要错误、非ARM64、依赖缺失、同名动态库冲突或编译失败直接失败，不搜索系统或Homebrew。保留既有NLS、Bonjour、GSS、ICU、LDAP、XML、XSLT、LZ4、OpenSSL、PAM、PL/Perl、PL/Tcl、UUID及Zstd能力；UUID由Apple SDK与上游已实现的libc路径支持，不新增e2fsprogs。库只接受显式闭包来源，包内动态链接改为相对位置并在修改后签名；最终版本和文件摘要必须回读。

PL/Perl的纯模块、架构模块及官方COPYING、Artistic全文随运行包保留；纯模块树排除已单独交付的架构子树，避免重复副本。主机子进程清除宿主Perl注入，仅在macOS按同一运行包的share/perl/pure与share/perl/arch建立模块路径；模块缺失直接失败，并在写初始化临时口令前核验。PL/Tcl继续使用所属Apple SDK的既有框架数据，受控Tcl只提供编译配置探测。原有数据库、模块业务、平台能力与许可原文保持。

旧的PostgreSQL缓存指纹只覆盖一个入口脚本，会漏掉工具、锁和补丁；主机打包移除该复用路径。每轮按完整闭包编译，原件仍可由唯一依赖库复用。受控交付及候选补丁不等于编译、PL扩展或真实主机运行验收成功。

主机 CI 的数据库测试输入由产品脚本 `scripts/host/postgres-runtime.mjs` 统一验真：仅消费源码外 PostgreSQL 17.11，同步核对完整文件清单、摘要、核心程序架构与真实版本输出。已交付运行包直接消费，不重复取件；缺少输入时只能通过所属产品的编译入口交付。macOS 编译要求显式提供既定工具及锁定原件，Windows/Linux 要求交付准确解释器入口；缺失直接失败。macOS、Windows Release 将此同一运行包纳入安装资产；Linux 的 deb 只读取本次源码外工作目录。输入边界单元测试使用二进制头测试替身，仅证明拒绝条件，不替代真实数据库验收。

macOS业务运行包禁止由Homebrew自动选件：只消费显式交付且来源已验真的编译组件，缺失即失败。OpenSSL来自既定受控工具交付，Python调用使用准确入口。商家PHP/PCRE2、厂家libffi/Pango的实际编译组件仍须在真实Build前完成来源和可用性验真；未完成交付不能判定真实Build通过。

## 准确Git工具交付方案（2026年10月6日）

固定源码工程入口已改为只接收显式 PRODUCT_GIT_BIN：普通可执行文件、规范绝对真实路径和 Git2.54.0 在读取来源前一起核验。来源、固定提交、干净原件、原始锁只读及无 override 合同保持；缺少交付或出现路径、版本漂移即失败。公开环境自行按本仓入口交付固定工具，本机可读取现有验真工具原件，不依赖控制台私有路径。

最终冻结差异已获第二次确认并写入，保持本产品原有正常、失败、隔离和清理回归；正式来源与工程独立回归8项通过；两项Release真实Shell片段回归仍需正式GNU基础交付。准确授权和实际结果同步唯一任务卡。

工程测试的既有Release赋值片段已改用显式PRODUCT_BASH_BIN，在执行前核验真实普通入口与GNU Bash5.3.20；成功/失败分支、退出码及后续导出顺序不变，不执行正式Release。此测试输入沿用本仓实际公开工具字段，不引用其它仓库实现。

## MLS统一清理固定来源与当前验收状态

CitizenSDK当前统一固定提交为3e53f18354e1b21c75d7e4543f2102ba8163c575；CitizenApp、TuyuLove、TuyuBooking/app与TuyuFactory/app的8份声明/锁已经同步，离线原件来自该真实保存提交及登记Git bundle。当前SDK公开Core为144项、Apple总导出148项、Flutter方法93项；旧用途钥API、结果和二维码响应已删除。MLS登记保持0x1C及同一32字节public_key，客户端钱包私钥之外只保留MLS协议秘密。

本轮源码、注释、测试源码与实际接口说明已经同步；此前测试记录不能证明本轮新快照通过。统一测试及已签名Release真实验收尚未完成，未推送或部署。


### 产品独立资源与编译入口

本产品的scripts/flows.json声明自身平台、准确工具版本、原始锁以及既有CI/Release入口；scripts/build.mjs独立实现requirements、prepare、build三个阶段，拥有工程准备、编译命令、候选验真和失败条件。产品只消费调用方交付的公开资源回执，按本仓原始锁取得依赖，所有生成状态进入规范源码外工作目录。平台或资源身份不符、版本错误、缺锁、链接越界、归档摘要错误、旧工程复用或编译器失败均立即失败。

本产品平台闭集为`host-macos`、`host-windows`、`host-linux-arm`、`host-linux-amd`、`client-ios`、`client-android`、`client-macos`、`client-windows`。调用格式为`node scripts/build.mjs <requirements|prepare|build> <platform> --work <绝对工作目录>`；requirements只读并输出唯一JSON，prepare/build从标准输入读取schema=1的资源回执。调用方交付准确工具执行器、锁定依赖目录、Git来源和归档后先prepare，再读取展开来源新增的需求，完整交付后执行build。准备、展开和编译属于同一调用工作根，各平台互不共享可写状态。独立调用方按本仓声明准备资源即可运行，无需读取其他产品工作树或私有资料。

Git依赖只接受本仓声明与锁一致的HTTPS地址及40位固定提交；原生归档只接受本产品锁定坐标及完整SHA-256。工程副本排除旧生成物，内部文件链接重映射到同轮副本，外部链接与已有工程拒绝。原始依赖缓存必须显式交付，不能落入用户默认缓存；离线编译禁止隐式取得缺失资源。已有CI/Release Workflow仍各自调用本仓scripts，不受本机可视化入口是否存在影响。入口回归由本仓`scripts/build.test.mjs`负责，适配与资源服务的验证不替代产品编译和真实候选验收。


## 2026-10-06 产品自主资源阶段（第2步）

本仓`scripts/resources.mjs`拥有工具准确来源/版本/配方、递归锁解析、缺失获取、验真、复用和本轮依赖准备；`scripts/build.mjs resources <platform> --work <绝对外部工作根>`调用同一实现，独立入口为`resources.mjs <platform> --work <工作根> [--offline]`。前者从stdin读取公开身份回执；后者允许空请求。最小宿主必须使用本仓声明的官方Node25.2.1绝对入口，本机配方限定macOS ARM；资源阶段回读官方发行归档与运行Node字节，不能从PATH取同名程序。工作根预先存在、位于源码外且不经过链接。

可选`PRODUCT_TOOL_ROOT`只供读取工具原件，`PRODUCT_DEPENDENCY_ROOT`只供读取依赖原件；产品不读取供给者的版本决策或私有任务变量。独立缺省原件库为源码外`~/.local/share/product-resources`，本轮可写状态仅在work。GNU Bash/grep/sed纳入自身需求；发行件旧Shell仅用于声明中的首次GNU构建，不进入正式PATH。下载/源码工具编译不持全局锁，最终不可变对象提交使用短锁，取消传递到工具进程组。错误摘要、损坏、未锁来源、路径越界和显式离线缺失失败并保留可疑原件。

Pub/npm/Cargo按原始锁准备；Git按固定HTTPS提交检出，Git Cargo目录源展开workspace继承并锁定相对包版本；CocoaPods按准确锁摘要恢复验真快照，缺失spec校验规范摘要，未锁源码来源拒绝取得。Android固定包与修订归产品；额外平台仅消费官方固定发行来源与发行树摘要，不借宿主历史SDK目录。Maven供给只读验真后复制到独占Gradle缓存，由产品准备现有配置，消费仍离线；全库坐标导入与旧目录清理留到第5步。

`PRODUCT_WORK_DIR`、`PRODUCT_BASH_BIN`、`PRODUCT_RSYNC_BIN`及`PRODUCT_SOURCE_DIR`是公开工作/工具/工程入口；Flutter修订不读取调用方私有变量，也不回退系统rsync。旧Flutter补丁对象与当前配方不符时拒绝复用，真实替换须按准确资源操作另行授权。本步不改变编译、签名、安装及回读顺序，不修改产品UI，也未执行真实工具下载/安装。受控资源测试不能代替官方首次取得、正式编译或最终真实运行验收；第4至7步仍待逐步确认实施。

资源原件按完整内容验真后整体提交：Git bundle与固定来源/摘要回执处于同一个不可变对象，不暴露中间状态；可选依赖供给读取`objects/<SHA256>.blob`。锁解析器、源码工具依赖与官方有序补丁也从同一产品原件存储复用。Pod spec每次按锁中的规范checksum回验，Git tag只核对发行声明并消费本产品预锁提交；HTTP发行件消费固定SHA256，首次源码准备命令来自该已验真spec并由GNU Bash执行。spec、准备后源码与文件清单整体提交，再复制到本轮缓存；供给索引不决定产品版本。正式PATH排除旧POSIX Shell，`sh`对应已验真的GNU Bash。

独立缺省资源目录内`tools`保存工具发行件及工具编译输入，`rely`保存产品依赖的归档、Git和Pod原件；工作区只承载本轮可写视图。根据用户最新要求，分步骤先完成实现与用例，整项解耦任务完成后统一测试；本步实施记录不等于真实工具首次取得、完整Build或安装验收通过。


### 第3步：产品完整Build入口（2026-10-06）

本产品的正式完整入口为已锁定Node的绝对路径调用`/Users/rhett/tuyubooking/scripts/build.mjs execute <platform> --work <已存在绝对工作根>`，可选`--offline`。输入stdin可为空；调用方可传schema/product_id/platform/work及真实run_id/program_digest，禁止私有变量或执行命令。入口内部完成需求→资源→准备→再次需求/资源闭包→编译→适用签名/安装/回读；独立与控制台调用同一实现。最小引导Node只启动本产品的资源引导器，产品按自己的官方Node声明验真、准备并重入，控制台运行Node不决定产品Node版本。

标准输出只有唯一有界JSON：schema、product_id、platform、work、completion、files及可选真实run_id。completion沿用固定平台的device-install/macos-artifact/compile-only；files按本产品flows.json登记路径和SHA256。编译日志使用stderr进入现有任务日志，不新增资源任务或任务状态。完整结果只在各阶段成功、源码/锁不漂移、工具进程确认退出后落入本轮build-result.json；同根并发或复用旧结果拒绝，取消/失联/错误身份/损坏候选不得成功。

控制台每次Build直接读取本产品当前flows.json入口，调用一次execute；控制台只跟踪真实任务、核验公开结果和保存产物，不解释产品工具、依赖、编译参数或设备规则。当前控制台静态菜单、其它产品流程/安装器与程序摘要的历史耦合仍归第4步解除，本步不能当作整项解耦已完成。

Android开发材料读取和仅首次创建可由专用PRODUCT_HOST_FD=3提供，原生端仅保管既有DEV_KEY；产品自身负责材料解析、工具、临时密钥、Release包签名、证书/版本核对、先直接USB安装以及多USB分支逐台安装回读。独立调用由产品自己的Keychain保管开发材料。材料不写入公开结果或日志，临时密钥只在工具确认退出后删除。iOS归档由产品解包并验证唯一Runner.app、原始Release配置、Apple签名profile、团队/设备授权、代码签名和entitlement，再完成主动真机探测、防降级、安装及bundleVersion回读。控制台不再包含LocalMobileTask/MobileSecurityManager执行链。

产物保持固定android.apk/ios.app.zip；控制台通用artifact能力在产品验真后、设备安装前保存候选，保存失败阻止安装，安装失败不伪造成功。iOS profile/entitlement原生用例迁入本产品Swift验真器测试；统一验收须显式交付产品锁定Xcode的PRODUCT_TEST_SWIFT及PRODUCT_TEST_DEVELOPER_DIR，缺失时测试失败，不静默跳过。

本步同步完整入口、失败/取消/并发、结果/路径/摘要及适用移动端用例，但未运行测试、语法检查、编译、签名、安装或工具下载/替换；全部实现步骤完成后统一验收。源码交付与用例存在不代表真实Build已经通过。


### 第4步实施中：远端路由当前声明

CI/Release的规范身份、标题、版本前缀和正式版本记录标志已迁入所属仓现有scripts/flows.json的remote_routes。调用方按固定已接入动作重读当前声明；原生授权与流程查询不再使用编译期产品路由常量。产品声明只提供数据，不授予凭据、扩大平台矩阵或新增按钮。损坏、重复、越仓、字段越界及超限拒绝。

本次同步路线读取、热更新和失败边界用例，未运行测试、语法检查、编译、签名、安装或下载。第4步仍在开发中：Publish执行器、聊天安装器、Start、固定菜单声明与完整程序摘要的其余实际耦合尚未解除，不能报告该步或整项任务完成。


第4步Start实施：既有5个macOS启动动作已调用所属产品当前scripts/flows.json登记的scripts/start.mjs。产品准备自身准确Node、受控POSIX与Apple工具，验证成功App与真实可执行文件、候选摘要和声明，再启动；调用方仅传成功产物规范路径并通过PRODUCT_RESULT_FD接收单一有界公开结果。启动目录使用产品源码外临时目录，不建控制台Start缓存。公民链保留已有节点窗口激活顺序，首次启动才准备当前17.11 PostgreSQL，原开发数据路径、端口、TLS及内嵌前端参数仍由产品保持；无需控制台或Homebrew。此处描述源码实现，尚未执行用例或真实启动，第4步仍未完成。

### 产品远端完整入口

本仓`scripts/flows.json`的`flow_entry`定位公开`scripts/flow.mjs`。`run ci <platform>`和`run release <platform>`分别执行同一产品流程，当前读取本仓Workflow与路由；Release的`version_source`声明准确版本文件类型和相对路径。成功CI选择、同源候选复用、版本递增、正式Release验真与旧Run/Artifact清理均由本产品入口完成。独立执行只需等价的本仓短期GitHub权限；没有宿主控制管道时入口自行跟踪Run，不依赖其它产品程序。

可选`PRODUCT_CONTROL_FD=3`只接受当前Run绑定确认、候选持久化确认和二值远端终态；令牌仅进入HTTPS请求头，未知身份、越仓、无成功CI、候选错源、控制帧错误、超时或取消均失败。宿主重启后的`recover`使用同一公开入口核验原Run、原候选并清理，不重新派发。公开控制协议不携带私有调用方变量，现有授权及用户操作顺序保持。源码、声明或Workflow在本次流程期间变化将拒绝继续。

相关正常、失败、身份、版本来源、独立远端跟踪、候选重试和真实控制管道边界用例位于本仓`scripts/flow.test.mjs`；当前只完善源码，尚未运行用例或远端操作。

本机固定菜单不再登记Start源码与产物，也不保存Build产物文件名或验真相对路径副本。执行时读取所属产品当前Start声明及Build的files、verificationPath；产品修改自己的App名称或可执行文件路径无需重编译菜单，原有平台完成方式及产物摘要收口保持。相关用例已同步，尚未运行。


### 产品软件记录与正式版本恢复

本仓公开`scripts/flow.mjs records`使用准确同仓短期GitHub权限，重读本仓当前路由，复用远端流程同一Run保留器并确认实际删除，再读取各平台最新正式版本。来源合同归本仓release.record_source：按实际产品选择Tag、单包正文或正式元数据资产验真，标题、版本、源码与适用不可变标志不能由调用方推测。准确元数据资产仅经官方HTTPS地址读取，跨主机不转发仓库令牌。正式资产和Tag不会在记录刷新中删除。公开结果仍是records/removed_run_ids，原记录页行为保持。

`recover`不重新派发；重新核验原候选、成功CI、原Run终态、正式资产来源与Tag，输出formal_release/removed_run_ids。控制调用方仅绑定原任务身份、原候选和产品公开回执，更新现有持久发布目标；产品验真算法不再随调用方程序编译。相关正常、失败、错资产/正文/来源、重定向隔离、独立记录刷新和恢复用例源码归本仓flow.test.mjs。

资源工具取消、超时、输出超限和异常收尾均等待主进程与整个后代组退出；无法确认退出时保留工作根和候选，禁止删除输入或改为可写。真实取消退出顺序用例仅写入resources.test.mjs，尚未执行。


### 发布实现范围

本轮新增产品发布实现已撤销，发布功能由后续逐个产品重建。现有操作入口与界面保留，当前不提供已删除实现的执行保证；Build、CI、Release和Start继续按各自现有入口运行。


### 产品独立资源与唯一依赖供给

本产品的scripts/resources.mjs拥有资源解析、来源与摘要验证、缺件取得、可写视图和失败条件。PRODUCT_DEPENDENCY_ROOT是可选只读供给；没有供给时使用源码外的本产品原件存储，产品需求仍只由当前源码、声明和锁决定。依赖索引读取仅接受schema_version=2及packages、git_sources、pods，不恢复旧目录或整锁快照。

Maven的具体JAR、AAR、POM、module及分类器文件统一由packages的group:artifact、version、准确上游URL、SHA256和SRI定位objects中的原件。产品在本轮work/dependencies/maven按上游分区复制独占文件；不复制Gradle二进制元数据、锁和下载状态。产品生成本轮GRADLE_USER_HOME/init.d初始化脚本，只在自身已声明的同源仓库之前加入本轮原件视图，缺件仍按产品原仓库解析，明确离线则失败。Gradle解析、工程状态和后续编译都属于同一产品任务。

Pod由pods中的name、version、checksum匹配当前Podfile.lock；spec保存官方CDN地址和原件摘要，source保存官方podspec来源，files保存发布树相对路径、文件内容摘要与权限或安全内部链接。只物化本产品所需的单个发布坐标；其它Pod、整锁、平台或宿主变化不要求复制全树。产品仍按CocoaPods官方规范回验SPEC CHECKSUMS，再验证本产品预锁定Git提交或HTTP发行摘要与源码回执。可写缓存和工具VERSION仅在本轮work产生，不能写回共享原件。

错来源、摘要、重复同源内容、生成状态、硬链接、内部链接越界或循环、取消及任务副本漂移均据实失败。独立与控制台调用使用同一实现；控制台只提供可选原件并跟踪原有任务，UI、功能、按钮、平台与操作顺序保持。用例源码已同步，执行留待整项实现结束后的统一测试。


### 独立入口回归验真边界

资源回归使用自带固定提交、源码字节和spec的合成Pod，不借用产品真实Pod清单提供测试输入；无真实Pod需求的平台也验证来源、摘要、链接、循环、取消和物化失败。测试现场仍位于本产品target的准确平台，不写源码或其它产品目录。资源声明与生产依赖坐标不因测试夹具改变。

Start只接受当前产品声明所对应平台target内的真实App目录；拒绝源码、其它平台和链接候选。产物验签、声明及可执行文件回读、前后摘要、取消处理和原启动顺序保持。

Apple验真器回归显式使用已验真的锁定Xcode及其SDK；官方swift入口允许包内链接，但规范目标必须属于同一Xcode且为有执行权限的普通文件。不得因此借用PATH或另一套工具。

requirements公开只读入口等待异步PostgreSQL归档计划完成，再输出带产品、平台和完整资源需求的唯一JSON；未知平台或缺少原锁仍失败，不写工作根。

资源取消对同一真实进程组每轮只发送一次信号；组不存在或Windows时才发送给主进程。仍等待主进程和后代实际退出，8秒未退出才强杀，12秒仍未确认则保留现场并失败；取消不能成为成功。

Apple验真器测试由同一锁定Xcode的swiftc编译实际XCTest Bundle，使用该包随附XCTest框架与Swift overlay，再由同包xctest执行；必须回读5项测试全部成功，空测试套件不得算通过。Bundle、模块缓存和临时输出仅归本产品target准确平台。


### 门禁官方归档字段与平台命名边界（2026-10-07）

平台禁用值继续来自本仓既有门禁登记。仅scripts/resources.mjs的唯一规范toolDefinitions声明内、唯一Flutter工具的archive.url可以按对应数字版本核对官方稳定版macOS归档；source、root和executable必须匹配原有官方坐标。识别后仅从平台扫描输入移除该URL，原资源源码、工具版本、来源及依赖锁均不修改。重复声明、重复键、转义或不可解析字面量、错版本、错来源及错形字段不予豁免；其它工具、字段、源码、注释和目录中的旧平台标识继续拒绝。

既有门禁测试覆盖本仓真实资源声明、官方字段、伪造来源和字段、歧义字面量、额外源码、旧平台注释与目录；全部夹具只在本产品target真实平台测试目录生成，并在finally清理。工作树诊断与绑定已保存提交SHA的正式门禁分别记录，不能将缺少Git跟踪文件的工作树冒充正式通过。

根技术文档机密扫描补齐既有validateSecrets所需hasSecretMaterial；识别原文、密钥正文、令牌、JSON键值、再次序列化字符串和既有补丁快照，格式说明不冒充真实凭据。结构不可解析或实际材料命中继续失败；实际入口只报告路径。回归使用合成正文，不输出真实材料。

当前完整门禁回归14/14通过，失败/取消/跳过/待办均0；本仓真实根技术文档、机密扫描及平台命名检查通过。完整资源源码和补丁边界、既有链接/临时目录/根文档夹具的失败已消除。测试及工作树检查不代替绑定已保存提交SHA的正式门禁，也不代替产品真实Build、签名安装及启动验收。本轮自有日志与夹具在结果记录后按原规则删除。


### 补丁原上下文与测试夹具边界（2026-10-07）

平台扫描只对scripts/resources.mjs中唯一规范flutterPatch JSON字面量执行原上下文识别：补丁登记字段严格为path、sha256、source；path为flutter.patch，source为Flutter官方固定40位提交，正文首行固定来源必须一致，全文SHA-256必须匹配本仓登记。仅当native_assets_host.dart准确文件、hunk及lipoDylibs邻接上下文唯一匹配时，从扫描副本移除那一行已核对的上游原注释。实际资源源码和补丁正文不修改；其它补丁行、源码、字段和目录继续完整扫描。错误来源、摘要、重复声明、非规范转义、上下文漂移和新增旧平台文字均不豁免，不跳过整段补丁。

既有门禁夹具以unlinkSync删除测试目录中的链接自身；测试临时目录仅调用本仓唯一testRoot，无旧API别名。机密扫描夹具生成本仓必需的合成根文档，原文档检查及拒绝断言保持。补丁正常、错源、错摘要、错形、重复、上下文外残留等边界同步在既有test.mjs，现场在本产品target内并由finally清理。补充实现后的统一门禁验收已通过，正式提交门禁及产品真实Build/启动验收仍待完成。


本产品scripts/build.mjs的模块初始化与CLI执行分离：私有异步runCLI承载原命令主体，仅在直接执行文件时启动，拒绝时输出错误并以退出码1失败。模块求值先完成，scripts/resources.mjs可反向导入同一checkWork、requirements和平台校验，不复制实现或增加启动入口；普通import不启动CLI。现有公开参数、JSON请求、--offline、锁定Node验真和必要重入、资源/准备/编译/适用签名安装回读步骤以及取消与结果合同保持。离线缺件和非法输入必须真实失败，禁止以未完成顶层await退出替代完整结果。对应真实CLI回归只在自有target测试现场替换资源供给边界，验证反向导入、参数与错误传播，不据此声称实际产品编译通过。


本产品scripts/resources.mjs的普通inventory清单保持独占文件要求；工具原件toolInventory复用同一扫描实现，只允许全部真实名称均位于同一规范payload内的硬链接组。扫描按dev/ino分组，实际名称数量必须与nlink闭合；工具普通文件以O_NOFOLLOW打开，打开及读取后复验身份、计数、权限和字节相关元数据，扫描结束再回读全部目录、文件及链接身份与规范目标。原件外额外名称、目录或链接越界、特殊项、读取期间替换/权限/内容变化均失败。清单仍逐路径保留原有path/sha256/executable或directory/target格式，继续由既有回执、准确官方归档/版本、配方和编译输入证明验真；regular与其它资源默认独占校验不放宽。不新增公开命令、参数、声明字段或原件登记，不改版本、锁、配方和工具原件，不以拆分内部链接、重新安装或下载解决验真。回归复制本仓完整实现到所属target测试现场，仅替换文件IO边界以确定性制造读取变化，并在夹具内暴露已有私有验真函数；纯合成对象覆盖正常、拒绝与回执漂移，不据此宣称真实工具或产品编译通过。


本产品资源验真将下载运输元数据与源码工具编译身份分开：仅在源码工具证明和本产品声明的比较副本中，验证并移除archive.mirrors与upstream_patches各项mirrors。镜像须为非空、无重复、无控制字符/空白、无账号/口令/片段的准确规范HTTPS地址数组；错误格式直接失败。官方来源URL、版本、归档字节摘要、kind/root/executable、补丁来源/摘要/顺序、前置与依赖闭包、其它位置同名字段及未知字段继续严格比较。Xcode/POSIX输入、recipe.source和source.archive/source.gem摘要、原回执清单及入口独占规则不变；比较不改写原证明、声明或回执，不改变原件/登记/配方/版本/锁和实际下载策略，不读取控制台登记作为产品版本或策略来源。既有回归使用完整本仓资源实现及纯合成物理证明，逐次重算清单，验证运输差异可复用与真正输入漂移必须失败；测试不启动工具或冒充真实编译交付。
