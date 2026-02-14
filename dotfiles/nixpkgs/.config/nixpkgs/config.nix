{
  allowUnfreePredicate = pkg:
    builtins.elem pkg.pname [
      "claude-code"
    ];
}
