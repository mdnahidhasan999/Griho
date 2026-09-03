import '../entities/repositories/tenant_repository.dart';
import '../entities/tenant_search_result.dart';

class SearchRegisteredTenant {
  final TenantRepository _repository;

  const SearchRegisteredTenant(this._repository);

  Future<TenantSearchResult?> call(String search) async {
    final normalizedSearch = search.trim();

    if (normalizedSearch.isEmpty) {
      return null;
    }

    return _repository.searchRegisteredTenant(normalizedSearch);
  }
}