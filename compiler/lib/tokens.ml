(* zfy 语言的 Token 定义 *)
type keyword =
  | KIf | KElse | KWhile | KFor | KReturn
  | KTrue | KFalse
  | KPub | KMod | KUse | KBreak | KContinue
  | KConst | KFrac | KUnreduced | KReduce | KAnd | KOr | KNot
  | KOutput | KInput
  | KCast | KArray | KList
  | KRemove | KImport | KAs | KSep | KEnd | KDelim
  | KFail | KPanic | KErr
  | KStruct | KPacked | KMove | KCopy | KRef | KNull | KUnsafe | KExtern | KType
  | KShort | KLong | KUshort | KUlong | KInt | KUint | KHalf | KFloat | KDouble | KQuad

let keyword_table =
  [ "if", KIf; "else", KElse;
    "while", KWhile; "for", KFor; "return", KReturn;
    "true", KTrue; "false", KFalse;
    "pub", KPub;
    "mod", KMod; "use", KUse; "break", KBreak; "continue", KContinue;
    "const", KConst; "frac", KFrac; "unred", KUnreduced;
    "reduce", KReduce;
    "and", KAnd; "or", KOr; "not", KNot;
    "output", KOutput; "input", KInput;
    "cast", KCast; "array", KArray; "list", KList;
    "remove", KRemove; "import", KImport; "as", KAs;
    "fail", KFail; "panic", KPanic; "err", KErr;
    "sep", KSep; "end", KEnd; "delim", KDelim;
    "struct", KStruct; "packed", KPacked; "move", KMove; "copy", KCopy;
    "ref", KRef; "null", KNull;
    "unsafe", KUnsafe; "extern", KExtern; "type", KType;
    "short", KShort; "long", KLong; "ushort", KUshort; "ulong", KUlong;
    "int", KInt; "uint", KUint;
    "half", KHalf; "float", KFloat; "double", KDouble; "quad", KQuad ]

type token =
  | IntLit of int64
  | BigIntLit of string   (* 超出 i64 的十进制整数字面量（w-014 #6）：十进制数字串，
                              仅在 i128/u128 期望上下文合法 *)
  | FloatLit of float
  | StrLit of string
  | CharLit of char
  | Ident of string
  | Keyword of keyword
  | LParen | RParen | LBracket | RBracket | LBrace | RBrace
  | Comma | Semicolon | Colon | FatArrow (* => *) | ThinArrow (* -> *)
  | Assign | Plus | Minus | Star | Slash | Percent | Amp
  | PlusAssign | MinusAssign | StarAssign | SlashAssign | PercentAssign
  | PlusPlus | MinusMinus
  | Eq | Ne | Lt | Gt | Le | Ge
  | Question (* ? *) | QuestionQuestion (* ?? *) | Bang (* ! *)
  | Caret (* ^：解引用后缀 p^（new2.md #10，替代 p* 消歧） *)
  | Dot
  | Newline
  | Indent
  | Dedent
  | Eof

(* 源码位置：file 为源文件路径（词法阶段注入，用于错误报告的文件定位） *)
type pos = { file : string; line : int; col : int }

let pp_keyword = function
  | KIf -> "if" | KElse -> "else"
  | KWhile -> "while" | KFor -> "for" | KReturn -> "return"
  | KTrue -> "true" | KFalse -> "false"
  | KOutput -> "output" | KInput -> "input" | KPub -> "pub"
  | KMod -> "mod" | KUse -> "use" | KBreak -> "break"
  | KContinue -> "continue"
  | KConst -> "const" | KFrac -> "frac" | KUnreduced -> "unred"
  | KReduce -> "reduce"
  | KRemove -> "remove" | KImport -> "import" | KAs -> "as"
  | KFail -> "fail" | KPanic -> "panic" | KErr -> "err"
  | KStruct -> "struct" | KPacked -> "packed" | KMove -> "move"
  | KCopy -> "copy" | KRef -> "ref"
  | KNull -> "null" | KUnsafe -> "unsafe" | KExtern -> "extern" | KType -> "type"
  | KSep -> "sep" | KEnd -> "end" | KDelim -> "delim"
  | KAnd -> "and" | KOr -> "or" | KNot -> "not"
  | KCast -> "cast"
  | KArray -> "array" | KList -> "list"
  | KShort -> "short" | KLong -> "long" | KUshort -> "ushort" | KUlong -> "ulong"
  | KInt -> "int"
  | KUint -> "uint" | KHalf -> "half" | KFloat -> "float" | KDouble -> "double"
  | KQuad -> "quad"

let pp_token = function
  | IntLit n -> Printf.sprintf "Int %Ld" n
  | BigIntLit s -> Printf.sprintf "Big %s" s
  | FloatLit f -> Printf.sprintf "Float %g" f
  | StrLit s -> Printf.sprintf "Str \"%s\"" (String.escaped s)
  | CharLit c -> Printf.sprintf "Char '%c'" c
  | Ident s -> Printf.sprintf "Ident %s" s
  | Keyword k -> Printf.sprintf "Kw %s" (pp_keyword k)
  | LParen -> "(" | RParen -> ")" | LBracket -> "[" | RBracket -> "]"
  | LBrace -> "{" | RBrace -> "}"
  | Comma -> "," | Semicolon -> ";" | Colon -> ":" | FatArrow -> "=>" | ThinArrow -> "->"
  | Assign -> "=" | Plus -> "+" | Minus -> "-" | Star -> "*" | Amp -> "&"
  | Slash -> "/" | Percent -> "%"
  | PlusAssign -> "+=" | MinusAssign -> "-="
  | StarAssign -> "*=" | SlashAssign -> "/=" | PercentAssign -> "%="
  | PlusPlus -> "++" | MinusMinus -> "--"
  | Eq -> "==" | Ne -> "!=" | Lt -> "<" | Gt -> ">" | Le -> "<=" | Ge -> ">="
  | Question -> "?" | QuestionQuestion -> "??" | Bang -> "!"
  | Caret -> "^"
  | Dot -> "."
  | Newline -> "\\n" | Indent -> "INDENT" | Dedent -> "DEDENT" | Eof -> "EOF"

(* 单词类型名（声明处类型位以 Ident 出现的名字）：
   基础类型 bool/char/string/void + 宽度类型 i8..i128 / u8..u128 / f16..f128 *)
let type_names =
  [ "bool"; "char"; "string"; "void"; "File";
    "i8"; "i16"; "i32"; "i64"; "i128";
    "u8"; "u16"; "u32"; "u64"; "u128";
    "f16"; "f32"; "f64"; "f128" ]
