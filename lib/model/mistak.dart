/// 틀린 문제 한 건을 담는 모델 (필요에 따라 확장)
class Mistake {
  final String prompt; // 문제 텍스트
  final String assetPath; // 관련 영상/이미지 경로
  final String correct; // 정답
  Mistake({
    required this.prompt,
    required this.assetPath,
    required this.correct,
  });
}
