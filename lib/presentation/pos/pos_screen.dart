import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/models/cart_item_model.dart';
import '../../data/models/product_model.dart';
import '../../data/models/product_unit_model.dart';
import '../../logic/pos/cart_cubit.dart';
import '../../logic/pos/cart_state.dart';
import '../../logic/product/product_cubit.dart';
import '../../logic/product/product_state.dart';

/// Point-of-Sale screen with a responsive layout:
/// * Landscape / tablet → split view (products left 60%, cart right 40%).
/// * Portrait / phone   → single view with a bottom-sheet cart.
class PosScreen extends StatefulWidget {
  const PosScreen({super.key});

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    // Ensure products are loaded for the grid.
    context.read<ProductCubit>().loadProducts();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  String _fmt(double v) {
    final s = v.toInt().toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return 'Rp $buf';
  }

  String _fmtStock(double v) =>
      v == v.truncateToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Theme.of(context).colorScheme.error : null,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kasir (POS)'),
        centerTitle: true,
        actions: [
          // Cart badge — only visible in narrow layouts (bottom-sheet mode).
          BlocBuilder<CartCubit, CartState>(
            buildWhen: (p, c) => p.cartItems.length != c.cartItems.length,
            builder: (ctx, state) {
              if (MediaQuery.of(context).size.width >= 720) {
                return const SizedBox.shrink();
              }
              return IconButton(
                icon: Badge(
                  isLabelVisible: state.cartItems.isNotEmpty,
                  label: Text('${state.cartItems.length}'),
                  child: const Icon(Icons.shopping_cart_outlined),
                ),
                onPressed: () => _showCartSheet(context),
              );
            },
          ),
        ],
      ),
      body: BlocListener<CartCubit, CartState>(
        listener: _cartListener,
        child: LayoutBuilder(
          builder: (ctx, constraints) {
            if (constraints.maxWidth >= 720) {
              return _buildWideLayout(ctx);
            }
            return _buildNarrowLayout(ctx);
          },
        ),
      ),
    );
  }

  void _cartListener(BuildContext context, CartState state) {
    if (state.status == CartStatus.error && state.errorMessage != null) {
      _snack(state.errorMessage!, isError: true);
    }
    if (state.status == CartStatus.success &&
        state.successTransaction != null) {
      _showCheckoutSuccessDialog(context, state);
    }
  }

  // ── Wide (tablet) layout ─────────────────────────────────────────────────

  Widget _buildWideLayout(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        // Left: Products
        Expanded(
          flex: 6,
          child: Column(
            children: [
              _buildSearchBar(cs),
              Expanded(child: _buildProductGrid(cs)),
            ],
          ),
        ),
        // Divider
        VerticalDivider(width: 1, color: cs.outlineVariant),
        // Right: Cart
        Expanded(
          flex: 4,
          child: _buildCartPanel(cs),
        ),
      ],
    );
  }

  // ── Narrow (phone) layout ────────────────────────────────────────────────

  Widget _buildNarrowLayout(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        _buildSearchBar(cs),
        Expanded(child: _buildProductGrid(cs)),
        // Mini summary bar
        BlocBuilder<CartCubit, CartState>(
          builder: (ctx, state) {
            if (state.cartItems.isEmpty) return const SizedBox.shrink();
            return _buildMiniCartBar(ctx, state, cs);
          },
        ),
      ],
    );
  }

  Widget _buildMiniCartBar(
      BuildContext context, CartState state, ColorScheme cs) {
    return Material(
      elevation: 8,
      color: cs.primaryContainer,
      child: InkWell(
        onTap: () => _showCartSheet(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Badge(
                label: Text('${state.cartItems.length}'),
                child: Icon(Icons.shopping_cart,
                    color: cs.onPrimaryContainer, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  '${state.cartItems.length} item  •  ${_fmt(state.grandTotal)}',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: cs.onPrimaryContainer,
                  ),
                ),
              ),
              Icon(Icons.keyboard_arrow_up_rounded,
                  color: cs.onPrimaryContainer),
            ],
          ),
        ),
      ),
    );
  }

  void _showCartSheet(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        // Use BlocProvider.value so we share the same cubit instance.
        return BlocProvider.value(
          value: context.read<CartCubit>(),
          child: DraggableScrollableSheet(
            initialChildSize: 0.85,
            minChildSize: 0.4,
            maxChildSize: 0.95,
            expand: false,
            builder: (sheetCtx, scrollCtrl) {
              return BlocBuilder<CartCubit, CartState>(
                builder: (ctx2, state) {
                  return _CartSheetContent(
                    state: state,
                    scrollCtrl: scrollCtrl,
                    fmt: _fmt,
                    onCheckout: () => _onCheckoutPressed(ctx2),
                    onRemove: (i) => ctx2.read<CartCubit>().removeFromCart(i),
                    onQtyChanged: (i, q) =>
                        ctx2.read<CartCubit>().updateQty(i, q),
                    onUnitChanged: (i, u) =>
                        ctx2.read<CartCubit>().changeUnit(i, u),
                    onOverridePrice: (i, item) =>
                        _showOverridePriceDialog(ctx2, i, item),
                    onAmountPaidChanged: (v) =>
                        ctx2.read<CartCubit>().setAmountPaid(v),
                    onPaymentMethodChanged: (m) =>
                        ctx2.read<CartCubit>().setPaymentMethod(m),
                    onDiscountChanged: (d) =>
                        ctx2.read<CartCubit>().setDiscount(d),
                    onClear: () => ctx2.read<CartCubit>().clearCart(),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  // ── Search ───────────────────────────────────────────────────────────────

  Widget _buildSearchBar(ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      color: cs.surface,
      child: TextField(
        controller: _searchCtrl,
        decoration: InputDecoration(
          hintText: 'Cari nama / barcode produk...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchCtrl.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none),
          filled: true,
          fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.5),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        onChanged: (v) => setState(() => _searchQuery = v),
      ),
    );
  }

  // ── Product grid ─────────────────────────────────────────────────────────

  Widget _buildProductGrid(ColorScheme cs) {
    return BlocBuilder<ProductCubit, ProductState>(
      builder: (ctx, state) {
        if (state.status == ProductStatus.loading && state.products.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state.status == ProductStatus.error) {
          return Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.error_outline, size: 48, color: cs.error),
              const SizedBox(height: 12),
              Text(state.errorMessage ?? 'Gagal memuat produk',
                  style: TextStyle(color: cs.error)),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => ctx.read<ProductCubit>().loadProducts(),
                icon: const Icon(Icons.refresh),
                label: const Text('Coba Lagi'),
              ),
            ]),
          );
        }

        // Only show active products with at least one sellable unit.
        var products = state.products
            .where(
                (p) => p.isActive && p.units.any((u) => u.isSellable))
            .toList();

        // Apply local search.
        if (_searchQuery.isNotEmpty) {
          final q = _searchQuery.toLowerCase();
          products = products
              .where((p) =>
                  p.name.toLowerCase().contains(q) ||
                  (p.sku?.toLowerCase().contains(q) ?? false) ||
                  (p.barcode?.toLowerCase().contains(q) ?? false))
              .toList();
        }

        if (products.isEmpty) {
          return Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.inventory_2_outlined,
                  size: 56, color: cs.onSurface.withValues(alpha: 0.3)),
              const SizedBox(height: 12),
              Text(
                _searchQuery.isNotEmpty
                    ? 'Produk tidak ditemukan'
                    : 'Belum ada produk aktif',
                style:
                    TextStyle(color: cs.onSurface.withValues(alpha: 0.5)),
              ),
            ]),
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.all(12),
          gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 200,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 0.82,
          ),
          itemCount: products.length,
          itemBuilder: (_, i) => _ProductTile(
            product: products[i],
            onTap: () => context.read<CartCubit>().addToCart(products[i]),
            fmtStock: _fmtStock,
            fmt: _fmt,
          ),
        );
      },
    );
  }

  // ── Cart panel (used in wide layout) ──────────────────────────────────

  Widget _buildCartPanel(ColorScheme cs) {
    return BlocBuilder<CartCubit, CartState>(
      builder: (ctx, state) {
        return Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: cs.primaryContainer.withValues(alpha: 0.3),
              child: Row(
                children: [
                  Icon(Icons.shopping_cart,
                      color: cs.onPrimaryContainer, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Keranjang (${state.cartItems.length})',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: cs.onPrimaryContainer,
                    ),
                  ),
                  const Spacer(),
                  if (state.cartItems.isNotEmpty)
                    TextButton.icon(
                      onPressed: () => ctx.read<CartCubit>().clearCart(),
                      icon: Icon(Icons.delete_sweep_outlined,
                          size: 18, color: cs.error),
                      label: Text('Kosongkan',
                          style: TextStyle(fontSize: 12, color: cs.error)),
                      style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact),
                    ),
                ],
              ),
            ),

            // Cart items
            Expanded(
              child: state.cartItems.isEmpty
                  ? Center(
                      child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                        Icon(Icons.add_shopping_cart,
                            size: 48,
                            color: cs.onSurface.withValues(alpha: 0.2)),
                        const SizedBox(height: 8),
                        Text('Ketuk produk untuk menambahkan',
                            style: TextStyle(
                                color:
                                    cs.onSurface.withValues(alpha: 0.4))),
                      ]),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: state.cartItems.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (_, i) => _CartItemCard(
                        index: i,
                        item: state.cartItems[i],
                        fmt: _fmt,
                        onRemove: () =>
                            ctx.read<CartCubit>().removeFromCart(i),
                        onQtyChanged: (q) =>
                            ctx.read<CartCubit>().updateQty(i, q),
                        onUnitChanged: (u) =>
                            ctx.read<CartCubit>().changeUnit(i, u),
                        onOverridePrice: () =>
                            _showOverridePriceDialog(ctx, i, state.cartItems[i]),
                      ),
                    ),
            ),

            // Payment section
            _buildPaymentSection(ctx, state, cs),
          ],
        );
      },
    );
  }

  // ── Payment section (shared) ──────────────────────────────────────────

  Widget _buildPaymentSection(
      BuildContext context, CartState state, ColorScheme cs) {
    if (state.cartItems.isEmpty) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(top: BorderSide(color: cs.outlineVariant)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Totals
          _summaryRow('Subtotal', _fmt(state.totalAmount), cs),
          if (state.discountAmount > 0)
            _summaryRow('Diskon', '- ${_fmt(state.discountAmount)}', cs,
                valueColor: cs.error),
          const Divider(height: 14),
          _summaryRow('Total', _fmt(state.grandTotal), cs,
              isBold: true, valueColor: cs.primary),
          const SizedBox(height: 10),

          // Payment method chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: ['cash', 'transfer', 'qris', 'credit'].map((m) {
                final selected = state.paymentMethod == m;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(_paymentLabel(m)),
                    selected: selected,
                    onSelected: (_) =>
                        context.read<CartCubit>().setPaymentMethod(m),
                    selectedColor: cs.primaryContainer,
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight:
                          selected ? FontWeight.w600 : FontWeight.w400,
                      color:
                          selected ? cs.onPrimaryContainer : cs.onSurface,
                    ),
                    visualDensity: VisualDensity.compact,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 10),

          // Amount paid + quick buttons
          _buildAmountPaidField(context, state, cs),

          if (state.amountPaid > 0) ...[
            const SizedBox(height: 8),
            _summaryRow('Kembalian', _fmt(state.changeAmount), cs,
                isBold: true,
                valueColor:
                    state.changeAmount >= 0 ? Colors.green : cs.error),
          ],

          const SizedBox(height: 12),

          // Checkout button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton.icon(
              onPressed: state.status == CartStatus.loading
                  ? null
                  : () => _onCheckoutPressed(context),
              icon: state.status == CartStatus.loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.payment_rounded),
              label: Text(
                state.status == CartStatus.loading
                    ? 'Memproses...'
                    : 'Bayar Sekarang',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmountPaidField(
      BuildContext context, CartState state, ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          initialValue: state.amountPaid > 0
              ? state.amountPaid.toStringAsFixed(0)
              : null,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            labelText: 'Uang Bayar',
            prefixText: 'Rp ',
            prefixIcon: const Icon(Icons.payments_outlined),
            border:
                OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            isDense: true,
          ),
          onChanged: (v) {
            final amount = double.tryParse(v) ?? 0.0;
            context.read<CartCubit>().setAmountPaid(amount);
          },
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            _quickPayChip('Uang Pas', state.grandTotal, context, cs),
            _quickPayChip('20rb', 20000, context, cs),
            _quickPayChip('50rb', 50000, context, cs),
            _quickPayChip('100rb', 100000, context, cs),
          ],
        ),
      ],
    );
  }

  Widget _quickPayChip(
      String label, double amount, BuildContext context, ColorScheme cs) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 11)),
      onPressed: () => context.read<CartCubit>().setAmountPaid(amount),
      visualDensity: VisualDensity.compact,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      side: BorderSide(color: cs.outlineVariant),
    );
  }

  Widget _summaryRow(String label, String value, ColorScheme cs,
      {bool isBold = false, Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isBold ? FontWeight.w700 : FontWeight.w400,
                color: cs.onSurface.withValues(alpha: 0.7),
              )),
          Text(value,
              style: TextStyle(
                fontSize: isBold ? 16 : 13,
                fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
                color: valueColor ?? cs.onSurface,
              )),
        ],
      ),
    );
  }

  String _paymentLabel(String method) {
    switch (method) {
      case 'cash':
        return 'Tunai';
      case 'transfer':
        return 'Transfer';
      case 'qris':
        return 'QRIS';
      case 'credit':
        return 'Kredit';
      default:
        return method;
    }
  }

  // ── Checkout flow ────────────────────────────────────────────────────────

  void _onCheckoutPressed(BuildContext context) {
    final cubit = context.read<CartCubit>();
    final state = cubit.state;

    if (state.cartItems.isEmpty) {
      _snack('Keranjang belanja masih kosong.', isError: true);
      return;
    }
    if (state.amountPaid < state.grandTotal) {
      _snack('Jumlah bayar kurang dari total belanja.', isError: true);
      return;
    }

    // Confirmation dialog
    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Konfirmasi Pembayaran',
              textAlign: TextAlign.center),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _dialogRow('Total Belanja', _fmt(state.grandTotal)),
              _dialogRow('Bayar (${_paymentLabel(state.paymentMethod)})',
                  _fmt(state.amountPaid)),
              const Divider(),
              _dialogRow('Kembalian', _fmt(state.changeAmount)),
            ],
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.pop(dialogCtx),
              style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  minimumSize: const Size(100, 42)),
              child: const Text('Batal'),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogCtx);
                cubit.checkout();
              },
              style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  minimumSize: const Size(100, 42)),
              child: const Text('Bayar'),
            ),
          ],
        );
      },
    );
  }

  Widget _dialogRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14)),
          Text(value,
              style:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  // ── Success dialog ──────────────────────────────────────────────────────

  void _showCheckoutSuccessDialog(BuildContext context, CartState state) {
    final tx = state.successTransaction!;
    final cs = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          icon: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.check_circle_rounded,
                color: Colors.green.shade600, size: 40),
          ),
          title: const Text('Transaksi Berhasil!',
              textAlign: TextAlign.center),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Text(tx.invoiceNo,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 16)),
                    const SizedBox(height: 10),
                    _dialogRow('Total', _fmt(tx.totalAmount)),
                    if (tx.discountAmount > 0)
                      _dialogRow('Diskon', '- ${_fmt(tx.discountAmount)}'),
                    _dialogRow('Bayar', _fmt(tx.amountPaid)),
                    const Divider(height: 16),
                    _dialogRow('Kembalian', _fmt(tx.changeAmount)),
                  ],
                ),
              ),
            ],
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogCtx);
                context.read<CartCubit>().clearCart();
                // Close the bottom sheet too if it's open
                if (Navigator.of(context).canPop()) {
                  // We're probably in the bottom sheet — pop it
                }
              },
              style: FilledButton.styleFrom(
                minimumSize: const Size(180, 46),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Selesai',
                  style: TextStyle(fontSize: 15)),
            ),
          ],
        );
      },
    );
  }

  // ── Override price dialog ────────────────────────────────────────────────

  void _showOverridePriceDialog(
      BuildContext context, int index, CartItemModel item) {
    final priceCtrl = TextEditingController(
        text: item.hargaJualAktual.toStringAsFixed(0));
    final reasonCtrl =
        TextEditingController(text: item.priceOverrideReason ?? '');
    final formKey = GlobalKey<FormState>();
    final minAllowed = item.product.hargaJualMin * item.unit.conversionToBase;

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Ubah Harga: ${item.product.name}',
              style: const TextStyle(fontSize: 16)),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Min. harga (${item.unit.unitName}): ${_fmt(minAllowed)}',
                  style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.5)),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: priceCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: 'Harga Baru',
                    prefixText: 'Rp ',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Wajib diisi';
                    final price = double.tryParse(v.trim());
                    if (price == null || price < minAllowed) {
                      return 'Min. ${_fmt(minAllowed)}';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: reasonCtrl,
                  decoration: InputDecoration(
                    labelText: 'Alasan (opsional)',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () {
                if (!formKey.currentState!.validate()) return;
                final price = double.tryParse(priceCtrl.text.trim()) ?? 0;
                context.read<CartCubit>().overridePrice(
                      index,
                      price,
                      reasonCtrl.text.trim(),
                    );
                Navigator.pop(dialogCtx);
              },
              child: const Text('Simpan'),
            ),
          ],
        );
      },
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Extracted widgets
// ════════════════════════════════════════════════════════════════════════════

/// A product tile for the POS product grid.
class _ProductTile extends StatelessWidget {
  final ProductModel product;
  final VoidCallback onTap;
  final String Function(double) fmtStock;
  final String Function(double) fmt;

  const _ProductTile({
    required this.product,
    required this.onTap,
    required this.fmtStock,
    required this.fmt,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final lowStock = product.stockAlertQty != null &&
        product.currentStock <= product.stockAlertQty!;

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon
              Center(
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: cs.primaryContainer.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.inventory_2_rounded,
                      color: cs.onPrimaryContainer, size: 22),
                ),
              ),
              const SizedBox(height: 8),
              // Name
              Text(
                product.name,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 13),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              // SKU
              if (product.sku != null && product.sku!.isNotEmpty)
                Text(product.sku!,
                    style: TextStyle(
                        fontSize: 11,
                        color: cs.onSurface.withValues(alpha: 0.5))),
              const Spacer(),
              // Stock
              Row(
                children: [
                  Icon(
                    lowStock
                        ? Icons.warning_amber_rounded
                        : Icons.inventory_outlined,
                    size: 14,
                    color: lowStock ? Colors.orange : cs.primary,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '${fmtStock(product.currentStock)} ${product.baseUnit}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: lowStock ? Colors.orange : cs.primary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              // Price
              Text(
                fmt(product.hargaJualMin),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: cs.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A single cart item card.
class _CartItemCard extends StatelessWidget {
  final int index;
  final CartItemModel item;
  final String Function(double) fmt;
  final VoidCallback onRemove;
  final ValueChanged<double> onQtyChanged;
  final ValueChanged<ProductUnitModel> onUnitChanged;
  final VoidCallback onOverridePrice;

  const _CartItemCard({
    required this.index,
    required this.item,
    required this.fmt,
    required this.onRemove,
    required this.onQtyChanged,
    required this.onUnitChanged,
    required this.onOverridePrice,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final sellableUnits =
        item.product.units.where((u) => u.isSellable).toList();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Name + remove
            Row(
              children: [
                Expanded(
                  child: Text(item.product.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ),
                InkWell(
                  onTap: onRemove,
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(Icons.close, size: 16, color: cs.error),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            // Unit selector + qty controls
            Row(
              children: [
                // Unit dropdown
                Expanded(
                  child: DropdownButtonFormField<ProductUnitModel>(
                    initialValue: item.unit,
                    isExpanded: true,
                    isDense: true,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                      isDense: true,
                    ),
                    items: sellableUnits.map((u) {
                      return DropdownMenuItem<ProductUnitModel>(
                        value: u,
                        child: Text(u.unitName,
                            style: const TextStyle(fontSize: 12)),
                      );
                    }).toList(),
                    onChanged: (u) {
                      if (u != null) onUnitChanged(u);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                // Qty -/+
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: cs.outlineVariant),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _qtyBtn(Icons.remove, () {
                        if (item.qty > 1) onQtyChanged(item.qty - 1);
                      }, cs),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Text(
                          item.qty == item.qty.truncateToDouble()
                              ? item.qty.toInt().toString()
                              : item.qty.toStringAsFixed(1),
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                      ),
                      _qtyBtn(Icons.add, () => onQtyChanged(item.qty + 1), cs),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            // Price + subtotal
            Row(
              children: [
                // Tappable price
                InkWell(
                  onTap: onOverridePrice,
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: item.isPriceOverridden
                          ? Colors.orange.shade50
                          : cs.surfaceContainerHighest.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(6),
                      border: item.isPriceOverridden
                          ? Border.all(color: Colors.orange.shade200)
                          : null,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '@ ${fmt(item.hargaJualAktual)}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: item.isPriceOverridden
                                ? Colors.orange.shade700
                                : cs.onSurface.withValues(alpha: 0.7),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.edit_outlined,
                            size: 12,
                            color: item.isPriceOverridden
                                ? Colors.orange.shade700
                                : cs.onSurface.withValues(alpha: 0.4)),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  fmt(item.subtotal),
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: cs.primary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _qtyBtn(IconData icon, VoidCallback onPressed, ColorScheme cs) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Icon(icon, size: 16, color: cs.primary),
      ),
    );
  }
}

/// Content widget for the bottom-sheet cart on narrow screens.
class _CartSheetContent extends StatelessWidget {
  final CartState state;
  final ScrollController scrollCtrl;
  final String Function(double) fmt;
  final VoidCallback onCheckout;
  final ValueChanged<int> onRemove;
  final void Function(int, double) onQtyChanged;
  final void Function(int, ProductUnitModel) onUnitChanged;
  final void Function(int, CartItemModel) onOverridePrice;
  final ValueChanged<double> onAmountPaidChanged;
  final ValueChanged<String> onPaymentMethodChanged;
  final ValueChanged<double> onDiscountChanged;
  final VoidCallback onClear;

  const _CartSheetContent({
    required this.state,
    required this.scrollCtrl,
    required this.fmt,
    required this.onCheckout,
    required this.onRemove,
    required this.onQtyChanged,
    required this.onUnitChanged,
    required this.onOverridePrice,
    required this.onAmountPaidChanged,
    required this.onPaymentMethodChanged,
    required this.onDiscountChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        // Drag handle
        Container(
          width: 40,
          height: 4,
          margin: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: cs.onSurface.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        // Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Text('Keranjang (${state.cartItems.length})',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 16)),
              const Spacer(),
              if (state.cartItems.isNotEmpty)
                TextButton.icon(
                  onPressed: () {
                    onClear();
                    Navigator.pop(context);
                  },
                  icon: Icon(Icons.delete_sweep_outlined,
                      size: 16, color: cs.error),
                  label: Text('Kosongkan',
                      style: TextStyle(fontSize: 12, color: cs.error)),
                ),
            ],
          ),
        ),
        const Divider(),
        // Items
        Expanded(
          child: state.cartItems.isEmpty
              ? Center(
                  child: Text('Keranjang kosong',
                      style: TextStyle(
                          color: cs.onSurface.withValues(alpha: 0.4))))
              : ListView.separated(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: state.cartItems.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _CartItemCard(
                    index: i,
                    item: state.cartItems[i],
                    fmt: fmt,
                    onRemove: () => onRemove(i),
                    onQtyChanged: (q) => onQtyChanged(i, q),
                    onUnitChanged: (u) => onUnitChanged(i, u),
                    onOverridePrice: () => onOverridePrice(i, state.cartItems[i]),
                  ),
                ),
        ),
        // Payment section inside sheet
        if (state.cartItems.isNotEmpty)
          _SheetPaymentSection(
            state: state,
            fmt: fmt,
            onCheckout: onCheckout,
            onAmountPaidChanged: onAmountPaidChanged,
            onPaymentMethodChanged: onPaymentMethodChanged,
          ),
      ],
    );
  }
}

class _SheetPaymentSection extends StatelessWidget {
  final CartState state;
  final String Function(double) fmt;
  final VoidCallback onCheckout;
  final ValueChanged<double> onAmountPaidChanged;
  final ValueChanged<String> onPaymentMethodChanged;

  const _SheetPaymentSection({
    required this.state,
    required this.fmt,
    required this.onCheckout,
    required this.onAmountPaidChanged,
    required this.onPaymentMethodChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(top: BorderSide(color: cs.outlineVariant)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Total
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              Text(fmt(state.grandTotal),
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: cs.primary)),
            ],
          ),
          const SizedBox(height: 10),
          // Payment method chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: ['cash', 'transfer', 'qris', 'credit'].map((m) {
                final selected = state.paymentMethod == m;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(_paymentLabel(m)),
                    selected: selected,
                    onSelected: (_) => onPaymentMethodChanged(m),
                    selectedColor: cs.primaryContainer,
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight:
                          selected ? FontWeight.w600 : FontWeight.w400,
                    ),
                    visualDensity: VisualDensity.compact,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 10),
          // Amount paid
          TextFormField(
            initialValue: state.amountPaid > 0
                ? state.amountPaid.toStringAsFixed(0)
                : null,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: 'Uang Bayar',
              prefixText: 'Rp ',
              prefixIcon: const Icon(Icons.payments_outlined),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              isDense: true,
            ),
            onChanged: (v) =>
                onAmountPaidChanged(double.tryParse(v) ?? 0.0),
          ),
          const SizedBox(height: 8),
          // Quick pay
          Wrap(
            spacing: 8,
            children: [
              _quickChip('Uang Pas', state.grandTotal),
              _quickChip('50rb', 50000),
              _quickChip('100rb', 100000),
            ],
          ),
          if (state.amountPaid > 0) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Kembalian',
                    style: TextStyle(
                        fontSize: 13,
                        color: cs.onSurface.withValues(alpha: 0.7))),
                Text(fmt(state.changeAmount),
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.green.shade700)),
              ],
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton.icon(
              onPressed:
                  state.status == CartStatus.loading ? null : onCheckout,
              icon: state.status == CartStatus.loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.payment_rounded),
              label: Text(
                state.status == CartStatus.loading
                    ? 'Memproses...'
                    : 'Bayar Sekarang',
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600),
              ),
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickChip(String label, double amount) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 11)),
      onPressed: () => onAmountPaidChanged(amount),
      visualDensity: VisualDensity.compact,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    );
  }

  String _paymentLabel(String method) {
    switch (method) {
      case 'cash':
        return 'Tunai';
      case 'transfer':
        return 'Transfer';
      case 'qris':
        return 'QRIS';
      case 'credit':
        return 'Kredit';
      default:
        return method;
    }
  }
}
