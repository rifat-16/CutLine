import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_functions/cloud_functions.dart';

import 'package:cutline/features/admin/services/admin_action_service.dart';
import 'package:cutline/features/admin/widgets/admin_ui.dart';
import 'package:cutline/shared/models/platform_fee_config.dart';
import 'package:cutline/shared/services/platform_fee_service.dart';

class PlatformFeeControlPanel extends StatefulWidget {
  const PlatformFeeControlPanel({super.key});

  @override
  State<PlatformFeeControlPanel> createState() =>
      _PlatformFeeControlPanelState();
}

class _PlatformFeeControlPanelState extends State<PlatformFeeControlPanel> {
  final PlatformFeeService _platformFeeService = PlatformFeeService();
  final AdminActionService _adminActionService = AdminActionService();
  final TextEditingController _amountController = TextEditingController();

  late Future<PlatformFeeConfig> _future;
  PlatformFeeConfig _liveConfig = const PlatformFeeConfig.free();
  bool _isFreeDraft = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<PlatformFeeConfig> _load() async {
    final config = await _platformFeeService.loadConfig();
    _applyDraft(config);
    return config;
  }

  void _applyDraft(PlatformFeeConfig config) {
    _liveConfig = config;
    _isFreeDraft = config.isFree;
    _amountController.text =
        config.isFree ? '' : config.effectiveAmount.toString();
  }

  int? get _draftAmount {
    final text = _amountController.text.trim();
    if (text.isEmpty) return null;
    return int.tryParse(text);
  }

  bool get _hasChanges {
    final draftAmount = _isFreeDraft ? 0 : (_draftAmount ?? 0);
    return _liveConfig.isFree != _isFreeDraft ||
        (!_isFreeDraft && draftAmount != _liveConfig.effectiveAmount);
  }

  bool get _isDraftValid {
    if (_isFreeDraft) return true;
    final amount = _draftAmount;
    return amount != null && amount > 0;
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _load();
    });
    await _future;
  }

  Future<void> _save() async {
    if (!_isDraftValid || !_hasChanges || _isSaving) return;
    final amount = _isFreeDraft ? 0 : _draftAmount ?? 0;

    setState(() => _isSaving = true);
    try {
      await _adminActionService.updatePlatformFeeConfig(
        isFree: _isFreeDraft,
        amount: amount,
      );
      final updated = await _platformFeeService.loadConfig();
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _liveConfig = updated;
        _future = Future<PlatformFeeConfig>.value(updated);
        _applyDraft(updated);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            updated.isFree
                ? 'Platform fee is now free.'
                : 'Platform fee updated to ${formatAdminCurrency(updated.effectiveAmount)}.',
          ),
        ),
      );
    } on FirebaseFunctionsException catch (error) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_mapSaveError(error)),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not update platform fee. Please try again.'),
        ),
      );
    }
  }

  String _mapSaveError(FirebaseFunctionsException error) {
    return switch (error.code) {
      'not-found' =>
        'This admin build is connected to a project where the platform fee function is not deployed yet.',
      'unauthenticated' => 'Please sign in again and retry.',
      'permission-denied' => 'Your account does not have superadmin access.',
      'invalid-argument' =>
        error.message ?? 'Enter a valid platform fee amount.',
      _ => error.message ?? 'Could not update platform fee. Please try again.',
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FutureBuilder<PlatformFeeConfig>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done &&
            snapshot.data == null) {
          return const AdminPanel(
            child: SizedBox(
              height: 180,
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        if (snapshot.hasError && snapshot.data == null) {
          return AdminPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Platform fee settings could not load',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF10261D),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Retry to fetch the current live platform fee setting.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF5D6F68),
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _refresh,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        final liveValue = _liveConfig.isFree
            ? 'Free'
            : formatAdminCurrency(_liveConfig.effectiveAmount);

        return AdminPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Current live fee',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: const Color(0xFF4C7B72),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          liveValue,
                          style: theme.textTheme.headlineMedium?.copyWith(
                            color: const Color(0xFF10261D),
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _liveConfig.isFree
                              ? 'New bookings will carry no platform fee.'
                              : 'New bookings will carry $liveValue as platform fee.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: const Color(0xFF5D6F68),
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  AdminStatusBadge(
                    label: _liveConfig.isFree ? 'Live: Free' : 'Live: Custom',
                    icon: _liveConfig.isFree
                        ? Icons.local_offer_outlined
                        : Icons.payments_outlined,
                    backgroundColor: _liveConfig.isFree
                        ? const Color(0xFFE6F6EA)
                        : const Color(0xFFFFF1D6),
                    foregroundColor: _liveConfig.isFree
                        ? const Color(0xFF166534)
                        : const Color(0xFF9A3412),
                  ),
                ],
              ),
              if (_liveConfig.updatedAt != null) ...[
                const SizedBox(height: 12),
                Text(
                  'Last updated: ${formatAdminDateTime(_liveConfig.updatedAt)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF6B7D76),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  ChoiceChip(
                    label: const Text('Free'),
                    selected: _isFreeDraft,
                    onSelected: _isSaving
                        ? null
                        : (_) {
                            setState(() => _isFreeDraft = true);
                          },
                  ),
                  ChoiceChip(
                    label: const Text('Custom amount'),
                    selected: !_isFreeDraft,
                    onSelected: _isSaving
                        ? null
                        : (_) {
                            setState(() => _isFreeDraft = false);
                          },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: _isFreeDraft
                    ? Container(
                        key: const ValueKey('free-mode'),
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5FAF8),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFFDDE6E0)),
                        ),
                        child: Text(
                          'Free mode keeps the platform fee at ৳0 for every new booking.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: const Color(0xFF48625A),
                            height: 1.45,
                          ),
                        ),
                      )
                    : TextField(
                        key: const ValueKey('custom-mode'),
                        controller: _amountController,
                        enabled: !_isSaving,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: InputDecoration(
                          labelText: 'Platform fee amount',
                          hintText: 'Enter amount in BDT',
                          prefixText: '৳',
                          helperText:
                              'This amount will apply to new bookings only.',
                          errorText:
                              _isDraftValid ? null : 'Enter a positive amount.',
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  FilledButton.icon(
                    onPressed: _isSaving || !_isDraftValid || !_hasChanges
                        ? null
                        : _save,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(_isSaving ? 'Saving...' : 'Save setting'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
