import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/supabase_client.dart';
import 'data/repositories/auth_repository.dart';
import 'data/repositories/product_repository.dart';
import 'logic/auth/auth_cubit.dart';
import 'logic/auth/auth_state.dart';
import 'logic/product/product_cubit.dart';
import 'presentation/auth/login_screen.dart';
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
                return const ProductListScreen();
              }
              return const LoginScreen();
            },
          ),
        ),
      ),
    );
  }
}

