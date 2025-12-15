// lib/transaksi.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class Transaksi {
  final String id;
  final String itemId; // ID dari dokumen barang
  final String namaBarang;
  final String tipe; // 'masuk' atau 'keluar'
  final int jumlah;
  final String satuan;
  final Timestamp timestamp;

  // Opsional, tergantung tipe
  final String? catatan;
  final String? petugas;  // Untuk keluar
  final String? tujuan;   // Untuk keluar
  final String? penerima; // Untuk masuk
  final String? pengirim; // Untuk masuk

  // --- TAMBAHAN BARU UNTUK LAPORAN PENGHASILAN ---
  final num totalModal;
  final num totalLaba;

  Transaksi({
    required this.id,
    required this.itemId,
    required this.namaBarang,
    required this.tipe,
    required this.jumlah,
    required this.satuan,
    required this.timestamp,
    this.catatan,
    this.petugas,
    this.tujuan,
    this.penerima,
    this.pengirim,
    this.totalModal = 0, // Default 0
    this.totalLaba = 0,  // Default 0
  });

  factory Transaksi.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Transaksi(
      id: doc.id,
      itemId: data['itemId'] ?? '',
      namaBarang: data['namaBarang'] ?? '',
      tipe: data['tipe'] ?? '',
      jumlah: (data['jumlah'] ?? 0).toInt(),
      satuan: data['satuan'] ?? '',
      timestamp: data['timestamp'] ?? Timestamp.now(),
      catatan: data['catatan'],
      petugas: data['petugas'],
      tujuan: data['tujuan'],
      penerima: data['penerima'],
      pengirim: data['pengirim'],
      // --- TAMBAHAN BARU ---
      totalModal: data['total_modal'] ?? 0,
      totalLaba: data['total_laba'] ?? 0,
    );
  }
}