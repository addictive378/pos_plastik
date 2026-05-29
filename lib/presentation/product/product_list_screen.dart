import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../logic/product/product_cubit.dart';
import '../../logic/product/product_state.dart';
import '../../data/models/product_model.dart';
import 'add_product_screen.dart';
import '../inventory/restock_screen.dart';

class ProductListScreen extends StatefulWidget {
  const ProductListScreen({super.key});

  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    context.read<ProductCubit>().loadProducts();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Manajemen Produk'), centerTitle: true),
      body: Column(
        children: [
          _buildSearchAndFilter(cs),
          Expanded(child: _buildProductList(cs)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _navigateToAdd(context),
        icon: const Icon(Icons.add),
        label: const Text('Tambah Produk'),
      ),
    );
  }

  Widget _buildSearchAndFilter(ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      decoration: BoxDecoration(
        color: cs.surface,
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Column(
        children: [
          TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: 'Cari produk...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: BlocBuilder<ProductCubit, ProductState>(
                buildWhen: (p, c) => p.searchQuery != c.searchQuery,
                builder: (ctx, s) => s.searchQuery.isEmpty
                    ? const SizedBox.shrink()
                    : IconButton(icon: const Icon(Icons.clear), onPressed: () { _searchCtrl.clear(); ctx.read<ProductCubit>().setSearchQuery(''); }),
              ),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              filled: true,
              fillColor: cs.surfaceContainerHighest.withOpacity(0.5),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            onChanged: (v) => context.read<ProductCubit>().setSearchQuery(v),
          ),
          const SizedBox(height: 10),
          BlocBuilder<ProductCubit, ProductState>(
            buildWhen: (p, c) => p.activeFilter != c.activeFilter,
            builder: (ctx, s) => Row(children: [
              _chip('Semua', s.activeFilter == ProductActiveFilter.all, () => ctx.read<ProductCubit>().setActiveFilter(ProductActiveFilter.all), cs),
              const SizedBox(width: 8),
              _chip('Aktif', s.activeFilter == ProductActiveFilter.active, () => ctx.read<ProductCubit>().setActiveFilter(ProductActiveFilter.active), cs),
              const SizedBox(width: 8),
              _chip('Non-Aktif', s.activeFilter == ProductActiveFilter.inactive, () => ctx.read<ProductCubit>().setActiveFilter(ProductActiveFilter.inactive), cs),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, bool sel, VoidCallback onTap, ColorScheme cs) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: sel ? cs.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: sel ? cs.primary : cs.outline.withOpacity(0.4)),
        ),
        child: Text(label, style: TextStyle(fontSize: 13, fontWeight: sel ? FontWeight.w600 : FontWeight.w400, color: sel ? cs.onPrimary : cs.onSurface)),
      ),
    );
  }

  Widget _buildProductList(ColorScheme cs) {
    return BlocBuilder<ProductCubit, ProductState>(
      builder: (ctx, state) {
        if (state.status == ProductStatus.loading && state.products.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state.status == ProductStatus.error) {
          return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.error_outline, size: 56, color: cs.error),
            const SizedBox(height: 16),
            Text(state.errorMessage ?? 'Terjadi kesalahan', textAlign: TextAlign.center, style: TextStyle(color: cs.error)),
            const SizedBox(height: 16),
            FilledButton.icon(onPressed: () => ctx.read<ProductCubit>().loadProducts(), icon: const Icon(Icons.refresh), label: const Text('Coba Lagi')),
          ]));
        }
        final products = state.filteredProducts;
        if (products.isEmpty) {
          return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.inventory_2_outlined, size: 64, color: cs.onSurface.withOpacity(0.3)),
            const SizedBox(height: 16),
            Text(state.searchQuery.isNotEmpty ? 'Produk tidak ditemukan' : 'Belum ada produk', style: TextStyle(fontSize: 16, color: cs.onSurface.withOpacity(0.5))),
          ]));
        }
        return RefreshIndicator(
          onRefresh: () => ctx.read<ProductCubit>().loadProducts(),
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: products.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) => _ProductCard(product: products[i]),
          ),
        );
      },
    );
  }

  Future<void> _navigateToAdd(BuildContext context) async {
    final result = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => const AddProductScreen()));
    if (result == true && mounted) context.read<ProductCubit>().loadProducts();
  }
}

class _ProductCard extends StatelessWidget {
  final ProductModel product;
  const _ProductCard({required this.product});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          final result = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => AddProductScreen(product: product)));
          if (result == true && context.mounted) context.read<ProductCubit>().loadProducts();
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(color: cs.primaryContainer, borderRadius: BorderRadius.circular(10)),
              child: Icon(Icons.inventory_2, color: cs.onPrimaryContainer),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(product.name, style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis)),
                if (!product.isActive) Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: cs.errorContainer, borderRadius: BorderRadius.circular(6)),
                  child: Text('Non-aktif', style: tt.labelSmall?.copyWith(color: cs.onErrorContainer)),
                ),
              ]),
              const SizedBox(height: 4),
              Text('Stok: ${_fmtStock(product.currentStock)} ${product.baseUnit}${product.sku != null && product.sku!.isNotEmpty ? '  •  SKU: ${product.sku}' : ''}', style: tt.bodySmall?.copyWith(color: cs.onSurface.withOpacity(0.6))),
              const SizedBox(height: 2),
              Text('Satuan: ${product.units.length} jenis', style: tt.bodySmall?.copyWith(color: cs.primary)),
            ])),
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, color: cs.onSurface.withOpacity(0.5)),
              onSelected: (v) {
                if (v == 'delete') _confirmDelete(context);
                if (v == 'restock') _navigateToRestock(context);
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'restock',
                  child: Row(children: [
                    Icon(Icons.add_shopping_cart_outlined, color: Colors.teal, size: 20),
                    SizedBox(width: 8),
                    Text('Tambah Stok (Restock)'),
                  ]),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(children: [
                    Icon(Icons.delete_outline, color: Colors.red, size: 20),
                    SizedBox(width: 8),
                    Text('Hapus'),
                  ]),
                ),
              ],
            ),
          ]),
        ),
      ),
    );
  }

  String _fmtStock(double v) => v == v.truncateToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

  void _confirmDelete(BuildContext context) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Hapus Produk'),
      content: Text('Yakin ingin menghapus "${product.name}"?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
          onPressed: () { Navigator.pop(ctx); context.read<ProductCubit>().deleteProduct(product.id!); },
          child: const Text('Hapus'),
        ),
      ],
    ));
  }

  Future<void> _navigateToRestock(BuildContext context) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => RestockScreen(initialProduct: product),
      ),
    );
    if (result == true && context.mounted) {
      context.read<ProductCubit>().loadProducts();
    }
  }
}
