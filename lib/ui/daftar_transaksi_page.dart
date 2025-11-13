import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; 
import '../transaksi.dart';
import 'form_barang_masuk_page.dart';
import 'form_barang_keluar_page.dart';

class DaftarTransaksiPage extends StatefulWidget {
  const DaftarTransaksiPage({Key? key}) : super(key: key);

  @override
  State<DaftarTransaksiPage> createState() => _DaftarTransaksiPageState();
}

class _DaftarTransaksiPageState extends State<DaftarTransaksiPage> {
  String _filter = 'semua'; // 'semua', 'masuk', 'keluar'

  Stream<QuerySnapshot> _getTransaksiStream() {
    Query query = FirebaseFirestore.instance
        .collection('transaksi')
        .orderBy('timestamp', descending: true);

    if (_filter == 'masuk') {
      query = query.where('tipe', isEqualTo: 'masuk');
    } else if (_filter == 'keluar') {
      query = query.where('tipe', isEqualTo: 'keluar');
    }
    
    return query.snapshots();
  }

  // Fungsi untuk menampilkan dialog konfirmasi hapus
  Future<void> _deleteTransaksi(Transaksi transaksi) async {
    bool? confirmDelete = await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Konfirmasi Hapus'),
          content: const Text('Menghapus transaksi ini juga akan MENGEMBALIKAN STOK barang. Apakah Anda yakin?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Batal'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              child: const Text('Hapus', style: TextStyle(color: Colors.red)),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );

    if (confirmDelete == true) {
      try {
        WriteBatch batch = FirebaseFirestore.instance.batch();

        // 1. Hapus dokumen transaksi
        DocumentReference trxRef = FirebaseFirestore.instance
            .collection('transaksi')
            .doc(transaksi.id);
        batch.delete(trxRef);

        // 2. Kembalikan stok barang
        DocumentReference itemRef = FirebaseFirestore.instance
            .collection('barang')
            .doc(transaksi.itemId);
        
        int stokAdjustment = transaksi.jumlah;
        if (transaksi.tipe == 'masuk') {
          // Jika hapus transaksi MASUK, stok DIKURANGI
          batch.update(itemRef, {'stok_awal': FieldValue.increment(-stokAdjustment)});
        } else {
          // Jika hapus transaksi KELUAR, stok DITAMBAH
          batch.update(itemRef, {'stok_awal': FieldValue.increment(stokAdjustment)});
        }
        
        await batch.commit();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Transaksi dihapus dan stok dikembalikan.')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menghapus: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Daftar Transaksi'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        elevation: 1,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() {}),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Filter Toggles
            _buildFilterToggles(),
            const SizedBox(height: 16),

            // Summary Chips
            StreamBuilder<QuerySnapshot>(
              stream: _getTransaksiStream(),
              builder: (context, snapshot) {
                int total = snapshot.hasData ? snapshot.data!.docs.length : 0;
                return _buildSummaryChips(total, total);
              }
            ),
            const SizedBox(height: 16),

            // Daftar Transaksi
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _getTransaksiStream(),
                builder: (BuildContext, snapshot) {
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.data!.docs.isEmpty) {
                    return const Center(child: Text('Belum ada transaksi.'));
                  }

                  return ListView.builder(
                    itemCount: snapshot.data!.docs.length,
                    itemBuilder: (context, index) {
                      Transaksi trx = Transaksi.fromFirestore(snapshot.data!.docs[index]);
                      return _buildTransactionCard(trx);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _buildFloatingActionButtons(),
    );
  }

  Widget _buildFilterToggles() {
    return Row(
      children: [
        _buildFilterChip('Semua', 'semua', Icons.check_circle),
        const SizedBox(width: 8),
        _buildFilterChip('Masuk', 'masuk', null),
        const SizedBox(width: 8),
        _buildFilterChip('Keluar', 'keluar', null),
      ],
    );
  }

  Widget _buildFilterChip(String label, String filterValue, IconData? icon) {
    bool isActive = _filter == filterValue;
    return ChoiceChip(
      label: Text(label),
      selected: isActive,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _filter = filterValue;
          });
        }
      },
      avatar: icon != null && isActive ? Icon(icon, size: 16, color: Colors.white) : null,
      backgroundColor: Colors.white,
      selectedColor: Theme.of(context).primaryColor,
      labelStyle: TextStyle(
        color: isActive ? Colors.white : Colors.black87,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: isActive ? Colors.transparent : Colors.grey[300]!),
      ),
      elevation: 1,
    );
  }

  Widget _buildSummaryChips(int total, int displayed) {
    return Row(
      children: [
        Chip(
          label: Text('Total: $total transaksi'),
          backgroundColor: Colors.white,
          side: BorderSide(color: Colors.grey[300]!),
        ),
        const SizedBox(width: 8),
        Chip(
          label: Text('Ditampilkan: $displayed'),
          backgroundColor: Colors.white,
          side: BorderSide(color: Colors.grey[300]!),
        ),
      ],
    );
  }
  
  Widget _buildFloatingActionButtons() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        FloatingActionButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const FormBarangMasukPage()),
            );
          },
          child: const Icon(Icons.add, color: Colors.white),
          backgroundColor: Colors.green,
          heroTag: 'fab_masuk',
        ),
        const SizedBox(height: 12),
        FloatingActionButton(
          onPressed: () {
             Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const FormBarangKeluarPage()),
            );
          },
          child: const Icon(Icons.remove, color: Colors.white),
          backgroundColor: Colors.red,
          heroTag: 'fab_keluar',
        ),
      ],
    );
  }

  Widget _buildTransactionCard(Transaksi trx) {
    bool isMasuk = trx.tipe == 'masuk';
    Color chipColor = isMasuk ? Colors.green : Colors.red;
    IconData chipIcon = isMasuk ? Icons.arrow_downward : Icons.arrow_upward;
    String chipLabel = isMasuk ? 'BARANG MASUK' : 'BARANG KELUAR';

    // Format tanggal
    String formattedDate = DateFormat('d/M/y H:mm').format(trx.timestamp.toDate());

    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.grey[50], // Warna kartu yang sedikit off-white
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Chip Tipe Transaksi
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: chipColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Icon(chipIcon, color: chipColor, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        chipLabel,
                        style: TextStyle(
                          color: chipColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                // Tombol Hapus
                IconButton(
                  icon: Icon(Icons.delete_outline, color: Colors.grey[600]),
                  onPressed: () => _deleteTransaksi(trx),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Nama Barang
            Text(
              trx.namaBarang,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            // Detail Transaksi
            _buildDetailRow('Jumlah:', '${trx.jumlah} ${trx.satuan}'),
            if (isMasuk) ...[
              _buildDetailRow('Penerima:', trx.penerima ?? '-'),
              _buildDetailRow('Pengirim:', trx.pengirim ?? '-'),
            ] else ...[
              _buildDetailRow('Petugas:', trx.petugas ?? '-'),
              _buildDetailRow('Tujuan:', trx.tujuan ?? '-'),
            ],
            _buildDetailRow('Waktu:', formattedDate),
            _buildDetailRow('Catatan:', trx.catatan ?? '-'),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 70, // Lebar tetap untuk label
            child: Text(
              label,
              style: TextStyle(fontSize: 13, color: Colors.grey[700]),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 13, color: Colors.grey[900]),
            ),
          ),
        ],
      ),
    );
  }
}