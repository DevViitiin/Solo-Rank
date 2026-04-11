/// Ponto de entrada do aplicativo Dracoryx (Solo-Rank).
///
/// Inicializa Firebase, configura o cache local e registra os providers
/// de estado antes de renderizar a árvore de widgets.
library;

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:monarch/core/auth_wrapper.dart';
import 'package:monarch/services/cache_service.dart';
import 'package:monarch/services/database_service.dart';
import 'package:provider/provider.dart';
import 'providers/user_provider.dart';

/// Inicializa dependências essenciais e executa o app.
///
/// Ordem de inicialização:
/// 1. Flutter bindings
/// 2. Firebase
/// 3. Data de teste (para desenvolvimento)
/// 4. Cache local (Hive)
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  DatabaseService.testDate = DateTime(2026, 3, 17);
  await CacheService.instance.init();
  
  runApp(const MyApp());
}

/// Widget raiz do aplicativo Dracoryx.
///
/// Configura o [MultiProvider] com [UserProvider] para gerenciamento
/// de estado global, e define o [MaterialApp] com tema escuro
/// customizado baseado no sistema de ranks.
class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => UserProvider()),
      ],
      child: MaterialApp(
        title: 'Dracoryx - Sistema de Evolução',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          fontFamily: 'Roboto',
          // Cores customizadas
          scaffoldBackgroundColor: const Color(0xFF120A1C),
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFFAB47BC),
            secondary: Color(0xFFCE93D8),
            surface: Color(0xFF18101F),
            background: Color(0xFF120A1C),
          ),
        ),
        home: const AuthWrapper(),
      ),
    );
  }
}
