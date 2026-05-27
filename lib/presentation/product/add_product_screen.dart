import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/models/product_model.dart';
import '../../data/models/product_unit_model.dart';
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
      final cubit = context.read<ProductCubit>();

      if (_isEditing) {
        await cubit.updateProduct(
          productId: widget.product!.id!,
          product: product,
          units: units,
        );
      } else {
        await cubit.createProduct(product: product, units: units);
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
}

/// Helper class to hold controllers for each dynamic unit entry.
class _UnitEntry {
  final TextEditingController nameCtrl;
  final TextEditingController convCtrl;
  bool isBaseUnit;
  bool isPurchasable;
  bool isSellable;

  _UnitEntry({
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
      name: m.unitName,
      conversion: m.conversionToBase,
      isBaseUnit: m.isBaseUnit,
      isPurchasable: m.isPurchasable,
      isSellable: m.isSellable,
    );
  }

  ProductUnitModel toModel() {
    return ProductUnitModel(
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
