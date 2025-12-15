// lib/ui/dashboard_page.dart
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'package:flutter/services.dart'; // Untuk SystemNavigator.pop()

// Pastikan Anda juga sudah punya file-file ini di folder /ui:
import 'daftar_barang_page.dart';
import 'daftar_transaksi_page.dart';
import 'laporan_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({Key? key}) : super(key: key);

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  // Daftar warna untuk palet chart
  final List<Color> colorPalette = [
    Colors.blue,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.red,
    Colors.teal,
    Colors.pink,
    Colors.amber,
  ];

  // Fungsi untuk memproses data dari Firestore untuk chart
  Map<String, dynamic> _prosesDataSnapshot(List<QueryDocumentSnapshot> docs) {
    Map<String, double> dataKategori = {};
    Map<String, Color> warnaKategori = {};

    for (var doc in docs) {
      var data = doc.data() as Map<String, dynamic>;
      String kategori = data['kategori'] ?? 'Lainnya';
      if (kategori.isEmpty) {
        kategori = 'Lainnya';
      }
      num stok = data['stok'] ?? 0;
      dataKategori[kategori] = (dataKategori[kategori] ?? 0) + stok.toDouble();
      if (!warnaKategori.containsKey(kategori)) {
        warnaKategori[kategori] =
            colorPalette[warnaKategori.length % colorPalette.length];
      }
    }
    return {'data': dataKategori, 'warna': warnaKategori};
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFF4A4E9E); // Warna ungu utama

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'INVENTORY BARANG',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        backgroundColor: primaryColor,
        centerTitle: true,
        elevation: 0,
        automaticallyImplyLeading: false, // Hilangkan tombol back di AppBar
      ),
      body: SafeArea(
        // 1. Body utama menggunakan Column agar bisa dibagi jadi 2 bagian
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 2. BAGIAN KONTEN (SCROLLABLE)
            Expanded(
              // Expanded mengisi semua ruang yang tersisa
              child: SingleChildScrollView(
                // Konten ini sekarang bisa di-scroll jika layarnya pendek
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildChartStream(),
                    const SizedBox(height: 24),
                    Text(
                      'Menu Utama',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildMenuGrid(),
                    const SizedBox(height: 20), // Spasi di akhir area scroll
                  ],
                ),
              ),
            ),

            // 3. BAGIAN TOMBOL (STATIS/TIDAK SCROLL)
            // Tombol ini ada di luar Expanded, jadi akan menempel di bawah
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: _buildLogoutButton(),
            ),
          ],
        ),
      ),
    );
  }

  // Widget untuk StreamBuilder Pie Chart
  Widget _buildChartStream() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('barang').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingChartCard(); // Tampilan loading
        }
        if (snapshot.hasError) {
          return const Center(child: Text('Error memuat data chart'));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildChartCard({}, {}); // Tampilan data kosong
        }

        // Proses data jika berhasil didapat
        var processedData = _prosesDataSnapshot(snapshot.data!.docs);
        Map<String, double> dataKategori = processedData['data'];
        Map<String, Color> warnaKategori = processedData['warna'];

        return _buildChartCard(dataKategori, warnaKategori);
      },
    );
  }

  // Tampilan kartu loading
  Widget _buildLoadingChartCard() {
    return Card(
      elevation: 1,
      shadowColor: Colors.black.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey[200]!, width: 1),
      ),
      color: Colors.white,
      child: Container(
        height: 250,
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Stok per Kategori',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const Expanded(
              child: Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF4A4E9E),
                ),
              ),
            ),
            const Text('Memuat data...', style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  // Tampilan kartu Pie Chart setelah data dimuat
  Widget _buildChartCard(
      Map<String, double> dataKategori, Map<String, Color> warnaKategori) {
    return Card(
      elevation: 1,
      shadowColor: Colors.black.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey[200]!, width: 1),
      ),
      color: Colors.white,
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Stok per Kategori',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 150, // Tinggi Pie Chart
                  child: PieChart(
                    PieChartData(
                      sections:
                          _generateChartSections(dataKategori, warnaKategori),
                      borderData: FlBorderData(show: false),
                      sectionsSpace: 2,
                      centerSpaceRadius: 40, // Ukuran lubang tengah
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                _buildDynamicLegend(dataKategori, warnaKategori),
              ],
            ),
          ),
          Positioned(
            top: 16,
            right: 16,
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                border: Border.all(color: Colors.grey[300]!, width: 2),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Fungsi untuk generate bagian-bagian Pie Chart
  List<PieChartSectionData> _generateChartSections(
      Map<String, double> dataKategori, Map<String, Color> warnaKategori) {
    if (dataKategori.isEmpty) {
      return [
        PieChartSectionData(
          color: Colors.grey[300],
          value: 1,
          title: '',
          radius: 30,
        )
      ];
    }
    return dataKategori.entries.map((entry) {
      return PieChartSectionData(
        color: warnaKategori[entry.key] ?? Colors.grey,
        value: entry.value,
        title: '',
        radius: 30,
      );
    }).toList();
  }

  // Fungsi untuk generate legenda di bawah Pie Chart
  Widget _buildDynamicLegend(
      Map<String, double> dataKategori, Map<String, Color> warnaKategori) {
    if (dataKategori.isEmpty) {
      return const Text('Belum ada data barang.',
          style: TextStyle(color: Colors.grey));
    }
    return Wrap(
      spacing: 16.0,
      runSpacing: 8.0,
      children: dataKategori.entries.map((entry) {
        return _buildLegendItem(
          warnaKategori[entry.key] ?? Colors.grey,
          '${entry.key} (${entry.value.toInt()})',
        );
      }).toList(),
    );
  }

  // Tampilan satu item legenda
  Widget _buildLegendItem(Color color, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, color: color),
        const SizedBox(width: 6),
        Text(text, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
      ],
    );
  }

  // Tampilan grid menu
   Widget _buildMenuGrid() {
    return Column(
      children: [
        _buildMenuCard(
          icon: Icons.swap_horiz,
          iconColor: const Color(0xFFE91E63),
          iconBackgroundColor: const Color(0xFFF5F5F5),
          title: 'Transaksi',
          subtitle: 'Barang Masuk & Keluar',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const DaftarTransaksiPage(),
              ),
            );
          },
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: _buildMenuCard(
                icon: Icons.description,
                iconColor: const Color(0xFF4CAF50),
                iconBackgroundColor: const Color(0xFFF5F5F5),
                title: 'Laporan',
                subtitle: 'Lihat Laporan Stok Barang',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const LaporanPage(),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildMenuCard(
                icon: Icons.inventory_2,
                iconColor: const Color(0xFF2196F3),
                iconBackgroundColor: const Color(0xFFF5F5F5),
                title: 'Data Barang',
                subtitle: 'Tambah, Edit, Hapus Barang',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const DaftarBarangPage(),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMenuCard({
    required IconData icon,
    required Color iconColor,
    required Color iconBackgroundColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 18,
            offset: const Offset(0, 10),
            spreadRadius: 1,
          ),
        ],
      ),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(28),
          child: Container(
            width: double.infinity,
            padding:
                const EdgeInsets.symmetric(horizontal: 24.0, vertical: 30.0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: iconBackgroundColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Icon(
                    icon,
                    color: iconColor,
                    size: 30,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Tombol Keluar
  Widget _buildLogoutButton() {
    return ElevatedButton(
      onPressed: () {
        // Fungsi untuk keluar dari aplikasi
        SystemNavigator.pop();
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF4A4E9E),
        padding: const EdgeInsets.symmetric(vertical: 14),
        minimumSize: const Size(double.infinity, 50),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 0,
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Keluar',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(width: 8),
          Icon(
            Icons.logout,
            color: Colors.white,
            size: 20,
          ),
        ],
      ),
    );
  }
}