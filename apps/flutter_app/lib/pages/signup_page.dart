import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _formKey = GlobalKey<FormState>();

  String name = "";
  String email = "";
  String password = "";
  String gender = "male";
  String role = "student";
  int? age;

  Future<void> signupUser() async {
    final response = await http.post(
      Uri.parse('http://localhost:5000/api/signup'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        "name": name,
        "email": email,
        "password": password,
        "age": age,
        "gender": gender,
        "role": role
      }),
    );
    final data = jsonDecode(response.body);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['message'])));
    if (response.statusCode == 201) {
      Navigator.pushNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFE5B4),
      appBar: AppBar(
        backgroundColor: const Color(0xFF5BB19F),
        title: const Text("Sign Up", style: TextStyle(color: Colors.white)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                decoration: const InputDecoration(labelText: "Name"),
                onChanged: (v) => name = v,
                validator: (v) => v!.isEmpty ? "Enter your name" : null,
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: "Email"),
                keyboardType: TextInputType.emailAddress,
                onChanged: (v) => email = v,
                validator: (v) => v!.isEmpty ? "Enter a valid email" : null,
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: "Password"),
                obscureText: true,
                onChanged: (v) => password = v,
                validator: (v) =>
                    v!.length < 6 ? "Password must be at least 6 characters" : null,
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: "Age"),
                keyboardType: TextInputType.number,
                onChanged: (v) => age = int.tryParse(v),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField(
                decoration: const InputDecoration(labelText: "Gender"),
                initialValue: gender,
                items: const [
                  DropdownMenuItem(value: "male", child: Text("Male")),
                  DropdownMenuItem(value: "female", child: Text("Female")),
                  DropdownMenuItem(value: "other", child: Text("Other")),
                ],
                onChanged: (v) => setState(() => gender = v!),
              ),
              DropdownButtonFormField(
                decoration: const InputDecoration(labelText: "Role"),
                initialValue: role,
                items: const [
                  DropdownMenuItem(value: "student", child: Text("Customer")),
                  DropdownMenuItem(value: "service_center", child: Text("Specialist")),
                  DropdownMenuItem(value: "admin", child: Text("Admin")),
                ],
                onChanged: (v) => setState(() => role = v!),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF5BB19F),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    signupUser();
                  }
                },
                child: const Text("Sign Up", style: TextStyle(color: Colors.white)),
              ),
              const SizedBox(height: 15),
              TextButton(
                onPressed: () => Navigator.pushNamed(context, '/login'),
                child: const Text("Already have an account? Log In"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
