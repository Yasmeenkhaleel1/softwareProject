import 'package:flutter/material.dart';

class CustomerProfilePage extends StatelessWidget {
  const CustomerProfilePage({super.key});
  
  // 💡 يمكنك جلب بيانات المستخدم الفعلية هنا من API (مثلاً: /api/users/:id)

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Customer Profile'),
        backgroundColor: const Color(0xFF62C6D9),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              // 🖼️ صورة البروفايل
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF62C6D9), width: 3),
                  image: const DecorationImage(
                    image: AssetImage('assets/images/default_avatar.png'), // استخدم صورة افتراضية
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(height: 15),

              // 🏷️ اسم المستخدم ودوره
              const Text(
                'Ahmad Al-Saleh', // اسم افتراضي
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1E2A38)),
              ),
              const Text(
                'Role: Customer',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 30),

              // 📝 قائمة التفاصيل
              Card(
                elevation: 3,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                child: Padding(
                  padding: const EdgeInsets.all(15.0),
                  child: Column(
                    children: <Widget>[
                      _buildProfileDetail(Icons.email, 'Email', 'ahmad.saleh@example.com'),
                      _buildProfileDetail(Icons.phone, 'Phone', '+962 7XXXXXXXX'),
                      _buildProfileDetail(Icons.cake, 'Age', '30'),
                      _buildProfileDetail(Icons.people, 'Gender', 'Male'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 30),

              // ✍️ زر تعديل البروفايل
              ElevatedButton.icon(
                onPressed: () {
                  // 💡 هنا سيتم الانتقال لصفحة تعديل البيانات
                },
                icon: const Icon(Icons.edit, color: Colors.white),
                label: const Text('Edit Profile Information', style: TextStyle(fontSize: 16, color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF62C6D9),
                  padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  // 🏗️ وظيفة بناء تفاصيل البروفايل
  Widget _buildProfileDetail(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Row(
        children: <Widget>[
          Icon(icon, color: const Color(0xFF62C6D9), size: 24),
          const SizedBox(width: 15),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(label, style: const TextStyle(fontSize: 14, color: Colors.grey)),
              Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
            ],
          ),
        ],
      ),
    );
  }
}