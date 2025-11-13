// lib/ui/tambah_barang_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:inventory/item.dart'; 

class TambahBarangPage extends StatefulWidget {
  final Item? item; // Buat ini opsional

  // Terima item jika ini mode edit
  const TambahBarangPage({Key? key, this.item}) : super(key: key);

  @override
  State<TambahBarangPage> createState() => _TambahBarangPageState();
}

class _TambahBarangPageState extends State<TambahBarangPage> {
  final _namaController = TextEditingController();
  final _kategoriController = TextEditingController();
  final _stokAwalController = TextEditingController();
  final _stokMinController = TextEditingController();
  final _satuanController = TextEditingController();

  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool get _isModeEdit => widget.item != null; // Cek apakah ini mode edit

  @override
  void initState() {
    super.initState();
    // Jika ini mode edit, isi field dengan data yang ada
    if (_isModeEdit) {
      _namaController.text = widget.item!.nama;
      _kategoriController.text = widget.item!.kategori;
      _stokAwalController.text = widget.item!.stokAwal.toString();
      _stokMinController.text = widget.item!.stokMinimum.toString();
      _satuanController.text = widget.item!.satuan;
    }
  }

  // Fungsi untuk menyimpan data ke Firestore
  Future<void> _simpanBarang() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        // Ambil data dari controller
        Map<String, dynamic> data = {
          'nama': _namaController.text,
          'kategori': _kategoriController.text,
          'stok_awal': int.tryParse(_stokAwalController.text) ?? 0,
          'stok_minimum': int.tryParse(_stokMinController.text) ?? 0,
          'satuan': _satuanController.text,
        };

        if (_isModeEdit) {
          // --- MODE EDIT ---
          // Update dokumen yang ada
          await FirebaseFirestore.instance
              .collection('barang')
              .doc(widget.item!.id)
              .update(data);
          
          Navigator.pop(context); // Kembali ke daftar barang
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Barang berhasil diperbarui!')),
          );

        } else {
          // --- MODE TAMBAH BARU ---
          data['timestamp'] = FieldValue.serverTimestamp(); // Catat waktu
          // Tambah dokumen baru
          await FirebaseFirestore.instance.collection('barang').add(data);
          
          Navigator.pop(context); // Kembali ke daftar barang
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Barang berhasil ditambahkan!')),
          );
        }

      } catch (e) {
        // Jika gagal, tampilkan error
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyimpan barang: $e')),
        );
      }
    }
  }


  @override
  void dispose() {
    _namaController.dispose();
    _kategoriController.dispose();
    _stokAwalController.dispose();
    _stokMinController.dispose();
    _satuanController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // Judul dinamis
        title: Text(_isModeEdit ? 'Edit Barang' : 'Tambah Barang'),
        backgroundColor: Colors.white,
        elevation: 1,
        foregroundColor: Colors.black87,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Info Box
              _buildInfoBox(),
              const SizedBox(height: 20),
              // Form Fields
              _buildTextField(
                controller: _namaController,
                label: 'Nama Barang *',
                icon: Icons.inventory_2_outlined,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Nama barang tidak boleh kosong';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _kategoriController,
                label: 'Kategori',
                icon: Icons.category_outlined,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      controller: _stokAwalController,
                      label: 'Stok Awal *',
                      icon: Icons.inventory_outlined,
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Stok tidak boleh kosong';
                        }
                        if (int.tryParse(value) == null) {
                          return 'Masukkan angka';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildTextField(
                      controller: _stokMinController,
                      label: 'Stok Minimum',
                      icon: Icons.warning_amber_outlined,
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _satuanController,
                label: 'Satuan *',
                icon: Icons.square_foot_outlined,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Satuan tidak boleh kosong';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 30),
              // Tombol Simpan
              ElevatedButton(
                onPressed: _isLoading ? null : _simpanBarang,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4A4E9E), // Warna ungu
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        // Teks tombol dinamis
                        _isModeEdit ? 'SIMPAN PERUBAHAN' : 'TAMBAH BARANG',
                        style: const TextStyle(
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

  // Widget helper untuk info box
  Widget _buildInfoBox() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue[100]!),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: Colors.blue[700]),
          const SizedBox(width: 12),
          Text(
            // Teks info dinamis
            _isModeEdit 
              ? 'Edit detail barang di inventory'
              : 'Tambah barang baru ke inventory',
            style: TextStyle(color: Colors.blue[800]),
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
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: keyboardType == TextInputType.number
          ? [FilteringTextInputFormatter.digitsOnly]
          : [],
      decoration: InputDecoration(
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
          borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
        ),
      ),
      validator: validator,
    );
  }
}