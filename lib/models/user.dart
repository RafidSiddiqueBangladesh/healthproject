class User {
  String id;
  String name;
  int points;
  String avatar;

  User({required this.id, required this.name, this.points = 0, this.avatar = ''});
}