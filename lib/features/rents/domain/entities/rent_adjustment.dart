enum RentAdjustmentType {
  increase,
  decrease,
}

class RentAdjustment {
  final RentAdjustmentType type;
  final double amount;

  const RentAdjustment({
    required this.type,
    required this.amount,
  });

  double applyTo(double currentRent) {
    if (amount <= 0) {
      throw ArgumentError(
        'Rent adjustment amount must be greater than zero.',
      );
    }

    final newRent = type == RentAdjustmentType.increase
        ? currentRent + amount
        : currentRent - amount;

    if (newRent <= 0) {
      throw ArgumentError(
        'Rent cannot be reduced to zero or below.',
      );
    }

    return newRent;
  }
}