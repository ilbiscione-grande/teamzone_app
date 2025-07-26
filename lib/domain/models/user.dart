/// Modell för användare utan statistik, bio och födelsedatum (tillfälligt)
class User {
  final String id;
  final String fullName;
  final String firstName;
  final String lastName;
  final String avatarUrl;
  final String email;
  final String mainRole;
  final String favouritePosition;
  final String phoneNumber;
  final String yob;

  User({
    required this.id,
    required this.fullName,
    required this.firstName,
    required this.lastName,
    required this.avatarUrl,
    required this.email,
    required this.favouritePosition,
    required this.phoneNumber,
    required this.mainRole,
    required this.yob,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      fullName: json['fullName'] as String,
      firstName: json['firstName'] as String,
      lastName: json['lastName'] as String,
      avatarUrl: json['avatarUrl'] as String,
      favouritePosition: json['favouritePosition'] as String,
      phoneNumber: json['phoneNumber'] as String,
      email: json['email'] as String,
      mainRole: json['mainRole'] as String,
      yob: json['yob'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'fullName': fullName,
    'firstName': firstName,
    'lastName': lastName,
    'avatarUrl': avatarUrl,
    'email': email,
    'favouritePosition': favouritePosition,
    'phoneNumber': phoneNumber,
    'mainRole': mainRole,
    'yob': yob,
  };
}
