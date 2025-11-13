// lib/ui/daftar_barang_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'tambah_barang_page.dart'; // Halaman form
import '../item.dart'; // Model data

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
  
  // Fungsi untuk membangun stream berdasarkan filter
  Stream<QuerySnapshot> _getItemsStream() {
    // Mulai dengan kueri dasar
    Query query = FirebaseFirestore.instance.collection('barang');
    
    // Terapkan filter pencarian jika ada
    if (_searchQuery.isNotEmpty) {
      // Ini adalah filter sederhana "starts with".
      // Untuk "contains", Anda perlu solusi pihak ketiga seperti Algolia.
      query = query
        .where('nama', isGreaterThanOrEqualTo: _searchQuery)
        .where('nama', isLessThanOrEqualTo: '$_searchQuery\uf8ff');
    }
    
    // Terapkan sorting
    query = query.orderBy('nama', descending: !_isAscending);
    
    return query.snapshots();
  }


  // Fungsi untuk menampilkan dialog konfirmasi hapus
  Future<void> _deleteItem(String docId) async {
    bool? confirmDelete = await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Konfirmasi Hapus'),
          content: const Text('Apakah Anda yakin ingin menghapus barang ini?'),
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
        await FirebaseFirestore.instance.collection('barang').doc(docId).delete();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Barang berhasil dihapus')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menghapus barang: $e')),
        );
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Daftar Barang'),
        backgroundColor: Colors.white,
        elevation: 1,
        foregroundColor: Colors.black87,
        actions: [
          IconButton(
            icon: const Icon(Icons.file_upload_outlined),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                // Ini akan memuat ulang stream
              });
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Search Bar
            _buildSearchBar(),
            const SizedBox(height: 16),
            
            // Filter Chips (StreamBuilder untuk data dinamis)
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('barang').snapshots(),
              builder: (context, snapshot) {
                int total = 0;
                int displayed = 0;
                
                if (snapshot.hasData) {
                  total = snapshot.data!.docs.length;
                  // Logika 'displayed' akan sama dengan 'total'
                  // kecuali Anda menambahkan logika filter yang lebih kompleks
                  displayed = snapshot.data!.docs.length;
                }
                
                return _buildFilterRow(total, displayed);
              }
            ),
            
            const SizedBox(height: 16),
            
            // Daftar Item
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _getItemsStream(), // Gunakan stream yang sudah difilter
                builder: (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
                  if (snapshot.hasError) {
                    return Center(child: Text('Terjadi kesalahan: ${snapshot.error}'));
                  }
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.data!.docs.isEmpty) {
                    return Center(
                        child: Text(_searchQuery.isEmpty 
                          ? 'Belum ada barang. Tekan + untuk menambah.'
                          : 'Barang tidak ditemukan.'));
                  }

                  // Tampilkan daftar menggunakan ListView.builder
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
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Navigasi ke Halaman Tambah Barang
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const TambahBarangPage()),
          );
        },
        child: const Icon(Icons.add),
        backgroundColor: const Color(0xFF4A4E9E), // Warna ungu
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
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
      ),
      onChanged: (value) {
        setState(() {
          _searchQuery = value;
        });
      },
    );
  }

  Widget _buildFilterRow(int total, int displayed) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildFilterChip('Total: $total barang', active: true),
        _buildFilterChip('Ditampilkan: $displayed', active: false),
        // Tombol sorting
        InkWell(
          onTap: () {
            setState(() {
              _isAscending = !_isAscending;
            });
          },
          child: _buildFilterChip(
              _isAscending ? '↑ A-Z' : '↓ Z-A', 
              active: false
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, {bool active = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: active ? Colors.purple.withOpacity(0.1) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: active ? Colors.purple : Colors.grey[300]!,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: active ? Colors.purple : Colors.grey[700],
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildItemCard(Item item) {
    // Tentukan status berdasarkan stok
    bool isMenipis = item.stokAwal <= item.stokMinimum && item.stokMinimum > 0;
    String statusLabel = isMenipis ? 'MENIPIS' : 'AMAN';
    Color statusColor = isMenipis ? Colors.orange : Colors.green;

    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.nama,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        '${item.stokAwal} ${item.satuan}',
                        style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          statusLabel,
                          style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.edit_outlined, color: Colors.blue),
              onPressed: () {
                // Aksi Edit: Buka TambahBarangPage dengan data item
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => TambahBarangPage(item: item)),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: () {
                // Panggil fungsi hapus
                _deleteItem(item.id);
              },
            ),
          ],
        ),
      ),
    );
  }
}