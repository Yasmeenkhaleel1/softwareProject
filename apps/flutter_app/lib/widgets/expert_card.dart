import 'package:flutter/material.dart';

class ExpertCard extends StatelessWidget {
  final String name;
  final String email;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const ExpertCard({
    super.key,
    required this.name,
    required this.email,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 10),
      elevation: 3,
      child: ListTile(
        leading: const CircleAvatar(
          backgroundImage: AssetImage('assets/images/experts.png'),
        ),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(email),
        trailing: Wrap(
          spacing: 10,
          children: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              onPressed: onApprove,
              child: const Text("Approve"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
              onPressed: onReject,
              child: const Text("Reject"),
            ),
          ],
        ),
      ),
    );
  }
}
