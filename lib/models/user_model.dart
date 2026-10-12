// lib/models/user_model.dart
// NE PAS importer flutter/material.dart ici

class UserModel {
  final int id;
  final String username;
  final String email;
  final String gender;
  final String? profileImage;
  final DateTime? createdAt;
  final String role; // 'admin', 'accountant', 'user'
  final bool isActive;

  UserModel({
    required this.id,
    required this.username,
    required this.email,
    required this.gender,
    this.profileImage,
    this.createdAt,
    this.role = 'user',
    this.isActive = true,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    print('📦 UserModel.fromJson - Reçu: $json');

    int userId = 0;
    if (json['id'] != null) {
      if (json['id'] is int) {
        userId = json['id'];
      } else if (json['id'] is String) {
        userId = int.tryParse(json['id']) ?? 0;
      }
    }

    final username = json['username']?.toString() ?? '';
    final email = json['email']?.toString() ?? '';
    final gender = json['gender']?.toString() ?? 'other';
    final role = json['role']?.toString() ?? 'user';
    final isActive = json['is_active'] == true || json['is_active'] == 1;

    String? profileImageUrl;
    if (json['profile_image'] != null && json['profile_image'].toString().isNotEmpty) {
      final imageValue = json['profile_image'].toString();
      if (imageValue.startsWith('http')) {
        profileImageUrl = imageValue;
      } else {
        profileImageUrl = 'http://10.123.109.205/uploads/profiles/$imageValue';
      }
      print('🖼️ URL construite dans fromJson: $profileImageUrl');
    } else if (json['profileImage'] != null) {
      final imageValue = json['profileImage'].toString();
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
    } else if (json['createdAt'] != null) {
      try {
        createdAt = DateTime.parse(json['createdAt'].toString());
      } catch (e) {
        print('⚠️ Erreur parsing date: $e');
        createdAt = null;
      }
    }

    return UserModel(
      id: userId,
      username: username,
      email: email,
      gender: gender,
      profileImage: profileImageUrl,
      createdAt: createdAt,
      role: role,
      isActive: isActive,
    );
  }

  Map<String, dynamic> toJson() {
    String? cleanProfileImage;
    if (profileImage != null && profileImage!.isNotEmpty) {
      if (profileImage!.startsWith('http')) {
        final uri = Uri.tryParse(profileImage!);
        if (uri != null) {
          cleanProfileImage = uri.pathSegments.isNotEmpty
              ? uri.pathSegments.last
              : profileImage;
        } else {
          cleanProfileImage = profileImage!.replaceAll('10.123.109.205/uploads/profiles/', '');
        }
      } else {
        cleanProfileImage = profileImage;
      }
    }

    return {
      'id': id,
      'username': username,
      'email': email,
      'gender': gender,
      'profile_image': cleanProfileImage,
      'created_at': createdAt?.toIso8601String(),
      'role': role,
      'is_active': isActive,
    };
  }

  UserModel copyWith({
    int? id,
    String? username,
    String? email,
    String? gender,
    String? profileImage,
    DateTime? createdAt,
    String? role,
    bool? isActive,
  }) {
    return UserModel(
      id: id ?? this.id,
      username: username ?? this.username,
      email: email ?? this.email,
      gender: gender ?? this.gender,
      profileImage: profileImage ?? this.profileImage,
      createdAt: createdAt ?? this.createdAt,
      role: role ?? this.role,
      isActive: isActive ?? this.isActive,
    );
  }

  String get initials {
    if (username.isEmpty) return '?';
    final parts = username.split(' ');
    if (parts.length > 1) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return username[0].toUpperCase();
  }

  bool get isAdmin => role == 'admin';
  bool get isAccountant => role == 'accountant';
  bool get isAccountantOrAdmin => role == 'admin' || role == 'accountant';

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
      case 'admin': return 'red';
      case 'accountant': return 'blue';
      default: return 'green';
    }
  }

  @override
  String toString() {
    return 'UserModel(id: $id, username: $username, email: $email, role: $role, isActive: $isActive, profileImage: $profileImage)';
  }
}

