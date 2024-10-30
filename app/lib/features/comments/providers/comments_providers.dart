import 'dart:async';

import 'package:acter_flutter_sdk/acter_flutter_sdk_ffi.dart'
    show Comment, CommentsManager, NewsEntry;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

final _log = Logger('a3::comments::manager');

final commentsManagerProvider = AsyncNotifierProvider.autoDispose.family<
    AsyncCommentsManagerNotifier, CommentsManager, Future<CommentsManager>>(
  () => AsyncCommentsManagerNotifier(),
);

class AsyncCommentsManagerNotifier extends AutoDisposeFamilyAsyncNotifier<
    CommentsManager, Future<CommentsManager>> {
  late Stream<bool> _listener;
  late StreamSubscription<void> _poller;

  @override
  FutureOr<CommentsManager> build(Future<CommentsManager> arg) async {
    final manager = await arg;
    _listener = manager.subscribeStream(); // keep it resident in memory
    _poller = _listener.listen(
      (data) async {
        // reset
        state = await AsyncValue.guard(() async => await manager.reload());
      },
      onError: (e, s) {
        _log.severe('msg stream errored', e, s);
      },
      onDone: () {
        _log.info('msg stream ended');
      },
    );
    ref.onDispose(() => _poller.cancel());
    return manager;
  }
}

final commentsListProvider = FutureProvider.family
    .autoDispose<List<Comment>, CommentsManager>((ref, manager) async {
  final commentList = (await manager.comments()).toList();
  commentList.sort(
    (a, b) => a.originServerTs().compareTo(b.originServerTs()),
  );
  return commentList;
});

final newsCommentsCountProvider =
    FutureProvider.family.autoDispose<int, NewsEntry>((ref, newsEntry) async {
  final manager = newsEntry.comments();
  final commentManager =
      await ref.watch(commentsManagerProvider(manager).future);
  final commentList =
      await ref.watch(commentsListProvider(commentManager).future);
  return commentList.length;
});
