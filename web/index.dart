library classy_logic;
import 'dart:html';
import 'dart:collection';
import 'package:js/js.dart' as js;

import 'classic_logic.dart';


List<List<String>> unicodeMapping = [
["¬", "!"],
["→", "->"],
["∨", "v"],
["⊥", "F"],
["⊤", "W"],
["∴", "::"],
["∀", "A"],
["∃", "E"],
];

String fromUnicode(String input) {
  return unicodeMapping.fold(input,
      (string, replace) => string.replaceAll(replace[0], replace[1]));
}

String toUnicode(String input) {
  return unicodeMapping.fold(input,
      (string, replace) => string.replaceAll(replace[1], replace[0]));
}

eventToElement(Event e) => (e.target as Element);
mapUnicode(TextAreaElement input) => input.value = fromUnicode(input.value);
ele(Event e) => (e.target as Element);
selector(sel) => (Event e) => ele(e).matches(sel);

void main() {
  querySelector(".dart-only").style.display = "block";

  Lexer lexer = logicLexer();
  Parser parser = logicParser();

  BodyElement body = querySelector('body');
  InputElement forceParentheses = querySelector('#force_parentheses');
  TextAreaElement inputField = querySelector("#formel_input");
  Element resultTarget = querySelector('#formel_result');
  Element unicodeTarget = querySelector('#formel_result_unicode');
  Element errorTarget = querySelector('#formel_error');
  Element errorOverlay = querySelector('#error_overlay');
  Element terminalTarget = querySelector('#formel_terminals');
  Element predicatTarget = querySelector('#formel_predicates');
  Element nameTarget = querySelector('#formel_names');
  Element boolTableTarget = querySelector('#boolean_table');
  Element resultContainer = querySelector('#result-container');
  Element performanceWarning = querySelector('#performance-warning');

  String currentInput;
  LogicNode currentTree;

  errorMarker(int start, int length, {String type: 'error'}) {
    errorOverlay.innerHtml = currentInput.substring(0, start)
        + '<span class="overlay-text-marker text-marker-$type">'+
        currentInput.substring(start, start+length)
        +'</span>'
        + currentInput.substring(start+length);
  }

  invalidateMarker() {
    errorOverlay.text = '';
  }

  var currentErrorType;
  errorHandler({type: 'error'}) {
    boolTableTarget.text = '';
    resultTarget.text = '';
    terminalTarget.text = '';
    predicatTarget.text = '';
    nameTarget.text = '';
    unicodeTarget.text = '';
    if(currentErrorType != null) {
      errorTarget.classes.remove(currentErrorType);
    }
    errorTarget.classes.remove("state-hidden");
    errorTarget.classes.add(currentErrorType = "alert-$type");
    resultContainer.classes.add('state-hidden');
  };

  readInput() {
    return inputField.value;
    //return inputField.nodes.map((e) => e.text + (e is DivElement  ?"\n" :'')).join("");
  }

  parseInput ({bool force: false}) {
    var newInput = readInput();
    if(currentInput == newInput && !force) {
      return;
    }
    currentInput = newInput;
    var iterator = lexer.lex(currentInput.split(''));
    try {
      var result = iterator.toList().map((t) => t.toString()).join('');
      LogicNode tree = parser.parse(iterator, forceParentheses: forceParentheses.checked);

      HashSet chars = tree.acceptVisitor(new PropositionFinder());

      currentTree=tree;
      if(tree.isNotEmpty) {
        if(chars.length > 6) {
          boolTableTarget.classes.add('state-hidden');
          performanceWarning.classes.remove('state-hidden');
        } else {
          performanceWarning.classes.add('state-hidden');
          boolTableTarget.classes.remove('state-hidden');
          boolTableTarget.text = generateTable(tree, chars);
        }
        resultContainer.classes.remove('state-hidden');
      } else {
        boolTableTarget.text = "";
        resultContainer.classes.add('state-hidden');
      }

      invalidateMarker();
      terminalTarget.innerHtml = chars.join(', ');
      predicatTarget.innerHtml = tree.acceptVisitor(new PredicateFinder(arity:1))
          .map((p) => "${p.id}<sup>${p.args.length}</sup>")
          .join(', ');
      nameTarget.innerHtml = tree.acceptVisitor(new NameFinder()).join(', ');
      resultTarget.text = tree.toString();
      unicodeTarget.text = toUnicode(tree.toString());
      errorTarget.text = '';
      drawTree(tree.toBigMap(), tree.height*2-1, tree.width);
      errorTarget.classes.add("state-hidden");
    } on LexingException catch(e) {
      errorHandler();
      errorMarker(e.sourcePosition.index-1, 1);
      errorTarget.text = "Unerwartetes Zeichen '${e.char}' in Zeile ${e.sourcePosition.lineNumber}, Spalte: ${e.sourcePosition.columnNumber}";
    } on RedundancyParsingException catch(e) {
      errorHandler(type: "warning");
      errorMarker(e.token.position.index-1, e.token.value.length, type: 'warning');

      errorTarget.innerHtml = """
          <p>Die Klammerung ist redundant in Zeile ${e.token.position.lineNumber}, Spalte: ${e.token.position.columnNumber}
          </p><p>Die strenge Klammerung ist optional und kann <span class="action action-toggle-strict">hier abgeschaltet werden</span>.</p>
          """;
    } on AmbiguousParsingException catch(e) {
      errorHandler(type: "warning");
      errorMarker(e.token.position.index-1, e.token.value.length, type: 'warning');

      errorTarget.innerHtml = """
          <p>Die Klammerung ist nicht eindeutig genug für den Operator ${e.token.value} in Zeile ${e.token.position.lineNumber}, Spalte: ${e.token.position.columnNumber}
          </p><p>Die strenge Klammerung ist optional und kann <span class="action action-toggle-strict">hier abgeschaltet werden</span>.</p>
          """;

  //} on StrictParsingException catch(e) {

    } on MismatchedTokenException catch(e) {
      errorMarker(e.token.position.index-1, e.token.value.length);
      errorHandler();

      if(e.open) {
        errorTarget.innerHtml = "<p>Klammer wurde geöffnet, aber nicht wieder geschlossen, in Zeile ${e.token.position.lineNumber}, Spalte: ${e.token.position.columnNumber}</p>";
      } else {
        errorTarget.innerHtml = "<p>Unerwartete schließende Klammer in Zeile ${e.token.position.lineNumber}, Spalte: ${e.token.position.columnNumber}</p>";
      }
    } on MissingOperandException catch(e) {
      errorMarker(e.token.position.index-1, e.token.value.length);
      errorHandler();

      errorTarget.innerHtml = "<p>Es ${e.missing==1?"fehlt ein Operand" : "fehlen zwei Operanden"} für den ${e.arity==1?'einstelligen' : 'zweistelligen'} Operator '${e.token.value}' in Zeile ${e.token.position.lineNumber}, Spalte: ${e.token.position.columnNumber}</p>";
    } on UnexpectedTokenException catch(e, t) {
      errorMarker(e.token.position.index-1, e.token.value.length);
      errorHandler();
      errorTarget.innerHtml =
          "<p>Unerwartetes Token '${e.token.value}' (${e.token.name}) in Zeile ${e.token.position.lineNumber}, Spalte: ${e.token.position.columnNumber}</p>"
          + (e.detail!=null ? "<p>${e.detail}</p>" : "") + "<pre>$t</pre>";
    } on ParsingException catch(e, stackTrace) {
      errorMarker(e.token.position.index-1, e.token.value.length);
      errorHandler();
      errorTarget.text = "${e.msg} in Zeile ${e.token.position.lineNumber}, Spalte: ${e.token.position.columnNumber}";
    } on Exception catch(e, stackTrace) {
      errorHandler();
      errorTarget.text = "Ein unerwarter Fehler ist aufgetreten. Da scheint etwas noch nicht so zu funktionieren, wie es soll.";
    }

  };

  inputField
  ..onPaste.map(eventToElement).listen(mapUnicode)
  ..onKeyDown.map(eventToElement).listen(mapUnicode)
  ..onKeyUp.map(eventToElement).listen(mapUnicode)
  //..onKeyDown.listen((_) => invalidateMarker())
  //..onInput.where(selector('div')).listen((Event e)=> parseInput(force: false))
  ..onKeyUp.listen((Event e) { parseInput(force: false); window.location.hash=inputField.value;})
  ..onInput.listen((Event e)=> invalidateMarker())
  ;

  forceParentheses
  ..onChange.listen((Event e) => parseInput(force:true));


  body
  .onClick
  ..where(selector('.action-toggle-strict')).listen((_){
    forceParentheses.checked = !forceParentheses.checked;
    parseInput(force: true);
  })
  ..where(selector('.action-generate-table')).listen((_){
    if(currentTree.isNotEmpty) {
      boolTableTarget.text = generateTable(currentTree, currentTree.acceptVisitor(new PropositionFinder()));
      boolTableTarget.classes.remove('state-hidden');
      performanceWarning.classes.add('state-hidden');
    }
  })
  ..where(selector('button[data-toggle]')).listen((Event e){
    var ele = querySelector((e.target as Element).dataset['toggle']);
    ele.classes.toggle("state-hidden");
  })

  ;

  scrollFix (Event e) {
    errorOverlay.style.top = "${-inputField.scrollTop}px";
  }

  inputField
  .onScroll
  ..listen(scrollFix);
  scrollFix(null);

  if(window.location.hash.length > 1) {
    inputField.value = Uri.decodeComponent(window.location.hash.substring(1));
     parseInput(force:true);
  }
  inputField.disabled = false;
  inputField.placeholder = "Gib eine Formel ein! z.B. (P & Q) v R";
  inputField.focus();


}

drawTree(Map treeMap, int height, int width) {
  js.scoped(() {
    var treeData = js.map(treeMap);
    var res = 800;

    var fix = height/(height+1);
    var lineHeight = 15;
    var colWidth = 15;
    var ratio = fix*fix*lineHeight/colWidth;
    var d3 = js.context['d3'];
    var vis = d3.select("#tree svg")
        .attr("viewBox", "0 0 $res ${ratio*height/width*res}")
        .attr("style", "height:${100*ratio*height/width}%")
        .select(".root")
        .attr("transform", "translate(40, 40)"); // shift everything to the right

    // Create a tree "canvas"
    var tree = d3.layout.tree()
        .size(js.array([res-100,ratio*res*height/width-100]));

    var diagonal = d3.svg.diagonal()
        // change x and y (for the left to right tree)
        .projection(new js.Callback.many( (d, i, context) => js.array([d['x'],d['y']])));

    bool hasChildren (d) {
      return (d.hasOwnProperty('children') && d['children'].length>0);
    };

    var textAnchor = new js.Callback.many( (d, i, context) {
      return hasChildren(d) ? (!d['right'] ? "end" : "start") : 'middle';
    });

    var textDX = new js.Callback.many( (d, i, context) {
      return hasChildren(d) ? (d['right'] ? 10 : -10) : 0;
    });

    var textDY = new js.Callback.many( (d, i, context) {
      return hasChildren(d) ? 0 : 25;
    });

    // Preparing the data for the tree layout, convert data into an array of nodes
    var nodes = tree.nodes(treeData);
    // Create an array with all the links
    var links = tree.links(nodes);


    var link = vis.selectAll("path.tree-link")
        .data(links);

        link.attr("d", diagonal);
        link.enter().insert("svg:path", '.node')
        .attr("class", "tree-link")
        .attr("d", diagonal);

        link.exit().remove();

    var node = vis.selectAll(".node")
        .data(nodes);

        node.attr("transform", new js.Callback.many( (d, i, context) => "translate(${d['x']},${d['y']})"))
        ..select("circle")
            .attr("class","node-circle")
            .attr("r", 6)
        ..select('text')
          .attr("y", textDY)
          .attr("x", textDX)
          .attr("text-anchor", textAnchor)
          .text(new js.Callback.many((d, i, context) => toUnicode(d['name'])));

        node.enter().append("g")
        .attr("class","node")
        .attr("transform", new js.Callback.many( (d, i, context) => "translate(${d['x']}, ${d['y']})"))
          ..append("circle")
            .attr("class","node-circle")
            .attr("r", 6)
          ..append("text")
            .attr("class", "node-label")
            .attr("y", textDY)
            .attr("x", textDX)
            .attr("text-anchor", textAnchor)
            .text(new js.Callback.many((d, i, context) => toUnicode(d['name'])));

        node.exit().remove();



  });
}

