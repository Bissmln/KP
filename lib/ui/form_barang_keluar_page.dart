// lib/ui/form_barang_keluar_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import '../item.dart'; // Impor model Item

class FormBarangKeluarPage extends StatefulWidget {
  const FormBarangKeluarPage({Key? key}) : super(key: key);

  @override
  State<FormBarangKeluarPage> createState() => _FormBarangKeluarPageState();
}

class _FormBarangKeluarPageState extends State<FormBarangKeluarPage> {
  final _formKey = GlobalKey<FormState>();
  final _jumlahController = TextEditingController();
  final _petugasController = TextEditingController(); // Ganti
  final _tujuanController = TextEditingController(); // Ganti
  final _catatanController = TextEditingController();

  Item? _selectedItem; 
  bool _isLoading = false;

  Future<void> _simpanBarangKeluar() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedItem == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Silakan pilih barang terlebih dahulu.')),
        );
        return;
      }

      int jumlah = int.parse(_jumlahController.text);

      // --- VALIDASI STOK ---
      if (jumlah > _selectedItem!.stokAwal) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Stok tidak mencukupi! Stok saat ini: ${_selectedItem!.stokAwal}')),
        );
        return;
      }
      // ----------------------

      setState(() { _isLoading = true; });

      try {
        WriteBatch batch = FirebaseFirestore.instance.batch();

        // 1. Buat dokumen transaksi baru
        DocumentReference trxRef = FirebaseFirestore.instance.collection('transaksi').doc();
        batch.set(trxRef, {
          'itemId': _selectedItem!.id,
          'namaBarang': _selectedItem!.nama,
          'tipe': 'keluar', // Ganti
          'jumlah': jumlah,
          'satuan': _selectedItem!.satuan,
          'petugas': _petugasController.text, // Ganti
          'tujuan': _tujuanController.text, // Ganti
          'catatan': _catatanController.text,
          'timestamp': FieldValue.serverTimestamp(),
        });

        // 2. Update stok barang (DIKURANGI)
        DocumentReference itemRef = FirebaseFirestore.instance
            .collection('barang')
            .doc(_selectedItem!.id);
        
        batch.update(itemRef, {'stok_awal': FieldValue.increment(-jumlah)}); // Ganti

        await batch.commit();

        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Barang keluar berhasil dicatat!')), // Ganti
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
    _petugasController.dispose();
    _tujuanController.dispose();
    _catatanController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Barang Keluar'), // Ganti
        backgroundColor: Colors.red, // Ganti
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
                controller: _petugasController, // Ganti
                label: 'Petugas *', // Ganti
                icon: Icons.person_outline,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _tujuanController, // Ganti
                label: 'Tujuan *', // Ganti
                icon: Icons.location_on_outlined,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _catatanController,
                label: 'Catatan (opsional)',
                icon: Icons.note_outlined,
              ),
              const SizedBox(height: 30),
              
              ElevatedButton(
                onPressed: _isLoading ? null : _simpanBarangKeluar, // Ganti
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red, // Ganti
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'SIMPAN BARANG KELUAR', // Ganti
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

  Widget _buildInfoBox() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1), // Ganti
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red[200]!), // Ganti
      ),
      child: Row(
        children: [
          Icon(Icons.arrow_upward, color: Colors.red[700]), // Ganti
          const SizedBox(width: 12),
          Text(
            'Catat barang yang keluar dari gudang', // Ganti
            style: TextStyle(color: Colors.red[800]), // Ganti
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
          borderSide: BorderSide(color: Colors.red, width: 2), // Ganti
        ),
      );
  }
}