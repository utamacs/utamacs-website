/// Typed enum for portal roles — replaces raw String comparisons throughout the app.
enum PortalRole {
  member,
  executive,
  secretary,
  president,
  securityGuard,
  vendor,
  admin;

  bool get isExec =>
      this == executive || this == secretary || this == president || this == admin;

  bool get isGuard => this == securityGuard;

  static PortalRole fromString(String? s) {
    switch (s) {
      case 'executive':      return PortalRole.executive;
      case 'secretary':      return PortalRole.secretary;
      case 'president':      return PortalRole.president;
      case 'security_guard': return PortalRole.securityGuard;
      case 'vendor':         return PortalRole.vendor;
      case 'admin':          return PortalRole.admin;
      default:               return PortalRole.member;
    }
  }

  String get value {
    switch (this) {
      case PortalRole.executive:      return 'executive';
      case PortalRole.secretary:      return 'secretary';
      case PortalRole.president:      return 'president';
      case PortalRole.securityGuard:  return 'security_guard';
      case PortalRole.vendor:         return 'vendor';
      case PortalRole.admin:          return 'admin';
      case PortalRole.member:         return 'member';
    }
  }
}
