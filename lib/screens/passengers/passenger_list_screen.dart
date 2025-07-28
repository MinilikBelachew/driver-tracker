

import 'package:flutter/material.dart';

import 'dart:ui'; // for ImageFilter

import '../../models/passenger.dart';
import '../../screens/passengers/passenger_detail_screen.dart';

// -------------- Passenger List Page -------------
class PassengerListPage extends StatelessWidget {
  const PassengerListPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Sort by earliest pickup time
    List<Passenger> sorted = [...passengerList];
    sorted.sort((a, b) => a.earliestPickup.compareTo(b.earliestPickup));
    return Scaffold(
      appBar: AppBar(title: Text("Passenger Schedule"), elevation: 0),
      body: ListView.builder(
        padding: EdgeInsets.all(8),
        itemCount: sorted.length,
        itemBuilder: (context, idx) {
          final p = sorted[idx];
          return Card(
            margin: EdgeInsets.symmetric(vertical: 6, horizontal: 4),
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => PassengerDetailPage(passenger: p),
                  ),
                );
              },
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: Colors.blue.withOpacity(0.2),
                          child: Icon(Icons.person, color: Colors.blue),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                p.name,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                "Pickup window: ${p.earliestPickup} - ${p.latestPickup}",
                                style: TextStyle(
                                  color:
                                      Theme.of(context).colorScheme.secondary,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(Icons.location_on, size: 18, color: Colors.green),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            p.pickupAddress,
                            style: TextStyle(fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.flag, size: 18, color: Colors.red),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            p.dropoffAddress,
                            style: TextStyle(fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          "Duration: ${p.duration.toStringAsFixed(1)} min",
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
