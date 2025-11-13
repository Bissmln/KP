// lib/ui/form_barang_masuk_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import '../item.dart'; // Impor model Item

class FormBarangMasukPage extends StatefulWidget {
  const FormBarangMasukPage({Key? key}) : super(key: key);

  @override
  State<FormBarangMasukPage> createState() => _FormBarangMasukPageState();
}

class _FormBarangMasukPageState extends State<FormBarangMasukPage> {
  final _formKey = GlobalKey<FormState>();
  final _jumlahController = TextEditingController();
  final _penerimaController = TextEditingController();
  final _pengirimController = TextEditingController();
  final _catatanController = TextEditingController();

  Item? _selectedItem; // Untuk menyimpan data barang yang dipilih
  bool _isLoading = false;

  Future<void> _simpanBarangMasuk() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedItem == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Silakan pilih barang terlebih dahulu.')),
        );
        return;
      }

      setState(() { _isLoading = true; });

      try {
        int jumlah = int.parse(_jumlahController.text);

        // Gunakan WriteBatch untuk operasi atomik
        WriteBatch batch = FirebaseFirestore.instance.batch();

        // 1. Buat dokumen transaksi baru
        DocumentReference trxRef = FirebaseFirestore.instance.collection('transaksi').doc();
        batch.set(trxRef, {
          'itemId': _selectedItem!.id,
          'namaBarang': _selectedItem!.nama,
          'tipe': 'masuk',
          'jumlah': jumlah,
          'satuan': _selectedItem!.satuan,
          'penerima': _penerimaController.text,
          'pengirim': _pengirimController.text,
          'catatan': _catatanController.text,
          'timestamp': FieldValue.serverTimestamp(),
        });

        // 2. Update stok barang di koleksi 'barang'
        DocumentReference itemRef = FirebaseFirestore.instance
            .collection('barang')
            .doc(_selectedItem!.id);
        
        // Gunakan FieldValue.increment() untuk menambah stok
        batch.update(itemRef, {'stok_awal': FieldValue.increment(jumlah)});

        // Commit batch
        await batch.commit();

        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Barang masuk berhasil dicatat!')),
        );

      } catch (e) {
        setState(() { _isLoading = false; });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyimpan: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _jumlahController.dispose();
    _penerimaController.dispose();
    _pengirimController.dispose();
    _catatanController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Barang Masuk'),
        backgroundColor: Colors.green,
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
              
              // Dropdown Pilih Barang
              _buildBarangDropdown(),
              
              const SizedBox(height: 16),
              _buildTextField(
                controller: _jumlahController,
                label: 'Jumlah *',
                icon: Icons.numbers,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _penerimaController,
                label: 'Penerima *',
                icon: Icons.person_outline,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _pengirimController,
                label: 'Pengirim *',
                icon: Icons.person_pin_circle_outlined,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _catatanController,
                label: 'Catatan (opsional)',
                icon: Icons.note_outlined,
              ),
              const SizedBox(height: 30),
              
              // Tombol Simpan
              ElevatedButton(
                onPressed: _isLoading ? null : _simpanBarangMasuk,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'SIMPAN BARANG MASUK',
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

  // Widget untuk Dropdown Barang (dengan StreamBuilder)
  Widget _buildBarangDropdown() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('barang').orderBy('nama').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        var items = snapshot.data!.docs.map((doc) {
          return Item.fromFirestore(doc);
        }).toList();

        return DropdownButtonFormField<Item>(
          value: _selectedItem,
          hint: const Text('Pilih Barang *'),
          decoration: _buildInputDecoration(label: 'Pilih Barang *', icon: Icons.inventory_2_outlined),
          isExpanded: true,
          items: items.map((Item item) {
            return DropdownMenuItem<Item>(
              value: item,
              child: Text('${item.nama} (Stok: ${item.stokAwal} ${item.satuan})'),
            );
          }).toList(),
          onChanged: (Item? newValue) {
            setState(() {
              _selectedItem = newValue;
            });
          },
          validator: (value) => value == null ? 'Barang tidak boleh kosong' : null,
        );
      },
    );
  }

  // Widget helper untuk info box
  Widget _buildInfoBox() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green[200]!),
      ),
      child: Row(
        children: [
          Icon(Icons.arrow_downward, color: Colors.green[700]),
          const SizedBox(width: 12),
          Text(
            'Catat barang yang masuk ke gudang',
            style: TextStyle(color: Colors.green[800]),
          ),
        ],
      ),
    );
  }

  // Widget helper untuk text field
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: keyboardType == TextInputType.number
          ? [FilteringTextInputFormatter.digitsOnly]
          : [],
      decoration: _buildInputDecoration(label: label, icon: icon),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return '$label tidak boleh kosong';
        }
        return null;
      },
    );
  }

  // Helper terpisah untuk Input Decoration
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
          borderSide: BorderSide(color: Colors.green, width: 2),
        ),
      );
  }
}