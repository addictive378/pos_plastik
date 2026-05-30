import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/supabase_client.dart';
import 'data/repositories/auth_repository.dart';
import 'data/repositories/product_repository.dart';
import 'data/repositories/stock_mutation_repository.dart';
import 'data/repositories/transaction_repository.dart';
import 'logic/auth/auth_cubit.dart';
import 'logic/auth/auth_state.dart';
import 'logic/inventory/stock_mutation_cubit.dart';
import 'logic/pos/cart_cubit.dart';
import 'logic/product/product_cubit.dart';
import 'presentation/auth/login_screen.dart';
import 'presentation/pos/pos_screen.dart';
import 'presentation/product/product_list_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseConfig.init();
  final sharedPreferences = await SharedPreferences.getInstance();
  runApp(MyApp(sharedPreferences: sharedPreferences));
}

class MyApp extends StatelessWidget {
  final SharedPreferences sharedPreferences;

  const MyApp({super.key, required this.sharedPreferences});

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<AuthRepository>(
          create: (_) => AuthRepository(),
        ),
        RepositoryProvider<ProductRepository>(
          create: (_) => ProductRepository(),
        ),
        RepositoryProvider<StockMutationRepository>(
          create: (_) => StockMutationRepository(),
        ),
        RepositoryProvider<TransactionRepository>(
          create: (_) => TransactionRepository(),
        ),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<AuthCubit>(
            create: (context) => AuthCubit(
              authRepository: context.read<AuthRepository>(),
              sharedPreferences: sharedPreferences,
            ),
          ),
          BlocProvider<ProductCubit>(
            create: (context) => ProductCubit(
              productRepository: context.read<ProductRepository>(),
            ),
          ),
          BlocProvider<StockMutationCubit>(
            create: (context) => StockMutationCubit(
              productRepository: context.read<ProductRepository>(),
              stockMutationRepository:
                  context.read<StockMutationRepository>(),
            ),
          ),
          BlocProvider<CartCubit>(
            create: (context) => CartCubit(
              transactionRepository:
                  context.read<TransactionRepository>(),
            ),
          ),
        ],
        child: MaterialApp(
          title: 'POS Toko Plastik',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
            useMaterial3: true,
          ),
          home: BlocBuilder<AuthCubit, AuthState>(
            builder: (context, state) {
              if (state.status == AuthStatus.authenticated) {
                return const _DashboardScreen();
              }
              return const LoginScreen();
            },
          ),
        ),
      ),
    );
  }
}

/// Simple bottom-navigation dashboard that houses the main app sections.
class _DashboardScreen extends StatefulWidget {
  const _DashboardScreen();

  @override
  State<_DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<_DashboardScreen> {
  int _currentIndex = 0;

  static const _screens = <Widget>[
    PosScreen(),
    ProductListScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.point_of_sale_outlined),
            selectedIcon: Icon(Icons.point_of_sale),
            label: 'Kasir',
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2),
            label: 'Produk',
          ),
        ],
      ),
    );
  }
}


