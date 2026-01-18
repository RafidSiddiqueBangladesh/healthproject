import 'package:flutter/material.dart';
import '../models/user.dart';

class UserProvider with ChangeNotifier {
  User _user = User(id: '1', name: 'User', points: 0);

  User get user => _user;

  void addPoints(int points) {
    _user.points += points;
    notifyListeners();
  }
}