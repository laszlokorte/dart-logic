library test_browser_runner;

import 'package:unittest/interactive_html_config.dart';
import 'stack_test.dart' as stack;
import 'token_test.dart' as token;
import 'lexer_test.dart' as lexer;

main() {
  useInteractiveHtmlConfiguration();
  stack.main();
  token.main();
  lexer.main();
}