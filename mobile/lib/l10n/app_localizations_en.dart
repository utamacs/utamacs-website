// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'UTA MACS';

  @override
  String get navHome => 'Home';

  @override
  String get navNotices => 'Notices';

  @override
  String get navVisitors => 'Visitors';

  @override
  String get navServices => 'Services';

  @override
  String get navProfile => 'Profile';

  @override
  String get actionSave => 'Save';

  @override
  String get actionCancel => 'Cancel';

  @override
  String get actionSubmit => 'Submit';

  @override
  String get actionEdit => 'Edit';

  @override
  String get actionDelete => 'Delete';

  @override
  String get actionConfirm => 'Confirm';

  @override
  String get actionClose => 'Close';

  @override
  String get actionBack => 'Back';

  @override
  String get actionRetry => 'Retry';

  @override
  String get actionSearch => 'Search';

  @override
  String get actionFilter => 'Filter';

  @override
  String get actionUpload => 'Upload';

  @override
  String get actionDownload => 'Download';

  @override
  String get actionShare => 'Share';

  @override
  String get actionApprove => 'Approve';

  @override
  String get actionReject => 'Reject';

  @override
  String get actionViewAll => 'View All';

  @override
  String get stateLoading => 'Loading…';

  @override
  String get stateEmpty => 'No items yet';

  @override
  String get stateError => 'Something went wrong';

  @override
  String get stateNoResults => 'No results found';

  @override
  String get stateOffline => 'You\'re offline';

  @override
  String get labelRequired => 'Required';

  @override
  String get labelOptional => 'Optional';

  @override
  String get labelAll => 'All';

  @override
  String get labelYes => 'Yes';

  @override
  String get labelNo => 'No';

  @override
  String get labelStatus => 'Status';

  @override
  String get labelDate => 'Date';

  @override
  String get labelDescription => 'Description';

  @override
  String get labelAmount => 'Amount';

  @override
  String get labelUnit => 'Unit';

  @override
  String get labelName => 'Name';

  @override
  String get labelPhone => 'Phone';

  @override
  String get labelEmail => 'Email';

  @override
  String get labelCategory => 'Category';

  @override
  String get labelPriority => 'Priority';

  @override
  String get labelAttachments => 'Attachments';

  @override
  String get moduleComplaints => 'Complaints';

  @override
  String get moduleFinance => 'Finance';

  @override
  String get moduleEvents => 'Events';

  @override
  String get modulePolls => 'Polls';

  @override
  String get moduleCommunity => 'Community';

  @override
  String get moduleDocuments => 'Documents';

  @override
  String get moduleFacilities => 'Facilities';

  @override
  String get moduleParking => 'Parking';

  @override
  String get moduleMaids => 'Domestic Help';

  @override
  String get moduleMembers => 'Members';

  @override
  String get moduleGallery => 'Gallery';

  @override
  String get moduleWaterTankers => 'Water Tankers';

  @override
  String get moduleFeedback => 'Feedback';

  @override
  String get moduleSnags => 'Snags';

  @override
  String get moduleSecurityPatrol => 'Security Patrol';

  @override
  String get modulePolicies => 'Policies';

  @override
  String get moduleRegister => 'Membership';

  @override
  String get moduleAgm => 'AGM';

  @override
  String get moduleTenantKyc => 'Tenant KYC';

  @override
  String get moduleHoto => 'HOTO';

  @override
  String get moduleLetters => 'Letters';

  @override
  String get moduleAnalytics => 'Analytics';

  @override
  String get moduleStaff => 'Staff';

  @override
  String get moduleVendors => 'Vendors';

  @override
  String get loginTitle => 'Welcome back';

  @override
  String get loginSubtitle => 'Sign in to your UTA MACS account';

  @override
  String get loginEmailHint => 'Enter your registered email';

  @override
  String get loginSendOtp => 'Send OTP';

  @override
  String get loginVerifyOtp => 'Verify OTP';

  @override
  String get loginOtpHint => 'Enter the 6-digit code';

  @override
  String get loginResendOtp => 'Resend OTP';

  @override
  String get loginSignOut => 'Sign Out';

  @override
  String get dashboardGreetingMorning => 'Good morning';

  @override
  String get dashboardGreetingAfternoon => 'Good afternoon';

  @override
  String get dashboardGreetingEvening => 'Good evening';

  @override
  String get dashboardQuickActions => 'Quick Actions';

  @override
  String get dashboardRecentActivity => 'Recent Activity';

  @override
  String get complaintNew => 'New Complaint';

  @override
  String get complaintStatus_open => 'Open';

  @override
  String get complaintStatus_inProgress => 'In Progress';

  @override
  String get complaintStatus_resolved => 'Resolved';

  @override
  String get complaintStatus_closed => 'Closed';

  @override
  String get visitorPreApprove => 'Pre-Approve Visitor';

  @override
  String get visitorAdmit => 'Admit';

  @override
  String get visitorExit => 'Mark Exit';

  @override
  String get visitorScanQr => 'Scan QR';

  @override
  String get financeMyDues => 'My Dues';

  @override
  String get financePaymentHistory => 'Payment History';

  @override
  String get financePayNow => 'Pay Now';

  @override
  String get financeOutstanding => 'Outstanding Balance';

  @override
  String get noticePin => 'Pin';

  @override
  String get noticeArchive => 'Archive';

  @override
  String get pollVote => 'Vote';

  @override
  String get pollResults => 'Results';

  @override
  String pollEnds(String date) {
    return 'Ends $date';
  }

  @override
  String get facilityBook => 'Book Facility';

  @override
  String get facilityAvailable => 'Available';

  @override
  String get facilityBooked => 'Booked';

  @override
  String get profileSettings => 'Settings';

  @override
  String get profileDarkMode => 'Dark Mode';

  @override
  String get profileTextSize => 'Text Size';

  @override
  String get profileLanguage => 'Language';

  @override
  String get errorNetwork => 'Network error. Please check your connection.';

  @override
  String get errorUnauthorized => 'You don\'t have permission to do that.';

  @override
  String get errorGeneric => 'An unexpected error occurred. Please try again.';

  @override
  String get errorFieldRequired => 'This field is required.';

  @override
  String get securityDeviceCompromised => 'Security Warning';

  @override
  String get securityDeviceCompromisedBody =>
      'This device appears to be rooted or jailbroken. For your security, some features may be restricted.';

  @override
  String get securityBiometricReason => 'Verify your identity to continue';

  @override
  String get securityBiometricRetry => 'Verify Identity';
}
