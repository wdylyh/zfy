(* 完整管线驱动：源码 -> .ll -> 可执行文件 *)
open Tokens
open Ast

exception CompileError of pos option * string

(* ---------- 错误报告（n3：多错误收集 + new.md 格式输出） ---------- *)

type fixkind =
  | FixNone                     (* 普通错误 *)
  | FixSem                      (* 语义级修复：coerce 已插 cast，编译继续
                                   （仅当源码 token 无法定位时的兜底） *)
  | FixPatch of int * int * string  (* 源码补丁 (col, len, newtext)：
                                   改名类与 cast 插入类均适用 *)

type zerr = { code : string; zpos : pos; zmsg : string; fix : fixkind }

(* 子串查找（朴素匹配；标准库无字符串 contains） *)
let has_sub (m : string) (sub : string) : bool =
  let n = String.length m and k = String.length sub in
  let rec go i =
    if i + k > n then false
    else if String.sub m i k = sub then true
    else go (i + 1)
  in
  if k = 0 then true else go 0

(* 错误码查表（一一对应 errors.md）：条目 (子串列表, 码)——错误消息命中
   全部子串即取该码，按表序先命中先得（特异条目在前）。未命中回退
   fallback 兜底码（未细分错误，不应触发）。 *)
let code_of_tbl fallback (tbl : (string list * string) list) (m : string) : string =
  let rec go = function
    | (subs, c) :: r ->
      if List.for_all (fun s -> has_sub m s) subs then c else go r
    | [] -> fallback
  in
  go tbl

(* 阶段 → 文案查表：同阶段同文案同码；跨阶段同文案不同码（如
   "unsupported assignment target"：typeck E3035 / mir E4008）故分表。 *)
let code_of = function
  | `Lex ->
    code_of_tbl "E1000" [
      ["unterminated string literal"], "E1001";
      ["dangling escape character"], "E1002";
      ["unknown escape sequence"], "E1003";
      ["raw newline in string literal"], "E1004";
      ["unterminated character literal"], "E1005";
      ["character literal must end with"], "E1008";
      ["numeric literal has no digits"], "E1009";
      ["invalid float literal"], "E1010";
      ["hex literal overflows"], "E1011";
      ["binary literal overflows"], "E1012";
      ["integer literal overflows"], "E1013";
      ["unterminated block comment"], "E1014";
      ["inconsistent indentation"], "E1015";
      ["illegal character"], "E1016";
    ]
  | `Parse -> fun m ->
    (* expect_ident 的 what 任意（变量名/函数名/...），用形态特征识别 *)
    if has_sub m " (identifier), got " then "E2006"
    else if has_sub m "invalid syntax 'a..b'" then "E2042"
    else
      code_of_tbl "E2007" [
        ["expected an expression, got "], "E2001";
        ["expected a type, got "], "E2008";
        ["expected a top-level item"], "E2005";
        ["declaration syntax: "], "E2003";
        ["duplicate base type: "], "E2010";
        ["const requires an initializer"], "E2012";
        ["lists do not support the frac modifier"], "E2013";
        ["arrays do not support the frac modifier"], "E2014";
        ["array/list parameters do not support the frac modifier"], "E2015";
        ["'array'/'list' keywords removed"], "E2018";
        ["'*' must follow a type"], "E2019";
        ["'[]T' / '[T;N]'"], "E2020";
        ["panic requires a message argument"], "E2021";
        ["duplicate sep parameter in output"], "E2022";
        ["duplicate end parameter in output"], "E2023";
        ["struct field syntax: "], "E2024";
        ["use file name must end with .zfy"], "E2025";
        ["extern supports only "], "E2031";
        ["expected \"C\" after extern"], "E2031";
        ["semicolon is only allowed in for headers"], "E2027";
        ["parameters do not support const"], "E2028";
        ["parameters do not support unred"], "E2029";
        ["array/list struct fields cannot have default values"], "E2030";
        ["expected ',' or ')' to end the parameter type list"], "E2032";
        ["expected ',' or ']"], "E2033";
        ["';' is not allowed between call arguments"], "E2034";
        ["expected ',' or ')' to end the argument list"], "E2035";
        ["expected ',' or ')' to end the panic arguments"], "E2036";
        ["unexpected end of input"], "E2037";
        ["named output parameters (sep/end) must come last"], "E2038";
        ["expected ',' or ')' to end the output argument list"], "E2039";
        ["input's delim parameter must come last"], "E2040";
        ["expected ',' or ')' to end the input target list"], "E2041";
      ] m
  | `Type ->
    code_of_tbl "E3000" [
      ["undefined generic struct: "], "E3169";
      [" type arguments, got "], "E3170";
      [" type parameters, got "], "E3170";
      ["cannot be a type argument"], "E3171";
      ["generic type argument must be a concrete type"], "E3171";
      ["cannot infer type argument"], "E3172";
      ["generic functions do not support ref parameters"], "E3173";
      ["main cannot be a generic function"], "E3174";
      ["duplicate type parameter in "], "E3175";
      (* w-014 容器与数值扩展（E3176~E3185） *)
      ["requires an i128/u128 context, got "], "E3176";
      ["requires an i128/u128 context)"], "E3176";
      [" overflows i128"], "E3177";
      [" overflows u128"], "E3177";
      ["sequence literal assignment"], "E3178";
      ["elements but target length is "], "E3179";
      ["elements but field length is "], "E3179";
      ["string index assignment requires a char"], "E3180";
      ["type-position array length must be an integer literal"], "E3181";
      ["nested array/list declarations do not support initializers"], "E3182";
      ["field assignment target must be a struct array/list element"], "E3183";
      ["extern functions do not support array/list return types"], "E3184";
      ["for header declarations do not support arrays/lists"], "E3185";
      (* 文件 I/O（design_fileio.md，E3186~E3188） *)
      ["File cannot be a struct field"], "E3186";
      ["File cannot be an array/list element"], "E3186";
      ["File cannot be a type argument"], "E3186";
      ["File cannot be an array element"], "E3186";
      ["File parameters are move-only"], "E3187";
      ["invalid open mode"], "E3188";
      ["ref parameters support scalar/string/array/list types only"], "E3162";
      ["push target must be a list, not a fixed-length array"], "E3061";
      ["(extern conflicts with an existing function)"], "E3106";
      ["duplicate function definition: "], "E3105";
      ["dot access is only for structs"], "E3088";
      ["has no field "], "E3087";
      ["has duplicate field "], "E3100";
      [" field type cannot be itself"], "E3098";
      ["has circular nesting"], "E3154";
      ["conflicts with an existing type/function"], "E3103";
      ["extern function name "], "E3107";
      ["struct name "], "E3095";
      ["function name "], "E3104";
      ["is already a function and cannot also be a struct name"], "E3096";
      ["struct field array length must be a compile-time literal"], "E3097";
      ["T! cannot be a struct field"], "E3099";
      ["duplicate struct definition: "], "E3094";
      ["struct field augmented assignment supports only"], "E3028";
      ["does not support field assignment "], "E3029";
      ["dereferenced augmented assignment supports only"], "E3024";
      ["augmented/inc/dec target must be a pointer dereference"], "E3025";
      ["augmented/inc/dec target must be a variable or array/list element"], "E3026";
      ["augmented assignment target does not support indexing"], "E3022";
      ["augmented assignment target does not support slicing"], "E3023";
      ["string slices do not support augmented assignment"], "E3018";
      ["frac slices do not support augmented assignment"], "E3019";
      ["f16/f128 slices do not support augmented assignment"], "E3020";
      ["pointers do not support augmented assignment/inc/dec"], "E3021";
      ["string concatenation requires both sides to be string"], "E3045";
      ["cannot assign to field of constant "], "E3027";
      ["cannot modify elements of constant "], "E3015";
      ["cannot assign to constant "], "E3014";
      ["cannot input into constant "], "E3151";
      ["cannot reduce constant "], "E3122";
      ["cannot remove from constant "], "E3153";
      ["has been moved and cannot be written"], "E3016";
      ["has been moved and cannot be removed from"], "E3152";
      ["has been moved and cannot be used"], "E3013";
      ["has already been moved"], "E3038";
      ["undefined error code: ErrCode."], "E3135";
      ["undefined variable: "], "E3011";
      ["undefined function: "], "E3101";
      ["undefined type: "], "E3001";
      ["circular type inference constraint"], "E3004";
      ["type mismatch: expected "], "E3005";
      ["narrowing conversion from "], "E3155";
      ["cannot write through pointer-to-const "], "E3156";
      ["explicit copy conflicts with automatic move"], "E3157";
      ["is passed by ref, but the parameter is not declared ref"], "E3158";
      ["is ref, pass the argument with ref"], "E3159";
      ["cannot pass constant "], "E3160";
      ["has been moved and cannot be passed by ref"], "E3038";
      ["ref can only apply to a variable"], "E3161";
      ["ref parameters support scalar/string types only"], "E3162";
      ["extern parameters do not support ref"], "E3163";
      ["ref is only allowed on function parameters"], "E3164";
      ["ref parameters do not support the frac modifier"], "E3165";
      ["function pointer calls do not support ref arguments"], "E3166";
      ["does not support ref arguments"], "E3167";
      ["ref parameters support scalar/string types only (got "], "E3162";
      ["move assignment requires an aggregate variable source"], "E3168";
      ["unsupported cast: "], "E3008";
      ["cannot omit an initializer"], "E3009";
      ["cannot convert to string"], "E3007";
      ["frac does not support modulo"], "E3117";
      ["mismatched frac element types"], "E3114";
      ["cannot be mixed with "], "E3115";
      ["cannot initialize "], "E3118";
      ["frac parameter does not support element type"], "E3120";
      ["frac return type does not support element type"], "E3121";
      ["frac does not support element type"], "E3113";
      ["bool can only be initialized with"], "E3146";
      ["array lengths differ"], "E3144";
      ["pointer arithmetic is only allowed inside an unsafe block"], "E3047";
      ["cannot add two pointers"], "E3048";
      ["cannot add an integer to a pointer"], "E3049";
      ["cannot subtract a pointer from an integer"], "E3052";
      ["pointer comparison requires both sides to be pointers or null"], "E3053";
      ["unsupported pointer operation: "], "E3054";
      ["comparison requires numeric types"], "E3055";
      ["arithmetic requires numeric types"], "E3056";
      ["unary minus requires a numeric type"], "E3057";
      ["panic_handler signature"], "E3059";
      ["panic_handler expects"], "E3058";
      ["push target must be a list, got "], "E3061";
      ["push takes two arguments"], "E3062";
      ["sizeof/alignof does not support type "], "E3063";
      ["expects a type name argument"], "E3064";
      [" pointer expects "], "E3065";
      ["function pointer calls do not support move arguments"], "E3066";
      ["function pointer calls do not support named argument "], "E3067";
      ["function calls do not support named argument "], "E3068";
      ["unsupported callee expression"], "E3069";
      ["does not support index access"], "E3070";
      ["slicing is only for string/array/list"], "E3071";
      ["'&' can only take the address of"], "E3072";
      ["cannot take the address of a void value"], "E3073";
      ["dereference requires a pointer type"], "E3074";
      ["block expressions are not supported here"], "E3149";
      ["left side of ?? must be a fallible value"], "E3136";
      ["??-block form (a ?? indented block) is only allowed"], "E3138";
      ["??-block declaration type must be the element type"], "E3137";
      ["??-block assignment target must be a variable"], "E3139";
      ["? propagation requires the enclosing function to return T! (current: void)"], "E3141";
      ["? propagation requires the enclosing function to return"], "E3142";
      ["? left side must be a fallible value"], "E3140";
      ["cannot move constant "], "E3036";
      ["cannot move global variable "], "E3037";
      ["move supports only string/array/list arguments"], "E3039";
      ["move can only apply to a local variable"], "E3150";
      ["does not support field access "], "E3089";
      ["struct constructor does not support move arguments"], "E3091";
      ([" fields, got "; " positional arguments"], "E3092");
      ["initialized twice"], "E3093";
      ["an integer type is required"], "E3075";
      ["struct field array length must be a compile-time literal"], "E3097";
      (["builtin "; " does not support move arguments"], "E3145");
      ["expects a string for its "], "E3076";
      ["does not accept type "], "E3077";
      ["length expects string/array/list"], "E3078";
      ["'s count must be > 0"], "E3079";
      ["must be char or string, got "], "E3083";
      ["replace requires (s, a, b, rep)"], "E3083";
      ["string element concatenation requires string or char"], "E3077";
      ["string concatenation requires string or char"], "E3077";
      ["string elements only support += "], "E3077";
      ["dereferenced string only supports += "], "E3035";
      ["slice step must be >= 1"; "slice step must not be 0"], "E3097";
      ["split does not accept '\\000'"], "E3086";
      ["prec does not support type "], "E3080";
      ["prec's length parameter must be"], "E3081";
      ["malformed argument list for builtin "], "E3082";
      ["a char is required ("], "E3083";
      ["input target must be string/integer/float/bool/char"], "E3084";
      ["output does not support argument type: "], "E3085";
      ["input's delim must be char or string"], "E3086";
      ["statement discards a value of type "], "E3189";
      (* v3.3.1 浮点字面量混合修复（E3190） *)
      ["floating-point literal cannot be used as "], "E3190";
      ["floating-point and integer operands cannot be mixed"], "E3190";
      ["strings do not support index assignment"], "E3017";
      ["dereference assignment supports only scalar/pointer types"], "E3031";
      ["does not support index assignment"], "E3032";
      ["index-assignment target must be"], "E3033";
      ["assignment target must be a pointer dereference"], "E3034";
      ["unsupported assignment target"], "E3035";
      ["frac arrays/lists are not yet supported"], "E3119";
      ["T! cannot be an array/list element"], "E3127";
      ["array length must be an integer"], "E3128";
      ["array length must be a compile-time constant"], "E3129";
      ["lists take no length"], "E3130";
      ["arrays require a length"], "E3131";
      [" initial values exceed array length "], "E3132";
      ["frac/unred does not support ??-block initialization"], "E3125";
      ["remove only works on arrays/lists"], "E3147";
      ["remove's first argument must be an array/list variable"], "E3147";
      ["array parameter length must be a literal"], "E3133";
      ["reduce's first argument must be a frac-typed local variable"], "E3124";
      ["reduce requires a frac-typed variable"], "E3123";
      ["top-level const does not support frac/unred"], "E3040";
      ["duplicate top-level constant: "], "E3041";
      ["top-level const currently supports only integer types"], "E3042";
      ["duplicate top-level variable: "], "E3043";
      ["but may not return a value"], "E3111";
      ["extern parameters do not support arrays/lists"], "E3108";
      ["extern parameters do not support T!"], "E3109";
      ["extern functions do not support a T! return type"], "E3110";
      ["missing main()"], "E3148";
      ["fallible value used directly as a plain value"], "E3010";
      ([" expects "; " arguments, got "], "E3102");
    ]
  | `Mir ->
    code_of_tbl "E4000" [
      ["unsupported frac operation"], "E4004";
      ["unsupported field-access target"], "E4005";
      ["unsupported address-of target"], "E4006";
      ["element address-of target must be a variable"], "E4007";
      ["unsupported assignment target"], "E4008";
      ["reduce target must be a frac-typed local variable"], "E4009";
      ["break outside a loop"], "E4010";
      ["continue outside a loop"], "E4011";
    ]
  | `Llvm ->
    code_of_tbl "E4000" [
      ["main's return type must be void, i32 or i64"], "E4012";
      ["unsupported float width f"], "E4013";
      ["error value element type does not support 128-bit width"], "E4002";
      ["invalid error value element type"], "E4003";
      ["unresolved type variable"], "E4014";
      ["cannot determine type size"], "E4015";
      ["undefined struct "], "E4015";
      ["unsupported array/list element type"], "E4016";
      ["pointer constant must be null"], "E4017";
      ["must be used as a pointer"], "E4018";
      ["undefined local variable "], "E4019";
      ["undefined variable "], "E4019";
      ["type cannot be stored as an array/list element"], "E4020";
      ["expected aggregate local: "], "E4021";
      ["aggregate type does not support arithmetic"], "E4022";
      ["unsupported pointer operation"], "E4023";
      ["float type does not support modulo"], "E4024";
      ["bool type does not support this operation"], "E4025";
      ["aggregate type does not support unary operations"], "E4026";
      ["type cannot convert to string"], "E4027";
      ["aggregate type does not support cast"], "E4028";
      ["unsupported conversion "], "E4029";
      ["output does not support this argument type"], "E4030";
      ["input does not support this error-value element type"], "E4031";
      ["input does not support this target type"], "E4031";
      ["invalid prec length parameter type"], "E4032";
      ["aggregate return value must be captured"], "E4033";
      ["non-void return value must be used"], "E4034";
      ["field access target is not a struct"], "E4035";
      ["invalid root type for field access"], "E4035";
      ["has no field index "], "E4036";
      ["does not match value type "], "E4037";
      ["invalid move target slot type "], "E4038";
      ["fail's code must be i32"], "E4039";
      ["MErrOk type error"], "E4040";
      ["MErrValue type error"], "E4040";
      ["panic's code must be i32"], "E4041";
      ["norm type error"], "E4042";
      ["reduce type error"], "E4042";
      ["unsupported augmented-assignment operation on slices"], "E4043";
      ["unsupported element type for slice augmented assignment"], "E4043";
      ["undefined temp "], "E4044";
      ["MEmptySeq type is not an array/list"], "E4045";
      ["address-of target is undefined: "], "E4046";
      ["dereference-assignment type mismatch"], "E4047";
      ["invalid root type for field address"], "E4048";
      ["invalid root type for element address"], "E4048";
      ["freed temp type is not a struct"], "E4049";
      ["type cannot be a return default value"], "E4050";
    ]
  | `Driver ->
    code_of_tbl "E5000" [
      ["use: file not found: "], "E5001";
      ["import conflict: "], "E5002";
      ["nested modules are not allowed"], "E5003";
      ["cannot read source file: "], "E5005";
      ["circular module dependency: "], "E5006";
      ["is not visible"], "E5007";
      ["unresolved path: "], "E5008";
      ["module file not found: "], "E5008";
      ["name conflict: "], "E5009";
    ]

let read_lines file =
  let ic = open_in_bin file in
  let n = in_channel_length ic in
  let s = really_input_string ic n in
  close_in ic;
  Array.of_list (String.split_on_char '\n' s)

let trim_cr (s : string) =
  if String.length s > 0 && s.[String.length s - 1] = '\r'
  then String.sub s 0 (String.length s - 1) else s

(* 估算错误处 token 显示宽度：标识符/数字取连续单词字符，字符串字面量
   取到闭合引号，其他（运算符/标点）为 1 —— 多字符 token 用等长 ^^^^ *)
let caret_width lines line col =
  let l = line - 1 in
  if l < 0 || l >= Array.length lines then 1
  else
    let s = trim_cr lines.(l) in
    let c = col - 1 in
    if c < 0 || c >= String.length s then 1
    else
      let is_word ch =
        (ch >= 'a' && ch <= 'z') || (ch >= 'A' && ch <= 'Z') ||
        (ch >= '0' && ch <= '9') || ch = '_'
      in
      let ch = s.[c] in
      if ch = '"' then
        let rec go i =
          if i >= String.length s then String.length s - c
          else if s.[i] = '\\' then go (i + 2)
          else if s.[i] = '"' then i - c + 1
          else go (i + 1)
        in
        max 1 (go (c + 1))
      else if is_word ch then begin
        let j = ref c in
        while !j < String.length s && is_word s.[!j] do incr j done;
        !j - c
      end
      else 1

(* 按 new.md 格式输出错误块：全局递增序号 [N] + 错误码：
   zfy:error[N][EXXX] in <line> of <文件名> because (原因)
   <错误行及上下各 2 行，共 5 行>
        ^
   含自动修复项时，顶部先罗列将自动修复的错误序号 *)
(* 报告序号的公共排序：按 (文件, 行, 列)——报告与交互式修复选择
   都以此顺序编号 *)
let sort_errs (errs : zerr list) : zerr list =
  List.stable_sort
    (fun a b ->
       compare (a.zpos.file, a.zpos.line, a.zpos.col)
         (b.zpos.file, b.zpos.line, b.zpos.col))
    errs

let report_err errs =
  let sorted = sort_errs errs in
  let fix_idx =
    sorted
    |> List.mapi (fun i (e : zerr) -> (i + 1, e))
    |> List.filter (fun (_, e) -> e.fix <> FixNone)
    |> List.map fst in
  if fix_idx <> [] then
    Printf.eprintf "zfy: auto-fixable: error(s) %s will be repaired automatically\n"
      (String.concat " "
         (List.map (fun i -> "[" ^ string_of_int i ^ "]") fix_idx));
  (* 错误数上限（n4）：超长程序失败时防终端爆刷；超出部分汇总一行 *)
  let max_show = 30 in
  let total = List.length sorted in
  List.iteri
    (fun i (e : zerr) ->
      if i >= max_show then begin
        if i = max_show then
          Printf.eprintf "zfy: ... and %d more errors (suppressed)\n" (total - max_show)
      end
      else begin
      Printf.eprintf "zfy:error[%d][%s] in %d of %s because (%s)\n"
        (i + 1) e.code e.zpos.line e.zpos.file e.zmsg;
      (try
         let lines = read_lines e.zpos.file in
         let n = Array.length lines in
         for l = max 1 (e.zpos.line - 2) to min n (e.zpos.line + 2) do
           Printf.eprintf "%s\n" (trim_cr lines.(l - 1))
         done;
         let w = caret_width lines e.zpos.line e.zpos.col in
         Printf.eprintf "%s%s\n"
           (String.make (max 0 (e.zpos.col - 1)) ' ') (String.make w '^')
       with _ -> ())
      end)
    sorted

let read_file path =
  let ic = open_in_bin path in
  let n = in_channel_length ic in
  let s = really_input_string ic n in
  close_in ic;
  s

(* ---------- use 多文件展开 ----------
 * use 文件名.zfy [import 模块名] [as 别名]
 *  - 无 /：从当前目录（导入文件所在目录）找；带 /：相对路径（./ 当前、../ 上一级）
 *  - 导入文件的函数以内联方式并入，改名 ns.fn；文件内模块 m 的函数改名 ns.m.fn
 *    （ns = 别名，缺省为文件名去 .zfy 后缀）
 *  - import 模块名：只导入该模块的函数（仍以 ns.模块名.fn 命名）
 *  - 导入文件体内的同名函数调用随映射改名；按归一化路径去重防环 *)

let expand_uses (main : program) (main_dir : string)
    (perrs : (pos * string) list ref) : program =
  Hashtbl.reset Typeck.method_tbl;   (* 方法表：每次编译重置 *)
  let names : (string, unit) Hashtbl.t = Hashtbl.create 16 in
  let loaded : (string, unit) Hashtbl.t = Hashtbl.create 8 in
  let out : item list ref = ref [] in
  let reg name p =
    if Hashtbl.mem names name then
      raise (CompileError (Some p, Printf.sprintf "import conflict: %s already exists" name));
    Hashtbl.replace names name ()
  in
  (* 改写函数体：m 为 本文件裸函数名 -> 全局名 映射 *)
  let rec rw_expr m (e : expr) : expr =
    match e with
    | ECall (EVar (n, np), args, p) ->
      let args =
        List.map
          (function
            | CPos e -> CPos (rw_expr m e)
            | CMove e -> CMove (rw_expr m e)
            | CCopy e -> CCopy (rw_expr m e)
            | CRef e -> CRef (rw_expr m e)
            | CNamed (s, e) -> CNamed (s, rw_expr m e))
          args
      in
      let callee =
        match List.assoc_opt n m with
        | Some n' -> EVar (n', np)
        | None -> EVar (n, np)
      in
      ECall (callee, args, p)
    | EBin (op, l, r, p) -> EBin (op, rw_expr m l, rw_expr m r, p)
    | EUn (op, e1, p) -> EUn (op, rw_expr m e1, p)
    | EIndex (b, i, p) -> EIndex (rw_expr m b, rw_expr m i, p)
    | ESlice (b, a, bb, st, p) ->
      ESlice (rw_expr m b, rw_expr m a, rw_expr m bb, Option.map (rw_expr m) st, p)
    | ECast (e1, t, p) -> ECast (rw_expr m e1, t, p)
    | ERemove (b, i, p) -> ERemove (rw_expr m b, rw_expr m i, p)
    | EBlock (bl, p) -> EBlock (rw_block m bl, p)
    | e -> e
  and rw_block m bl = List.map (rw_stmt m) bl
  and rw_stmt m (s : stmt) : stmt =
    match s with
    | SDecl (a, b, c, n, t, e, p) -> SDecl (a, b, c, n, t, Option.map (rw_expr m) e, p)
    | SSeqDecl (a, f2, u2, n, t, len, isl, inits, p) ->
      SSeqDecl (a, f2, u2, n, t, Option.map (rw_expr m) len, isl,
                List.map (rw_expr m) inits, p)
    | SDeclList ss -> SDeclList (List.map (rw_stmt m) ss)
    | SAssign (l, r, p) -> SAssign (rw_expr m l, rw_expr m r, p)
    | SAug (op, l, r, p) -> SAug (op, rw_expr m l, rw_expr m r, p)
    | SInc (e, p) -> SInc (rw_expr m e, p)
    | SDec (e, p) -> SDec (rw_expr m e, p)
    | SExpr e -> SExpr (rw_expr m e)
    | SReturn (e, p) -> SReturn (Option.map (rw_expr m) e, p)
    | SIf (c, a, b, p) ->
      SIf (rw_expr m c, rw_block m a, Option.map (rw_block m) b, p)
    | SWhile (c, b, p) -> SWhile (rw_expr m c, rw_block m b, p)
    | SFor (inits, c, ups, b, p) ->
      SFor
        (List.map
           (function
             | FIDecl (a, f2, u2, n, t, e, p) ->
               FIDecl (a, f2, u2, n, t, Option.map (rw_expr m) e, p)
             | FIExpr (e, p) -> FIExpr (rw_expr m e, p))
           inits,
         rw_expr m c,
         List.map
           (function
             | FUAssign (l, r, p) -> FUAssign (rw_expr m l, rw_expr m r, p)
             | FUOp (op, l, r, p) -> FUOp (op, rw_expr m l, rw_expr m r, p)
             | FUInc (e, p) -> FUInc (rw_expr m e, p)
             | FUDec (e, p) -> FUDec (rw_expr m e, p))
           ups,
         rw_block m b,
         p)
    | SOutput (es, sep, endd, p) ->
      SOutput (List.map (rw_expr m) es, Option.map (rw_expr m) sep,
               Option.map (rw_expr m) endd, p)
    | SInput (ts, d, p) -> SInput (ts, Option.map (rw_expr m) d, p)
    | SReduce (a, b, c, p) -> SReduce (rw_expr m a, rw_expr m b, rw_expr m c, p)
    | s -> s
  in
  (* 把一个文件的函数并入全局：ns 前缀；import 为 None 导入全部，Some m 只导入模块 m *)
  let add_items ns (items0 : item list) (import : string option) =
    (* legacy 子文件容错：剥 pub；新语法项（IUseP/IModFile）报错（应走
       模块系统）；legacy 子文件内联 IMod 走原 ns.m.fn 逻辑 *)
    let rec strip its =
      List.map
        (function
          | IPub (x, _) -> x
          | IUseP { pos; _ } | IModFile (_, pos) ->
            raise (CompileError (Some pos, "module system syntax (use a::b / mod name;) is not allowed in a legacy use file"))
          | IMod (n, its2, p) -> IMod (n, strip its2, p)
          | x -> x)
        its
    in
    let items = strip items0 in
    let own : (string * string) list ref = ref [] in
    let collect its =
      let rec go_mod mname its2 =
        List.iter
          (function
            | IFn f -> own := (f.name, ns ^ mname ^ "." ^ f.name) :: !own
            | IMod _ | IUse _ | IUseP _ | IModFile _ | IPub _ | IDecl _
            | IStruct _ | IEnum _ | IIf _ | IExtern _ | ITypeAlias _ -> ())
          its2
      in
      List.iter
        (function
          | IFn f -> own := (f.name, ns ^ f.name) :: !own
          | IMod (m, its2, _) -> go_mod m its2
          | IUse _ | IUseP _ | IModFile _ | IPub _ | IDecl _ | IStruct _ | IEnum _ | IIf _
          | IExtern _ | ITypeAlias _ -> ())
        its
    in
    collect items;
    let m = !own in
    let emit_fn name fpos fparams fret fbody =
      reg name fpos;
      out := IFn { name; params = fparams; ret = fret; rfrac = false;
                  runred = false; body = rw_block m fbody; pos = fpos;
                  tparams = [] } :: !out
    in
    let rec go_mod ns_mod mname its2 =
      List.iter
        (function
          | IFn f -> emit_fn (ns_mod ^ f.name) f.pos f.params f.ret f.body
          | IMod (_, _, p) ->
            raise (CompileError (Some p, "nested modules are not allowed"))
          | IDecl _ | IUse _ | IUseP _ | IModFile _ | IPub _ | IStruct _ | IEnum _ | IIf _
          | IExtern _ | ITypeAlias _ -> ())
        its2
    in
    List.iter
      (function
        | IUse _ -> ()
        | IDecl (d, dp) ->
          (* 子文件顶层 const 原样并入（全局编译期常量） *)
          (match d with
           | SDecl (_, _, _, n, _, _, p) -> reg n p
           | _ -> reg "_" dp);
          out := IDecl (d, dp) :: !out
        | IMod (mname, its2, p) ->
          let want =
            match import with
            | Some im when im = mname -> true
            | Some _ -> false
            | None -> true
          in
          if want then go_mod (ns ^ mname ^ ".") mname its2
          else ignore p
        | IFn f ->
          (match import with
           | Some _ -> ()      (* import 模块名时不导入文件顶层函数 *)
           | None ->
             (match List.assoc_opt f.name m with
              | Some n -> emit_fn n f.pos f.params f.ret f.body
              | None -> emit_fn (ns ^ f.name) f.pos f.params f.ret f.body))
        | IStruct ({ name; methods; _ } as s) ->
          (* struct 原样并入（类型名无命名空间；重名由 typeck 统一报错）。
             v3.2：struct 方法脱糖为顶层函数 <S>__<m>（ns 前缀随文件），
             隐式首参 self = ref let <S>；方法表供调用点分派 *)
          (match methods with
           | [] -> out := IStruct s :: !out
           | _ ->
             out := IStruct { s with methods = [] } :: !out;
             List.iter
               (fun mth ->
                 let gname = ns ^ name ^ "__" ^ mth.mname in
                 Hashtbl.replace Typeck.method_tbl (name, mth.mname) gname;
                 let selfp =
                   { pname = "self"; pty = TNamed (name, mth.mpos); pfrac = false;
                     pseq = PScalar; pconst = false; punred = false; pref = true;
                     ppos = mth.mpos }
                 in
                 (* 方法体裸调用映射：兄弟方法名 → 全局名（自由函数沿用 m） *)
                 let mm =
                   m @ List.map
                       (fun x -> (x.mname, ns ^ name ^ "__" ^ x.mname))
                       methods
                 in
                 reg gname mth.mpos;
                 out := IFn { name = gname; params = selfp :: mth.mparams;
                              ret = mth.mret; rfrac = mth.mrfrac; runred = false;
                              body = rw_block mm mth.mbody; pos = mth.mpos;
                              tparams = [] } :: !out)
               methods)
        | IExtern it ->
          (* extern "C" 原样并入（符号链接期解析；重名由 typeck 报错） *)
          out := IExtern it :: !out
        | ITypeAlias it ->
          (* type 别名原样并入（重名由 typeck 报错） *)
          out := ITypeAlias it :: !out)
      items
  in
  let rec load_use base_dir (upath, uimport, ualias, upos) =
    let path =
      if Filename.is_relative upath then Filename.concat base_dir upath
      else upath
    in
    if not (Sys.file_exists path) then
      raise (CompileError (Some upos, Printf.sprintf "use: file not found: %s" upath));
    let norm = String.lowercase_ascii (Filename.concat (Sys.getcwd ()) path) in
    if not (Hashtbl.mem loaded norm) then begin
      Hashtbl.replace loaded norm ();
      (* 子文件词法/语法错误：记录后跳过该文件（多错误收集） *)
      match
        (try
           let src = read_file path in
           let sub_p = Parser.make (Lexer.tokenize ~file:path src) in
           let sub = Parser.parse_program sub_p in
           List.iter (fun x -> perrs := x :: !perrs) sub_p.Parser.errs;
           Some sub
         with
         | Lexer.LexError (p, m) -> perrs := (p, m) :: !perrs; None
         | Parser.ParseError (p, m) -> perrs := (p, m) :: !perrs; None)
      with
      | None -> ()
      | Some sub ->
      let base =
        match ualias with
        | Some a -> a ^ "."
        | None -> (Filename.remove_extension (Filename.basename upath)) ^ "."
      in
      let sub_dir = Filename.dirname path in
      go_file sub sub_dir;       (* 先展开子文件自己的 use *)
      add_items base sub uimport
    end
  and go_file (items : item list) base_dir =
    List.iter
      (function
        | IUse u -> load_use base_dir (u.path, u.import, u.alias, u.pos)
        | _ -> ())
      items
  in
  go_file main main_dir;
  (* 主文件其余项原样保留（剔除 IUse） *)
  List.iter
    (function
      | IUse _ | IUseP _ | IModFile _ | IPub _ -> ()
      | (IFn _ | IMod _ | IDecl _ | IStruct _ | IEnum _ | IIf _ | IExtern _ | ITypeAlias _) as it ->
        out := it :: !out)
    main;
  List.rev !out

(* v3.2：主文件 struct 方法脱糖——IStruct.methods → 顶层 IFn <S>__<m>，
   隐式首参 self = ref let <S>；方法表供调用点分派。
   导入文件的方法已在 expand_uses 内脱糖（带 ns 前缀），此处只处理主文件，
   故不重置方法表 *)
let desugar_main_methods (prog : program) : program =
  let out = ref [] in
  List.iter
    (fun it ->
      match it with
      | IStruct ({ name; methods; _ } as s) when methods <> [] ->
        out := IStruct { s with methods = [] } :: !out;
        List.iter
          (fun mth ->
            let gname = name ^ "__" ^ mth.mname in
            Hashtbl.replace Typeck.method_tbl (name, mth.mname) gname;
            let selfp =
              { pname = "self"; pty = TNamed (name, mth.mpos); pfrac = false;
                pseq = PScalar; pconst = false; punred = false; pref = true;
                ppos = mth.mpos }
            in
            out := IFn { name = gname; params = selfp :: mth.mparams;
                         ret = mth.mret; rfrac = mth.mrfrac; runred = false;
                         body = mth.mbody; pos = mth.mpos; tparams = [] } :: !out)
          methods
      | it -> out := it :: !out)
    prog;
  List.rev !out

(* 把改名类自动修复补丁应用到内存源码（同名行按列号降序应用防漂移；
   源文件不动，仅递归重跑用） *)
let patch_src (src : string) (fixes : zerr list) : string =
  let lines = Array.of_list (String.split_on_char '\n' src) in
  let ordered =
    List.filter (fun (e : zerr) -> e.fix <> FixNone) fixes
    |> List.stable_sort
      (fun a b -> compare (a.zpos.line, -a.zpos.col) (b.zpos.line, -b.zpos.col)) in
  List.iter
    (fun (e : zerr) ->
       match e.fix with
       | FixPatch (col, len, newtext)
         when e.zpos.line >= 1 && e.zpos.line <= Array.length lines ->
         let s = lines.(e.zpos.line - 1) in
         let c = col - 1 in
         if c >= 0 && c + len <= String.length s then
           lines.(e.zpos.line - 1) <-
             String.sub s 0 c ^ newtext ^
             String.sub s (c + len) (String.length s - c - len)
       | _ -> ())
    ordered;
  String.concat "\n" (Array.to_list lines)

(* 定位源码 token：返回 (长度, 原文)。用于 cast 插入类补丁——把
   `100` 包成 `cast(100, i8)`、把 `'A'`/char 变量包成 `cast(…, i32)`。
   char 字面量从开引号扫到闭引号（容忍转义），其余按标识符/数字字符扫描 *)
let token_at (src : string) (line : int) (col : int) : (int * string) option =
  let lines = String.split_on_char '\n' src in
  let nlines = List.length lines in
  if line < 1 || line > nlines then None
  else begin
    let s = List.nth lines (line - 1) in
    let n = String.length s in
    let c = col - 1 in
    if c < 0 || c >= n then None
    else if s.[c] = '\'' then begin
      let rec go i =
        if i >= n then None
        else if s.[i] = '\\' then (if i + 1 < n then go (i + 2) else None)
        else if s.[i] = '\'' then
          Some (i - c + 1, String.sub s c (i - c + 1))
        else go (i + 1)
      in
      (try go (c + 1) with _ -> None)
    end
    else begin
      let is_word ch =
        match ch with
        | 'a' .. 'z' | 'A' .. 'Z' | '0' .. '9' | '_' -> true
        | _ -> false
      in
      let j = ref c in
      while !j < n && is_word s.[!j] do incr j done;
      if !j = c then None else Some (!j - c, String.sub s c (!j - c))
    end
  end

(* 补丁重跑轮数上限（防改名建议彼此互改死循环） *)
let fix_round_cap = 4

(* 收集式管线：词法 → 语法 → use 展开 → 类型 → MIR → LLVM。
   各阶段错误收集进 errs（多错误一次报告），阶段间提前终止：
   词法有错不进语法，语法/use 有错不进类型检查，类型有错不进降码。
   自动修复：typeck 登记的唯一语义修复（undefined 改名/传统别名迁移/
   范围内字面量窄化插 cast/char→整数插 cast）从 errs 分流进 fixes。
   ~auto（非交互默认 true）：fixes 对内存源码打补丁静默重跑（≤4 轮），
   全部可修 → Ok（产出 exe）；~auto=false（交互模式）：fixes 原样随
   Error 返回，由 compile 报告全部错误后询问用户选择、写回源文件重跑 *)
let rec run_checked ?(src : string option) ?(acc : zerr list = [])
    ?(round = 0) ?(auto = true) (path : string) :
    (string * zerr list, zerr list) result =
  Hashtbl.reset Typeck.fix_pos;
  Typeck.autofixed := [];
  let errs = ref [] in
  let fixes = ref [] in
  let mk k p m fx =
    { code = code_of k m; zpos = p; zmsg = m; fix = fx } in
  let add k p m =
    (* file 为空的 pos（如 main 缺失的合成位置）归属主文件 *)
    let p = if p.file = "" then { p with file = path } else p in
    (* 改名类修复登记命中 → 分流进 fixes（不阻塞编译，打补丁重跑） *)
    (match Hashtbl.find_opt Typeck.fix_pos (p.file, p.line, p.col) with
     | Some (len, newtext) ->
       fixes := !fixes @ [ mk k p m (FixPatch (p.col, len, newtext)) ]
     | None ->
       (* 尾插：保持收集顺序（parse → use → typeck），输出即此顺序 *)
       errs := !errs @ [ mk k p m FixNone ])
  in
  let driver_add k po m =
    match po with
    | Some p -> add k p m
    | None -> add k { file = path; line = 0; col = 0 } m
  in
  let result =
    try
      let src = match src with Some s -> s | None -> read_file path in
      let toks =
        try Lexer.tokenize ~file:path src
        with Lexer.LexError (p, m) -> add `Lex p m; []
      in
      if !errs <> [] then None
      else
        let pp = Parser.make toks in
        let prog =
          try Ok (Parser.parse_program pp)
          with Parser.ParseError (p, m) -> add `Parse p m; Error ()
        in
        match prog with
        | Error () -> None
        | Ok prog ->
          (* 主文件 parse 恢复收集的错误先入列（头插列表反转成源码顺序） *)
          List.iter (fun (p, m) -> add `Parse p m) (List.rev pp.Parser.errs);
          let perrs = ref [] in
          (* 模块解析 pass（new2.md 第4条）：内联/文件 mod、pub、use 路径
             语法；旧 use file.zfy 保留原样交 expand_uses *)
          let rerrs = ref [] in
          let prog =
            match Resolve.resolve prog (Filename.dirname path) rerrs with
            | Some p -> Ok p
            | None -> Error ()
          in
          match prog with
          | Error () ->
            List.iter
              (fun (k, p, m) ->
                 let kk =
                   match k with
                   | Resolve.RLex -> `Lex
                   | Resolve.RParse -> `Parse
                   | Resolve.RDriver -> `Driver
                 in
                 add kk p m)
              (List.rev !rerrs);
            None
          | Ok prog ->
            let prog =
              try Ok (expand_uses prog (Filename.dirname path) perrs)
              with CompileError (po, m) -> driver_add `Driver po m; Error ()
            in
            match prog with
            | Error () -> None
            | Ok prog ->
            (* 子文件词法/语法错误（use 展开）；已恢复的 AST 继续做类型
               检查（报出更多错误，不在此终止） *)
            List.iter (fun (p, m) -> add `Parse p m) (List.rev !perrs);
            (* 主文件 struct 方法脱糖（v3.2；导入文件的已在 expand_uses 处理） *)
            let prog = desugar_main_methods prog in
            let hir = Typeck.check_program prog in
            List.iter (fun (p, m) -> add `Type p m)
              (List.rev !(Typeck.collected));
            if !errs <> [] then None
            else if !fixes <> [] then
              (* 有改名补丁：本轮不做代码生成——被修复语句经 recover 以
                 TError 毒型入 HIR，直接 codegen 会炸 E4014；先补丁重跑 *)
              None
            else Some (Llvmgen.gen_program (Mir.lower hir))
    with
    | Typeck.TypeError (p, m) ->
      (* main 缺失等 check_program 尾部错误：先收集中途已收集项再补本条 *)
      List.iter (fun (q, mm) -> add `Type q mm) (List.rev !(Typeck.collected));
      add `Type p m;
      None
    | Mir.MirError (p, m) -> add `Mir p m; None
    | Llvmgen.LlvmError (po, m) -> driver_add `Llvm po m; None
    | CompileError (po, m) -> driver_add `Driver po m; None
    | Sys_error m ->
      driver_add `Driver None ("cannot read source file: " ^ m); None
  in
  (* cast 插入类自动修复（coerce）：登记条目 → fix 条目。补丁 = 把源码
     token（字面量/char 变量）包成 `cast(token, 目标类型)`（交互模式写回
     源文件；非交互对内存源码打补丁）；同一位置可能因 coerce 多次调用
     重复登记，按 (行,列,文案) 去重。token 定位失败时兜底 FixSem（编译
     继续但无法写回源码） *)
  let casts =
    if !Typeck.autofixed = [] then []
    else
      let seen = Hashtbl.create 8 in
      let src0 = match src with Some s -> s | None -> read_file path in
      List.filter_map
        (fun (p, pp, m, ty) ->
           let p = if p.file = "" then { p with file = path } else p in
           let pp = if pp.file = "" then { pp with file = path } else pp in
           let key = (p.line, p.col, m) in
           if Hashtbl.mem seen key then None
           else begin
             Hashtbl.replace seen key ();
             match token_at src0 pp.line pp.col with
             | Some (len, tok) ->
               Some (mk `Type p m
                       (FixPatch (pp.col, len, "cast(" ^ tok ^ ", " ^ ty ^ ")")))
             | None -> Some (mk `Type p m FixSem)
           end)
        !(Typeck.autofixed)
  in
  let fx = !fixes @ casts in
  match result with
  | Some ll when !errs = [] && (auto || fx = []) -> Ok (ll, acc @ fx)
  | _ ->
    if !errs = [] && fx <> [] && auto && round < fix_round_cap
       && List.for_all (fun (e : zerr) -> e.fix <> FixNone && e.zpos.file = path) fx
       && List.exists (fun (e : zerr) -> (match e.fix with FixPatch _ -> true | _ -> false)) fx
       then begin
      (* 非交互：有可修复错误（且无残余硬错误）→ 打内存源码补丁重跑 *)
      let src0 = match src with Some s -> s | None -> read_file path in
      let patched = patch_src src0 fx in
      run_checked ~src:patched ~acc:(acc @ fx) ~round:(round + 1) ~auto path
    end
    else Error (acc @ fx @ !errs)

let find_clang () =
  match Sys.getenv_opt "ZFY_CLANG" with
  | Some s when s <> "" -> s
  | _ -> if Sys.win32 then "D:/LLVM/bin/clang.exe" else "clang"

(* 运行时 C 源文件：优先 ZFY_RUNTIME，其次编译器目录/runtime/runtime.c *)
let find_runtime () =
  match Sys.getenv_opt "ZFY_RUNTIME" with
  | Some s when Sys.file_exists s -> Some s
  | _ ->
    let exe_dir = Filename.dirname Sys.executable_name in
    let cands =
      [ Filename.concat exe_dir "runtime.c";
        Filename.concat exe_dir (Filename.concat "runtime" "runtime.c");
        Filename.concat (Filename.concat exe_dir "..") (Filename.concat "runtime" "runtime.c") ]
    in
    let rec go = function
      | [] -> None
      | c :: rest -> if Sys.file_exists c then Some c else go rest
    in
    go cands

(* stdin 是否为交互终端（Unix.isatty；探测失败按非交互处理） *)
let stdin_tty () : bool =
  try Unix.isatty (Unix.descr_of_in_channel stdin) with _ -> false

(* 修复模式：交互终端或 ZFY_FIX=ask → 询问用户选择；非交互默认 / 
   ZFY_FIX=all → 自动修复全部（内存，源文件不动）。ZFY_FIX 供脚本/
   测试强制指定 *)
let fix_mode () =
  match Option.map String.trim (Sys.getenv_opt "ZFY_FIX") with
  | Some "ask" -> `Ask
  | Some "all" -> `All
  | _ -> if stdin_tty () then `Ask else `All

(* 拆分用户输入：空格/逗号/Tab 均为分隔符（两种都支持，可混用） *)
let split_selection (line : string) : string list =
  let is_sep c = c = ' ' || c = ',' || c = '\t' || c = '\r' in
  let n = String.length line in
  let toks = ref [] in
  let i = ref 0 in
  while !i < n do
    if is_sep line.[!i] then incr i
    else begin
      let j = ref !i in
      while !j < n && not (is_sep line.[!j]) do incr j done;
      toks := String.sub line !i (!j - !i) :: !toks;
      i := !j
    end
  done;
  List.rev !toks

(* 交互询问：报告序号即选择序号（与 sort_errs 排序一致）。空输入=全部，
   q/n/no=不修；非法/越界序号忽略并提示；选中不可修序号提示后跳过 *)
let prompt_selection (errs : zerr list) (fixable : zerr list) : zerr list =
  let arr = Array.of_list errs in
  let total = Array.length arr in
  Printf.eprintf
    "zfy: enter error number(s) to auto-fix (space/comma separated; Enter = all, q = none): "
  ;
  flush stderr;
  let line = (try input_line stdin with End_of_file -> "q") in
  let line = String.trim line in
  if line = "" then fixable
  else if line = "q" || line = "n" || line = "no" then []
  else begin
    let toks = split_selection line in
    let nums =
      List.filter_map
        (fun t ->
           match int_of_string_opt t with
           | Some k when k >= 1 && k <= total -> Some k
           | _ ->
             Printf.eprintf "zfy: ignoring invalid selection '%s'\n" t;
             None)
        toks
    in
    List.iter
      (fun k ->
         if arr.(k - 1).fix = FixNone then
           Printf.eprintf "zfy: error [%d] is not auto-fixable, skipped\n" k)
      nums;
    List.filter
      (fun (e : zerr) -> e.fix <> FixNone)
      (List.map (fun k -> arr.(k - 1)) nums)
  end

(* 编译到可执行文件，返回可执行文件路径。
   错误处理（含自动修复主循环）：
   1. 报告全部错误（顶部罗列可自动修复的序号）；
   2. 非交互 → 自动修复全部（内存补丁，源文件不动）；交互 → 询问用户
      要修哪些（空格/逗号分隔序号），选中项直接写回源文件；
   3. 重跑编译（≤4 轮），残余错误再次报告。
   选了修复 → 产出 exe 时随报告打印修复明细；不修/不可全修失败 → exit 1 *)
let compile path : string =
  let mode = fix_mode () in
  let rec go round =
    match run_checked ~auto:(mode = `All) ~round path with
    | Ok (ll, fixes) -> (ll, fixes)
    | Error errs ->
      if round >= fix_round_cap then (report_err errs; exit 1);
      let errs = sort_errs errs in
      let fixable =
        List.filter (fun (e : zerr) -> e.fix <> FixNone) errs in
      if fixable = [] then (report_err errs; exit 1);
      (* 全部错误照常报告，顶部罗列可自动修复的序号 *)
      report_err errs;
      let sel =
        match mode with
        | `All -> fixable
        | `Ask -> prompt_selection errs fixable
      in
      if sel = [] then exit 1;
      (* 按文件分组，把补丁直接写回源文件后重跑 *)
      let files =
        List.sort_uniq compare
          (List.map (fun (e : zerr) -> e.zpos.file) sel) in
      List.iter
        (fun f ->
           let fs =
             List.filter (fun (e : zerr) -> e.zpos.file = f) sel in
           let patched = patch_src (read_file f) fs in
           let oc = open_out f in
           output_string oc patched;
           close_out oc)
        files;
      Printf.eprintf "zfy: patched %d error(s) into source file(s), recompiling\n"
        (List.length sel);
      let ll, _ = go (round + 1) in
      (ll, sel)
  in
  let ll, fixes = go 0 in
  (* 全部错误被自动修复（仍产出 exe）：报告修复明细（全局序号与报告一致） *)
  if fixes <> [] then begin
    Printf.eprintf "zfy: note: auto-fixed %d error(s):\n" (List.length fixes);
    List.iteri
      (fun i (e : zerr) ->
         Printf.eprintf "zfy:   [%d][%s] in %d of %s because (%s)\n"
           (i + 1) e.code e.zpos.line e.zpos.file e.zmsg)
      fixes
  end;
  let base = Filename.remove_extension path in
  let ll_path = base ^ ".ll" in
  let oc = open_out ll_path in
  output_string oc ll;
  close_out oc;
  let exe = if Sys.win32 then base ^ ".exe" else base in
  let clang = find_clang () in
  let target =
    if Sys.win32 then "--target=x86_64-w64-mingw32 -B D:/mingw64/bin "
    else ""
  in
  let runtime =
    match find_runtime () with
    | Some rt -> Printf.sprintf "%s " rt
    | None -> ""
  in
  (* GUI 核心层（v3.3.7）依赖 GDI/User32；非 Windows 无 GUI 层无需链接 *)
  let libs = if Sys.win32 then "-lgdi32 -luser32 " else "" in
  let cmd =
    (* cmd.exe 对整串引号处理怪异：路径无空格时不加引号 *)
    if String.contains clang ' ' then
      Printf.sprintf "\"%s\" %s\"%s\" %s-O2 %s-o \"%s\"" clang target ll_path runtime libs exe
  else
    (* -O2：链接时对 LLVM IR 做 mem2reg/内联等优化（否则 alloca 槽全走内存，性能差数倍） *)
    Printf.sprintf "%s %s%s %s-O2 %s-o %s" clang target ll_path runtime libs exe
  in
  let code = Sys.command cmd in
  if code <> 0 then begin
    Printf.eprintf "zfy:error[E5004] in 0 of %s because (link failed (clang exit code %d))\n" path code;
    exit 1
  end;
  exe
