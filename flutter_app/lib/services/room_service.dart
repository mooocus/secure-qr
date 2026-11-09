
import 'package:cloud_firestore/cloud_firestore.dart';

class Room {
  final String id;
  final String name;
  final String description;

  Room({
    required this.id,
    required this.name,
    required this.description,
  });
}

class RoomService {
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  Stream<List<Room>> watchRooms() {
    return _firestore
        .collection('rooms')
        .where('enabled', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
      final rooms = snapshot.docs.map((doc) {
        final data = doc.data();

        return Room(
          id: doc.id,
          name: (data['name'] ?? '').toString(),
          description:
              (data['description'] ?? '').toString(),
        );
      }).toList();

      rooms.sort(
        (a, b) => a.name.compareTo(b.name),
      );

      return rooms;
    });
  }
}
