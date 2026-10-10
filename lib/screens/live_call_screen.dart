import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:provider/provider.dart';

import '../core/config.dart';
import '../models/rental_models.dart';
import '../state/property24_state.dart';
import '../theme/app_theme.dart';

class CallSetupException implements Exception {
  const CallSetupException(this.message);

  final String message;

  @override
  String toString() => message;
}

class LiveCallScreen extends StatefulWidget {
  const LiveCallScreen({
    required this.conversation,
    required this.call,
    required this.localStream,
    required this.peerId,
    required this.peerName,
    required this.isOutgoing,
    super.key,
  });

  final ConversationItem conversation;
  final CallLogItem call;
  final MediaStream localStream;
  final String peerId;
  final String peerName;
  final bool isOutgoing;

  static Future<MediaStream> _requestMedia(CallMode mode) async {
    try {
      return await navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': mode == CallMode.video
            ? {
                'facingMode': 'user',
                'width': {'ideal': 1280, 'max': 1920},
                'height': {'ideal': 720, 'max': 1080},
              }
            : false,
      });
    } on PlatformException catch (exception) {
      final reason = switch (exception.code.toLowerCase()) {
        'permission_denied' || 'permissiondenied' || 'notallowederror' =>
          'Allow camera and microphone access in your device settings, then try again.',
        'notfounderror' =>
          'A camera or microphone could not be found on this device.',
        _ =>
          'Could not access the camera and microphone '
              '(${exception.code}). ${exception.message ?? ''}',
      };
      throw CallSetupException(reason);
    }
  }

  static Future<void> startOutgoing(
    BuildContext context, {
    required ConversationItem conversation,
    required CallMode mode,
    required String peerName,
  }) async {
    final state = context.read<Property24State>();
    final userId = state.user?.id ?? '';
    AccountUser? peer;
    for (final participant in conversation.participants) {
      if (participant.id != userId) {
        peer = participant;
        break;
      }
    }
    if (peer == null || peer.id.isEmpty) {
      throw const CallSetupException(
        'This conversation has no other participant to call.',
      );
    }
    final targetPeerId = peer.id;
    if (!state.liveConnected) {
      throw const CallSetupException(
        'Chat is reconnecting. Wait for it to reconnect before calling.',
      );
    }
    if (!state.isUserOnline(peer.id, fallback: peer.isCurrentlyOnline)) {
      throw const CallSetupException(
        'This person is offline right now. Try again when they are online.',
      );
    }

    final localStream = await _requestMedia(mode);
    try {
      final call = await state.startCall(conversation.id, mode: mode);
      if (!context.mounted) {
        await localStream.dispose();
        return;
      }
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => LiveCallScreen(
            conversation: conversation,
            call: call,
            localStream: localStream,
            peerId: targetPeerId,
            peerName: peerName,
            isOutgoing: true,
          ),
        ),
      );
    } catch (_) {
      await localStream.dispose();
      rethrow;
    }
  }

  static Future<void> answerIncoming(
    BuildContext context, {
    required ConversationItem conversation,
    required CallLogItem call,
    required String peerId,
    required String peerName,
  }) async {
    final localStream = await _requestMedia(call.mode);
    if (!context.mounted) {
      await localStream.dispose();
      return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => LiveCallScreen(
          conversation: conversation,
          call: call,
          localStream: localStream,
          peerId: peerId,
          peerName: peerName,
          isOutgoing: false,
        ),
      ),
    );
  }

  @override
  State<LiveCallScreen> createState() => _LiveCallScreenState();
}

class _LiveCallScreenState extends State<LiveCallScreen> {
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  final List<RTCIceCandidate> _pendingCandidates = <RTCIceCandidate>[];
  StreamSubscription<Map<String, dynamic>>? _callSubscription;
  RTCPeerConnection? _peerConnection;
  Timer? _durationTimer;
  Timer? _callTimeout;
  Timer? _disconnectTimer;
  DateTime? _connectedAt;
  Duration _duration = Duration.zero;
  bool _muted = false;
  bool _speakerOn = false;
  bool _cameraEnabled = true;
  bool _makingOffer = false;
  bool _offerCreated = false;
  bool _remoteReady = false;
  bool _hasRemoteDescription = false;
  bool _callEnded = false;
  bool _closing = false;
  bool _resourcesReleased = false;
  bool _remoteCameraEnabled = true;
  String _status = 'Connecting…';
  late Property24State _appState;

  bool get _supportsSpeakerRouting =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  void initState() {
    super.initState();
    _appState = context.read<Property24State>();
    if (!_appState.activateLocalCall(widget.call.id)) {
      _callEnded = true;
      _closing = true;
      _status = 'Already in another call';
      _resourcesReleased = true;
      unawaited(widget.localStream.dispose());
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop();
      });
      return;
    }
    _callSubscription = _appState.callEvents.listen(_handleCallEvent);
    _callTimeout = Timer(const Duration(seconds: 60), () {
      if (_connectedAt == null && !_callEnded) {
        unawaited(
          _failCall(
            StateError(
              widget.isOutgoing
                  ? 'The call was not answered in time.'
                  : 'The call could not connect after it was answered.',
            ),
          ),
        );
      }
    });
    unawaited(_initializeCall());
  }

  @override
  void dispose() {
    _callSubscription?.cancel();
    _durationTimer?.cancel();
    unawaited(_releaseResources());
    super.dispose();
  }

  Future<void> _initializeCall() async {
    try {
      await Future.wait([
        _localRenderer.initialize(),
        _remoteRenderer.initialize(),
      ]);
      if (_callEnded) return;
      if (_supportsSpeakerRouting) {
        final speakerOn = widget.call.mode == CallMode.video;
        try {
          await Helper.setSpeakerphoneOn(speakerOn);
          _speakerOn = speakerOn;
        } catch (exception) {
          _showError(exception);
        }
      }
      _localRenderer.srcObject = widget.localStream;
      final peerConnection = await createPeerConnection({
        'iceServers': AppConfig.webrtcIceServers,
        'sdpSemantics': 'unified-plan',
      });
      if (_callEnded) {
        await peerConnection.close();
        return;
      }
      _peerConnection = peerConnection;
      peerConnection.onIceCandidate = (candidate) {
        final value = candidate.candidate;
        if (value == null || value.isEmpty) return;
        _sendSignal('ice-candidate', {
          'candidate': value,
          'sdpMid': candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex,
        });
      };
      peerConnection.onTrack = (event) {
        if (event.streams.isNotEmpty) {
          _remoteRenderer.srcObject = event.streams.first;
          if (mounted) setState(() => _status = 'Connected');
        }
      };
      peerConnection.onConnectionState = (connectionState) {
        if (!mounted) return;
        if (connectionState ==
            RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
          _markConnected();
        } else if (connectionState ==
            RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
          _disconnectTimer?.cancel();
          _disconnectTimer = Timer(const Duration(seconds: 15), () {
            if (!_callEnded) {
              unawaited(
                _failCall(
                  StateError('The call connection could not be restored.'),
                ),
              );
            }
          });
          setState(() => _status = 'Connection interrupted');
        } else if (connectionState ==
            RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
          unawaited(_failCall(StateError('The call connection failed.')));
        }
      };
      for (final track in widget.localStream.getTracks()) {
        await peerConnection.addTrack(track, widget.localStream);
      }
      if (widget.isOutgoing) {
        if (mounted) {
          setState(() => _status = _remoteReady ? 'Connecting…' : 'Calling…');
        }
        if (_remoteReady) await _makeOffer();
      } else {
        _sendSignal('ready', const {});
        if (mounted) setState(() => _status = 'Connecting…');
      }
    } catch (exception) {
      await _failCall(exception);
    }
  }

  Future<void> _handleCallEvent(Map<String, dynamic> event) async {
    if (_callEnded || _resourcesReleased) return;
    final payload = event['payload'];
    if (payload is! Map) return;
    if ('${payload['call_id'] ?? payload['id'] ?? ''}' != widget.call.id) {
      return;
    }
    final type = '${event['type'] ?? ''}';
    if (type == 'call.ended') {
      final status = '${payload['status'] ?? ''}';
      _finishFromRemote(status: status == 'missed' ? 'No answer' : 'Call ended');
      return;
    }
    if (type != 'call.signal') return;
    if ('${payload['sender_id'] ?? ''}' == _appState.user?.id) {
      return;
    }
    final targetUserId = '${payload['target_user_id'] ?? ''}';
    if (targetUserId.isNotEmpty && targetUserId != _appState.user?.id) {
      return;
    }
    final signal = payload['signal'];
    if (signal is! Map) return;
    try {
      switch ('${payload['signal_type'] ?? ''}') {
        case 'reject':
          _finishFromRemote(status: 'Call declined');
          break;
        case 'busy':
          _finishFromRemote(status: 'Busy');
          break;
        case 'ready':
          if (widget.isOutgoing) {
            _remoteReady = true;
            if (mounted) setState(() => _status = 'Connecting…');
            await _makeOffer();
          }
          break;
        case 'offer':
          if (!widget.isOutgoing) await _acceptOffer(signal);
          break;
        case 'answer':
          if (widget.isOutgoing) await _acceptAnswer(signal);
          break;
        case 'ice-candidate':
          await _receiveCandidate(signal);
          break;
        case 'camera-off':
          if (mounted) setState(() => _remoteCameraEnabled = false);
          break;
        case 'camera-on':
          if (mounted) setState(() => _remoteCameraEnabled = true);
          break;
      }
    } catch (exception) {
      unawaited(_failCall(exception));
    }
  }

  Future<void> _makeOffer() async {
    final peerConnection = _peerConnection;
    if (peerConnection == null || _makingOffer || _offerCreated || _callEnded) {
      return;
    }
    _makingOffer = true;
    try {
      final offer = await peerConnection.createOffer();
      await peerConnection.setLocalDescription(offer);
      _offerCreated = true;
      _sendSignal('offer', {'sdp': offer.sdp, 'type': offer.type});
    } finally {
      _makingOffer = false;
    }
  }

  Future<void> _acceptOffer(Map<dynamic, dynamic> signal) async {
    final peerConnection = _peerConnection;
    if (peerConnection == null || _callEnded) return;
    final sdp = signal['sdp'];
    if (sdp is! String || sdp.isEmpty || signal['type'] != 'offer') {
      throw const FormatException('The incoming call offer is invalid.');
    }
    final description = RTCSessionDescription(sdp, 'offer');
    await peerConnection.setRemoteDescription(description);
    _hasRemoteDescription = true;
    await _applyPendingCandidates();
    final answer = await peerConnection.createAnswer();
    await peerConnection.setLocalDescription(answer);
    _sendSignal('answer', {'sdp': answer.sdp, 'type': answer.type});
  }

  Future<void> _acceptAnswer(Map<dynamic, dynamic> signal) async {
    final peerConnection = _peerConnection;
    if (peerConnection == null || _callEnded) return;
    final sdp = signal['sdp'];
    if (sdp is! String || sdp.isEmpty || signal['type'] != 'answer') {
      throw const FormatException('The incoming call answer is invalid.');
    }
    await peerConnection.setRemoteDescription(
      RTCSessionDescription(sdp, 'answer'),
    );
    _hasRemoteDescription = true;
    await _applyPendingCandidates();
  }

  Future<void> _receiveCandidate(Map<dynamic, dynamic> signal) async {
    final candidateValue = signal['candidate'];
    if (candidateValue is! String || candidateValue.isEmpty) return;
    final candidate = RTCIceCandidate(
      candidateValue,
      signal['sdpMid'] as String?,
      (signal['sdpMLineIndex'] as num?)?.toInt(),
    );
    if (_hasRemoteDescription) {
      await _peerConnection?.addCandidate(candidate);
    } else {
      _pendingCandidates.add(candidate);
    }
  }

  Future<void> _applyPendingCandidates() async {
    final peerConnection = _peerConnection;
    if (peerConnection == null) return;
    for (final candidate in _pendingCandidates) {
      await peerConnection.addCandidate(candidate);
    }
    _pendingCandidates.clear();
  }

  void _sendSignal(String signalType, Map<String, dynamic> signal) {
    final sent = _appState.sendLiveEvent(
      'call.signal',
      widget.conversation.id,
      payload: {
        'call_id': widget.call.id,
        'target_user_id': widget.peerId,
        'signal_type': signalType,
        'signal': signal,
      },
    );
    if (!sent && !_callEnded) {
      unawaited(
        _failCall(
          StateError('The live connection was lost. The call has ended.'),
        ),
      );
    }
  }

  void _markConnected() {
    if (!mounted || _callEnded) return;
    _callTimeout?.cancel();
    _disconnectTimer?.cancel();
    _connectedAt ??= DateTime.now();
    _durationTimer ??= Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _connectedAt == null) return;
      setState(() => _duration = DateTime.now().difference(_connectedAt!));
    });
    setState(() => _status = _formatDuration(_duration));
  }

  void _finishFromRemote({String status = 'Call ended'}) {
    if (_callEnded) {
      if (status != 'Call ended' && mounted) {
        setState(() => _status = status);
      }
      return;
    }
    _callEnded = true;
    _closing = true;
    _callTimeout?.cancel();
    _disconnectTimer?.cancel();
    unawaited(_releaseResources());
    if (mounted) setState(() => _status = status);
  }

  Future<void> _endCall() async {
    await _closeCall(status: 'ended');
  }

  Future<void> _failCall(Object exception) async {
    if (_callEnded) return;
    _showError(exception);
    await _closeCall(status: 'missed');
  }

  Future<void> _closeCall({required String status}) async {
    if (_callEnded) {
      await _releaseResources();
      if (mounted) Navigator.of(context).pop();
      return;
    }
    _callEnded = true;
    _callTimeout?.cancel();
    _disconnectTimer?.cancel();
    try {
      await _appState.endCall(
        widget.conversation.id,
        widget.call.id,
        status: status,
      );
    } catch (exception) {
      _showError(exception);
    }
    await _releaseResources();
    if (mounted) {
      setState(() {
        _closing = true;
        _status = status == 'missed' ? 'Call ended' : _status;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop();
      });
    }
  }

  Future<void> _releaseResources() async {
    if (_resourcesReleased) return;
    _resourcesReleased = true;
    _appState.deactivateLocalCall(widget.call.id);
    _durationTimer?.cancel();
    _callTimeout?.cancel();
    _disconnectTimer?.cancel();
    _localRenderer.srcObject = null;
    _remoteRenderer.srcObject = null;
    await _peerConnection?.close();
    _peerConnection = null;
    for (final track in widget.localStream.getTracks()) {
      await track.stop();
    }
    await widget.localStream.dispose();
    await _localRenderer.dispose();
    await _remoteRenderer.dispose();
  }

  void _toggleMute() {
    _muted = !_muted;
    for (final track in widget.localStream.getAudioTracks()) {
      track.enabled = !_muted;
    }
    setState(() {});
    _sendSignal(_muted ? 'mute' : 'unmute', const {});
  }

  Future<void> _toggleSpeaker() async {
    final speakerOn = !_speakerOn;
    try {
      await Helper.setSpeakerphoneOn(speakerOn);
      if (mounted) setState(() => _speakerOn = speakerOn);
    } catch (exception) {
      _showError(exception);
    }
  }

  void _toggleCamera() {
    _cameraEnabled = !_cameraEnabled;
    for (final track in widget.localStream.getVideoTracks()) {
      track.enabled = _cameraEnabled;
    }
    setState(() {});
    _sendSignal(_cameraEnabled ? 'camera-on' : 'camera-off', const {});
  }

  void _showError(Object exception) {
    if (!mounted) return;
    final message = exception is CallSetupException
        ? exception.message
        : exception is StateError
        ? exception.message.toString()
        : exception.toString();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    final hours = duration.inHours;
    return hours == 0 ? '$minutes:$seconds' : '$hours:$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final isVideo = widget.call.mode == CallMode.video && !_callEnded;
    final connected = _connectedAt != null;
    return PopScope<void>(
      canPop: _closing,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_endCall());
      },
      child: Scaffold(
        backgroundColor: const Color(0xff101418),
        appBar: AppBar(
          backgroundColor: const Color(0xff101418),
          foregroundColor: Colors.white,
          title: Text(widget.peerName),
          centerTitle: true,
        ),
        body: Stack(
          fit: StackFit.expand,
          children: [
            if (isVideo &&
                _remoteCameraEnabled &&
                _remoteRenderer.textureId != null)
              RTCVideoView(_remoteRenderer)
            else
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircleAvatar(
                      radius: 54,
                      backgroundColor: AppTheme.accent,
                      child: Icon(
                        CupertinoIcons.person_fill,
                        color: Colors.white,
                        size: 50,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      connected ? _formatDuration(_duration) : _status,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
            if (isVideo &&
                _localRenderer.textureId != null &&
                _cameraEnabled &&
                !_callEnded)
              Positioned(
                top: 16,
                right: 16,
                width: 112,
                height: 156,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: RTCVideoView(_localRenderer, mirror: true),
                ),
              ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 28,
              child: SafeArea(
                top: false,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _CallControl(
                      icon: _muted
                          ? CupertinoIcons.mic_slash
                          : CupertinoIcons.mic,
                      label: _muted ? 'Unmute' : 'Mute',
                      onTap: _callEnded ? null : _toggleMute,
                    ),
                    if (_supportsSpeakerRouting) ...[
                      const SizedBox(width: 22),
                      _CallControl(
                        icon: _speakerOn
                            ? CupertinoIcons.speaker_2_fill
                            : CupertinoIcons.phone_fill,
                        label: _speakerOn ? 'Speaker' : 'Earpiece',
                        color: _speakerOn
                            ? AppTheme.accentTeal
                            : const Color(0xff303840),
                        onTap: _callEnded ? null : _toggleSpeaker,
                      ),
                    ],
                    if (widget.call.mode == CallMode.video) ...[
                      const SizedBox(width: 22),
                      _CallControl(
                        icon: _cameraEnabled
                            ? CupertinoIcons.video_camera
                            : CupertinoIcons.video_camera_solid,
                        label: _cameraEnabled ? 'Camera' : 'Camera off',
                        onTap: _callEnded ? null : _toggleCamera,
                      ),
                    ],
                    const SizedBox(width: 22),
                    _CallControl(
                      icon: CupertinoIcons.phone_down_fill,
                      label: _callEnded ? 'Close' : 'End',
                      color: const Color(0xffe5484d),
                      onTap: _endCall,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CallControl extends StatelessWidget {
  const _CallControl({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = const Color(0xff303840),
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: onTap == null ? color.withAlpha(100) : color,
          shape: const CircleBorder(),
          child: IconButton(
            onPressed: onTap,
            color: Colors.white,
            icon: Icon(icon),
            iconSize: 23,
            padding: const EdgeInsets.all(16),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 11),
        ),
      ],
    );
  }
}
