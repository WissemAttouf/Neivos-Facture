// lib/models/user_model.dart
// NE PAS importer flutter/material.dart ici

class UserModel {
  final int id;
  final String username;
  

  UserModel({
    required this.id,
    required this.username,
   
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    print('📦 UserModel.fromJson - Reçu: $json');

      } else if (json['id'] is String) {
        userId = int.tryParse(json['id']) ?? 0;
      }
    }

  
    final isActive = json['is_active'] == true || json['is_active'] == 1;

    String? profileImageUrl;
    if (json['profile_image'] != null && json['profile_image'].toString().isNotEmpty) {
      final imageValue = json['profile_image'].toString();
      
      if (imageValue.startsWith('http')) {
        profileImageUrl = imageValue;
      } else {
        profileImageUrl = 'http://10.123.109.205/uploads/profiles/$imageValue';
      }
    }

    DateTime? createdAt;
    if (json['created_at'] != null) {
      try {
        createdAt = DateTime.parse(json['created_at'].toString());
      } catch (e) {
        print('⚠️ Erreur parsing date: $e');
        createdAt = null;
      }
    } 

    return UserModel(
      id: userId,
      username: username,
      
    );
  }

  Map<String, dynamic> toJson() {
    String? cleanProfileImage;
    if (profileImage != null && profileImage!.isNotEmpty) {
      
      }
    }

    return {
      'id': id,
      'username': username,
      
    };
  }

  UserModel copyWith({
    int? id,
    String? username,
    
  }) {
    return UserModel(
      id: id ?? this.id,
      username: username ?? this.username,
      
    );
  }

  String get initials {
    if (username.isEmpty) return '?';
    final parts = username.split(' ');
   

  String get roleName {
    switch (role) {
      case 'admin': return 'Administrateur';
      case 'accountant': return 'Comptable';
      default: return 'Utilisateur';
    }
  }

  // Retourne le nom de la couleur (pas l'objet Color)
  String get roleColorName {
    switch (role) {
      
  }

  @override
  String toString() {
    return 'UserModel(id: $id, username: $username, email: $email, role: $role, isActive: $isActive, profileImage: $profileImage)';
  }
}

