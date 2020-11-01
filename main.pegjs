
{

  const fl8lib = {

    fl8: (() => {
      const fl8 = {};

      {
        class Fluorite8RuntimeError extends Error {
          constructor(message, locationInfo) {
            super(message + " @ " + locationInfo[0] + " (" + locationInfo[1] + ")");
            this.name = "Fluorite8RuntimeError";
            this.file = locationInfo[0];
            this.fl8Location = locationInfo[1];
          }
        }
        fl8.Fluorite8RuntimeError = Fluorite8RuntimeError;
      }

      fl8.getFunction = object => {
        return object[Object.getOwnPropertyNames(object)[0]];
      };

      fl8.throwRuntimeError = function(message, locationInfo) {
        fl8.getFunction({[locationInfo[0] + " (" + locationInfo[1] + ")"]: function() {
          const e = new fl8.Fluorite8RuntimeError(message, locationInfo);
          //console.log(e);
          throw e;
        }})();
      };

      {
        class Runtime {

          constructor() {
            this.properties = {};
          }

          setProperty(key, value) {
            this.properties[key] = value;
          }

          getProperty(key) {
            return this.properties[key];
          }

        }
        fl8.Runtime = Runtime;
      }

      fl8.toNumber = (value, file, fl8Location) => {
        const type = typeof value;
        if (type === "number") return value;
        fl8.throwRuntimeError("Cannot convert to number: " + value, file, fl8Location);
      };

      return fl8;
    })(),

    fl8c: (() => {
      const fl8c = {};

      fl8c.indent = code => "  " + code.replace(/\n(?!$)/g, "\n  ");

      {
        class Fluorite8CompileError extends Error {
          constructor(message, env, token) {
            super(message + " @ " + env.file + " (L:" + token.location.line + ",C:" + token.location.column + ")");
            this.name = "Fluorite8CompileError";
            this.env = env;
            this.token = token;
          }
        }
        fl8c.Fluorite8CompileError = Fluorite8CompileError;
      }

      {
        class Environment {

          constructor() {
            this.file = null;
            this.handlerRegistry = {};
          }

          setFile(file) {
            this.file = file;
          }

          registerHandler(domain, type, handler) {
            if (this.handlerRegistry[domain] === undefined) {
              this.handlerRegistry[domain] = {};
            }
            this.handlerRegistry[domain][type] = handler;
          }

          getHandler(domain, token) {
            const map = this.handlerRegistry[domain];
            if (map === undefined) throw new fl8c.Fluorite8CompileError("No such domain: " + domain, this, token);
            return map[token.type];
          }

          getNode(domain, token) {
            const handler = this.getHandler(domain, token)
            if (handler === undefined) throw new fl8c.Fluorite8CompileError("No such handler: " + domain + "/" + token.type, this, token);
            return handler(this, token);
          }

          compile(token) {
            const node = this.getNode("get", token);
            return (
              "(function(fl8, runtime) {\n" +
              fl8c.indent(
                "const file = " + JSON.stringify(this.file) + ";\n" +
                node.head +
                "return " + node.body + ";\n"
              ) +
              "})"
            );
          }

        }
        fl8c.Environment = Environment;
      }

      return fl8c;
    })(),

  };

  //

  function createRuntime(fl8) {
    const runtime = new fl8.Runtime();

    runtime.setProperty("PI", Math.PI);

    return runtime;
  }

  function createEnvironment(fl8c) {

    function nodeGet(head, body, type) {
      return {head, body, type};
    }

    function loc(token) {
      return "[file, \"" + "L:" + token.location.line + ",C:" + token.location.column + "\"]";
    }

    function throwRuntimeError(message, token) {
      return "fl8.throwRuntimeError(" + JSON.stringify(message) + ", " + loc(token) + ");\n";
    }

    const env = new fl8c.Environment();

    env.registerHandler("get", "integer", (env, token) => {
      return nodeGet("", "" + parseInt(token.arg, 10), "number");
    });
    env.registerHandler("get", "identifier", (env, token) => {
      if (token.arg === "NULL") {
        return nodeGet("", "(null)", "unknown");
      } else if (token.arg === "DIE") {
        return nodeGet(throwRuntimeError("Died", token), "(null)", "unknown");
      } else if (token.arg === "UNKNOWN") {
        throw new fl8c.Fluorite8CompileError("Unknown alias: " + token.arg, env, token);
      } else {
        return nodeGet("", "(runtime.getProperty(" + JSON.stringify(token.arg) + "))", "unknown");
      }
    });
    env.registerHandler("get", "string", (env, token) => {
      return nodeGet("", JSON.stringify(token.arg), "string");
    });
    env.registerHandler("get", "round", (env, token) => {
      return env.getNode("get", token.arg[0]);
    });
    env.registerHandler("get", "left_plus", (env, token) => {
      const node1 = env.getNode("get", token.arg[0])
      return nodeGet(node1.head, "(fl8.toNumber(" + node1.body + ", " + loc(token) + "))", "number");
    });
    env.registerHandler("get", "circumflex", (env, token) => {
      const node1 = env.getNode("get", token.arg[0])
      const node2 = env.getNode("get", token.arg[1])
      if (node1.type === "number" && node2.type === "number") {
        return nodeGet(
          node1.head + node2.head,
          "(Math.pow(" + node1.body + ", " + node2.body + "))",
          "number"
        );
      } else {
        throw new fl8c.Fluorite8CompileError("Unknown operation: " + token.type + "(" + node1.type + ", " + node2.type + ")", env, token);
      }
    });
    env.registerHandler("get", "asterisk", (env, token) => {
      const node1 = env.getNode("get", token.arg[0])
      const node2 = env.getNode("get", token.arg[1])
      if (node1.type === "number" && node2.type === "number") {
        return nodeGet(
          node1.head + node2.head,
          "(" + node1.body + " * " + node2.body + ")",
          "number"
        );
      } else {
        throw new fl8c.Fluorite8CompileError("Unknown operation: " + token.type + "(" + node1.type + ", " + node2.type + ")", env, token);
      }
    });
    env.registerHandler("get", "slash", (env, token) => {
      const node1 = env.getNode("get", token.arg[0])
      const node2 = env.getNode("get", token.arg[1])
      if (node1.type === "number" && node2.type === "number") {
        return nodeGet(
          node1.head + node2.head,
          "(" + node1.body + " / " + node2.body + ")",
          "number"
        );
      } else {
        throw new fl8c.Fluorite8CompileError("Unknown operation: " + token.type + "(" + node1.type + ", " + node2.type + ")", env, token);
      }
    });
    env.registerHandler("get", "percentage", (env, token) => {
      const node1 = env.getNode("get", token.arg[0])
      const node2 = env.getNode("get", token.arg[1])
      if (node1.type === "number" && node2.type === "number") {
        return nodeGet(
          node1.head + node2.head,
          "(" + node1.body + " % " + node2.body + ")",
          "number"
        );
      } else {
        throw new fl8c.Fluorite8CompileError("Unknown operation: " + token.type + "(" + node1.type + ", " + node2.type + ")", env, token);
      }
    });
    env.registerHandler("get", "plus", (env, token) => {
      const node1 = env.getNode("get", token.arg[0])
      const node2 = env.getNode("get", token.arg[1])
      if (node1.type === "number" && node2.type === "number") {
        return nodeGet(
          node1.head + node2.head,
          "(" + node1.body + " + " + node2.body + ")",
          "number"
        );
      } else {
        throw new fl8c.Fluorite8CompileError("Unknown operation: " + token.type + "(" + node1.type + ", " + node2.type + ")", env, token);
      }
    });
    env.registerHandler("get", "minus", (env, token) => {
      const node1 = env.getNode("get", token.arg[0])
      const node2 = env.getNode("get", token.arg[1])
      if (node1.type === "number" && node2.type === "number") {
        return nodeGet(
          node1.head + node2.head,
          "(" + node1.body + " - " + node2.body + ")",
          "number"
        );
      } else {
        throw new fl8c.Fluorite8CompileError("Unknown operation: " + token.type + "(" + node1.type + ", " + node2.type + ")", env, token);
      }
    });

    return env;
  }

  //

  function token(type, arg, location) {
    return {type, arg, location};
  }

}

//

Root
  = _ main:Expression _ {

      const token = main;

      const env = createEnvironment(fl8lib.fl8c);
      env.setFile("Online Demo");

      let code;
      try {
        code = env.compile(token);
      } catch (e) {
        if (e instanceof fl8lib.fl8c.Fluorite8CompileError) {
          return ["[Compile Error] " + e, token];
        } else {
          throw e;
        }
      }

      let func = eval(code);

      const runtime = createRuntime(fl8lib.fl8);

      let result;
      try {
        result = func(fl8lib.fl8, runtime);
      } catch (e) {
        if (e instanceof fl8lib.fl8.Fluorite8RuntimeError) {
          return ["[Runtime Error] " + e, code, token];
        } else {
          throw e;
        }
      }

      return [result, code, token];
    }

//

CharacterWhitespace
  = [ \t\r\n]

CharacterIdentifierHead
  = [a-zA-Z_]

CharacterIdentifierBody
  = [a-zA-Z_0-9]

//

_ "Gap"
  = $(CharacterWhitespace*)

LiteralInteger "Integer"
  = [0-9]+ { return token("integer", text(), location().start); }

LiteralIdentifier "Identifier"
  = main:$(CharacterIdentifierHead CharacterIdentifierBody*) {
      return token("identifier", text(), location().start);
    }

LiteralString "String"
  = "\'" main:(
      [^'\\]
    / "\\" main:. { return main; }
    )* "\'" {
      return token("string", main.join(""), location().start);
    }

Brackets
  = "(" _ main:Expression _ ")" { return token("round", [main], location().start); }

Factor
  = LiteralInteger
  / LiteralIdentifier
  / LiteralString
  / Brackets

Left
  = head:((
      "+" { return ["left_plus", location().start]; }
    ) _)* tail:Factor {
      let result = tail;
      for (let i = head.length - 1; i >= 0; i--) {
        result = token(head[i][0][0], [result], head[i][0][1]);
      }
      return result;
    }

Pow
  = head:(Left _ (
      "^" { return ["circumflex", location().start]; }
    ) _)* tail:Left {
      let result = tail;
      for (let i = head.length - 1; i >= 0; i--) {
        result = token(head[i][2][0], [head[i][0], result], head[i][2][1]);
      }
      return result;
    }

Mul
  = head:Pow tail:(_ (
      "*" { return ["asterisk", location().start]; }
    / "/" { return ["slash", location().start]; }
    / "%" { return ["percentage", location().start]; }
    ) _ Pow)* {
      let result = head;
      for (let i = 0; i < tail.length; i++) {
        result = token(tail[i][1][0], [result, tail[i][3]], tail[i][1][1]);
      }
      return result;
    }

Add
  = head:Mul tail:(_ (
      "+" { return ["plus", location().start]; }
    / "-" { return ["minus", location().start]; }
    ) _ Mul)* {
      let result = head;
      for (let i = 0; i < tail.length; i++) {
        result = token(tail[i][1][0], [result, tail[i][3]], tail[i][1][1]);
      }
      return result;
    }

Expression
  = Add
