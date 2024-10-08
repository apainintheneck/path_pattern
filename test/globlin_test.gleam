/// Some of these tests are based on the tests in the Python standard library for the `fnmatch` library.
/// 
/// Source: https://github.com/python/cpython/blob/e913d2c87f1ae4e7a4aef5ba78368ef31d060767/Lib/test/test_fnmatch.py
/// 
import gleam/list
import gleam/string
import gleeunit
import gleeunit/should
import globlin

pub fn main() {
  gleeunit.main()
}

type Pair {
  Pair(content: String, pattern: String)
}

const empty_options = globlin.PatternOptions(
  ignore_case: False,
  match_dotfiles: False,
)

const no_case_options = globlin.PatternOptions(
  ignore_case: True,
  match_dotfiles: False,
)

const with_dots_options = globlin.PatternOptions(
  ignore_case: False,
  match_dotfiles: True,
)

fn check_pattern(
  pair pair: Pair,
  is_match is_match: Bool,
  options options: globlin.PatternOptions,
) -> Nil {
  globlin.new_pattern_with(pair.pattern, from: "", with: options)
  |> should.be_ok
  |> globlin.match_pattern(pair.content)
  |> should.equal(is_match)
}

pub fn simple_patterns_test() {
  [
    Pair(content: "abc", pattern: "abc"),
    Pair(content: "abc", pattern: "?*?"),
    Pair(content: "abc", pattern: "???*"),
    Pair(content: "abc", pattern: "*???"),
    Pair(content: "abc", pattern: "???"),
    Pair(content: "abc", pattern: "*"),
    Pair(content: "abc", pattern: "ab[cd]"),
    Pair(content: "abc", pattern: "ab[!de]"),
  ]
  |> list.each(check_pattern(pair: _, is_match: True, options: empty_options))

  [
    Pair(content: "abc", pattern: "ab[de]"),
    Pair(content: "a", pattern: "??"),
    Pair(content: "a", pattern: "b"),
  ]
  |> list.each(check_pattern(pair: _, is_match: False, options: empty_options))
}

pub fn paths_with_newlines_test() {
  [
    Pair(content: "foo\nbar", pattern: "foo*"),
    Pair(content: "foo\nbar\n", pattern: "foo*"),
    Pair(content: "\nfoo", pattern: "\nfoo*"),
    Pair(content: "\n", pattern: "*"),
  ]
  |> list.each(check_pattern(pair: _, is_match: True, options: empty_options))
}

pub fn slow_patterns_test() {
  [
    Pair(content: string.repeat("a", 50), pattern: "*a*a*a*a*a*a*a*a*a*a"),
    Pair(
      content: string.repeat("a", 50) <> "b",
      pattern: "*a*a*a*a*a*a*a*a*a*ab",
    ),
  ]
  |> list.each(check_pattern(pair: _, is_match: True, options: empty_options))
}

pub fn case_sensitivity_test() {
  [Pair(content: "abc", pattern: "abc"), Pair(content: "AbC", pattern: "AbC")]
  |> list.each(fn(pair) {
    check_pattern(pair: pair, is_match: True, options: empty_options)
    check_pattern(pair: pair, is_match: True, options: no_case_options)
  })

  [Pair(content: "AbC", pattern: "abc"), Pair(content: "abc", pattern: "AbC")]
  |> list.each(fn(pair) {
    check_pattern(pair: pair, is_match: False, options: empty_options)
    check_pattern(pair: pair, is_match: True, options: no_case_options)
  })
}

pub fn dotfiles_test() {
  [
    Pair(content: ".secrets.txt", pattern: "*"),
    Pair(content: "repo/.git/config", pattern: "repo/**/config"),
    Pair(content: ".vimrc", pattern: "?vim*"),
  ]
  |> list.each(fn(pair) {
    check_pattern(pair: pair, is_match: False, options: empty_options)
    check_pattern(pair: pair, is_match: True, options: with_dots_options)
  })

  [
    Pair(content: "go/pkg/.mod/golang.org/", pattern: "go/*/.mod/*/"),
    Pair(content: ".vscode/argv.json", pattern: ".vscode/**"),
    Pair(content: "/path/README.md", pattern: "/path/README???"),
  ]
  |> list.each(fn(pair) {
    check_pattern(pair: pair, is_match: True, options: empty_options)
    check_pattern(pair: pair, is_match: True, options: with_dots_options)
  })
}

pub fn globstar_test() {
  [
    "**", "**/ghi", "**/def/**", "**/def/ghi", "abc/**", "abc/def/**",
    "**/abc/def/ghi", "abc/def/ghi/**",
  ]
  |> list.each(fn(pattern) {
    let pair = Pair(content: "abc/def/ghi", pattern:)
    check_pattern(pair:, is_match: True, options: empty_options)
  })

  [
    "hello_world.gleam", "hello.world.gleam", "hello/world.gleam",
    "he.llo/wo.rld.gleam",
  ]
  |> list.each(fn(content) {
    let pair = Pair(content:, pattern: "**/*.gleam")
    check_pattern(pair:, is_match: True, options: empty_options)
  })
}

pub fn from_directory_test() {
  ["/home/", "/home"]
  |> list.each(fn(directory) {
    globlin.new_pattern_with(
      "documents/**/img_*.png",
      from: directory,
      with: empty_options,
    )
    |> should.be_ok
    |> globlin.match_pattern(
      path: "/home/documents/mallorca_2012/img_beach.png",
    )
    |> should.be_true
  })
}

pub fn invalid_pattern_test() {
  ["[", "abc[def", "abc[def\\]g", "]]]][[]["]
  |> list.each(fn(pattern) {
    globlin.new_pattern(pattern)
    |> should.equal(Error(globlin.MissingClosingBracketError))
  })

  ["ab**cd", "one/two**/three", "four/**five/six", "**seven", "eight**"]
  |> list.each(fn(pattern) {
    globlin.new_pattern(pattern)
    |> should.equal(Error(globlin.InvalidGlobStarError))
  })

  globlin.new_pattern_with("/**/*.json", from: "/home", with: empty_options)
  |> should.equal(Error(globlin.AbsolutePatternFromDirError))
}

// JS: In unicode aware mode these need to be escaped explicitly.
// See https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Errors/Regex_raw_bracket
pub fn raw_brackets_test() {
  [
    "]", "[[[]]]", "[]]]]", "{", "}", "{{{}}}", "{}}}", "(", ")", "((()))",
    "()))",
  ]
  |> list.each(fn(pattern) {
    globlin.new_pattern(pattern)
    |> should.be_ok
  })
}

pub fn readme_test() {
  let files = [
    ".gitignore", "gleam.toml", "LICENCE", "manifest.toml", "README.md",
    "src/globlin.gleam", "test/globlin_test.gleam",
  ]

  let assert Ok(pattern) = globlin.new_pattern("**/*.gleam")

  files
  |> list.filter(keeping: globlin.match_pattern(pattern:, path: _))
  |> should.equal(["src/globlin.gleam", "test/globlin_test.gleam"])
}
