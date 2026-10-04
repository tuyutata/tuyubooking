// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => '途遇商家端';

  @override
  String get brandMark => '途遇 · 商家';

  @override
  String get merchantConsole => '途遇商家端';

  @override
  String get merchantLoginTitle => '管理员扫码登录';

  @override
  String get merchantLoginSubtitle => '扫码签名，安全登录。';

  @override
  String get signInAction => '扫描请求';

  @override
  String get signInError => '管理员签名响应验证失败，请生成新挑战后重新扫码。';

  @override
  String get localSigningHint => '私钥始终保留在手机。';

  @override
  String get initializeAdministratorTitle => '初始化途遇商家端';

  @override
  String get administratorName => '管理员姓名';

  @override
  String get optionalField => '选填，最多 30 个字符';

  @override
  String get scanAdministratorPublicKey => '扫描管理员公钥二维码';

  @override
  String get publicKeyScanInstruction => '请将手机显示的 TUYU 管理员公钥二维码对准本机摄像头。';

  @override
  String get scanSignatureResponse => '展示签名码';

  @override
  String get signatureResponseInstruction => '将手机上的签名二维码对准摄像头。';

  @override
  String get cameraPreparing => '准备摄像头';

  @override
  String get cameraScanning => '对准签名二维码';

  @override
  String get signatureResponseRecognized => '正在验签';

  @override
  String get cameraUnavailable => '无法使用本机摄像头。请检查系统相机权限和摄像头状态。';

  @override
  String get newLoginChallenge => '刷新二维码';

  @override
  String get privateKeyNeverStored => '私钥始终保留在手机。';

  @override
  String get administratorManagement => '管理员管理';

  @override
  String get administratorPolicySummary =>
      '所有管理员权限相同，最多 99 名，并始终至少保留 1 名启用管理员。公钥不能修改。';

  @override
  String get addAdministrator => '新增管理员';

  @override
  String get renameAdministrator => '修改姓名';

  @override
  String get deleteAdministrator => '删除管理员';

  @override
  String get deleteAdministratorConfirmation =>
      '删除会移除该管理员的本机登录权限，但审计记录会保留。确认删除吗？';

  @override
  String get unnamedAdministrator => '未填写姓名';

  @override
  String get currentAdministrator => '当前管理员';

  @override
  String get administratorOperationFailed => '管理员操作失败，请检查当前管理员状态后重试。';

  @override
  String get cancel => '取消';

  @override
  String get confirm => '确认';

  @override
  String get startingLocalService => '正在启动商家私有本地数据服务...';

  @override
  String get startupError => '商家本地数据服务启动失败。';

  @override
  String get retry => '重新启动';

  @override
  String get homeHeadline => '一个商家端，统一经营全部业务';

  @override
  String get homeSubtitle => '安装包包含全部业务系统，运行时只启动当前商家启用的系统。';

  @override
  String get manageBusinessModules => '管理业务系统';

  @override
  String get businessModuleSelectionTitle => '选择经营模式';

  @override
  String get businessModuleSelectionSubtitle => '可多选，稍后可启用或停用。';

  @override
  String get businessModuleRequired => '至少选择一个经营模式。';

  @override
  String get saveBusinessModules => '开始使用';

  @override
  String get businessModuleUpdateFailed => '经营模式配置保存失败。';

  @override
  String get moduleStatusDisabled => '已停用';

  @override
  String get moduleStatusMissing => '运行件缺失';

  @override
  String get moduleStatusInstalled => '已安装';

  @override
  String get moduleStatusStarting => '启动中';

  @override
  String get moduleStatusReady => '运行正常';

  @override
  String get moduleStatusDegraded => 'HTTPS 不可用';

  @override
  String get moduleStatusFailed => '运行失败';

  @override
  String get moduleStatusStopping => '停止中';

  @override
  String get moduleStatusStopped => '已停止';

  @override
  String get moduleStatusUnknown => '状态未知';

  @override
  String get restartModule => '只重启此子系统';

  @override
  String get employeeAccessTooltip => '员工设备访问';

  @override
  String get employeeAccessTitle => '员工局域网访问';

  @override
  String get employeeAccessSubtitle =>
      '由管理员控制是否通过一个局域网 HTTPS 地址开放全部运行正常的业务子系统。';

  @override
  String get employeeGatewayDisabled => '局域网访问已停用';

  @override
  String get employeeGatewayStarting => '正在启动安全局域网访问';

  @override
  String get employeeGatewayReady => '局域网 HTTPS 访问已就绪';

  @override
  String get employeeGatewayFailed => '局域网 HTTPS 访问启动失败';

  @override
  String get employeeGatewayStopping => '正在停止局域网访问';

  @override
  String get enableEmployeeAccess => '启用局域网 HTTPS 访问';

  @override
  String get disableEmployeeAccess => '停用局域网访问';

  @override
  String get employeeAccessAddress => 'HTTPS 地址';

  @override
  String get certificateFingerprint => '证书 SHA-256 指纹';

  @override
  String get employeeAccessRoutes => '业务访问路径';

  @override
  String get employeeAccessDiscoveryHint =>
      '分机首次初始化会自动连接本机并保存固定局域网地址，之后每次启动直接连接，无需二维码。';

  @override
  String get employeeAccessSecurityHint =>
      '子系统内部端口只允许本机访问，员工身份仍由 Kamra、URY、Voyant 或 Hi.Events 原有账户体系验证。';

  @override
  String get employeeAccessOperationFailed => '员工局域网访问操作失败。';

  @override
  String get employeeAppTitle => '途遇商家员工端';

  @override
  String get employeeDiscoveryTitle => '正在连接商家主机';

  @override
  String get employeeDiscoverySubtitle => '分机将直接连接初始化时保存的固定主机地址。';

  @override
  String get employeeConnectionFailed => '无法信任或连接商家主机。证书发生变化时会阻止连接。';

  @override
  String get employeeUseSubsystemAccount => '使用该业务子系统的员工账户登录。';

  @override
  String get hotel => '酒店及酒店餐厅';

  @override
  String get hotelSubtitle => '管理客房、价格、房态、住宿和酒店餐饮。';

  @override
  String get restaurant => '独立餐厅';

  @override
  String get restaurantSubtitle => '管理桌台、菜单、订座和服务订单。';

  @override
  String get tour => '旅行团活动';

  @override
  String get tourSubtitle => '管理行程、出团、团队和游客资料。';

  @override
  String get ticket => '活动票务';

  @override
  String get ticketSubtitle => '管理活动、座位库存、票务订单和核验入场。';

  @override
  String get roomInventory => '客房库存';

  @override
  String get roomRates => '房价与房态';

  @override
  String get hotelDining => '酒店餐饮';

  @override
  String get tables => '桌台与订座';

  @override
  String get menu => '菜单管理';

  @override
  String get restaurantOrders => '服务订单';

  @override
  String get itineraries => '旅行行程';

  @override
  String get departures => '出团与团队';

  @override
  String get travelers => '游客资料';

  @override
  String get events => '活动管理';

  @override
  String get seats => '座位与库存';

  @override
  String get admission => '票务与核验';

  @override
  String get clientBusinessModeTitle => '选择经营模式';

  @override
  String get clientBusinessModeSubtitle => '可选择一个或多个模式，之后将按选择初始化商家移动端。';

  @override
  String get clientBusinessModeRequired => '请至少选择一个经营模式。';

  @override
  String get clientBusinessModeSave => '保存选择';

  @override
  String get clientBusinessModeSaveFailed => '经营模式保存失败，请重试。';

  @override
  String get clientBusinessModeHotel => '酒店';

  @override
  String get clientBusinessModeRestaurant => '餐厅';

  @override
  String get clientBusinessModeTour => '旅行社';

  @override
  String get clientBusinessModeTicket => '票务';

  @override
  String get clientSdkTitle => '公民SDK';

  @override
  String get clientSdkStarting => '正在启动公民SDK...';

  @override
  String get clientSdkUnavailable => '公民SDK暂时无法启动，请重试。';

  @override
  String get clientRetry => '重试';

  @override
  String get clientWalletTitle => '钱包初始化';

  @override
  String get clientWalletChecking => '正在检查本机钱包...';

  @override
  String get clientWalletSubtitle => '创建或导入钱包。请妥善保管助记词及所设置的附加密码。';

  @override
  String get clientWalletOperationFailed => '钱包操作失败，请重试。';

  @override
  String get clientCreateWallet => '创建钱包';

  @override
  String get clientImportWallet => '导入钱包';
}
