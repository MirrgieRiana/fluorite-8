
{

  const fl8lib = {

    fl8: (() => {
      const fl8 = {};

      {
        class Fluorite8RuntimeError extends Error {
          constructor(message, file, fl8Location) {
            super(message + " @ " + file + " (" + fl8Location + ")");
            this.name = "Fluorite8RuntimeError";
            this.file = file;
            this.fl8Location = fl8Location;
          }
        }
        fl8.Fluorite8RuntimeError = Fluorite8RuntimeError;
      }

      {
        fl8.getFunction = object => {
          return object[Object.getOwnPropertyNames(object)[0]];
        };
      }

      {
        fl8.throwRuntimeError = function(message, file, fl8Location) {
          fl8.getFunction({[file + " (" + fl8Location + ")"]: function() {
            const e = new fl8.Fluorite8RuntimeError(message, file, fl8Location);
            //console.log(e);
            throw e;
          }})();
        };
      }

      return fl8;
    })(),

    fl8c: (() => {
      const fl8c = {};

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
            return "const file = " + JSON.stringify(this.file) + ";\n" + node.head + node.body;
          }

        }
        fl8c.Environment = Environment;
      }

      return fl8c;
    })(),

  };

  //

  function createEnvironment(fl8c) {

    function nodeGet(head, body, type) {
      return {head, body, type};
    }

    function throwRuntimeError(message, token) {
      return "fl8.throwRuntimeError(" + JSON.stringify(message) + ", file, \"" + "L:" + token.location.line + ",C:" + token.location.column + "\");\n"
    }

    const env = new fl8c.Environment();

    env.registerHandler("get", "integer", (env, token) => {
      return nodeGet("", "" + parseInt(token.arg, 10), "number");
    });
    env.registerHandler("get", "identifier", (env, token) => {
      if (token.arg === "NULL") {
        return nodeGet("", "(null)", "unknown");
      } else {
        throw new fl8c.Fluorite8CompileError("Unknown alias: " + token.arg, env, token);
      }
    });
    env.registerHandler("get", "round", (env, token) => {
      return env.getNode("get", token.arg[0]);
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

      const env = createEnvironment(fl8lib.fl8c);
      env.setFile("Online Demo");

      const token = main;
      const js = env.compile(token);
      let result;
      {
        const fl8 = fl8lib.fl8;
        try {
          result = eval(js);
        } catch (e) {
          if (e instanceof fl8.Fluorite8RuntimeError) {
            result = "ERROR: " + e;
          } else {
            throw e;
          }
        }
      }

      return [result, js, token];
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

TokenInteger "Integer"
  = [0-9]+ { return token("integer", text(), location().start); }

TokenIdentifier "Identifier"
  = main:$(CharacterIdentifierHead CharacterIdentifierBody*) {
      return token("identifier", text(), location().start);
    }

Brackets
  = "(" _ main:Expression _ ")" { return token("round", [main], location().start); }

Factor
  = TokenInteger
  / TokenIdentifier
  / Brackets

Pow
  = head:(Factor _ (
      "^" { return ["circumflex", location().start]; }
    ) _)* tail:Factor {
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
