import 'package:firebase_auth/firebase_auth.dart';

import '../../../tenants/data/datasources/tenant_invitation_data_source.dart';
import '../../../tenants/data/datasources/tenant_data_source.dart';
import '../../../tenants/data/repositories/tenant_invitation_repository_impl.dart';
import '../../../tenants/data/repositories/tenant_repository_impl.dart';
import '../../../tenants/domain/usecases/link_and_accept_tenant_invitation.dart';
import '../../../../core/services/current_user_service.dart';

import '../../domain/entities/app_user.dart';
import '../../domain/entities/registration_intent.dart';

import '../datasources/user_profile_datasource.dart';
import '../models/app_user_model.dart';

import 'griho_id_generator.dart';

class UserRegistrationService {
  final FirebaseAuth _firebaseAuth;
  final GrihoIdGenerator _grihoIdGenerator;
  final UserProfileDataSource _userProfileDataSource;

  final TenantInvitationDataSource _tenantInvitationDataSource;
  final LinkAndAcceptTenantInvitation _linkAndAcceptTenantInvitation;

  UserRegistrationService({
    FirebaseAuth? firebaseAuth,
    GrihoIdGenerator? grihoIdGenerator,
    UserProfileDataSource? userProfileDataSource,
    TenantInvitationDataSource? tenantInvitationDataSource,
    LinkAndAcceptTenantInvitation? linkAndAcceptTenantInvitation,
  })  : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
        _grihoIdGenerator = grihoIdGenerator ?? GrihoIdGenerator(),
        _userProfileDataSource =
            userProfileDataSource ?? UserProfileDataSource(),
        _tenantInvitationDataSource =
            tenantInvitationDataSource ?? TenantInvitationDataSource(),
        _linkAndAcceptTenantInvitation =
            linkAndAcceptTenantInvitation ??
                LinkAndAcceptTenantInvitation(
                  tenantRepository: TenantRepositoryImpl(
                    dataSource: TenantDataSource(),
                    currentUserService: CurrentUserService(),
                  ),
                  invitationRepository: TenantInvitationRepositoryImpl(
                    dataSource: TenantInvitationDataSource(),
                    currentUserService: CurrentUserService(),
                  ),
                );

  // ============================================================
  // REGISTER
  // ============================================================

  Future<AppUser> register({
    required RegistrationIntent intent,
    required String name,
  }) async {
    final firebaseUser = _firebaseAuth.currentUser;

    if (firebaseUser == null) {
      throw StateError(
        'A Firebase authenticated user is required for registration.',
      );
    }

    final normalizedName = name.trim();

    if (normalizedName.isEmpty) {
      throw ArgumentError(
        'Name cannot be empty.',
      );
    }

    // ----------------------------------------------------------
    // EXISTING USER
    // ----------------------------------------------------------

    final existingUser =
    await _userProfileDataSource.getUserByUid(
      firebaseUser.uid,
    );

    if (existingUser != null) {
      return existingUser;
    }

    // ==========================================================
    // TENANT
    // ==========================================================

    if (intent == RegistrationIntent.tenant) {
      return _registerTenant(
        firebaseUser: firebaseUser,
        name: normalizedName,
      );
    }

    // ==========================================================
    // OWNER
    // ==========================================================

    return _registerOwner(
      firebaseUser: firebaseUser,
      name: normalizedName,
    );
  }

  // ============================================================
  // REGISTER OWNER
  // ============================================================

  Future<AppUser> _registerOwner({
    required User firebaseUser,
    required String name,
  }) async {
    final publicId =
    await _grihoIdGenerator.generateAndReserve();

    final now = DateTime.now();

    final user = AppUser(
      uid: firebaseUser.uid,
      publicId: publicId,
      role: UserRole.owner,
      name: name,
      phoneNumber: firebaseUser.phoneNumber,
      email: firebaseUser.email,
      photoUrl: firebaseUser.photoURL,
      isActive: true,
      createdAt: now,
      updatedAt: now,
    );

    try {
      await _userProfileDataSource.createUser(
        AppUserModel.fromEntity(user),
      );

      return user;
    } catch (error) {
      await _grihoIdGenerator.releaseReservation(
        publicId,
      );

      rethrow;
    }
  }

  // ============================================================
  // REGISTER TENANT
  // ============================================================
  //
  // Flow:
  //
  // Firebase Auth
  //      ↓
  // verified phone
  //      ↓
  // pending tenant invitation
  //      ↓
  // tenantId
  //      ↓
  // link Firebase UID
  //      ↓
  // accept invitation
  //      ↓
  // create AppUser
  //
  // ============================================================

  Future<AppUser> _registerTenant({
    required User firebaseUser,
    required String name,
  }) async {
    final phone = firebaseUser.phoneNumber?.trim();

    if (phone == null || phone.isEmpty) {
      throw StateError(
        'A verified phone number is required for tenant registration.',
      );
    }

    // ----------------------------------------------------------
    // FIND PENDING INVITATION
    // ----------------------------------------------------------

    final invitation =
    await _tenantInvitationDataSource
        .getPendingInvitationByPhone(
      phone,
    );

    // ----------------------------------------------------------
    // NO INVITATION
    //
    // Tenant can still create an account.
    // ----------------------------------------------------------

    if (invitation == null) {
      return _registerTenantWithoutInvitation(
        firebaseUser: firebaseUser,
        name: name,
        phone: phone,
      );
    }

    // ----------------------------------------------------------
    // INVITATION EXISTS
    // ----------------------------------------------------------

    final tenantId = invitation.tenantId;

    final publicId =
    await _grihoIdGenerator.generateAndReserve();

    final now = DateTime.now();

    final user = AppUser(
      uid: firebaseUser.uid,
      publicId: publicId,
      role: UserRole.tenant,
      name: name,
      phoneNumber: phone,
      email: firebaseUser.email,
      photoUrl: firebaseUser.photoURL,
      isActive: true,
      createdAt: now,
      updatedAt: now,
    );

    try {
      // --------------------------------------------------------
      // CREATE APP USER
      // --------------------------------------------------------

      await _userProfileDataSource.createUser(
        AppUserModel.fromEntity(user),
      );

      // --------------------------------------------------------
      // LINK TENANT + ACCEPT INVITATION
      // --------------------------------------------------------

      await _linkAndAcceptTenantInvitation(
        tenantId: tenantId,
        userId: firebaseUser.uid,
        invitationId: invitation.id,
      );

      return user;
    } catch (error) {
      await _grihoIdGenerator.releaseReservation(
        publicId,
      );

      rethrow;
    }
  }

  // ============================================================
  // REGISTER TENANT WITHOUT INVITATION
  // ============================================================

  Future<AppUser> _registerTenantWithoutInvitation({
    required User firebaseUser,
    required String name,
    required String phone,
  }) async {
    final publicId =
    await _grihoIdGenerator.generateAndReserve();

    final now = DateTime.now();

    final user = AppUser(
      uid: firebaseUser.uid,
      publicId: publicId,
      role: UserRole.tenant,
      name: name,
      phoneNumber: phone,
      email: firebaseUser.email,
      photoUrl: firebaseUser.photoURL,
      isActive: true,
      createdAt: now,
      updatedAt: now,
    );

    try {
      await _userProfileDataSource.createUser(
        AppUserModel.fromEntity(user),
      );

      return user;
    } catch (error) {
      await _grihoIdGenerator.releaseReservation(
        publicId,
      );

      rethrow;
    }
  }
}