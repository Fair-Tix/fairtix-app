import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import '../../theme/fairtix_palette.dart';
import '../../widgets/ft_dark_ui.dart';

/// What the liveness screen returns once the person has passed: a still photo
/// of their face, taken after the challenges.
class LivenessSelfie {
  const LivenessSelfie({required this.bytes, required this.extension});

  final Uint8List bytes;
  final String extension;
}

enum _Challenge { blink, smile, turn }

enum _Phase { starting, challenge, finishing, failed, error }

extension on _Challenge {
  String get prompt => switch (this) {
    _Challenge.blink => 'Blink your eyes',
    _Challenge.smile => 'Give us a smile',
    _Challenge.turn => 'Slowly turn your head to one side',
  };
}

/// Registration Step 4 helper: live face check with the in-app front camera.
///
/// The person is asked to do two random actions (blink, smile, turn the
/// head) and then look straight at the camera, and the app takes the photo.
/// Face detection runs on the phone (Google ML Kit), so a printed photo or a
/// screenshot cannot pass. It does NOT stop a video replay or a tampered
/// app: there is no server-side liveness check.
///
/// Pops a [LivenessSelfie] when passed, or null if the person backs out.
class LivenessCaptureScreen extends StatefulWidget {
  const LivenessCaptureScreen({super.key});

  /// Camera streaming + ML Kit are only available on Android and iOS.
  static bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  State<LivenessCaptureScreen> createState() => _LivenessCaptureScreenState();
}

class _LivenessCaptureScreenState extends State<LivenessCaptureScreen> {
  static const _challengeSeconds = 10;
  static const _orientations = <DeviceOrientation, int>{
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  CameraController? _controller;
  late final FaceDetector _detector;

  List<_Challenge> _plan = const [];
  int _index = 0;
  int _stage = 0;
  _Phase _phase = _Phase.starting;
  String? _error;
  String _hint = '';

  bool _processing = false;
  bool _taking = false;
  int _frontalFrames = 0;
  DateTime _lastFrame = DateTime.fromMillisecondsSinceEpoch(0);
  Timer? _timeout;

  @override
  void initState() {
    super.initState();
    _detector = FaceDetector(
      options: FaceDetectorOptions(
        enableClassification: true,
        minFaceSize: 0.3,
        performanceMode: FaceDetectorMode.fast,
      ),
    );
    _newPlan();
    _initCamera();
  }

  @override
  void dispose() {
    _timeout?.cancel();
    _detector.close();
    _controller?.dispose();
    super.dispose();
  }

  void _newPlan() {
    final all = [..._Challenge.values]..shuffle();
    _plan = all.take(2).toList();
    _index = 0;
    _stage = 0;
    _frontalFrames = 0;
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      CameraDescription? front;
      for (final c in cameras) {
        if (c.lensDirection == CameraLensDirection.front) {
          front = c;
          break;
        }
      }
      if (front == null) {
        _fail('No front camera was found on this phone.');
        return;
      }
      final controller = CameraController(
        front,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: defaultTargetPlatform == TargetPlatform.android
            ? ImageFormatGroup.nv21
            : ImageFormatGroup.bgra8888,
      );
      await controller.initialize();
      await controller.lockCaptureOrientation(DeviceOrientation.portraitUp);
      if (!mounted) {
        await controller.dispose();
        return;
      }
      _controller = controller;
      setState(() => _phase = _Phase.challenge);
      _beginChallenge();
      await controller.startImageStream(_onFrame);
    } on CameraException catch (e) {
      final denied = e.code.toLowerCase().contains('denied');
      _fail(
        denied
            ? 'Camera permission is off. Allow camera access for FairTix in your phone settings, then try again.'
            : 'Could not open the camera. Please try again.',
      );
    } catch (_) {
      _fail('Could not open the camera. Please try again.');
    }
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() {
      _phase = _Phase.error;
      _error = message;
    });
  }

  void _beginChallenge() {
    _stage = 0;
    _hint = '';
    _timeout?.cancel();
    _timeout = Timer(const Duration(seconds: _challengeSeconds), _onTimeout);
  }

  void _onTimeout() {
    if (!mounted || _taking) return;
    setState(() => _phase = _Phase.failed);
  }

  void _retry() {
    setState(() {
      _newPlan();
      _phase = _Phase.challenge;
    });
    _beginChallenge();
  }

  // -------------------------------------------------------------------------
  // Frames
  // -------------------------------------------------------------------------

  Future<void> _onFrame(CameraImage image) async {
    if (_processing || _taking) return;
    if (_phase != _Phase.challenge && _phase != _Phase.finishing) return;
    final now = DateTime.now();
    if (now.difference(_lastFrame).inMilliseconds < 120) return;
    _lastFrame = now;
    _processing = true;
    try {
      final input = _toInputImage(image);
      if (input == null) return;
      final faces = await _detector.processImage(input);
      if (!mounted) return;
      _handleFaces(faces);
    } catch (_) {
      // A bad frame is skipped; the next one is tried.
    } finally {
      _processing = false;
    }
  }

  InputImage? _toInputImage(CameraImage image) {
    final controller = _controller;
    if (controller == null) return null;
    final camera = controller.description;
    final sensor = camera.sensorOrientation;

    InputImageRotation? rotation;
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      rotation = InputImageRotationValue.fromRawValue(sensor);
    } else {
      var compensation = _orientations[controller.value.deviceOrientation];
      if (compensation == null) return null;
      if (camera.lensDirection == CameraLensDirection.front) {
        compensation = (sensor + compensation) % 360;
      } else {
        compensation = (sensor - compensation + 360) % 360;
      }
      rotation = InputImageRotationValue.fromRawValue(compensation);
    }
    if (rotation == null) return null;

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null) return null;
    if (defaultTargetPlatform == TargetPlatform.android &&
        format != InputImageFormat.nv21) {
      return null;
    }
    if (defaultTargetPlatform == TargetPlatform.iOS &&
        format != InputImageFormat.bgra8888) {
      return null;
    }
    if (image.planes.length != 1) return null;
    final plane = image.planes.first;

    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  void _setHint(String hint) {
    if (_hint == hint) return;
    setState(() => _hint = hint);
  }

  void _handleFaces(List<Face> faces) {
    if (faces.isEmpty) {
      _frontalFrames = 0;
      _setHint('Move your face into the oval');
      return;
    }
    if (faces.length > 1) {
      _frontalFrames = 0;
      _setHint('Only one face, please');
      return;
    }
    _setHint('');

    final face = faces.first;
    final yaw = (face.headEulerAngleY ?? 0).abs();
    final left = face.leftEyeOpenProbability;
    final right = face.rightEyeOpenProbability;
    final smile = face.smilingProbability;
    final eyesOpen = left != null && right != null && left > 0.6 && right > 0.6;

    if (_phase == _Phase.finishing) {
      // Wait for a few steady, straight-on frames, then take the photo.
      final straight = yaw < 10 && (left == null || eyesOpen);
      _frontalFrames = straight ? _frontalFrames + 1 : 0;
      if (_frontalFrames >= 4) _takeStill();
      return;
    }

    switch (_plan[_index]) {
      case _Challenge.blink:
        if (left == null || right == null) return;
        final closed = left < 0.25 && right < 0.25;
        if (_stage == 0 && eyesOpen) {
          _stage = 1;
        } else if (_stage == 1 && closed) {
          _stage = 2;
        } else if (_stage == 2 && eyesOpen) {
          _completeChallenge();
        }
      case _Challenge.smile:
        if (smile == null) return;
        if (_stage == 0 && smile < 0.35) {
          _stage = 1;
        } else if (_stage == 1 && smile > 0.8) {
          _completeChallenge();
        }
      case _Challenge.turn:
        if (_stage == 0 && yaw < 10) {
          _stage = 1;
        } else if (_stage == 1 && yaw >= 20) {
          _completeChallenge();
        }
    }
  }

  void _completeChallenge() {
    _timeout?.cancel();
    final next = _index + 1;
    if (next >= _plan.length) {
      setState(() {
        _index = next;
        _phase = _Phase.finishing;
        _frontalFrames = 0;
      });
      _timeout = Timer(const Duration(seconds: _challengeSeconds), _onTimeout);
    } else {
      setState(() => _index = next);
      _beginChallenge();
    }
  }

  Future<void> _takeStill() async {
    if (_taking) return;
    _taking = true;
    _timeout?.cancel();
    try {
      final controller = _controller!;
      await controller.stopImageStream();
      final shot = await controller.takePicture();
      final bytes = await shot.readAsBytes();
      final name = shot.name;
      final ext = name.contains('.') ? name.split('.').last : 'jpg';
      if (!mounted) return;
      Navigator.of(context).pop(LivenessSelfie(bytes: bytes, extension: ext));
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _taking = false;
        _phase = _Phase.error;
        _error = 'Could not take the photo. Please go back and try again.';
      });
    }
  }

  // -------------------------------------------------------------------------
  // UI
  // -------------------------------------------------------------------------

  String get _instruction => switch (_phase) {
    _Phase.starting => 'Starting the camera…',
    _Phase.challenge => _plan[math.min(_index, _plan.length - 1)].prompt,
    _Phase.finishing => 'Now look straight at the camera',
    _Phase.failed => 'Time ran out. Let’s try again.',
    _Phase.error => _error ?? 'Something went wrong.',
  };

  @override
  Widget build(BuildContext context) {
    final p = FairTixPalette.of(context);
    final t = FtAuthTheme.live(context);
    final ringColor = switch (_phase) {
      _Phase.finishing => p.success,
      _Phase.failed || _Phase.error => p.danger,
      _ => t.activeAccent,
    };

    TextStyle text(double size, FontWeight weight, Color color) =>
        GoogleFonts.plusJakartaSans(
          fontSize: size,
          height: 1.3,
          fontWeight: weight,
          color: color,
        );

    final canRetry = _phase == _Phase.failed;

    return Scaffold(
      backgroundColor: p.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(19, 8, 19, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  IconButton(
                    tooltip: 'Close',
                    onPressed: _taking
                        ? null
                        : () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close_rounded, color: p.textPrimary),
                  ),
                  const Spacer(),
                  Text(
                    'Live face check',
                    style: text(16, FontWeight.w700, p.textPrimary),
                  ),
                  const Spacer(),
                  const SizedBox(width: 48),
                ],
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, box) {
                    final ovalW = math.min(
                      box.maxWidth * 0.72,
                      box.maxHeight / 1.29 * 0.95,
                    );
                    final ovalH = ovalW * 1.29;
                    return Center(
                      child: SizedBox(
                        width: ovalW,
                        height: ovalH,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            _preview(ovalW, ovalH, p),
                            CustomPaint(
                              painter: _RingPainter(color: ringColor),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _instruction,
                textAlign: TextAlign.center,
                style: text(20, FontWeight.w800, p.textPrimary),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 20,
                child: Text(
                  _hint,
                  textAlign: TextAlign.center,
                  style: text(14, FontWeight.w500, p.textSecondary),
                ),
              ),
              const SizedBox(height: 10),
              if (_phase == _Phase.challenge || _phase == _Phase.finishing)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < _plan.length; i++)
                      Container(
                        width: 28,
                        height: 6,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(3),
                          color: i < _index ? p.success : p.progressTrack,
                        ),
                      ),
                  ],
                ),
              const SizedBox(height: 16),
              SizedBox(
                height: 52,
                child: canRetry
                    ? FilledButton(
                        onPressed: _retry,
                        child: const Text('Try again'),
                      )
                    : _phase == _Phase.error
                    ? OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Go back'),
                      )
                    : null,
              ),
              const SizedBox(height: 4),
              Text(
                'Your face is checked on this phone to make sure a real person is registering.',
                textAlign: TextAlign.center,
                style: text(12.5, FontWeight.w500, p.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _preview(double w, double h, FairTixPalette p) {
    final c = _controller;
    final size = c?.value.previewSize;
    if (c == null || !c.value.isInitialized || size == null) {
      return ClipOval(child: ColoredBox(color: p.progressTrack));
    }
    // previewSize is reported in landscape, so width/height are swapped for a
    // portrait phone.
    return ClipOval(
      child: SizedBox(
        width: w,
        height: h,
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: size.height,
            height: size.width,
            child: CameraPreview(c),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 4.0;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    canvas.drawOval((Offset.zero & size).deflate(stroke / 2), paint);
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.color != color;
}
