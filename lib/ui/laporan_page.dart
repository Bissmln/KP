// lib/ui/laporan_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math; // Penting untuk chart
import 'package:intl/date_symbol_data_local.dart'; // Penting untuk format tanggal Indo
import '../transaksi.dart';
import '../services/pdf_service.dart';
import '../services/excel_service.dart';

class LaporanPage extends StatefulWidget {
  const LaporanPage({Key? key}) : super(key: key);

  @override
  State<LaporanPage> createState() => _LaporanPageState();
}

class _LaporanPageState extends State<LaporanPage> {
  DateTime _selectedDate = DateTime.now();
  String _filterType = 'harian'; 
  final formatRupiah = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    // Pastikan locale ID siap saat halaman dibuka
    initializeDateFormatting('id_ID', null).then((_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: const Locale('id', 'ID'), // Paksa kalender bahasa Indonesia
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

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
    } else { 
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
        ],
      ),
      // --- PERUBAHAN UTAMA: SingleChildScrollView membungkus SEMUANYA ---
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(), // Efek membal saat scroll mentok
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // BAGIAN ATAS
            _buildDatePickerCard(),
            const SizedBox(height: 16),
            _buildFilterToggles(),
            const SizedBox(height: 24),
            _buildIncomeChartCard(),
            const SizedBox(height: 24),
            _buildExportButtons(),
            const SizedBox(height: 24),

            // BAGIAN BAWAH (LIST)
            _buildTransactionsListHeader(),
            const SizedBox(height: 16),
            // List ini sekarang ada di dalam scroll utama
            _buildTransactionsListStream(), 
            const SizedBox(height: 30), // Jarak ekstra di paling bawah
          ],
        ),
      ),
    );
  }

  Widget _buildDatePickerCard() {
    String dateString;
    try {
      dateString = DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(_selectedDate);
    } catch (e) {
      dateString = DateFormat('yyyy-MM-dd').format(_selectedDate);
    }

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey[200]!)),
      color: Colors.white,
      child: ListTile(
        leading: Icon(Icons.calendar_today_outlined, color: Theme.of(context).primaryColor),
        title: const Text('Pilih Tanggal', style: TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(dateString),
        trailing: Icon(Icons.edit_outlined, color: Colors.grey[600]),
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

  Widget _buildIncomeChartCard() {
    var range = _getDateRange();
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Penghasilan', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                _buildChartLegend(),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 200,
              child: StreamBuilder<QuerySnapshot>(
                stream: stream,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    String errorMsg = snapshot.error.toString();
                    if (errorMsg.contains('failed-precondition')) {
                       return Center(child: Text('Error: Perlu Indeks Firestore. Cek Terminal.', style: TextStyle(color: Colors.red[700], fontSize: 12)));
                    }
                    return Center(child: Text('Error memuat chart.', style: TextStyle(color: Colors.red[700])));
                  }
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(child: Text('Tidak ada data penjualan.'));
                  }
                  
                  Map<String, double> modalPerItem = {};
                  Map<String, double> labaPerItem = {};
                  double totalModal = 0;
                  double totalLaba = 0;

                  for (var doc in snapshot.data!.docs) {
                      var data = doc.data() as Map<String, dynamic>;
                      String nama = data['namaBarang'] ?? 'Lainnya';
                      double modal = (data['total_modal'] ?? 0).toDouble();
                      double laba = (data['total_laba'] ?? 0).toDouble();
                      
                      modalPerItem[nama] = (modalPerItem[nama] ?? 0) + modal;
                      labaPerItem[nama] = (labaPerItem[nama] ?? 0) + laba;

                      totalModal += modal;
                      totalLaba += laba;
                  }
                  
                  List<String> itemNames = modalPerItem.keys.toList();
                  
                  return Column(
                    children: [
                      Expanded(
                        child: BarChart(
                          BarChartData(
                            alignment: BarChartAlignment.spaceAround,
                            maxY: _calculateMaxY(modalPerItem, labaPerItem),
                            barGroups: List.generate(itemNames.length, (index) {
                              String nama = itemNames[index];
                              return BarChartGroupData(
                                x: index,
                                barRods: [
                                  BarChartRodData(toY: modalPerItem[nama]!, color: Colors.blueGrey, width: 15),
                                  BarChartRodData(toY: labaPerItem[nama]!, color: Colors.green, width: 15),
                                ],
                              );
                            }),
                            titlesData: FlTitlesData(
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  getTitlesWidget: (value, meta) {
                                    int index = value.toInt();
                                    if (index < 0 || index >= itemNames.length) return const SizedBox();
                                    // Menggunakan math.min agar tidak error index out of range
                                    return Text(itemNames[index].substring(0, math.min(5, itemNames[index].length)), style: const TextStyle(fontSize: 10));
                                  },
                                ),
                              ),
                              leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40)),
                              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Text("Modal: ${formatRupiah.format(totalModal)}", style: const TextStyle(color: Colors.blueGrey, fontWeight: FontWeight.bold)),
                          Text("Laba: ${formatRupiah.format(totalLaba)}", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                        ],
                      )
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  double _calculateMaxY(Map<String, double> modal, Map<String, double> laba) {
    double maxVal = 0;
    for (var val in modal.values) {
      if (val > maxVal) maxVal = val;
    }
    for (var val in laba.values) {
      if (val > maxVal) maxVal = val;
    }
    return maxVal == 0 ? 100 : maxVal * 1.2; 
  }
  
  Widget _buildChartLegend() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Row(children: [
          Container(width: 10, height: 10, color: Colors.blueGrey),
          const SizedBox(width: 4),
          const Text('Modal', style: TextStyle(fontSize: 12)),
        ]),
        const SizedBox(width: 8),
        Row(children: [
          Container(width: 10, height: 10, color: Colors.green),
          const SizedBox(width: 4),
          const Text('Laba', style: TextStyle(fontSize: 12)),
        ]),
      ],
    );
  }

  Widget _buildExportButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () async {
              _handleExport('pdf');
            },
            icon: const Icon(Icons.picture_as_pdf_outlined),
            label: const Text('Export PDF'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.red[700],
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey[300]!),
              ),
              elevation: 1,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () async {
              _handleExport('excel');
            },
            icon: const Icon(Icons.table_chart_outlined),
            label: const Text('Export Excel'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.green[700],
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey[300]!),
              ),
              elevation: 1,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _handleExport(String type) async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Sedang menyiapkan $type...')),
    );

    try {
      var range = _getDateRange();
      var snapshot = await FirebaseFirestore.instance
          .collection('transaksi')
          .where('timestamp', isGreaterThanOrEqualTo: range['start'])
          .where('timestamp', isLessThan: range['end'])
          .orderBy('timestamp', descending: true)
          .get(); 

      List<Transaksi> dataExport = snapshot.docs
          .map((doc) => Transaksi.fromFirestore(doc))
          .toList();

      if (dataExport.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tidak ada data untuk diexport.')),
        );
        return;
      }

      if (type == 'pdf') {
        final pdfService = PdfService();
        await pdfService.exportLaporan(dataExport, _selectedDate, _filterType);
      } else {
        final excelService = ExcelService();
        await excelService.exportLaporan(dataExport, _filterType);
      }

    } catch (e) {
      print(e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal export $type: $e')),
      );
    }
  }

  Widget _buildTransactionsListHeader() {
    var range = _getDateRange();
    
    String title = 'Riwayat Transaksi';
    try {
        if (_filterType == 'harian') {
          title = 'Transaksi ${DateFormat('d MMMM yyyy', 'id_ID').format(_selectedDate)}';
        } else if (_filterType == 'mingguan') {
          title = 'Transaksi Minggu Ini';
        } else {
          title = 'Transaksi Bulan Ini';
        }
    } catch (e) {
        title = 'Riwayat Transaksi';
    }

    var countStream = FirebaseFirestore.instance
        .collection('transaksi')
        .where('timestamp', isGreaterThanOrEqualTo: range['start'])
        .where('timestamp', isLessThan: range['end'])
        .snapshots();

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        StreamBuilder<QuerySnapshot>(
          stream: countStream,
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const SizedBox();
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${snapshot.data!.docs.length}', 
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[700]),
              ),
            );
          }
        ),
      ],
    );
  }

  // --- PENTING: WIDGET LISTVIEW DIUBAH AGAR BISA SCROLL ---
  Widget _buildTransactionsListStream() {
    var range = _getDateRange();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('transaksi')
          .where('timestamp', isGreaterThanOrEqualTo: range['start'])
          .where('timestamp', isLessThan: range['end'])
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
           String errorMsg = snapshot.error.toString();
           if (errorMsg.contains('failed-precondition')) {
               return Center(child: Text('Error: Perlu Indeks Firestore. Cek Terminal.', style: TextStyle(color: Colors.red[700])));
           }
          return Center(child: Text('Error: ${snapshot.error}', style: TextStyle(color: Colors.red[700])));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Text(
              'Belum ada transaksi pada periode ini.',
              style: const TextStyle(color: Colors.grey),
            ),
          );
        }

        // MENGGUNAKAN SHRINKWRAP DAN NEVER SCROLLABLE
        return ListView.builder(
          shrinkWrap: true, // Penting! Agar tinggi list menyesuaikan isi
          physics: const NeverScrollableScrollPhysics(), // Penting! Agar scroll ikut induk (SingleChildScrollView)
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            var doc = snapshot.data!.docs[index];
            Transaksi trx = Transaksi.fromFirestore(doc);
            return _buildRecentTrxCard(trx);
          },
        );
      },
    );
  }

  Widget _buildRecentTrxCard(Transaksi trx) {
    bool isMasuk = trx.tipe == 'masuk';
    Color color = isMasuk ? Colors.green : Colors.red;
    IconData icon = isMasuk ? Icons.arrow_downward : Icons.arrow_upward;
    String status = isMasuk ? 'MASUK' : 'KELUAR';
    
    String title = trx.namaBarang;
    String detail = isMasuk
        ? '${trx.jumlah} ${trx.satuan} • Pengirim: ${trx.pengirim}'
        : '${trx.jumlah} ${trx.satuan} • Petugas: ${trx.petugas}';
    
    String formattedDate = '';
    try {
        formattedDate = DateFormat('dd/MM/yyyy HH:mm', 'id_ID').format(trx.timestamp.toDate());
    } catch (e) {
        formattedDate = trx.timestamp.toDate().toString();
    }

    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 10),
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: Colors.grey[200]!)),
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