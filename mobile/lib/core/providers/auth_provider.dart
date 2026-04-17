import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../api/api_client.dart';
import '../models/user.dart';

class AuthState {
  final User? user;
  final bool isLoading;
  final String? error;

  const AuthState({this.user, this.isLoading = false, this.error});

  bool get isAuthenticated => user != null;
  AuthState copyWith({User? user, bool? isLoading, String? error}) =>
      AuthState(
        user: user ?? this.user,
        isLoading: isLoading ?? this.isLoading,
        error: error,
      );
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState());

  Future<void> login(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final res = await ApiClient.instance.post('/auth/login', data: {
        'email': email,
        'password': password,
      });
      await ApiClient.saveToken(res.data['token']);
      state = AuthState(user: User.fromJson(res.data['user']));
    } on DioException catch (e) {
      String message = 'Email ou mot de passe incorrect';
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.unknown) {
        message = 'Impossible de contacter le serveur. Vérifiez votre connexion.';
      } else if (e.response?.data?['message'] != null) {
        message = e.response!.data['message'];
      }
      state = state.copyWith(isLoading: false, error: message);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Erreur inattendue : $e');
    }
  }

  Future<void> register(String name, String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await ApiClient.instance.post('/auth/register', data: {
        'name': name,
        'email': email,
        'password': password,
      });
      // Inscription OK → connexion automatique
      await login(email, password);
    } on DioException catch (e) {
      String message = 'Erreur lors de l\'inscription';
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.unknown) {
        message = 'Impossible de contacter le serveur. Vérifiez votre connexion.';
      } else if (e.response?.data?['errors'] != null) {
        // Erreurs de validation AdonisJS (tableau)
        final errors = e.response!.data['errors'] as List<dynamic>;
        message = errors.map((err) => err['message']).join('\n');
      } else if (e.response?.data?['message'] != null) {
        message = e.response!.data['message'];
      }
      state = state.copyWith(isLoading: false, error: message);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Erreur inattendue : $e');
    }
  }

  Future<void> logout() async {
    try {
      await ApiClient.instance.post('/auth/logout');
    } catch (_) {}
    await ApiClient.deleteToken();
    state = const AuthState();
  }

  Future<void> fetchMe() async {
    final token = await ApiClient.getToken();
    if (token == null) return;
    try {
      final res = await ApiClient.instance.get('/auth/me');
      state = AuthState(user: User.fromJson(res.data));
    } on DioException catch (e) {
      // Supprimer le token seulement si le serveur dit explicitement non autorisé
      if (e.response?.statusCode == 401) {
        await ApiClient.deleteToken();
      }
      // Erreur réseau : on garde l'état tel quel
    } catch (_) {}
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(),
);
