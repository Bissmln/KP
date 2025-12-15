// lib/ui/tambah_barang_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import '../item.dart';

class TambahBarangPage extends StatefulWidget {
  final Item? item;

  // Terima item jika ini mode edit
  const TambahBarangPage({Key? key, this.item}) : super(key: key);

  @override
  State<TambahBarangPage> createState() => _TambahBarangPage();
}

class _TambahBarangPage extends State<TambahBarangPage> {
  // Controller untuk setiap field
  final _namaController = TextEditingController();
  final _kategoriController = TextEditingController();
  final _stokAwalController = TextEditingController();
  final _stokMinController = TextEditingController();
  final _satuanController = TextEditingController();
  final _hargaBeliController = TextEditingController();
  final _hargaJualController = TextEditingController();

  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool get _isModeEdit => widget.item != null;

  @override
  void initState() {
    super.initState();
    // Jika ini mode edit, isi field dengan data yang ada
    if (_isModeEdit) {
      _namaController.text = widget.item!.nama;
      _kategoriController.text = widget.item!.kategori;
      _satuanController.text = widget.item!.satuan;
      _stokMinController.text = widget.item!.stokMinimum.toString();
      _hargaBeliController.text = widget.item!.hargaBeli.toInt().toString();
      _hargaJualController.text = widget.item!.hargaJual.toInt().toString();
      // Saat edit, stok awal kita set 0 atau kosong agar tidak bingung
      _stokAwalController.text = '0';
    }
  }

  // Fungsi Helper untuk membuat keyword pencarian
  List<String> _generateSearchKeywords(String nama) {
    List<String> keywords = [];
    String text = nama.toLowerCase();
    for (int i = 1; i <= text.length; i++) {
      keywords.add(text.substring(0, i));
    }
    return keywords;
  }

  // Fungsi untuk menyimpan data ke Firestore
  Future<void> _simpanBarang() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        // Bersihkan input angka dari karakter non-digit (jika ada)
        String hargaBeliClean = _hargaBeliController.text.replaceAll(RegExp(r'[^0-9]'), '');
        String hargaJualClean = _hargaJualController.text.replaceAll(RegExp(r'[^0-9]'), '');
        
        int stokAwal = int.tryParse(_stokAwalController.text) ?? 0;
        String kategori = _kategoriController.text.isNotEmpty ? _kategoriController.text : 'Lainnya';
        String satuan = _satuanController.text.isNotEmpty ? _satuanController.text : 'Pcs';

        Map<String, dynamic> data = {
          'nama': _namaController.text,
          'kategori': kategori,
          'satuan': satuan,
          'stokMinimum': int.tryParse(_stokMinController.text) ?? 0, // Pastikan nama field konsisten dgn model
          'hargaBeli': int.parse(hargaBeliClean), // Gunakan int sesuai logika baru
          'hargaJual': int.parse(hargaJualClean), // Gunakan int sesuai logika baru
          'searchKeywords': _generateSearchKeywords(_namaController.text), // Tambahkan keywords
          'isArchived': false, // Default: Tidak diarsip
        };

        if (_isModeEdit) {
          // --- MODE EDIT ---
          await FirebaseFirestore.instance
              .collection('barang')
              .doc(widget.item!.id)
              .update(data);

          if (mounted) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Barang berhasil diperbarui!')),
            );
          }
        } else {
          // --- MODE TAMBAH BARU ---
          data['stok'] = stokAwal; // Simpan stok awal hanya saat baru buat
          data['createdAt'] = FieldValue.serverTimestamp(); // Timestamp pembuatan

          await FirebaseFirestore.instance.collection('barang').add(data);

          if (mounted) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Barang berhasil ditambahkan!')),
            );
          }
        }
      } catch (e) {
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
    _hargaBeliController.dispose();
    _hargaJualController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
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
              _buildInfoBox(),
              const SizedBox(height: 20),

              // 1. Nama Barang
              _buildTextField(
                controller: _namaController,
                label: 'Nama Barang',
                icon: Icons.inventory_2_outlined,
              ),
              const SizedBox(height: 16),

              // 2. Kategori
              _buildTextField(
                controller: _kategoriController,
                label: 'Kategori',
                icon: Icons.category_outlined,
                helperText: 'Contoh: Makanan, Minuman',
              ),
              const SizedBox(height: 16),

              // 3. Stok Awal | Stok Minimum
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      controller: _stokAwalController,
                      label: 'Stok Awal',
                      icon: Icons.inventory_outlined,
                      keyboardType: TextInputType.number,
                      enabled: !_isModeEdit, // Nonaktifkan saat edit
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

              // 4. Satuan
              _buildTextField(
                controller: _satuanController,
                label: 'Satuan',
                icon: Icons.square_foot_outlined,
                helperText: 'Contoh: Pcs, Dus, Kg',
              ),
              const SizedBox(height: 16),

              // 5. Harga Beli | Harga Jual (Kustom dengan Logo Rp)
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _hargaBeliController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        labelText: 'Harga Beli',
                        // --- LOGO RUPIAH ---
                        prefixIcon: Padding(
                          padding: const EdgeInsets.all(14.0),
                          child: Text(
                            'Rp',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).primaryColor,
                            ),
                          ),
                        ),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                      ),
                      validator: (val) => val!.isEmpty ? 'Wajib diisi' : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _hargaJualController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        labelText: 'Harga Jual',
                        // --- LOGO RUPIAH ---
                        prefixIcon: Padding(
                          padding: const EdgeInsets.all(14.0),
                          child: Text(
                            'Rp',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).primaryColor,
                            ),
                          ),
                        ),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                      ),
                      validator: (val) => val!.isEmpty ? 'Wajib diisi' : null,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 30),

              // Tombol Simpan
              ElevatedButton(
                onPressed: _isLoading ? null : _simpanBarang,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4A4E9E),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
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
          Expanded(
            child: Text(
              _isModeEdit
                  ? 'Edit detail barang.'
                  : 'Tambah barang baru. Stok awal akan menjadi stok saat ini.',
              style: TextStyle(color: Colors.blue[800]),
            ),
          ),
        ],
      ),
    );
  }

  // Widget helper untuk text field biasa (Nama, Kategori, Stok)
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    String? helperText,
    bool? enabled,
    bool isRequired = true,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      enabled: enabled,
      inputFormatters: keyboardType == TextInputType.number
          ? [FilteringTextInputFormatter.digitsOnly]
          : [],
      decoration: InputDecoration(
        labelText: label,
        floatingLabelBehavior: FloatingLabelBehavior.auto,
        prefixIcon: Icon(icon, color: Colors.grey[600]),
        filled: true,
        fillColor: enabled == false ? Colors.grey[100] : Colors.white,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: BorderSide(color: Colors.grey[400]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: const BorderSide(color: Colors.red),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: const BorderSide(color: Colors.red, width: 2),
        ),
        helperText: helperText,
        helperMaxLines: 2,
      ),
      validator: (value) {
        if (isRequired) {
          if (value == null || value.isEmpty) {
            return '$label tidak boleh kosong';
          }
          if (keyboardType == TextInputType.number && num.tryParse(value) == null) {
            return 'Input harus berupa angka';
          }
        }
        return null;
      },
    );
  }
}