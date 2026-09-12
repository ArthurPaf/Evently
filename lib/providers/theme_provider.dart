import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _chavePreferencia = 'modo_escuro';

class ThemeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    // Carrega a preferência salva de forma assíncrona; enquanto isso,
    // começa no modo claro (padrão).
    _carregarPreferencia();
    return ThemeMode.light;
  }

  Future<void> _carregarPreferencia() async {
    final prefs = await SharedPreferences.getInstance();
    final escuro = prefs.getBool(_chavePreferencia) ?? false;
    state = escuro ? ThemeMode.dark : ThemeMode.light;
  }

  Future<void> alternar(bool escuro) async {
    state = escuro ? ThemeMode.dark : ThemeMode.light;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_chavePreferencia, escuro);
  }

  bool get isEscuro => state == ThemeMode.dark;
}

final themeProvider = NotifierProvider<ThemeNotifier, ThemeMode>(() {
  return ThemeNotifier();
});