import 'dart:js_interop';
import 'dart:typed_data';
import 'dart:convert';

// JavaScript 함수들을 올바른 타입으로 선언
@JS('window.detectHandsAndPose')
external void _detectHandsAndPose(
  JSArray<JSNumber> imageData,
  int width,
  int height,
);

@JS('window.setMediaPipeCallbacks')
external void _setMediaPipeCallbacks(
  JSFunction? handsCallback,
  JSFunction? poseCallback,
);

class MediaPipeService {
  static MediaPipeService? _instance;
  static MediaPipeService get instance => _instance ??= MediaPipeService._();

  MediaPipeService._();

  Function(List<HandLandmarks>)? _onHandsDetected;
  Function(PoseLandmarks?)? _onPoseDetected;

  void initialize() {
    // MediaPipe 콜백 설정
    _setMediaPipeCallbacks(
      _onHandsDetected != null ? _handleHandsResult.toJS : null,
      _onPoseDetected != null ? _handlePoseResult.toJS : null,
    );
  }

  void _handleHandsResult(String jsonResult) {
    try {
      final data = jsonDecode(jsonResult);
      final List<HandLandmarks> hands = [];

      if (data['hands'] != null) {
        for (final handData in data['hands']) {
          final landmarks = <Landmark>[];
          for (final point in handData) {
            landmarks.add(
              Landmark(
                x: point['x'].toDouble(),
                y: point['y'].toDouble(),
                z: point['z'].toDouble(),
              ),
            );
          }
          hands.add(HandLandmarks(landmarks: landmarks));
        }
      }

      _onHandsDetected?.call(hands);
    } catch (e) {
      print('MediaPipe 손 결과 처리 오류: $e');
    }
  }

  void _handlePoseResult(String jsonResult) {
    try {
      final data = jsonDecode(jsonResult);

      if (data['pose'] != null) {
        final landmarks = <Landmark>[];
        for (final point in data['pose']) {
          landmarks.add(
            Landmark(
              x: point['x'].toDouble(),
              y: point['y'].toDouble(),
              z: point['z'].toDouble(),
              visibility: point['visibility']?.toDouble(),
            ),
          );
        }

        _onPoseDetected?.call(PoseLandmarks(landmarks: landmarks));
      } else {
        _onPoseDetected?.call(null);
      }
    } catch (e) {
      print('MediaPipe 포즈 결과 처리 오류: $e');
    }
  }

  void setHandsCallback(Function(List<HandLandmarks>) callback) {
    _onHandsDetected = callback;
    initialize();
  }

  void setPoseCallback(Function(PoseLandmarks?) callback) {
    _onPoseDetected = callback;
    initialize();
  }

  void detectFromFrame(Uint8List frameBytes, int width, int height) {
    try {
      // Uint8List를 JSArray<JSNumber>로 변환
      final jsArray = frameBytes.map((byte) => byte.toJS).toList().toJS;
      _detectHandsAndPose(jsArray, width, height);
    } catch (e) {
      print('MediaPipe 프레임 감지 오류: $e');
    }
  }
}

class Landmark {
  final double x;
  final double y;
  final double z;
  final double? visibility;

  Landmark({
    required this.x,
    required this.y,
    required this.z,
    this.visibility,
  });
}

class HandLandmarks {
  final List<Landmark> landmarks;

  HandLandmarks({required this.landmarks});

  // 손가락 끝점들 (MediaPipe 기준)
  Landmark get thumbTip => landmarks[4];
  Landmark get indexTip => landmarks[8];
  Landmark get middleTip => landmarks[12];
  Landmark get ringTip => landmarks[16];
  Landmark get pinkyTip => landmarks[20];

  // 손목
  Landmark get wrist => landmarks[0];
}

class PoseLandmarks {
  final List<Landmark> landmarks;

  PoseLandmarks({required this.landmarks});

  // 주요 포즈 포인트들 (MediaPipe 기준)
  Landmark get nose => landmarks[0];
  Landmark get leftShoulder => landmarks[11];
  Landmark get rightShoulder => landmarks[12];
  Landmark get leftElbow => landmarks[13];
  Landmark get rightElbow => landmarks[14];
  Landmark get leftWrist => landmarks[15];
  Landmark get rightWrist => landmarks[16];
}

// 감지 상태를 나타내는 enum
enum DetectionStatus {
  none, // 아무것도 감지되지 않음
  hands, // 손만 감지됨
  pose, // 포즈만 감지됨
  both, // 손과 포즈 모두 감지됨
}
