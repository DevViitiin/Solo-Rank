import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:monarch/auth_wrapper.dart';
import 'package:monarch/services/cache_service.dart';
import 'package:provider/provider.dart';
import 'providers/user_provider.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await CacheService.instance.init();
  
  runApp(const MyApp());
}

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
