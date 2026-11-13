import 'package:iris/entities/user_rate/domain/user_rate.dart';
import 'package:iris/features/profile/domain/entities/user_list_entry.dart';

enum UserListLoad { loading, loaded, failed }

/// One status of a user's list, as far as it has been read.
class UserListState {
  const UserListState({
    this.userId,
    this.status = UserRateStatus.watching,
    this.entries = const [],
    this.load = UserListLoad.loading,
    this.page = 0,
    this.hasMore = false,
    this.loadingMore = false,
    this.moreFailed = false,
    this.refreshing = false,
  });

  /// Null while nobody's list is shown (signed out).
  final String? userId;
  final UserRateStatus status;
  final List<UserListEntry> entries;
  final UserListLoad load;

  /// The last page read; 0 before the first.
  final int page;
  final bool hasMore;
  final bool loadingMore;
  final bool moreFailed;

  /// The first page is being read again without replacing the visible list.
  final bool refreshing;

  UserListState copyWith({
    List<UserListEntry>? entries,
    UserListLoad? load,
    int? page,
    bool? hasMore,
    bool? loadingMore,
    bool? moreFailed,
    bool? refreshing,
  }) => UserListState(
    userId: userId,
    status: status,
    entries: entries ?? this.entries,
    load: load ?? this.load,
    page: page ?? this.page,
    hasMore: hasMore ?? this.hasMore,
    loadingMore: loadingMore ?? this.loadingMore,
    moreFailed: moreFailed ?? this.moreFailed,
    refreshing: refreshing ?? this.refreshing,
  );
}
