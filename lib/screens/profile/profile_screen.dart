import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // Import provider
import '../../providers/auth_provider.dart'; // Import your AuthProvider

// -------------- Profile Page --------------
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    // Watch the AuthProvider to react to changes in authentication state
    final authProvider = context.watch<AuthProvider>();

    // Get driver information from the AuthProvider
    final String driverName = authProvider.driverName ?? 'N/A';
    final String mdtUsername = authProvider.mdtUsername ?? 'N/A';
    final String driverId = authProvider.driverId ?? 'N/A'; // Assuming driverId is available

    return Scaffold(
      appBar: AppBar(
        title: const Text("Driver Profile"),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              // TODO: Implement profile editing functionality
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Profile editing coming soon!')),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 60,
                  backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                  child: Icon(
                    Icons.person,
                    size: 80,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  driverName, // Display actual driver name
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  mdtUsername, // Display actual MDT username
                  style: TextStyle(
                    fontSize: 16,
                    color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
          ProfileInfoCard(
            title: "Driver Information",
            items: [
              ProfileInfoItem(label: "ID", value: driverId), // Display actual driver ID
              const ProfileInfoItem(label: "Phone", value: "+1 (555) 123-4567"), // Dummy data, replace with actual
              const ProfileInfoItem(label: "License", value: "CO-12345678"), // Dummy data, replace with actual
              const ProfileInfoItem(label: "Vehicle", value: "Honda Civic (2023)"), // Dummy data, replace with actual
            ],
          ),
          const SizedBox(height: 16),
          // You might want to fetch and display actual statistics here
          ProfileInfoCard(
            title: "Statistics",
            items: [
              const ProfileInfoItem(label: "Total Trips", value: "248"),
              const ProfileInfoItem(label: "Completed Trips", value: "245"),
              const ProfileInfoItem(label: "Cancelled Trips", value: "3"),
              const ProfileInfoItem(label: "Rating", value: "4.9/5.0"),
            ],
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            icon: const Icon(Icons.logout),
            label: const Text("Sign Out"),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            onPressed: () {
              // Call the logout method from AuthProvider
              context.read<AuthProvider>().logout();
            },
          ),
        ],
      ),
    );
  }
}

class ProfileInfoCard extends StatelessWidget {
  final String title;
  final List<ProfileInfoItem> items;

  const ProfileInfoCard({
    super.key, // Added super.key
    required this.title,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ...items.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        item.label,
                        style: TextStyle(
                          color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
                        ),
                      ),
                      Text(
                        item.value,
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }
}

class ProfileInfoItem {
  final String label;
  final String value;

  const ProfileInfoItem({
    required this.label,
    required this.value,
  });
}
