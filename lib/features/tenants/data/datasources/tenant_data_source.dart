import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/utils/phone_number_utils.dart';
import '../../../rents/data/models/rent_rate_model.dart';
import '../../../rents/domain/entities/rent_rate.dart';
import '../../../units/domain/entities/unit.dart';
import '../../domain/entities/tenant.dart';
import '../../domain/entities/tenant_search_result.dart';
import '../models/tenant_model.dart';

class TenantDataSource {
  final FirebaseFirestore _firestore;

  TenantDataSource({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  // ==========================================================================
  // COLLECTIONS
  // ==========================================================================

  static const String _tenantCollectionName = 'tenants';
  static const String _unitCollectionName = 'units';
  static const String _propertyCollectionName = 'properties';
  static const String _publicIdCollectionName = 'public_ids';
  static const String _phoneLookupCollectionName = 'phone_lookups';
  static const String _tenantAccessCollectionName = 'tenantAccess';
  static const String _tenancyHistoryCollectionName = 'tenancyHistories';
  static const String _rentRateCollectionName = 'rentRates';

  CollectionReference<Map<String, dynamic>> get _tenants {
    return _firestore.collection(_tenantCollectionName);
  }

  CollectionReference<Map<String, dynamic>> get _units {
    return _firestore.collection(_unitCollectionName);
  }

  CollectionReference<Map<String, dynamic>> get _properties {
    return _firestore.collection(_propertyCollectionName);
  }

  CollectionReference<Map<String, dynamic>> get _publicIds {
    return _firestore.collection(_publicIdCollectionName);
  }

  CollectionReference<Map<String, dynamic>> get _phoneLookups {
    return _firestore.collection(_phoneLookupCollectionName);
  }

  CollectionReference<Map<String, dynamic>> get _tenantAccess {
    return _firestore.collection(_tenantAccessCollectionName);
  }

  CollectionReference<Map<String, dynamic>> get _tenancyHistories {
    return _firestore.collection(_tenancyHistoryCollectionName);
  }

  CollectionReference<Map<String, dynamic>> get _rentRates {
    return _firestore.collection(_rentRateCollectionName);
  }

  // ==========================================================================
  // GET TENANT BY ID
  // ==========================================================================

  Future<TenantModel?> getTenantById(String tenantId) async {
    final normalizedId = tenantId.trim();

    if (normalizedId.isEmpty) {
      return null;
    }

    final snapshot = await _tenants.doc(normalizedId).get();

    if (!snapshot.exists) {
      return null;
    }

    return TenantModel.fromFirestore(snapshot);
  }

  // ==========================================================================
  // GET TENANT BY USER ID
  // ==========================================================================

  Future<TenantModel?> getTenantByUserId(String userId) async {
    final normalizedUserId = userId.trim();

    if (normalizedUserId.isEmpty) {
      return null;
    }

    final snapshot = await _tenants
        .where('userId', isEqualTo: normalizedUserId)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) {
      return null;
    }

    return TenantModel.fromFirestore(snapshot.docs.first);
  }

  // ==========================================================================
  // GET TENANTS BY PROPERTY
  // CURRENT OWNER ONLY
  // ==========================================================================

  Future<List<TenantModel>> getTenantsByPropertyId({
    required String propertyId,
    required String ownerId,
  }) async {
    final normalizedPropertyId = propertyId.trim();
    final normalizedOwnerId = ownerId.trim();

    if (normalizedPropertyId.isEmpty ||
        normalizedOwnerId.isEmpty) {
      return [];
    }

    final snapshot = await _tenants
        .where(
      'propertyId',
      isEqualTo: normalizedPropertyId,
    )
        .where(
      'ownerId',
      isEqualTo: normalizedOwnerId,
    )
        .orderBy(
      'createdAt',
      descending: true,
    )
        .get();

    return snapshot.docs.map(TenantModel.fromFirestore).toList();
  }

  // ==========================================================================
  // GET ACTIVE TENANT BY UNIT
  // CURRENT OWNER ONLY
  // ==========================================================================

  Future<TenantModel?> getTenantByUnitId({
    required String unitId,
    required String ownerId,
  }) async {
    final normalizedUnitId = unitId.trim();
    final normalizedOwnerId = ownerId.trim();

    if (normalizedUnitId.isEmpty ||
        normalizedOwnerId.isEmpty) {
      return null;
    }

    final snapshot = await _tenants
        .where(
      'unitId',
      isEqualTo: normalizedUnitId,
    )
        .where(
      'ownerId',
      isEqualTo: normalizedOwnerId,
    )
        .where(
      'status',
      isEqualTo: TenantStatus.active.name,
    )
        .orderBy(
      'createdAt',
      descending: true,
    )
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) {
      return null;
    }

    return TenantModel.fromFirestore(snapshot.docs.first);
  }

  // ==========================================================================
  // GET ALL ACTIVE TENANTS BY UNIT
  // CURRENT OWNER ONLY
  // ==========================================================================

  Future<List<TenantModel>> getActiveTenantsByUnitId({
    required String unitId,
    required String ownerId,
  }) async {
    final normalizedUnitId = unitId.trim();
    final normalizedOwnerId = ownerId.trim();

    if (normalizedUnitId.isEmpty ||
        normalizedOwnerId.isEmpty) {
      return [];
    }

    final snapshot = await _tenants
        .where(
      'unitId',
      isEqualTo: normalizedUnitId,
    )
        .where(
      'ownerId',
      isEqualTo: normalizedOwnerId,
    )
        .where(
      'status',
      isEqualTo: TenantStatus.active.name,
    )
        .orderBy(
      'createdAt',
      descending: true,
    )
        .get();

    return snapshot.docs.map(TenantModel.fromFirestore).toList();
  }

  // ==========================================================================
  // CREATE TENANT
  // ==========================================================================

  Future<TenantModel> createTenant({
    required TenantModel tenant,
  }) async {
    final normalizedPhone = tenant.phone.trim();
    final normalizedOwnerId = tenant.ownerId.trim();
    final normalizedPropertyId = tenant.propertyId.trim();
    final normalizedUnitId = tenant.unitId.trim();

    if (normalizedPhone.isEmpty) {
      throw StateError(
        'Tenant phone number cannot be empty.',
      );
    }

    if (normalizedOwnerId.isEmpty) {
      throw StateError(
        'Tenant owner ID cannot be empty.',
      );
    }

    if (normalizedPropertyId.isEmpty) {
      throw StateError(
        'Tenant property ID cannot be empty.',
      );
    }

    if (normalizedUnitId.isEmpty) {
      throw StateError(
        'Tenant unit ID cannot be empty.',
      );
    }

    final phoneSnapshot = await _tenants
        .where(
      'ownerId',
      isEqualTo: normalizedOwnerId,
    )
        .where(
      'phone',
      isEqualTo: normalizedPhone,
    )
        .limit(1)
        .get();

    if (phoneSnapshot.docs.isNotEmpty) {
      final existingTenant = TenantModel.fromFirestore(
        phoneSnapshot.docs.first,
      );

      throw StateError(
        'A tenant with this phone number already exists: '
            '${existingTenant.name} (${existingTenant.phone}).',
      );
    }

    if (tenant.status == TenantStatus.active) {
      final activeSnapshot = await _tenants
          .where(
        'unitId',
        isEqualTo: normalizedUnitId,
      )
          .where(
        'ownerId',
        isEqualTo: normalizedOwnerId,
      )
          .where(
        'status',
        isEqualTo: TenantStatus.active.name,
      )
          .limit(1)
          .get();

      if (activeSnapshot.docs.isNotEmpty) {
        final existingTenant = TenantModel.fromFirestore(
          activeSnapshot.docs.first,
        );

        throw StateError(
          'This unit already has an active tenant: '
              '${existingTenant.name} (${existingTenant.phone}).',
        );
      }
    }

    final tenantDocument = _tenants.doc(tenant.id);
    final propertyDocument = _properties.doc(
      normalizedPropertyId,
    );
    final unitDocument = _units.doc(
      normalizedUnitId,
    );

    await _firestore.runTransaction(
          (transaction) async {
        final propertySnapshot = await transaction.get(
          propertyDocument,
        );

        final unitSnapshot = await transaction.get(
          unitDocument,
        );

        if (!propertySnapshot.exists) {
          throw StateError(
            'Property $normalizedPropertyId does not exist.',
          );
        }

        if (!unitSnapshot.exists) {
          throw StateError(
            'Unit $normalizedUnitId does not exist.',
          );
        }

        final propertyData = propertySnapshot.data();

        if (propertyData == null) {
          throw StateError(
            'Property $normalizedPropertyId contains no data.',
          );
        }

        final propertyOwnerId =
        (propertyData['ownerId'] as String?)?.trim();

        if (propertyOwnerId != normalizedOwnerId) {
          throw StateError(
            'The selected property does not belong to the current owner.',
          );
        }

        final unitData = unitSnapshot.data();

        if (unitData == null) {
          throw StateError(
            'Unit $normalizedUnitId contains no data.',
          );
        }

        final unitPropertyId =
        (unitData['propertyId'] as String?)?.trim();

        if (unitPropertyId != normalizedPropertyId) {
          throw StateError(
            'The selected unit does not belong to the selected property.',
          );
        }

        if (tenant.status == TenantStatus.active) {
          final unitStatus = unitData['status'];

          if (unitStatus != UnitStatus.available.name) {
            throw StateError(
              'The selected unit is not available.',
            );
          }

          final existingTenantUserId =
          unitData['tenantUserId'];

          if (existingTenantUserId != null) {
            if (existingTenantUserId is! String ||
                existingTenantUserId
                    .trim()
                    .isNotEmpty) {
              throw StateError(
                'The selected unit already has a tenant.',
              );
            }
          }
        }

        transaction.set(
          tenantDocument,
          tenant.toFirestore(),
        );

        if (tenant.status == TenantStatus.active) {
          final tenantUserId = tenant.userId?.trim();

          transaction.update(
            unitDocument,
            {
              'status': UnitStatus.occupied.name,
              'tenantUserId': tenantUserId,
              'updatedAt': FieldValue.serverTimestamp(),
            },
          );

          if (tenantUserId != null &&
              tenantUserId.isNotEmpty) {
            transaction.update(
              propertyDocument,
              {
                'tenantUserIds': FieldValue.arrayUnion(
                  [tenantUserId],
                ),
                'updatedAt': FieldValue.serverTimestamp(),
              },
            );
          }
        } else {
          transaction.update(
            unitDocument,
            {
              'status': UnitStatus.available.name,
              'tenantUserId': null,
              'updatedAt': FieldValue.serverTimestamp(),
            },
          );
        }
      },
    );

    return tenant;
  }

  // ==========================================================================
  // LINK TENANT ACCOUNT
  // ==========================================================================

  Future<TenantModel> linkTenantAccount({
    required String tenantId,
    required String userId,
  }) async {
    final normalizedTenantId = tenantId.trim();
    final normalizedUserId = userId.trim();

    if (normalizedTenantId.isEmpty) {
      throw ArgumentError(
        'Tenant ID cannot be empty.',
      );
    }

    if (normalizedUserId.isEmpty) {
      throw ArgumentError(
        'Tenant user ID cannot be empty.',
      );
    }

    final tenantDocument = _tenants.doc(
      normalizedTenantId,
    );

    final tenantSnapshot = await tenantDocument.get();

    if (!tenantSnapshot.exists) {
      throw StateError(
        'Tenant $normalizedTenantId does not exist.',
      );
    }

    final tenant = TenantModel.fromFirestore(
      tenantSnapshot,
    );

    if (tenant.userId != null &&
        tenant.userId!.trim().isNotEmpty) {
      if (tenant.userId == normalizedUserId) {
        return tenant;
      }

      throw StateError(
        'This tenant is already linked to another account.',
      );
    }

    final existingUserSnapshot = await _tenants
        .where(
      'userId',
      isEqualTo: normalizedUserId,
    )
        .limit(1)
        .get();

    if (existingUserSnapshot.docs.isNotEmpty) {
      final existingTenant = TenantModel.fromFirestore(
        existingUserSnapshot.docs.first,
      );

      if (existingTenant.id != normalizedTenantId) {
        throw StateError(
          'This account is already linked to another tenant.',
        );
      }

      return existingTenant;
    }

    final tenantPropertyDocument =
    _properties.doc(tenant.propertyId);

    final tenantUnitDocument =
    _units.doc(tenant.unitId);

    await _firestore.runTransaction(
          (transaction) async {
        final currentTenantSnapshot =
        await transaction.get(
          tenantDocument,
        );

        final propertySnapshot =
        await transaction.get(
          tenantPropertyDocument,
        );

        final unitSnapshot =
        await transaction.get(
          tenantUnitDocument,
        );

        if (!currentTenantSnapshot.exists) {
          throw StateError(
            'Tenant $normalizedTenantId no longer exists.',
          );
        }

        if (!propertySnapshot.exists) {
          throw StateError(
            'Tenant property no longer exists.',
          );
        }

        if (!unitSnapshot.exists) {
          throw StateError(
            'Tenant unit no longer exists.',
          );
        }

        final currentTenant =
        TenantModel.fromFirestore(
          currentTenantSnapshot,
        );

        final currentUserId =
        currentTenant.userId?.trim();

        if (currentUserId != null &&
            currentUserId.isNotEmpty &&
            currentUserId != normalizedUserId) {
          throw StateError(
            'This tenant is already linked to another account.',
          );
        }

        final updatedTenant =
        currentTenant.copyWith(
          userId: normalizedUserId,
          accountStatus:
          TenantAccountStatus.registered,
          updatedAt: DateTime.now(),
        );

        final updatedModel =
        TenantModel.fromEntity(
          updatedTenant,
        );

        transaction.update(
          tenantDocument,
          updatedModel.toFirestore(),
        );

        if (currentTenant.status ==
            TenantStatus.active) {
          transaction.update(
            tenantUnitDocument,
            {
              'tenantUserId': normalizedUserId,
              'status': UnitStatus.occupied.name,
              'updatedAt': FieldValue.serverTimestamp(),
            },
          );

          transaction.update(
            tenantPropertyDocument,
            {
              'tenantUserIds': FieldValue.arrayUnion(
                [normalizedUserId],
              ),
              'updatedAt': FieldValue.serverTimestamp(),
            },
          );
        }
      },
    );

    final updatedSnapshot =
    await tenantDocument.get();

    if (!updatedSnapshot.exists) {
      throw StateError(
        'Tenant was linked but could not be retrieved.',
      );
    }

    return TenantModel.fromFirestore(
      updatedSnapshot,
    );
  }

  // ==========================================================================
  // UPDATE TENANT
  // ==========================================================================
  //
  // updateTenant() is only for tenant profile/data updates.
  //
  // IMPORTANT:
  //
  // - Active → inactive:
  //     Use endTenancy().
  //
  // - Inactive → active:
  //     Use startNewTenancy().
  //
  // - Active tenant property/unit movement:
  //     Not allowed here.
  //
  // - Account linking:
  //     Use linkTenantAccount().
  //
  // - Rent changes:
  //     Use RentRate functionality.
  //
  // ==========================================================================

  Future<TenantModel> updateTenant(TenantModel tenant,) async {
    final tenantId = tenant.id.trim();

    if (tenantId.isEmpty) {
      throw ArgumentError(
        'Tenant ID cannot be empty.',
      );
    }

    final tenantDocument = _tenants.doc(tenantId);

    final existingSnapshot =
    await tenantDocument.get();

    if (!existingSnapshot.exists) {
      throw StateError(
        'Tenant $tenantId does not exist.',
      );
    }

    final existingTenant =
    TenantModel.fromFirestore(
      existingSnapshot,
    );

    // --------------------------------------------------------------------------
    // NORMALIZE IDS
    // --------------------------------------------------------------------------

    final existingOwnerId =
    existingTenant.ownerId.trim();

    final newOwnerId =
    tenant.ownerId.trim();

    final oldPropertyId =
    existingTenant.propertyId.trim();

    final newPropertyId =
    tenant.propertyId.trim();

    final oldUnitId =
    existingTenant.unitId.trim();

    final newUnitId =
    tenant.unitId.trim();

    if (existingOwnerId.isEmpty) {
      throw StateError(
        'Existing tenant owner ID is missing.',
      );
    }

    if (newOwnerId.isEmpty) {
      throw ArgumentError(
        'Tenant owner ID cannot be empty.',
      );
    }

    if (oldPropertyId.isEmpty) {
      throw StateError(
        'Existing tenant property ID is missing.',
      );
    }

    if (newPropertyId.isEmpty) {
      throw ArgumentError(
        'Property ID cannot be empty.',
      );
    }

    if (oldUnitId.isEmpty) {
      throw StateError(
        'Existing tenant unit ID is missing.',
      );
    }

    if (newUnitId.isEmpty) {
      throw ArgumentError(
        'Unit ID cannot be empty.',
      );
    }

    // --------------------------------------------------------------------------
    // OWNER CANNOT CHANGE
    // --------------------------------------------------------------------------

    if (newOwnerId != existingOwnerId) {
      throw StateError(
        'Tenant owner cannot be changed through updateTenant().',
      );
    }

    // --------------------------------------------------------------------------
    // STATUS CANNOT CHANGE
    // --------------------------------------------------------------------------

    if (tenant.status != existingTenant.status) {
      throw StateError(
        'Tenant status cannot be changed through updateTenant(). '
            'Use endTenancy() or startNewTenancy().',
      );
    }

    // --------------------------------------------------------------------------
    // ACCOUNT LINK CANNOT CHANGE
    // --------------------------------------------------------------------------

    final existingUserId =
    existingTenant.userId?.trim();

    final newUserId =
    tenant.userId?.trim();

    final normalizedExistingUserId =
    existingUserId != null &&
        existingUserId.isNotEmpty
        ? existingUserId
        : null;

    final normalizedNewUserId =
    newUserId != null &&
        newUserId.isNotEmpty
        ? newUserId
        : null;

    if (normalizedNewUserId !=
        normalizedExistingUserId) {
      throw StateError(
        'Tenant account cannot be changed through updateTenant(). '
            'Use linkTenantAccount().',
      );
    }

    // --------------------------------------------------------------------------
    // ACCOUNT STATUS CANNOT CHANGE
    // --------------------------------------------------------------------------

    if (tenant.accountStatus !=
        existingTenant.accountStatus) {
      throw StateError(
        'Tenant account status cannot be changed through updateTenant().',
      );
    }

    // --------------------------------------------------------------------------
    // TENANCY START DATE CANNOT CHANGE
    // --------------------------------------------------------------------------

    if (tenant.tenancyStartedAt !=
        existingTenant.tenancyStartedAt) {
      throw StateError(
        'Tenancy start date cannot be changed through updateTenant().',
      );
    }

    // --------------------------------------------------------------------------
    // PHONE VALIDATION
    // --------------------------------------------------------------------------

    final normalizedPhone =
    tenant.phone.trim();

    if (normalizedPhone.isEmpty) {
      throw ArgumentError(
        'Tenant phone number cannot be empty.',
      );
    }

    // --------------------------------------------------------------------------
    // DUPLICATE PHONE CHECK
    // --------------------------------------------------------------------------

    final phoneSnapshot = await _tenants
        .where(
      'ownerId',
      isEqualTo: existingOwnerId,
    )
        .where(
      'phone',
      isEqualTo: normalizedPhone,
    )
        .limit(2)
        .get();

    for (final document in phoneSnapshot.docs) {
      if (document.id == tenantId) {
        continue;
      }

      final duplicate =
      TenantModel.fromFirestore(
        document,
      );

      throw StateError(
        'A tenant with this phone number already exists: '
            '${duplicate.name} (${duplicate.phone}).',
      );
    }

    // --------------------------------------------------------------------------
    // ACTIVE TENANT CANNOT MOVE
    // --------------------------------------------------------------------------

    final isActive =
        existingTenant.status ==
            TenantStatus.active;

    final propertyChanged =
        oldPropertyId != newPropertyId;

    final unitChanged =
        oldUnitId != newUnitId;

    if (isActive &&
        (propertyChanged || unitChanged)) {
      throw StateError(
        'An active tenant cannot be moved to another property or unit '
            'through updateTenant(). End the current tenancy first, then '
            'start a new tenancy.',
      );
    }

    // --------------------------------------------------------------------------
    // DOCUMENT REFERENCES
    // --------------------------------------------------------------------------

    final newPropertyDocument =
    _properties.doc(newPropertyId);

    final newUnitDocument =
    _units.doc(newUnitId);

    // --------------------------------------------------------------------------
    // TRANSACTION
    // --------------------------------------------------------------------------

    await _firestore.runTransaction(
          (transaction) async {
        // ----------------------------------------------------------------------
        // ALL READS FIRST
        // ----------------------------------------------------------------------

        final currentTenantSnapshot =
        await transaction.get(
          tenantDocument,
        );

        final newPropertySnapshot =
        await transaction.get(
          newPropertyDocument,
        );

        final newUnitSnapshot =
        await transaction.get(
          newUnitDocument,
        );

        // ----------------------------------------------------------------------
        // TENANT VALIDATION
        // ----------------------------------------------------------------------

        if (!currentTenantSnapshot.exists) {
          throw StateError(
            'Tenant $tenantId no longer exists.',
          );
        }

        final currentTenant =
        TenantModel.fromFirestore(
          currentTenantSnapshot,
        );

        if (currentTenant.ownerId.trim() !=
            existingOwnerId) {
          throw StateError(
            'Tenant owner changed unexpectedly.',
          );
        }

        if (currentTenant.status !=
            existingTenant.status) {
          throw StateError(
            'Tenant status changed unexpectedly.',
          );
        }

        final currentUserId =
        currentTenant.userId?.trim();

        final normalizedCurrentUserId =
        currentUserId != null &&
            currentUserId.isNotEmpty
            ? currentUserId
            : null;

        if (normalizedCurrentUserId !=
            normalizedExistingUserId) {
          throw StateError(
            'Tenant account link changed unexpectedly.',
          );
        }

        // ----------------------------------------------------------------------
        // PROPERTY VALIDATION
        // ----------------------------------------------------------------------

        if (!newPropertySnapshot.exists) {
          throw StateError(
            'Property $newPropertyId does not exist.',
          );
        }

        final propertyData =
        newPropertySnapshot.data();

        if (propertyData == null) {
          throw StateError(
            'Property $newPropertyId contains no data.',
          );
        }

        final propertyOwnerId =
        (propertyData['ownerId'] as String?)
            ?.trim();

        if (propertyOwnerId != existingOwnerId) {
          throw StateError(
            'The selected property does not belong to the current owner.',
          );
        }

        // ----------------------------------------------------------------------
        // UNIT VALIDATION
        // ----------------------------------------------------------------------

        if (!newUnitSnapshot.exists) {
          throw StateError(
            'Unit $newUnitId does not exist.',
          );
        }

        final unitData =
        newUnitSnapshot.data();

        if (unitData == null) {
          throw StateError(
            'Unit $newUnitId contains no data.',
          );
        }

        final unitPropertyId =
        (unitData['propertyId'] as String?)
            ?.trim();

        if (unitPropertyId != newPropertyId) {
          throw StateError(
            'The selected unit does not belong to the selected property.',
          );
        }

        // ----------------------------------------------------------------------
        // INACTIVE TENANT UNIT VALIDATION
        // ----------------------------------------------------------------------
        //
        // An inactive tenant can have its stored property/unit changed.
        //
        // But updateTenant() must NOT occupy the new unit.
        //
        // A real new tenancy must use startNewTenancy().
        //
        // ----------------------------------------------------------------------

        if (!isActive) {
          final unitStatus =
          unitData['status'];

          final unitTenantUserId =
          unitData['tenantUserId'];

          final hasTenantUser =
              unitTenantUserId is String &&
                  unitTenantUserId
                      .trim()
                      .isNotEmpty;

          if (newUnitId != oldUnitId &&
              unitStatus != UnitStatus.available.name) {
            throw StateError(
              'The selected unit is not available.',
            );
          }

          if (newUnitId != oldUnitId &&
              hasTenantUser) {
            throw StateError(
              'The selected unit already has a tenant.',
            );
          }
        }

        // ----------------------------------------------------------------------
        // CREATE UPDATED TENANT
        // ----------------------------------------------------------------------

        final updatedTenant =
        currentTenant.copyWith(
          name: tenant.name.trim(),
          phone: normalizedPhone,
          propertyId: newPropertyId,
          unitId: newUnitId,
          updatedAt: DateTime.now(),
        );

        // ----------------------------------------------------------------------
        // SAVE TENANT
        // ----------------------------------------------------------------------

        transaction.update(
          tenantDocument,
          TenantModel.fromEntity(
            updatedTenant,
          ).toFirestore(),
        );

        // ----------------------------------------------------------------------
        // ACTIVE TENANT
        // ----------------------------------------------------------------------
        //
        // Active tenant cannot move.
        //
        // Therefore only profile data is updated.
        //
        // ----------------------------------------------------------------------

        if (isActive) {
          return;
        }

        // ----------------------------------------------------------------------
        // INACTIVE TENANT
        // ----------------------------------------------------------------------
        //
        // No occupancy update is performed.
        //
        // startNewTenancy() owns the actual occupancy operation.
        //
        // ----------------------------------------------------------------------

        if (newPropertyId == oldPropertyId &&
            newUnitId == oldUnitId) {
          return;
        }
      },
    );

    // --------------------------------------------------------------------------
    // RETURN UPDATED TENANT
    // --------------------------------------------------------------------------

    final updatedSnapshot =
    await tenantDocument.get();

    if (!updatedSnapshot.exists) {
      throw StateError(
        'Tenant was updated but could not be retrieved.',
      );
    }

    return TenantModel.fromFirestore(
      updatedSnapshot,
    );
  }

  // ==========================================================================
  // CLEANUP DUPLICATE ACTIVE TENANTS
  // ==========================================================================

  Future<void> cleanupDuplicateActiveTenants({
    required String unitId,
    required String ownerId,
    required String keepTenantId,
  }) async {
    final normalizedUnitId = unitId.trim();
    final normalizedOwnerId = ownerId.trim();
    final normalizedKeepTenantId = keepTenantId.trim();

    if (normalizedUnitId.isEmpty ||
        normalizedOwnerId.isEmpty ||
        normalizedKeepTenantId.isEmpty) {
      return;
    }

    final snapshot = await _tenants
        .where(
      'unitId',
      isEqualTo: normalizedUnitId,
    )
        .where(
      'ownerId',
      isEqualTo: normalizedOwnerId,
    )
        .where(
      'status',
      isEqualTo: TenantStatus.active.name,
    )
        .get();

    final duplicateDocuments = snapshot.docs
        .where(
          (document) =>
      document.id != normalizedKeepTenantId,
    )
        .toList();

    if (duplicateDocuments.isEmpty) {
      return;
    }

    final batch = _firestore.batch();

    for (final document in duplicateDocuments) {
      batch.update(
        document.reference,
        {
          'status': TenantStatus.inactive.name,
          'updatedAt': FieldValue.serverTimestamp(),
        },
      );
    }

    await batch.commit();
  }

  // ==========================================================================
  // END TENANCY
  // ==========================================================================
  //
  // Rent belongs to Unit, not Tenant.
  //
  // When tenancy ends:
  //
  // 1. Current Unit RentRate is found.
  // 2. RentRate amount is snapshotted into tenancy history.
  // 3. Current RentRate is closed.
  // 4. Tenant becomes inactive.
  // 5. Unit becomes available.
  // 6. Tenant is removed from property tenant list.
  // 7. Tenant access is deleted.
  //
  // ==========================================================================

  Future<TenantModel> endTenancy({
    required String tenantId,
    required String ownerId,
  }) async {
    final normalizedTenantId =
    tenantId.trim();

    final normalizedOwnerId =
    ownerId.trim();

    if (normalizedTenantId.isEmpty) {
      throw ArgumentError(
        'Tenant ID cannot be empty.',
      );
    }

    if (normalizedOwnerId.isEmpty) {
      throw ArgumentError(
        'Owner ID cannot be empty.',
      );
    }

    final tenantDocument =
    _tenants.doc(normalizedTenantId);

    // --------------------------------------------------------------------------
    // READ TENANT BEFORE TRANSACTION
    // --------------------------------------------------------------------------

    final tenantSnapshot =
    await tenantDocument.get();

    if (!tenantSnapshot.exists) {
      throw StateError(
        'Tenant $normalizedTenantId does not exist.',
      );
    }

    final tenant =
    TenantModel.fromFirestore(
      tenantSnapshot,
    );

    if (tenant.ownerId != normalizedOwnerId) {
      throw StateError(
        'This tenant does not belong to the current owner.',
      );
    }

    if (tenant.status == TenantStatus.inactive) {
      throw StateError(
        'This tenant is already inactive.',
      );
    }

    final normalizedPropertyId =
    tenant.propertyId.trim();

    final normalizedUnitId =
    tenant.unitId.trim();

    if (normalizedPropertyId.isEmpty) {
      throw StateError(
        'Tenant property ID is missing.',
      );
    }

    if (normalizedUnitId.isEmpty) {
      throw StateError(
        'Tenant unit ID is missing.',
      );
    }

    final tenancyStartedAt =
        tenant.tenancyStartedAt;

    if (tenancyStartedAt == null) {
      throw StateError(
        'Tenancy start date is missing.',
      );
    }

    final endedAt = DateTime.now();

    if (endedAt.isBefore(tenancyStartedAt)) {
      throw StateError(
        'Tenancy end date cannot be before tenancy start date.',
      );
    }

    // --------------------------------------------------------------------------
    // FIND CURRENT UNIT RENT RATE
    // --------------------------------------------------------------------------

    final rentRateSnapshot = await _rentRates
        .where(
      'ownerId',
      isEqualTo: normalizedOwnerId,
    )
        .where(
      'unitId',
      isEqualTo: normalizedUnitId,
    )
        .where(
      'effectiveFrom',
      isLessThanOrEqualTo:
      Timestamp.fromDate(endedAt),
    )
        .orderBy(
      'effectiveFrom',
      descending: true,
    )
        .limit(1)
        .get();

    if (rentRateSnapshot.docs.isEmpty) {
      throw StateError(
        'No current rent rate was found for this unit.',
      );
    }

    final rentRateQueryDocument =
        rentRateSnapshot.docs.first;

    final queriedRentRate =
    RentRateModel.fromFirestore(
      rentRateQueryDocument,
    );

    if (!queriedRentRate.isApplicableAt(endedAt)) {
      throw StateError(
        'No rent rate is currently applicable to this unit.',
      );
    }

    final rentRateDocument =
        rentRateQueryDocument.reference;

    // --------------------------------------------------------------------------
    // DOCUMENT REFERENCES
    // --------------------------------------------------------------------------

    final propertyDocument =
    _properties.doc(normalizedPropertyId);

    final unitDocument =
    _units.doc(normalizedUnitId);

    // --------------------------------------------------------------------------
    // TRANSACTION
    // --------------------------------------------------------------------------

    await _firestore.runTransaction(
          (transaction) async {
        // ----------------------------------------------------------------------
        // ALL READS FIRST
        // ----------------------------------------------------------------------

        final currentTenantSnapshot =
        await transaction.get(
          tenantDocument,
        );

        final propertySnapshot =
        await transaction.get(
          propertyDocument,
        );

        final unitSnapshot =
        await transaction.get(
          unitDocument,
        );

        final currentRentRateSnapshot =
        await transaction.get(
          rentRateDocument,
        );

        // ----------------------------------------------------------------------
        // TENANT VALIDATION
        // ----------------------------------------------------------------------

        if (!currentTenantSnapshot.exists) {
          throw StateError(
            'Tenant $normalizedTenantId no longer exists.',
          );
        }

        final currentTenant =
        TenantModel.fromFirestore(
          currentTenantSnapshot,
        );

        if (currentTenant.ownerId !=
            normalizedOwnerId) {
          throw StateError(
            'This tenant does not belong to the current owner.',
          );
        }

        if (currentTenant.status ==
            TenantStatus.inactive) {
          throw StateError(
            'This tenancy has already ended.',
          );
        }

        if (currentTenant.propertyId.trim() !=
            normalizedPropertyId) {
          throw StateError(
            'Tenant property changed unexpectedly.',
          );
        }

        if (currentTenant.unitId.trim() !=
            normalizedUnitId) {
          throw StateError(
            'Tenant unit changed unexpectedly.',
          );
        }

        // ----------------------------------------------------------------------
        // PROPERTY VALIDATION
        // ----------------------------------------------------------------------

        if (!propertySnapshot.exists) {
          throw StateError(
            'Tenant property no longer exists.',
          );
        }

        final propertyData =
        propertySnapshot.data();

        if (propertyData == null) {
          throw StateError(
            'Tenant property contains no data.',
          );
        }

        final propertyOwnerId =
        (propertyData['ownerId'] as String?)?.trim();

        if (propertyOwnerId != normalizedOwnerId) {
          throw StateError(
            'Tenant property does not belong to the current owner.',
          );
        }

        // ----------------------------------------------------------------------
        // UNIT VALIDATION
        // ----------------------------------------------------------------------

        if (!unitSnapshot.exists) {
          throw StateError(
            'Tenant unit no longer exists.',
          );
        }

        final unitData =
        unitSnapshot.data();

        if (unitData == null) {
          throw StateError(
            'Tenant unit contains no data.',
          );
        }

        final unitPropertyId =
        (unitData['propertyId'] as String?)?.trim();

        if (unitPropertyId != normalizedPropertyId) {
          throw StateError(
            'Tenant unit does not belong to the tenant property.',
          );
        }

        // ----------------------------------------------------------------------
        // RENT RATE VALIDATION
        // ----------------------------------------------------------------------

        if (!currentRentRateSnapshot.exists) {
          throw StateError(
            'The current rent rate no longer exists.',
          );
        }

        final currentRentRate =
        RentRateModel.fromFirestore(
          currentRentRateSnapshot,
        );

        if (currentRentRate.ownerId !=
            normalizedOwnerId) {
          throw StateError(
            'Current rent rate does not belong to the current owner.',
          );
        }

        if (currentRentRate.propertyId !=
            normalizedPropertyId) {
          throw StateError(
            'Current rent rate does not belong to the tenant property.',
          );
        }

        if (currentRentRate.unitId !=
            normalizedUnitId) {
          throw StateError(
            'Current rent rate does not belong to the tenant unit.',
          );
        }

        if (!currentRentRate.isApplicableAt(endedAt)) {
          throw StateError(
            'The current rent rate is no longer applicable.',
          );
        }

        if (currentRentRate.amount <= 0) {
          throw StateError(
            'Current rent rate amount is invalid.',
          );
        }

        // ----------------------------------------------------------------------
        // PROPERTY SNAPSHOT
        // ----------------------------------------------------------------------

        final propertyName =
        propertyData['name'];

        if (propertyName is! String ||
            propertyName
                .trim()
                .isEmpty) {
          throw StateError(
            'Property name is missing or invalid.',
          );
        }

        final propertyCode =
        propertyData['propertyCode'];

        if (propertyCode is! String ||
            propertyCode
                .trim()
                .isEmpty) {
          throw StateError(
            'Property code is missing or invalid.',
          );
        }

        String? propertyAddress;

        final propertyAddressValue =
        propertyData['address'];

        if (propertyAddressValue != null) {
          if (propertyAddressValue is! String) {
            throw StateError(
              'Property address is invalid.',
            );
          }

          final value =
          propertyAddressValue.trim();

          if (value.isNotEmpty) {
            propertyAddress = value;
          }
        }

        // ----------------------------------------------------------------------
        // UNIT SNAPSHOT
        // ----------------------------------------------------------------------

        final unitNumber =
        unitData['unitNumber'];

        if (unitNumber is! String ||
            unitNumber
                .trim()
                .isEmpty) {
          throw StateError(
            'Unit number is missing or invalid.',
          );
        }

        String? unitName;

        final unitNameValue =
        unitData['name'];

        if (unitNameValue != null) {
          if (unitNameValue is! String) {
            throw StateError(
              'Unit name is invalid.',
            );
          }

          final value =
          unitNameValue.trim();

          if (value.isNotEmpty) {
            unitName = value;
          }
        }

        final floorNumberValue =
        unitData['floorNumber'];

        if (floorNumberValue is! num) {
          throw StateError(
            'Unit floor number is missing or invalid.',
          );
        }

        final floorNumber =
        floorNumberValue.toInt();

        if (floorNumber < 1) {
          throw StateError(
            'Unit floor number is invalid.',
          );
        }

        // ----------------------------------------------------------------------
        // CREATE TENANCY HISTORY SNAPSHOT
        // ----------------------------------------------------------------------

        final historyDocument =
        _tenancyHistories.doc();

        transaction.set(
          historyDocument,
          {
            'tenantId': normalizedTenantId,
            'tenantUserId':
            currentTenant.userId?.trim(),
            'ownerId': normalizedOwnerId,
            'tenantName': currentTenant.name.trim(),
            'propertyId': normalizedPropertyId,
            'propertyName': propertyName.trim(),
            'propertyCode': propertyCode.trim(),
            'propertyAddress': propertyAddress,
            'unitId': normalizedUnitId,
            'unitNumber': unitNumber.trim(),
            'unitName': unitName,
            'floorNumber': floorNumber,
            'monthlyRent': currentRentRate.amount,
            'rentRateId': currentRentRate.id,
            'startedAt':
            Timestamp.fromDate(tenancyStartedAt),
            'endedAt':
            Timestamp.fromDate(endedAt),
            'status': 'ended',
            'createdAt':
            FieldValue.serverTimestamp(),
          },
        );

        // ----------------------------------------------------------------------
        // CLOSE CURRENT RENT RATE
        // ----------------------------------------------------------------------

        transaction.update(
          rentRateDocument,
          {
            'effectiveTo':
            Timestamp.fromDate(endedAt),
            'updatedAt':
            FieldValue.serverTimestamp(),
          },
        );

        // ----------------------------------------------------------------------
        // UPDATE TENANT
        // ----------------------------------------------------------------------

        final updatedTenant =
        currentTenant.copyWith(
          status: TenantStatus.inactive,
          updatedAt: endedAt,
        );

        transaction.update(
          tenantDocument,
          TenantModel.fromEntity(
            updatedTenant,
          ).toFirestore(),
        );

        // ----------------------------------------------------------------------
        // MAKE UNIT AVAILABLE
        // ----------------------------------------------------------------------

        transaction.update(
          unitDocument,
          {
            'status': UnitStatus.available.name,
            'tenantUserId': null,
            'updatedAt': FieldValue.serverTimestamp(),
          },
        );

        // ----------------------------------------------------------------------
        // REMOVE TENANT FROM PROPERTY
        // ----------------------------------------------------------------------

        final tenantUserId =
        currentTenant.userId?.trim();

        if (tenantUserId != null &&
            tenantUserId.isNotEmpty) {
          transaction.update(
            propertyDocument,
            {
              'tenantUserIds':
              FieldValue.arrayRemove(
                [tenantUserId],
              ),
              'updatedAt':
              FieldValue.serverTimestamp(),
            },
          );

          transaction.delete(
            _tenantAccess.doc(tenantUserId),
          );
        }
      },
    );

    // --------------------------------------------------------------------------
    // RETURN UPDATED TENANT
    // --------------------------------------------------------------------------

    final updatedSnapshot =
    await tenantDocument.get();

    if (!updatedSnapshot.exists) {
      throw StateError(
        'Tenancy was ended but tenant could not be retrieved.',
      );
    }

    return TenantModel.fromFirestore(
      updatedSnapshot,
    );
  }

  // ==========================================================================
  // START NEW TENANCY
  // ==========================================================================
  //
  // Rent belongs to Unit, not Tenant.
  //
  // Cases:
  //
  // 1. Unit has no current RentRate:
  //    → create initial RentRate.
  //
  // 2. Unit has current RentRate and agreed amount is SAME:
  //    → keep existing RentRate.
  //
  // 3. Unit has current RentRate and agreed amount is DIFFERENT:
  //    → close old RentRate.
  //    → create new Unit RentRate.
  //
  // ==========================================================================

  Future<TenantModel> startNewTenancy({
    required String tenantId,
    required String propertyId,
    required String unitId,
    required String ownerId,
    required double amount,
  }) async {
    final normalizedTenantId =
    tenantId.trim();

    final normalizedPropertyId =
    propertyId.trim();

    final normalizedUnitId =
    unitId.trim();

    final normalizedOwnerId =
    ownerId.trim();

    if (normalizedTenantId.isEmpty) {
      throw ArgumentError(
        'Tenant ID cannot be empty.',
      );
    }

    if (normalizedPropertyId.isEmpty) {
      throw ArgumentError(
        'Property ID cannot be empty.',
      );
    }

    if (normalizedUnitId.isEmpty) {
      throw ArgumentError(
        'Unit ID cannot be empty.',
      );
    }

    if (normalizedOwnerId.isEmpty) {
      throw ArgumentError(
        'Owner ID cannot be empty.',
      );
    }

    if (amount <= 0) {
      throw ArgumentError(
        'Rent amount must be greater than zero.',
      );
    }

    final tenantDocument =
    _tenants.doc(normalizedTenantId);

    final propertyDocument =
    _properties.doc(normalizedPropertyId);

    final unitDocument =
    _units.doc(normalizedUnitId);

    final now = DateTime.now();

    // --------------------------------------------------------------------------
    // FIND CURRENT UNIT RENT RATE
    // --------------------------------------------------------------------------

    final currentRentSnapshot =
    await _rentRates
        .where(
      'ownerId',
      isEqualTo: normalizedOwnerId,
    )
        .where(
      'unitId',
      isEqualTo: normalizedUnitId,
    )
        .where(
      'effectiveFrom',
      isLessThanOrEqualTo:
      Timestamp.fromDate(now),
    )
        .orderBy(
      'effectiveFrom',
      descending: true,
    )
        .limit(1)
        .get();

    DocumentReference<Map<String, dynamic>>?
    currentRentRateDocument;

    if (currentRentSnapshot.docs.isNotEmpty) {
      final document =
          currentRentSnapshot.docs.first;

      final rate =
      RentRateModel.fromFirestore(document);

      if (rate.isApplicableAt(now)) {
        currentRentRateDocument =
            document.reference;
      }
    }

    // --------------------------------------------------------------------------
    // CHECK FUTURE RENT RATE
    // --------------------------------------------------------------------------

    final futureRentSnapshot =
    await _rentRates
        .where(
      'ownerId',
      isEqualTo: normalizedOwnerId,
    )
        .where(
      'unitId',
      isEqualTo: normalizedUnitId,
    )
        .where(
      'effectiveFrom',
      isGreaterThan:
      Timestamp.fromDate(now),
    )
        .orderBy(
      'effectiveFrom',
      descending: false,
    )
        .limit(1)
        .get();

    // --------------------------------------------------------------------------
    // TRANSACTION
    // --------------------------------------------------------------------------

    await _firestore.runTransaction(
          (transaction) async {
        // ----------------------------------------------------------------------
        // ALL READS FIRST
        // ----------------------------------------------------------------------

        final tenantSnapshot =
        await transaction.get(
          tenantDocument,
        );

        final propertySnapshot =
        await transaction.get(
          propertyDocument,
        );

        final unitSnapshot =
        await transaction.get(
          unitDocument,
        );

        DocumentSnapshot<Map<String, dynamic>>?
        transactionCurrentRentSnapshot;

        if (currentRentRateDocument != null) {
          transactionCurrentRentSnapshot =
          await transaction.get(
            currentRentRateDocument,
          );
        }

        // ----------------------------------------------------------------------
        // TENANT VALIDATION
        // ----------------------------------------------------------------------

        if (!tenantSnapshot.exists) {
          throw StateError(
            'Tenant $normalizedTenantId does not exist.',
          );
        }

        final tenant =
        TenantModel.fromFirestore(
          tenantSnapshot,
        );

        if (tenant.ownerId !=
            normalizedOwnerId) {
          throw StateError(
            'This tenant does not belong to the current owner.',
          );
        }

        if (tenant.status !=
            TenantStatus.inactive) {
          throw StateError(
            'Only an inactive tenant can start a new tenancy.',
          );
        }

        // ----------------------------------------------------------------------
        // TENANT ACCOUNT VALIDATION
        // ----------------------------------------------------------------------

        if (tenant.accountStatus !=
            TenantAccountStatus.registered) {
          throw StateError(
            'Tenant account must be registered before starting a new tenancy.',
          );
        }

        final tenantUserId =
        tenant.userId?.trim();

        if (tenantUserId == null ||
            tenantUserId.isEmpty) {
          throw StateError(
            'Tenant account is not linked.',
          );
        }

        // ----------------------------------------------------------------------
        // PROPERTY VALIDATION
        // ----------------------------------------------------------------------

        if (!propertySnapshot.exists) {
          throw StateError(
            'Property $normalizedPropertyId does not exist.',
          );
        }

        final propertyData =
        propertySnapshot.data();

        if (propertyData == null) {
          throw StateError(
            'Property $normalizedPropertyId contains no data.',
          );
        }

        final propertyOwnerId =
        (propertyData['ownerId'] as String?)
            ?.trim();

        if (propertyOwnerId !=
            normalizedOwnerId) {
          throw StateError(
            'The selected property does not belong to the current owner.',
          );
        }

        // ----------------------------------------------------------------------
        // UNIT VALIDATION
        // ----------------------------------------------------------------------

        if (!unitSnapshot.exists) {
          throw StateError(
            'Unit $normalizedUnitId does not exist.',
          );
        }

        final unitData =
        unitSnapshot.data();

        if (unitData == null) {
          throw StateError(
            'Unit $normalizedUnitId contains no data.',
          );
        }

        final unitPropertyId =
        (unitData['propertyId'] as String?)
            ?.trim();

        if (unitPropertyId !=
            normalizedPropertyId) {
          throw StateError(
            'The selected unit does not belong to the selected property.',
          );
        }

        final unitStatus =
        unitData['status'];

        if (unitStatus !=
            UnitStatus.available.name) {
          throw StateError(
            'The selected unit is not available.',
          );
        }

        final existingTenantUserId =
        unitData['tenantUserId'];

        if (existingTenantUserId != null) {
          if (existingTenantUserId is! String ||
              existingTenantUserId
                  .trim()
                  .isNotEmpty) {
            throw StateError(
              'The selected unit already has a tenant.',
            );
          }
        }

        // ----------------------------------------------------------------------
        // REVALIDATE CURRENT RENT RATE
        // ----------------------------------------------------------------------

        RentRateModel?
        transactionCurrentRentRate;

        if (transactionCurrentRentSnapshot !=
            null) {
          if (!transactionCurrentRentSnapshot
              .exists) {
            throw StateError(
              'The current rent rate no longer exists.',
            );
          }

          final rate =
          RentRateModel.fromFirestore(
            transactionCurrentRentSnapshot,
          );

          if (rate.isApplicableAt(now)) {
            transactionCurrentRentRate =
                rate;
          }
        }

        // ----------------------------------------------------------------------
        // DETERMINE RENT RATE ACTION
        // ----------------------------------------------------------------------

        final shouldCreateNewRate =
            transactionCurrentRentRate ==
                null ||
                transactionCurrentRentRate
                    .amount !=
                    amount;

        // ----------------------------------------------------------------------
        // FUTURE RATE CONFLICT
        // ----------------------------------------------------------------------

        if (shouldCreateNewRate &&
            futureRentSnapshot.docs.isNotEmpty) {
          throw StateError(
            'A future rent rate is already scheduled for this unit. '
                'Please review or cancel the scheduled rent change first.',
          );
        }

        // ----------------------------------------------------------------------
        // NEW RENT RATE
        // ----------------------------------------------------------------------

        DocumentReference<Map<String, dynamic>>?
        newRentRateDocument;

        RentRateModel? newRentRate;

        if (shouldCreateNewRate) {
          newRentRateDocument =
              _rentRates.doc();

          final source =
          transactionCurrentRentRate == null
              ? RentRateSource.initial
              : RentRateSource.unit;

          newRentRate =
              RentRateModel(
                id: newRentRateDocument.id,
                ownerId: normalizedOwnerId,
                propertyId: normalizedPropertyId,
                unitId: normalizedUnitId,
                amount: amount,
                effectiveFrom: now,
                effectiveTo: null,
                source: source,
                previousRentRateId:
                transactionCurrentRentRate?.id,
                nextRentRateId: null,
                createdAt: now,
                updatedAt: now,
              );
        }

        // ----------------------------------------------------------------------
        // UPDATE TENANT
        // ----------------------------------------------------------------------

        final updatedTenant =
        tenant.copyWith(
          propertyId: normalizedPropertyId,
          unitId: normalizedUnitId,
          status: TenantStatus.active,
          tenancyStartedAt: now,
          updatedAt: now,
        );

        transaction.update(
          tenantDocument,
          TenantModel.fromEntity(
            updatedTenant,
          ).toFirestore(),
        );

        // ----------------------------------------------------------------------
        // OCCUPY UNIT
        // ----------------------------------------------------------------------

        transaction.update(
          unitDocument,
          {
            'status': UnitStatus.occupied.name,
            'tenantUserId': tenantUserId,
            'updatedAt': FieldValue.serverTimestamp(),
          },
        );

        // ----------------------------------------------------------------------
        // ADD TENANT TO PROPERTY
        // ----------------------------------------------------------------------

        transaction.update(
          propertyDocument,
          {
            'tenantUserIds': FieldValue.arrayUnion(
              [tenantUserId],
            ),
            'updatedAt': FieldValue.serverTimestamp(),
          },
        );

        // ----------------------------------------------------------------------
        // CREATE TENANT ACCESS
        // ----------------------------------------------------------------------

        final tenantAccessDocument =
        _tenantAccess.doc(tenantUserId);

        transaction.set(
          tenantAccessDocument,
          {
            'userId': tenantUserId,
            'tenantId': normalizedTenantId,
            'ownerId': normalizedOwnerId,
            'propertyId': normalizedPropertyId,
            'unitId': normalizedUnitId,
            'invitationId': null,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          },
        );

        // ----------------------------------------------------------------------
        // RENT RATE UPDATE
        // ----------------------------------------------------------------------

        if (shouldCreateNewRate) {
          // --------------------------------------------------------------------
          // CLOSE PREVIOUS CURRENT RATE
          // --------------------------------------------------------------------

          if (transactionCurrentRentRate != null &&
              currentRentRateDocument != null) {
            transaction.update(
              currentRentRateDocument,
              {
                'effectiveTo':
                Timestamp.fromDate(now),
                'nextRentRateId':
                newRentRateDocument!.id,
                'updatedAt':
                FieldValue.serverTimestamp(),
              },
            );
          }

          // --------------------------------------------------------------------
          // CREATE NEW UNIT RENT RATE
          // --------------------------------------------------------------------

          transaction.set(
            newRentRateDocument!,
            newRentRate!.toFirestore(),
          );
        }
      },
    );

    // --------------------------------------------------------------------------
    // RETURN UPDATED TENANT
    // --------------------------------------------------------------------------

    final updatedSnapshot =
    await tenantDocument.get();

    if (!updatedSnapshot.exists) {
      throw StateError(
        'New tenancy was started but tenant could not be retrieved.',
      );
    }

    return TenantModel.fromFirestore(
      updatedSnapshot,
    );
  }

  // ==========================================================================
  // DELETE TENANT
  // ==========================================================================
  //
  // Rules:
  //
  // 1. Active tenant cannot be deleted directly.
  //    → endTenancy() must be called first.
  //
  // 2. Inactive tenant can be deleted.
  //
  // 3. Tenancy history is preserved.
  //
  // 4. RentRate history is preserved.
  //    → RentRate is NOT deleted here.
  //
  // 5. Tenant access is removed.
  //
  // 6. Unit is cleaned only if it is still linked to this tenant's account.
  //
  // ==========================================================================

  Future<void> deleteTenant(String tenantId) async {
    final normalizedTenantId =
    tenantId.trim();

    if (normalizedTenantId.isEmpty) {
      return;
    }

    final tenantDocument =
    _tenants.doc(normalizedTenantId);

    await _firestore.runTransaction(
          (transaction) async {
        // ----------------------------------------------------------------------
        // READ TENANT
        // ----------------------------------------------------------------------

        final tenantSnapshot =
        await transaction.get(
          tenantDocument,
        );

        if (!tenantSnapshot.exists) {
          return;
        }

        final tenant =
        TenantModel.fromFirestore(
          tenantSnapshot,
        );

        // ----------------------------------------------------------------------
        // ACTIVE TENANT PROTECTION
        // ----------------------------------------------------------------------

        if (tenant.status ==
            TenantStatus.active) {
          throw StateError(
            'Active tenant cannot be deleted directly. '
                'End the tenancy first.',
          );
        }

        // ----------------------------------------------------------------------
        // NORMALIZE REFERENCES
        // ----------------------------------------------------------------------

        final propertyId =
        tenant.propertyId.trim();

        final unitId =
        tenant.unitId.trim();

        final tenantUserId =
        tenant.userId?.trim();

        final propertyDocument =
        propertyId.isEmpty
            ? null
            : _properties.doc(propertyId);

        final unitDocument =
        unitId.isEmpty
            ? null
            : _units.doc(unitId);

        final tenantAccessDocument =
        tenantUserId != null &&
            tenantUserId.isNotEmpty
            ? _tenantAccess.doc(
          tenantUserId,
        )
            : null;

        // ----------------------------------------------------------------------
        // READ PROPERTY
        // ----------------------------------------------------------------------

        DocumentSnapshot<Map<String, dynamic>>?
        propertySnapshot;

        if (propertyDocument != null) {
          propertySnapshot =
          await transaction.get(
            propertyDocument,
          );
        }

        // ----------------------------------------------------------------------
        // READ UNIT
        // ----------------------------------------------------------------------

        DocumentSnapshot<Map<String, dynamic>>?
        unitSnapshot;

        if (unitDocument != null) {
          unitSnapshot =
          await transaction.get(
            unitDocument,
          );
        }

        // ----------------------------------------------------------------------
        // READ TENANT ACCESS
        // ----------------------------------------------------------------------

        DocumentSnapshot<Map<String, dynamic>>?
        tenantAccessSnapshot;

        if (tenantAccessDocument != null) {
          tenantAccessSnapshot =
          await transaction.get(
            tenantAccessDocument,
          );
        }

        // ----------------------------------------------------------------------
        // DELETE TENANT DOCUMENT
        // ----------------------------------------------------------------------

        transaction.delete(
          tenantDocument,
        );

        // ----------------------------------------------------------------------
        // CLEAN UNIT
        // ----------------------------------------------------------------------
        //
        // Only clear the unit if it is still linked to this tenant.
        //
        // This prevents an old inactive tenant record from accidentally
        // changing a unit that is now occupied by another tenant.
        //
        // ----------------------------------------------------------------------

        if (unitDocument != null &&
            unitSnapshot != null &&
            unitSnapshot.exists) {
          final unitData =
          unitSnapshot.data();

          if (unitData != null) {
            final currentTenantUserId =
            unitData['tenantUserId'];

            final isLinkedToThisTenant =
                tenantUserId != null &&
                    tenantUserId.isNotEmpty &&
                    currentTenantUserId is String &&
                    currentTenantUserId.trim() ==
                        tenantUserId;

            if (isLinkedToThisTenant) {
              transaction.update(
                unitDocument,
                {
                  'status':
                  UnitStatus.available.name,
                  'tenantUserId': null,
                  'updatedAt':
                  FieldValue.serverTimestamp(),
                },
              );
            }
          }
        }

        // ----------------------------------------------------------------------
        // REMOVE FROM PROPERTY TENANT LIST
        // ----------------------------------------------------------------------

        if (propertyDocument != null &&
            propertySnapshot != null &&
            propertySnapshot.exists &&
            tenantUserId != null &&
            tenantUserId.isNotEmpty) {
          transaction.update(
            propertyDocument,
            {
              'tenantUserIds':
              FieldValue.arrayRemove(
                [tenantUserId],
              ),
              'updatedAt':
              FieldValue.serverTimestamp(),
            },
          );
        }

        // ----------------------------------------------------------------------
        // DELETE TENANT ACCESS
        // ----------------------------------------------------------------------

        if (tenantAccessDocument != null &&
            tenantAccessSnapshot != null &&
            tenantAccessSnapshot.exists) {
          transaction.delete(
            tenantAccessDocument,
          );
        }
      },
    );
  }

  // ==========================================================================
  // SEARCH REGISTERED TENANT BY GRIHO ID
  // CURRENT OWNER SCOPE
  // ==========================================================================

  Future<TenantSearchResult?>
  searchRegisteredTenantByPublicId({
    required String publicId,
    required String ownerId,
  }) async {
    final normalizedPublicId =
    publicId.trim().toUpperCase();

    final normalizedOwnerId =
    ownerId.trim();

    if (normalizedPublicId.isEmpty ||
        normalizedOwnerId.isEmpty) {
      return null;
    }

    final publicIdSnapshot =
    await _publicIds
        .doc(normalizedPublicId)
        .get();

    if (!publicIdSnapshot.exists) {
      return null;
    }

    return _buildTenantSearchResult(
      userData: publicIdSnapshot.data(),
      ownerId: normalizedOwnerId,
    );
  }

  // ==========================================================================
  // SEARCH REGISTERED TENANT BY PHONE
  // CURRENT OWNER SCOPE
  // ==========================================================================

  Future<TenantSearchResult?>
  searchRegisteredTenantByPhone({
    required String phone,
    required String ownerId,
  }) async {
    final normalizedOwnerId =
    ownerId.trim();

    if (normalizedOwnerId.isEmpty) {
      return null;
    }

    final normalizedPhone =
    PhoneNumberUtils.normalizeAndValidate(
      phone,
    );

    final phoneLookupSnapshot =
    await _phoneLookups
        .doc(normalizedPhone)
        .get();

    if (!phoneLookupSnapshot.exists) {
      return null;
    }

    return _buildTenantSearchResult(
      userData: phoneLookupSnapshot.data(),
      ownerId: normalizedOwnerId,
    );
  }

  // ==========================================================================
  // BUILD SEARCH RESULT
  // ==========================================================================

  Future<TenantSearchResult?>
  _buildTenantSearchResult({
    required Map<String, dynamic>? userData,
    required String ownerId,
  }) async {
    if (userData == null) {
      return null;
    }

    final userId =
    userData['uid'];

    final publicId =
    userData['publicId'];

    final name =
    userData['name'];

    final phoneNumber =
    userData['phoneNumber'];

    final email =
    userData['email'];

    if (userId is! String ||
        userId
            .trim()
            .isEmpty) {
      return null;
    }

    if (publicId is! String ||
        publicId
            .trim()
            .isEmpty) {
      return null;
    }

    if (name is! String ||
        name
            .trim()
            .isEmpty) {
      return null;
    }

    final normalizedUserId =
    userId.trim();

    final normalizedPublicId =
    publicId.trim();

    final normalizedName =
    name.trim();

    final normalizedPhone =
    phoneNumber is String
        ? phoneNumber.trim()
        : '';

    final normalizedEmail =
    email is String &&
        email
            .trim()
            .isNotEmpty
        ? email.trim()
        : null;

    final existingTenantSnapshot =
    await _tenants
        .where(
      'ownerId',
      isEqualTo: ownerId,
    )
        .where(
      'userId',
      isEqualTo: normalizedUserId,
    )
        .limit(1)
        .get();

    TenantModel? existingTenant;

    if (existingTenantSnapshot.docs.isNotEmpty) {
      existingTenant =
          TenantModel.fromFirestore(
            existingTenantSnapshot.docs.first,
          );
    }

    return TenantSearchResult(
      userId: normalizedUserId,
      publicId: normalizedPublicId,
      name: normalizedName,
      phone: normalizedPhone,
      email: normalizedEmail,
      tenantId: existingTenant?.id,
      isExistingTenant:
      existingTenant != null,
    );
  }

  // ==========================================================================
  // FIND TENANT BY PHONE
  // CURRENT OWNER ONLY
  // ==========================================================================

  Future<TenantModel?> findTenantByPhone({
    required String phone,
    required String ownerId,
  }) async {
    final normalizedPhone =
    phone.trim();

    final normalizedOwnerId =
    ownerId.trim();

    if (normalizedPhone.isEmpty ||
        normalizedOwnerId.isEmpty) {
      return null;
    }

    final snapshot = await _tenants
        .where(
      'ownerId',
      isEqualTo: normalizedOwnerId,
    )
        .where(
      'phone',
      isEqualTo: normalizedPhone,
    )
        .where(
      'status',
      isEqualTo: TenantStatus.active.name,
    )
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) {
      return null;
    }

    return TenantModel.fromFirestore(
      snapshot.docs.first,
    );
  }
}