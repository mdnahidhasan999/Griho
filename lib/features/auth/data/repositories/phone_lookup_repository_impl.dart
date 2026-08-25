import '../../domain/repositories/phone_lookup_repository.dart';
import '../datasources/phone_lookup_data_source.dart';

class PhoneLookupRepositoryImpl
    implements PhoneLookupRepository {
  final PhoneLookupDataSource _dataSource;

  PhoneLookupRepositoryImpl({
    PhoneLookupDataSource? dataSource,
  }) : _dataSource =
      dataSource ?? PhoneLookupDataSource();

  @override
  Future<Map<String, dynamic>?> getUserByPhone(
      String phoneNumber,
      ) {
    return _dataSource.getUserByPhone(
      phoneNumber,
    );
  }

  @override
  Future<void> savePhoneLookup({
    required String phoneNumber,
    required String uid,
    required String publicId,
    required String name,
    String? email,
    String? nidNumber,
  }) {
    return _dataSource.savePhoneLookup(
      phoneNumber: phoneNumber,
      uid: uid,
      publicId: publicId,
      name: name,
      email: email,
      nidNumber: nidNumber,
    );
  }

  @override
  Future<void> deletePhoneLookup(
      String phoneNumber,
      ) {
    return _dataSource.deletePhoneLookup(
      phoneNumber,
    );
  }
}