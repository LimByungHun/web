import 'dart:convert';
import 'dart:typed_data';
import 'dart:js' as js;
import 'dart:async';

class OpenCVWeb {
  static bool _isInitialized = false;
  static Completer<bool>? _initCompleter;

  // 🎨 OpenCV 처리 활성화 여부 (컬러 유지를 위해 true로 설정)
  static bool enableProcessing = true; // true: OpenCV 처리, false: 원본 유지

  /// OpenCV 처리 모드 변경
  static void setProcessingMode(bool enabled) {
    enableProcessing = enabled;
    print(enabled ? '🔧 OpenCV 처리 활성화' : '🎨 원본 컬러 유지 모드');
  }

  /// OpenCV.js 초기화 확인 (Promise 기반)
  static Future<bool> initialize() async {
    if (_isInitialized) return true;

    // 이미 초기화 중인 경우 기다림
    if (_initCompleter != null) {
      return await _initCompleter!.future;
    }

    _initCompleter = Completer<bool>();

    try {
      // JavaScript의 OpenCV 로더 사용
      if (js.context.hasProperty('cvReady')) {
        print('🔄 OpenCV 로드 대기 중...');

        // cvReady Promise 대기
        final completer = Completer<bool>();
        final cvReadyPromise = js.context['cvReady'];

        cvReadyPromise.callMethod('then', [
          js.allowInterop((result) {
            final success = result == true;
            print(success ? '✅ OpenCV 로드 성공' : '❌ OpenCV 로드 실패');
            completer.complete(success);
          }),
          js.allowInterop((error) {
            print('❌ OpenCV 로드 에러: $error');
            completer.complete(false);
          }),
        ]);

        // 타임아웃 설정 (40초)
        final result = await Future.any([
          completer.future,
          Future.delayed(Duration(seconds: 40), () => false),
        ]);

        _isInitialized = result;
        _initCompleter!.complete(result);

        if (result) {
          print('🎉 OpenCV 초기화 완료 - 수어 인식 준비됨');
        } else {
          print('⚠️ OpenCV 초기화 실패 - 수어 인식 불가');
        }

        return result;
      } else {
        print('❌ cvReady Promise를 찾을 수 없음');
        _initCompleter!.complete(false);
        return false;
      }
    } catch (e) {
      print('💥 OpenCV 초기화 예외: $e');
      _initCompleter!.complete(false);
      return false;
    }
  }

  /// OpenCV 상태 확인
  static bool checkStatus() {
    try {
      if (js.context.hasProperty('isOpenCVReady')) {
        return js.context.callMethod('isOpenCVReady');
      }

      // 대체 확인 방법
      return js.context.hasProperty('cv') &&
          js.context['cv'] != null &&
          js.context['cv']['Mat'] != null &&
          js.context.hasProperty('processImageBase64');
    } catch (e) {
      print('OpenCV 상태 확인 실패: $e');
      return false;
    }
  }

  /// 이미지 처리 (컬러 유지 옵션)
  static Future<Uint8List> processImage(Uint8List rawBytes) async {
    try {
      // OpenCV 처리 비활성화된 경우 원본 반환
      if (!enableProcessing) {
        print('🎨 원본 컬러 이미지 유지');
        return rawBytes;
      }

      // OpenCV 초기화 확인
      if (!_isInitialized) {
        print('OpenCV 미초기화, 초기화 시도...');
        final initialized = await initialize();
        if (!initialized) {
          print('⚠️ OpenCV 초기화 실패, 원본 이미지 반환');
          return rawBytes;
        }
      }

      // 런타임 상태 재확인
      if (!checkStatus()) {
        print('⚠️ OpenCV 런타임 상태 불량, 원본 이미지 반환');
        return rawBytes;
      }

      // 이미지 형식 감지
      String mimeType = _detectImageFormat(rawBytes);
      final base64Str = 'data:$mimeType;base64,${base64Encode(rawBytes)}';

      // JavaScript 함수 호출
      final completer = Completer<String>();

      try {
        final result = js.context.callMethod('processImageBase64', [base64Str]);

        // Promise 처리
        result.callMethod('then', [
          js.allowInterop((value) {
            if (!completer.isCompleted) {
              completer.complete(value.toString());
            }
          }),
          js.allowInterop((error) {
            if (!completer.isCompleted) {
              print('🔧 OpenCV 처리 오류: $error');
              completer.completeError(error.toString());
            }
          }),
        ]);
      } catch (e) {
        completer.completeError(e);
      }

      // 타임아웃과 함께 결과 대기
      String processedBase64;
      try {
        processedBase64 = await completer.future.timeout(
          Duration(seconds: 5),
          onTimeout: () {
            print('⏰ OpenCV 처리 타임아웃');
            throw TimeoutException(
              'OpenCV processing timeout',
              Duration(seconds: 5),
            );
          },
        );
      } catch (e) {
        print('OpenCV 처리 실패: $e, 원본 반환');
        return rawBytes;
      }

      // Base64 디코딩
      try {
        final base64Data = processedBase64.split(',').last;
        final result = base64Decode(base64Data);
        print(
          '✅ OpenCV 이미지 처리 성공 (${rawBytes.length} → ${result.length} bytes)',
        );
        return result;
      } catch (e) {
        print('Base64 디코딩 실패: $e');
        return rawBytes;
      }
    } catch (e) {
      print('💥 OpenCV 이미지 처리 예외: $e');
      return rawBytes;
    }
  }

  /// 이미지 형식 자동 감지
  static String _detectImageFormat(Uint8List bytes) {
    if (bytes.length >= 8) {
      // PNG 시그니처 (89 50 4E 47 0D 0A 1A 0A)
      if (bytes[0] == 0x89 &&
          bytes[1] == 0x50 &&
          bytes[2] == 0x4E &&
          bytes[3] == 0x47) {
        return 'image/png';
      }
      // JPEG 시그니처 (FF D8)
      else if (bytes[0] == 0xFF && bytes[1] == 0xD8) {
        return 'image/jpeg';
      }
      // WebP 시그니처 (52 49 46 46 ... 57 45 42 50)
      else if (bytes[0] == 0x52 &&
          bytes[1] == 0x49 &&
          bytes[2] == 0x46 &&
          bytes[3] == 0x46 &&
          bytes.length >= 12 &&
          bytes[8] == 0x57 &&
          bytes[9] == 0x45 &&
          bytes[10] == 0x42 &&
          bytes[11] == 0x50) {
        return 'image/webp';
      }
    }
    return 'image/jpeg'; // 기본값
  }

  /// OpenCV 가용성 확인
  static bool get isAvailable {
    return _isInitialized && checkStatus();
  }

  /// 강제 재초기화
  static Future<bool> forceReinitialize() async {
    print('🔄 OpenCV 강제 재초기화 시작');
    _isInitialized = false;
    _initCompleter = null;
    return await initialize();
  }

  /// 상세 상태 정보
  static Map<String, dynamic> getDetailedStatus() {
    return {
      'initialized': _isInitialized,
      'enableProcessing': enableProcessing,
      'hasCV': js.context.hasProperty('cv'),
      'hasCVReady': js.context.hasProperty('cvReady'),
      'hasProcessFunction': js.context.hasProperty('processImageBase64'),
      'hasStatusFunction': js.context.hasProperty('isOpenCVReady'),
      'runtimeStatus': checkStatus(),
    };
  }
}
