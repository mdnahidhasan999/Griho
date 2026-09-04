import '../entities/repositories/tenant_repository.dart';
import '../entities/tenant_search_result.dart';

class SearchRegisteredTenant {
  final TenantRepository _repository;

  const SearchRegisteredTenant({
    required this._repository,
  });

  // ============================================================
  // BY GRIHO ID
  // ============================================================

  Future<TenantSearchResult?> byPublicId(
      String publicId,
      ) async {
    final normalizedPublicId =
    publicId.trim();

    if (normalizedPublicId.isEmpty) {
      return null;
    }

    return _repository.searchRegisteredTenantByPublicId(
      normalizedPublicId,
    );
  }

  // ============================================================
  // BY PHONE
  // ============================================================

  Future<TenantSearchResult?> byPhone(
      String phone,
      ) async {
    final normalizedPhone =
    phone.trim();

    if (normalizedPhone.isEmpty) {
      return null;
    }

    return _repository.searchRegisteredTenantByPhone(
      normalizedPhone,
    );
  }
}