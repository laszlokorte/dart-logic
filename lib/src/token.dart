part of shunting_dart;

/**
 * A part of text accepted by a lexer.
 */
class Token {
  final String name;
  final String value;
  final SourcePosition position;

  Token(this.name, this.value, this.position);

  String toString() {
    return "Token(${this.name}, ${this.value}, Pos:${this.position.index})";
  }

  bool operator ==(Object other) {
    if(other is! Token) {
      return false;
    }

    return this.name==(other as Token).name && this.value==(other as Token).value;
  }

  int get hashCode => this.name.hashCode + this.value.hashCode;
}