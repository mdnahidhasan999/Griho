import 'package:flutter/material.dart';

import '../widgets/variable_bill_amount_dialog.dart';

class PendingVariableBillAction extends StatelessWidget {
  final String billId;
  final String title;
  final VoidCallback? onUpdated;

  const PendingVariableBillAction({
    super.key,
    required this.billId,
    required this.title,
    this.onUpdated,
  });

  Future<void> _openAmountDialog(BuildContext context) async {
    final result = await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return VariableBillAmountDialog(
          billId: billId,
          title: title,
        );
      },
    );

    if (result != null) {
      onUpdated?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: () => _openAmountDialog(context),
        icon: const Icon(Icons.edit_outlined),
        label: const Text('Enter Amount'),
      ),
    );
  }
}