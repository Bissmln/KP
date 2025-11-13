// lib/ui/laporan_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

class LaporanPage extends StatefulWidget {
  const LaporanPage({Key? key}) : super(key: key);

  @override
  State<LaporanPage> createState() => _LaporanPageState();
}

class _LaporanPageState extends State<LaporanPage> {
  DateTime _selectedDate = DateTime.now();
  String _filterType = 'harian'; // 'harian', 'mingguan', 'bulanan'

  // Fungsi untuk menampilkan date picker
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  // Fungsi untuk mendapatkan rentang tanggal berdasarkan filter
  Map<String, DateTime> _getDateRange() {
    DateTime now = _selectedDate;
    DateTime start;
    DateTime end;

    if (_filterType == 'harian') {
      start = DateTime(now.year, now.month, now.day);
      end = start.add(const Duration(days: 1));
    } else if (_filterType == 'mingguan') {
      start = now.subtract(Duration(days: now.weekday - 1));
      start = DateTime(start.year, start.month, start.day);
      end = start.add(const Duration(days: 7));
    } else { // bulanan
      start = DateTime(now.year, now.month, 1);
      end = DateTime(now.year, now.month + 1, 1);
    }
    return {'start': start, 'end': end};
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Laporan'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(onPressed: () => setState(() {}), icon: const Icon(Icons.refresh)),
          IconButton(onPressed: () {}, icon: const Icon(Icons.settings_outlined)),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Date Picker
            _buildDatePickerCard(),
            const SizedBox(height: 16),
            
            // 2. Filter Toggles
            _buildFilterToggles(),
            const SizedBox(height: 24),

            // 3. Line Chart
            _buildLineChartCard(),
            const SizedBox(height: 24),
            
            // 4. Barang Paling Laku
            _buildTopSoldCard(),
            
            // --- TAMBAHAN BARU ---
            const SizedBox(height: 24),
            _buildTransactionsForDate(), // 5. Daftar Transaksi
            // --- AKHIR TAMBAHAN ---
          ],
        ),
      ),
    );
  }

  Widget _buildDatePickerCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.white,
      child: ListTile(
        leading: Icon(Icons.calendar_today_outlined, color: Theme.of(context).primaryColor),
        title: const Text('Pilih Tanggal', style: TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(DateFormat('EEEE, d MMMM yyyy').format(_selectedDate)),
        trailing: const Icon(Icons.edit_outlined),
        onTap: () => _selectDate(context),
      ),
    );
  }

  Widget _buildFilterToggles() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        FilterChip(
          label: const Text('Harian'),
          selected: _filterType == 'harian',
          onSelected: (selected) {
            if (selected) setState(() => _filterType = 'harian');
          },
          selectedColor: Theme.of(context).primaryColor,
          labelStyle: TextStyle(
              color: _filterType == 'harian' ? Colors.white : Colors.black),
          checkmarkColor: Colors.white,
        ),
        FilterChip(
          label: const Text('Mingguan'),
          selected: _filterType == 'mingguan',
          onSelected: (selected) {
            if (selected) setState(() => _filterType = 'mingguan');
          },
          selectedColor: Theme.of(context).primaryColor,
          labelStyle: TextStyle(
              color: _filterType == 'mingguan' ? Colors.white : Colors.black),
          checkmarkColor: Colors.white,
        ),
        FilterChip(
          label: const Text('Bulanan'),
          selected: _filterType == 'bulanan',
          onSelected: (selected) {
            if (selected) setState(() => _filterType = 'bulanan');
          },
          selectedColor: Theme.of(context).primaryColor,
          labelStyle: TextStyle(
              color: _filterType == 'bulanan' ? Colors.white : Colors.black),
          checkmarkColor: Colors.white,
        ),
      ],
    );
  }

  // --- CARD UNTUK LINE CHART (TREND STOK) ---
  Widget _buildLineChartCard() {
    var range = _getDateRange();
    // ⚠️ PERINGATAN: Kueri ini mungkin memerlukan indeks komposit di Firestore
    // (timestamp DESC, tipe ASC)
    var stream = FirebaseFirestore.instance
        .collection('transaksi')
        .where('timestamp', isGreaterThanOrEqualTo: range['start'])
        .where('timestamp', isLessThan: range['end'])
        .orderBy('timestamp', descending: true)
        .snapshots();
        
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Trend Stok', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            SizedBox(
              height: 200,
              child: StreamBuilder<QuerySnapshot>(
                stream: stream,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  
                  // Proses data untuk chart
                  List<FlSpot> dataMasuk = [];
                  List<FlSpot> dataKeluar = [];
                  
                  // Agregasi data (sederhana, berdasarkan jumlah transaksi)
                  // Untuk 'harian', X = jam. Untuk 'mingguan', X = hari.
                  for (var doc in snapshot.data!.docs) {
                      var data = doc.data() as Map<String, dynamic>;
                      var timestamp = (data['timestamp'] as Timestamp).toDate();
                      double xValue = _filterType == 'harian' 
                          ? timestamp.hour.toDouble() 
                          : timestamp.day.toDouble();
                      double yValue = (data['jumlah'] ?? 0).toDouble();

                      if (data['tipe'] == 'masuk') {
                        dataMasuk.add(FlSpot(xValue, yValue));
                      } else {
                        dataKeluar.add(FlSpot(xValue, yValue));
                      }
                  }

                  if (dataMasuk.isEmpty && dataKeluar.isEmpty) {
                    return const Center(child: Text('Tidak ada data transaksi pada periode ini.'));
                  }

                  return LineChart(
                    LineChartData(
                      gridData: FlGridData(show: true, drawVerticalLine: true, verticalInterval: _filterType == 'harian' ? 4 : 1),
                      titlesData: FlTitlesData(
                        show: true,
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 30, interval: _filterType == 'harian' ? 6 : 5)),
                      ),
                      borderData: FlBorderData(show: true, border: Border.all(color: const Color(0xffe7e7e7))),
                      lineBarsData: [
                        _buildLineData(dataMasuk, Colors.green),
                        _buildLineData(dataKeluar, Colors.red),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            _buildChartLegend()
          ],
        ),
      ),
    );
  }
  
  // Helper untuk Line Chart
  LineChartBarData _buildLineData(List<FlSpot> spots, Color color) {
    return LineChartBarData(
      spots: spots,
      isCurved: true,
      color: color,
      barWidth: 4,
      isStrokeCapRound: true,
      dotData: const FlDotData(show: false),
      belowBarData: BarAreaData(show: true, color: color.withOpacity(0.1)),
    );
  }

  // Helper untuk Legend Line Chart
  Widget _buildChartLegend() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(children: [
          Container(width: 12, height: 12, color: Colors.green),
          const SizedBox(width: 4),
          const Text('Barang Masuk'),
        ]),
        const SizedBox(width: 16),
        Row(children: [
          Container(width: 12, height: 12, color: Colors.red),
          const SizedBox(width: 4),
          const Text('Barang Keluar'),
        ]),
      ],
    );
  }

  // --- CARD UNTUK BARANG PALING LAKU ---
  Widget _buildTopSoldCard() {
    var range = _getDateRange();
    // ⚠️ PERINGATAN: Kueri ini PASTI memerlukan indeks komposit di Firestore
    // (tipe ASC, timestamp DESC)
    var stream = FirebaseFirestore.instance
        .collection('transaksi')
        .where('tipe', isEqualTo: 'keluar')
        .where('timestamp', isGreaterThanOrEqualTo: range['start'])
        .where('timestamp', isLessThan: range['end'])
        .orderBy('timestamp', descending: true)
        .snapshots();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Barang Paling Laku (${_filterType.capitalize()})',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            StreamBuilder<QuerySnapshot>(
              stream: stream,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('Tidak ada barang keluar pada periode ini.'));
                }
                
                // Proses data
                Map<String, int> soldCounts = {};
                for (var doc in snapshot.data!.docs) {
                  var data = doc.data() as Map<String, dynamic>;
                  String nama = data['namaBarang'] ?? 'Error';
                  int jumlah = (data['jumlah'] ?? 0).toInt();
                  soldCounts[nama] = (soldCounts[nama] ?? 0) + jumlah;
                }
                
                // Urutkan map
                var sortedItems = soldCounts.entries.toList()
                  ..sort((a, b) => b.value.compareTo(a.value));
                  
                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: sortedItems.length > 5 ? 5 : sortedItems.length, // Tampilkan top 5
                  itemBuilder: (context, index) {
                    var item = sortedItems[index];
                    return ListTile(
                      dense: true,
                      leading: Text(
                        '${index + 1}.',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      title: Text(item.key, style: const TextStyle(fontWeight: FontWeight.w500)),
                      trailing: Text(
                        '${item.value} unit',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // --- [TAMBAHAN BARU] ---
  // Widget untuk menampilkan daftar transaksi berdasarkan tanggal
  Widget _buildTransactionsForDate() {
    // Tentukan rentang tanggal
    DateTime selected = _selectedDate;
    DateTime dateStart = DateTime(selected.year, selected.month, selected.day);
    DateTime dateEnd = dateStart.add(const Duration(days: 1));
    
    // Cek apakah tanggal yang dipilih adalah hari ini
    bool isToday = DateFormat('d MMMM yyyy').format(selected) == 
                   DateFormat('d MMMM yyyy').format(DateTime.now());
                   
    String title = isToday 
        ? 'Transaksi Hari Ini' 
        : 'Transaksi ${DateFormat('d MMMM yyyy').format(selected)}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Judul dinamis
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        const SizedBox(height: 16),
        
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('transaksi')
              .where('timestamp', isGreaterThanOrEqualTo: dateStart)
              .where('timestamp', isLessThan: dateEnd)
              .orderBy('timestamp', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Center(
                child: Text(
                  'Belum ada transaksi pada tanggal ini.',
                  style: const TextStyle(color: Colors.grey),
                ),
              );
            }

            // Buat daftar card
            return ListView.builder(
              itemCount: snapshot.data!.docs.length,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemBuilder: (context, index) {
                var doc = snapshot.data!.docs[index];
                var data = doc.data() as Map<String, dynamic>;
                return _buildRecentTrxCard(data);
              },
            );
          },
        ),
      ],
    );
  }

  // Card untuk satu transaksi (gaya dari Gambar 1)
  Widget _buildRecentTrxCard(Map<String, dynamic> data) {
    bool isMasuk = data['tipe'] == 'masuk';
    Color color = isMasuk ? Colors.green : Colors.red;
    IconData icon = isMasuk ? Icons.arrow_downward : Icons.arrow_upward;
    String status = isMasuk ? 'MASUK' : 'KELUAR';
    
    String title = data['namaBarang'] ?? 'Nama Barang Error';
    String detail = isMasuk
        ? '${data['jumlah']} unit • Pengirim: ${data['pengirim']}'
        : '${data['jumlah']} unit • Petugas: ${data['petugas']}';
    
    Timestamp timestamp = data['timestamp'] ?? Timestamp.now();
    String formattedDate = DateFormat('dd/MM/yyyy HH:mm').format(timestamp.toDate());

    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 10),
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    detail,
                    style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    formattedDate,
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              status,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Helper kecil untuk 'harian'.capitalize()
extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}