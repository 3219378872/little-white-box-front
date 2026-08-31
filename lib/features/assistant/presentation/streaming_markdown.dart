import 'package:flutter/widgets.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

import 'streaming_reveal.dart';

const _caretDuration = Duration(milliseconds: 530);
const _resetDuration = Duration(milliseconds: 120);
const tailMarkdownMinInterval = Duration(milliseconds: 125);

class StreamingMarkdownBody extends StatefulWidget {
  const StreamingMarkdownBody({
    super.key,
    required this.committedText,
    required this.isStreaming,
    required this.style,
    required this.foreground,
    this.onRevealed,
  });

  final String committedText;
  final bool isStreaming;
  final TextStyle style;
  final Color foreground;
  final VoidCallback? onRevealed;

  @override
  State<StreamingMarkdownBody> createState() => _StreamingMarkdownBodyState();
}

enum _RevealMode { revealing, resetting }

class _StreamingMarkdownBodyState extends State<StreamingMarkdownBody>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final StreamingRevealController _reveal;
  Duration? _lastElapsed;
  _RevealMode _mode = _RevealMode.revealing;
  String? _fadingOut;
  String? _publishedTail;
  String _lastStablePrefix = '';
  bool _lastTailIsFence = false;
  Duration _lastTailPublish = Duration.zero;
  var _appliedMount = false;

  @override
  void initState() {
    super.initState();
    _reveal = StreamingRevealController();
    _controller = AnimationController(vsync: this, duration: _caretDuration)
      ..addListener(_onControllerTick);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = MediaQuery.disableAnimationsOf(context);
    _reveal.reduceMotion = reduce;
    _reveal.isStreaming = widget.isStreaming;
    if (!_appliedMount) {
      _appliedMount = true;
      final signal = classifyMount(
        committed: widget.committedText,
        isStreaming: widget.isStreaming,
        reduceMotion: reduce,
      );
      _reveal.applyCommitted(widget.committedText, signal);
      _startRevealingIfNeeded();
    } else if (reduce) {
      _reveal.applyCommitted(widget.committedText, RevealSignal.snapFull);
      _controller.stop();
    }
  }

  @override
  void didUpdateWidget(StreamingMarkdownBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    final reduce = MediaQuery.disableAnimationsOf(context);
    _reveal.reduceMotion = reduce;
    _reveal.isStreaming = widget.isStreaming;
    final signal = classifyUpdate(
      previousCommitted: oldWidget.committedText,
      nextCommitted: widget.committedText,
      isStreaming: widget.isStreaming,
      reduceMotion: reduce,
    );
    if (signal == RevealSignal.reset) {
      _startReset(reduce);
      _reveal.applyCommitted(widget.committedText, signal);
      return;
    }
    _reveal.applyCommitted(widget.committedText, signal);
    if (signal == RevealSignal.snapFull) {
      _controller.stop();
      return;
    }
    _startRevealingIfNeeded();
  }

  void _startRevealingIfNeeded() {
    if (!widget.isStreaming || _reveal.reduceMotion) {
      _controller.stop();
      return;
    }
    if (_mode != _RevealMode.revealing) return;
    if (_controller.duration != _caretDuration) {
      _controller.duration = _caretDuration;
    }
    if (!_controller.isAnimating) {
      _syncLastElapsed();
      _controller.repeat(reverse: true);
    }
  }

  void _startReset(bool reduceMotion) {
    _fadingOut = _reveal.revealedString();
    if (reduceMotion || _fadingOut == null || _fadingOut!.isEmpty) {
      _reveal.resetCursor();
      _fadingOut = null;
      _mode = _RevealMode.revealing;
      _startRevealingIfNeeded();
      return;
    }
    _mode = _RevealMode.resetting;
    _controller.stop();
    _controller.duration = _resetDuration;
    _syncLastElapsed();
    _controller.value = 1.0;
    _controller.animateTo(0, curve: Curves.easeOut).whenComplete(_finishReset);
  }

  void _finishReset() {
    if (!mounted || _mode != _RevealMode.resetting) return;
    _fadingOut = null;
    _reveal.resetCursor();
    _mode = _RevealMode.revealing;
    _controller.duration = _caretDuration;
    _syncLastElapsed();
    _startRevealingIfNeeded();
    setState(() {});
  }

  void _syncLastElapsed() {
    _lastElapsed = _controller.lastElapsedDuration;
  }

  void _onControllerTick() {
    if (_mode == _RevealMode.resetting) {
      setState(() {});
      return;
    }
    final now = _controller.lastElapsedDuration ?? Duration.zero;
    final dt = now - (_lastElapsed ?? now);
    _lastElapsed = now;
    if (dt <= Duration.zero) {
      setState(() {});
      return;
    }
    final before = _reveal.revealedCount;
    _reveal.onTick(dt);
    setState(() {});
    if (_reveal.revealedCount > before) {
      widget.onRevealed?.call();
    }
  }

  String _tailDataForBuild({
    required String pendingTail,
    required bool tailIsFence,
    required String stablePrefix,
    required Duration clock,
  }) {
    final splitChanged =
        stablePrefix != _lastStablePrefix || tailIsFence != _lastTailIsFence;
    _lastStablePrefix = stablePrefix;
    _lastTailIsFence = tailIsFence;

    if (tailIsFence) {
      _publishedTail = pendingTail;
      return pendingTail;
    }
    if (splitChanged || !_reveal.isCatchingUp) {
      _publishedTail = pendingTail;
      _lastTailPublish = clock;
      return pendingTail;
    }
    if (_publishedTail == null ||
        clock - _lastTailPublish >= tailMarkdownMinInterval) {
      _publishedTail = pendingTail;
      _lastTailPublish = clock;
    }
    return _publishedTail!;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_mode == _RevealMode.resetting && _fadingOut != null) {
      return Opacity(
        opacity: _controller.value,
        child: GptMarkdown(_fadingOut!, style: widget.style),
      );
    }

    final revealed = _reveal.revealedString();
    final split = splitMarkdownReveal(revealed);
    final clock = _controller.lastElapsedDuration ?? Duration.zero;
    final tailData = _tailDataForBuild(
      pendingTail: split.pendingTail,
      tailIsFence: split.tailIsFence,
      stablePrefix: split.stablePrefix,
      clock: clock,
    );
    final catchingUp = _reveal.isCatchingUp;
    final showCaret =
        widget.isStreaming &&
        !_reveal.reduceMotion &&
        _reveal.revealedCount > 0;
    final caretOpacity = catchingUp ? 1.0 : _controller.value;
    final fontSize = widget.style.fontSize ?? 14;

    Widget? tail;
    if (split.tailIsFence) {
      tail = Text(
        tailData,
        style: widget.style.copyWith(fontFamily: 'monospace'),
      );
    } else if (tailData.isNotEmpty) {
      tail = GptMarkdown(tailData, style: widget.style);
    }

    return MergeSemantics(
      child: Semantics(
        container: true,
        label: revealed,
        child: ExcludeSemantics(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (split.stablePrefix.isNotEmpty)
                GptMarkdown(
                  split.stablePrefix,
                  key: ValueKey<String>(split.stablePrefix),
                  style: widget.style,
                ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (tail != null) Flexible(child: tail),
                  if (showCaret)
                    Padding(
                      padding: const EdgeInsets.only(left: 1),
                      child: Opacity(
                        opacity: caretOpacity,
                        child: SizedBox(
                          key: const Key('assistant-stream-caret'),
                          width: 1.5,
                          height: fontSize * 0.85,
                          child: ColoredBox(color: widget.foreground),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
