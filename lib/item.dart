import 'package:cloud_firestore/cloud_firestore.dart';

class Item {
  final String id;
  final String nama;
  final String kategori;
  final int stokAwal;
  final int stokMinimum;
  final String satuan;

  Item({
    required this.id,
    required this.nama,
    required this.kategori,
    required this.stokAwal,
    required this.stokMinimum,
    required this.satuan,
  });

  // Factory untuk membuat Item dari data Firestore
  factory Item.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Item(
      id: doc.id,
      nama: data['nama'] ?? '',
      kategori: data['kategori'] ?? '',
      // Konversi ke int dengan aman
      stokAwal: (data['stok_awal'] ?? 0).toInt(),
      stokMinimum: (data['stok_minimum'] ?? 0).toInt(),
      satuan: data['satuan'] ?? '',
    );
  }
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Item &&
          runtimeType == other.runtimeType &&
          id == other.id; // Bandingkan berdasarkan ID unik

  @override
  int get hashCode => id.hashCode; // Gunakan hash dari ID
}