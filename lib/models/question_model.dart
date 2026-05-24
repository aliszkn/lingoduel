class QuestionModel {
  final String desc;
  final String descTr;
  final String answer;
  final String wrong1;
  final String wrong2;
  final String wrong3;
  final String wrong4;

  const QuestionModel({
    required this.desc,
    required this.descTr,
    required this.answer,
    required this.wrong1,
    required this.wrong2,
    required this.wrong3,
    required this.wrong4,
  });

  List<String> get allOptions => [answer, wrong1, wrong2, wrong3, wrong4];
}
