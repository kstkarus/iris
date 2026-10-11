import 'package:flutter/material.dart';

import 'package:iris/features/player/data/adapters/player_runtime_memory_adapter.dart';
import 'package:iris/features/player/domain/entities/anime_player_source.dart';
import 'package:iris/features/player/domain/entities/player_decoding_preferences.dart';
import 'package:iris/features/player/domain/entities/player_video_file.dart';
import 'package:iris/features/player/domain/entities/subtitle_preferences.dart';
import 'package:iris/features/player/domain/repositories/player_decoding_preferences_repository.dart';
import 'package:iris/features/player/domain/repositories/subtitle_preferences_repository.dart';
import 'package:iris/features/player/presentation/cubit/player_cubit.dart';
import 'package:iris/features/player/presentation/cubit/player_decoding_preferences_cubit.dart';
import 'package:iris/features/player/presentation/cubit/player_source_cubit.dart';
import 'package:iris/features/player/presentation/cubit/player_source_state.dart';
import 'package:iris/features/player/presentation/cubit/player_state.dart';
import 'package:iris/features/player/presentation/cubit/player_subtitle_preferences_cubit.dart';
import 'package:iris/features/player/presentation/playback/player_engine.dart';
import 'package:iris/features/player/presentation/widgets/player_countdown.dart';
import 'package:iris/features/player/presentation/widgets/player_viewport_factory.dart';

import '../../helpers/fake_player_engine.dart';
import '../../helpers/fake_player_repository.dart';

const fmaPlayerSource = AnimePlayerSource(
  animeId: '5114',
  animeTitle: 'Fullmetal Alchemist: Brotherhood',
  sourceTitle: '[Mock] Fullmetal Alchemist: Brotherhood Batch',
  sessionId: '42',
  fileIndex: 2,
  fileName: 'episode-02.mkv',
);

/// A [PlayerCubit] whose state the test pushes, recording what the page
/// asks of it.
class FakePlayerCubit extends PlayerCubit {
  FakePlayerCubit(PlayerState initialState, {required super.source})
    : super(repository: StubPlayerRepository(), engine: FakePlayerEngine()) {
    emit(initialState);
  }

  int loadCalls = 0;
  final playedFiles = <int>[];

  void push(PlayerState next) => emit(next);

  @override
  Future<void> loadPlayback() async {
    loadCalls++;
  }

  @override
  Future<void> playFile(PlayerVideoFile file) async {
    playedFiles.add(file.index);
  }
}

/// A [PlayerSourceCubit] whose state the test pushes, recording session
/// ownership hand-offs.
class FakePlayerSourceCubit extends PlayerSourceCubit {
  FakePlayerSourceCubit([PlayerSourceState? initialState])
    : super(
        magnet: 'magnet:?xt=urn:btih:test-source',
        repository: StubPlayerRepository(),
      ) {
    if (initialState != null) emit(initialState);
  }

  bool didTransferOwnership = false;
  bool didReclaimOwnership = false;

  void push(PlayerSourceState next) => emit(next);

  @override
  void transferSessionOwnership() {
    didTransferOwnership = true;
    super.transferSessionOwnership();
  }

  @override
  void reclaimSessionOwnership() {
    didReclaimOwnership = true;
    super.reclaimSessionOwnership();
  }
}

/// Builds a black `player_video_surface` and writes the chrome and the
/// input out as text, so tests can read what the page passed.
class FakePlayerViewportFactory implements PlayerViewportFactory {
  const FakePlayerViewportFactory();

  @override
  PlayerEngine createEngine({
    required PlayerSubtitlePreferencesCubit subtitlePreferences,
    required PlayerDecodingPreferencesCubit decodingPreferences,
  }) {
    return FakePlayerEngine();
  }

  @override
  Widget build({
    required PlayerEngine engine,
    required PlayerChrome chrome,
    PlayerInputMode input = PlayerInputMode.pointer,
    PlayerNextFile? next,
  }) {
    const surface = _FakeVideoSurface(key: Key('player_video_surface'));
    final episodes = chrome.episodes;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 200, child: surface),
        Text('overline: ${chrome.overline}'),
        Text('details: ${chrome.details}'),
        Text('title: ${chrome.title}'),
        Text('titleDetail: ${chrome.titleDetail}'),
        Text('episodes: ${chrome.episodesCaption}'),
        Text('input: ${input.name}'),
        if (chrome.notice case final notice?)
          // Counts down as the immersive player's notice does.
          PlayerCountdown(
            duration: notice.timeout,
            onElapsed: notice.onTimeout,
            child: TextButton(
              onPressed: notice.onAction,
              child: Text('notice: ${notice.message} / ${notice.actionLabel}'),
            ),
          ),
        TextButton(onPressed: chrome.onBack, child: const Text('back')),
        if (episodes != null)
          Expanded(
            child: Builder(builder: (context) => episodes(context, () {})),
          ),
      ],
    );
  }
}

/// Stateful so tests can tell a kept surface from a recreated one.
class _FakeVideoSurface extends StatefulWidget {
  const _FakeVideoSurface({super.key});

  @override
  State<_FakeVideoSurface> createState() => _FakeVideoSurfaceState();
}

class _FakeVideoSurfaceState extends State<_FakeVideoSurface> {
  @override
  Widget build(BuildContext context) {
    return const ColoredBox(color: Colors.black, child: SizedBox.expand());
  }
}

class MemorySubtitlePreferencesRepository
    implements SubtitlePreferencesRepository {
  MemorySubtitlePreferencesRepository([
    this.state = const SubtitlePreferences.defaults(),
  ]);

  SubtitlePreferences state;
  final savedStates = <SubtitlePreferences>[];

  @override
  Future<SubtitlePreferences> loadPreferences() async => state;

  @override
  Future<void> savePreferences(SubtitlePreferences preferences) async {
    savedStates.add(preferences);
    state = preferences;
  }
}

class MemoryDecodingPreferencesRepository
    implements PlayerDecodingPreferencesRepository {
  MemoryDecodingPreferencesRepository([
    this.state = const PlayerDecodingPreferences.defaults(),
  ]);

  PlayerDecodingPreferences state;
  final savedStates = <PlayerDecodingPreferences>[];

  @override
  Future<PlayerDecodingPreferences> loadPreferences() async => state;

  @override
  Future<void> savePreferences(PlayerDecodingPreferences preferences) async {
    savedStates.add(preferences);
    state = preferences;
  }
}

class FixedMemoryAdapter implements PlayerRuntimeMemoryAdapter {
  const FixedMemoryAdapter(this.appMemoryBytes);

  final int? appMemoryBytes;

  @override
  Future<int?> getAppMemoryBytes() async => appMemoryBytes;
}
