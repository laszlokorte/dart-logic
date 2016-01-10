library shunting_dart_lexer_test;

import 'package:unittest/unittest.dart';
import 'package:shunting_dart/shunting_dart.dart';

main() {
  group('Rule', () {
    Rule rule;

    setUp((){
      rule = new Rule('char', 'a|b');
    });

    test("getter methods", () {
      expect(rule.name, equals('char'));
    });

    test("matching excatly", () {
      expect(rule.matches('a'), isTrue);
      expect(rule.matches('b'), isTrue);

      expect(rule.matches('aa'), isFalse);
      expect(rule.matches('ax'), isFalse);
      expect(rule.matches('xa'), isFalse);
    });

  });

  group('Lexer Generator', () {
    LexerGenerator generator;

    setUp((){
      generator = new LexerGenerator();
      generator.add('char', r'a|b|c');
      generator.add('number', r'\d+');

      generator.ignore(r'\s+');
    });

    test("generate lexer", () {
      Lexer lexer = generator.lexer;
      expect(lexer, new isInstanceOf<Lexer>());

      expect(lexer.ignoreRules.length, equals(1));
      expect(lexer.rules.length, equals(2));

      expect(lexer.ignoreRules.first.name, equals('ignore'));
      expect(lexer.rules.first.name, equals('char'));
      expect(lexer.rules.last.name, equals('number'));
    });

  });


  group('Lexer', () {
    LexerGenerator generator;
    Tokens tokens;

    setUp((){
      generator = new LexerGenerator();
      generator.add('c', r'a|b|c'); //char
      generator.add('o', r'\+'); //operator
      generator.add('n', r'\d+'); //number

      generator.ignore(r'\s+');

      tokens = generator.lexer.lex(r"""
23a
108+42
c
1337
""".split(""));
    });

    test("correct tokens", () {
      String result = tokens.map((Token t) => t.name).join(",");

      expect(result, equals("n,c,n,o,n,c,n"));
    });

    test("tokens line number", () {
      String result = tokens.map((Token t) => t.position.lineNumber).join(",");

      expect(result, equals("1,1,2,2,2,3,4"));
    });

    test("tokens column number", () {
      String result = tokens.map((Token t) => t.position.columnNumber).join(",");

      expect(result, equals("1,3,1,4,5,1,1"));
    });

    test("tokens position number", () {
      String result = tokens.map((Token t) => t.position.index).join(",");

      expect(result, equals("1,3,5,8,9,12,14"));

    });

  });

}