abstract final class RouteNames {
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
  // TENANTS
  // ============================================================

  static const tenantDetails = '/owner/tenants/:tenantId';

  static const editTenant = '/owner/tenants/:tenantId/edit';

  static const addTenant = '/owner/add-tenant';

  static const propertyTenants = '/owner/properties/:propertyId/tenants';
}
