import 'package:flutter_test/flutter_test.dart';
import 'package:nai_huishi/presentation/pages/home_page.dart';

void main() {
  test('home page defaults to generate tab index', () {
    expect(HomePage.initialIndex, 1);
  });
}
