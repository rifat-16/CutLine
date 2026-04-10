import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:cutline/features/owner/providers/barber_payout_detail_provider.dart';

const _barberPayoutErrorColor = Color(0xFFB42318);

class BarberPayoutPaymentScreen extends StatefulWidget {
  const BarberPayoutPaymentScreen({
    super.key,
    required this.provider,
    required this.barberName,
    required this.readyToPayAmount,
    required this.totalDueAmount,
    required this.pendingAmount,
    required this.unpaidCount,
  });

  final BarberPayoutDetailProvider provider;
  final String barberName;
  final int readyToPayAmount;
  final int totalDueAmount;
  final int pendingAmount;
  final int unpaidCount;

  @override
  State<BarberPayoutPaymentScreen> createState() =>
      _BarberPayoutPaymentScreenState();
}

class _BarberPayoutPaymentScreenState extends State<BarberPayoutPaymentScreen> {
  late final TextEditingController _amountController;
  final TextEditingController _methodController =
      TextEditingController(text: 'Cash');
  final TextEditingController _noteController = TextEditingController();

  bool _submitting = false;
  String? _amountError;
  String? _methodError;

  @override
  void initState() {
    super.initState();
    _amountController =
        TextEditingController(text: widget.readyToPayAmount.toString());
  }

  @override
  void dispose() {
    _amountController.dispose();
    _methodController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(symbol: '৳', decimalDigits: 0);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Pay Barber Tips',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          Text(
            'Record the payout after the amount is handed over to ${widget.barberName}.',
            style: const TextStyle(
              fontSize: 15,
              height: 1.45,
              color: Colors.black87,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          _SummaryStrip(
            readyAmount: currency.format(widget.readyToPayAmount),
            totalDue: currency.format(widget.totalDueAmount),
            pending: currency.format(widget.pendingAmount),
          ),
          const SizedBox(height: 16),
          _InfoCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.barberName,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${widget.unpaidCount} tip ledger items are ready to be covered by this payout.',
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.45,
                    color: Color(0xFF4B5563),
                  ),
                ),
                const SizedBox(height: 16),
                const _BulletLine(
                  text: 'Enter the exact amount you handed over to the barber.',
                ),
                const SizedBox(height: 10),
                const _BulletLine(
                  text:
                      'Use the payment method field to match how the payout was made.',
                ),
                const SizedBox(height: 10),
                const _BulletLine(
                  text:
                      'Add a note only if you need to clarify something for later review.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _InfoCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Payout form',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Complete the payout details carefully before you submit them.',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.45,
                    color: Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 18),
                _FormFieldGroup(
                  label: 'Amount',
                  helper: 'You can submit up to the ready payout balance only.',
                  errorText: _amountError,
                  child: _InputShell(
                    icon: Icons.payments_outlined,
                    hasError: _amountError != null,
                    child: TextField(
                      controller: _amountController,
                      keyboardType: TextInputType.number,
                      onChanged: (_) {
                        if (_amountError == null) return;
                        setState(() => _amountError = null);
                      },
                      style: _inputTextStyle(),
                      decoration: _inputDecoration(
                        hintText: 'Enter amount',
                        prefixText: '৳ ',
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _FormFieldGroup(
                  label: 'Payment method',
                  helper:
                      'Example: Cash, bKash, bank transfer, or any method you used.',
                  errorText: _methodError,
                  child: _InputShell(
                    icon: Icons.account_balance_wallet_outlined,
                    hasError: _methodError != null,
                    child: TextField(
                      controller: _methodController,
                      onChanged: (_) {
                        if (_methodError == null) return;
                        setState(() => _methodError = null);
                      },
                      style: _inputTextStyle(),
                      decoration: _inputDecoration(
                        hintText: 'Enter payment method',
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _FormFieldGroup(
                  label: 'Note (optional)',
                  helper: 'Add extra context only if you need it for records.',
                  child: _InputShell(
                    icon: Icons.note_alt_outlined,
                    child: TextField(
                      controller: _noteController,
                      maxLines: 3,
                      style: _inputTextStyle(),
                      decoration: _inputDecoration(
                        hintText: 'Write a note if needed',
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _submitting ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: const Color(0xFFE5E7EB),
                      disabledForegroundColor: const Color(0xFF9CA3AF),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: _submitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Record payout',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    final amountText = _amountController.text.trim();
    final parsedAmount = int.tryParse(amountText);

    String? amountError;
    if (amountText.isEmpty) {
      amountError = 'Amount is required.';
    } else if (parsedAmount == null || parsedAmount <= 0) {
      amountError = 'Enter a valid amount.';
    } else if (parsedAmount > widget.readyToPayAmount) {
      amountError = 'Amount cannot be more than the ready balance.';
    }

    final methodError = _methodController.text.trim().isEmpty
        ? 'Payment method is required.'
        : null;

    if (amountError != null || methodError != null) {
      setState(() {
        _amountError = amountError;
        _methodError = methodError;
      });
      _showMessage('Please complete the required fields.');
      return;
    }

    setState(() => _submitting = true);
    final success = await widget.provider.recordPayout(
      amount: parsedAmount!,
      paymentMethod: _methodController.text.trim(),
      note: _noteController.text.trim(),
    );
    if (!mounted) return;
    setState(() => _submitting = false);

    if (!success) {
      _showMessage(widget.provider.error ?? 'Failed to record payout.');
      return;
    }
    Navigator.of(context).pop(true);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

class _SummaryStrip extends StatelessWidget {
  const _SummaryStrip({
    required this.readyAmount,
    required this.totalDue,
    required this.pending,
  });

  final String readyAmount;
  final String totalDue;
  final String pending;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _SummaryPill(
            label: 'Ready',
            value: readyAmount,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _SummaryPill(
            label: 'Total due',
            value: totalDue,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _SummaryPill(
            label: 'Pending',
            value: pending,
          ),
        ),
      ],
    );
  }
}

class _SummaryPill extends StatelessWidget {
  const _SummaryPill({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: child,
    );
  }
}

class _BulletLine extends StatelessWidget {
  const _BulletLine({
    required this.text,
  });

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 6),
          width: 6,
          height: 6,
          decoration: const BoxDecoration(
            color: Colors.black,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              height: 1.45,
              color: Colors.black87,
            ),
          ),
        ),
      ],
    );
  }
}

class _FormFieldGroup extends StatelessWidget {
  const _FormFieldGroup({
    required this.label,
    required this.helper,
    required this.child,
    this.errorText,
  });

  final String label;
  final String helper;
  final Widget child;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          helper,
          style: const TextStyle(
            fontSize: 12,
            height: 1.45,
            color: Color(0xFF6B7280),
          ),
        ),
        const SizedBox(height: 10),
        child,
        if (errorText != null) ...[
          const SizedBox(height: 8),
          Text(
            errorText!,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _barberPayoutErrorColor,
            ),
          ),
        ],
      ],
    );
  }
}

class _InputShell extends StatelessWidget {
  const _InputShell({
    required this.icon,
    required this.child,
    this.hasError = false,
  });

  final IconData icon;
  final Widget child;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: hasError ? _barberPayoutErrorColor : const Color(0xFFD1D5DB),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Icon(
              icon,
              size: 19,
              color:
                  hasError ? _barberPayoutErrorColor : const Color(0xFF6B7280),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: child),
        ],
      ),
    );
  }
}

InputDecoration _inputDecoration({String? hintText, String? prefixText}) {
  return InputDecoration(
    hintText: hintText,
    prefixText: prefixText,
    prefixStyle: const TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w700,
      color: Colors.black,
    ),
    hintStyle: const TextStyle(
      color: Color(0xFF9CA3AF),
      fontWeight: FontWeight.w500,
    ),
    border: InputBorder.none,
    enabledBorder: InputBorder.none,
    focusedBorder: InputBorder.none,
    contentPadding: const EdgeInsets.symmetric(vertical: 13),
  );
}

TextStyle _inputTextStyle() {
  return const TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: Colors.black,
  );
}

BoxDecoration _cardDecoration() {
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(24),
    border: Border.all(color: const Color(0xFFE5E7EB)),
    boxShadow: const [
      BoxShadow(
        color: Color(0x05000000),
        blurRadius: 18,
        offset: Offset(0, 8),
      ),
    ],
  );
}
