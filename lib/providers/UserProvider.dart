import 'package:flutter/material.dart';

class User {
  final int id;


class UserProvider with ChangeNotifier {
  User? _user;

  User? get user => _user;

  
  void clearUser() {
    _user = null;
    notifyListeners();
  }
}
