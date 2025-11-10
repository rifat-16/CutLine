import 'package:cutline/ui/screens/user/booking_summary_screen.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class BookingScreen extends StatefulWidget {
  const BookingScreen({Key? key}) : super(key: key);

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  List<String> selectedServiceList = [];
  String? selectedBarber;
  DateTime selectedDate = DateTime.now();
  String? selectedTime;

  int currentWaiting = 3; // mock data for waiting customers

  final List<String> services = ["Haircut", "Beard Trim", "Facial", "Coloring"];
  final List<String> barbers = ["Arafat", "Rafi", "Siam", "Hasan"];
  final List<String> timeSlots = [
    "10:00 AM", "10:30 AM", "11:00 AM", "11:30 AM",
    "12:00 PM", "12:30 PM", "1:00 PM", "1:30 PM",
    "2:00 PM", "2:30 PM", "3:00 PM", "3:30 PM",
    "4:00 PM", "4:30 PM", "5:00 PM", "5:30 PM",
    "6:00 PM", "6:30 PM", "7:00 PM", "7:30 PM",
  ];

  final List<String> bookedSlots = ["11:00 AM", "2:30 PM", "5:00 PM"]; // mock booked slots

  @override
  Widget build(BuildContext context) {
    final Map<String, int> servicePrices = {
      "Haircut": 500,
      "Beard Trim": 300,
      "Facial": 800,
      "Coloring": 1200,
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Book Your Slot",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.blueAccent,
        elevation: 0.5,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Salon Info Card
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        height: 60,
                        width: 60,
                        child: Image.network(
                          "https://images.unsplash.com/photo-1600891964093-3b40cc0d2c7e",
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Urban Fade Salon",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            "Dhanmondi, Dhaka",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: Colors.black54),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: const [
                              Icon(Icons.star, color: Colors.amber, size: 16),
                              Text("4.8", style: TextStyle(fontWeight: FontWeight.w600)),
                              Icon(Icons.schedule, color: Colors.blueAccent, size: 16),
                              Text("10 AM - 8 PM", style: TextStyle(color: Colors.black54)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Grid-based Multi-Select Service
            const Text("Select Service", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: services.map((service) {
                final isSelected = selectedServiceList.contains(service);
                final name = service;
                final price = servicePrices[service] ?? 0;
                return ChoiceChip(
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isSelected ? Icons.check : Icons.add,
                        size: 20,
                        color: isSelected ? Colors.white : Colors.black54,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        "$name  ৳$price",
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  selected: isSelected,
                  showCheckmark: false,
                  selectedColor: Colors.blueAccent,
                  backgroundColor: Colors.white,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : Colors.blueAccent,
                    fontWeight: FontWeight.w600,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(
                      color: isSelected ? Colors.blueAccent : Colors.grey.shade300,
                      width: 1.2,
                    ),
                  ),
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        selectedServiceList.add(service);
                      } else {
                        selectedServiceList.remove(service);
                      }
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Barber Dropdown
            const Text("Select Barber", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: barbers.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 1.6,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemBuilder: (context, index) {
                final barber = barbers[index];
                final isSelected = selectedBarber == barber;
                return GestureDetector(
                  onTap: () => setState(() => selectedBarber = barber),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isSelected
                            ? [Colors.blueAccent.shade200, Colors.blueAccent]
                            : [Colors.white, Colors.white],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.blueAccent.withOpacity(0.4), width: 1.2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundImage: NetworkImage("https://i.pravatar.cc/150?img=${index + 10}"),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          barber,
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.blueAccent,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          "⭐ 4.9 • Hair Specialist",
                          style: TextStyle(
                            color: isSelected ? Colors.white70 : Colors.black54,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),

            // Date Picker Horizontal
            const Text("Select Date", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            SizedBox(
              height: 70,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: 7,
                itemBuilder: (context, index) {
                  final date = DateTime.now().add(Duration(days: index));
                  final isSelected = selectedDate.year == date.year && selectedDate.month == date.month && selectedDate.day == date.day;
                  return GestureDetector(
                    onTap: () => setState(() => selectedDate = date),
                    child: Container(
                      width: 70,
                      margin: const EdgeInsets.only(right: 10),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.blueAccent : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blueAccent),
                      ),
                      child: Center(
                        child: Text(
                          DateFormat('EEE\ndd').format(date),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.blueAccent,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),

            // Time Slot Grid
            const Text("Select Time Slot", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: timeSlots.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 2.6,
              ),
              itemBuilder: (context, index) {
                final slot = timeSlots[index];
                final isBooked = bookedSlots.contains(slot);
                final isSelected = selectedTime == slot;

                return GestureDetector(
                  onTap: isBooked ? null : () => setState(() => selectedTime = slot),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isBooked
                          ? Colors.grey.shade300
                          : (isSelected ? Colors.blueAccent : Colors.white),
                      border: Border.all(color: Colors.blueAccent),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        slot,
                        style: TextStyle(
                          color: isBooked
                              ? Colors.grey
                              : (isSelected ? Colors.white : Colors.blueAccent),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            Text(
              "Current waiting: $currentWaiting people ahead",
              style: const TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 8),
            const SizedBox(height: 30),

            // Wait Time Info
            const Text("Estimated wait time: 20 min", style: TextStyle(color: Colors.black54)),
            const SizedBox(height: 30),

            // Confirm Booking Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  // TODO: Add booking confirmation logic
                  Navigator.push(context,
                    MaterialPageRoute(
                      builder: (context) => const BookingSummaryScreen(),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text(
                  "Confirm Booking",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
