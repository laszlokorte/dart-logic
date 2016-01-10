library classy_logic;

import 'dart:collection';
import 'dart:math' as math;
import 'package:shunting_dart/shunting_dart.dart';

export 'package:shunting_dart/shunting_dart.dart';


x() {
  Map<Type, String> foo = new HashMap();
  foo[String] = "string";
}

Parser logicParser() {
  return new Parser<LogicNode>(new ClassicLogicParserDelegate());
}

const String TOKEN_CUSTOM_NAME_PREMISE_SEPARATOR = 'sequence_separator';
const String TOKEN_CUSTOM_NAME_LITERAL = 'literal';
const String TOKEN_CUSTOM_NAME_ERGO = 'ergo';

const String TOKEN_CUSTOM_NAME_BRACKET_LEFT = 'bracket_l';
const String TOKEN_CUSTOM_NAME_BRACKET_RIGHT = 'bracket_r';

Lexer logicLexer() {
  return (new LexerGenerator()
  ..add(Parser.TOKEN_NAME_PREDICATE, r'(P\d*|Q|R|S|T)')
  ..add(Parser.TOKEN_NAME_PARENTHESE_LEFT, r'\(')
  ..add(Parser.TOKEN_NAME_PARENTHESE_RIGHT, r'\)')

  ..add(TOKEN_CUSTOM_NAME_BRACKET_LEFT, r'\[')
  ..add(TOKEN_CUSTOM_NAME_BRACKET_RIGHT, r'\]')

  ..add(Parser.TOKEN_NAME_UNARY_OPERATOR, r'!')
  ..add(Parser.TOKEN_NAME_BINARY_OPERATOR, r'&')
  ..add(Parser.TOKEN_NAME_BINARY_OPERATOR, r'v')
  ..add(Parser.TOKEN_NAME_BINARY_OPERATOR, r'->')

  ..add(TOKEN_CUSTOM_NAME_PREMISE_SEPARATOR, r',')
  ..add(TOKEN_CUSTOM_NAME_LITERAL, r'W')
  ..add(TOKEN_CUSTOM_NAME_LITERAL, r'F')
  ..add(TOKEN_CUSTOM_NAME_ERGO, r'::')

  ..add(Parser.TOKEN_NAME_SCOPE_BEGIN, r'(E|A)')
  ..add(Parser.TOKEN_NAME_SCOPED_VARIABLE, r'(x\d*|y|z)')
  ..add(Parser.TOKEN_NAME_GLOBAL_VARIABLE, r'(m\d*|n)')
  ..add(Parser.TOKEN_NAME_PREDICATE, r'(G\d*|H|J)')

  ..ignore(r'\s+')
  ..ignore(r'\u00A0+')).lexer;
}

class LogicEnvironment {

}

abstract class LogicNodeVisitor<E> {

  const LogicNodeVisitor();

  E visitLogicNode(LogicNode node);

  E visitSequenceNode(SequenceNode node);

  E visitArgumentNode(ArgumentNode node);

  E visitEmptyNode(EmptyNode node);

  E visitFunctionNode(FunctionNode node);

  E visitPredicateNode(PredicateNode node);

  E visitUnaryOperatorNode(UnaryOperatorNode node);

  E visitBinaryOperatorNode(BinaryOperatorNode node);

  E visitNameNode(VariableNode node);

  E visitValueNode(ValueNode node);

  E visitQuantorNode(QuantorOperatorNode node);

}

class TreeWidthMeasurer extends LogicNodeVisitor<int> {
  const TreeWidthMeasurer();

  int visitLogicNode(LogicNode node) => 1;

  int visitSequenceNode(SequenceNode node) {
    return node.nodeList
        .map((LogicNode n) => n.acceptVisitor(this))
        .fold(node.nodeList.length*2-2, (left, right) => left+right);
  }

  int visitArgumentNode(ArgumentNode node)
    => 1 + node.premises.acceptVisitor(this)
         + node.conclusion.acceptVisitor(this);

  int visitEmptyNode(EmptyNode node) => 1;

  int visitFunctionNode(FunctionNode node) => 1;

  int visitPredicateNode(PredicateNode node)
    => node.args.fold(1, (int a, LogicNode b) => a+b.acceptVisitor(this));

  int visitUnaryOperatorNode(UnaryOperatorNode node)
    => 1 + node.operand.acceptVisitor(this);

  int visitBinaryOperatorNode(BinaryOperatorNode node) {
    return 1 + node.operation.length +
        node.leftHandOperand.acceptVisitor(this) +
        node.rightHandOperand.acceptVisitor(this);
  }

  int visitNameNode(VariableNode node) => 1;

  int visitValueNode(ValueNode node) => 1;

  int visitQuantorNode(QuantorOperatorNode node)
    => 2 + node.scopeName.acceptVisitor(this)
         + node.range.acceptVisitor(this);
}

class TreeHeightMeasurer extends LogicNodeVisitor<int> {
  const TreeHeightMeasurer();

  int visitLogicNode(LogicNode node) => 1;

  int visitSequenceNode(SequenceNode node)
    => 1 + node.nodeList
    .fold(0, (left, LogicNode right) => math.max(left,right.acceptVisitor(this)));

  int visitArgumentNode(ArgumentNode node) {
    return 1 + math.max(
        node.premises.acceptVisitor(this),
        node.conclusion.acceptVisitor(this)
        );
  }

  int visitEmptyNode(EmptyNode node) => 1;

  int visitFunctionNode(FunctionNode node) => 1;

  int visitPredicateNode(PredicateNode node) => 2;

  int visitUnaryOperatorNode(UnaryOperatorNode node)
    => 1 + node.operand.acceptVisitor(this);

  int visitBinaryOperatorNode(BinaryOperatorNode node) {
    return 1 + math.max(
        node.leftHandOperand.acceptVisitor(this),
        node.rightHandOperand.acceptVisitor(this)
        );
  }

  int visitNameNode(VariableNode node) => 1;

  int visitValueNode(ValueNode node) => 1;

  int visitQuantorNode(QuantorOperatorNode node)
    => 1 + node.range.acceptVisitor(this);
}

class TreeMapper extends LogicNodeVisitor<Map> {

  bool _right = false;

  bool get isRight => _right;

  Map right(scope, [bool right = true]) {
    bool temp = _right;
    try {
      _right = right;
      return scope();
    } finally {
      _right = temp;
    }
  }

  Map visitLogicNode(LogicNode node) {
    return {
      "name":"$node",
      "right": _right,
      "children": [ node.acceptVisitor(this) ]
      };
  }

  Map visitSequenceNode(SequenceNode node) {
    if(node.nodeList.length == 1) {
      return node.nodeList.first.acceptVisitor(this);
    }

    int i = node.nodeList.length~/2;
    return {
      "name":"Σ",
      "right": _right,
      "children": node.nodeList.map((n) => right(() => n.acceptVisitor(this), --i<0) ).toList()
      };
  }

  Map visitArgumentNode(ArgumentNode node) {
    return {
      "name":"::",
      "right": _right,
      "children": [
                    node.premises.acceptVisitor(this),
                    right(()=>node.conclusion.acceptVisitor(this))
                    ]
      };
  }

  Map visitEmptyNode(EmptyNode node) {
    return {
      "name" : "empty",
      "right": _right
      };
  }

  Map visitFunctionNode(FunctionNode node) {
    int i = node.args.length~/2;
    return {
      "name":node.name,
      "right": _right,
      "children": node.args.map((n) => right(() => n.acceptVisitor(this), --i<0) ).toList()
      };
  }

  Map visitPredicateNode(PredicateNode node) {
    return {
      "name":node.name,
      "right": _right,
      "children": node.args.map((n) => n.acceptVisitor(this) ).toList()
      };
  }

  Map visitUnaryOperatorNode(UnaryOperatorNode node) {
    return {
      "name":node.operation,
      "right": _right,
      "children": [ node.operand.acceptVisitor(this) ]
      };
  }

  Map visitBinaryOperatorNode(BinaryOperatorNode node) {
    return {
      "name":node.operation,
      "right": _right,
      "children": [ node.leftHandOperand.acceptVisitor(this),
                    right(()=>node.rightHandOperand.acceptVisitor(this)) ]
      };
  }

  Map visitNameNode(VariableNode node) {
    return {
      "name":node.value,
      "right": _right,
      "children": [ ]
      };
  }

  Map visitValueNode(ValueNode node) {
    return {
      "name":node.value ? "W" : "F",
      "right": _right,
      "children": [ ]
      };
  }

  Map visitQuantorNode(QuantorOperatorNode node) {
    return {
      "name": "${node.name}${node.scopeName}",
      "right": _right,
      "children": [ node.range.acceptVisitor(this) ]
      };
  }

}

class BigTreeMapper extends TreeMapper {

  Map visitLogicNode(LogicNode node) {
    return {
      "name":"$node",
      "right": isRight,
      "children": [super.visitLogicNode(node)]
      };
  }

  Map visitSequenceNode(SequenceNode node) {
    if(node.nodeList.length == 1) {
      return node.nodeList.first.acceptVisitor(this);
    }

    return {
      "name":"$node",
      "right": isRight,
      "children": [super.visitSequenceNode(node)]
      };
  }

  Map visitArgumentNode(ArgumentNode node) {
    return {
      "name":"$node",
      "right": isRight,
      "children": [super.visitArgumentNode(node)]
      };
  }

  Map visitEmptyNode(EmptyNode node) {
    return {
      "name":"$node",
      "right": isRight,
      "children": [super.visitEmptyNode(node)]
      };
  }

  Map visitFunctionNode(FunctionNode node) {
    return {
      "name":"$node",
      "right": isRight,
      "children": [super.visitFunctionNode(node)]
      };
  }

  Map visitUnaryOperatorNode(UnaryOperatorNode node) {
    return {
      "name":"$node",
      "right": isRight,
      "children": [super.visitUnaryOperatorNode(node)]
      };
  }

  Map visitBinaryOperatorNode(BinaryOperatorNode node) {
    return {
      "name":"$node",
      "right": isRight,
      "children": [super.visitBinaryOperatorNode(node)]
      };
  }

  Map visitQuantorNode(QuantorOperatorNode node) {
    return {
      "name":"$node",
      "right": isRight,
      "children": [super.visitQuantorNode(node)]
      };
  }
}

abstract class NodeFinder<E> extends LogicNodeVisitor<Set<E>> {

  const NodeFinder();

  Set<E> _thisIfMatch(LogicNode node) {
    var set = new HashSet<E>();
    if(match(node)) {
      set.add(node);
    }
    return set;
  }

  bool match(LogicNode node);

  bool stopAt(LogicNode node);

  Set<E> visitLogicNode(LogicNode node) => _thisIfMatch(node);

  Set<E> visitSequenceNode(SequenceNode node) {
    if(stopAt(node)) {
      return _thisIfMatch(node);
    }

    return node.nodeList
        .fold(_thisIfMatch(node), (left, right) => left.union(right.acceptVisitor(this)));
  }

  Set<E> visitArgumentNode(ArgumentNode node) {
    if(stopAt(node)) {
      return _thisIfMatch(node);
    }

    return node.premises.acceptVisitor(this)
        .union(node.conclusion.acceptVisitor(this))
        .union(_thisIfMatch(node));
  }

  Set<E> visitEmptyNode(EmptyNode node) => _thisIfMatch(node);

  Set<E> visitFunctionNode(FunctionNode node) {
    if(stopAt(node)) {
      return _thisIfMatch(node);
    }

    return node.args
        .fold(_thisIfMatch(node), (left, right) => left.union(right.acceptVisitor(this)));
  }

  Set<E> visitPredicateNode(PredicateNode node) {
    if(stopAt(node)) {
      return _thisIfMatch(node);
    }

    return node.args
        .fold(_thisIfMatch(node), (left, right) => left.union(right.acceptVisitor(this)));
  }

  Set<E> visitUnaryOperatorNode(UnaryOperatorNode node) {
    if(stopAt(node)) {
      return _thisIfMatch(node);
    }
    return node.operand.acceptVisitor(this).union(_thisIfMatch(node));
  }

  Set<E> visitBinaryOperatorNode(BinaryOperatorNode node) {
    if(stopAt(node)) {
      return _thisIfMatch(node);
    }

    return node.leftHandOperand.acceptVisitor(this)
        .union(node.rightHandOperand.acceptVisitor(this))
        .union(_thisIfMatch(node));
  }

  Set<E> visitNameNode(VariableNode node) => _thisIfMatch(node);

  Set<E> visitValueNode(ValueNode node) => _thisIfMatch(node);

  Set<E> visitQuantorNode(QuantorOperatorNode node) {
    if(stopAt(node)) {
      return _thisIfMatch(node);
    }
    return node.range.acceptVisitor(this).union(node.scopeName.acceptVisitor(this)).union(_thisIfMatch(node));
  }

}

class PredicateFinder extends NodeFinder<PredicateNode> {

  int _arity;

  PredicateFinder({int arity}) : _arity = arity;

  bool match(LogicNode node) {
    if(node is PredicateNode) {
      if(_arity==null) {
        return true;
      }
      return (node as PredicateNode).args.length >= _arity;
    } else {
      return false;
    }
  }

  bool stopAt(LogicNode node) {
    return node is PredicateNode;
  }
}

class NameFinder extends NodeFinder<VariableNode> {

  bool match(LogicNode node) {
    return node is VariableNode;
  }

  bool stopAt(LogicNode node) {
    return node is VariableNode;
  }

  Set<VariableNode> visitQuantorNode(QuantorOperatorNode node) {
    return node.range.acceptVisitor(this).union(_thisIfMatch(node))..remove(node.scopeName);
  }
}

class PropositionFinder extends NodeFinder<LogicNode> {

  bool match(LogicNode node) {
    return node is PredicateNode || node is QuantorOperatorNode;
  }

  bool stopAt(LogicNode node) {
    return node is PredicateNode || node is QuantorOperatorNode;
  }
}

class NodeSerializer extends LogicNodeVisitor<String> {

  final Map<String, dynamic> symbolTable;

  const NodeSerializer.standard() :
  symbolTable = const {
    'comma' : ', ',
    'ergo' : ' :: ',
    'true' : 'W',
    'false' : 'F',
    'operator' : const {
      'ExistenceQuantorNode': 'E',
      'AlQuantorNode': 'A',
      'NegationOperatorNode' : '!',
      'AndOperatorNode' : ' & ',
      'OrOperatorNode' : ' v ',
      'SubjunctionOperatorNode' : ' -> '
    }
  };

  NodeSerializer(this.symbolTable);

  String visitLogicNode(LogicNode node) => "";

  String visitSequenceNode(SequenceNode node) {
    return node.nodeList.map((n) => n.acceptVisitor(this) ).join(symbolTable['comma']);
  }

  String visitArgumentNode(ArgumentNode node) {
    return "${node.premises.acceptVisitor(this)}${symbolTable['ergo']}${node.conclusion.acceptVisitor(this)}";
  }

  String visitEmptyNode(EmptyNode node) => "";

  String visitFunctionNode(FunctionNode node) {
    if(node.args.length<1) {
      return node.name.toString();
    }
    return "${node.name}(${node.args.map((n) => n.acceptVisitor(this)).join(symbolTable['comma'])})";
  }

  String visitPredicateNode(PredicateNode node) {
    return node.name + node.args.map((n) => n.acceptVisitor(this) ).join('');
  }

  String visitUnaryOperatorNode(UnaryOperatorNode node) {
    return symbolTable['operator'][node.runtimeType.toString()] + node.operand.acceptVisitor(this);
  }

  String visitBinaryOperatorNode(BinaryOperatorNode node) {
    return "(${node.leftHandOperand.acceptVisitor(this)}${symbolTable['operator'][node.runtimeType.toString()]}${node.rightHandOperand.acceptVisitor(this)})";
  }

  String visitNameNode(VariableNode node) {
    return node.value.toString();
  }

  String visitValueNode(ValueNode node) {
    return node.value ? symbolTable['true'] : symbolTable['false'];
  }

  String visitQuantorNode(QuantorOperatorNode node) {
    return "${symbolTable['operator'][node.runtimeType.toString()]}${node.scopeName}[${node.range.acceptVisitor(this)}]";
  }
}

abstract class LogicNode {

  dynamic acceptVisitor(LogicNodeVisitor visitor);

  bool eval (Map a) => true;

  String evalSteps (Map a) => "";

  String evalString(Map a) => eval(a)?"W":"F";

  bool get isEmpty => false;

  bool get isNotEmpty => !this.isEmpty;

  int get length => acceptVisitor(const NodeSerializer.standard()).length;

  int get height => acceptVisitor(const TreeHeightMeasurer());

  int get width => acceptVisitor(const TreeWidthMeasurer());

  Map toMap() => acceptVisitor(new TreeMapper());

  Map toBigMap() => acceptVisitor(new BigTreeMapper());

  String toString() => acceptVisitor(const NodeSerializer.standard());
}

abstract class QuantorOperatorNode extends LogicNode
{
  String name;

  VariableNode scopeName;

  LogicNode range;

  QuantorOperatorNode(this.scopeName, this.range);

  String evalSteps (Map a) => evalString(a);

  String evalString(Map a) {
    return (eval(a)?"W":"F") + new List.filled(length-1, " ").join("");
  }
  bool eval (Map a) => a[this];

  int get hashCode => name.hashCode + range.hashCode;

  bool operator ==(other) => name==other.id && range == other.range;

  dynamic acceptVisitor(LogicNodeVisitor visitor) {
    return visitor.visitQuantorNode(this);
  }

}



class ExistenceQuantorNode extends QuantorOperatorNode {
  final String name = "E";

  ExistenceQuantorNode(scope, range) : super(scope, range);
}

class AlQuantorNode extends QuantorOperatorNode {
  final String name = "A";

  AlQuantorNode(scope, range) : super(scope, range);
}

class SequenceNode extends LogicNode {
  List<LogicNode> nodeList;

  SequenceNode(this.nodeList);

  dynamic acceptVisitor(LogicNodeVisitor visitor) {
    return visitor.visitSequenceNode(this);
  }

  String evalSteps(a) {
    return nodeList
        .map((LogicNode n) => n.evalSteps(a))
        .join(", ");
  }

  bool eval(a) {
    return nodeList.isEmpty || nodeList
        .map((LogicNode n) => n.eval(a))
        .fold(true, (left, right) => left && right);
  }

  bool get isEmpty {
    return nodeList.isEmpty || nodeList
        .map((LogicNode n) => n.isEmpty)
        .fold(true, (left, right) => left && right);
  }

}

class ArgumentNode extends LogicNode {
  SequenceNode premises;
  LogicNode conclusion;

  ArgumentNode(this.premises, this.conclusion);

  dynamic acceptVisitor(LogicNodeVisitor visitor) {
    return visitor.visitArgumentNode(this);
  }

  bool eval (Map a) => !premises.eval(a) || conclusion.eval(a);

  String evalSteps(a) => ("${premises.evalSteps(a)} ${eval(a)?"::":".."} ${conclusion.evalSteps(a)}");

}

class EmptyNode extends LogicNode {
  dynamic acceptVisitor(LogicNodeVisitor visitor) {
    return visitor.visitEmptyNode(this);
  }

  bool get isEmpty => true;

}

abstract class OperatorNode extends LogicNode {

}

class FunctionNode extends LogicNode {
  String name;
  Iterable<LogicNode> args;

  FunctionNode(this.name, this.args);

  dynamic acceptVisitor(LogicNodeVisitor visitor) {
    return visitor.visitFunctionNode(this);
  }
}

class PredicateNode extends LogicNode {
  String name;
  Iterable<LogicNode> args;

  String get value => name;

  PredicateNode(this.name, this.args);

  dynamic acceptVisitor(LogicNodeVisitor visitor) {
    return visitor.visitPredicateNode(this);
  }

  String evalSteps (Map a) => evalString(a);

  String evalString(Map a) {
    return (eval(a)?"W":"F") + new List.filled(length-1, " ").join("");
  }
  bool eval (Map a) => a[this];

  int get hashCode => name.hashCode * args.length;

  bool operator ==(other) => name==other.name && args.length == other.args.length;
}

class UnaryOperatorNode extends OperatorNode {
  String operation;
  LogicNode operand;

  UnaryOperatorNode(this.operand);

  dynamic acceptVisitor(LogicNodeVisitor visitor) {
    return visitor.visitUnaryOperatorNode(this);
  }

  String evalSteps (Map a) => "${evalString(a)}${operand.evalSteps(a)}";

}

class NegationOperatorNode extends UnaryOperatorNode {
  String operation = '!';

  NegationOperatorNode(LogicNode operand) : super(operand);

  bool eval (Map a) => !operand.eval(a);
}

abstract class BinaryOperatorNode extends OperatorNode {
  String operation;
  LogicNode leftHandOperand;
  LogicNode rightHandOperand;

  BinaryOperatorNode(this.leftHandOperand, this.rightHandOperand);

  dynamic acceptVisitor(LogicNodeVisitor visitor) {
    return visitor.visitBinaryOperatorNode(this);
  }

  String evalSteps (Map a) => "(${leftHandOperand.evalSteps(a)} ${evalString(a)} ${rightHandOperand.evalSteps(a)})";

}

class AndOperatorNode extends BinaryOperatorNode {
  String operation = '&';

  AndOperatorNode(leftHandOperand, rightHandOperand) : super(leftHandOperand, rightHandOperand);

  bool eval (Map a) => leftHandOperand.eval(a) && rightHandOperand.eval(a);
}

class OrOperatorNode extends BinaryOperatorNode {
  String operation = 'v';

  OrOperatorNode(leftHandOperand, rightHandOperand) : super(leftHandOperand, rightHandOperand);

  bool eval (Map a) => leftHandOperand.eval(a) || rightHandOperand.eval(a);
}

class SubjunctionOperatorNode extends BinaryOperatorNode {
  String operation = '->';

  SubjunctionOperatorNode(leftHandOperand, rightHandOperand) : super(leftHandOperand, rightHandOperand);

  bool eval (Map a) => !leftHandOperand.eval(a) || rightHandOperand.eval(a);

  String evalString(Map a) => "${eval(a)?"W":"F"} ";
}

class VariableNode extends LogicNode {
  final String value;

  VariableNode(this.value);

  dynamic acceptVisitor(LogicNodeVisitor visitor) {
    return visitor.visitNameNode(this);
  }

  String evalSteps (Map a) => evalString(a);

  int get hashCode => value.hashCode;

  bool operator ==(other) => value==other.value;

  bool eval (Map a) => a[this];

}

class ValueNode extends LogicNode {
  bool value;

  ValueNode(this.value);

  dynamic acceptVisitor(LogicNodeVisitor visitor) {
    return visitor.visitValueNode(this);
  }

  String evalSteps (Map a) => evalString(a);

  String evalString(Map a) => eval(a)?"W":"F";

  int get hashCode => value.hashCode;

  bool operator ==(other) => value==other.value;

  bool eval (Map a) => value;
}

class ClassicLogicParserContext extends ParserContext<LogicNode> {
  final Stack<Token> ergoStack = new Stack<Token>();
  final Stack<Token> commaStack = new Stack<Token>();
  final List<LogicNode> sequenceList = new List<LogicNode>();

  ClassicLogicParserContext() : super();
}

class ClassicLogicParserDelegate extends ParserDelegate<LogicNode> {

  ClassicLogicParserDelegate();

  bool isOpeningToken(Token token) {
    return token.name == TOKEN_CUSTOM_NAME_BRACKET_LEFT || super.isOpeningToken(token);
  }

  bool isClosingToken(Token token) {
    return token.name == TOKEN_CUSTOM_NAME_BRACKET_RIGHT || super.isClosingToken(token);
  }

  bool isMatchingPair(Token left, Token right) {
    return (left.name == TOKEN_CUSTOM_NAME_BRACKET_LEFT) && (right.name==TOKEN_CUSTOM_NAME_BRACKET_RIGHT) ||
        super.isMatchingPair(left, right);
  }

  Map<String, dynamic> _literals = {
    'W' : () => new ValueNode(true) ,
    'F' : () => new ValueNode(false)
  };

  Map<String, dynamic> _binaryOperators = {
   '&': (l,r)=> new AndOperatorNode(l, r),
   'v': (l,r)=> new OrOperatorNode(l, r),
   '->': (l,r)=> new SubjunctionOperatorNode(l, r)
  };

  Map<String, dynamic> _unaryOperators = {
   '!': (o)=> new NegationOperatorNode(o)
  };

  Map<String, dynamic> _scopeOperators = {
    'E': (scoped,range)=> new ExistenceQuantorNode(scoped, range),
    'A': (scoped,range)=> new AlQuantorNode(scoped, range)
  };

  LogicNode variableTokenToNode(Token token) {
    return new VariableNode(token.value);
  }

  LogicNode _literalTokenToNode(Token token) {
    if(_literals.containsKey(token.value)) {
      return _literals[token.value]();
    }

    throw new UnexpectedTokenException(token);
  }

  LogicNode emptyNode() {
    return new EmptyNode();
  }

  LogicNode unaryOperatorToNode(Token operator, LogicNode operand) {
    return _unaryOperators[operator.value](operand);
  }

  LogicNode binaryOperatorToNode(Token operator, LogicNode leftHand, LogicNode rightHand) {
    return _binaryOperators[operator.value](leftHand, rightHand);
  }

  LogicNode scopeOperatorToNode(Token operator, LogicNode scoped, LogicNode range) {
    return _scopeOperators[operator.value](scoped, range);
  }

  LogicNode predicateTokenToNode(Token pred, Iterable<LogicNode> args) {
    return new PredicateNode(pred.value, args);
  }

  LogicNode functionTokenToNode(Token token, Iterable<LogicNode> args) {
    return new FunctionNode(token.value, args);
  }

  LogicNode _sequenceToNode(List<LogicNode> nodes) {
    return new SequenceNode(nodes);
  }

  LogicNode _ergoTokenToNode(LogicNode nodes, LogicNode node) {
    return new ArgumentNode(nodes, node);
  }

  bool hasBinaryOperator(Token operator) {
    return _binaryOperators.containsKey(operator.value);
  }

  bool hasUnaryOperator(Token operator) {
    return _unaryOperators.containsKey(operator.value);
  }

  bool hasScopeOperator(Token operator) {
    return _scopeOperators.containsKey(operator.value);
  }

  Associativity assocOfOperator(Token token) {
    switch(token.value) {
      // case '' : return Associativity.RIGHT;
    };

    return Associativity.LEFT;
  }

  int precedenceOfOperator(Token token) {
    if(_scopeOperators.containsKey(token.value)) {
      return 1000;
    }

    if(_unaryOperators.containsKey(token.value)) {
      return 1000;
    }

    return 100;
  }

  ClassicLogicParserContext newContext() {
    return new ClassicLogicParserContext();
  }

  void unknownToken(Token token, ClassicLogicParserContext context, finalize) {
    switch(token.name) {

      case TOKEN_CUSTOM_NAME_PREMISE_SEPARATOR:
        if(context.ergoStack.isNotEmpty) {
          throw new UnexpectedTokenException.explained(token, "Commas must not be on the right side of the ergo token '${context.ergoStack.top.value}'.");
        }
        if(context.output.isEmpty && context.stack.isEmpty) {
          throw new UnexpectedTokenException.explained(token, "Premise expected.");
        }
        context.commaStack.push(token);
        context.sequenceList.add(finalize(context));
        context.lastTokenAtom = false;
        break;

      case TOKEN_CUSTOM_NAME_ERGO:
        if(context.ergoStack.isNotEmpty) {
          throw new UnexpectedTokenException(token);
        }
        if(context.output.isEmpty && context.stack.isEmpty && context.commaStack.isNotEmpty) {
          throw new UnexpectedTokenException.explained(token, "Premise expected.");
        } else {
          context.sequenceList.add(finalize(context));
        }

        context.ergoStack.push(token);
        context.lastTokenAtom = false;
        break;


      case TOKEN_CUSTOM_NAME_LITERAL:
        if(context.lastTokenAtom) {
          throw new UnexpectedTokenException(token);
        }
        context.output.push(_literalTokenToNode(token));
        context.lastTokenAtom = true;
        break;

      default:
        super.unknownToken(token, context, finalize);
    }
  }

  LogicNode finish(finalize, context) {
    if(context.ergoStack.isEmpty) {
      if(context.output.isEmpty && context.stack.isEmpty && context.commaStack.isNotEmpty) {
        throw new UnexpectedTokenException.explained(context.commaStack.top, "Premise expected.");
      }
      return this._sequenceToNode(context.sequenceList..add(finalize(context)));
    } else {
      if(context.output.isEmpty && context.stack.isEmpty) {
        throw new UnexpectedTokenException.explained(context.ergoStack.top, "Ergo must be followed by an expression.");
      }
      return this._ergoTokenToNode(this._sequenceToNode(context.sequenceList), finalize(context));
    }
  }

}


class AssignmentGenerator {

  const AssignmentGenerator();

  Set<Map<LogicNode, bool>> generate(HashSet<LogicNode> chars) {
    var set = new HashSet<HashMap<LogicNode, bool>>();

    if(chars.length > -1) {
      for (var i = 0, j=math.pow(2, chars.length); i < j; i++) {
        var col = 1;
        var assignment = new HashMap<LogicNode, bool>();
        for(var char in chars) {
          col*=2;
          assignment[char] = (i%(2*(j~/col))<(j~/col));
        }
        set.add(assignment);
      }
    }

    return set;
  }

}

String generateTable(tree, chars) {
  StringBuffer asciTable = new StringBuffer();
  var assignmentGen = const AssignmentGenerator();
  var charList = chars.toList();

  var assignments = assignmentGen.generate(chars).toList()..sort((a,b){
    for(var char in charList) {
      if(a[char] && !b[char]) {
        return -1;
      } else if(!a[char] && b[char]) {
        return 1;
      }
    }
    return 0;
  });

  for(var char in charList) {
    asciTable.write("| ${char} ");
  }
  asciTable.writeln("|| ${tree.toString()} |");

  for(var char in charList) {
    asciTable.write("|${new List.filled(char.length+2, "=").join("")}");
  }
  asciTable.writeln("||${new List.filled(tree.length+2, "=").join("")}|");

  for (var a in assignments) {
    var col = 1;
    for(var char in charList) {
      asciTable.write("| ${char.evalSteps(a)} ");
    }
    asciTable.writeln("|| ${tree.evalSteps(a)} |");
  }

  return asciTable.toString();
}