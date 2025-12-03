enum UserRole { customer, owner, barber }

extension UserRoleKey on UserRole {
  String get key => name;

  static UserRole fromKey(String key) {
    switch (key) {
      case 'owner':
        return UserRole.owner;
      case 'barber':
        return UserRole.barber;
      default:
        return UserRole.customer;
    }
  }
}
