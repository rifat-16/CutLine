import 'package:flutter/material.dart';

class BookingSummaryScreen extends StatefulWidget {
  const BookingSummaryScreen({super.key});

  @override
  State<BookingSummaryScreen> createState() => _BookingSummaryScreenState();
}

class _BookingSummaryScreenState extends State<BookingSummaryScreen> {
  String selectedPayment = "Pay at Salon";

  final List<Map<String, dynamic>> services = [
    {"name": "Haircut", "price": 300},
    {"name": "Facial", "price": 500},
    {"name": "Beard Trim", "price": 200},
  ];

  int get totalPrice =>
      services.fold(0, (sum, item) => sum + (item["price"] as int));

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.blueAccent),
          const SizedBox(width: 10),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          const Spacer(),
          Text(value,
              style: const TextStyle(
                  fontWeight: FontWeight.w600, color: Colors.black87)),
        ],
      ),
    );
  }

  Widget _paymentTile(String title, IconData icon) {
    final isSelected = selectedPayment == title;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => selectedPayment = title),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isSelected ? Colors.blueAccent : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? Colors.blueAccent : Colors.grey.shade300,
              width: 1.2,
            ),
            boxShadow: [
              if (isSelected)
                BoxShadow(
                  color: Colors.blueAccent.withOpacity(0.2),
                  blurRadius: 6,
                  offset: const Offset(0, 4),
                ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  size: 26,
                  color: isSelected ? Colors.white : Colors.blueAccent),
              const SizedBox(height: 6),
              Text(
                title,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.blueAccent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text("Booking Summary"),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 1,
        foregroundColor: Colors.black87,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Container(
          color: Colors.white,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Booking Summary",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const Divider(height: 24),

              // Salon Info
              Row(
                children: [
                  const CircleAvatar(
                    radius: 26,
                    backgroundImage:
                        NetworkImage("https://i.pravatar.cc/150?img=12"),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text("Urban Fade Salon",
                          style: TextStyle(
                              fontSize: 17, fontWeight: FontWeight.bold)),
                      Text("45 Dhanmondi Rd, Dhaka",
                          style: TextStyle(color: Colors.black54)),
                      Text("📞 017XXXXXXXX",
                          style: TextStyle(color: Colors.black54)),
                    ],
                  ),
                ],
              ),
              const Divider(height: 30),

              // Booking Details
              _infoRow(Icons.calendar_today, "Date", "10 Nov 2025"),
              _infoRow(Icons.access_time, "Time", "4:30 PM"),
              _infoRow(Icons.person, "Barber", "Rafi"),
              const Divider(height: 30),

              // Services
              const Text("Selected Services",
                  style:
                      TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              Column(
                children: services
                    .map((service) => ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(service["name"],
                              style: const TextStyle(fontSize: 20,
                                fontWeight: FontWeight.w400,
                                color: Colors.black87
                              )),
                          trailing: Text("৳${service["price"]}",
                              style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87)),
                        ))
                    .toList(),
              ),
              const Divider(height: 30),

              // Total
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text("Service Charge",
                      style: TextStyle(fontWeight: FontWeight.w400, fontSize: 15)),
                  Text("৳10",
                      style: TextStyle(
                          fontWeight: FontWeight.w400,
                          fontSize: 15,
                          color: Colors.black87)),
                ],
              ),
              const SizedBox(height: 4),
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Total",
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text("৳${totalPrice + 10}",
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.blueAccent)),
                ],
              ),
              const Divider(height: 30),

              // Payment
              const Text("Choose Payment Method",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  children: [
                    RadioListTile<String>(
                      value: "Pay at Salon",
                      groupValue: selectedPayment,
                      activeColor: Colors.blueAccent,
                      title: const Text("Pay at Salon",
                          style: TextStyle(fontWeight: FontWeight.w500)),
                      onChanged: (value) {
                        setState(() {
                          selectedPayment = value!;
                        });
                      },
                    ),
                    const Divider(height: 1),
                    RadioListTile<String>(
                      value: "Online Payment (Coming Soon..!)",
                      groupValue: selectedPayment,
                      activeColor: Colors.grey,
                      title: const Text(
                        "Online Payment (Coming Soon)",
                        style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w500),
                      ),
                      onChanged: null, // Disabled for now
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              // Confirm Button
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        title: const Text(
                          "Booking Confirmed!",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        content: const Text(
                          "Your booking has been successfully submitted.",
                        ),
                        actions: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () {
                                  Navigator.pop(context); // Close dialog
                                  Navigator.pop(context); // Navigate back (placeholder)
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blueAccent,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text(
                                  "View Booking",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text(
                    "Confirm Booking",
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}