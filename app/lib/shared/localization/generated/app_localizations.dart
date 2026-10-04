import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'TuyuBooking'**
  String get appTitle;

  /// No description provided for @brandMark.
  ///
  /// In en, this message translates to:
  /// **'TUYU · BOOKING'**
  String get brandMark;

  /// No description provided for @merchantConsole.
  ///
  /// In en, this message translates to:
  /// **'TuyuBooking'**
  String get merchantConsole;

  /// No description provided for @merchantLoginTitle.
  ///
  /// In en, this message translates to:
  /// **'Administrator sign-in'**
  String get merchantLoginTitle;

  /// No description provided for @merchantLoginSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Scan and sign to continue.'**
  String get merchantLoginSubtitle;

  /// No description provided for @signInAction.
  ///
  /// In en, this message translates to:
  /// **'Scan request'**
  String get signInAction;

  /// No description provided for @signInError.
  ///
  /// In en, this message translates to:
  /// **'The administrator signature response was rejected. Create a new challenge and scan again.'**
  String get signInError;

  /// No description provided for @localSigningHint.
  ///
  /// In en, this message translates to:
  /// **'Private key stays on your phone.'**
  String get localSigningHint;

  /// No description provided for @initializeAdministratorTitle.
  ///
  /// In en, this message translates to:
  /// **'Initialize TuyuBooking'**
  String get initializeAdministratorTitle;

  /// No description provided for @administratorName.
  ///
  /// In en, this message translates to:
  /// **'Administrator name'**
  String get administratorName;

  /// No description provided for @optionalField.
  ///
  /// In en, this message translates to:
  /// **'Optional, up to 30 characters'**
  String get optionalField;

  /// No description provided for @scanAdministratorPublicKey.
  ///
  /// In en, this message translates to:
  /// **'Scan administrator public-key QR'**
  String get scanAdministratorPublicKey;

  /// No description provided for @publicKeyScanInstruction.
  ///
  /// In en, this message translates to:
  /// **'Point this computer\'s camera at the TUYU administrator public-key QR displayed on the phone.'**
  String get publicKeyScanInstruction;

  /// No description provided for @scanSignatureResponse.
  ///
  /// In en, this message translates to:
  /// **'Show signed QR'**
  String get scanSignatureResponse;

  /// No description provided for @signatureResponseInstruction.
  ///
  /// In en, this message translates to:
  /// **'Show the signed QR on your phone to the camera.'**
  String get signatureResponseInstruction;

  /// No description provided for @cameraPreparing.
  ///
  /// In en, this message translates to:
  /// **'Starting camera'**
  String get cameraPreparing;

  /// No description provided for @cameraScanning.
  ///
  /// In en, this message translates to:
  /// **'Show signed QR'**
  String get cameraScanning;

  /// No description provided for @signatureResponseRecognized.
  ///
  /// In en, this message translates to:
  /// **'Verifying'**
  String get signatureResponseRecognized;

  /// No description provided for @cameraUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The application camera is unavailable. Check the system camera permission and camera status.'**
  String get cameraUnavailable;

  /// No description provided for @newLoginChallenge.
  ///
  /// In en, this message translates to:
  /// **'Refresh QR'**
  String get newLoginChallenge;

  /// No description provided for @privateKeyNeverStored.
  ///
  /// In en, this message translates to:
  /// **'Private key stays on your phone.'**
  String get privateKeyNeverStored;

  /// No description provided for @administratorManagement.
  ///
  /// In en, this message translates to:
  /// **'Administrator management'**
  String get administratorManagement;

  /// No description provided for @administratorPolicySummary.
  ///
  /// In en, this message translates to:
  /// **'All administrators have equal access. Up to 99 are allowed and at least one must remain active. Public keys cannot be changed.'**
  String get administratorPolicySummary;

  /// No description provided for @addAdministrator.
  ///
  /// In en, this message translates to:
  /// **'Add administrator'**
  String get addAdministrator;

  /// No description provided for @renameAdministrator.
  ///
  /// In en, this message translates to:
  /// **'Change name'**
  String get renameAdministrator;

  /// No description provided for @deleteAdministrator.
  ///
  /// In en, this message translates to:
  /// **'Delete administrator'**
  String get deleteAdministrator;

  /// No description provided for @deleteAdministratorConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Deleting removes this administrator\'s local sign-in access while retaining the audit record. Continue?'**
  String get deleteAdministratorConfirmation;

  /// No description provided for @unnamedAdministrator.
  ///
  /// In en, this message translates to:
  /// **'Unnamed administrator'**
  String get unnamedAdministrator;

  /// No description provided for @currentAdministrator.
  ///
  /// In en, this message translates to:
  /// **'Current administrator'**
  String get currentAdministrator;

  /// No description provided for @administratorOperationFailed.
  ///
  /// In en, this message translates to:
  /// **'The administrator operation failed. Check the current administrator state and try again.'**
  String get administratorOperationFailed;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @startingLocalService.
  ///
  /// In en, this message translates to:
  /// **'Starting the private local data service...'**
  String get startingLocalService;

  /// No description provided for @startupError.
  ///
  /// In en, this message translates to:
  /// **'The local data service could not start.'**
  String get startupError;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @homeHeadline.
  ///
  /// In en, this message translates to:
  /// **'One merchant system for every operation'**
  String get homeHeadline;

  /// No description provided for @homeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'The package contains every business system and runs only those enabled for this merchant.'**
  String get homeSubtitle;

  /// No description provided for @manageBusinessModules.
  ///
  /// In en, this message translates to:
  /// **'Manage business systems'**
  String get manageBusinessModules;

  /// No description provided for @businessModuleSelectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose business modes'**
  String get businessModuleSelectionTitle;

  /// No description provided for @businessModuleSelectionSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Select one or more. You can enable or disable them later.'**
  String get businessModuleSelectionSubtitle;

  /// No description provided for @businessModuleRequired.
  ///
  /// In en, this message translates to:
  /// **'Choose at least one business mode.'**
  String get businessModuleRequired;

  /// No description provided for @saveBusinessModules.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get saveBusinessModules;

  /// No description provided for @businessModuleUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'The business mode configuration could not be saved.'**
  String get businessModuleUpdateFailed;

  /// No description provided for @moduleStatusDisabled.
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get moduleStatusDisabled;

  /// No description provided for @moduleStatusMissing.
  ///
  /// In en, this message translates to:
  /// **'Runtime missing'**
  String get moduleStatusMissing;

  /// No description provided for @moduleStatusInstalled.
  ///
  /// In en, this message translates to:
  /// **'Installed'**
  String get moduleStatusInstalled;

  /// No description provided for @moduleStatusStarting.
  ///
  /// In en, this message translates to:
  /// **'Starting'**
  String get moduleStatusStarting;

  /// No description provided for @moduleStatusReady.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get moduleStatusReady;

  /// No description provided for @moduleStatusDegraded.
  ///
  /// In en, this message translates to:
  /// **'HTTPS unavailable'**
  String get moduleStatusDegraded;

  /// No description provided for @moduleStatusFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get moduleStatusFailed;

  /// No description provided for @moduleStatusStopping.
  ///
  /// In en, this message translates to:
  /// **'Stopping'**
  String get moduleStatusStopping;

  /// No description provided for @moduleStatusStopped.
  ///
  /// In en, this message translates to:
  /// **'Stopped'**
  String get moduleStatusStopped;

  /// No description provided for @moduleStatusUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get moduleStatusUnknown;

  /// No description provided for @restartModule.
  ///
  /// In en, this message translates to:
  /// **'Restart this subsystem'**
  String get restartModule;

  /// No description provided for @employeeAccessTooltip.
  ///
  /// In en, this message translates to:
  /// **'Employee device access'**
  String get employeeAccessTooltip;

  /// No description provided for @employeeAccessTitle.
  ///
  /// In en, this message translates to:
  /// **'Employee LAN access'**
  String get employeeAccessTitle;

  /// No description provided for @employeeAccessSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Expose every ready subsystem through one administrator-controlled LAN HTTPS address.'**
  String get employeeAccessSubtitle;

  /// No description provided for @employeeGatewayDisabled.
  ///
  /// In en, this message translates to:
  /// **'LAN access is disabled'**
  String get employeeGatewayDisabled;

  /// No description provided for @employeeGatewayStarting.
  ///
  /// In en, this message translates to:
  /// **'Starting secure LAN access'**
  String get employeeGatewayStarting;

  /// No description provided for @employeeGatewayReady.
  ///
  /// In en, this message translates to:
  /// **'LAN HTTPS access is ready'**
  String get employeeGatewayReady;

  /// No description provided for @employeeGatewayFailed.
  ///
  /// In en, this message translates to:
  /// **'LAN HTTPS access failed'**
  String get employeeGatewayFailed;

  /// No description provided for @employeeGatewayStopping.
  ///
  /// In en, this message translates to:
  /// **'Stopping LAN access'**
  String get employeeGatewayStopping;

  /// No description provided for @enableEmployeeAccess.
  ///
  /// In en, this message translates to:
  /// **'Enable LAN HTTPS access'**
  String get enableEmployeeAccess;

  /// No description provided for @disableEmployeeAccess.
  ///
  /// In en, this message translates to:
  /// **'Disable LAN access'**
  String get disableEmployeeAccess;

  /// No description provided for @employeeAccessAddress.
  ///
  /// In en, this message translates to:
  /// **'HTTPS address'**
  String get employeeAccessAddress;

  /// No description provided for @certificateFingerprint.
  ///
  /// In en, this message translates to:
  /// **'Certificate SHA-256 fingerprint'**
  String get certificateFingerprint;

  /// No description provided for @employeeAccessRoutes.
  ///
  /// In en, this message translates to:
  /// **'Business routes'**
  String get employeeAccessRoutes;

  /// No description provided for @employeeAccessDiscoveryHint.
  ///
  /// In en, this message translates to:
  /// **'A client connects automatically during initialization and saves this fixed LAN address. Later launches connect directly without a QR code.'**
  String get employeeAccessDiscoveryHint;

  /// No description provided for @employeeAccessSecurityHint.
  ///
  /// In en, this message translates to:
  /// **'Internal subsystem ports remain loopback-only. Employee authentication is still handled by Kamra, URY, Voyant, or Hi.Events.'**
  String get employeeAccessSecurityHint;

  /// No description provided for @employeeAccessOperationFailed.
  ///
  /// In en, this message translates to:
  /// **'The employee LAN access operation failed.'**
  String get employeeAccessOperationFailed;

  /// No description provided for @employeeAppTitle.
  ///
  /// In en, this message translates to:
  /// **'TuyuBooking staff'**
  String get employeeAppTitle;

  /// No description provided for @employeeDiscoveryTitle.
  ///
  /// In en, this message translates to:
  /// **'Connecting to your merchant host'**
  String get employeeDiscoveryTitle;

  /// No description provided for @employeeDiscoverySubtitle.
  ///
  /// In en, this message translates to:
  /// **'This client connects directly to the fixed host address saved during initialization.'**
  String get employeeDiscoverySubtitle;

  /// No description provided for @employeeConnectionFailed.
  ///
  /// In en, this message translates to:
  /// **'The merchant host could not be trusted or connected. Certificate changes are blocked.'**
  String get employeeConnectionFailed;

  /// No description provided for @employeeUseSubsystemAccount.
  ///
  /// In en, this message translates to:
  /// **'Sign in with your employee account for this subsystem.'**
  String get employeeUseSubsystemAccount;

  /// No description provided for @hotel.
  ///
  /// In en, this message translates to:
  /// **'Hotel & hotel dining'**
  String get hotel;

  /// No description provided for @hotelSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Rooms, rates, availability, stays, and hotel dining.'**
  String get hotelSubtitle;

  /// No description provided for @restaurant.
  ///
  /// In en, this message translates to:
  /// **'Independent restaurant'**
  String get restaurant;

  /// No description provided for @restaurantSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Tables, menus, reservations, and service orders.'**
  String get restaurantSubtitle;

  /// No description provided for @tour.
  ///
  /// In en, this message translates to:
  /// **'Travel tours'**
  String get tour;

  /// No description provided for @tourSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Itineraries, departures, groups, and traveler records.'**
  String get tourSubtitle;

  /// No description provided for @ticket.
  ///
  /// In en, this message translates to:
  /// **'Events & ticketing'**
  String get ticket;

  /// No description provided for @ticketSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Events, seat inventory, ticket orders, and admission.'**
  String get ticketSubtitle;

  /// No description provided for @roomInventory.
  ///
  /// In en, this message translates to:
  /// **'Room inventory'**
  String get roomInventory;

  /// No description provided for @roomRates.
  ///
  /// In en, this message translates to:
  /// **'Rates & availability'**
  String get roomRates;

  /// No description provided for @hotelDining.
  ///
  /// In en, this message translates to:
  /// **'Hotel dining'**
  String get hotelDining;

  /// No description provided for @tables.
  ///
  /// In en, this message translates to:
  /// **'Tables & reservations'**
  String get tables;

  /// No description provided for @menu.
  ///
  /// In en, this message translates to:
  /// **'Menus'**
  String get menu;

  /// No description provided for @restaurantOrders.
  ///
  /// In en, this message translates to:
  /// **'Service orders'**
  String get restaurantOrders;

  /// No description provided for @itineraries.
  ///
  /// In en, this message translates to:
  /// **'Itineraries'**
  String get itineraries;

  /// No description provided for @departures.
  ///
  /// In en, this message translates to:
  /// **'Departures & groups'**
  String get departures;

  /// No description provided for @travelers.
  ///
  /// In en, this message translates to:
  /// **'Traveler records'**
  String get travelers;

  /// No description provided for @events.
  ///
  /// In en, this message translates to:
  /// **'Events'**
  String get events;

  /// No description provided for @seats.
  ///
  /// In en, this message translates to:
  /// **'Seats & inventory'**
  String get seats;

  /// No description provided for @admission.
  ///
  /// In en, this message translates to:
  /// **'Tickets & admission'**
  String get admission;

  /// No description provided for @clientBusinessModeTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose business modes'**
  String get clientBusinessModeTitle;

  /// No description provided for @clientBusinessModeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose one or more modes. TuyuBooking client will initialize from this selection.'**
  String get clientBusinessModeSubtitle;

  /// No description provided for @clientBusinessModeRequired.
  ///
  /// In en, this message translates to:
  /// **'Choose at least one business mode.'**
  String get clientBusinessModeRequired;

  /// No description provided for @clientBusinessModeSave.
  ///
  /// In en, this message translates to:
  /// **'Save selection'**
  String get clientBusinessModeSave;

  /// No description provided for @clientBusinessModeSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'The business modes could not be saved. Try again.'**
  String get clientBusinessModeSaveFailed;

  /// No description provided for @clientBusinessModeHotel.
  ///
  /// In en, this message translates to:
  /// **'Hotel'**
  String get clientBusinessModeHotel;

  /// No description provided for @clientBusinessModeRestaurant.
  ///
  /// In en, this message translates to:
  /// **'Restaurant'**
  String get clientBusinessModeRestaurant;

  /// No description provided for @clientBusinessModeTour.
  ///
  /// In en, this message translates to:
  /// **'Travel agency'**
  String get clientBusinessModeTour;

  /// No description provided for @clientBusinessModeTicket.
  ///
  /// In en, this message translates to:
  /// **'Ticketing'**
  String get clientBusinessModeTicket;

  /// No description provided for @clientSdkTitle.
  ///
  /// In en, this message translates to:
  /// **'CitizenSDK'**
  String get clientSdkTitle;

  /// No description provided for @clientSdkStarting.
  ///
  /// In en, this message translates to:
  /// **'Starting CitizenSDK...'**
  String get clientSdkStarting;

  /// No description provided for @clientSdkUnavailable.
  ///
  /// In en, this message translates to:
  /// **'CitizenSDK could not start. Try again.'**
  String get clientSdkUnavailable;

  /// No description provided for @clientRetry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get clientRetry;

  /// No description provided for @clientWalletTitle.
  ///
  /// In en, this message translates to:
  /// **'Wallet setup'**
  String get clientWalletTitle;

  /// No description provided for @clientWalletChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking this device wallet...'**
  String get clientWalletChecking;

  /// No description provided for @clientWalletSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Create or import a wallet. Keep your recovery phrase and any optional passphrase safe.'**
  String get clientWalletSubtitle;

  /// No description provided for @clientWalletOperationFailed.
  ///
  /// In en, this message translates to:
  /// **'The wallet operation failed. Try again.'**
  String get clientWalletOperationFailed;

  /// No description provided for @clientCreateWallet.
  ///
  /// In en, this message translates to:
  /// **'Create wallet'**
  String get clientCreateWallet;

  /// No description provided for @clientImportWallet.
  ///
  /// In en, this message translates to:
  /// **'Import wallet'**
  String get clientImportWallet;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
