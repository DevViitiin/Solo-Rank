import 'package:firebase_auth/firebase_auth.dart';

/// Serviço de autenticação via Firebase Auth.
///
/// Encapsula todas as operações de autenticação do app:
/// - Criação de conta com email/senha
/// - Login e logout
/// - Recuperação de senha por email
/// - Tratamento de erros com mensagens em português
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Stream do usuário atual
  Stream<User?> get userStream => _auth.authStateChanges();

  /// Usuário atual
  User? get currentUser => _auth.currentUser;

  /// UID do usuário atual
  String? get currentUserId => _auth.currentUser?.uid;

  /// Cria um novo usuário no Firebase Authentication
  /// 
  /// Parâmetros:
  /// - [email]: Email do usuário
  /// - [password]: Senha do usuário
  /// 
  /// Retorna o UID do usuário criado
  /// 
  /// Lança exceções em caso de erro
  Future<String> createUser(String email, String password) async {
    try {
      final UserCredential credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Aguarda um pouco para garantir que o usuário foi completamente criado
      await Future.delayed(const Duration(milliseconds: 500));

      if (credential.user == null) {
        throw Exception('Erro ao criar usuário');
      }

      return credential.user!.uid;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      // Remove a referência ao erro de tipo que pode estar causando o problema
      print('Erro detalhado ao criar usuário: $e');
      throw Exception('Erro ao criar usuário. Por favor, tente novamente.');
    }
  }

  /// Faz login com email e senha
  /// 
  /// Parâmetros:
  /// - [email]: Email do usuário
  /// - [password]: Senha do usuário
  /// 
  /// Retorna o UID do usuário
  /// 
  /// Lança exceções em caso de erro
  Future<String> signIn(String email, String password) async {
    try {
      final UserCredential credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user == null) {
        throw Exception('Erro ao fazer login');
      }

      return credential.user!.uid;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      print('Erro detalhado ao fazer login: $e');
      throw Exception('Erro ao fazer login. Por favor, tente novamente.');
    }
  }

  /// Faz logout do usuário
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      print('Erro ao fazer logout: $e');
      throw Exception('Erro ao fazer logout');
    }
  }

  /// Envia email de recuperação de senha
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      print('Erro ao enviar email de recuperação: $e');
      throw Exception('Erro ao enviar email de recuperação');
    }
  }

  /// Converte códigos de erro do Firebase Auth em mensagens amigáveis em português.
  ///
  /// Cobre os erros mais comuns: senha fraca, email duplicado, usuário
  /// não encontrado, erro de rede, etc.
  String _handleAuthException(FirebaseAuthException e) {
    print('FirebaseAuthException: code=${e.code}, message=${e.message}');
    
    switch (e.code) {
      case 'weak-password':
        return 'A senha é muito fraca';
      case 'email-already-in-use':
        return 'Este email já está em uso';
      case 'invalid-email':
        return 'Email inválido';
      case 'user-not-found':
        return 'Usuário não encontrado';
      case 'wrong-password':
        return 'Senha incorreta';
      case 'user-disabled':
        return 'Usuário desabilitado';
      case 'too-many-requests':
        return 'Muitas tentativas. Tente novamente mais tarde';
      case 'operation-not-allowed':
        return 'Operação não permitida';
      case 'network-request-failed':
        return 'Erro de conexão. Verifique sua internet';
      default:
        return 'Erro de autenticação: ${e.message ?? e.code}';
    }
  }
}
