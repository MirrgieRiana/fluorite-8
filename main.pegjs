
{

  function token(type, arg, location) {
    return {type, arg, location};
  }

  class Fluorite8CompileError extends Error {

    constructor(message, fl8Location) {
      super(message + " (L:" + fl8Location.line + ",C:" + fl8Location.column + ")");
      this.name = "Fluorite8CompileError";
      this.fl8Location = fl8Location;
    }

  }

  class Environment {

    constructor() {
      this.handlerRegistry = {};
    }

    registerHandler(domain, type, handler) {
      if (this.handlerRegistry[domain] === undefined) {
        this.handlerRegistry[domain] = {};
      }
      this.handlerRegistry[domain][type] = handler;
    }

    compile(domain, token) {
      const list1 = this.handlerRegistry[domain];
      if (list1 === undefined) throw new Fluorite8CompileError("No such domain: " + domain, token.location);
      const list2 = list1[token.type];
      if (list2 === undefined) throw new Fluorite8CompileError("No such handler: " + domain + "/" + token.type, token.location);
      return list2(this, token);
    }

  }

  function createEnvironment() {

    function codeGet(head, body, type) {
      return {head, body, type};
    }

    const env = new Environment();

    env.registerHandler("get", "integer", (env, token) => {
      return codeGet("", "" + parseInt(token.arg, 10), "number");
    });
    env.registerHandler("get", "round", (env, token) => {
      return env.compile("get", token.arg[0]);
    });
    env.registerHandler("get", "circumflex", (env, token) => {
      const node1 = env.compile("get", token.arg[0])
      const node2 = env.compile("get", token.arg[1])
      return codeGet(
        node1.head + node2.head,
        "(Math.pow(" + node1.body + ", " + node2.body + "))",
        "number"
      );
    });
    env.registerHandler("get", "asterisk", (env, token) => {
      const node1 = env.compile("get", token.arg[0])
      const node2 = env.compile("get", token.arg[1])
      return codeGet(
        node1.head + node2.head,
        "(" + node1.body + " * " + node2.body + ")",
        "number"
      );
    });
    env.registerHandler("get", "slash", (env, token) => {
      const node1 = env.compile("get", token.arg[0])
      const node2 = env.compile("get", token.arg[1])
      return codeGet(
        node1.head + node2.head,
        "(" + node1.body + " / " + node2.body + ")",
        "number"
      );
    });
    env.registerHandler("get", "plus", (env, token) => {
      const node1 = env.compile("get", token.arg[0])
      const node2 = env.compile("get", token.arg[1])
      return codeGet(
        node1.head + node2.head,
        "(" + node1.body + " + " + node2.body + ")",
        "number"
      );
    });
    env.registerHandler("get", "minus", (env, token) => {
      const node1 = env.compile("get", token.arg[0])
      const node2 = env.compile("get", token.arg[1])
      return codeGet(
        node1.head + node2.head,
        "(" + node1.body + " - " + node2.body + ")",
        "number"
      );
    });

    return env;
  }

}

//

Root
  = _ main:Expression _ {
      const env = createEnvironment();
      const token = main;
      const node = env.compile("get", token);
      const js = node.head + node.body;
      const result = eval(js);
      return [result, js, node, token];
    }

//

Whitespace "Whitespace"
  = [ \t\r\n]

_ "Gap"
  = $(Whitespace*)

FactorInteger "Integer"
  = [0-9]+ { return token("integer", text(), location().start); }

FactorNumeric
  = FactorInteger

FactorBrackets
  = "(" _ main:Expression _ ")" { return token("round", [main], location().start); }

Factor
  = FactorNumeric
  / FactorBrackets

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
