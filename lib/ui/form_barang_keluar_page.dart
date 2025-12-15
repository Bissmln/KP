// lib/ui/form_barang_keluar_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:dropdown_search/dropdown_search.dart';
import '../item.dart';

class FormBarangKeluarPage extends StatefulWidget {
  const FormBarangKeluarPage({Key? key}) : super(key: key);

  @override
  State<FormBarangKeluarPage> createState() => _FormBarangKeluarPageState();
}

class _FormBarangKeluarPageState extends State<FormBarangKeluarPage> {
  final _formKey = GlobalKey<FormState>();
  final _jumlahController = TextEditingController();
  final _tujuanController = TextEditingController();
  final _catatanController = TextEditingController();

  Item? _selectedItem;
  bool _isLoading = false;
  String _labelJumlah = 'Jumlah *';

  // Daftar Nama Petugas
  final List<String> _daftarPetugas = ['Rita', 'Teddy'];
  String? _selectedPetugas;

  Future<void> _simpanBarangKeluar() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedItem == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Silakan pilih barang terlebih dahulu.')),
        );
        return;
      }

      int jumlah = int.parse(_jumlahController.text);
      int sisaStok = _selectedItem!.stok - jumlah;

      // --- [VALIDASI STOK ABSOLUT] ---
      if (jumlah > _selectedItem!.stok) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Stok tidak mencukupi! Sisa stok: ${_selectedItem!.stok} ${_selectedItem!.satuan}')),
        );
        return;
      }

      // --- [VALIDASI STOK MINIMUM] ---
      if (sisaStok < _selectedItem!.stokMinimum) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Peringatan Stok Minimum'),
            content: Text(
              'Transaksi ini akan membuat stok tersisa $sisaStok ${_selectedItem!.satuan}.\n'
              'Batas minimum adalah ${_selectedItem!.stokMinimum} ${_selectedItem!.satuan}.\n\n'
              'Transaksi ditolak untuk menjaga stok minimum.',
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
            ],
          ),
        );
        return; // Batalkan proses
      }

      setState(() {
        _isLoading = true;
      });

      try {
        num totalModal = _selectedItem!.hargaBeli * jumlah;
        num totalJual = _selectedItem!.hargaJual * jumlah;
        num totalLaba = totalJual - totalModal;

        WriteBatch batch = FirebaseFirestore.instance.batch();

        DocumentReference trxRef = FirebaseFirestore.instance.collection('transaksi').doc();
        batch.set(trxRef, {
          'itemId': _selectedItem!.id,
          'namaBarang': _selectedItem!.nama,
          'tipe': 'keluar',
          'jumlah': jumlah,
          'satuan': _selectedItem!.satuan,
          'petugas': _selectedPetugas,
          'tujuan': _tujuanController.text,
          'catatan': _catatanController.text,
          'timestamp': FieldValue.serverTimestamp(),
          'total_modal': totalModal,
          'total_laba': totalLaba,
        });

        DocumentReference itemRef = FirebaseFirestore.instance.collection('barang').doc(_selectedItem!.id);
        batch.update(itemRef, {'stok': FieldValue.increment(-jumlah)});

        await batch.commit();

        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Barang keluar berhasil dicatat!')),
          );
        }
      } catch (e) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyimpan: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _jumlahController.dispose();
    _tujuanController.dispose();
    _catatanController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Barang Keluar'),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _buildInfoBox(),
              const SizedBox(height: 20),

              // Dropdown Barang (Dengan Filter isArchived)
              _buildBarangDropdown(),

              const SizedBox(height: 16),
              _buildTextField(
                controller: _jumlahController,
                label: _labelJumlah,
                icon: Icons.numbers,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),

              // Dropdown Petugas
              DropdownButtonFormField<String>(
                value: _selectedPetugas,
                decoration: _buildInputDecoration(label: 'Petugas *', icon: Icons.person_outline),
                items: _daftarPetugas.map((String nama) {
                  return DropdownMenuItem<String>(
                    value: nama,
                    child: Text(nama),
                  );
                }).toList(),
                onChanged: (newValue) {
                  setState(() {
                    _selectedPetugas = newValue;
                  });
                },
                validator: (value) => value == null ? 'Petugas tidak boleh kosong' : null,
              ),

              const SizedBox(height: 16),
              _buildTextField(
                controller: _tujuanController,
                label: 'Tujuan *',
                icon: Icons.location_on_outlined,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _catatanController,
                label: 'Catatan (opsional)',
                icon: Icons.note_outlined,
                isRequired: false,
              ),
              const SizedBox(height: 30),

              ElevatedButton(
                onPressed: _isLoading ? null : _simpanBarangKeluar,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'SIMPAN BARANG KELUAR',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Modifikasi: Tambahkan Filter isArchived
  Widget _buildBarangDropdown() {
    return DropdownSearch<Item>(
      asyncItems: (String filter) async {
        // Query hanya mengambil barang yang TIDAK DIARSIP
        var snapshot = await FirebaseFirestore.instance
            .collection('barang')
            .where('isArchived', isEqualTo: false) // Filter Aktif
            .orderBy('nama')
            .get();
        return snapshot.docs.map((doc) => Item.fromFirestore(doc)).toList();
      },
      itemAsString: (Item item) => "${item.nama} (Stok: ${item.stok} ${item.satuan})",
      popupProps: PopupProps.modalBottomSheet(
        showSearchBox: true,
        searchFieldProps: const TextFieldProps(
          decoration: InputDecoration(
            labelText: "Cari barang...",
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.search),
          ),
        ),
        modalBottomSheetProps: const ModalBottomSheetProps(
          useSafeArea: true,
        ),
        title: Container(
          padding: const EdgeInsets.all(16),
          child: const Text(
            'Pilih Barang',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
        ),
      ),
      dropdownDecoratorProps: DropDownDecoratorProps(
        dropdownSearchDecoration: _buildInputDecoration(label: 'Pilih Barang *', icon: Icons.inventory_2_outlined),
      ),
      onChanged: (Item? newValue) {
        setState(() {
          _selectedItem = newValue;
          if (newValue != null) {
            _labelJumlah = 'Jumlah (dalam ${newValue.satuan}) *';
          }
        });
      },
      selectedItem: _selectedItem,
      validator: (value) => value == null ? 'Barang tidak boleh kosong' : null,
    );
  }

  Widget _buildInfoBox() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red[200]!),
      ),
      child: Row(
        children: [
          Icon(Icons.arrow_upward, color: Colors.red[700]),
          const SizedBox(width: 12),
          Text(
            'Catat barang yang keluar dari gudang',
            style: TextStyle(color: Colors.red[800]),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool isRequired = true,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: keyboardType == TextInputType.number
          ? [FilteringTextInputFormatter.digitsOnly]
          : [],
      decoration: _buildInputDecoration(label: label, icon: icon),
      validator: (value) {
        if (isRequired && (value == null || value.isEmpty)) {
          return '$label tidak boleh kosong';
        }
        return null;
      },
    );
  }

  InputDecoration _buildInputDecoration({required String label, required IconData icon}) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: Colors.grey[600]),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.0),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.0),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.0),
        borderSide: const BorderSide(color: Colors.red, width: 2),
      ),
    );
  }
}