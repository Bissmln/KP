import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
// 1. IMPORT WAJIB UNTUK FORMAT TANGGAL INDONESIA
import 'package:intl/date_symbol_data_local.dart'; 
import '../transaksi.dart'; 

class PdfService {
  // Fungsi utama untuk membuat dan membagikan PDF
  Future<void> exportLaporan(List<Transaksi> dataTransaksi, DateTime tanggal, String tipeFilter) async {
    
    // Ini menjamin data bahasa 'id_ID' siap sebelum DateFormat dipanggil
    await initializeDateFormatting('id_ID', null);

    final pdf = pw.Document();
    final formatRupiah = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    
    // Gunakan locale 'id_ID' secara eksplisit
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm', 'id_ID'); 

    // 3. Tentukan Judul Laporan (Konsisten pakai id_ID)
    String judulPeriode = '';
    if (tipeFilter == 'harian') {
      judulPeriode = DateFormat('d MMMM yyyy', 'id_ID').format(tanggal);
    } else if (tipeFilter == 'mingguan') {
      // Format tanggal untuk mingguan
      judulPeriode = 'Mingguan (Mulai ${DateFormat('d MMM yyyy', 'id_ID').format(tanggal)})';
    } else {
      // Format tanggal untuk bulanan
      judulPeriode = DateFormat('MMMM yyyy', 'id_ID').format(tanggal);
    }

    // Hitung Ringkasan Data
    num totalMasuk = 0;
    num totalKeluar = 0;
    num totalModal = 0;
    num totalLaba = 0;

    for (var trx in dataTransaksi) {
      if (trx.tipe == 'masuk') {
        totalMasuk++;
      } else {
        totalKeluar++;
        totalModal += trx.totalModal;
        totalLaba += trx.totalLaba;
      }
    }

    // Desain Halaman PDF
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            // HEADER
            pw.Header(
              level: 0,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Laporan Inventaris & Keuangan', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 4),
                  pw.Text('Periode: $judulPeriode', style: const pw.TextStyle(fontSize: 12)),
                  pw.Divider(),
                ],
              ),
            ),
            
            pw.SizedBox(height: 10),

            // KOTAK RINGKASAN
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey400),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  _buildSummaryItem('Trx Masuk', '$totalMasuk', pdf),
                  _buildSummaryItem('Trx Keluar', '$totalKeluar', pdf),
                  _buildSummaryItem('Total Modal', formatRupiah.format(totalModal), pdf),
                  _buildSummaryItem('Total Laba', formatRupiah.format(totalLaba), pdf, isGreen: true),
                ],
              ),
            ),
            
            pw.SizedBox(height: 20),
            pw.Text('Rincian Transaksi', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),

            // TABEL DATA
            pw.TableHelper.fromTextArray(
              headers: ['Waktu', 'Tipe', 'Barang', 'Jml', 'Ket', 'Modal', 'Laba'],
              data: dataTransaksi.map((trx) {
                final isMasuk = trx.tipe == 'masuk';
                return [
                  dateFormat.format(trx.timestamp.toDate()),
                  isMasuk ? 'Masuk' : 'Keluar',
                  trx.namaBarang,
                  '${trx.jumlah} ${trx.satuan}',
                  isMasuk ? (trx.pengirim ?? '-') : (trx.tujuan ?? '-'),
                  isMasuk ? '-' : formatRupiah.format(trx.totalModal),
                  isMasuk ? '-' : formatRupiah.format(trx.totalLaba),
                ];
              }).toList(),
              headerStyle: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey),
              rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(width: 0.5, color: PdfColors.grey300))),
              cellAlignment: pw.Alignment.centerLeft,
              cellAlignments: {
                3: pw.Alignment.centerRight, // Jumlah rata kanan
                5: pw.Alignment.centerRight, // Modal rata kanan
                6: pw.Alignment.centerRight, // Laba rata kanan
              },
              cellStyle: const pw.TextStyle(fontSize: 9),
            ),
          ];
        },
      ),
    );

    // Tampilkan Preview / Print / Share
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Laporan_$tipeFilter.pdf',
    );
  }

  // Helper Widget untuk PDF
  pw.Widget _buildSummaryItem(String label, String value, pw.Document pdf, {bool isGreen = false}) {
    return pw.Column(
      children: [
        pw.Text(label, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
        pw.Text(value, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: isGreen ? PdfColors.green700 : PdfColors.black)),
      ],
    );
  }
}