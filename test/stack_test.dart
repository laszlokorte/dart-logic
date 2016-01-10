library shunting_dart_stack_test;

import 'package:unittest/unittest.dart';
import 'package:shunting_dart/shunting_dart.dart';

main() {
  group('Stack', () {
    Stack<int> stack;

    setUp(() {
      stack = new Stack<int>();
    });

    test("stack is initially empty", () {
      expect(stack.isEmpty, isTrue);
      expect(stack.isNotEmpty, isFalse);
    });

    test("can push element", () {
      stack.push(5);

      expect(stack.top, equals(5));
      expect(stack.isEmpty, isFalse);
      expect(stack.isNotEmpty, isTrue);
    });

    test("can pop element", () {
      stack.push(5);
      var el = stack.pop();

      expect(el, equals(5));
      expect(stack.isEmpty, isTrue);
      expect(stack.isNotEmpty, isFalse);
    });

    test("LIFO", () {
      stack.push(1);
      stack.push(2);
      stack.push(3);
      stack.push(4);

      expect(stack.pop(), equals(4));
      expect(stack.pop(), equals(3));
      expect(stack.pop(), equals(2));
      expect(stack.pop(), equals(1));

      expect(stack.isEmpty, isTrue);
    });

    test("can not pop if empty", () {
      expect(()=> stack.pop(),
          throwsA(new isInstanceOf<EmptyStackException>()));

      expect(()=> stack.top,
          throwsA(new isInstanceOf<EmptyStackException>()));


      expect(stack.isEmpty, isTrue);
      expect(stack.isNotEmpty, isFalse);
    });

    test("can not access top if empty", () {
      expect(()=> stack.top,
          throwsA(new isInstanceOf<EmptyStackException>()));
    });
  });
}