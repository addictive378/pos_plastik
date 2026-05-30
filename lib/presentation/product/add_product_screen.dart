import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/models/product_model.dart';
import '../../data/models/product_unit_model.dart';
import '../../data/repositories/product_repository.dart';
import '../../logic/product/product_cubit.dart';

/// Screen for creating or editing a product with dynamic product-unit sub-forms.
class AddProductScreen extends StatefulWidget {
  /// If non-null we are editing; otherwise we are creating.
  final ProductModel? product;

  const AddProductScreen({super.key, this.product});

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;

  // ── Main product fields ──
  late final TextEditingController _nameCtrl;
  late final TextEditingController _skuCtrl;
  late final TextEditingController _hargaModalCtrl;
  late final TextEditingController _hargaJualMinCtrl;
  late bool _isActive;

  // ── Dynamic unit entries ──
  final List<_UnitEntry> _unitEntries = [];

  final List<_PriceEntry> _priceEntries = [];
  bool _isLoadingPrices = false;

  bool get _isEditing => widget.product != null;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _nameCtrl = TextEditingController(text: p?.name ?? '');
    _skuCtrl = TextEditingController(text: p?.sku ?? '');
    _hargaModalCtrl = TextEditingController(
        text: p != null ? p.hargaModalTerakhir.toStringAsFixed(0) : '');
    _hargaJualMinCtrl = TextEditingController(
        text: p != null ? p.hargaJualMin.toStringAsFixed(0) : '');
    _isActive = p?.isActive ?? true;

    if (p != null && p.units.isNotEmpty) {
      for (final u in p.units) {
        _unitEntries.add(_UnitEntry.fromModel(u));
      }
    } else {
      // Start with one empty base-unit row.
      _unitEntries.add(_UnitEntry(isBaseUnit: true));
    }

    if (_isEditing) {
      _loadSpecialPrices();
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _skuCtrl.dispose();
    _hargaModalCtrl.dispose();
    _hargaJualMinCtrl.dispose();
    for (final e in _unitEntries) {
      e.dispose();
    }
    super.dispose();
  }

  // ── Submit logic ──
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    // Validate at least one base unit
    final baseCount = _unitEntries.where((e) => e.isBaseUnit).length;
    if (baseCount == 0) {
      _showSnackBar('Harus ada minimal 1 satuan base unit.');
      return;
    }
    if (baseCount > 1) {
      _showSnackBar('Hanya boleh ada 1 satuan base unit.');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final ownerId = Supabase.instance.client.auth.currentUser!.id;
      final baseUnitEntry = _unitEntries.firstWhere((e) => e.isBaseUnit);

      final product = ProductModel(
        ownerId: ownerId,
        name: _nameCtrl.text.trim(),
        sku: _skuCtrl.text.trim().isEmpty ? null : _skuCtrl.text.trim(),
        baseUnit: baseUnitEntry.nameCtrl.text.trim(),
        hargaModalTerakhir:
            double.tryParse(_hargaModalCtrl.text.trim()) ?? 0,
        hargaJualMin:
            double.tryParse(_hargaJualMinCtrl.text.trim()) ?? 0,
        isActive: _isActive,
      );

      final units = _unitEntries.map((e) => e.toModel()).toList();
      final priceRules = _priceEntries.map((e) => e.toJson()).toList();
      final cubit = context.read<ProductCubit>();

      if (_isEditing) {
        await cubit.updateProduct(
          productId: widget.product!.id!,
          product: product,
          units: units,
          priceRules: priceRules,
        );
      } else {
        await cubit.createProduct(
          product: product,
          units: units,
          priceRules: priceRules,
        );
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      _showSnackBar('Gagal menyimpan: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showSnackBar(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  // ── Unit management ──
  void _addUnit() {
    setState(() => _unitEntries.add(_UnitEntry()));
  }

  void _removeUnit(int index) {
    if (_unitEntries.length <= 1) {
      _showSnackBar('Minimal harus ada 1 satuan.');
      return;
    }
    setState(() {
      _unitEntries[index].dispose();
      _unitEntries.removeAt(index);
    });
  }

  void _setBaseUnit(int index) {
    setState(() {
      for (int i = 0; i < _unitEntries.length; i++) {
        _unitEntries[i].isBaseUnit = i == index;
        if (i == index) {
          _unitEntries[i].convCtrl.text = '1';
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Produk' : 'Tambah Produk'),
        centerTitle: true,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _sectionLabel('Informasi Produk'),
            const SizedBox(height: 8),
            _buildTextField(_nameCtrl, 'Nama Produk', required: true),
            const SizedBox(height: 12),
            _buildTextField(_skuCtrl, 'SKU (opsional)'),
            const SizedBox(height: 12),
            _buildNumberField(_hargaModalCtrl, 'Harga Modal Terakhir'),
            const SizedBox(height: 12),
            _buildNumberField(_hargaJualMinCtrl, 'Harga Jual Minimum'),
            const SizedBox(height: 12),
            SwitchListTile(
              title: const Text('Status Aktif'),
              subtitle: Text(_isActive ? 'Produk aktif dijual' : 'Produk non-aktif'),
              value: _isActive,
              onChanged: (v) => setState(() => _isActive = v),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              tileColor: cs.surfaceContainerHighest.withOpacity(0.3),
            ),

            const SizedBox(height: 24),
            _sectionLabel('Satuan Produk'),
            const SizedBox(height: 4),
            Text('Minimal 1 satuan harus diset sebagai Base Unit.',
                style: TextStyle(fontSize: 12, color: cs.onSurface.withOpacity(0.5))),
            const SizedBox(height: 12),

            // Dynamic unit cards
            ..._unitEntries.asMap().entries.map((entry) {
              final idx = entry.key;
              final unit = entry.value;
              return _buildUnitCard(idx, unit, cs);
            }),

            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _addUnit,
              icon: const Icon(Icons.add),
              label: const Text('Tambah Satuan'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            _buildSpecialPricesSection(cs),
            const SizedBox(height: 32),

            // Submit button
            FilledButton(
              onPressed: _isSubmitting ? null : _submit,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isSubmitting
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(_isEditing ? 'Simpan Perubahan' : 'Simpan Produk', style: const TextStyle(fontSize: 16)),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(text, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700));
  }

  Widget _buildTextField(TextEditingController ctrl, String label, {bool required = false}) {
    return TextFormField(
      controller: ctrl,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      validator: required ? (v) => (v == null || v.trim().isEmpty) ? '$label wajib diisi' : null : null,
    );
  }

  Widget _buildNumberField(TextEditingController ctrl, String label) {
    return TextFormField(
      controller: ctrl,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(
        labelText: label,
        prefixText: 'Rp ',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildUnitCard(int index, _UnitEntry unit, ColorScheme cs) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: unit.isBaseUnit ? BorderSide(color: cs.primary, width: 2) : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Header row
          Row(children: [
            if (unit.isBaseUnit)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: cs.primaryContainer, borderRadius: BorderRadius.circular(8)),
                child: Text('Base Unit', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: cs.onPrimaryContainer)),
              )
            else
              TextButton.icon(
                onPressed: () => _setBaseUnit(index),
                icon: const Icon(Icons.star_outline, size: 18),
                label: const Text('Set Base Unit'),
                style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
              ),
            const Spacer(),
            IconButton(
              icon: Icon(Icons.delete_outline, color: cs.error, size: 20),
              onPressed: () => _removeUnit(index),
              visualDensity: VisualDensity.compact,
            ),
          ]),
          const SizedBox(height: 8),
          TextFormField(
            controller: unit.nameCtrl,
            decoration: InputDecoration(
              labelText: 'Nama Satuan',
              hintText: 'cth: pcs, lusin, karton',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              isDense: true,
            ),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Nama satuan wajib diisi' : null,
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: unit.convCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            enabled: !unit.isBaseUnit,
            decoration: InputDecoration(
              labelText: 'Konversi ke Base',
              hintText: unit.isBaseUnit ? '1 (otomatis)' : 'cth: 12',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              isDense: true,
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Wajib diisi';
              final n = double.tryParse(v.trim());
              if (n == null || n <= 0) return 'Harus > 0';
              return null;
            },
          ),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: CheckboxListTile(
              title: const Text('Bisa dibeli', style: TextStyle(fontSize: 13)),
              value: unit.isPurchasable,
              onChanged: (v) => setState(() => unit.isPurchasable = v ?? true),
              dense: true, contentPadding: EdgeInsets.zero, controlAffinity: ListTileControlAffinity.leading,
            )),
            Expanded(child: CheckboxListTile(
              title: const Text('Bisa dijual', style: TextStyle(fontSize: 13)),
              value: unit.isSellable,
              onChanged: (v) => setState(() => unit.isSellable = v ?? true),
              dense: true, contentPadding: EdgeInsets.zero, controlAffinity: ListTileControlAffinity.leading,
            )),
          ]),
        ]),
      ),
    );
  }

  // ── Special Prices ──

  Future<void> _loadSpecialPrices() async {
    if (!_isEditing) return;
    setState(() => _isLoadingPrices = true);
    try {
      final repo = context.read<ProductRepository>();
      final prices = await repo.getProductPrices(widget.product!.id!);
      setState(() {
        _priceEntries.clear();
        for (final p in prices) {
          final unitName = _getUnitName(p.unitId);
          _priceEntries.add(_PriceEntry(
            id: p.id,
            unitName: unitName,
            priceType: p.priceType,
            minQty: p.minQty,
            customerLevel: p.customerLevel,
            hargaJual: p.hargaJual,
          ));
        }
      });
    } catch (e) {
      _showSnackBar('Gagal memuat harga khusus: ${e.toString()}');
    } finally {
      setState(() => _isLoadingPrices = false);
    }
  }

  String _getUnitName(String unitId) {
    if (widget.product != null) {
      for (final u in widget.product!.units) {
        if (u.id == unitId) return u.unitName;
      }
    }
    return 'Satuan';
  }

  String _formatMoney(double val) {
    return val.toStringAsFixed(0).replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.');
  }

  Widget _buildSpecialPricesSection(ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        _sectionLabel('Harga Khusus (Grosir & Agen)'),
        const SizedBox(height: 12),
        if (_isLoadingPrices)
          const Center(child: CircularProgressIndicator())
        else if (_priceEntries.isEmpty)
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: cs.primary),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Belum ada harga khusus untuk produk ini.',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          ..._priceEntries.asMap().entries.map((entry) => _buildSpecialPriceCard(entry.key, entry.value, cs)),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _showAddSpecialPriceDialog,
          icon: const Icon(Icons.add),
          label: const Text('Tambah Harga Khusus'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }

  Widget _buildSpecialPriceCard(int index, _PriceEntry price, ColorScheme cs) {
    final isQtyBased = price.priceType == 'qty_based';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: cs.primaryContainer,
          child: Icon(
            isQtyBased ? Icons.shopping_bag_outlined : Icons.person_outline,
            color: cs.onPrimaryContainer,
            size: 20,
          ),
        ),
        title: Text(
          isQtyBased
              ? 'Min. Beli ${price.minQty} ${price.unitName}'
              : 'Level ${price.customerLevel?.toUpperCase()}',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        subtitle: Text(
          'Harga: Rp ${_formatMoney(price.hargaJual)} / ${price.unitName}',
          style: TextStyle(color: cs.primary, fontSize: 13, fontWeight: FontWeight.w500),
        ),
        trailing: IconButton(
          icon: Icon(Icons.delete_outline, color: cs.error),
          onPressed: () => _deleteSpecialPrice(index),
        ),
      ),
    );
  }

  Future<void> _deleteSpecialPrice(int index) async {
    final cs = Theme.of(context).colorScheme;
    final repo = context.read<ProductRepository>();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Aturan Harga'),
        content: const Text('Apakah Anda yakin ingin menghapus aturan harga khusus ini?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: cs.error),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    if (!mounted) return;

    if (_isEditing) {
      final priceId = _priceEntries[index].id;
      if (priceId != null) {
        setState(() => _isLoadingPrices = true);
        try {
          await repo.deleteProductPrice(priceId);
          _showSnackBar('Aturan harga berhasil dihapus dari database.');
          await _loadSpecialPrices();
        } catch (e) {
          _showSnackBar('Gagal menghapus aturan harga: ${e.toString()}');
        } finally {
          if (mounted) {
            setState(() => _isLoadingPrices = false);
          }
        }
      } else {
        setState(() {
          _priceEntries.removeAt(index);
        });
      }
    } else {
      setState(() {
        _priceEntries.removeAt(index);
      });
    }
  }

  void _showAddSpecialPriceDialog() {
    final availableUnits = _unitEntries
        .map((e) => e.nameCtrl.text.trim())
        .where((name) => name.isNotEmpty)
        .toSet()
        .toList();

    if (availableUnits.isEmpty) {
      _showSnackBar('Tambahkan minimal 1 Satuan Produk terlebih dahulu.');
      return;
    }

    final units = _unitEntries.map((e) => e.toModel()).toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return _AddPriceBottomSheet(
          units: units,
          unitNames: availableUnits,
          productId: widget.product?.id,
          onSavedLocal: (_PriceEntry entry) {
            setState(() {
              _priceEntries.add(entry);
            });
            Navigator.pop(ctx);
          },
          onSavedDb: () {
            Navigator.pop(ctx);
            _loadSpecialPrices();
          },
        );
      },
    );
  }
}

/// Helper class to hold controllers for each dynamic unit entry.
class _UnitEntry {
  final String? id;
  final TextEditingController nameCtrl;
  final TextEditingController convCtrl;
  bool isBaseUnit;
  bool isPurchasable;
  bool isSellable;

  _UnitEntry({
    this.id,
    String name = '',
    double conversion = 1,
    this.isBaseUnit = false,
    this.isPurchasable = true,
    this.isSellable = true,
  })  : nameCtrl = TextEditingController(text: name),
        convCtrl = TextEditingController(
            text: conversion == 1 && !isBaseUnit ? '' : conversion.toStringAsFixed(conversion == conversion.truncateToDouble() ? 0 : 2));

  factory _UnitEntry.fromModel(ProductUnitModel m) {
    return _UnitEntry(
      id: m.id,
      name: m.unitName,
      conversion: m.conversionToBase,
      isBaseUnit: m.isBaseUnit,
      isPurchasable: m.isPurchasable,
      isSellable: m.isSellable,
    );
  }

  ProductUnitModel toModel() {
    return ProductUnitModel(
      id: id,
      unitName: nameCtrl.text.trim(),
      conversionToBase: isBaseUnit ? 1 : (double.tryParse(convCtrl.text.trim()) ?? 1),
      isBaseUnit: isBaseUnit,
      isPurchasable: isPurchasable,
      isSellable: isSellable,
    );
  }

  void dispose() {
    nameCtrl.dispose();
    convCtrl.dispose();
  }
}

class _PriceEntry {
  final String? id;
  final String unitName;
  final String priceType;
  final int minQty;
  final String? customerLevel;
  final double hargaJual;

  _PriceEntry({
    this.id,
    required this.unitName,
    required this.priceType,
    this.minQty = 1,
    this.customerLevel,
    required this.hargaJual,
  });

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'unit_name': unitName,
      'price_type': priceType,
      'min_qty': minQty,
      'customer_level': customerLevel,
      'harga_jual': hargaJual,
      'is_active': true,
    };
  }
}

class _AddPriceBottomSheet extends StatefulWidget {
  final List<ProductUnitModel> units;
  final List<String> unitNames;
  final String? productId;
  final ValueChanged<_PriceEntry> onSavedLocal;
  final VoidCallback onSavedDb;

  const _AddPriceBottomSheet({
    required this.units,
    required this.unitNames,
    this.productId,
    required this.onSavedLocal,
    required this.onSavedDb,
  });

  @override
  State<_AddPriceBottomSheet> createState() => _AddPriceBottomSheetState();
}

class _AddPriceBottomSheetState extends State<_AddPriceBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;

  late String _selectedUnitName;
  String _priceType = 'qty_based'; // 'qty_based' or 'customer_level'
  
  final _minQtyCtrl = TextEditingController(text: '1');
  final _hargaJualCtrl = TextEditingController();
  String _selectedCustomerLevel = 'grosir'; // 'grosir', 'agen'

  @override
  void initState() {
    super.initState();
    _selectedUnitName = widget.unitNames.first;
  }

  @override
  void dispose() {
    _minQtyCtrl.dispose();
    _hargaJualCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (widget.productId != null) {
      final sm = ScaffoldMessenger.of(context);
      // Direct INSERT to Supabase (Edit Mode)
      setState(() => _isSaving = true);
      try {
        final repo = context.read<ProductRepository>();
        final unit = widget.units.firstWhere(
          (u) => u.unitName == _selectedUnitName,
          orElse: () => throw Exception('Satuan tidak ditemukan'),
        );

        if (unit.id == null) {
          throw Exception('Satuan "$_selectedUnitName" belum disimpan ke database. Silakan klik "Simpan Perubahan" pada produk terlebih dahulu.');
        }

        final data = {
          'product_id': widget.productId,
          'unit_id': unit.id,
          'price_type': _priceType,
          'min_qty': _priceType == 'qty_based'
              ? (int.tryParse(_minQtyCtrl.text.trim()) ?? 1)
              : 1,
          'customer_level': _priceType == 'customer_level'
               ? _selectedCustomerLevel
               : null,
          'harga_jual': double.tryParse(_hargaJualCtrl.text.trim()) ?? 0,
          'is_active': true,
        };

        await repo.addProductPrice(data);
        widget.onSavedDb();
      } catch (e) {
        sm.showSnackBar(
          SnackBar(content: Text('Gagal menyimpan: ${e.toString()}')),
        );
      } finally {
        if (mounted) setState(() => _isSaving = false);
      }
    } else {
      // Local Save (Create Mode)
      final entry = _PriceEntry(
        unitName: _selectedUnitName,
        priceType: _priceType,
        minQty: _priceType == 'qty_based'
            ? (int.tryParse(_minQtyCtrl.text.trim()) ?? 1)
            : 1,
        customerLevel: _priceType == 'customer_level'
            ? _selectedCustomerLevel
            : null,
        hargaJual: double.tryParse(_hargaJualCtrl.text.trim()) ?? 0,
      );
      widget.onSavedLocal(entry);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Tambah Harga Khusus',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: 12),

              // Dropdown Satuan
              DropdownButtonFormField<String>(
                value: _selectedUnitName,
                decoration: InputDecoration(
                  labelText: 'Pilih Satuan',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                items: widget.unitNames.map((name) {
                  return DropdownMenuItem<String>(
                    value: name,
                    child: Text(name),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _selectedUnitName = val);
                  }
                },
              ),
              const SizedBox(height: 12),

              // Dropdown Tipe Aturan
              DropdownButtonFormField<String>(
                value: _priceType,
                decoration: InputDecoration(
                  labelText: 'Tipe Aturan',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'qty_based',
                    child: Text('Berdasarkan Jumlah Beli (Grosir Qty)'),
                  ),
                  DropdownMenuItem(
                    value: 'customer_level',
                    child: Text('Berdasarkan Level Pembeli'),
                  ),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _priceType = val);
                  }
                },
              ),
              const SizedBox(height: 12),

              // Conditional fields
              if (_priceType == 'qty_based') ...[
                TextFormField(
                  controller: _minQtyCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: 'Minimal Jumlah Beli (Qty)',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Wajib diisi';
                    final n = int.tryParse(v.trim());
                    if (n == null || n < 1) return 'Harus minimal 1';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
              ] else ...[
                DropdownButtonFormField<String>(
                  value: _selectedCustomerLevel,
                  decoration: InputDecoration(
                    labelText: 'Level Pembeli',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'grosir', child: Text('Grosir')),
                    DropdownMenuItem(value: 'agen', child: Text('Agen')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _selectedCustomerLevel = val);
                    }
                  },
                ),
                const SizedBox(height: 12),
              ],

              // Harga Spesial
              TextFormField(
                controller: _hargaJualCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: 'Harga Spesial',
                  prefixText: 'Rp ',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Wajib diisi';
                  final n = double.tryParse(v.trim());
                  if (n == null || n < 0) return 'Harus bernilai positif';
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Button Simpan
              FilledButton(
                onPressed: _isSaving ? null : _save,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Simpan Aturan Harga', style: TextStyle(fontSize: 16)),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
