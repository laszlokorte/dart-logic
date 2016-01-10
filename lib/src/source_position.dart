part of shunting_dart;

/**
 * The position of a character in a String.
 */
class SourcePosition {
  final int index;
  final int lineNumber;
  final int columnNumber;

  SourcePosition(this.index, this.lineNumber, this.columnNumber);

  String toString() => "Position($index,line:$lineNumber,column:$columnNumber)";
}