import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_hi.dart';
import 'app_localizations_te.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
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
    Locale('hi'),
    Locale('te'),
  ];

  /// Application name
  ///
  /// In en, this message translates to:
  /// **'UTA MACS'**
  String get appTitle;

  /// Bottom nav: Home tab
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// Bottom nav: Notices tab
  ///
  /// In en, this message translates to:
  /// **'Notices'**
  String get navNotices;

  /// Bottom nav: Visitors tab
  ///
  /// In en, this message translates to:
  /// **'Visitors'**
  String get navVisitors;

  /// Bottom nav: Services tab
  ///
  /// In en, this message translates to:
  /// **'Services'**
  String get navServices;

  /// Bottom nav: Profile tab
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get navProfile;

  /// Generic save button
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get actionSave;

  /// Generic cancel button
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get actionCancel;

  /// Generic submit button
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get actionSubmit;

  /// Generic edit button
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get actionEdit;

  /// Generic delete button
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get actionDelete;

  /// Generic confirm button
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get actionConfirm;

  /// Generic close button
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get actionClose;

  /// Generic back button
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get actionBack;

  /// Retry after error
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get actionRetry;

  /// Search action / hint
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get actionSearch;

  /// Filter action
  ///
  /// In en, this message translates to:
  /// **'Filter'**
  String get actionFilter;

  /// Upload file action
  ///
  /// In en, this message translates to:
  /// **'Upload'**
  String get actionUpload;

  /// Download file action
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get actionDownload;

  /// Share action
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get actionShare;

  /// Approve action
  ///
  /// In en, this message translates to:
  /// **'Approve'**
  String get actionApprove;

  /// Reject action
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get actionReject;

  /// View all items link
  ///
  /// In en, this message translates to:
  /// **'View All'**
  String get actionViewAll;

  /// Generic loading indicator label
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get stateLoading;

  /// Empty list state
  ///
  /// In en, this message translates to:
  /// **'No items yet'**
  String get stateEmpty;

  /// Generic error state
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get stateError;

  /// Search / filter empty state
  ///
  /// In en, this message translates to:
  /// **'No results found'**
  String get stateNoResults;

  /// No internet connection message
  ///
  /// In en, this message translates to:
  /// **'You\'re offline'**
  String get stateOffline;

  /// Field required label
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get labelRequired;

  /// Field optional label
  ///
  /// In en, this message translates to:
  /// **'Optional'**
  String get labelOptional;

  /// Filter: All option
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get labelAll;

  /// Yes / affirmative
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get labelYes;

  /// No / negative
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get labelNo;

  /// Status label
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get labelStatus;

  /// Date label
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get labelDate;

  /// Description field label
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get labelDescription;

  /// Amount / money label
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get labelAmount;

  /// Flat / unit number label
  ///
  /// In en, this message translates to:
  /// **'Unit'**
  String get labelUnit;

  /// Name field label
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get labelName;

  /// Phone number label
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get labelPhone;

  /// Email address label
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get labelEmail;

  /// Category field label
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get labelCategory;

  /// Priority label
  ///
  /// In en, this message translates to:
  /// **'Priority'**
  String get labelPriority;

  /// Attachments label
  ///
  /// In en, this message translates to:
  /// **'Attachments'**
  String get labelAttachments;

  /// Module name: Complaints
  ///
  /// In en, this message translates to:
  /// **'Complaints'**
  String get moduleComplaints;

  /// Module name: Finance & Dues
  ///
  /// In en, this message translates to:
  /// **'Finance'**
  String get moduleFinance;

  /// Module name: Events
  ///
  /// In en, this message translates to:
  /// **'Events'**
  String get moduleEvents;

  /// Module name: Polls & Voting
  ///
  /// In en, this message translates to:
  /// **'Polls'**
  String get modulePolls;

  /// Module name: Community Board
  ///
  /// In en, this message translates to:
  /// **'Community'**
  String get moduleCommunity;

  /// Module name: Documents
  ///
  /// In en, this message translates to:
  /// **'Documents'**
  String get moduleDocuments;

  /// Module name: Facility Booking
  ///
  /// In en, this message translates to:
  /// **'Facilities'**
  String get moduleFacilities;

  /// Module name: Parking
  ///
  /// In en, this message translates to:
  /// **'Parking'**
  String get moduleParking;

  /// Module name: Maids registry
  ///
  /// In en, this message translates to:
  /// **'Domestic Help'**
  String get moduleMaids;

  /// Module name: Member Directory
  ///
  /// In en, this message translates to:
  /// **'Members'**
  String get moduleMembers;

  /// Module name: Photo Gallery
  ///
  /// In en, this message translates to:
  /// **'Gallery'**
  String get moduleGallery;

  /// Module name: Water Tanker orders
  ///
  /// In en, this message translates to:
  /// **'Water Tankers'**
  String get moduleWaterTankers;

  /// Module name: Feedback
  ///
  /// In en, this message translates to:
  /// **'Feedback'**
  String get moduleFeedback;

  /// Module name: Snag / defect list
  ///
  /// In en, this message translates to:
  /// **'Snags'**
  String get moduleSnags;

  /// Module name: Security Patrol Log
  ///
  /// In en, this message translates to:
  /// **'Security Patrol'**
  String get moduleSecurityPatrol;

  /// Module name: Policies & Compliance
  ///
  /// In en, this message translates to:
  /// **'Policies'**
  String get modulePolicies;

  /// Module name: Society membership application
  ///
  /// In en, this message translates to:
  /// **'Membership'**
  String get moduleRegister;

  /// Module name: Annual General Meeting
  ///
  /// In en, this message translates to:
  /// **'AGM'**
  String get moduleAgm;

  /// Module name: Tenant KYC verification
  ///
  /// In en, this message translates to:
  /// **'Tenant KYC'**
  String get moduleTenantKyc;

  /// Module name: Handover-Takeover tracker
  ///
  /// In en, this message translates to:
  /// **'HOTO'**
  String get moduleHoto;

  /// Module name: Official Letters
  ///
  /// In en, this message translates to:
  /// **'Letters'**
  String get moduleLetters;

  /// Module name: Analytics & Reports
  ///
  /// In en, this message translates to:
  /// **'Analytics'**
  String get moduleAnalytics;

  /// Module name: Staff management
  ///
  /// In en, this message translates to:
  /// **'Staff'**
  String get moduleStaff;

  /// Module name: Vendors & Work Orders
  ///
  /// In en, this message translates to:
  /// **'Vendors'**
  String get moduleVendors;

  /// Login screen heading
  ///
  /// In en, this message translates to:
  /// **'Welcome back'**
  String get loginTitle;

  /// Login screen subheading
  ///
  /// In en, this message translates to:
  /// **'Sign in to your UTA MACS account'**
  String get loginSubtitle;

  /// Login email field hint
  ///
  /// In en, this message translates to:
  /// **'Enter your registered email'**
  String get loginEmailHint;

  /// Send OTP button
  ///
  /// In en, this message translates to:
  /// **'Send OTP'**
  String get loginSendOtp;

  /// Verify OTP button
  ///
  /// In en, this message translates to:
  /// **'Verify OTP'**
  String get loginVerifyOtp;

  /// OTP input hint
  ///
  /// In en, this message translates to:
  /// **'Enter the 6-digit code'**
  String get loginOtpHint;

  /// Resend OTP link
  ///
  /// In en, this message translates to:
  /// **'Resend OTP'**
  String get loginResendOtp;

  /// Sign out button
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get loginSignOut;

  /// Morning greeting on dashboard
  ///
  /// In en, this message translates to:
  /// **'Good morning'**
  String get dashboardGreetingMorning;

  /// Afternoon greeting on dashboard
  ///
  /// In en, this message translates to:
  /// **'Good afternoon'**
  String get dashboardGreetingAfternoon;

  /// Evening greeting on dashboard
  ///
  /// In en, this message translates to:
  /// **'Good evening'**
  String get dashboardGreetingEvening;

  /// Dashboard section: Quick Actions
  ///
  /// In en, this message translates to:
  /// **'Quick Actions'**
  String get dashboardQuickActions;

  /// Dashboard section: Recent Activity
  ///
  /// In en, this message translates to:
  /// **'Recent Activity'**
  String get dashboardRecentActivity;

  /// New complaint button
  ///
  /// In en, this message translates to:
  /// **'New Complaint'**
  String get complaintNew;

  /// Complaint status: open
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get complaintStatus_open;

  /// Complaint status: in progress
  ///
  /// In en, this message translates to:
  /// **'In Progress'**
  String get complaintStatus_inProgress;

  /// Complaint status: resolved
  ///
  /// In en, this message translates to:
  /// **'Resolved'**
  String get complaintStatus_resolved;

  /// Complaint status: closed
  ///
  /// In en, this message translates to:
  /// **'Closed'**
  String get complaintStatus_closed;

  /// Pre-approve visitor button
  ///
  /// In en, this message translates to:
  /// **'Pre-Approve Visitor'**
  String get visitorPreApprove;

  /// Admit visitor button (guard view)
  ///
  /// In en, this message translates to:
  /// **'Admit'**
  String get visitorAdmit;

  /// Mark visitor exit button
  ///
  /// In en, this message translates to:
  /// **'Mark Exit'**
  String get visitorExit;

  /// Scan QR code button
  ///
  /// In en, this message translates to:
  /// **'Scan QR'**
  String get visitorScanQr;

  /// Finance tab: My Dues
  ///
  /// In en, this message translates to:
  /// **'My Dues'**
  String get financeMyDues;

  /// Finance tab: Payment History
  ///
  /// In en, this message translates to:
  /// **'Payment History'**
  String get financePaymentHistory;

  /// Pay Now button
  ///
  /// In en, this message translates to:
  /// **'Pay Now'**
  String get financePayNow;

  /// Outstanding balance label
  ///
  /// In en, this message translates to:
  /// **'Outstanding Balance'**
  String get financeOutstanding;

  /// Pin notice action
  ///
  /// In en, this message translates to:
  /// **'Pin'**
  String get noticePin;

  /// Archive notice action
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get noticeArchive;

  /// Vote action in polls
  ///
  /// In en, this message translates to:
  /// **'Vote'**
  String get pollVote;

  /// Poll results label
  ///
  /// In en, this message translates to:
  /// **'Results'**
  String get pollResults;

  /// Poll end date
  ///
  /// In en, this message translates to:
  /// **'Ends {date}'**
  String pollEnds(String date);

  /// Book facility button
  ///
  /// In en, this message translates to:
  /// **'Book Facility'**
  String get facilityBook;

  /// Facility availability: available
  ///
  /// In en, this message translates to:
  /// **'Available'**
  String get facilityAvailable;

  /// Facility availability: booked
  ///
  /// In en, this message translates to:
  /// **'Booked'**
  String get facilityBooked;

  /// Profile settings section
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get profileSettings;

  /// Dark mode toggle label
  ///
  /// In en, this message translates to:
  /// **'Dark Mode'**
  String get profileDarkMode;

  /// Text size preference label
  ///
  /// In en, this message translates to:
  /// **'Text Size'**
  String get profileTextSize;

  /// Language preference label
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get profileLanguage;

  /// Network error message
  ///
  /// In en, this message translates to:
  /// **'Network error. Please check your connection.'**
  String get errorNetwork;

  /// Authorization error message
  ///
  /// In en, this message translates to:
  /// **'You don\'t have permission to do that.'**
  String get errorUnauthorized;

  /// Generic error fallback message
  ///
  /// In en, this message translates to:
  /// **'An unexpected error occurred. Please try again.'**
  String get errorGeneric;

  /// Form validation: field required
  ///
  /// In en, this message translates to:
  /// **'This field is required.'**
  String get errorFieldRequired;

  /// Security warning dialog title
  ///
  /// In en, this message translates to:
  /// **'Security Warning'**
  String get securityDeviceCompromised;

  /// Security warning dialog body
  ///
  /// In en, this message translates to:
  /// **'This device appears to be rooted or jailbroken. For your security, some features may be restricted.'**
  String get securityDeviceCompromisedBody;

  /// Default biometric prompt reason
  ///
  /// In en, this message translates to:
  /// **'Verify your identity to continue'**
  String get securityBiometricReason;

  /// Retry biometric button
  ///
  /// In en, this message translates to:
  /// **'Verify Identity'**
  String get securityBiometricRetry;
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
      <String>['en', 'hi', 'te'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'hi':
      return AppLocalizationsHi();
    case 'te':
      return AppLocalizationsTe();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
