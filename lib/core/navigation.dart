import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AppTab { map, site, crew, market, settings }

final navProvider = NotifierProvider<NavController, AppTab>(NavController.new);

class NavController extends Notifier<AppTab> {
  @override
  AppTab build() => AppTab.site;

  void go(AppTab tab) => state = tab;
}
