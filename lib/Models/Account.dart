class Account {
  String? email;
  String?
      password; // You have this field but not used in constructor or JSON methods.
  String? userId;
  String? location;
  List<Account>? groupwith;

  Account({
    this.email,
    this.userId,
    this.location,
    this.groupwith,
  });

  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'userId': userId,
      'location': location,
      'groupwith': groupwith?.map((account) => account.toJson()).toList(),
    };
  }

  factory Account.fromJson(Map<String, dynamic> json) {
    var groupWithJson = json['groupwith'] as List<dynamic>?;
    List<Account>? groupWithList = groupWithJson
        ?.map((e) => Account.fromJson(e as Map<String, dynamic>))
        .toList();

    return Account(
      email: json['email'],
      userId: json['userId'],
      location: json['location'] ?? '',
      groupwith: groupWithList,
    );
  }
}
