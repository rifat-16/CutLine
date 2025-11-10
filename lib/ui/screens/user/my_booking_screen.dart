

import 'package:flutter/material.dart';
import 'booking_receipt_screen.dart';

class MyBookingScreen extends StatelessWidget {
  static const Color primaryColor = Color(0xFF1565C0);
  static const Color lightRed = Color(0xFFFFE5E5);
  static const Color red = Color(0xFFD32F2F);

  final List<Map<String, dynamic>> upcomingBookings = const [
    {
      'image':
          'https://images.unsplash.com/photo-1517841905240-472988babdf9?auto=format&fit=facearea&w=400&h=200',
      'salon': 'Chic Cuts Salon',
      'location': '123 Main St, Springfield',
      'services': ['Hair Cut', 'Hair Wash'],
      'datetime': 'Fri, 20 Jun 2024 • 2:30 PM',
    },
    {
      'image':
          'https://images.unsplash.com/photo-1515378791036-0648a3ef77b2?auto=format&fit=facearea&w=400&h=200',
      'salon': 'Urban Style Studio',
      'location': '456 Park Ave, Metropolis',
      'services': ['Beard Trim', 'Shave'],
      'datetime': 'Mon, 24 Jun 2024 • 5:00 PM',
    },
  ];

  final List<Map<String, dynamic>> completedBookings = const [
    {
      'image':
          'https://images.unsplash.com/photo-1517841905240-472988babdf9?auto=format&fit=facearea&w=400&h=200',
      'salon': 'Glamour Lounge',
      'location': '789 Elm St, Gotham',
      'services': ['Hair Color', 'Blow Dry'],
      'datetime': 'Tue, 11 Jun 2024 • 1:00 PM',
    },
  ];

  final List<Map<String, dynamic>> cancelledBookings = const [
    {
      'image':
          'https://images.unsplash.com/photo-1515378791036-0648a3ef77b2?auto=format&fit=facearea&w=400&h=200',
      'salon': 'Classic Cutz',
      'location': '321 Oak St, Star City',
      'services': ['Hair Cut'],
      'datetime': 'Sat, 15 Jun 2024 • 11:00 AM',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0.5,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          title: Text(
            'Bookings',
            style: TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          centerTitle: true,
          bottom: PreferredSize(
            preferredSize: Size.fromHeight(48),
            child: Material(
              color: Colors.white,
              child: TabBar(
                indicatorColor: primaryColor,
                labelColor: primaryColor,
                unselectedLabelColor: Colors.grey,
                labelStyle: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                tabs: [
                  Tab(text: 'Upcoming'),
                  Tab(text: 'Completed'),
                  Tab(text: 'Cancelled'),
                ],
              ),
            ),
          ),
        ),
        body: TabBarView(
          children: [
            _buildUpcomingTab(context),
            _buildCompletedTab(context),
            _buildCancelledTab(context),
          ],
        ),
      ),
    );
  }

  Widget _buildUpcomingTab(BuildContext context) {
    if (upcomingBookings.isEmpty) {
      return _emptyState('No upcoming bookings.');
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: upcomingBookings.length,
      separatorBuilder: (_, __) => SizedBox(height: 16),
      itemBuilder: (context, i) {
        final booking = upcomingBookings[i];
        return _BookingCard(
          image: booking['image'],
          salon: booking['salon'],
          location: booking['location'],
          services: booking['services'],
          datetime: booking['datetime'],
          primaryColor: primaryColor,
          onCancel: () => _showCancelDialog(context),
          onViewReceipt: () {},
        );
      },
    );
  }

  Widget _buildCompletedTab(BuildContext context) {
    if (completedBookings.isEmpty) {
      return _emptyState('No completed bookings.');
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: completedBookings.length,
      separatorBuilder: (_, __) => SizedBox(height: 16),
      itemBuilder: (context, i) {
        final booking = completedBookings[i];
        return _BookingCard(
          image: booking['image'],
          salon: booking['salon'],
          location: booking['location'],
          services: booking['services'],
          datetime: booking['datetime'],
          primaryColor: primaryColor,
          onViewReceipt: () {},
          showCancel: false,
        );
      },
    );
  }

  Widget _buildCancelledTab(BuildContext context) {
    if (cancelledBookings.isEmpty) {
      return _emptyState('No cancelled bookings.');
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: cancelledBookings.length,
      separatorBuilder: (_, __) => SizedBox(height: 16),
      itemBuilder: (context, i) {
        final booking = cancelledBookings[i];
        return _BookingCard(
          image: booking['image'],
          salon: booking['salon'],
          location: booking['location'],
          services: booking['services'],
          datetime: booking['datetime'],
          borderColor: lightRed,
          showCancel: false,
          showCancelledLabel: true,
          primaryColor: primaryColor,
          showViewReceipt: false,
        );
      },
    );
  }

  Widget _emptyState(String msg) {
    return Center(
      child: Text(
        msg,
        style: TextStyle(color: Colors.grey, fontSize: 16),
      ),
    );
  }

  void _showCancelDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Cancel Booking', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Text(
            'Are you sure you want to cancel? Canceling your appointment will remove it from your upcoming bookings.',
            style: TextStyle(color: Colors.grey[700]),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                _showCancelSuccessDialog(context);
              },
              child: Text(
                'Yes, Cancel Booking',
                style: TextStyle(color: red, fontWeight: FontWeight.bold),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(
                'Keep Appointment',
                style: TextStyle(color: primaryColor),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showCancelSuccessDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.check_circle, color: primaryColor, size: 40),
              SizedBox(height: 12),
              Text('Booking Canceled', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: Text(
            'Your appointment has been successfully canceled.',
            style: TextStyle(color: Colors.grey[700]),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(
                'Back to Bookings',
                style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _BookingCard extends StatelessWidget {
  final String image;
  final String salon;
  final String location;
  final List<String> services;
  final String datetime;
  final Color? borderColor;
  final bool showCancel;
  final bool showCancelledLabel;
  final Color primaryColor;
  final VoidCallback? onCancel;
  final VoidCallback? onViewReceipt;
  final bool showViewReceipt;

  const _BookingCard({
    required this.image,
    required this.salon,
    required this.location,
    required this.services,
    required this.datetime,
    this.borderColor,
    this.showCancel = true,
    this.showCancelledLabel = false,
    required this.primaryColor,
    this.onCancel,
    this.onViewReceipt,
    this.showViewReceipt = true,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: borderColor ?? Colors.grey[200]!,
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.05),
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      datetime,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Colors.black,
                      ),
                    ),
                    if (showCancelledLabel)
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Cancelled',
                          style: TextStyle(
                            color: Color(0xFFD32F2F),
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                  ],
                ),
                SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        image,
                        width: 70,
                        height: 70,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 70,
                          height: 70,
                          color: Colors.grey[200],
                          child: Icon(Icons.image, color: Colors.grey, size: 30),
                        ),
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            salon,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                              color: Colors.black,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            location,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Services: ${services.join(', ')}',
                            style: TextStyle(
                              color: Colors.grey[700],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 18),
                Row(
                  children: [
                    if (showCancel)
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: primaryColor),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: onCancel,
                          child: Text(
                            'Cancel Booking',
                            style: TextStyle(
                              color: primaryColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    if (showCancel) SizedBox(width: 12),
                    if (showViewReceipt)
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 0),
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const BookingReceiptScreen()),
                            );
                          },
                          child: Text(
                            'View Receipt',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
