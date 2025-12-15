import 'dart:io';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import '../transaksi.dart'; 

class ExcelService {
  Future<void> exportLaporan(List<Transaksi> dataTransaksi, String tipeFilter) async {
    // Buat Workbook Excel Baru
    var excel = Excel.createExcel();
    
    // Hapus sheet default 'Sheet1' dan buat sheet baru
    String sheetName = 'Laporan Keuangan';
    Sheet sheetObject = excel[sheetName];
    excel.delete('Sheet1');

    // Buat Header (Judul Kolom)
    CellStyle headerStyle = CellStyle(
      bold: true, 
      horizontalAlign: HorizontalAlign.Center,
      backgroundColorHex: ExcelColor.fromHexString('#CCCCCC'),
    );

    List<String> headers = [
      'Tanggal', 
      'Jam', 
      'Tipe', 
      'Nama Barang', 
      'Jumlah', 
      'Satuan', 
      'Keterangan (Asal/Tujuan)', 
      'Total Modal', 
      'Total Laba'
    ];

    sheetObject.appendRow(headers.map((e) => TextCellValue(e)).toList());

    // 3. Isi Data Baris demi Baris
    final dateFormat = DateFormat('dd/MM/yyyy');
    final timeFormat = DateFormat('HH:mm');

    for (var trx in dataTransaksi) {
      bool isMasuk = trx.tipe == 'masuk';
      
      List<CellValue> rowData = [
        TextCellValue(dateFormat.format(trx.timestamp.toDate())), // Tanggal
        TextCellValue(timeFormat.format(trx.timestamp.toDate())), // Jam
        TextCellValue(isMasuk ? 'Masuk' : 'Keluar'),              // Tipe
        TextCellValue(trx.namaBarang),                            // Barang
        IntCellValue(trx.jumlah),                                 // Jumlah (Angka)
        TextCellValue(trx.satuan),                                // Satuan
        TextCellValue(isMasuk ? (trx.pengirim ?? '-') : (trx.tujuan ?? '-')), // Ket
        IntCellValue(isMasuk ? 0 : trx.totalModal.toInt()),       // Modal (Angka)
        IntCellValue(isMasuk ? 0 : trx.totalLaba.toInt()),        // Laba (Angka)
      ];

      sheetObject.appendRow(rowData);
    }

    // 4. Simpan File ke Penyimpanan Sementara
    var fileBytes = excel.save();
    var directory = await getTemporaryDirectory();
    
    String fileName = 'Laporan_Inventory_$tipeFilter.xlsx';
    File file = File('${directory.path}/$fileName');
    
    if (fileBytes != null) {
      await file.writeAsBytes(fileBytes);

      // 5. Bagikan File (Share) agar bisa dibuka di Excel/WPS/WA
      await Share.shareXFiles([XFile(file.path)], text: 'Laporan Excel $tipeFilter');
    }
  }
}