import 'package:flutter/material.dart';

class BookingReceiptScreen extends StatelessWidget {
  const BookingReceiptScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Booking Receipt"),
        centerTitle: true,
        backgroundColor: Colors.blueAccent,
        elevation: 0,
      ),
      backgroundColor: const Color(0xFFF5F7FB),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 20),

            // Floating Main Card
            Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.storefront, color: Colors.blueAccent),
                      SizedBox(width: 8),
                      Text("Salon Luxe", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text("123 Main Street, Dhaka"),
                  const Text("Phone: +880 1712 345678"),
                  const Text("Email: salonluxe@example.com"),
                  const Text("Stylist: Rafi Uddin"),
                  const SizedBox(height: 4),
                  const Text("Date: 12 Nov 2025, 3:00 PM"),
                  const SizedBox(height: 20),
                  const Divider(),

                  const Text("Customer Information", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  SizedBox(height: 10),
                  _infoRow("Name", "Boss"),
                  _infoRow("Phone", "+880 1999 556677"),
                  _infoRow("Email", "boss@email.com"),
                  const SizedBox(height: 20),
                  const Divider(),

                  const Text("Service Details", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),

                  _serviceTile("Haircut", "৳250", Icons.content_cut),
                  _serviceTile("Beard Trim", "৳150", Icons.face_6_outlined),

                  const Divider(),
                  _priceRow("Subtotal", "৳400"),
                  _priceRow("Service Charge", "৳40"),
                  const Divider(),
                  _priceRow("Total", "৳440"),

                  const SizedBox(height: 15),

                  const SizedBox(height: 25),

                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F6FB),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      children: [
                        _infoRow("💳 Payment Method", "Pay at salon"),
                        const SizedBox(height: 8),
                        _infoRow("✅ Booking Status", "Completed"),
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),
                  const Center(
                    child: Column(
                      children: [
                        Text(
                          "Thank you for choosing CutLine 💈",
                          style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic, fontSize: 14),
                        ),
                        SizedBox(height: 4),
                        Text(
                          "Powered by CutLine",
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // Back Button (solid color)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    "Back to My Bookings",
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  static Widget _priceRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontSize: 15)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  static Widget _serviceTile(String title, String price, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: Colors.orangeAccent),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontSize: 15)),
            ],
          ),
          Text(price, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  static Widget _infoRow(String title, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(fontSize: 15)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    );
  }
}
