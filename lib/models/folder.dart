/// A flat (non-nested) folder used to organize books in the library.
class Folder {
  final String id;
  final String name;
  final DateTime createdAt;

  const Folder({required this.id, required this.name, required this.createdAt});

  Map<String, dynamic> toMap() => {
    'name': name,
    'createdAt': createdAt.toIso8601String(),
  };

  factory Folder.fromMap(String id, Map raw) => Folder(
    id: id,
    name: raw['name'] as String,
    createdAt: DateTime.parse(raw['createdAt'] as String),
  );
}
