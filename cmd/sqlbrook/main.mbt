///|
const NAME = "<stdin>"

///|
async fn eprint(msg : String) -> Unit {
  @stdio.stderr.write(msg)
}

///|
async fn report_error(message : String, hint~ : Bool) -> Unit {
  eprint("sqlbrook: \{NAME}: \{message}\n")
  if hint {
    eprint(
      "sqlbrook: \{NAME}: input is not lexable SQLite SQL; check for stray bytes or host-language interpolation (use bind parameters instead)\n",
    )
  }
}

///|
async fn run() -> Int32 {
  let matches = command().parse() catch {
    err => {
      let text = err.to_string()
      let first = text.split("\n").next().unwrap_or("")
      let first = first.strip_prefix("error: ").unwrap_or(first).to_owned()
      eprint("sqlbrook: \{first}, run `sqlbrook --help`\n")
      return 2
    }
  }
  if matches.flags.get("man").unwrap_or(false) {
    @stdio.stdout.write(MAN_PAGE)
    return 0
  }
  let check = matches.flags.get("check").unwrap_or(false)
  let bytes = @stdio.stdin.read_all().binary()
  let src = @utf8.decode(bytes) catch {
    _ => {
      report_error(
        "invalid UTF-8 at offset \{utf8_error_offset(bytes)}",
        hint=true,
      )
      return 2
    }
  }
  let formatted = @lib.format(src) catch {
    err => {
      let hint = err is UnexpectedByte(_, ..)
      report_error(err.to_string(), hint~)
      return 2
    }
  }
  let unformatted = formatted.output != src
  if !check {
    @stdio.stdout.write(formatted.output)
  }
  for skip in formatted.skips {
    eprint(
      "sqlbrook: \{NAME}: line \{skip.line}: \{skip.kind} not yet formatted, passed through\n",
    )
  }
  if check && unformatted {
    eprint("sqlbrook: \{NAME}: not formatted\n")
  }
  if formatted.had_passthrough() {
    3
  } else if check && unformatted {
    1
  } else {
    0
  }
}

///|
async fn main {
  @sys.exit(run())
}
