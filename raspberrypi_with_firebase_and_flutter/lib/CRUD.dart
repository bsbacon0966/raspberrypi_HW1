import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreServices {
  final CollectionReference notes = FirebaseFirestore.instance.collection('devices');
  final CollectionReference controller = FirebaseFirestore.instance.collection('settings');

  // 獲取設備信息流
  Stream<QuerySnapshot> getDeviceInfo() {
    final device_info = notes.orderBy('timestamp', descending: true).snapshots();
    return device_info;
  }

  // 刪除單個記錄
  Future<void> deleteNote(String docID) {
    return notes.doc(docID).delete();
  }

  // 刪除所有記錄
  Future<void> deleteAllNotes() async {
    final querySnapshot = await notes.get();
    for (final doc in querySnapshot.docs) {
      await doc.reference.delete();
    }
  }

  // 設置 Z_THRESHOLD
  Future<void> setZThreshold(double threshold) {
    return controller.doc('thresholds').set({
      'Z_THRESHOLD': threshold,
    });
  }

  // 獲取 Z_THRESHOLD
  Future<double?> getZThreshold() async {
    DocumentSnapshot doc = await controller.doc('thresholds').get();
    if (doc.exists) {
      return (doc.data() as Map<String, dynamic>)['Z_THRESHOLD']?.toDouble();
    }
    return null;
  }
}