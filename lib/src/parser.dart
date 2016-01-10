part of shunting_dart;

class ParserContext<E> {

  final Stack<Token> stack = new Stack<Token>();
  final Stack<E> output = new Stack<E>();

  final Stack<bool> wereValues = new Stack<bool>();
  final Stack<int> argCount = new Stack<int>();

  final Stack<Token> scoped = new Stack<Token>();
  final Set<Token> scopeRange = new HashSet<Token>();

  int arityCount = 0;

  bool lastTokenAtom = false;

  ParserContext();
}

class Parser<E> {

  final ParserDelegate<E> delegate;

  Parser(this.delegate);

  static const String TOKEN_NAME_SCOPE_BEGIN = 'scope_begin';
  static const String TOKEN_NAME_SCOPED_VARIABLE = 'scoped_variable';
  static const String TOKEN_NAME_GLOBAL_VARIABLE = 'global_variable';

  static const String TOKEN_NAME_PREDICATE = 'predicate';

  //static const String TOKEN_NAME_VARIABLE = 'variable';
  static const String TOKEN_NAME_FUNCTION = 'function';
  static const String TOKEN_NAME_ARG_SEP = 'argument_separator';
  static const String TOKEN_NAME_UNARY_OPERATOR = 'unary_operator';
  static const String TOKEN_NAME_BINARY_OPERATOR = 'binary_operator';
  static const String TOKEN_NAME_PARENTHESE_LEFT = 'l_parenthese';
  static const String TOKEN_NAME_PARENTHESE_RIGHT = 'r_parenthese';

  /**
   * Shunting-yard algorythm
   */
  E parse(Iterable<Token> lexerResult, {bool forceParentheses: false}) {
    var context = delegate.newContext();

    for(Token token in lexerResult) {
      switch(token.name) {

        case TOKEN_NAME_GLOBAL_VARIABLE:
          if(context.stack.isEmpty || context.stack.top.id != TOKEN_NAME_PREDICATE) {
            throw new UnexpectedTokenException.explained(token, "Predicate expected.");
          }

          context.arityCount++;
          context.output.push(delegate.variableTokenToNode(token));

          if(context.wereValues.isNotEmpty) {
            context.wereValues.pop();
            context.wereValues.push(true);
          }
          break;

        case TOKEN_NAME_SCOPED_VARIABLE:
          if(context.scopeRange.contains(token)) {
            if(context.scoped.top == null) {
              throw new UnexpectedTokenException.explained(token, "Scoped variable is already bound.");
            }
            if(context.stack.isEmpty || context.stack.top.id != TOKEN_NAME_PREDICATE) {
              throw new UnexpectedTokenException.explained(token, "Predicate expected.");
            }
            context.arityCount++;
            context.output.push(delegate.variableTokenToNode(token));

            if(context.wereValues.isNotEmpty) {
              context.wereValues.pop();
              context.wereValues.push(true);
            }
          } else {
            if(context.scoped.isEmpty || context.scoped.top != null) {
              throw new UnexpectedTokenException.explained(token, "Variable has to be bound.");
            }
            context.scoped.pop();
            context.scoped.push(token);
            context.scopeRange.add(token);
            context.arityCount--;
          }

          break;

       /* read_variable:
        case TOKEN_NAME_VARIABLE:
          if(context.lastTokenAtom) {
            throw new UnexpectedTokenException(token);
          }
          context.lastTokenAtom = true;

          context.output.push(delegate.variableTokenToNode(token));

          if(context.wereValues.isNotEmpty) {
            context.wereValues.pop();
            context.wereValues.push(true);
          }

          break;*/

        case TOKEN_NAME_FUNCTION:
          if(context.lastTokenAtom) {
            throw new UnexpectedTokenException(token);
          }
          context.stack.push(token);
          context.argCount.push(0);

          if(context.wereValues.isNotEmpty) {
            context.wereValues.pop();
            context.wereValues.push(true);
          }
          context.wereValues.push(false);
          break;

        case TOKEN_NAME_ARG_SEP:
          while(context.stack.isNotEmpty && !delegate.isOpeningToken(context.stack.top)) {
            context.output.push(_pipe(context.stack.pop(), context));
          }
          if(context.stack.isEmpty || context.wereValues.isEmpty) {
            throw new UnexpectedTokenException(token);
          }
          if(context.wereValues.pop()) {
            context.argCount.push(context.argCount.pop()+1);
          }
          context.wereValues.push(true);
          context.lastTokenAtom = false;
          break;

        case TOKEN_NAME_PREDICATE:
          if(context.arityCount > 0) {
            throw new UnexpectedTokenException.explained(token, "Nested predicates are not allowed.");
          }
          if(context.lastTokenAtom) {
            throw new UnexpectedTokenException(token);
          }
          context.stack.push(token);
          context.lastTokenAtom = true;
          break;

        case TOKEN_NAME_SCOPE_BEGIN:
          context.scoped.push(null);
          context.lastTokenAtom = false;
          context.arityCount++;
          continue read_unary;

        read_unary:
        case TOKEN_NAME_UNARY_OPERATOR:
          if(context.lastTokenAtom) {
            throw new UnexpectedTokenException(token);
          }
          context.stack.push(token);
          break;

        case TOKEN_NAME_BINARY_OPERATOR:

          if (context.stack.isNotEmpty && context.stack.top.id == TOKEN_NAME_FUNCTION) {
            context.output.push(_pipe(context.stack.pop(), context));
          }

          while(
              ( !forceParentheses
                && context.stack.isNotEmpty
                && (context.stack.top.id == TOKEN_NAME_BINARY_OPERATOR ||
                    context.stack.top.id == TOKEN_NAME_UNARY_OPERATOR ||
                    context.stack.top.id == TOKEN_NAME_SCOPE_BEGIN ||
                    context.stack.top.id == TOKEN_NAME_PREDICATE
                   )
                && (
                  delegate.precedenceOfOperator(token) < delegate.precedenceOfOperator(context.stack.top) ||
                  (delegate.assocOfOperator(token) == Associativity.LEFT &&
                   delegate.precedenceOfOperator(token) == delegate.precedenceOfOperator(context.stack.top))
                )
              )
              ||
              ( forceParentheses
                && context.stack.isNotEmpty
                && (context.stack.top.id == TOKEN_NAME_UNARY_OPERATOR ||
                    context.stack.top.id == TOKEN_NAME_SCOPE_BEGIN ||
                    context.stack.top.id == TOKEN_NAME_PREDICATE)
                && delegate.precedenceOfOperator(token) < delegate.precedenceOfOperator(context.stack.top)
              )
          ) {
            context.output.push(_pipe(context.stack.pop(), context));
          }

          if(forceParentheses && (context.stack.isEmpty || !delegate.isOpeningToken(context.stack.top))) {
            throw new AmbiguousParsingException(token);
          }

          context.stack.push(token);
          context.lastTokenAtom = false;
          break;

        default:
          if(delegate.isOpeningToken(token)) {
            if(context.lastTokenAtom) {
              throw new UnexpectedTokenException(token);
            }
            context.stack.push(token);
          } else if(delegate.isClosingToken(token)) {
            Token stackTop = null;
            Token stackScopeBottom;
            while(context.stack.isNotEmpty && !delegate.isMatchingPair(context.stack.top, token)) {
              context.output.push(_pipe(stackTop = context.stack.pop(), context));
            }

            if(context.stack.isNotEmpty) {
              stackScopeBottom = context.stack.pop();
            } else {
              throw new MismatchedTokenException.notOpened(token);
            }

            if(context.stack.isNotEmpty && context.stack.top.id == TOKEN_NAME_FUNCTION) {
              if(forceParentheses && (context.wereValues.isEmpty || !context.wereValues.top)) {
                throw new RedundancyParsingException(stackScopeBottom);
              }
              context.output.push(_pipe(context.stack.pop(), context));
            } else if(forceParentheses && (stackTop==null ||
                stackTop.name == TOKEN_NAME_UNARY_OPERATOR ||
                stackTop.name == TOKEN_NAME_FUNCTION
            )) {
              throw new RedundancyParsingException(stackScopeBottom);
            }
          } else {
            delegate.unknownToken(token, context, this.finalize);
          }

      }
    }

    return delegate.finish(finalize, context);
  }

  E finalize(context) {
    while(context.stack.isNotEmpty) {
      if(delegate.isOpeningToken(context.stack.top)) {
        throw new MismatchedTokenException.notClosed(context.stack.top);
      }
      if(delegate.isClosingToken(context.stack.top)) {
        throw new MismatchedTokenException.notOpened(context.stack.top);
      }
      context.output.push(_pipe(context.stack.pop(), context));
    }

    if(context.output.isNotEmpty) {
      E result = context.output.pop();
      if(context.output.isNotEmpty) {
        throw new ParsingException("Unexpecteded parse error. Parser is in invalid state. ${context.output.top}, $result", new Token('E','E',new SourcePosition(1,1,0)));
      }
      return result;
    } else {
      return delegate.emptyNode();
    }
  }


  E _pipe(Token op, ParserContext<E> context) {
    switch(op.name) {
      case TOKEN_NAME_SCOPE_BEGIN:
        if(!delegate.hasScopeOperator(op)) {
          throw new UnknownOperatorException.scope(op);
        }

        if(context.scoped.isEmpty || context.scoped.top == null) {
          throw new UnexpectedTokenException(op);
        }
        E range;
        Token scopedVar = context.scoped.pop();
        context.scopeRange.remove(scopedVar);

        if(context.output.isNotEmpty) {
          range = context.output.pop();
        } else {
          throw new MissingOperandException.unary(op);
        }

        return delegate.scopeOperatorToNode(op, delegate.variableTokenToNode(scopedVar), range);

        break;

      case TOKEN_NAME_PREDICATE:
        var list = [];
        while(context.output.isNotEmpty && context.arityCount > 0) {
          list.add(context.output.pop());
          context.arityCount--;
        }
        if(context.arityCount>0) {
          throw new ParsingException("...", op);
        }

        return delegate.predicateTokenToNode(op, list.reversed);

        break;

      case TOKEN_NAME_FUNCTION:
        bool w = context.wereValues.pop();
        int  a = context.argCount.pop();
        List<E> temp = new List<E>();

        while(a-->0 && context.output.isNotEmpty) {
          temp.add(context.output.pop());
        }
        if(w && context.output.isNotEmpty) {
          temp.add(context.output.pop());
        } else if(w) {
          throw new ParsingException("Unexpected end of argument list for function '${op.value}'.", op);
        }
        return delegate.functionTokenToNode(op, temp.reversed);

      case TOKEN_NAME_UNARY_OPERATOR:
        E operand;

        if(!delegate.hasUnaryOperator(op)) {
          throw new UnknownOperatorException.binary(op);
        }

        if(context.output.isNotEmpty) {
          operand = context.output.pop();
        } else {
          throw new MissingOperandException.unary(op);
        }

        return delegate.unaryOperatorToNode(op, operand);

      case TOKEN_NAME_BINARY_OPERATOR:
        E leftHand, rightHand;

        if(!delegate.hasBinaryOperator(op)) {
          throw new UnknownOperatorException.binary(op);
        }

        if(context.output.isNotEmpty) {
          rightHand = context.output.pop();
        } else {
          throw new MissingOperandException.binary(op, 2);
        }

        if(context.output.isNotEmpty) {
          leftHand = context.output.pop();
        } else {
          throw new MissingOperandException.binary(op, 1);
        }

        return delegate.binaryOperatorToNode(op, leftHand, rightHand);
      default:
        return delegate.unknownOperator(op, context, this.finalize);
    }
  }

}

class Associativity {
  static const LEFT = const Associativity._(0);
  static const RIGHT = const Associativity._(1);

  static get values => [LEFT, RIGHT];

  final int value;

  const Associativity._(this.value);
}

abstract class ParserDelegate<E> {

  bool isOpeningToken(Token token) {
    return [
            Parser.TOKEN_NAME_PARENTHESE_LEFT
            ].contains(token.name);
  }

  bool isClosingToken(Token token) {
    return [
            Parser.TOKEN_NAME_PARENTHESE_RIGHT
            ].contains(token.name);
  }

  bool isMatchingPair(Token left, Token right) {
    return (left.name == Parser.TOKEN_NAME_PARENTHESE_LEFT) && (right.name==Parser.TOKEN_NAME_PARENTHESE_RIGHT);
  }

  E variableTokenToNode(Token token);

  E emptyNode();

  E unaryOperatorToNode(Token operator, E operand);

  E binaryOperatorToNode(Token operator, E leftHand, E rightHand);

  E functionTokenToNode(Token function, Iterable<E> args);

  E scopeOperatorToNode(Token operator, E scopedVar, E range);

  E predicateTokenToNode(Token pred, Iterable<E> args);

  bool hasBinaryOperator(Token operator);

  bool hasUnaryOperator(Token operator);

  bool hasScopeOperator(Token operator);

  Associativity assocOfOperator(Token token);

  int precedenceOfOperator(Token);

  void unknownToken(Token token, ParserContext<E> context, finalize) {
    throw new UnexpectedTokenException(token);
  }

  E unknownOperator(Token op, ParserContext<E> context, finalize) {
    throw new UnexpectedTokenException(op);
  }

  ParserContext<E> newContext();

  E finish(finalize, context) {
    return finalize(context);
  }

}

/**
 * Superclass for all Exceptions thrown when parsing fails.
 */
class ParsingException implements Exception {
  final String msg;
  final Token token;

  ParsingException(this.msg, this.token);
}

/**
 * Exception thrown when the parser reads an token it did not expect.
 */
class UnexpectedTokenException extends ParsingException {
  final String detail;

  UnexpectedTokenException(Token t) :
    super("Unexpected token ${t.value} (${t.name}).", t),
    this.detail = null;

  UnexpectedTokenException.explained(Token t, String explaination) :
    super("Unexpected token ${t.value} (${t.name}). $explaination", t),
    this.detail = explaination;

}

/**
 * Exception thrown when two tokens which must occure in pairs do not match.
 */
class MismatchedTokenException extends ParsingException {
  final bool open;

  MismatchedTokenException.notClosed(Token t) :
    super("Token '${t.value}' (${t.name}) has to be closed.", t),
    this.open = true;

  MismatchedTokenException.notOpened(Token t) :
    super("Unxpected closing token '${t.value}' (${t.name}).", t),
    this.open = false;

}

/**
 * Exception thrown when the parser reads an operator token but can not find matching operands.
 */
class MissingOperandException extends ParsingException {
  final int arity;
  final int missing;

  MissingOperandException.unary(Token t) :
    super("Missing operand for unary operator '${t.value}'.", t),
    this.arity = 1,
    this.missing = 1;

  MissingOperandException.binary(Token t, int missing) :
    super("Missing ${missing==1?'one operand':'two operands'} for binary operator '${t.value}'.", t),
    this.arity = 2,
    this.missing = missing;
}

/**
 * Exception thrown when the parser does not know the operand.
 */
class UnknownOperatorException extends ParsingException {
  final int arity;

  UnknownOperatorException.unary(Token t) :
    super("Unknown unary operator '${t.value}'.", t),
    this.arity = 1;

  UnknownOperatorException.binary(Token t) :
    super("Unknown binary operator '${t.value}'.", t),
    this.arity = 2;

  UnknownOperatorException.scope(Token t) :
    super("Unknown scope operator '${t.value}'.", t),
    this.arity = 2;
}

/**
 * Exception thrown when the parser runs in strict mode and.
 */
class StrictParsingException extends ParsingException {
  StrictParsingException(msg, Token t) : super(msg, t);
}

/**
 * Exception thrown when the parser finds redundant syntax.
 */
class RedundancyParsingException extends StrictParsingException {
  RedundancyParsingException(Token t) : super("Redundant pair of parantheses.", t);
}

/**
 * Exception thrown when the the syntax is ambigous.
 */
class AmbiguousParsingException extends StrictParsingException {
  AmbiguousParsingException(Token t) : super("Parantheses required for ${t.name} '${t.value}'.", t);
}
