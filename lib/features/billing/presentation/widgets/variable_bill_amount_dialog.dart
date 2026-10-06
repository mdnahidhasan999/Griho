import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/monthly_bill_controller.dart';

class VariableBillAmountDialog extends ConsumerStatefulWidget {
  final String billId;
  final String title;

  const VariableBillAmountDialog({
    super.key,
    required this.billId,
    required this.title,
  });

  @override
  ConsumerState<VariableBillAmountDialog> createState() =>
      _VariableBillAmountDialogState();
}

class _VariableBillAmountDialogState
    extends ConsumerState<VariableBillAmountDialog> {
  late final TextEditingController _amountController;

  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();

    final rawValue = _amountController.text.trim();

    if (rawValue.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter the bill amount.';
      });
      return;
    }

    final amount = double.tryParse(rawValue);

    if (amount == null || amount.isNaN || amount.isInfinite) {
      setState(() {
        _errorMessage = 'Please enter a valid amount.';
      });
      return;
    }

    if (amount < 0) {
      setState(() {
        _errorMessage = 'Amount cannot be negative.';
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final updatedBill = await ref
          .read(monthlyBillControllerProvider)
          .updateAmount(billId: widget.billId, amount: amount);

      if (!mounted) {
        return;
      }

      if (updatedBill == null) {
        setState(() {
          _isSaving = false;
          _errorMessage = 'Bill could not be updated.';
        });
        return;
      }

      Navigator.of(context).pop(updatedBill);
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isSaving = false;
        _errorMessage = _cleanErrorMessage(error);
      });
    }
  }

  String _cleanErrorMessage(Object error) {
    final message = error.toString();

    if (message.startsWith('Exception: ')) {
      return message.substring('Exception: '.length);
    }

    return message;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Enter the actual amount for this variable bill.'),
            const SizedBox(height: 16),
            TextField(
              controller: _amountController,
              autofocus: true,
              enabled: !_isSaving,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) {
                if (!_isSaving) {
                  _save();
                }
              },
              decoration: InputDecoration(
                labelText: 'Amount',
                hintText: '0.00',
                prefixText: '৳ ',
                border: const OutlineInputBorder(),
                errorText: _errorMessage,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving
              ? null
              : () {
                  Navigator.of(context).pop();
                },
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _save,
          child: _isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}
