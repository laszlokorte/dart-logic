library quantoren_logic;

import 'dart:collection';
import 'package:shunting_dart/shunting_dart.dart';

export 'package:shunting_dart/shunting_dart.dart';


QuantumParser logicParser() {
  return new QuantumParser();
}

Lexer logicLexer() {
  return (new LexerGenerator()
  ..add('variable', r'(x|y|z)')
  ..add('l_parenthese', r'\(')
  ..add('r_parenthese', r'\)')

  ..add('quantor', r'(E|A)')

  ..add('sequence_separator', r',')
  ..add('unary_operator', r'!')
  ..add('binary_operator', r'&')
  ..add('binary_operator', r'V')
  ..add('binary_operator', r'->')


  ..add('ergo', r'::')

  ..ignore(r'\s+')).lexer;
}

class QuantumParser<E> {

  E parse(Tokens tokens) {

    Stack<Token> quantorStack = new Stack<Token>();
    Set<String> bindings = new HashSet<String>();

    for(Token token in tokens) {
      switch(token.name) {

        case 'quantor':
          quantorStack.push(token);



      }
    }
  }

}