// lib/features/home/data/repositories/user_repository.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/models/user.dart';

/// Repository för att hämta, uppdatera och ta bort användardata i Firestore
class UserRepository {
  final FirebaseFirestore _db;

  /// Ta emot din Firestore-instans i konstruktorn
  UserRepository(this._db);

  CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection('users');

  /// Hämtar en [User] baserat på [userId]
  Future<User> getUserById(String userId) async {
    final doc = await _users.doc(userId).get();
    if (!doc.exists) {
      throw Exception('Användare med id $userId hittades inte.');
    }

    final data = doc.data()!;
    final safeData = <String, dynamic>{
      'id': doc.id,
      'fullName':
          '${data['firstName']?.toString() ?? ''} ${data['lastName']?.toString() ?? ''}'
              .trim(),
      'firstName': data['firstName']?.toString() ?? '',
      'lastName': data['lastName']?.toString() ?? '',
      'avatarUrl': data['profilePicture']?.toString() ?? '',
      'email': data['email']?.toString() ?? '',
      'favouritePosition': data['favouritePosition']?.toString() ?? '',
      'phoneNumber': data['phoneNumber']?.toString() ?? '',
      'mainRole': data['mainRole']?.toString() ?? '',
      'yob': data['yob']?.toString() ?? '',
    };

    return User.fromJson(safeData);
  }

  /// Uppdaterar befintlig [User] i Firestore
  Future<void> updateUser(User user) async {
    final docRef = _users.doc(user.id);

    // Dela upp fullName i firstName och lastName
    final nameParts = user.fullName.trim().split(' ');
    final firstName = nameParts.isNotEmpty ? nameParts.first : '';
    final lastName = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';

    final updateData = {
      'firstName': firstName,
      'lastName': lastName,
      'profilePicture': user.avatarUrl,
      'email': user.email,
      'mainRole': user.mainRole,
    };

    await docRef.update(updateData);
  }

  /// Tar bort användardokumentet för [userId] från Firestore
  Future<void> deleteUser(String userId) async {
    await _users.doc(userId).delete();
  }
}
