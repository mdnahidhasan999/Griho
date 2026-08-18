import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/create_property_request.dart';
import '../../domain/entities/property.dart';
import '../providers/property_provider.dart';

final propertyControllerProvider =
NotifierProvider<PropertyController, PropertyControllerState>(
  PropertyController.new,
);

class PropertyControllerState {
  final bool isLoading;
  final List<Property> properties;
  final Property? selectedProperty;
  final String? errorMessage;

  const PropertyControllerState({
    this.isLoading = false,
    this.properties = const [],
    this.selectedProperty,
    this.errorMessage,
  });

  PropertyControllerState copyWith({
    bool? isLoading,
    List<Property>? properties,
    Property? selectedProperty,
    String? errorMessage,
    bool clearSelectedProperty = false,
    bool clearError = false,
  }) {
    return PropertyControllerState(
      isLoading: isLoading ?? this.isLoading,
      properties: properties ?? this.properties,
      selectedProperty: clearSelectedProperty
          ? null
          : selectedProperty ?? this.selectedProperty,
      errorMessage: clearError
          ? null
          : errorMessage ?? this.errorMessage,
    );
  }
}

class PropertyController
    extends Notifier<PropertyControllerState> {
  @override
  PropertyControllerState build() {
    return const PropertyControllerState();
  }

  Future<void> loadProperties({
    required String ownerId,
  }) async {
    state = state.copyWith(
      isLoading: true,
      clearError: true,
    );

    try {
      final repository = ref.read(
        propertyRepositoryProvider,
      );

      final properties = await repository.getPropertiesByOwnerId(
        ownerId,
      );

      state = state.copyWith(
        isLoading: false,
        properties: properties,
      );
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: error.toString(),
      );
    }
  }

  Future<void> loadProperty({
    required String propertyId,
  }) async {
    state = state.copyWith(
      isLoading: true,
      clearError: true,
    );

    try {
      final repository = ref.read(
        propertyRepositoryProvider,
      );

      final property = await repository.getPropertyById(
        propertyId,
      );

      if (property == null) {
        state = state.copyWith(
          isLoading: false,
          clearSelectedProperty: true,
        );
        return;
      }

      state = state.copyWith(
        isLoading: false,
        selectedProperty: property,
      );
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: error.toString(),
      );
    }
  }

  Future<Property?> createProperty({
    required CreatePropertyRequest request,
  }) async {
    state = state.copyWith(
      isLoading: true,
      clearError: true,
    );

    try {
      final repository = ref.read(
        propertyRepositoryProvider,
      );

      final createdProperty = await repository.createProperty(
        request,
      );

      state = state.copyWith(
        isLoading: false,
        properties: [
          createdProperty,
          ...state.properties,
        ],
        selectedProperty: createdProperty,
      );

      return createdProperty;
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: error.toString(),
      );

      return null;
    }
  }

  Future<Property?> updateProperty({
    required Property property,
  }) async {
    state = state.copyWith(
      isLoading: true,
      clearError: true,
    );

    try {
      final repository = ref.read(
        propertyRepositoryProvider,
      );

      final updatedProperty = await repository.updateProperty(
        property,
      );

      final updatedProperties = state.properties.map(
            (item) {
          if (item.id == updatedProperty.id) {
            return updatedProperty;
          }

          return item;
        },
      ).toList();

      state = state.copyWith(
        isLoading: false,
        properties: updatedProperties,
        selectedProperty: updatedProperty,
      );

      return updatedProperty;
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: error.toString(),
      );

      return null;
    }
  }

  Future<bool> deleteProperty({
    required String propertyId,
  }) async {
    state = state.copyWith(
      isLoading: true,
      clearError: true,
    );

    try {
      final repository = ref.read(
        propertyRepositoryProvider,
      );

      await repository.deleteProperty(
        propertyId,
      );

      final remainingProperties = state.properties
          .where(
            (property) => property.id != propertyId,
      )
          .toList();

      final selectedProperty = state.selectedProperty;

      state = state.copyWith(
        isLoading: false,
        properties: remainingProperties,
        clearSelectedProperty:
        selectedProperty?.id == propertyId,
      );

      return true;
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: error.toString(),
      );

      return false;
    }
  }

  void clearError() {
    state = state.copyWith(
      clearError: true,
    );
  }

  void clearSelectedProperty() {
    state = state.copyWith(
      clearSelectedProperty: true,
    );
  }
}