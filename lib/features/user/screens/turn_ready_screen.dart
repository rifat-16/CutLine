import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cutline/routes/app_router.dart';
import 'package:cutline/shared/theme/cutline_theme.dart';
import 'package:flutter/material.dart';
import 'dart:async';

class TurnReadyScreen extends StatefulWidget {
  final String bookingId;
  final String salonId;
  final String salonName;

  const TurnReadyScreen({
    super.key,
    required this.bookingId,
    required this.salonId,
    required this.salonName,
  });

  @override
  State<TurnReadyScreen> createState() => _TurnReadyScreenState();
}

class _TurnReadyScreenState extends State<TurnReadyScreen> {
  Timer? _countdownTimer;
  int _remainingSeconds = 180; // 3 minutes
  bool _isMarkingArrived = false;
  bool _hasArrived = false;
  DateTime? _turnReadyAt;

  @override
  void initState() {
    super.initState();
    _loadBookingData();
    _startCountdown();
  }

  Future<void> _loadBookingData() async {
    try {
      final bookingDoc = await FirebaseFirestore.instance
          .collection('salons')
          .doc(widget.salonId)
          .collection('bookings')
          .doc(widget.bookingId)
          .get();

      if (bookingDoc.exists) {
        final data = bookingDoc.data()!;
        final turnReadyAt = data['turnReadyAt'] as Timestamp?;
        final arrived = data['arrived'] as bool? ?? false;
        final status = data['status'] as String? ?? '';

        setState(() {
          _hasArrived = arrived;
          if (turnReadyAt != null) {
            _turnReadyAt = turnReadyAt.toDate();
            final now = DateTime.now();
            final elapsed = now.difference(_turnReadyAt!).inSeconds;
            _remainingSeconds = (180 - elapsed).clamp(0, 180);
          }
        });

        // If already arrived or status changed, navigate back
        if (_hasArrived || status != 'turn_ready') {
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      debugPrint('Error loading booking data: $e');
    }
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        if (_remainingSeconds > 0) {
          _remainingSeconds--;
        } else {
          timer.cancel();
          // Time expired - booking will be auto-cancelled by Cloud Function
          _showExpiredDialog();
        }
      });
    });
  }

  void _showExpiredDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Time Expired'),
        content: const Text(
          'You did not confirm within 3 minutes. Your booking has been cancelled.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              Navigator.of(context).pop(); // Close screen
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _markAsArrived() async {
    if (_isMarkingArrived || _hasArrived) return;

    setState(() {
      _isMarkingArrived = true;
    });

    try {
      // Update booking status to arrived
      await FirebaseFirestore.instance
          .collection('salons')
          .doc(widget.salonId)
          .collection('bookings')
          .doc(widget.bookingId)
          .update({
        'status': 'arrived',
        'arrived': true,
        'arrivalTime': FieldValue.serverTimestamp(),
      });

      // Update queue if exists
      await FirebaseFirestore.instance
          .collection('salons')
          .doc(widget.salonId)
          .collection('queue')
          .doc(widget.bookingId)
          .set({
        'status': 'arrived',
        'arrived': true,
        'arrivalTime': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      setState(() {
        _hasArrived = true;
        _isMarkingArrived = false;
      });

      _countdownTimer?.cancel();

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Confirmed! The salon will serve you soon.'),
            backgroundColor: Colors.green,
          ),
        );
      }

      // Navigate back after a short delay
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          Navigator.of(context).pop();
        }
      });
    } catch (e) {
      debugPrint('Error marking as arrived: $e');
      setState(() {
        _isMarkingArrived = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to confirm. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Turn is Ready'),
        backgroundColor: CutlineColors.primary,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              // Salon Name
              Text(
                widget.salonName,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              // Queue Position
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: CutlineColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    const Text(
                      'Queue Position',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Now Serving',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: CutlineColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              // Countdown Timer
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: _remainingSeconds < 60
                      ? Colors.red.withValues(alpha: 0.1)
                      : CutlineColors.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _remainingSeconds < 60
                        ? Colors.red
                        : CutlineColors.accent,
                    width: 3,
                  ),
                ),
                child: Column(
                  children: [
                    const Text(
                      'Confirm within',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _formatTime(_remainingSeconds),
                      style: TextStyle(
                        fontSize: 56,
                        fontWeight: FontWeight.bold,
                        color: _remainingSeconds < 60
                            ? Colors.red
                            : CutlineColors.accent,
                        fontFeatures: const [
                          FontFeature.tabularFigures(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              // Action Button
              if (!_hasArrived)
                ElevatedButton(
                  onPressed: _isMarkingArrived ? null : _markAsArrived,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: CutlineColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  child: _isMarkingArrived
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          "I'm Here",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                )
              else
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle, color: Colors.green),
                      SizedBox(width: 8),
                      Text(
                        'Confirmed!',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 24),
              // Info Text
              Text(
                _hasArrived
                    ? 'You have confirmed your arrival. The salon will serve you soon.'
                    : 'Please confirm your arrival within 3 minutes to keep your place in the queue.',
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black54,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

