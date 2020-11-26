{

  function loc(env, token) {
    return `(${env.getFile()},L:${token.location.start.line},C:${token.location.start.column})`;
  }

  class Fluorite8CompileError extends Error {
    constructor(message, env, token) {
      super(message + " " + loc(env, token));
      this.name = "Fluorite8CompileError";
      this.file = env.getFile();
      this.token = token;
    }
  }

  class Environment {

    constructor() {
      this._nextUid = 0;
      this._aliasFrame = Object.create(null);
      this._operatorRegistry = Object.create(null);
      this._compilerRegistry = Object.create(null);
      this._file = "anonymous";
      this._suggestedName = undefined;
    }

    getNextUid() {
      return this._nextUid++;
    }

    registerAlias(alias, handlerTable) {
      this._aliasFrame[alias] = handlerTable;
    }
    resolveAlias(alias) {
      return this._aliasFrame[alias];
    }
    pushAliasFrame() {
      this._aliasFrame = Object.create(this._aliasFrame);
    }
    popAliasFrame() {
      this._aliasFrame = Object.getPrototypeOf(this._aliasFrame);
    }

    registerOperatorHandler(domain, type, handler) {
      if (this._operatorRegistry[domain] === undefined) this._operatorRegistry[domain] = Object.create(null);
      this._operatorRegistry[domain][type] = handler;
    }
    registerCompilerHandler(domain, handler) {
      this._compilerRegistry[domain] = handler;
    }
    tryCompile(domain, token, options) {
      const handlerTable = this._operatorRegistry[domain];
      if (handlerTable === undefined) return null;
      const handler = handlerTable[token.type];
      if (handler === undefined) return null;

      const suggestedName = this._suggestedName;
      this._suggestedName = options.suggestedName;
      const operation = handler(this, token);
      this._suggestedName = suggestedName;

      return operation;
    }
    compile(domain, token, options = {}) {
      const handler = this._compilerRegistry[domain];
      if (handler === undefined) throw new Fluorite8CompileError("Unknown compiler: " + domain, this, token); 
      return handler(this, token, options);
    }

    setFile(file) {
      this._file = file;
    }
    getFile() {
      return this._file;
    }

    getSuggestedName() {
      if (this._suggestedName === undefined) return "anonymous";
      return this._suggestedName;
    }

  }

  const library = {
    arrayAccess(array, index, location) {
      if (!(array instanceof Array)) throw new Error("" + array + " is not an Array " + location);
      if (typeof index !== "number") throw new Error("" + index + " is not a number " + location);
      return array[index];
    },
    checkNumber(value, location) {
      if (typeof value !== "number") throw new Error("" + value + " is not a number " + location);
    },
    add(a, b, location) {
      if (typeof a !== "number") throw new Error("" + a + " is not a number " + location);
      if (typeof b !== "number") throw new Error("" + b + " is not a number " + location);
      return a + b;
    },
    sub(a, b, location) {
      if (typeof a !== "number") throw new Error("" + a + " is not a number " + location);
      if (typeof b !== "number") throw new Error("" + b + " is not a number " + location);
      return a - b;
    },
    mul(a, b, location) {
      if (typeof a !== "number") throw new Error("" + a + " is not a number " + location);
      if (typeof b !== "number") throw new Error("" + b + " is not a number " + location);
      return a * b;
    },
    div(a, b, location) {
      if (typeof a !== "number") throw new Error("" + a + " is not a number " + location);
      if (typeof b !== "number") throw new Error("" + b + " is not a number " + location);
      return a / b;
    },
    pow(a, b, location) {
      if (typeof a !== "number") throw new Error("" + a + " is not a number " + location);
      if (typeof b !== "number") throw new Error("" + b + " is not a number " + location);
      return Math.pow(a, b);
    },
    toPositive(number, location) {
      if (typeof number !== "number") throw new Error("" + number + " is not a number " + location);
      return number;
    },
    toNegative(number, location) {
      if (typeof number !== "number") throw new Error("" + number + " is not a number " + location);
      return -number;
    },
    getLength(array, location) {
      if (!(array instanceof Array)) throw new Error("" + array + " is not an Array " + location);
      return array.length;
    },
    call(func, arg, location) {
      if (!(func instanceof Function)) throw new Error("" + func + " is not a Function " + location);
      return func(arg);
    },
  };

  function customizeEnvironment(env) {

    function indent(code) {
      return "  " + code.replace(/\n(?!$)/g, "\n  ");
    }
    function toOperation(head/* string */, body/* string */) {
      return {head, body};
    }
    function toOperationSet(accept/* operationGet => operationRun */, suggestedName = undefined/* string */) {
      return {accept, suggestedName};
    }
    function toOperationArray(generate/* operationSet => operationRun */) {
      return {generate};
    }
    function toOperationRun(head/* string */) {
      return {head};
    }
    function registerDefaultCompilerHandler(domain) {
      env.registerCompilerHandler(domain, (env, token, options) => {
        let operation;
        operation = env.tryCompile(domain, token, options);
        if (operation !== null) return operation;
        throw new Fluorite8CompileError("Unknown operator: " + domain + "/" + token.type, env, token);
      });
    }

    env.registerCompilerHandler("root", (env, token, options) => {
      let operation;
      operation = env.tryCompile("get", token, options);
      if (operation !== null) {
        const label = `<root>${loc(env, token)}`;
        const uidSymbol = env.getNextUid();
        const uid = env.getNextUid();
        return (
          "const v_" + uidSymbol + " = Symbol(" + JSON.stringify(label) + ");\n" +
          "const v_" + uid + " = " + "{[v_" + uidSymbol + "]: function(library) {\n" +
          indent(
            operation.head +
            "return " + operation.body + ";\n"
          ) +
          "}}[v_" + uidSymbol + "];\n" +
          "(v_" + uid + ")"
        );
      }
      throw new Fluorite8CompileError("Unknown operator: root/" + token.type, env, token);
    });
    registerDefaultCompilerHandler("get");
    registerDefaultCompilerHandler("set");
    registerDefaultCompilerHandler("run");
    env.registerCompilerHandler("array", (env, token, options) => {
      let operation;
      operation = env.tryCompile("array", token, options);
      if (operation !== null) return operation;
      operation = env.tryCompile("get", token, options);
      if (operation !== null) return toOperationArray(oSet => oSet.accept(operation));
      throw new Fluorite8CompileError("Unknown operator: array/" + token.type, env, token);
    });

    env.registerOperatorHandler("get", "integer", (env, token) => toOperation("", "(" + parseInt(token.argument, 10) + ")"));
    env.registerOperatorHandler("get", "string", (env, token) => toOperation("", "(" + JSON.stringify(token.argument) + ")"));
    env.registerOperatorHandler("get", "identifier", (env, token) => {
      const handlerTable = env.resolveAlias(token.argument);
      if (handlerTable === undefined) throw new Fluorite8CompileError("Unknown identifier: " + token.argument, env, token);
      const handler = handlerTable["get"];
      if (handler === undefined) throw new Fluorite8CompileError("Unreadable identifier: " + token.argument, env, token);
      return handler(env);
    });
    env.registerOperatorHandler("get", "round", (env, token) => {
      env.pushAliasFrame();
      const o1 = env.compile("get", token.argument[0], {
        suggestedName: env.getSuggestedName(),
      });
      env.popAliasFrame();
      return o1;
    });
    env.registerOperatorHandler("get", "square", (env, token) => {
      const o1 = env.compile("array", token.argument[0]);
      const uid = env.getNextUid();
      const o2 = o1.generate(toOperationSet(o => toOperationRun(
        o.head +
        "v_" + uid + "[v_" + uid + ".length] = " + o.body + ";\n"
      )));
      return toOperation(
        "const v_" + uid + " = [];\n" +
        o2.head,
        "(v_" + uid + ")"
      );
    });
    env.registerOperatorHandler("get", "empty_square", (env, token) => {
      const uid = env.getNextUid();
      return toOperation(
        "const v_" + uid + " = [];\n",
        "(v_" + uid + ")"
      );
    });
    env.registerOperatorHandler("get", "left_plus", (env, token) => {
      const o1 = env.compile("get", token.argument[0]);
      const uid = env.getNextUid();
      return toOperation(
        o1.head + "const v_" + uid + " = library.toPositive(" + o1.body + ", " + JSON.stringify(loc(env, token)) + ");\n",
        "(v_" + uid + ")"
      );
    });
    env.registerOperatorHandler("get", "left_minus", (env, token) => {
      const o1 = env.compile("get", token.argument[0]);
      const uid = env.getNextUid();
      return toOperation(
        o1.head + "const v_" + uid + " = library.toNegative(" + o1.body + ", " + JSON.stringify(loc(env, token)) + ");\n",
        "(v_" + uid + ")"
      );
    });
    env.registerOperatorHandler("get", "left_dollar_hash", (env, token) => {
      const o1 = env.compile("get", token.argument[0]);
      const uid = env.getNextUid();
      return toOperation(
        o1.head + "const v_" + uid + " = library.getLength(" + o1.body + ", " + JSON.stringify(loc(env, token)) + ");\n",
        "(v_" + uid + ")"
      );
    });
    env.registerOperatorHandler("get", "right_round", (env, token) => {
      const o1 = env.compile("get", token.argument[0]);
      env.pushAliasFrame();
      const o2 = env.compile("get", token.argument[1]);
      env.popAliasFrame();
      const uid = env.getNextUid();
      return toOperation(
        o1.head + o2.head + "const v_" + uid + " = library.call(" + o1.body + ", " + o2.body + ", " + JSON.stringify(loc(env, token)) + ");\n",
        "(v_" + uid + ")"
      );
    });
    env.registerOperatorHandler("get", "right_square", (env, token) => {
      const o1 = env.compile("get", token.argument[0]);
      env.pushAliasFrame();
      const o2 = env.compile("get", token.argument[1]);
      env.popAliasFrame();
      const uid = env.getNextUid();
      return toOperation(
        o1.head +
        o2.head +
        "const v_" + uid + " = library.arrayAccess(" + o1.body + ", " + o2.body + ", " + JSON.stringify(loc(env, token)) + ");\n",
        "(v_" + uid + ")"
      );
    });
    env.registerOperatorHandler("get", "plus", (env, token) => {
      const o1 = env.compile("get", token.argument[0]);
      const o2 = env.compile("get", token.argument[1]);
      const uid = env.getNextUid();
      return toOperation(
        o1.head + o2.head + "const v_" + uid + " = library.add(" + o1.body + ", " + o2.body + ", " + JSON.stringify(loc(env, token)) + ");\n",
        "(v_" + uid + ")"
      );
    });
    env.registerOperatorHandler("get", "minus", (env, token) => {
      const o1 = env.compile("get", token.argument[0]);
      const o2 = env.compile("get", token.argument[1]);
      const uid = env.getNextUid();
      return toOperation(
        o1.head + o2.head + "const v_" + uid + " = library.sub(" + o1.body + ", " + o2.body + ", " + JSON.stringify(loc(env, token)) + ");\n",
        "(v_" + uid + ")"
      );
    });
    env.registerOperatorHandler("get", "asterisk", (env, token) => {
      const o1 = env.compile("get", token.argument[0]);
      const o2 = env.compile("get", token.argument[1]);
      const uid = env.getNextUid();
      return toOperation(
        o1.head + o2.head + "const v_" + uid + " = library.mul(" + o1.body + ", " + o2.body + ", " + JSON.stringify(loc(env, token)) + ");\n",
        "(v_" + uid + ")"
      );
    });
    env.registerOperatorHandler("get", "slash", (env, token) => {
      const o1 = env.compile("get", token.argument[0]);
      const o2 = env.compile("get", token.argument[1]);
      const uid = env.getNextUid();
      return toOperation(
        o1.head + o2.head + "const v_" + uid + " = library.div(" + o1.body + ", " + o2.body + ", " + JSON.stringify(loc(env, token)) + ");\n",
        "(v_" + uid + ")"
      );
    });
    env.registerOperatorHandler("get", "circumflex", (env, token) => {
      const o1 = env.compile("get", token.argument[0]);
      const o2 = env.compile("get", token.argument[1]);
      const uid = env.getNextUid();
      return toOperation(
        o1.head + o2.head + "const v_" + uid + " = library.pow(" + o1.body + ", " + o2.body + ", " + JSON.stringify(loc(env, token)) + ");\n",
        "(v_" + uid + ")"
      );
    });
    env.registerOperatorHandler("get", "ternary_question_colon", (env, token) => {
      const o1 = env.compile("get", token.argument[0]);
      const o2 = env.compile("get", token.argument[1]);
      const o3 = env.compile("get", token.argument[2]);
      const uid = env.getNextUid();
      return toOperation(
        o1.head +
        "let v_" + uid + ";\n" +
        "library.checkNumber(" + o1.body + ", " + JSON.stringify(loc(env, token)) + ");" +
        "if (" + o1.body + ") {\n" +
        indent(
          o2.head +
          "v_" + uid + " = " + o2.body + ";\n"
        ) +
        "} else {\n" +
        indent(
          o3.head +
          "v_" + uid + " = " + o3.body + ";\n"
        ) +
        "}\n",
        "(v_" + uid + ")"
      );
    });
    env.registerOperatorHandler("get", "minus_greater", (env, token) => {
      const name = token.argument[0].argument;
      const uidBody = env.getNextUid();
      env.pushAliasFrame();
      env.registerAlias(token.argument[0].argument, {
        get: (env, token) => toOperation("", "(v_" + uidBody + ")"),
      });
      const operationBody = env.compile("get", token.argument[1]);
      env.popAliasFrame();
      const label = `${env.getSuggestedName()}${loc(env, token)}`;
      const uidSymbol = env.getNextUid();
      const uid = env.getNextUid();
      return toOperation(
        "const v_" + uidSymbol + " = Symbol(" + JSON.stringify(label) + ");\n" +
        "const v_" + uid + " = " + "{[v_" + uidSymbol + "]: function(v_" + uidBody + ") {\n" +
        indent(
          operationBody.head +
          "return " + operationBody.body + ";\n"
        ) +
        "}}[v_" + uidSymbol + "];\n",
        "(v_" + uid + ")"
      );
    });
    env.registerOperatorHandler("get", "semicolons", (env, token) => {
      const heads = [];
      for (let i = 0; i < token.argument.length - 1; i++) {
        const operation = env.compile("run", token.argument[i]);
        heads.push(operation.head);
      }
      const operation = env.compile("get", token.argument[token.argument.length - 1]);
      return toOperation(
        heads.join("") +
        operation.head,
        operation.body
      );
    });

    env.registerOperatorHandler("set", "identifier", (env, token) => {
      const handlerTable = env.resolveAlias(token.argument);
      if (handlerTable === undefined) throw new Fluorite8CompileError("Unknown identifier: " + token.argument, env, token);
      const handler = handlerTable["set"];
      if (handler === undefined) throw new Fluorite8CompileError("Readonly identifier: " + token.argument, env, token);
      return handler(env);
    });

    env.registerOperatorHandler("array", "semicolons", (env, token) => {
      return toOperationArray(oSet => toOperationRun(
        token.argument.map(token2 => env.compile("array", token2).generate(oSet).head).join("")
      ));
    });

    env.registerOperatorHandler("run", "colon", (env, token) => {
      const name = token.argument[0].argument;
      const uid = env.getNextUid();
      env.registerAlias(name, {
        get: (env, token) => toOperation("", "(v_" + uid + ")"),
        set: (env, token) => toOperationSet(o => toOperationRun(o.head + "v_" + uid + " = " + o.body + ";\n"), name),
      });
      const operation = env.compile("get", token.argument[1], {
        suggestedName: name,
      });
      return toOperationRun(
        "let v_" + uid + ";\n" +
        operation.head +
        "v_" + uid + " = " + operation.body + ";\n"
      );
    });
    env.registerOperatorHandler("run", "equal", (env, token) => {
      const operationSetLeft = env.compile("set", token.argument[0]);
      const operationGetRight = env.compile("get", token.argument[1], {
        suggestedName: operationSetLeft.suggestedName,
      });
      return toOperationRun(
        operationSetLeft.accept(operationGetRight).head
      );
    });

    env.registerAlias("PI", {
      get: (env, token) => toOperation("", "(" + Math.PI + ")"),
    });

  }

  function token(type, argument, location) {
    return {type, argument, location};
  }

}
Root     = _ main:Formula _ {
             const token = main;
             let code;
             try {
               const env = new Environment();
               env.setFile("OnlineDemo");
               customizeEnvironment(env);
               code = env.compile("root", main);
             } catch (e) {
               console.log(e);
               return ["CompileError: " + e, token];
             }
             let result;
             try {
               result = eval(code)(library);
             } catch (e) {
               console.log(e);
               return ["RuntimeError: " + e, code, token];
             }
             return [result, code, token];
           }
Formula  = Semicolons
Semicolons = head:Lambda tail:(_ (";" { return location(); }) _ Lambda)* {
             if (tail.length == 0) return head;
             return token("semicolons", [head, ...tail.map(s => s[3])], tail[0][1]);
           }
Lambda   = head:(If _ (
             "->" { return ["minus_greater", location()]; }
           / ":" { return ["colon", location()]; }
           / "=" { return ["equal", location()]; }
           ) _)* tail:If {
             let result = tail;
             for (let i = head.length - 1; i >= 0; i--) {
               result = token(head[i][2][0], [head[i][0], result], head[i][2][1]);
             }
             return result;
           }
If       = head:Add _ operator:("?" { return location(); }) _ body:If _ ":" _ tail:If {
             return token("ternary_question_colon", [head, body, tail], operator);
           }
         / Add
Add      = head:Term tail:(_ (
             "+" { return ["plus", location()]; }
           / "-" { return ["minus", location()]; }
           ) _ Term)* {
             let result = head;
             for (let i = 0; i < tail.length; i++) {
               result = token(tail[i][1][0], [result, tail[i][3]], tail[i][1][1]);
             }
             return result;
           }
Term  = head:Left tail:(_ (
             "*" { return ["asterisk", location()]; }
           / "/" { return ["slash", location()]; }
           ) _ Left)* {
             let result = head;
             for (let i = 0; i < tail.length; i++) {
               result = token(tail[i][1][0], [result, tail[i][3]], tail[i][1][1]);
             }
             return result;
           }
Left     = head:((
             "+" { return ["left_plus", location()]; }
           / "-" { return ["left_minus", location()]; }
           / "$#" { return ["left_dollar_hash", location()]; }
           ) _)* tail:Pow {
             let result = tail;
             for (let i = head.length - 1; i >= 0; i--) {
               result = token(head[i][0][0], [result], head[i][0][1]);
             }
             return result;
           }
Pow      = head:Right _ operator:(
             "^" { return ["circumflex", location()]; }
           ) _ tail:Left {
             return token(operator[0], [head, tail], operator[1]);
           }
         / Right
Right    = head:Factor tail:(_ (
             "(" _ main:Formula _ ")" { return ["right_round", [main], location()] }
           / "[" _ main:Formula _ "]" { return ["right_square", [main], location()] }
           ))* {
             let result = head;
             for (let i = 0; i < tail.length; i++) {
               result = token(tail[i][1][0], [result, ...tail[i][1][1]], tail[i][1][2]);
             }
             return result;
           }
Factor   = Integer
         / String
         / Identifier
         / Brackets
Integer  = main:$[0-9]+ {
             return token("integer", main, location());
           }
String   = "'" main:(
             [^'\\]
           / "\\" main:. { return main; }
           )* "'" {
             return token("string", main.join(""), location());
           }
Identifier = main:$([a-zA-Z_] [a-zA-Z0-9_]*) {
             return token("identifier", main, location());
           }
Brackets = main:(
             "(" _ main:Formula _ ")" { return ["round", [main], location()]; }
           / "[" _ main:Formula _ "]" { return ["square", [main], location()]; }
           / "[" _ "]" { return ["empty_square", [], location()]; }
           ) {
             return token(main[0], main[1], main[2]);
           }
_        = [ \t\r\n]*
