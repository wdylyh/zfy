(* zfy 语言的 Token 定义 *)
type keyword =
  | KIf | KElse | KWhile | KFor | KReturn
  | KTrue | KFalse
  | KPub | KMod | KUse | KBreak | KContinue
  | KConst | KFrac | KUnreduced | KReduce | KAnd | KOr | KNot | KXor
  | KOutput | KInput
  | KCast | KArray | KList
  | KRemove | KImport | KAs | KSep | KEnd | KDelim
  | KFail | KPanic | KErr
  | KStruct | KPacked | KMove | KCopy | KBorrow | KRef | KNull | KUnsafe | KExtern | KType
  | KUnion | KExport | KSection | KInternal
  | KEnum | KMatch | KInterface | KUi
  | KShared | KLet | KFn | KIn
  | KAsm

let keyword_table =
  [ "if", KIf; "else", KElse;
    "while", KWhile; "for", KFor; "return", KReturn;
    "true", KTrue; "false", KFalse;
    "pub", KPub;
    "mod", KMod; "use", KUse; "break", KBreak; "continue", KContinue;
    "const", KConst; "frac", KFrac; "unred", KUnreduced;
    "reduce", KReduce;
    "and", KAnd; "or", KOr; "not", KNot; "xor", KXor;
    "output", KOutput; "input", KInput;
    "cast", KCast; "array", KArray; "list", KList;
    "remove", KRemove; "import", KImport; "as", KAs;
    "fail", KFail; "panic", KPanic; "err", KErr;
    "sep", KSep; "end", KEnd; "delim", KDelim;
    "struct", KStruct; "packed", KPacked; "move", KMove; "copy", KCopy;
    "union", KUnion; "export", KExport; "section", KSection;
    "internal", KInternal;
    "borrow", KBorrow;
    "ref", KRef; "null", KNull;
    "unsafe", KUnsafe; "extern", KExtern; "type", KType;
    "let", KLet; "fn", KFn; "in", KIn;
    "enum", KEnum; "match", KMatch; "interface", KInterface;
    "ui", KUi;
    "shared", KShared;
    "asm", KAsm ]

type token =
  | IntLit of int64
  | BigIntLit of string   (* 超出 i64 的十进制整数字面量（w-014 #6）：十进制数字串，
                              仅在 i128/u128 期望上下文合法 *)
  | RDecLit of int64 * int64  (* 循环小数字面量 (前缀,循环节,)（new.md 2026-10-11）：
                                 已折算为分数 num/den（num 含符号，den > 0）。
                                 由词法直接识别，parser 降为 EBin(Div, num, den)——
                                 frac 上下文按分数构造、float 上下文实数除、
                                 int 上下文整数除（截断，恰好符合"不四舍五入"） *)
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
  | Shl (* << *) | Shr (* >> *) | Pipe (* | *) | Tilde (* ~ *)
  | Pow (* ** 幂，右结合（v3.3） *)
  | Question (* ? *) | QuestionQuestion (* ?? *) | Bang (* ! *)
  | Ellipsis (* ...：extern 可变参数列表尾缀 *)
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
  | KUnion -> "union" | KExport -> "export" | KSection -> "section"
  | KInternal -> "internal"
  | KCopy -> "copy" | KBorrow -> "borrow" | KRef -> "ref"
  | KNull -> "null" | KUnsafe -> "unsafe" | KExtern -> "extern" | KType -> "type"
  | KSep -> "sep" | KEnd -> "end" | KDelim -> "delim"
  | KAnd -> "and" | KOr -> "or" | KNot -> "not" | KXor -> "xor"
  | KCast -> "cast"
  | KArray -> "array" | KList -> "list"
  | KLet -> "let" | KFn -> "fn" | KIn -> "in"
  | KEnum -> "enum" | KMatch -> "match" | KInterface -> "interface" | KUi -> "ui"
  | KShared -> "shared" | KAsm -> "asm"
let pp_token = function
  | IntLit n -> Printf.sprintf "Int %Ld" n
  | BigIntLit s -> Printf.sprintf "Big %s" s
  | RDecLit (a, b) -> Printf.sprintf "RDec %Ld/%Ld" a b
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
  | Shl -> "<<" | Shr -> ">>" | Pipe -> "|" | Tilde -> "~" | Pow -> "**"
  | Question -> "?" | QuestionQuestion -> "??" | Bang -> "!"
  | Ellipsis -> "..."
  | Caret -> "^"
  | Dot -> "."
  | Newline -> "\\n" | Indent -> "INDENT" | Dedent -> "DEDENT" | Eof -> "EOF"

(* 行尾续行判定（v3.5 DX）：行尾是这些 token 时，下一行自动并入当前表达式
   （不产生 Newline，下一行不做缩进测量）。覆盖二元运算符、复合赋值、逗号、
   成员/路径点等所有"行尾必未完"的词素。
   注意：? / ! 不在内（expr? 传播、T! 类型后缀在行尾是合法完结）；
   ?? 也不在内——行尾 ?? 是"解包块"语法（失败路径缩进块），不是续行。 *)
let is_line_cont = function
  | Plus | Minus | Star | Slash | Percent | Pow
  | Amp | Pipe | Tilde | Shl | Shr
  | Eq | Ne | Lt | Gt | Le | Ge
  | Assign | PlusAssign | MinusAssign | StarAssign | SlashAssign
  | PercentAssign | Comma | Dot | Colon -> true
  | Keyword (KAnd | KOr | KNot | KXor) -> true
  | _ -> false

(* 单词类型名（声明处类型位以 Ident 出现的名字）：
   基础类型 bool/char/string/void + 宽度类型 i8..i128 / u8..u128 / f16..f128 *)
let type_names =
  [ "bool"; "char"; "string"; "void"; "File";
    "i8"; "i16"; "i32"; "i64"; "i128";
    "u8"; "u16"; "u32"; "u64"; "u128";
    "f16"; "f32"; "f64"; "f128" ]
