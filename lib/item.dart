import 'package:cloud_firestore/cloud_firestore.dart';

class Item {
  final String id;
  final String nama;
  final String kategori;
  final int stok;
  final String satuan;
  final int stokMinimum; // Menggunakan camelCase
  final int hargaBeli;   // Menggunakan camelCase
  final int hargaJual;   // Menggunakan camelCase
  final bool isArchived; // Tambahan untuk status arsip

  Item({
    required this.id,
    required this.nama,
    required this.kategori,
    required this.stok,
    required this.satuan,
    required this.stokMinimum,
    required this.hargaBeli,
    required this.hargaJual,
    required this.isArchived,
  });

  factory Item.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    return Item(
      id: doc.id,
      nama: data['nama'] ?? '',
      kategori: data['kategori'] ?? 'Lainnya',
      // Menggunakan (?? 0) agar tidak error jika data kosong
      stok: (data['stok'] ?? 0).toInt(),
      satuan: data['satuan'] ?? 'Pcs',
      
      // --- PERBAIKAN DI SINI (Membaca format camelCase) ---
      // Kita tambahkan fallback check agar support data lama (snake_case) & baru (camelCase)
      stokMinimum: (data['stokMinimum'] ?? data['stok_minimum'] ?? 0).toInt(),
      hargaBeli: (data['hargaBeli'] ?? data['harga_beli'] ?? 0).toInt(),
      hargaJual: (data['hargaJual'] ?? data['harga_jual'] ?? 0).toInt(),
      
      // Default false jika field belum ada
      isArchived: data['isArchived'] ?? false,
    );
  }
}