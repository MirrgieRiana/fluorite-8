
{

  function token(type, args) {
    return {type, args};
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
      if (list1 === undefined) throw new Error("No such domain: " + domain);
      const list2 = list1[token.type];
      if (list2 === undefined) throw new Error("No such handler: " + domain + "/" + token.type);
      return list2(this, token.args);
    }

  }

  function createEnvironment() {

    function codeGet(head, body, type) {
      return {head, body, type};
    }

    const env = new Environment();

    env.registerHandler("get", "integer", (env, arg) => {
      return codeGet("", "" + parseInt(arg, 10), "number");
    });
    env.registerHandler("get", "round", (env, arg) => {
      return env.compile("get", arg[0]);
    });
    env.registerHandler("get", "circumflex", (env, arg) => {
      const node1 = env.compile("get", arg[0])
      const node2 = env.compile("get", arg[1])
      return codeGet(
        node1.head + node2.head,
        "(Math.pow(" + node1.body + ", " + node2.body + "))",
        "number"
      );
    });
    env.registerHandler("get", "asterisk", (env, arg) => {
      const node1 = env.compile("get", arg[0])
      const node2 = env.compile("get", arg[1])
      return codeGet(
        node1.head + node2.head,
        "(" + node1.body + " * " + node2.body + ")",
        "number"
      );
    });
    env.registerHandler("get", "slash", (env, arg) => {
      const node1 = env.compile("get", arg[0])
      const node2 = env.compile("get", arg[1])
      return codeGet(
        node1.head + node2.head,
        "(" + node1.body + " / " + node2.body + ")",
        "number"
      );
    });
    env.registerHandler("get", "plus", (env, arg) => {
      const node1 = env.compile("get", arg[0])
      const node2 = env.compile("get", arg[1])
      return codeGet(
        node1.head + node2.head,
        "(" + node1.body + " + " + node2.body + ")",
        "number"
      );
    });
    env.registerHandler("get", "minus", (env, arg) => {
      const node1 = env.compile("get", arg[0])
      const node2 = env.compile("get", arg[1])
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
  = [0-9]+ { return token("integer", text()); }

FactorNumeric
  = FactorInteger

FactorBrackets
  = "(" _ main:Expression _ ")" { return token("round", [main]); }

Factor
  = FactorNumeric
  / FactorBrackets

Pow
  = head:(Factor _ (
      "^" { return "circumflex"; }
    ) _)* tail:Factor {
      let result = tail;
      for (let i = head.length - 1; i >= 0; i--) {
        result = token(head[i][2], [head[i][0], result]);
      }
      return result;
    }

Mul
  = head:Pow tail:(_ (
      "*" { return "asterisk"; }
    / "/" { return "slash"; }
    ) _ Pow)* {
      let result = head;
      for (let i = 0; i < tail.length; i++) {
        result = token(tail[i][1], [result, tail[i][3]]);
      }
      return result;
    }

Add
  = head:Mul tail:(_ (
      "+" { return "plus"; }
    / "-" { return "minus"; }
    ) _ Mul)* {
      let result = head;
      for (let i = 0; i < tail.length; i++) {
        result = token(tail[i][1], [result, tail[i][3]]);
      }
      return result;
    }

Expression
  = Add
