abstract final class RouteNames {
  // ============================================================
  // AUTH
  // ============================================================

  static const splash = '/';

  static const login = '/login';

  static const otpVerification = '/otp-verification';

  static const onboarding = '/onboarding';

  // ============================================================
  // HOME
  // ============================================================

  static const ownerHome = '/owner';

  static const managerHome = '/manager';

  static const caretakerHome = '/caretaker';

  static const tenantHome = '/tenant';

  static const editProfile = '/profile/edit';

  // ============================================================
  // PROPERTIES
  // ============================================================

  static const addProperty = '/owner/add-property';

  static const propertyList = '/owner/properties';

  static const propertyDetails =
      '/owner/properties/:propertyId';

  static const editProperty =
      '/owner/properties/:propertyId/edit';

  // ============================================================
  // UNITS
  // ============================================================

  static const propertyUnits =
      '/owner/properties/:propertyId/units';

  static const addUnit =
      '/owner/properties/:propertyId/units/add';

  static const unitDetails =
      '/owner/units/:unitId';

  static const editUnit =
      '/owner/units/:unitId/edit';

  // ============================================================
  // RENTS
  // ============================================================

  static const unitRentManagement =
      '/owner/units/:unitId/rent';

  static const changeUnitRent =
      '/owner/units/:unitId/rent/change';

  static const unitRentRateHistory =
      '/owner/units/:unitId/rent/history';

  static const unitMonthlyRent =
      '/owner/units/:unitId/monthly-rent';

  // ============================================================
  // TENANTS
  // ============================================================

  static const addTenant =
      '/owner/add-tenant';

  static const ownerTenants =
      '/owner/tenants';

  static const tenantDetails =
      '/owner/tenants/:tenantId';

  static const editTenant =
      '/owner/tenants/:tenantId/edit';

  static const propertyTenants =
      '/owner/properties/:propertyId/tenants';

  // ============================================================
  // TENANT ACCOUNT LINK
  // ============================================================

  static const tenantAccountLink =
      '/tenant-account-link';

  // ============================================================
  // TENANT INVITATION
  // ============================================================

  static const tenantInvitation =
      '/i/:invitationId';

  static String tenantInvitationPath(String invitationId,) {
    return '/i/${Uri.encodeComponent(
      invitationId.trim(),
    )}';
  }


// ============================================================
// BILLING
// ============================================================

  static const ownerBillingSetup =
      '/owner/billing/setup';

  static const ownerBillingRules =
      '/owner/billing/rules';
  static const billingRules =

      '/owner/billing-rules';

  static const editBillingRule =

      '/owner/billing-rules/:ruleId/edit';

  // ============================================================
  // TENANT INVITATIONS
  // ============================================================

  static const tenantInvitations =
      '/tenant/invitations';
}