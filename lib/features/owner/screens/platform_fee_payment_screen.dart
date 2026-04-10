import 'dart:io';

import 'package:cutline/features/owner/providers/platform_fee_report_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

const _errorColor = Color(0xFFB42318);

class PlatformFeePaymentScreen extends StatefulWidget {
  const PlatformFeePaymentScreen({
    super.key,
    required this.provider,
    required this.readyToSubmitAmount,
    required this.totalDueAmount,
    required this.pendingReviewAmount,
    required this.unpaidCount,
  });

  final PlatformFeeReportProvider provider;
  final int readyToSubmitAmount;
  final int totalDueAmount;
  final int pendingReviewAmount;
  final int unpaidCount;

  @override
  State<PlatformFeePaymentScreen> createState() =>
      _PlatformFeePaymentScreenState();
}

class _PlatformFeePaymentScreenState extends State<PlatformFeePaymentScreen> {
  static const _bkashNumber = '01742317133';

  final TextEditingController _transactionController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  late final TextEditingController _amountController;
  final ImagePicker _picker = ImagePicker();

  bool _submitting = false;
  XFile? _proofFile;
  String? _amountError;
  String? _transactionError;
  String? _receiptError;

  @override
  void initState() {
    super.initState();
    _amountController =
        TextEditingController(text: widget.readyToSubmitAmount.toString());
  }

  @override
  void dispose() {
    _transactionController.dispose();
    _noteController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(symbol: '৳', decimalDigits: 0);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Pay Platform Fee',
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
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          MediaQuery.of(context).viewInsets.bottom + 28,
        ),
        children: [
          const Text(
            'Send the payment with bKash, then submit the TrxID and receipt screenshot.',
            style: TextStyle(
              fontSize: 15,
              height: 1.45,
              color: Colors.black87,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          _SummaryStrip(
            readyAmount: currency.format(widget.readyToSubmitAmount),
            totalDue: currency.format(widget.totalDueAmount),
            pendingReview: currency.format(widget.pendingReviewAmount),
          ),
          const SizedBox(height: 16),
          _InfoCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'bKash personal number',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            _bkashNumber,
                            style: TextStyle(
                              fontSize: 28,
                              height: 1,
                              fontWeight: FontWeight.w800,
                              color: Colors.black,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Payment method: bKash Personal -> Send Money',
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.45,
                              color: Color(0xFF4B5563),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton(
                      onPressed: _copyBkashNumber,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.black,
                        side: const BorderSide(color: Color(0xFFD1D5DB)),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 13,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Copy',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const _BulletLine(
                  text: 'Open the bKash app and choose Send Money.',
                ),
                const SizedBox(height: 10),
                const _BulletLine(
                  text: 'Send the exact amount to 01742317133.',
                ),
                const SizedBox(height: 10),
                const _BulletLine(
                  text:
                      'After payment, keep the TrxID and screenshot ready before filling out the form.',
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
                  'Verification form',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Enter every detail exactly as shown in your bKash receipt. Missing or incorrect information may cause the payment to be rejected.',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.45,
                    color: Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 18),
                _FormFieldGroup(
                  label: 'Amount',
                  helper: 'Enter the exact amount you sent from bKash.',
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
                const _FormFieldGroup(
                  label: 'Payment method',
                  helper: 'Only bKash Personal -> Send Money is accepted.',
                  child: _StaticField(
                    icon: Icons.phone_android_outlined,
                    value: 'bKash Personal -> Send Money',
                  ),
                ),
                const SizedBox(height: 16),
                _FormFieldGroup(
                  label: 'TrxID',
                  helper: 'Copy the TrxID from the bKash app or SMS receipt.',
                  errorText: _transactionError,
                  child: _InputShell(
                    icon: Icons.receipt_long_outlined,
                    hasError: _transactionError != null,
                    child: TextField(
                      controller: _transactionController,
                      onChanged: (_) {
                        if (_transactionError == null) return;
                        setState(() => _transactionError = null);
                      },
                      style: _inputTextStyle(),
                      decoration: _inputDecoration(),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _FormFieldGroup(
                  label: 'Note (optional)',
                  helper: 'Add extra context only if admin needs it.',
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
                const SizedBox(height: 16),
                _FormFieldGroup(
                  label: 'Receipt screenshot',
                  helper:
                      'Upload a clear screenshot where the amount, number, and TrxID are visible.',
                  errorText: _receiptError,
                  child: _ReceiptPicker(
                    proofFile: _proofFile,
                    hasError: _receiptError != null,
                    onPick: _submitting ? null : _pickScreenshot,
                    onClear: _submitting
                        ? null
                        : () => setState(() {
                              _proofFile = null;
                            }),
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
                            'Submit for verification',
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

  Future<void> _copyBkashNumber() async {
    await Clipboard.setData(const ClipboardData(text: _bkashNumber));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('bKash number copied.')),
    );
  }

  Future<void> _pickScreenshot() async {
    final selected = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 88,
      maxWidth: 1600,
    );
    if (!mounted || selected == null) return;
    setState(() {
      _proofFile = selected;
      _receiptError = null;
    });
  }

  Future<void> _submit() async {
    final amountText = _amountController.text.trim();
    final parsedAmount = int.tryParse(amountText);

    String? amountError;
    if (amountText.isEmpty) {
      amountError = 'Amount is required.';
    } else if (parsedAmount == null || parsedAmount <= 0) {
      amountError = 'Enter a valid amount.';
    } else if (parsedAmount > widget.readyToSubmitAmount) {
      amountError = 'Amount cannot be more than the ready balance.';
    }

    final transactionError = _transactionController.text.trim().isEmpty
        ? 'Transaction ID is required.'
        : null;
    final receiptError =
        _proofFile == null ? 'Receipt screenshot is required.' : null;

    if (amountError != null ||
        transactionError != null ||
        receiptError != null) {
      setState(() {
        _amountError = amountError;
        _transactionError = transactionError;
        _receiptError = receiptError;
      });
      _showMessage('Please complete the required fields.');
      return;
    }

    setState(() => _submitting = true);
    final success = await widget.provider.recordPayment(
      amount: parsedAmount!,
      transactionId: _transactionController.text.trim(),
      proofFile: _proofFile!,
      note: _noteController.text.trim(),
    );
    if (!mounted) return;
    setState(() => _submitting = false);

    if (!success) {
      _showMessage(widget.provider.error ?? 'Failed to submit payment.');
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
    required this.pendingReview,
  });

  final String readyAmount;
  final String totalDue;
  final String pendingReview;

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
            label: 'Review',
            value: pendingReview,
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
              color: _errorColor,
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
          color: hasError ? _errorColor : const Color(0xFFD1D5DB),
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
              color: hasError ? _errorColor : const Color(0xFF6B7280),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _StaticField extends StatelessWidget {
  const _StaticField({
    required this.icon,
    required this.value,
  });

  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD1D5DB)),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 19,
            color: const Color(0xFF6B7280),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReceiptPicker extends StatelessWidget {
  const _ReceiptPicker({
    required this.proofFile,
    required this.onPick,
    required this.onClear,
    this.hasError = false,
  });

  final XFile? proofFile;
  final VoidCallback? onPick;
  final VoidCallback? onClear;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onPick,
      child: Ink(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: hasError ? _errorColor : const Color(0xFFD1D5DB),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.image_outlined,
                  size: 20,
                  color: hasError ? _errorColor : const Color(0xFF6B7280),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        proofFile == null
                            ? 'Tap to select a screenshot'
                            : proofFile!.name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        proofFile == null
                            ? 'Choose an image from your gallery'
                            : 'Tap again to replace the screenshot',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ),
                if (proofFile != null)
                  TextButton(
                    onPressed: onClear,
                    child: const Text(
                      'Remove',
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
            if (proofFile != null) ...[
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.file(
                  File(proofFile!.path),
                  width: double.infinity,
                  height: 210,
                  fit: BoxFit.cover,
                ),
              ),
            ],
          ],
        ),
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
