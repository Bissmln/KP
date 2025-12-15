// lib/ui/daftar_barang_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'tambah_barang_page.dart';
import '../item.dart';

class DaftarBarangPage extends StatefulWidget {
  const DaftarBarangPage({Key? key}) : super(key: key);

  @override
  State<DaftarBarangPage> createState() => _DaftarBarangPageState();
}

class _DaftarBarangPageState extends State<DaftarBarangPage> {
  // Arah sorting
  bool _isAscending = true;
  // Kueri pencarian
  String _searchQuery = '';
  // --- [BARU] Status Filter: Apakah sedang melihat arsip? ---
  bool _showArchived = false; 

  // Format Rupiah
  final formatRupiah = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  // Fungsi untuk membangun stream berdasarkan filter
  Stream<QuerySnapshot> _getItemsStream() {
    Query query = FirebaseFirestore.instance.collection('barang');

    // 1. Filter: Tampilkan sesuai status _showArchived
    // Jika _showArchived = false (default), cari yang isArchived == false
    // Jika _showArchived = true (lihat arsip), cari yang isArchived == true
    query = query.where('isArchived', isEqualTo: _showArchived);

    // 2. Filter Search
    if (_searchQuery.isNotEmpty) {
      query = query
          .where('nama', isGreaterThanOrEqualTo: _searchQuery)
          .where('nama', isLessThanOrEqualTo: '$_searchQuery\uf8ff');
    }

    // 3. Sorting
    query = query.orderBy('nama', descending: !_isAscending);

    return query.snapshots();
  }

  // Fungsi Arsipkan Barang (Menyembunyikan)
  Future<void> _archiveItem(String docId) async {
    bool? confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Arsipkan Barang?'),
        content: const Text('Barang akan disembunyikan dari transaksi.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true), 
            child: const Text('Arsipkan', style: TextStyle(color: Colors.orange))
          ),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseFirestore.instance.collection('barang').doc(docId).update({'isArchived': true});
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Barang diarsipkan.')));
    }
  }

  // --- [BARU] Fungsi Restore Barang (Mengembalikan) ---
  Future<void> _restoreItem(String docId) async {
    bool? confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Kembalikan Barang?'),
        content: const Text('Barang akan muncul kembali di daftar transaksi.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true), 
            child: const Text('Kembalikan', style: TextStyle(color: Colors.green))
          ),
        ],
      ),
    );

    if (confirm == true) {
      // Set isArchived kembali jadi false
      await FirebaseFirestore.instance.collection('barang').doc(docId).update({'isArchived': false});
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Barang dikembalikan aktif.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_showArchived ? 'Arsip Barang' : 'Daftar Barang'), // Judul berubah
        backgroundColor: _showArchived ? Colors.grey[200] : Colors.white, // Warna AppBar berubah biar sadar mode
        elevation: 1,
        foregroundColor: Colors.black87,
        actions: [
          // Tombol Ganti Mode (Aktif <-> Arsip)
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            onSelected: (value) {
              setState(() {
                if (value == 'active') _showArchived = false;
                if (value == 'archived') _showArchived = true;
              });
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'active',
                child: Row(children: [Icon(Icons.check_circle_outline, color: Colors.green), SizedBox(width: 8), Text('Barang Aktif')]),
              ),
              const PopupMenuItem<String>(
                value: 'archived',
                child: Row(children: [Icon(Icons.archive_outlined, color: Colors.orange), SizedBox(width: 8), Text('Barang Diarsipkan')]),
              ),
            ],
          ),
        ],
      ),
      // Ubah background body jika mode arsip agar user sadar
      backgroundColor: _showArchived ? Colors.grey[100] : Colors.white, 
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Search Bar
            _buildSearchBar(),
            const SizedBox(height: 16),

            // Info Bar Kecil
            if (_showArchived) 
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(color: Colors.orange[50], borderRadius: BorderRadius.circular(8)),
                child: const Text('Sedang melihat barang yang diarsipkan.', textAlign: TextAlign.center, style: TextStyle(color: Colors.orange)),
              ),

            // Daftar Item
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _getItemsStream(),
                builder: (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
                  if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
                  if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                  
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(
                        child: Text(_showArchived 
                          ? 'Tidak ada barang di arsip.' 
                          : 'Belum ada barang aktif.'));
                  }

                  return ListView.builder(
                    itemCount: snapshot.data!.docs.length,
                    itemBuilder: (context, index) {
                      var doc = snapshot.data!.docs[index];
                      Item item = Item.fromFirestore(doc);
                      return _buildItemCard(item);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _showArchived 
        ? null // Hilangkan tombol tambah jika sedang di mode arsip
        : FloatingActionButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const TambahBarangPage()),
              );
            },
            child: const Icon(Icons.add),
            backgroundColor: const Color(0xFF4A4E9E), 
          ),
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      decoration: InputDecoration(
        hintText: 'Cari barang...',
        prefixIcon: const Icon(Icons.search),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[300]!)),
      ),
      onChanged: (value) => setState(() => _searchQuery = value),
    );
  }

  Widget _buildItemCard(Item item) {
    bool isMenipis = item.stok <= item.stokMinimum && item.stokMinimum > 0;
    
    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.white,
      // Jika arsip, buat agak transparan biar beda
      surfaceTintColor: _showArchived ? Colors.grey : Colors.white, 
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            Expanded(
              child: Opacity( // Buat teks agak pudar jika diarsipkan
                opacity: _showArchived ? 0.6 : 1.0,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.nama, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text('Stok: ${item.stok} ${item.satuan}', style: TextStyle(fontSize: 14, color: Colors.grey[700])),
                    const SizedBox(height: 4),
                    Text('Jual: ${formatRupiah.format(item.hargaJual)}', style: TextStyle(fontSize: 14, color: Colors.green[700], fontWeight: FontWeight.w500)),
                    
                    if (!_showArchived) ...[ // Hanya tampilkan label status jika bukan arsip
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: (isMenipis ? Colors.orange : Colors.green).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          isMenipis ? 'MENIPIS' : 'AMAN',
                          style: TextStyle(color: isMenipis ? Colors.orange : Colors.green, fontWeight: FontWeight.bold, fontSize: 10),
                        ),
                      ),
                    ]
                  ],
                ),
              ),
            ),
            
            // --- LOGIKA TOMBOL AKSI ---
            if (!_showArchived) ...[
              // MODE AKTIF: Tombol Edit & Arsip
              IconButton(
                icon: const Icon(Icons.edit_outlined, color: Colors.blue),
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => TambahBarangPage(item: item)));
                },
              ),
              IconButton(
                icon: const Icon(Icons.archive_outlined, color: Colors.orange),
                tooltip: 'Arsipkan',
                onPressed: () => _archiveItem(item.id),
              ),
            ] else ...[
              // MODE ARSIP: Tombol Restore (Kembalikan)
              IconButton(
                icon: const Icon(Icons.restore_from_trash, color: Colors.green),
                tooltip: 'Kembalikan Barang',
                onPressed: () => _restoreItem(item.id),
              ),
            ]
          ],
        ),
      ),
    );
  }
}