import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/stock_mutation_model.dart';

class StockMutationRepository {
  final SupabaseClient _client;

  StockMutationRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  /// Current authenticated user's ID.
  String get _ownerId => _client.auth.currentUser!.id;

  /// Insert a new purchase mutation into `stock_mutations`.
  ///
  /// The database trigger handles updating `products.current_stock`
  /// and `products.harga_modal_terakhir`, so we only need to insert here.
  Future<StockMutationModel> createPurchaseMutation(
      StockMutationModel mutation) async {
    final json = mutation.toInsertJson();
    json['owner_id'] = _ownerId;

    final response = await _client
        .from('stock_mutations')
        .insert(json)
        .select()
        .single();

    return StockMutationModel.fromJson(response);
  }
}
