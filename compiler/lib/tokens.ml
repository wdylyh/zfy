(* zfy 语言的 Token 定义 *)
type keyword =
  | KIf | KElse | KWhile | KFor | KReturn
  | KTrue | KFalse
  | KPub | KMod | KUse | KBreak | KContinue
  | KConst | KFrac | KUnreduced | KReduce | KAnd | KOr | KNot
  | KOutput | KInput
  | KCast | KArray | KList
  | KRemove | KImport | KAs | KSep | KEnd | KDelim
  | KThrow | KTry | KCatch
  | KShort | KLong | KInt | KUint | KHalf | KFloat | KDouble

let keyword_table =
  [ "if", KIf; "else", KElse;
    "while", KWhile; "for", KFor; "return", KReturn;
    "true", KTrue; "false", KFalse;
    "pub", KPub;
    "mod", KMod; "use", KUse; "break", KBreak; "continue", KContinue;
    "const", KConst; "frac", KFrac; "unreduced", KUnreduced;
    "reduce", KReduce;
    "and", KAnd; "or", KOr; "not", KNot;
    "output", KOutput; "input", KInput;
    "cast", KCast; "array", KArray; "list", KList;
    "remove", KRemove; "import", KImport; "as", KAs;
    "throw", KThrow; "try", KTry; "catch", KCatch;
    "sep", KSep; "end", KEnd; "delim", KDelim;
    "short", KShort; "long", KLong; "int", KInt; "uint", KUint;
    "half", KHalf; "float", KFloat; "double", KDouble ]

type token =
  | IntLit of int64
  | FloatLit of float
  | StrLit of string
  | CharLit of char
  | Ident of string
  | Keyword of keyword
  | LParen | RParen | LBracket | RBracket | LBrace | RBrace
  | Comma | Semicolon | Colon | FatArrow (* => *) | ThinArrow (* -> *)
  | Assign | Plus | Minus | Star | Slash | Percent
  | PlusAssign | MinusAssign | StarAssign | SlashAssign | PercentAssign
  | PlusPlus | MinusMinus
  | Eq | Ne | Lt | Gt | Le | Ge
  | Dot
  | Newline
  | Indent
  | Dedent
  | Eof

type pos = { line : int; col : int }

let pp_keyword = function
  | KIf -> "if" | KElse -> "else"
  | KWhile -> "while" | KFor -> "for" | KReturn -> "return"
  | KTrue -> "true" | KFalse -> "false"
  | KOutput -> "output" | KInput -> "input" | KPub -> "pub"
  | KMod -> "mod" | KUse -> "use" | KBreak -> "break"
  | KContinue -> "continue"
  | KConst -> "const" | KFrac -> "frac" | KUnreduced -> "unreduced"
  | KReduce -> "reduce"
  | KRemove -> "remove" | KImport -> "import" | KAs -> "as"
  | KThrow -> "throw" | KTry -> "try" | KCatch -> "catch"
  | KSep -> "sep" | KEnd -> "end" | KDelim -> "delim"
  | KAnd -> "and" | KOr -> "or" | KNot -> "not"
  | KCast -> "cast"
  | KArray -> "array" | KList -> "list"
  | KShort -> "short" | KLong -> "long" | KInt -> "int" | KUint -> "uint"
  | KHalf -> "half" | KFloat -> "float" | KDouble -> "double"

let pp_token = function
  | IntLit n -> Printf.sprintf "Int %Ld" n
  | FloatLit f -> Printf.sprintf "Float %g" f
  | StrLit s -> Printf.sprintf "Str \"%s\"" (String.escaped s)
  | CharLit c -> Printf.sprintf "Char '%c'" c
  | Ident s -> Printf.sprintf "Ident %s" s
  | Keyword k -> Printf.sprintf "Kw %s" (pp_keyword k)
  | LParen -> "(" | RParen -> ")" | LBracket -> "[" | RBracket -> "]"
  | LBrace -> "{" | RBrace -> "}"
  | Comma -> "," | Semicolon -> ";" | Colon -> ":" | FatArrow -> "=>" | ThinArrow -> "->"
  | Assign -> "=" | Plus -> "+" | Minus -> "-" | Star -> "*"
  | Slash -> "/" | Percent -> "%"
  | PlusAssign -> "+=" | MinusAssign -> "-="
  | StarAssign -> "*=" | SlashAssign -> "/=" | PercentAssign -> "%="
  | PlusPlus -> "++" | MinusMinus -> "--"
  | Eq -> "==" | Ne -> "!=" | Lt -> "<" | Gt -> ">" | Le -> "<=" | Ge -> ">="
  | Dot -> "."
  | Newline -> "\\n" | Indent -> "INDENT" | Dedent -> "DEDENT" | Eof -> "EOF"

(* 单词类型名（声明处类型位以 Ident 出现的名字；数值类型是关键字多词形式） *)
let type_names =
  [ "bool"; "char"; "string"; "void" ]

(* 数值类型关键字（可开启多词类型序列） *)
let numeric_ty_kws = [ KShort; KLong; KInt; KUint; KHalf; KFloat; KDouble ]
