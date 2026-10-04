// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'TuyuBooking';

  @override
  String get brandMark => 'TUYU · BOOKING';

  @override
  String get merchantConsole => 'TuyuBooking';

  @override
  String get merchantLoginTitle => 'Administrator sign-in';

  @override
  String get merchantLoginSubtitle => 'Scan and sign to continue.';

  @override
  String get signInAction => 'Scan request';

  @override
  String get signInError =>
      'The administrator signature response was rejected. Create a new challenge and scan again.';

  @override
  String get localSigningHint => 'Private key stays on your phone.';

  @override
  String get initializeAdministratorTitle => 'Initialize TuyuBooking';

  @override
  String get administratorName => 'Administrator name';

  @override
  String get optionalField => 'Optional, up to 30 characters';

  @override
  String get scanAdministratorPublicKey => 'Scan administrator public-key QR';

  @override
  String get publicKeyScanInstruction =>
      'Point this computer\'s camera at the TUYU administrator public-key QR displayed on the phone.';

  @override
  String get scanSignatureResponse => 'Show signed QR';

  @override
  String get signatureResponseInstruction =>
      'Show the signed QR on your phone to the camera.';

  @override
  String get cameraPreparing => 'Starting camera';

  @override
  String get cameraScanning => 'Show signed QR';

  @override
  String get signatureResponseRecognized => 'Verifying';

  @override
  String get cameraUnavailable =>
      'The application camera is unavailable. Check the system camera permission and camera status.';

  @override
  String get newLoginChallenge => 'Refresh QR';

  @override
  String get privateKeyNeverStored => 'Private key stays on your phone.';

  @override
  String get administratorManagement => 'Administrator management';

  @override
  String get administratorPolicySummary =>
      'All administrators have equal access. Up to 99 are allowed and at least one must remain active. Public keys cannot be changed.';

  @override
  String get addAdministrator => 'Add administrator';

  @override
  String get renameAdministrator => 'Change name';

  @override
  String get deleteAdministrator => 'Delete administrator';

  @override
  String get deleteAdministratorConfirmation =>
      'Deleting removes this administrator\'s local sign-in access while retaining the audit record. Continue?';

  @override
  String get unnamedAdministrator => 'Unnamed administrator';

  @override
  String get currentAdministrator => 'Current administrator';

  @override
  String get administratorOperationFailed =>
      'The administrator operation failed. Check the current administrator state and try again.';

  @override
  String get cancel => 'Cancel';

  @override
  String get confirm => 'Confirm';

  @override
  String get startingLocalService =>
      'Starting the private local data service...';

  @override
  String get startupError => 'The local data service could not start.';

  @override
  String get retry => 'Retry';

  @override
  String get homeHeadline => 'One merchant system for every operation';

  @override
  String get homeSubtitle =>
      'The package contains every business system and runs only those enabled for this merchant.';

  @override
  String get manageBusinessModules => 'Manage business systems';

  @override
  String get businessModuleSelectionTitle => 'Choose business modes';

  @override
  String get businessModuleSelectionSubtitle =>
      'Select one or more. You can enable or disable them later.';

  @override
  String get businessModuleRequired => 'Choose at least one business mode.';

  @override
  String get saveBusinessModules => 'Continue';

  @override
  String get businessModuleUpdateFailed =>
      'The business mode configuration could not be saved.';

  @override
  String get moduleStatusDisabled => 'Disabled';

  @override
  String get moduleStatusMissing => 'Runtime missing';

  @override
  String get moduleStatusInstalled => 'Installed';

  @override
  String get moduleStatusStarting => 'Starting';

  @override
  String get moduleStatusReady => 'Ready';

  @override
  String get moduleStatusDegraded => 'HTTPS unavailable';

  @override
  String get moduleStatusFailed => 'Failed';

  @override
  String get moduleStatusStopping => 'Stopping';

  @override
  String get moduleStatusStopped => 'Stopped';

  @override
  String get moduleStatusUnknown => 'Unknown';

  @override
  String get restartModule => 'Restart this subsystem';

  @override
  String get employeeAccessTooltip => 'Employee device access';

  @override
  String get employeeAccessTitle => 'Employee LAN access';

  @override
  String get employeeAccessSubtitle =>
      'Expose every ready subsystem through one administrator-controlled LAN HTTPS address.';

  @override
  String get employeeGatewayDisabled => 'LAN access is disabled';

  @override
  String get employeeGatewayStarting => 'Starting secure LAN access';

  @override
  String get employeeGatewayReady => 'LAN HTTPS access is ready';

  @override
  String get employeeGatewayFailed => 'LAN HTTPS access failed';

  @override
  String get employeeGatewayStopping => 'Stopping LAN access';

  @override
  String get enableEmployeeAccess => 'Enable LAN HTTPS access';

  @override
  String get disableEmployeeAccess => 'Disable LAN access';

  @override
  String get employeeAccessAddress => 'HTTPS address';

  @override
  String get certificateFingerprint => 'Certificate SHA-256 fingerprint';

  @override
  String get employeeAccessRoutes => 'Business routes';

  @override
  String get employeeAccessDiscoveryHint =>
      'A client connects automatically during initialization and saves this fixed LAN address. Later launches connect directly without a QR code.';

  @override
  String get employeeAccessSecurityHint =>
      'Internal subsystem ports remain loopback-only. Employee authentication is still handled by Kamra, URY, Voyant, or Hi.Events.';

  @override
  String get employeeAccessOperationFailed =>
      'The employee LAN access operation failed.';

  @override
  String get employeeAppTitle => 'TuyuBooking staff';

  @override
  String get employeeDiscoveryTitle => 'Connecting to your merchant host';

  @override
  String get employeeDiscoverySubtitle =>
      'This client connects directly to the fixed host address saved during initialization.';

  @override
  String get employeeConnectionFailed =>
      'The merchant host could not be trusted or connected. Certificate changes are blocked.';

  @override
  String get employeeUseSubsystemAccount =>
      'Sign in with your employee account for this subsystem.';

  @override
  String get hotel => 'Hotel & hotel dining';

  @override
  String get hotelSubtitle =>
      'Rooms, rates, availability, stays, and hotel dining.';

  @override
  String get restaurant => 'Independent restaurant';

  @override
  String get restaurantSubtitle =>
      'Tables, menus, reservations, and service orders.';

  @override
  String get tour => 'Travel tours';

  @override
  String get tourSubtitle =>
      'Itineraries, departures, groups, and traveler records.';

  @override
  String get ticket => 'Events & ticketing';

  @override
  String get ticketSubtitle =>
      'Events, seat inventory, ticket orders, and admission.';

  @override
  String get roomInventory => 'Room inventory';

  @override
  String get roomRates => 'Rates & availability';

  @override
  String get hotelDining => 'Hotel dining';

  @override
  String get tables => 'Tables & reservations';

  @override
  String get menu => 'Menus';

  @override
  String get restaurantOrders => 'Service orders';

  @override
  String get itineraries => 'Itineraries';

  @override
  String get departures => 'Departures & groups';

  @override
  String get travelers => 'Traveler records';

  @override
  String get events => 'Events';

  @override
  String get seats => 'Seats & inventory';

  @override
  String get admission => 'Tickets & admission';

  @override
  String get clientBusinessModeTitle => 'Choose business modes';

  @override
  String get clientBusinessModeSubtitle =>
      'Choose one or more modes. TuyuBooking client will initialize from this selection.';

  @override
  String get clientBusinessModeRequired => 'Choose at least one business mode.';

  @override
  String get clientBusinessModeSave => 'Save selection';

  @override
  String get clientBusinessModeSaveFailed =>
      'The business modes could not be saved. Try again.';

  @override
  String get clientBusinessModeHotel => 'Hotel';

  @override
  String get clientBusinessModeRestaurant => 'Restaurant';

  @override
  String get clientBusinessModeTour => 'Travel agency';

  @override
  String get clientBusinessModeTicket => 'Ticketing';

  @override
  String get clientSdkTitle => 'CitizenSDK';

  @override
  String get clientSdkStarting => 'Starting CitizenSDK...';

  @override
  String get clientSdkUnavailable => 'CitizenSDK could not start. Try again.';

  @override
  String get clientRetry => 'Try again';

  @override
  String get clientWalletTitle => 'Wallet setup';

  @override
  String get clientWalletChecking => 'Checking this device wallet...';

  @override
  String get clientWalletSubtitle =>
      'Create or import a wallet. Keep your recovery phrase and any optional passphrase safe.';

  @override
  String get clientWalletOperationFailed =>
      'The wallet operation failed. Try again.';

  @override
  String get clientCreateWallet => 'Create wallet';

  @override
  String get clientImportWallet => 'Import wallet';
}
