abstract final class RouteNames {
  // ============================================================
  // AUTH
  // ============================================================
  static const splash = '/';
  static const login = '/login';
  static const createAccount = '/create-account';
  static const forgotPassword = '/forgot-password';
  static const linkWaiting = '/link-waiting';
  static const onboarding = '/onboarding';
  static const roleSelection = '/role-selection';

  // ============================================================
  // HOME
  // ============================================================
  static const ownerHome = '/owner';
  static const more = '/more';
  static const ownerWelcome = '/owner/welcome';
  static const managerHome = '/manager';
  static const caretakerHome = '/caretaker';
  static const electricianHome = '/electrician';
  static const tenantHome = '/tenant';
  static const editProfile = '/profile/edit';

  // ============================================================
  // PROPERTIES
  // ============================================================
  static const addProperty = '/owner/add-property';
  static const propertyList = '/owner/properties';
  static const propertyDetails = '/owner/properties/:propertyId';
  static const editProperty = '/owner/properties/:propertyId/edit';

  // ============================================================
  // UNITS
  // ============================================================
  static const propertyUnits = '/owner/properties/:propertyId/units';
  static const addUnit = '/owner/properties/:propertyId/units/add';
  static const unitDetails = '/owner/units/:unitId';
  static const editUnit = '/owner/units/:unitId/edit';

  // ============================================================
  // RENTS
  // ============================================================
  static const unitRentManagement = '/owner/units/:unitId/rent';
  static const changeUnitRent = '/owner/units/:unitId/rent/change';
  static const unitRentRateHistory = '/owner/units/:unitId/rent/history';
  static const unitMonthlyRent = '/owner/units/:unitId/monthly-rent';

  // ============================================================
  // TENANTS
  // ============================================================
  static const addTenant = '/owner/add-tenant';
  static const ownerTenants = '/owner/tenants';
  static const tenantDetails = '/owner/tenants/:tenantId';
  static const editTenant = '/owner/tenants/:tenantId/edit';
  static const propertyTenants = '/owner/properties/:propertyId/tenants';


// ============================================================
// TENANT ACCOUNT LINK & INVITATION
// ============================================================

  static const tenantAccountLink = '/tenant-account-link';

  static const tenantInvitation = '/i/:invitationToken';

  static String tenantInvitationPath(String invitationToken) {
    final token = invitationToken.trim();

    if (token.isEmpty) {
      throw ArgumentError(
        'Invitation token cannot be empty.',
      );
    }

    return '/i/${Uri.encodeComponent(token)}';
  }

  // ============================================================
  // BILLING
  // ============================================================
  static const ownerBillingSetup = '/owner/billing/setup';
  static const ownerBillingRules = '/owner/billing/rules';
  static const billingRules = '/owner/billing-rules';
  static const editBillingRule = '/owner/billing-rules/:ruleId/edit';
  static const ownerPayments = '/owner/payments';
  static const tenantPayments = '/tenant/payments';

  // ============================================================
  // TENANT INVITATIONS
  // ============================================================
  static const tenantInvitations = '/tenant/invitations';
}
