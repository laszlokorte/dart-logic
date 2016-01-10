library shunting_dart_token_test;

import 'package:unittest/unittest.dart';
import 'package:shunting_dart/shunting_dart.dart';

main() {
  group('Token', () {
    Token token;

    setUp((){
      SourcePosition pos = new SourcePosition(108,23,42);
      token = new Token('operator', '+', pos);
    });

    test("getter methods", () {
      expect(token.name, equals('operator'));
      expect(token.value, equals('+'));
      expect(token.position, new isInstanceOf<SourcePosition>());
    });

    test("toString", () {
      expect(token.toString(), equals("Token(operator, +, Pos:108)"));
    });

    test("equality", () {
      SourcePosition pos = new SourcePosition(108,23,42);
      SourcePosition otherPos = new SourcePosition(13,37,5);
      Token token = new Token('operator', '+', pos);
      Token sameToken = new Token('operator', '+', pos);
      Token equalToken = new Token('operator', '+', otherPos);
      Token otherValueToken = new Token('operator', '*', pos);
      Token otherNameToken = new Token('prefix', '+', pos);
      Token otherToken = new Token('comma', ',', pos);

      expect(token, equals(token));
      expect(token, equals(sameToken));
      expect(token, equals(equalToken));

      expect(token, isNot(equals(otherValueToken)));
      expect(token, isNot(equals(otherNameToken)));
      expect(token, isNot(equals(otherToken)));
    });
  });


  group('SourcePosition', () {
    SourcePosition pos;

    setUp((){
      pos = new SourcePosition(108,23,42);
    });

    test("getter methods", () {
      expect(pos.index, equals(108));
      expect(pos.lineNumber, equals(23));
      expect(pos.columnNumber, equals(42));
    });

    test("toString", () {
      expect(pos.toString(), equals("Position(108,line:23,column:42)"));
    });
  });
}