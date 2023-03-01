import 'package:effektio/features/chat/pages/chat_page.dart';
import 'package:effektio/features/faq/pages/faq_page.dart';
import 'package:effektio/features/home/controllers/home_controller.dart';
import 'package:effektio/features/news/pages/news_page.dart';
import 'package:effektio/features/todo/pages/todo_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class HomeWidget extends ConsumerWidget {
  final TabController controller;
  const HomeWidget(this.controller, {super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final client = ref.watch(clientProvider).requireValue;
    return DefaultTabController(
      length: 4,
      key: const Key('bottom-bar'),
      child: TabBarView(
        controller: controller,
        children: <Widget>[
          const NewsPage(),
          FaqPage(client: client),
          ToDoPage(client: client),
          ChatPage(client: client),
        ],
      ),
    );
  }
}