import 'package:cutline/ui/screens/user/salon_details_screen.dart';
import 'package:flutter/material.dart';

class FavoriteSalonScreen extends StatefulWidget {
  const FavoriteSalonScreen({super.key});

  @override
  State<FavoriteSalonScreen> createState() => _FavoriteSalonScreenState();
}

class _FavoriteSalonScreenState extends State<FavoriteSalonScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Favorite Salons"),
        centerTitle: true,
        backgroundColor: Colors.blueAccent,
        elevation: 0,
      ),
      backgroundColor: const Color(0xFFF5F7FB),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 2,
            separatorBuilder: (_, __) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              return InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SalonDetailsScreen(salonName: ''),
                    ),
                  );
                },
                child: Container(
                  height: 300,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12.withOpacity(0.05),
                        blurRadius: 4,
                        spreadRadius: 1,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Cover Image + Favorite Icon + Name/Rating Overlay
                      Stack(
                        children: [
                          // Cover image placeholder
                          Container(
                            height: 200,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(16),
                                topRight: Radius.circular(16),
                              ),
                              color: Colors.grey[300],
                            ),
                            child: const Center(
                              child: Text(
                                'Cover Image Area',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            right: 10,
                            top: 10,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.black38,
                                borderRadius: BorderRadius.circular(50),
                              ),
                              padding: const EdgeInsets.all(4),
                              child: const Icon(Icons.favorite_border,
                                  color: Colors.white, size: 22),
                            ),
                          ),
                          Positioned(
                            left: 12,
                            bottom: 10,
                            child: Column(
                              crossAxisAlignment:
                              CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Row(
                                  children: const [
                                    Icon(Icons.star,
                                        size: 16,
                                        color: Colors.orangeAccent),
                                    SizedBox(width: 4),
                                    Text(
                                      "4.6 (120)",
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 13),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      // Info section
                      Flexible(fit: FlexFit.loose,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment:
                                CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: const [
                                      Icon(Icons.location_on,
                                          size: 16, color: Colors.grey),
                                      SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          "Banani, Dhaka • 0.8 km away",
                                          style: TextStyle(
                                              color: Colors.black87,
                                              fontSize: 13),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 6),
                                  Row(
                                    children: const [
                                      Icon(Icons.access_time,
                                          size: 16, color: Colors.grey),
                                      SizedBox(width: 4),
                                      Text(
                                        "Wait time: 10 mins  •  ",
                                        style: TextStyle(
                                            color: Colors.black87,
                                            fontSize: 13),
                                      ),
                                      Text(
                                        "Open Now",
                                        style: TextStyle(
                                            color: Colors.green,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 6),
                                  Text(
                                    "Top Services: Haircut, Beard Trim, Facial",
                                    style: TextStyle(
                                        color: Colors.grey[700],
                                        fontSize: 13),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      )
    );
  }
}
