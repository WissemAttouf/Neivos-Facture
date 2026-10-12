import 'package:flutter/material.dart';

class User {
  final int id;
  final String username;
  final String email;

  User({required this.id, required this.username, required this.email});
}

class UserProvider with ChangeNotifier {
  User? _user;

  User? get user => _user;

  void setUser(User user) {
    _user = user;
    notifyListeners();
  }

  void clearUser() {
    _user = null;
    notifyListeners();
  }
}
