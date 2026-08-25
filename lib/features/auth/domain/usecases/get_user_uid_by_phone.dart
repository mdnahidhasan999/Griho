import '../repositories/phone_lookup_repository.dart';

class GetUserByPhoneLookup {
  final PhoneLookupRepository _repository;

  const GetUserByPhoneLookup({
    required this._repository,
  });

  Future<Map<String, dynamic>?> call(String phoneNumber) {
    return _repository.getUserByPhone(
      phoneNumber.trim(),
    );
  }
}