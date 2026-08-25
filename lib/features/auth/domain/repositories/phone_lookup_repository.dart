abstract class PhoneLookupRepository {
  Future<Map<String, dynamic>?> getUserByPhone(
      String phoneNumber,
      );

  Future<void> savePhoneLookup({
    required String phoneNumber,
    required String uid,
    required String publicId,
    required String name,
    String? email,
    String? nidNumber,
  });

  Future<void> deletePhoneLookup(
      String phoneNumber,
      );
}