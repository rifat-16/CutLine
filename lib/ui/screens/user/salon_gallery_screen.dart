import 'package:flutter/material.dart';

class SalonGalleryScreen extends StatelessWidget {
  final String salonName;
  final int uploadedCount;
  final int totalLimit;

  const SalonGalleryScreen({
    Key? key,
    required this.salonName,
    this.uploadedCount = 7,
    this.totalLimit = 10,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "$salonName Gallery",
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.blueAccent),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Center(
              child: Text(
                "$uploadedCount / $totalLimit",
                style: const TextStyle(
                  color: Colors.blueAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.delayed(const Duration(seconds: 1));
        },
        child: GridView.builder(
          padding: const EdgeInsets.all(6.0),
          physics: const AlwaysScrollableScrollPhysics(),
          itemCount: uploadedCount,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 1,
            crossAxisSpacing: 0,
            mainAxisSpacing: 6,
            childAspectRatio: 1.3,
          ),
          itemBuilder: (context, index) {
            return GestureDetector(
              onTap: () {
                // TODO: Open full-screen image viewer
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Image.asset(
                  "assets/images/salon_${(index % 4) + 1}.jpg",
                  fit: BoxFit.cover,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}