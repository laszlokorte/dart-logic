part of shunting_dart;

/**
 * A generator for configuring the rules for a Lexer.
 */
class LexerGenerator {

  List<Rule> _rules = new List<Rule>();

  List<Rule> _ignores = new List<Rule>();

  /**
   * Add a new token pattern to this configuration.
   *
   * The name is meant for the parser to recognize a token.
   * The pattern is a part of a regular expression describing the expected input.
   *
   *     lexerGen.add('number', '-?[0-9]+')
   */
  add(String name, String pattern) {
    _rules.add(new Rule(name, pattern));
  }

  /**
   * Configure a pattern to be ignored.
   *
   * The pattern is a part of a regular expression describing ignored input.
   *
   *     lexerGen.ignore('\s+')
   */
  ignore(String pattern) {
    _ignores.add(new Rule('ignore', pattern));
  }

  Lexer get lexer => new Lexer(_rules, _ignores);

}

/**
 * A Iterator based lexer.
 */
class Lexer {

  final Iterable<Rule> rules;

  final Iterable<Rule> ignoreRules;

  Lexer(this.rules, this.ignoreRules);

  Tokens lex(Iterable<String> input) {
    return new Tokens(this, input);
  }

}

/**
 * A list of tokens being the output of the lexer.
 */
class Tokens extends Object with IterableMixin<Token> {
  Iterable<String> input;
  Lexer lexer;

  Tokens(this.lexer, this.input);

  Iterator<Token> get iterator => new TokenIterator(this.lexer, this.input.iterator);
}


/**
 *
 */
class TokenIterator implements Iterator<Token> {

  final Lexer lexer;
  final Iterator<String> input;

  int _index = 1;
  int _line = 1;
  int _column = 1;

  String _accFirst;
  StringBuffer _accumulator;
  Queue<String> _inputQueue;

  Token _current;

  TokenIterator(this.lexer, this.input) {
    this._accumulator = new StringBuffer();
    this._inputQueue = new Queue<String>();
  }

  bool moveNext() {
    Rule currentRule;
    int currentColumn = _column;
    int currentLine = _line;

    while(true) {
      if(_inputQueue.isEmpty) {
        if(input.moveNext()) {
          _inputQueue.add(input.current);
        } else {
          break;
        }
      } else if(currentRule != null) {
        if(currentRule.matches(this._accumulator.toString() + this._inputQueue.last)) {
          _consume();
          continue;
        } else {
          break;
        }
      } else {
        _consume();
        for(Rule rule in this.lexer.ignoreRules) {
          if(rule.matches(this._accumulator.toString())) {
            currentColumn = _column;
            currentLine = _line;
            this._index += this._accumulator.length;
            this._accumulator.clear();
            break;
          }
        }

        for(Rule rule in this.lexer.rules) {
          if(rule.matches(this._accumulator.toString())) {
            currentRule = rule;
            break;
          }
        }
      }

    }

    if(currentRule!=null) {
      var sourcePos = new SourcePosition(_index, currentLine, currentColumn);
      this._current = new Token(currentRule.name, this._accumulator.toString(), sourcePos);
      this._index += this._accumulator.length;
      this._accumulator.clear();
      currentRule = null;

      return true;
    }

    if(_accumulator.isNotEmpty) {
      throw new LexingException(_accFirst, new SourcePosition(_index, currentLine, currentColumn));
    }

    return false;
  }

  void _consume() {
    if(this._accumulator.isEmpty) {
      _accFirst = this._inputQueue.last;
    }

    if(this._inputQueue.last=="\n") {
      _column = 1;
      _line++;
    } else {
      _column++;
    }

    this._accumulator.write(this._inputQueue.removeLast());
  }

  Token get current => _current;
}


class Rule {

  final String name;

  final RegExp _pattern;

  Rule(this.name, String pattern) : this._pattern = new RegExp("^($pattern)\$");

  bool matches(String input) {
    return _pattern.hasMatch(input);
  }

}

class LexingException implements Exception {
  final SourcePosition sourcePosition;
  final String char;

  LexingException(this.char, this.sourcePosition);
}