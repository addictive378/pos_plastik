import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/models/product_model.dart';
import '../../data/models/product_unit_model.dart';
import '../../logic/inventory/stock_mutation_cubit.dart';
import '../../logic/inventory/stock_mutation_state.dart';
import '../product/add_product_screen.dart';

/// Screen for recording incoming stock from a supplier (purchase).
class RestockScreen extends StatefulWidget {
  /// If provided, the product dropdown will be pre-selected with this product.
  final ProductModel? initialProduct;

  const RestockScreen({super.key, this.initialProduct});

  @override
  State<RestockScreen> createState() => _RestockScreenState();
}

class _RestockScreenState extends State<RestockScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;

  // ── Form controllers ──
  final _qtyCtrl = TextEditingController();
  final _hargaBaruCtrl = TextEditingController();
  final _supplierCtrl = TextEditingController();
  final _invoiceCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final cubit = context.read<StockMutationCubit>();
    cubit.loadProducts().then((_) {
      if (widget.initialProduct != null) {
        cubit.selectProduct(widget.initialProduct!);
        _hargaBaruCtrl.text =
            widget.initialProduct!.hargaModalTerakhir.toStringAsFixed(0);
      }
    });
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _hargaBaruCtrl.dispose();
    _supplierCtrl.dispose();
    _invoiceCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  // ── Helpers ──

  void _showSnackBar(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Theme.of(context).colorScheme.error : null,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  String _formatCurrency(double value) {
    final intVal = value.toInt().toString();
    final buffer = StringBuffer();
    for (int i = 0; i < intVal.length; i++) {
      if (i > 0 && (intVal.length - i) % 3 == 0) buffer.write('.');
      buffer.write(intVal[i]);
    }
    return 'Rp $buffer';
  }

  // ── Submit logic with price-check dialog ──

  void _onSubmitPressed() {
    if (!_formKey.currentState!.validate()) return;

    final state = context.read<StockMutationCubit>().state;
    final product = state.selectedProduct;
    if (product == null) {
      _showSnackBar('Pilih produk terlebih dahulu.', isError: true);
      return;
    }
    if (state.selectedUnit == null) {
      _showSnackBar('Pilih satuan terlebih dahulu.', isError: true);
      return;
    }

    final newPrice = double.tryParse(_hargaBaruCtrl.text.trim()) ?? 0;

    if (newPrice > product.hargaModalTerakhir) {
      // Price increased → show confirmation dialog
      _showPriceIncreaseDialog(product, newPrice);
    } else {
      // No increase → submit directly
      _executeSubmit(navigateToEdit: false);
    }
  }

  void _showPriceIncreaseDialog(ProductModel product, double newPrice) {
    final cs = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            shape: BoxShape.circle,
          ),
          child:
              Icon(Icons.trending_up_rounded, color: Colors.orange.shade700, size: 32),
        ),
        title: const Text(
          'Harga Modal Naik!',
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        Text('Sebelum',
                            style: TextStyle(
                                fontSize: 11,
                                color: cs.onSurface.withValues(alpha: 0.6))),
                        const SizedBox(height: 2),
                        Text(
                          _formatCurrency(product.hargaModalTerakhir),
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.arrow_forward_rounded,
                      color: Colors.orange.shade700, size: 20),
                  Expanded(
                    child: Column(
                      children: [
                        Text('Sesudah',
                            style: TextStyle(
                                fontSize: 11,
                                color: cs.onSurface.withValues(alpha: 0.6))),
                        const SizedBox(height: 2),
                        Text(
                          _formatCurrency(newPrice),
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: Colors.orange.shade700),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Stok akan ditambahkan, namun apakah Anda ingin meninjau ulang Harga Jual sekarang?',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14),
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          OutlinedButton(
            onPressed: () {
              Navigator.pop(dialogCtx);
              _executeSubmit(navigateToEdit: false);
            },
            style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              minimumSize: const Size(100, 42),
            ),
            child: const Text('Tidak'),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: () {
              Navigator.pop(dialogCtx);
              _executeSubmit(navigateToEdit: true);
            },
            style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              minimumSize: const Size(100, 42),
            ),
            child: const Text('Ya, Tinjau'),
          ),
        ],
      ),
    );
  }

  Future<void> _executeSubmit({required bool navigateToEdit}) async {
    setState(() => _isSubmitting = true);

    try {
      final cubit = context.read<StockMutationCubit>();
      final product = cubit.state.selectedProduct;

      await cubit.submitPurchase(
        qtyOriginal: double.parse(_qtyCtrl.text.trim()),
        hargaModalBaru: double.parse(_hargaBaruCtrl.text.trim()),
        supplierName: _supplierCtrl.text.trim(),
        invoiceRef: _invoiceCtrl.text.trim(),
        notes: _notesCtrl.text.trim(),
      );

      if (!mounted) return;

      final state = cubit.state;
      if (state.status == StockMutationStatus.error) {
        _showSnackBar(state.errorMessage ?? 'Terjadi kesalahan.', isError: true);
        return;
      }

      _showSnackBar('Stok masuk berhasil dicatat! ✓');

      if (navigateToEdit && product != null) {
        // Replace this screen with the product edit screen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => AddProductScreen(product: product),
          ),
        );
      } else {
        Navigator.pop(context, true);
      }
    } catch (e) {
      _showSnackBar('Gagal menyimpan: ${e.toString()}', isError: true);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // ── Build ──

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stok Masuk (Pembelian)'),
        centerTitle: true,
      ),
      body: BlocConsumer<StockMutationCubit, StockMutationState>(
        listener: (context, state) {
          if (state.status == StockMutationStatus.error &&
              state.errorMessage != null) {
            _showSnackBar(state.errorMessage!, isError: true);
          }
        },
        builder: (context, state) {
          if (state.status == StockMutationStatus.loading &&
              state.products.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ── Section: Pilih Produk ──
                _sectionLabel('Pilih Produk'),
                const SizedBox(height: 8),
                _buildProductDropdown(state, cs),

                // ── Section: Info Produk (read-only) ──
                if (state.selectedProduct != null) ...[
                  const SizedBox(height: 16),
                  _buildProductInfoCard(state.selectedProduct!, cs),
                ],

                const SizedBox(height: 24),

                // ── Section: Detail Pembelian ──
                _sectionLabel('Detail Pembelian'),
                const SizedBox(height: 8),

                // Unit dropdown
                _buildUnitDropdown(state, cs),
                const SizedBox(height: 12),

                // Quantity
                TextFormField(
                  controller: _qtyCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                  ],
                  decoration: InputDecoration(
                    labelText: 'Jumlah Masuk (Qty)',
                    hintText: 'cth: 10',
                    prefixIcon: const Icon(Icons.inventory_2_outlined),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    suffixText: state.selectedUnit?.unitName ?? '',
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Qty wajib diisi';
                    final n = double.tryParse(v.trim());
                    if (n == null || n <= 0) return 'Qty harus > 0';
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                // Harga modal baru
                TextFormField(
                  controller: _hargaBaruCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: 'Harga Modal Baru (per base unit)',
                    prefixText: 'Rp ',
                    prefixIcon: const Icon(Icons.monetization_on_outlined),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Harga modal wajib diisi';
                    }
                    final n = double.tryParse(v.trim());
                    if (n == null || n < 0) return 'Harga tidak valid';
                    return null;
                  },
                ),

                const SizedBox(height: 24),

                // ── Section: Info Supplier (opsional) ──
                _sectionLabel('Info Supplier (Opsional)'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _supplierCtrl,
                  decoration: InputDecoration(
                    labelText: 'Nama Supplier',
                    prefixIcon: const Icon(Icons.store_outlined),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _invoiceCtrl,
                  decoration: InputDecoration(
                    labelText: 'No. Invoice / Referensi',
                    prefixIcon: const Icon(Icons.receipt_long_outlined),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _notesCtrl,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Catatan',
                    prefixIcon: const Padding(
                      padding: EdgeInsets.only(bottom: 40),
                      child: Icon(Icons.notes_outlined),
                    ),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),

                const SizedBox(height: 32),

                // ── Submit ──
                FilledButton.icon(
                  onPressed: _isSubmitting ? null : _onSubmitPressed,
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.save_rounded),
                  label: Text(
                    _isSubmitting ? 'Menyimpan...' : 'Simpan Stok Masuk',
                    style: const TextStyle(fontSize: 16),
                  ),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── Widgets ──

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: Theme.of(context)
          .textTheme
          .titleMedium
          ?.copyWith(fontWeight: FontWeight.w700),
    );
  }

  Widget _buildProductDropdown(StockMutationState state, ColorScheme cs) {
    return DropdownButtonFormField<ProductModel>(
      initialValue: state.selectedProduct,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: 'Cari / Pilih Produk',
        prefixIcon: const Icon(Icons.search_rounded),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      hint: const Text('Pilih produk...'),
      items: state.products.map((p) {
        return DropdownMenuItem<ProductModel>(
          value: p,
          child: Text(
            p.sku != null && p.sku!.isNotEmpty
                ? '${p.name} (${p.sku})'
                : p.name,
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(),
      onChanged: (product) {
        if (product != null) {
          context.read<StockMutationCubit>().selectProduct(product);
          // Pre-fill harga modal baru with current harga modal
          _hargaBaruCtrl.text =
              product.hargaModalTerakhir.toStringAsFixed(0);
        }
      },
      validator: (v) => v == null ? 'Pilih produk terlebih dahulu' : null,
    );
  }

  Widget _buildProductInfoCard(ProductModel product, ColorScheme cs) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: _infoTile(
                icon: Icons.price_change_outlined,
                label: 'Harga Modal Terakhir',
                value: _formatCurrency(product.hargaModalTerakhir),
                cs: cs,
              ),
            ),
            Container(
              width: 1,
              height: 40,
              color: cs.outlineVariant.withValues(alpha: 0.5),
            ),
            Expanded(
              child: _infoTile(
                icon: Icons.inventory_outlined,
                label: 'Stok Saat Ini',
                value:
                    '${product.currentStock.toStringAsFixed(product.currentStock == product.currentStock.truncateToDouble() ? 0 : 2)} ${product.baseUnit}',
                cs: cs,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoTile({
    required IconData icon,
    required String label,
    required String value,
    required ColorScheme cs,
  }) {
    return Column(
      children: [
        Icon(icon, size: 20, color: cs.primary),
        const SizedBox(height: 4),
        Text(label,
            style: TextStyle(
                fontSize: 11, color: cs.onSurface.withValues(alpha: 0.6))),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildUnitDropdown(StockMutationState state, ColorScheme cs) {
    final units = state.purchasableUnits;

    if (state.selectedProduct == null) {
      return DropdownButtonFormField<ProductUnitModel>(
        items: const [],
        onChanged: null,
        decoration: InputDecoration(
          labelText: 'Satuan',
          prefixIcon: const Icon(Icons.straighten_outlined),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          enabled: false,
        ),
        hint: const Text('Pilih produk dulu'),
      );
    }

    return DropdownButtonFormField<ProductUnitModel>(
      initialValue: state.selectedUnit,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: 'Satuan',
        prefixIcon: const Icon(Icons.straighten_outlined),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      hint: const Text('Pilih satuan...'),
      items: units.map((u) {
        final suffix = u.isBaseUnit
            ? ' (base)'
            : ' (1 = ${u.conversionToBase.toStringAsFixed(u.conversionToBase == u.conversionToBase.truncateToDouble() ? 0 : 2)} base)';
        return DropdownMenuItem<ProductUnitModel>(
          value: u,
          child: Text('${u.unitName}$suffix'),
        );
      }).toList(),
      onChanged: (unit) {
        if (unit != null) {
          context.read<StockMutationCubit>().selectUnit(unit);
        }
      },
      validator: (v) => v == null ? 'Pilih satuan terlebih dahulu' : null,
    );
  }
}
