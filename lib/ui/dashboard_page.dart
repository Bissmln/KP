// lib/ui/dashboard_page.dart
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; 
import 'daftar_barang_page.dart'; 
import 'daftar_transaksi_page.dart';
import 'laporan_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({Key? key}) : super(key: key);

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  // Daftar warna untuk kategori
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

  // Fungsi untuk memproses data dari Firestore
  Map<String, dynamic> _prosesDataSnapshot(List<QueryDocumentSnapshot> docs) {
    Map<String, double> dataKategori = {};
    Map<String, Color> warnaKategori = {};

    for (var doc in docs) {
      var data = doc.data() as Map<String, dynamic>;
      String kategori = data['kategori'] ?? 'Lainnya';
      if (kategori.isEmpty) {
        kategori = 'Lainnya';
      }
      
      num stok = data['stok_awal'] ?? 0;

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
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Text(
                  'INVENTORY BARANG',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // KARTU PIE CHART DIBUNGKUS STREAMBUILDER
              _buildChartStream(),

              const SizedBox(height: 30),
              Text(
                'Menu Utama',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              const SizedBox(height: 16),
              _buildMenuGrid(),
              const SizedBox(height: 30),
              _buildLogoutButton(),
            ],
          ),
        ),
      ),
    );
  }

  // Widget baru untuk StreamBuilder Pie Chart
  Widget _buildChartStream() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('barang').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingChartCard();
        }
        if (snapshot.hasError) {
          return const Center(child: Text('Error memuat data chart'));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildChartCard({}, {});
        }

        var processedData = _prosesDataSnapshot(snapshot.data!.docs);
        Map<String, double> dataKategori = processedData['data'];
        Map<String, Color> warnaKategori = processedData['warna'];

        return _buildChartCard(dataKategori, warnaKategori);
      },
    );
  }
  
  // Widget untuk tampilan loading chart
  Widget _buildLoadingChartCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                child: CircularProgressIndicator(),
              ),
            ),
            const Text('Memuat data...', style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  // Widget kartu Pie Chart
  Widget _buildChartCard(
      Map<String, double> dataKategori, Map<String, Color> warnaKategori) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                  height: 150,
                  child: PieChart(
                    PieChartData(
                      sections: _generateChartSections(dataKategori, warnaKategori),
                      borderData: FlBorderData(show: false),
                      sectionsSpace: 2,
                      centerSpaceRadius: 40,
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

  // Fungsi untuk membuat section PieChart secara dinamis
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

  // Fungsi untuk membuat Legend secara dinamis
  Widget _buildDynamicLegend(
      Map<String, double> dataKategori, Map<String, Color> warnaKategori) {
    if (dataKategori.isEmpty) {
      return const Text('Belum ada data barang.', style: TextStyle(color: Colors.grey));
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

  // --- FUNGSI MENU GRID YANG DIPERBARUI SESUAI GAMBAR ---
  Widget _buildMenuGrid() {
    return Column(
      children: [
        // 1. Kartu Transaksi (lebar penuh)
        _buildMenuCard(
          icon: Icons.sync_alt_rounded,
          iconColor: const Color(0xFFE91E63), // Pink
          iconBackgroundColor: const Color(0xFFFCE4EC), // Pink light
          title: 'Transaksi',
          subtitle: 'Barang Masuk & Keluar',
          onTap: () {
            print('KARTU TRANSAKSI DIKLIK!');
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const DaftarTransaksiPage()),
            );
          },
        ),

        const SizedBox(height: 16),

        // 2. Baris untuk Laporan dan Data Barang
        Row(
          children: [
            // Kartu Laporan (Setengah lebar)
            Expanded(
              child: _buildMenuCard(
                icon: Icons.description_outlined,
                iconColor: const Color(0xFF4CAF50), // Green
                iconBackgroundColor: const Color(0xFFE8F5E9), // Green light
                title: 'Laporan',
                subtitle: 'Lihat Laporan Stok Barang',
                onTap: () {
                  print('CARD LAPORAN DIKLIK!');
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const LaporanPage()),
                  );
                },
              ),
            ),
            
            const SizedBox(width: 16),

            // Kartu Data Barang (Setengah lebar)
            Expanded(
              child: _buildMenuCard(
                icon: Icons.inventory_2_outlined,
                iconColor: const Color(0xFF2196F3), // Blue
                iconBackgroundColor: const Color(0xFFE3F2FD), // Blue light
                title: 'Data Barang',
                subtitle: 'Tambah, Edit, Hapus Barang',
                onTap: () {
                  print('KARTU DATA BARANG DIKLIK!');
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const DaftarBarangPage()),
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
  
  // Widget untuk membuat kartu menu yang diperbarui
  Widget _buildMenuCard({
    required IconData icon,
    required Color iconColor,
    required Color iconBackgroundColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 1,
      shadowColor: Colors.black.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.grey[200]!, width: 1),
      ),
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon dengan background circular
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: iconBackgroundColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon, 
                  color: iconColor, 
                  size: 28,
                ),
              ),
              const SizedBox(height: 16),
              // Title
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
              // Subtitle
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogoutButton() {
    return ElevatedButton(
      onPressed: () {},
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