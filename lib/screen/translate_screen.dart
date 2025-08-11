import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:math';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:sign_web/widget/animation_widget.dart';
import 'package:sign_web/service/translate_api.dart';
import 'package:sign_web/widget/sidebar_widget.dart';
import 'package:sign_web/theme/tabler_theme.dart';
import 'package:sign_web/widget/tablerui_widget.dart';

class TranslateScreen extends StatefulWidget {
  const TranslateScreen({super.key});
  @override
  State<TranslateScreen> createState() => TranslateScreenWebState();
}

class TranslateScreenWebState extends State<TranslateScreen> {
  bool isSignToKorean = true; // true: 수어 -> 한글 | false 한글 -> 수어
  bool isCameraOn = false;
  bool isTranslating = false;
  XFile? capturedVideo;
  bool useRealtimeMode = true;

  final TextEditingController inputController = TextEditingController();

  // 콤보박스
  final List<String> langs = ['한국어', 'English', '日本語', '中文'];
  String selectedLang = '한국어';

  String? resultKorean;
  String? resultEnglish;
  String? resultJapanese;
  String? resultChinese;

  CameraController? cameraController;
  final List<Uint8List> frameBuffer = [];
  final GlobalKey<AnimationWidgetState> animationKey =
      GlobalKey<AnimationWidgetState>();
  List<Uint8List> decodeFrames = [];

  // 실시간 인식 결과 누적 및 폴링
  Timer? _recognitionPollingTimer;
  static const int _autoFinalizeWordCount = 3;
  bool _autoFinalized = false;

  // 프레임 상태 표시용 변수 추가
  String frameStatus = '';
  bool isCollectingFrames = false;
  bool hasCollectedFramesOnce = false;

  // 실시간 번역 관련 변수들
  Timer? realtimeTranslationTimer;
  bool isRealtimeTranslating = false;
  List<String> translationHistory = []; // 번역 히스토리
  DateTime? lastTranslationTime;

  // 웹 기반 사람 감지 시스템
  Uint8List? previousFrameBytes;
  List<double> recentPresenceScores = []; // 최근 사람 존재 점수들
  double presenceThreshold = 0.02; // 사람 감지 임계값
  int presenceHistorySize = 3; // 사람 감지 히스토리 크기

  // 적응형 임계값 조정
  double adaptiveThreshold = 0.02;
  List<double> backgroundNoise = []; // 배경 노이즈 레벨

  // 관심 영역 기반 감지 (손/얼굴 영역)
  List<Rect> interestRegions = [
    Rect.fromLTWH(0.2, 0.1, 0.6, 0.4), // 상체 영역 (얼굴/어깨)
    Rect.fromLTWH(0.1, 0.3, 0.8, 0.6), // 손 영역
  ];

  // 프레임 수집 관련 변수들
  Timer? frameCollectionTimer;
  static const int frameCollectionCount = 45;
  static const int frameCollectionIntervalMs = 100;
  static const Duration frameCollectionInterval = Duration(
    milliseconds: frameCollectionIntervalMs,
  );

  // 웹 캡처 중복 호출 방지
  bool _isCapturingWeb = false;

  // 웹 기반 카메라 테두리 시스템
  Color _dynamicBorderColor = TablerColors.border;
  double _dynamicBorderWidth = 2.0;
  double _borderGlowIntensity = 0.0;
  bool _isPersonDetected = false;
  Timer? _borderAnimationTimer;

  // 테두리 애니메이션 상태
  double _borderPulseValue = 0.0;
  bool _isBorderPulsing = false;

  // 상태 텍스트 기반 보조 플래그
  bool get _isErrorState =>
      frameStatus.contains('오류') || frameStatus.contains('실패');
  bool get _isAnalyzingState => frameStatus.contains('분석');
  bool get isRecognitionSuccess =>
      resultKorean != null && resultKorean!.isNotEmpty;
  bool get isRecognizingNow =>
      isCameraOn &&
      (_isAnalyzingState || isCollectingFrames || frameBuffer.isNotEmpty);

  Color get _cameraBorderColor => _dynamicBorderColor;
  double get _cameraBorderWidth => _dynamicBorderWidth;

  @override
  void initState() {
    super.initState();
    _startBorderAnimation();
  }

  @override
  void dispose() {
    stopFrameCollection();
    _stopRealtimePolling();
    stopCamera();
    inputController.dispose();
    _borderAnimationTimer?.cancel();

    // 움직임 감지 시스템 리소스 정리
    previousFrameBytes = null;

    super.dispose();
  }

  Future<void> sendFrames(List<Uint8List> frames) async {
    // 카메라가 꺼져있으면 전송하지 않음
    if (!isCameraOn) {
      print("카메라가 꺼져있어 프레임 전송을 중단합니다.");
      return;
    }

    if (!hasCollectedFramesOnce) {
      setState(() {
        frameStatus = "프레임 ${frames.length}개 서버로 전송 중...";
        isCollectingFrames = false;
      });
    }

    print("프레임 ${frames.length}개 서버로 전송 시도...");
    final List<String> base64Frames = frames
        .map((frame) => base64Encode(frame))
        .toList();

    try {
      // 전송 중에도 카메라 상태 재확인
      if (!isCameraOn) {
        print("전송 중 카메라가 꺼져 프레임 전송을 중단합니다.");
        return;
      }

      final result = await TranslateApi.sendFrames(base64Frames);

      if (result != null) {
        print("서버 응답 성공: $result");
        if (!hasCollectedFramesOnce) {
          setState(() {
            frameStatus = "분석 중... 잠시만 기다려주세요";
          });
        }
      } else {
        print("서버 응답 실패: result is null");
        setState(() {
          frameStatus = "전송 실패";
        });
      }
    } catch (e) {
      print("프레임 전송 중 오류 발생: $e");
      setState(() {
        frameStatus = "전송 오류 발생";
      });
    }
  }

  void startFrameCollection() {
    frameCollectionTimer?.cancel();
    frameCollectionTimer = Timer.periodic(frameCollectionInterval, (
      timer,
    ) async {
      // 카메라가 꺼져있거나 컨트롤러가 없으면 즉시 중단
      if (!isCameraOn || cameraController == null) {
        timer.cancel();
        return;
      }

      try {
        if (_isCapturingWeb) return; // 중복 캡처 방지
        _isCapturingWeb = true;

        // 추가 안전 검사: 카메라가 꺼져있는지 다시 한번 확인
        if (!isCameraOn || cameraController == null) {
          _isCapturingWeb = false;
          return;
        }

        final picture = await cameraController!.takePicture();
        final bytes = await picture.readAsBytes();

        // 프레임 수집 중단 여부 재확인
        if (!isCameraOn) {
          _isCapturingWeb = false;
          return;
        }

        // 웹 기반 실시간 프레임 분석 및 테두리 업데이트
        await _analyzeFrameAndUpdateBorder(bytes);

        // 사람이 감지되었을 때만 프레임 수집
        if (_isPersonDetected) {
          frameBuffer.add(bytes);

          if (!hasCollectedFramesOnce) {
            setState(() {
              isCollectingFrames = true;
            });
          }
        } else {
          // 사람이 감지되지 않으면 프레임 버퍼 클리어
          if (frameBuffer.isNotEmpty) {
            frameBuffer.clear();
            setState(() {
              isCollectingFrames = false;
            });
          }
        }

        // 프레임이 충분히 모이면 전송하고 버퍼만 클리어
        if (frameBuffer.length >= frameCollectionCount) {
          // 전송 전에 카메라 상태 재확인
          if (!isCameraOn) {
            frameBuffer.clear();
            _isCapturingWeb = false;
            return;
          }

          final framesToSend = List<Uint8List>.from(frameBuffer);
          frameBuffer.clear();

          await sendFrames(framesToSend);

          if (!hasCollectedFramesOnce) {
            hasCollectedFramesOnce = true;
            setState(() {
              frameStatus = "";
              isCollectingFrames = false;
            });
          }
        }
      } catch (e) {
        print("웹 캡처 오류: $e");
      } finally {
        _isCapturingWeb = false;
      }
    });
  }

  void stopFrameCollection() {
    frameCollectionTimer?.cancel();
    frameCollectionTimer = null;
  }

  /// 테두리 애니메이션 시작
  void _startBorderAnimation() {
    _borderAnimationTimer = Timer.periodic(const Duration(milliseconds: 50), (
      timer,
    ) {
      if (mounted) {
        setState(() {
          _borderPulseValue = (_borderPulseValue + 0.1) % (2 * pi);
        });
      }
    });
  }

  /// 웹 기반 실시간 프레임 분석 및 테두리 업데이트
  Future<void> _analyzeFrameAndUpdateBorder(Uint8List frameBytes) async {
    try {
      // 사람 감지
      await _detectPerson(frameBytes);

      // 테두리 상태 업데이트
      _updateBorderState();
    } catch (e) {
      print('프레임 분석 오류: $e');
    }
  }

  /// 고급 사람 감지 (웹 최적화)
  Future<void> _detectPerson(Uint8List frameBytes) async {
    try {
      if (previousFrameBytes == null) {
        previousFrameBytes = Uint8List.fromList(frameBytes);
        return;
      }

      double presenceScore = await _calculateAdvancedPresenceScore(frameBytes);

      // 사람 존재 히스토리 관리
      recentPresenceScores.add(presenceScore);
      if (recentPresenceScores.length > presenceHistorySize) {
        recentPresenceScores.removeAt(0);
      }

      // 적응형 임계값 조정
      _updateAdaptiveThreshold();

      // 스무딩된 사람 존재 점수 계산
      double smoothedPresence = _getSmoothedPresenceScore();

      // 사람 감지 (여러 조건 체크)
      bool hasPerson = _evaluatePresence(smoothedPresence);

      // 디버깅을 위한 로그 추가
      print(
        '사람 감지 결과: 점수=$smoothedPresence, 임계값=$adaptiveThreshold, 감지됨=$hasPerson',
      );

      // 프레임 수집 상태와 연동하여 실제 인식 가능한 상태 판단
      bool canRecognize =
          hasPerson &&
          !isCollectingFrames &&
          frameBuffer.length < frameCollectionCount;

      setState(() {
        _isPersonDetected = hasPerson;
        // 사람이 감지되고 프레임 수집이 가능한 상태일 때만 인식 준비 완료
        if (canRecognize && !isCollectingFrames) {
          frameStatus = "수어 동작을 시작하세요";
        } else if (hasPerson && isCollectingFrames) {
          frameStatus =
              "프레임 수집 중... (${frameBuffer.length}/$frameCollectionCount)";
        } else if (hasPerson && !canRecognize) {
          frameStatus = "잠시만 기다려주세요...";
        } else {
          frameStatus = "카메라에 사람이 보이지 않습니다";
        }
      });

      previousFrameBytes = Uint8List.fromList(frameBytes);
    } catch (e) {
      print('고급 사람 감지 오류: $e');
    }
  }

  /// 고급 사람 존재 점수 계산
  Future<double> _calculateAdvancedPresenceScore(Uint8List frameBytes) async {
    double totalPresence = 0.0;
    int validRegions = 0;

    // 관심 영역별로 사람 존재 계산
    for (Rect region in interestRegions) {
      double regionPresence = await _calculateRegionPresence(
        frameBytes,
        region,
      );
      if (regionPresence > 0) {
        totalPresence += regionPresence;
        validRegions++;
      }
    }

    return validRegions > 0 ? totalPresence / validRegions : 0.0;
  }

  /// 특정 영역의 사람 존재 계산
  Future<double> _calculateRegionPresence(
    Uint8List frameBytes,
    Rect region,
  ) async {
    if (previousFrameBytes == null) return 0.0;

    // 프레임 크기 추정 (일반적인 JPEG 프레임 크기 가정)
    int estimatedWidth = 640;
    int estimatedHeight = 480;

    // 영역 좌표 계산
    int startX = (region.left * estimatedWidth).round();
    int endX = ((region.left + region.width) * estimatedWidth).round();
    int startY = (region.top * estimatedHeight).round();
    int endY = ((region.top + region.height) * estimatedHeight).round();

    double regionPresence = 0.0;
    int sampleCount = 0;

    // 영역 내에서 샘플링하여 사람 존재 계산
    int step = 50; // 더 세밀한 샘플링
    for (
      int i = 0;
      i < frameBytes.length - 2 && i < previousFrameBytes!.length - 2;
      i += step
    ) {
      // 대략적인 위치 계산 (정확하지 않지만 웹에서는 충분)
      int approxY = i ~/ (estimatedWidth * 3); // RGB 가정
      int approxX = (i % (estimatedWidth * 3)) ~/ 3;

      // 관심 영역 내인지 확인
      if (approxX >= startX &&
          approxX < endX &&
          approxY >= startY &&
          approxY < endY) {
        // RGB 값 추출 (안전한 범위 체크)
        int r1 = frameBytes[i];
        int g1 = frameBytes[i + 1];
        int b1 = frameBytes[i + 2];

        int r2 = previousFrameBytes![i];
        int g2 = previousFrameBytes![i + 1];
        int b2 = previousFrameBytes![i + 2];

        // 현재 프레임의 밝기와 색상 정보
        double currentBrightness = (r1 + g1 + b1) / 3.0;
        double currentSaturation = (max(max(r1, g1), b1) - min(min(r1, g1), b1))
            .toDouble();

        // 이전 프레임의 밝기와 색상 정보
        double previousBrightness = (r2 + g2 + b2) / 3.0;
        double previousSaturation =
            (max(max(r2, g2), b2) - min(min(r2, g2), b2)).toDouble();

        // 밝기 변화와 색상 변화를 종합적으로 판단
        double brightnessChange =
            (currentBrightness - previousBrightness).abs() / 255.0;
        double saturationChange =
            (currentSaturation - previousSaturation).abs() / 255.0;

        // 사람 존재 점수 계산 (밝기 + 색상 변화)
        double pixelPresence =
            (brightnessChange * 0.7 + saturationChange * 0.3);
        regionPresence += pixelPresence;
        sampleCount++;
      }
    }

    return sampleCount > 0 ? regionPresence / sampleCount : 0.0;
  }

  /// 적응형 임계값 업데이트
  void _updateAdaptiveThreshold() {
    if (recentPresenceScores.length < 3) return;

    // 최근 사람 존재의 평균과 표준편차 계산
    double mean =
        recentPresenceScores.reduce((a, b) => a + b) /
        recentPresenceScores.length;
    double variance =
        recentPresenceScores
            .map((score) => pow(score - mean, 2))
            .reduce((a, b) => a + b) /
        recentPresenceScores.length;
    double stdDev = sqrt(variance);

    // 배경 노이즈 레벨 추정
    backgroundNoise.add(mean);
    if (backgroundNoise.length > 10) {
      backgroundNoise.removeAt(0);
    }

    double avgNoise =
        backgroundNoise.reduce((a, b) => a + b) / backgroundNoise.length;

    // 적응형 임계값 = 배경 노이즈 + (표준편차 * 2)
    adaptiveThreshold = (avgNoise + (stdDev * 2)).clamp(0.01, 0.15);
  }

  /// 스무딩된 사람 존재 점수 계산
  double _getSmoothedPresenceScore() {
    if (recentPresenceScores.isEmpty) return 0.0;

    // 가중 평균 (최근 값에 더 큰 가중치)
    double weightedSum = 0.0;
    double totalWeight = 0.0;

    for (int i = 0; i < recentPresenceScores.length; i++) {
      double weight = (i + 1) / recentPresenceScores.length; // 최근일수록 높은 가중치
      weightedSum += recentPresenceScores[i] * weight;
      totalWeight += weight;
    }

    return weightedSum / totalWeight;
  }

  /// 사람 존재 평가 (여러 조건 체크)
  bool _evaluatePresence(double smoothedPresence) {
    // 1. 기본 임계값 체크
    bool aboveThreshold = smoothedPresence > adaptiveThreshold;

    // 2. 급격한 변화 감지
    bool suddenChange = false;
    if (recentPresenceScores.length >= 2) {
      double lastScore = recentPresenceScores.last;
      double prevScore = recentPresenceScores[recentPresenceScores.length - 2];
      suddenChange = (lastScore - prevScore).abs() > adaptiveThreshold * 2;
    }

    // 3. 지속적인 사람 존재 체크
    bool consistentPresence = false;
    if (recentPresenceScores.length >= 3) {
      int aboveThresholdCount = recentPresenceScores
          .where((score) => score > adaptiveThreshold * 0.5)
          .length;
      consistentPresence = aboveThresholdCount >= 2;
    }

    return aboveThreshold || suddenChange || consistentPresence;
  }

  /// 테두리 상태 업데이트
  void _updateBorderState() {
    Color newColor = TablerColors.border;
    double newGlow = 0.0;
    bool newPulsing = false;

    // 카메라가 꺼져있으면 테두리 없음
    if (!isCameraOn) {
      newColor = Colors.transparent;
      newGlow = 0.0;
      newPulsing = false;
    }
    // 사람이 감지된 경우 - 초록색 테두리 (서버로 보낼 수 있는 상태)
    else if (_isPersonDetected) {
      newColor = TablerColors.success;
      newGlow = 0.4;
      newPulsing = true;
    }
    // 사람이 감지되지 않은 경우 - 빨간색 테두리 (위험 상태)
    else if (!_isPersonDetected) {
      newColor = TablerColors.danger;
      newGlow = 0.5;
      newPulsing = true;
    }
    // 오류 상태인 경우 - 빨간색 테두리
    else if (_isErrorState) {
      newColor = TablerColors.danger;
      newGlow = 0.5;
      newPulsing = true;
    }
    // 분석 중인 경우 - 보라색 테두리
    else if (_isAnalyzingState) {
      newColor = TablerColors.primary;
      newGlow = 0.3;
      newPulsing = true;
    }
    // 프레임 수집 중인 경우 - 주황색 테두리
    else if (isCollectingFrames) {
      newColor = TablerColors.warning;
      newGlow = 0.3;
      newPulsing = true;
    }
    // 기본 상태 - 회색 테두리
    else {
      newColor = TablerColors.border;
      newGlow = 0.0;
      newPulsing = false;
    }

    // 디버깅을 위한 로그 추가
    print(
      '테두리 상태 업데이트: 카메라=$isCameraOn, 사람감지=$_isPersonDetected, 색상=$newColor',
    );

    // 상태가 변경된 경우에만 업데이트
    if (_dynamicBorderColor != newColor ||
        _borderGlowIntensity != newGlow ||
        _isBorderPulsing != newPulsing) {
      setState(() {
        _dynamicBorderColor = newColor;
        _borderGlowIntensity = newGlow;
        _isBorderPulsing = newPulsing;
      });
    }
  }

  Future<void> startCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw Exception('카메라를 찾을 수 없습니다');
      }

      final front = cameras.firstWhere(
        (cam) => cam.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      cameraController = CameraController(
        front,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await cameraController!.initialize();

      startFrameCollection();
      if (isSignToKorean) {
        _startRealtimePolling();
      }

      setState(() {
        isCameraOn = true;
        _autoFinalized = false;
        if (!hasCollectedFramesOnce) {
          frameStatus = "카메라 준비 완료!\n수어 동작을 시작하세요";
        } else {
          frameStatus = "";
        }
      });

      Fluttertoast.showToast(
        msg: '카메라가 켜졌습니다',
        backgroundColor: TablerColors.success,
        textColor: Colors.white,
      );
    } catch (e) {
      print("카메라 초기화 실패: $e");
      setState(() {
        frameStatus = "카메라 오류";
      });
      Fluttertoast.showToast(
        msg: '카메라를 켤 수 없습니다',
        backgroundColor: TablerColors.danger,
        textColor: Colors.white,
      );
    }
  }

  Future<void> stopCamera() async {
    if (cameraController == null) return;

    setState(() {
      frameStatus = "카메라 중지 중...";
      isCollectingFrames = false;
      isCameraOn = false; // 즉시 카메라 상태를 false로 설정
    });

    print("카메라 중지 요청 수신");

    // 먼저 타이머들을 중지
    stopFrameCollection();
    _stopRealtimePolling();

    // 잔여 프레임 즉시 정리
    if (frameBuffer.isNotEmpty) {
      try {
        print("잔여 프레임 ${frameBuffer.length}개 정리 중...");
        frameBuffer.clear();
      } catch (e) {
        print("잔여 프레임 정리 실패: $e");
      }
    }

    // 사람 감지 시스템 상태 초기화
    previousFrameBytes = null;
    recentPresenceScores.clear();
    backgroundNoise.clear();
    adaptiveThreshold = 0.02;
    _isPersonDetected = false;

    try {
      await cameraController!.dispose();
      print("컨트롤러 dispose 완료");
    } catch (e) {
      print("컨트롤러 dispose 오류: $e");
    } finally {
      cameraController = null;
    }

    if (mounted) {
      setState(() {
        frameStatus = "";
        hasCollectedFramesOnce = false;
      });
    }
  }

  void toggleDirection() {
    setState(() {
      isSignToKorean = !isSignToKorean;
      clearResults();
    });

    if (isCameraOn) {
      stopCamera();
    }
  }

  void clearResults() {
    resultKorean = null;
    resultEnglish = null;
    resultJapanese = null;
    resultChinese = null;
    decodeFrames = [];
    inputController.clear();
    frameStatus = '';
    isCollectingFrames = false;
    hasCollectedFramesOnce = false;
    frameBuffer.clear();

    _autoFinalized = false;

    // 사람 감지 시스템 상태 초기화
    previousFrameBytes = null;
    recentPresenceScores.clear();
    backgroundNoise.clear();
    adaptiveThreshold = 0.02;

    // 테두리 시스템 상태 초기화
    _isPersonDetected = false;
    _dynamicBorderColor = TablerColors.border;
    _dynamicBorderWidth = 2.0;
    _borderGlowIntensity = 0.0;
    _isBorderPulsing = false;
  }

  // --- 실시간 인식 폴링 로직 ---
  void _startRealtimePolling() {
    _recognitionPollingTimer?.cancel();
    _recognitionPollingTimer = Timer.periodic(const Duration(seconds: 5), (
      timer,
    ) async {
      if (!mounted || !isCameraOn || !isSignToKorean) return;
      try {
        final latest = await TranslateApi.translateLatest();
        if (latest == null) return;

        String? korean;
        final k = latest['korean'];
        if (k is List) {
          korean = k.join(' ');
        } else if (k is String) {
          korean = k.trim();
        }

        if (korean == null || korean.isEmpty) return;

        setState(() {
          resultKorean = korean;
        });

        // 자동 완료 조건 체크 (단어 개수 기준)
        final wordCount = korean
            .split(RegExp(r"\s+"))
            .where((e) => e.trim().isNotEmpty)
            .length;
        if (!_autoFinalized && wordCount >= _autoFinalizeWordCount) {
          _autoFinalized = true;
          // 기존 버튼 로직 재사용
          await handleTranslate();
        }
      } catch (_) {}
    });
  }

  void _stopRealtimePolling() {
    _recognitionPollingTimer?.cancel();
    _recognitionPollingTimer = null;
  }

  Future<void> handleTranslate() async {
    setState(() => isTranslating = true);

    try {
      if (isSignToKorean) {
        // 수어 -> 텍스트 번역
        setState(() {
          frameStatus = "번역 결과 처리 중...";
        });

        final result = await TranslateApi.translateLatest();
        if (result != null) {
          setState(() {
            resultKorean = result['korean'] is List
                ? (result['korean'] as List).join(' ')
                : result['korean']?.toString();
            resultEnglish = result['english'];
            resultJapanese = result['japanese'];
            resultChinese = result['chinese'];
            frameStatus = "";
            isCollectingFrames = false;
          });

          Fluttertoast.showToast(
            msg: '번역이 완료되었습니다',
            backgroundColor: TablerColors.success,
            textColor: Colors.white,
          );
        } else {
          setState(() {
            frameStatus = "번역 실패";
          });
          showTranslationError('번역 결과를 가져올 수 없습니다');
        }
      } else {
        // 텍스트 -> 수어 번역
        final word = inputController.text.trim();
        if (word.isEmpty) {
          Fluttertoast.showToast(
            msg: '번역할 단어를 입력하세요',
            backgroundColor: TablerColors.warning,
            textColor: Colors.white,
          );
          return;
        }

        final frameList = await TranslateApi.translate_word_to_video(word);
        if (frameList != null && frameList.isNotEmpty) {
          setState(() {
            decodeFrames = frameList.map((b64) => base64Decode(b64)).toList();
            resultKorean = word;
          });

          Fluttertoast.showToast(
            msg: '수어 번역이 완료되었습니다',
            backgroundColor: TablerColors.success,
            textColor: Colors.white,
          );
        } else {
          showTranslationError('수어 애니메이션이 없습니다');
        }
      }
    } catch (e) {
      setState(() {
        frameStatus = "오류 발생";
      });
      showTranslationError('번역 중 오류가 발생했습니다');
    } finally {
      setState(() => isTranslating = false);
    }
  }

  Future<void> translateSignToText() async {
    try {
      final result = await TranslateApi.translateLatest();
      if (result != null) {
        setState(() {
          resultKorean = result['korean'] ?? '';
          resultEnglish = result['english'] ?? '';
          resultJapanese = result['japanese'] ?? '';
          resultChinese = result['chinese'] ?? '';
        });

        Fluttertoast.showToast(
          msg: '번역이 완료되었습니다',
          backgroundColor: TablerColors.success,
          textColor: Colors.white,
        );
      } else {
        showTranslationError('번역 결과를 가져올 수 없습니다');
      }
    } catch (e) {
      showTranslationError('번역 중 오류가 발생했습니다');
    }
  }

  Future<void> translateTextToSign() async {
    final word = inputController.text.trim();
    if (word.isEmpty) {
      Fluttertoast.showToast(
        msg: '번역할 단어를 입력하세요',
        backgroundColor: TablerColors.warning,
        textColor: Colors.white,
      );
      return;
    }

    try {
      final frameList = await TranslateApi.translate_word_to_video(word);
      if (frameList != null && frameList.isNotEmpty) {
        setState(() {
          decodeFrames = frameList.map((b64) => base64Decode(b64)).toList();
          resultKorean = word;
        });

        Fluttertoast.showToast(
          msg: '수어 번역이 완료되었습니다',
          backgroundColor: TablerColors.success,
          textColor: Colors.white,
        );
      } else {
        showTranslationError('해당 단어의 수어 영상을 찾을 수 없습니다');
      }
    } catch (e) {
      showTranslationError('수어 번역 중 오류가 발생했습니다');
    }
  }

  void showTranslationError(String message) {
    Fluttertoast.showToast(
      msg: message,
      backgroundColor: TablerColors.danger,
      textColor: Colors.white,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TablerColors.background,
      body: SafeArea(
        child: Row(
          children: [
            Sidebar(initialIndex: 3),
            VerticalDivider(width: 1, color: TablerColors.border),
            Expanded(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  children: [
                    buildLanguageSelector(),
                    SizedBox(height: 24),
                    Expanded(child: buildTranslationArea()),
                    SizedBox(height: 24),
                    if (!isSignToKorean) buildTranslateButton(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildLanguageSelector() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: TablerColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: buildLanguageBox(
              isSignToKorean ? '수어' : selectedLang,
              false,
            ),
          ),
          SizedBox(width: 16),
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: TablerColors.primary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: IconButton(
              icon: Icon(Icons.swap_horiz, color: Colors.white, size: 20),
              onPressed: toggleDirection,
              tooltip: '번역 방향 전환',
              padding: EdgeInsets.zero,
              constraints: BoxConstraints(),
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: buildLanguageBox(isSignToKorean ? selectedLang : '수어', true),
          ),
        ],
      ),
    );
  }

  Widget buildLanguageBox(String language, bool isTarget) {
    if (language == '수어') {
      return Container(
        padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: TablerColors.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: TablerColors.primary.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.sign_language, color: TablerColors.primary, size: 20),
            SizedBox(width: 8),
            Text(
              '수어',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: TablerColors.primary,
              ),
            ),
          ],
        ),
      );
    }

    // 언어 선택 드롭다운
    bool canChange =
        (isSignToKorean && isTarget) || (!isSignToKorean && !isTarget);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: TablerColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedLang,
          isExpanded: true,
          icon: Icon(Icons.arrow_drop_down, color: TablerColors.textSecondary),
          items: langs
              .map(
                (lang) => DropdownMenuItem(
                  value: lang,
                  child: Text(
                    lang,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: TablerColors.textPrimary,
                    ),
                  ),
                ),
              )
              .toList(),
          onChanged: canChange
              ? (lang) => setState(() => selectedLang = lang!)
              : null,
        ),
      ),
    );
  }

  Widget buildTranslationArea() {
    return Row(
      children: [
        Expanded(child: buildInputCard()),
        SizedBox(width: 24),
        Expanded(child: buildResultCard()),
      ],
    );
  }

  Widget buildInputCard() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: TablerColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isSignToKorean ? Icons.videocam : Icons.text_fields,
                color: TablerColors.textSecondary,
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                isSignToKorean ? '수어 동작' : '텍스트 입력',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: TablerColors.textPrimary,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Expanded(child: isSignToKorean ? buildCameraArea() : buildTextArea()),
        ],
      ),
    );
  }

  Widget buildCameraArea() {
    return Column(
      children: [
        Expanded(
          child: AnimatedContainer(
            duration: Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _cameraBorderColor,
                width: _cameraBorderWidth,
              ),
              boxShadow: [
                BoxShadow(
                  color: _cameraBorderColor.withOpacity(_borderGlowIntensity),
                  blurRadius: _isBorderPulsing
                      ? 15 + 5 * sin(_borderPulseValue)
                      : 12,
                  spreadRadius: _isBorderPulsing
                      ? 2 + sin(_borderPulseValue)
                      : 1,
                ),
                if (_isBorderPulsing)
                  BoxShadow(
                    color: _cameraBorderColor.withOpacity(0.2),
                    blurRadius: 25 + 10 * sin(_borderPulseValue),
                    spreadRadius: 0,
                  ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                decoration: BoxDecoration(color: Colors.black),
                child:
                    isCameraOn && cameraController?.value.isInitialized == true
                    ? CameraPreview(cameraController!)
                    : Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.videocam_off,
                              size: 48,
                              color: Colors.white54,
                            ),
                            SizedBox(height: 16),
                            Text(
                              '카메라를 켜서\n수어 동작을 실행하십시오.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            ),
          ),
        ),
        SizedBox(height: 16),

        SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: TablerButton(
            text: isCameraOn ? '카메라 끄기' : '카메라 켜기',
            icon: isCameraOn ? Icons.videocam_off : Icons.videocam,
            outline: !isCameraOn,
            onPressed: isCameraOn ? stopCamera : startCamera,
          ),
        ),
      ],
    );
  }

  Widget buildTextArea() {
    return TextField(
      controller: inputController,
      maxLines: null,
      expands: true,
      textAlignVertical: TextAlignVertical.top,
      decoration: InputDecoration(
        hintText: '번역할 텍스트를 입력하세요...',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: TablerColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: TablerColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: TablerColors.primary, width: 2),
        ),
        contentPadding: EdgeInsets.all(16),
      ),
      style: TextStyle(fontSize: 16),
    );
  }

  Widget buildResultCard() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: TablerColors.background.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: TablerColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isSignToKorean ? Icons.text_fields : Icons.videocam,
                color: const Color.fromARGB(255, 188, 190, 192),
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                '번역 결과',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: TablerColors.textPrimary,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Expanded(
            child: isSignToKorean ? buildTextResults() : buildVideoResult(),
          ),
        ],
      ),
    );
  }

  Widget buildTextResults() {
    // 프레임 수집/전송 상태가 있으면 표시
    if (frameStatus.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.info_outline,
              size: 48,
              color: TablerColors.textSecondary,
            ),

            SizedBox(height: 16),

            Text(
              frameStatus,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: TablerColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    // 번역 결과가 있으면 표시
    if (resultKorean == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.translate, size: 48, color: TablerColors.textSecondary),
            SizedBox(height: 16),
            Text(
              '번역 결과가 여기에\n표시됩니다',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: TablerColors.textSecondary),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 수어 -> 텍스트 번역 결과
          if (isSignToKorean && resultKorean != null) ...[
            Container(
              margin: EdgeInsets.only(bottom: 12),
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: TablerColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: TablerColors.primary.withOpacity(0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    selectedLang,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: TablerColors.primary,
                    ),
                  ),
                  SizedBox(height: 4),
                  if (selectedLang == '한국어')
                    Text(
                      '$resultKorean',
                      style: TextStyle(
                        fontSize: 16,
                        color: TablerColors.textPrimary,
                      ),
                    ),
                  if (selectedLang == 'English')
                    Text(
                      '$resultEnglish',
                      style: TextStyle(
                        fontSize: 16,
                        color: TablerColors.textPrimary,
                      ),
                    ),
                  if (selectedLang == '日本語')
                    Text(
                      '$resultJapanese',
                      style: TextStyle(
                        fontSize: 16,
                        color: TablerColors.textPrimary,
                      ),
                    ),
                  if (selectedLang == '中文')
                    Text(
                      '$resultChinese',
                      style: TextStyle(
                        fontSize: 16,
                        color: TablerColors.textPrimary,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget buildVideoResult() {
    if (!isSignToKorean && decodeFrames.isNotEmpty) {
      return Column(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: AnimationWidget(
                    key: animationKey,
                    frames: decodeFrames,
                    fps: 12.0,
                  ),
                ),
              ),
            ),
          ),
          SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: TablerButton(
              text: '다시보기',
              icon: Icons.replay,
              outline: true,
              onPressed: () => animationKey.currentState?.reset(),
            ),
          ),
        ],
      );
    } else if (!isSignToKorean) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.video_library_outlined,
              size: 48,
              color: TablerColors.textSecondary,
            ),
            SizedBox(height: 16),
            Text(
              '수어 영상이 여기에\n표시됩니다',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: TablerColors.textSecondary),
            ),
          ],
        ),
      );
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.translate, size: 48, color: TablerColors.textSecondary),
          SizedBox(height: 16),
          Text(
            '결과가 여기에\n표시됩니다',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: TablerColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget buildTranslateButton() {
    return Center(
      child: SizedBox(
        width: 200,
        height: 48,
        child: TablerButton(
          text: isTranslating ? '확인 중...' : '결과 확인',
          icon: isTranslating ? null : Icons.translate,
          onPressed: isTranslating ? null : handleTranslate,
        ),
      ),
    );
  }
}
