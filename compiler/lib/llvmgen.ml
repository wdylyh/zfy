(* LLVM IR 文本生成（自 MIR） *)
open Tokens
open Hir
open Mir

exception LlvmError of pos option * string

let lerr p fmt = Printf.ksprintf (fun s -> raise (LlvmError (p, s))) fmt

(* ---------- 类型 ---------- *)

let rec ll_ty (t : zty) : string =
  match t with
  | TInt n | TUint n -> Printf.sprintf "i%d" n
  | TFloat 16 -> "half"
  | TFloat 32 -> "float"
  | TFloat 64 -> "double"
  | TFloat 128 -> "x86_fp80"   (* MinGW long double：80 位扩展精度（fp128 软浮点在 MinGW 下不可用） *)
  | TFloat n -> lerr None "不支持的浮点宽度 f%d" n
  | TBool -> "i1"
  | TChar -> "i8"
  | TString -> "ptr"
  | TVoid -> "void"
  | TFrac e -> Printf.sprintf "%%frac.%s" (Hir.suffix_of e)
  | TArray _ | TList _ -> "ptr"      (* 槽内是指向 zfy_seq 的指针 *)
  | TVar _ -> lerr None "未求解的类型变量"

(* 只有 frac 是真正的 LLVM 聚合；数组/列表槽是 ptr 标量 *)
let is_agg = function TFrac _ -> true | _ -> false

let width_of (t : zty) : int =
  match t with
  | TInt n | TUint n -> n
  | TBool -> 1
  | TChar -> 8
  | _ -> 64

let float_width (t : zty) : int =
  match t with TFloat n -> n | _ -> 0

(* ---------- 模块上下文 ---------- *)

type gctx = {
  mbuf : Buffer.t;                 (* 模块级定义（全局常量等） *)
  mutable nstr : int;
  globals : (string, unit) Hashtbl.t;  (* 顶层变量槽（'@' 前缀）去重表 *)
}

let rec size_of g (t : zty) : int =
  match t with
  | TInt n | TUint n -> n / 8
  | TFloat n -> n / 8
  | TBool | TChar -> 1
  | TString -> 8
  | TFrac e -> 2 * size_of g e
  | TArray _ | TList _ -> 8        (* 槽：seq 指针 *)
  | TVoid | TVar _ -> lerr None "无法确定类型大小"

let string_escape (s : string) : string * int =
  let b = Buffer.create (String.length s + 8) in
  String.iter
    (fun c ->
      let n = Char.code c in
      if n >= 32 && n <= 126 && c <> '"' && c <> '\\' then Buffer.add_char b c
      else Buffer.add_string b (Printf.sprintf "\\%02X" n))
    s;
  (Buffer.contents b, String.length s + 1)  (* +1 为 NUL *)

let intern_string g (s : string) : string =
  g.nstr <- g.nstr + 1;
  let name = Printf.sprintf "@.str%d" g.nstr in
  let (esc, len) = string_escape s in
  Buffer.add_string g.mbuf
    (Printf.sprintf "%s = private unnamed_addr constant [%d x i8] c\"%s\\00\"\n"
       name len esc);
  name

(* ---------- 浮点常量（half / fp128 用十六进制位模式） ---------- *)

(* double -> IEEE half（binary16）位模式 *)
let double_to_half_bits (f : float) : int =
  let b = Int64.bits_of_float f in
  let sign = Int64.to_int (Int64.shift_right_logical b 63) land 1 in
  let exp = Int64.to_int (Int64.logand (Int64.shift_right_logical b 52) 0x7FFL) in
  let mant = Int64.logand b 0xFFFFFFFFFFFFFL in
  if exp = 0 && mant = 0L then sign * 0x8000
  else if exp = 0x7FF then (sign * 0x8000) lor 0x7C00
  else
    let e = exp - 1023 + 15 in
    if e >= 31 then (sign * 0x8000) lor 0x7C00        (* 溢出 -> inf *)
    else if e > 0 then
      let m10 = Int64.to_int (Int64.shift_right_logical mant 42) in
      (sign * 0x8000) lor (e lsl 10) lor m10
    else begin
      (* 半精度非规格化（极少见于源码字面量） *)
      let m10 = Int64.to_int (Int64.shift_right_logical
                                (Int64.logor mant 0x10000000000000L)
                                (42 + (1 - e))) in
      (sign * 0x8000) lor (m10 land 0x3FF)
    end

(* double -> IEEE quad（binary128）位模式（double 可被 quad 精确表示） *)
(* 已废弃 fp128（MinGW 软浮点不可用）；f128 用 x86_fp80（long double） *)

(* double -> x86_fp80 位模式（80 位扩展精度：1 位符号 + 15 位指数 + 显式整数位 + 63 位尾数） *)
let double_to_fp80_bits (f : float) : int * Int64.t =
  let b = Int64.bits_of_float f in
  let sign = Int64.to_int (Int64.shift_right_logical b 63) land 1 in
  let exp = Int64.to_int (Int64.logand (Int64.shift_right_logical b 52) 0x7FFL) in
  let mant = Int64.logand b 0xFFFFFFFFFFFFFL in
  if exp = 0 && mant = 0L then (sign lsl 15, 0L)
  else if exp = 0x7FF then ((sign lsl 15) lor 0x7FFF, 0x8000000000000000L)
  else begin
    let e = exp - 1023 + 16383 in
    let hi = (sign lsl 15) lor e in
    let lo = Int64.logor 0x8000000000000000L (Int64.shift_left mant 11) in
    (hi, lo)
  end

(* 浮点字面量 -> LLVM 常量文本 *)
let float_const (t : zty) (f : float) : string =
  match t with
  | TFloat 16 -> Printf.sprintf "0xH%04X" (double_to_half_bits f)
  | TFloat 128 ->
    let (hi, lo) = double_to_fp80_bits f in
    Printf.sprintf "0xK%04X%016LX" hi lo
  | _ ->
    let s = Printf.sprintf "%.17g" f in
    (* LLVM 要求浮点常量带小数点/指数 *)
    if String.contains s '.' || String.contains s 'e' || String.contains s 'n'
    then s
    else s ^ ".0"

(* ---------- 函数上下文 ---------- *)

type fctx = {
  g : gctx;
  buf : Buffer.t;
  ebuf : Buffer.t;                             (* 入口块 alloca 专用（循环内 alloca 会耗尽栈） *)
  mutable nr : int;
  allocas : (string, string * zty) Hashtbl.t;  (* 变量名 -> (地址寄存器, 类型) *)
  regs : (string, string) Hashtbl.t;           (* 纯临时名 -> LLVM 寄存器 *)
  fret : zty;
  mutable nl : int;                            (* 内联边界检查的局部标签计数 *)
}

let fresh_r fc = fc.nr <- fc.nr + 1; Printf.sprintf "%%r%d" fc.nr

let fresh_lbl fc = fc.nl <- fc.nl + 1; Printf.sprintf "L%d" fc.nl

let emitf fc fmt =
  Printf.ksprintf (fun s -> Buffer.add_string fc.buf (s ^ "\n")) fmt

(* alloca 沉入函数入口块（支配所有块，且循环内不重复占用栈帧） *)
let emitf_entry fc fmt =
  Printf.ksprintf (fun s -> Buffer.add_string fc.ebuf (s ^ "\n")) fmt

(* 字符串字面量 -> i8* 值 *)
let str_value fc s =
  let name = intern_string fc.g s in
  let r = fresh_r fc in
  emitf fc "  %s = getelementptr inbounds [%d x i8], ptr %s, i64 0, i64 0"
    r (String.length s + 1) name;
  r

(* i128 位模式 -> 元素类型的 LLVM 值（MSeqGet 读出路径） *)
let from_bits fc (raw : string) (e : zty) : string * string =
  let trunc_to w =
    let r = fresh_r fc in
    emitf fc "  %s = trunc i128 %s to i%d" r raw w;
    r
  in
  match e with
  | TInt w | TUint w ->
    let r = if w < 128 then trunc_to w else raw in
    (r, Printf.sprintf "i%d" w)
  | TBool -> (trunc_to 1, "i1")
  | TChar -> (trunc_to 8, "i8")
  | TFloat 16 ->
    let i = trunc_to 16 in
    let r = fresh_r fc in
    emitf fc "  %s = bitcast i16 %s to half" r i;
    (r, "half")
  | TFloat 32 ->
    let i = trunc_to 32 in
    let r = fresh_r fc in
    emitf fc "  %s = bitcast i32 %s to float" r i;
    (r, "float")
  | TFloat 64 ->
    let i = trunc_to 64 in
    let r = fresh_r fc in
    emitf fc "  %s = bitcast i64 %s to double" r i;
    (r, "double")
  | TFloat 128 ->
    let i = trunc_to 80 in
    let r = fresh_r fc in
    emitf fc "  %s = bitcast i80 %s to x86_fp80" r i;
    (r, "x86_fp80")
  | TString ->
    let i = trunc_to 64 in
    let r = fresh_r fc in
    emitf fc "  %s = inttoptr i64 %s to ptr" r i;
    (r, "ptr")
  | _ -> lerr None "数组/列表不支持该元素类型"

(* 标量操作数 -> LLVM 值 *)
let rec val_of fc (o : operand) : string * string =
  let t = ll_ty o.oty in
  match o.o with
  | OInt n ->
    (match o.oty with
     | TFloat w ->
       let f = Int64.to_float n in
       (float_const o.oty f, ll_ty (TFloat w))
     | _ -> (Printf.sprintf "%Ld" n, t))
  | OFloat f -> (float_const o.oty f, t)
  | OBool b -> ((if b then "1" else "0"), t)
  | OChar c -> (string_of_int (Char.code c), t)
  | OStr s -> (str_value fc s, t)
  | OLocal n ->
    if Hashtbl.mem fc.regs n then (Hashtbl.find fc.regs n, t)
    else if Hashtbl.mem fc.allocas n then begin
      if is_agg o.oty then lerr None "聚合值 %s 需按指针使用" n;
      let (addr, _) = Hashtbl.find fc.allocas n in
      let r = fresh_r fc in
      emitf fc "  %s = load %s, ptr %s" r t addr;
      (r, t)
    end
    else lerr None "未定义的局部变量 %s" n

(* 标量值 -> i128 位模式（数组/列表元素统一按位模式存储，宽度由 elemsz 决定） *)
let bits_of fc (o : operand) : string =
  let to_i128 (v : string) (t : string) (signed : bool) : string =
    let r = fresh_r fc in
    if t = "i128" then v
    else begin
      if signed then emitf fc "  %s = sext %s %s to i128" r t v
      else emitf fc "  %s = zext %s %s to i128" r t v;
      r
    end
  in
  match o.oty with
  | TInt w ->
    let (v, t) = val_of fc o in
    to_i128 v t true
  | TUint w ->
    let (v, t) = val_of fc o in
    to_i128 v t false
  | TBool ->
    let (v, _) = val_of fc o in
    to_i128 v "i1" false
  | TChar ->
    let (v, _) = val_of fc o in
    to_i128 v "i8" false
  | TFloat 16 ->
    let (v, _) = val_of fc o in
    let i = fresh_r fc in
    emitf fc "  %s = bitcast half %s to i16" i v;
    to_i128 i "i16" false
  | TFloat 32 ->
    let (v, _) = val_of fc o in
    let i = fresh_r fc in
    emitf fc "  %s = bitcast float %s to i32" i v;
    to_i128 i "i32" false
  | TFloat 64 ->
    let (v, _) = val_of fc o in
    let i = fresh_r fc in
    emitf fc "  %s = bitcast double %s to i64" i v;
    to_i128 i "i64" false
  | TFloat 128 ->
    let (v, _) = val_of fc o in
    let i = fresh_r fc in
    emitf fc "  %s = bitcast x86_fp80 %s to i80" i v;
    to_i128 i "i80" false
  | TString ->
    let (v, _) = val_of fc o in
    let i = fresh_r fc in
    emitf fc "  %s = ptrtoint ptr %s to i64" i v;
    to_i128 i "i64" false
  | _ -> lerr None "该类型不能存入数组/列表元素"

(* 聚合操作数 -> 指针（槽位地址） *)
let ptr_of fc (o : operand) : string * string =
  match o.o with
  | OLocal n ->
    if Hashtbl.mem fc.allocas n then
      let (addr, ty) = Hashtbl.find fc.allocas n in
      (addr, ll_ty ty)
    else lerr None "未定义的变量 %s" n
  | _ -> lerr None "期望聚合局部变量"

let operand_of_name (n : string) (t : zty) : operand = { o = OLocal n; oty = t }

let gen_memcpy fc dst src size =
  emitf fc "  call void @llvm.memcpy.p0.p0.i64(ptr %s, ptr %s, i64 %d, i1 false)"
    dst src size

let gen_gep fc cur sty idx : string =
  let r = fresh_r fc in
  emitf fc "  %s = getelementptr inbounds %s, ptr %s, i32 0, i32 %d" r sty cur idx;
  r

(* ---------- 运算 ---------- *)

let cmp_op_int unsigned = function
  | BEq -> "eq" | BNe -> "ne"
  | BLt -> if unsigned then "ult" else "slt"
  | BGt -> if unsigned then "ugt" else "sgt"
  | BLe -> if unsigned then "ule" else "sle"
  | BGe -> if unsigned then "uge" else "sge"
  | _ -> assert false

let gen_binop fc d bop (a : operand) (b : operand) =
  if is_agg a.oty then lerr None "聚合类型不支持算术运算";
  let (va, tya) = val_of fc a and (vb, _) = val_of fc b in
  match a.oty with
  | TFloat _ ->
    (match bop with
     | BAdd -> emitf fc "  %s = fadd %s %s, %s" d tya va vb
     | BSub -> emitf fc "  %s = fsub %s %s, %s" d tya va vb
     | BMul -> emitf fc "  %s = fmul %s %s, %s" d tya va vb
     | BDiv -> emitf fc "  %s = fdiv %s %s, %s" d tya va vb
     | BMod -> lerr None "浮点类型不支持取模"
     | bopc ->
       let c =
         match bopc with
         | BEq -> "oeq" | BNe -> "one" | BLt -> "olt"
         | BGt -> "ogt" | BLe -> "ole" | BGe -> "oge" | _ -> assert false
       in
       emitf fc "  %s = fcmp %s %s %s, %s" d c tya va vb)
  | TBool ->
    (match bop with
     | BAnd -> emitf fc "  %s = and i1 %s, %s" d va vb
     | BOr -> emitf fc "  %s = or i1 %s, %s" d va vb
     | BEq -> emitf fc "  %s = icmp eq i1 %s, %s" d va vb
     | BNe -> emitf fc "  %s = icmp ne i1 %s, %s" d va vb
     | _ -> lerr None "布尔类型不支持该运算")
  | TUint _ ->
    (match bop with
     | BAdd -> emitf fc "  %s = add %s %s, %s" d tya va vb
     | BSub -> emitf fc "  %s = sub %s %s, %s" d tya va vb
     | BMul -> emitf fc "  %s = mul %s %s, %s" d tya va vb
     | BDiv -> emitf fc "  %s = udiv %s %s, %s" d tya va vb
     | BMod -> emitf fc "  %s = urem %s %s, %s" d tya va vb
     | bopc -> emitf fc "  %s = icmp %s %s %s, %s" d (cmp_op_int true bopc) tya va vb)
  | _ ->
    (match bop with
     | BAdd -> emitf fc "  %s = add %s %s, %s" d tya va vb
     | BSub -> emitf fc "  %s = sub %s %s, %s" d tya va vb
     | BMul -> emitf fc "  %s = mul %s %s, %s" d tya va vb
     | BDiv -> emitf fc "  %s = sdiv %s %s, %s" d tya va vb
     | BMod -> emitf fc "  %s = srem %s %s, %s" d tya va vb
     | bopc -> emitf fc "  %s = icmp %s %s %s, %s" d (cmp_op_int false bopc) tya va vb)

let gen_unop fc d u (a : operand) =
  if is_agg a.oty then lerr None "聚合类型不支持一元运算";
  let (va, tya) = val_of fc a in
  match u with
  | UNeg ->
    (match a.oty with
     | TFloat _ -> emitf fc "  %s = fneg %s %s" d tya va
     | _ -> emitf fc "  %s = sub %s 0, %s" d tya va)
  | UNot -> emitf fc "  %s = xor %s %s, 1" d tya va

(* ---------- 值 -> string（输出格式，供 prec 与 cast 用） ---------- *)

(* 把标量值按打印格式转为 malloc 堆串（LLVM 寄存器 ptr，归调用者释放） *)
let tostr_ptr fc (o : operand) : string =
  match o.oty with
  | TString -> fst (val_of fc o)
  | TBool ->
    let (v, _) = val_of fc o in
    let z = fresh_r fc in
    emitf fc "  %s = zext i1 %s to i32" z v;
    let r = fresh_r fc in
    emitf fc "  %s = call ptr @zfy_tostr_bool(i32 %s)" r z;
    r
  | TChar ->
    let (v, _) = val_of fc o in
    let r = fresh_r fc in
    emitf fc "  %s = call ptr @zfy_tostr_char(i8 %s)" r v;
    r
  | TInt 128 ->
    let (v, _) = val_of fc o in
    (* MinGW C ABI 中 __int128 标量参数按引用 *)
    let a = fresh_r fc in
    emitf_entry fc "  %s = alloca i128" a;
    emitf fc "  store i128 %s, ptr %s" v a;
    let r = fresh_r fc in
    emitf fc "  %s = call ptr @zfy_tostr_i128(ptr %s)" r a;
    r
  | TUint 128 ->
    let (v, _) = val_of fc o in
    let a = fresh_r fc in
    emitf_entry fc "  %s = alloca i128" a;
    emitf fc "  store i128 %s, ptr %s" v a;
    let r = fresh_r fc in
    emitf fc "  %s = call ptr @zfy_tostr_u128(ptr %s)" r a;
    r
  | TInt w ->
    let (v, _) = val_of fc o in
    let x =
      if w < 64 then
        let z = fresh_r fc in
        emitf fc "  %s = sext i%d %s to i64" z w v;
        z
      else v
    in
    let r = fresh_r fc in
    emitf fc "  %s = call ptr @zfy_tostr_i64(i64 %s)" r x;
    r
  | TUint w ->
    let (v, _) = val_of fc o in
    let x =
      if w < 64 then
        let z = fresh_r fc in
        emitf fc "  %s = zext i%d %s to i64" z w v;
        z
      else v
    in
    let r = fresh_r fc in
    emitf fc "  %s = call ptr @zfy_tostr_u64(i64 %s)" r x;
    r
  | TFloat _ ->
    let (v, _) = val_of fc o in
    let d =
      if float_width o.oty < 64 then
        let z = fresh_r fc in
        emitf fc "  %s = fpext %s %s to double" z (ll_ty o.oty) v;
        z
      else if float_width o.oty > 64 then
        let z = fresh_r fc in
        emitf fc "  %s = fptrunc %s %s to double" z (ll_ty o.oty) v;
        z
      else v
    in
    let r = fresh_r fc in
    emitf fc "  %s = call ptr @zfy_tostr_f64(double %s)" r d;
    r
  | TFrac e ->
    let (p, _) = ptr_of fc o in
    let r = fresh_r fc in
    emitf fc "  %s = call ptr @zfy_frac_str_%s(ptr %s)" r (Hir.suffix_of e) p;
    r
  | _ -> lerr None "该类型不能转为 string"

let gen_cast fc d (a : operand) (t : zty) =
  if is_agg a.oty || is_agg t then lerr None "聚合类型不支持 cast";
  let (va, ta) = val_of fc a in
  let tb = ll_ty t in
  let int_like = function TInt _ | TUint _ | TBool | TChar -> true | _ -> false in
  let is_unsigned = function TUint _ -> true | _ -> false in
  if ta = tb then begin
    match a.oty with
    | TFloat _ -> emitf fc "  %s = fadd %s %s, 0.0" d ta va
    | _ -> emitf fc "  %s = add %s %s, 0" d ta va
  end
  else
    match a.oty, t with
    | _, TBool when int_like a.oty ->
      (* 整数/bool/char -> bool：非 0 为 true *)
      emitf fc "  %s = icmp ne %s %s, 0" d ta va
    | TFloat _, TBool ->
      emitf fc "  %s = fcmp one %s %s, 0.0" d ta va
    | TString, (TInt _ | TUint _) ->
      (* string -> 整数：运行时解析前缀数字（C++ stoi 语义） *)
      let r = fresh_r fc in
      emitf fc "  %s = call i64 @zfy_stoi(ptr %s)" r va;
      (match t with
       | TInt 128 -> emitf fc "  %s = sext i64 %s to i128" d r
       | TUint 128 -> emitf fc "  %s = zext i64 %s to i128" d r
       | (TInt w | TUint w) when w < 64 ->
         emitf fc "  %s = trunc i64 %s to i%d" d r w
       | _ -> emitf fc "  %s = add i64 %s, 0" d r)
    | TString, TFloat _ ->
      (* string -> 浮点：strtod 解析后按宽度重编码 *)
      let r = fresh_r fc in
      emitf fc "  %s = call double @zfy_stod(ptr %s)" r va;
      if t <> TFloat 64 then begin
        if float_width t < 64 then
          emitf fc "  %s = fptrunc double %s to %s" d r tb
        else
          emitf fc "  %s = fpext double %s to %s" d r tb
      end
      else emitf fc "  %s = fadd double %s, 0.0" d r
    | TString, TBool ->
      (* string -> bool：非空为 true *)
      let r = fresh_r fc in
      emitf fc "  %s = call i64 @strlen(ptr %s)" r va;
      emitf fc "  %s = icmp ne i64 %s, 0" d r
    | _, TString when int_like a.oty || (match a.oty with TFloat _ -> true | _ -> false) ->
      (* 数值/bool/char -> string：按输出格式格式化 *)
      let sp = tostr_ptr fc a in
      emitf fc "  %s = call ptr @zfy_strdup(ptr %s)" d sp
    | TFloat _, TFloat _ ->
      let wa = float_width a.oty and wb = float_width t in
      if wa < wb then emitf fc "  %s = fpext %s %s to %s" d ta va tb
      else emitf fc "  %s = fptrunc %s %s to %s" d ta va tb
    | TFloat _, _ ->
      if is_unsigned t then emitf fc "  %s = fptoui %s %s to %s" d ta va tb
      else emitf fc "  %s = fptosi %s %s to %s" d ta va tb
    | _, TFloat _ ->
      if is_unsigned a.oty then emitf fc "  %s = uitofp %s %s to %s" d ta va tb
      else emitf fc "  %s = sitofp %s %s to %s" d ta va tb
    | _ when int_like a.oty && int_like t ->
      let wa = width_of a.oty and wb = width_of t in
      if wa = wb then emitf fc "  %s = bitcast %s %s to %s" d ta va tb
      else if wa < wb then begin
        if is_unsigned a.oty then emitf fc "  %s = zext %s %s to %s" d ta va tb
        else emitf fc "  %s = sext %s %s to %s" d ta va tb
      end
      else emitf fc "  %s = trunc %s %s to %s" d ta va tb
    | _ -> lerr None "不支持的转换 %s -> %s" ta tb

(* ---------- output / input ---------- *)

(* 数组/列表元素的存储宽度（字节）：bool/char/i8/u8/f16 1-2、i32/f32 4、
   i64/f64/string 8、i128/u128/f128 16 *)
let elem_width (e : zty) : int =
  match e with
  | TInt 8 | TUint 8 | TBool | TChar -> 1
  | TFloat 16 | TInt 16 | TUint 16 -> 2
  | TInt 32 | TUint 32 | TFloat 32 -> 4
  | TInt 64 | TUint 64 | TFloat 64 | TString -> 8
  | TInt 128 | TUint 128 | TFloat 128 -> 16
  | _ -> lerr None "数组/列表不支持该元素类型"

(* 元素读出时的扩展方式：有符号整数符号扩展，其余零扩展 *)
let elem_signed (e : zty) : int =
  match e with TInt _ -> 1 | _ -> 0

(* 内联元素地址：边界检查（icmp ult 同时覆盖负下标：负数无符号比较必失败）
   + GEP 到元素字节地址。失败路径调用 zfy_bounds_fail（不返回）后 unreachable。
   返回 (元素地址, join 标签)：调用方在快速块内完成 load/store 后须
   `br label %join` 收尾；join 块只有一个前驱（快速块），无需 phi。 *)
let inline_elem_addr fc (seqp : string) (iv : string) (elem : zty) : string * string =
  let lenp = fresh_r fc in
  emitf fc "  %s = getelementptr inbounds %%zfy.seq, ptr %s, i32 0, i32 2" lenp seqp;
  let len = fresh_r fc in
  emitf fc "  %s = load i64, ptr %s" len lenp;
  let ok = fresh_r fc in
  emitf fc "  %s = icmp ult i64 %s, %s" ok iv len;
  let lb = fresh_lbl fc and fb = fresh_lbl fc and jb = fresh_lbl fc in
  emitf fc "  br i1 %s, label %%%s, label %%%s" ok lb fb;
  emitf fc "%s:" fb;
  emitf fc "  call void @zfy_bounds_fail()";
  emitf fc "  unreachable";
  emitf fc "%s:" lb;
  let dp = fresh_r fc in
  emitf fc "  %s = load ptr, ptr %s" dp seqp;
  let off = fresh_r fc in
  emitf fc "  %s = mul i64 %s, %d" off iv (elem_width elem);
  let ep = fresh_r fc in
  emitf fc "  %s = getelementptr inbounds i8, ptr %s, i64 %s" ep dp off;
  (ep, jb)

(* 按类型输出一个值 *)
let gen_print_val fc (o : operand) =
  match o.oty with
  | TString ->
    let (v, _) = val_of fc o in
    emitf fc "  call void @zfy_print_str(ptr %s)" v
  | TBool ->
    let (v, _) = val_of fc o in
    let z = fresh_r fc in
    emitf fc "  %s = zext i1 %s to i32" z v;
    emitf fc "  call void @zfy_print_bool(i32 %s)" z
  | TChar ->
    let (v, _) = val_of fc o in
    emitf fc "  call void @zfy_print_char(i8 %s)" v
  | TFloat 16 ->
    let (v, _) = val_of fc o in
    let d = fresh_r fc in
    emitf fc "  %s = fpext half %s to double" d v;
    emitf fc "  call void @zfy_print_f64(double %s)" d
  | TFloat 32 ->
    let (v, _) = val_of fc o in
    let d = fresh_r fc in
    emitf fc "  %s = fpext float %s to double" d v;
    emitf fc "  call void @zfy_print_f64(double %s)" d
  | TFloat 64 ->
    let (v, _) = val_of fc o in
    emitf fc "  call void @zfy_print_f64(double %s)" v
  | TFloat 128 ->
    let (v, _) = val_of fc o in
    let d = fresh_r fc in
    emitf fc "  %s = fptrunc x86_fp80 %s to double" d v;
    emitf fc "  call void @zfy_print_f64(double %s)" d
  | TFrac e ->
    let (p, _) = ptr_of fc o in
    emitf fc "  call void @zfy_frac_print_%s(ptr %s)" (Hir.suffix_of e) p
  | TUint 128 ->
    let (v, _) = val_of fc o in
    (* MinGW C ABI 中 __int128 标量参数按引用：alloca + store + 传指针 *)
    let a = fresh_r fc in
    emitf_entry fc "  %s = alloca i128" a;
    emitf fc "  store i128 %s, ptr %s" v a;
    emitf fc "  call void @zfy_print_u128(ptr %s)" a
  | TUint w ->
    let (v, _) = val_of fc o in
    let v64 =
      if w < 64 then begin
        let z = fresh_r fc in
        emitf fc "  %s = zext i%d %s to i64" z w v;
        z
      end else v
    in
    emitf fc "  call void @zfy_print_u64(i64 %s)" v64
  | TInt 128 ->
    let (v, _) = val_of fc o in
    let a = fresh_r fc in
    emitf_entry fc "  %s = alloca i128" a;
    emitf fc "  store i128 %s, ptr %s" v a;
    emitf fc "  call void @zfy_print_i128(ptr %s)" a
  | TInt w ->
    let (v, _) = val_of fc o in
    let v64 =
      if w < 64 then begin
        let z = fresh_r fc in
        emitf fc "  %s = sext i%d %s to i64" z w v;
        z
      end else v
    in
    emitf fc "  call void @zfy_print_i64(i64 %s)" v64
  | _ -> lerr None "output 不支持该参数类型"

(* 读入一段输入存入变量槽：runtime 按 delim 分段、解析并写入值槽
   （EOF 或解析失败直接报运行时错误退出）；delim 为空串时用
   默认"换行和空格"字符集（' ' 或 '\n' 任一命中即切分） *)
let gen_input fc name (ty : zty) delim =
  match Hashtbl.find_opt fc.allocas name with
  | None -> lerr None "未定义的变量 %s" name
  | Some (addr, _) ->
    let (dp, _) = val_of fc delim in
    let (fname, extra) =
      match ty with
      | TString -> ("zfy_input_str", "")
      | TInt 128 -> ("zfy_input_i128", "")
      | TUint 128 -> ("zfy_input_u128", "")
      | TInt _ | TUint _ -> ("zfy_input_i64", "")
      | TBool -> ("zfy_input_bool", "")
      | TChar -> ("zfy_input_char", "")
      | TFloat 16 -> ("zfy_input_f64", ", i32 2")
      | TFloat 32 -> ("zfy_input_f64", ", i32 1")   (* as_f32：按 4 字节写槽 *)
      | TFloat 64 -> ("zfy_input_f64", ", i32 0")
      | TFloat 128 -> ("zfy_input_f64", ", i32 3")
      | _ -> lerr None "input 不支持该目标类型"
    in
    emitf fc "  call void @%s(ptr %s, ptr %s%s)"
      fname addr dp extra

(* ---------- 内建函数 ---------- *)

let gen_call fc dst name (args : operand list) (ret_ty : zty) =
  let arg_values () =
    List.map
      (fun (o : operand) ->
        if is_agg o.oty then begin
          (* 聚合参数按指针传递 *)
          let (p, _) = ptr_of fc o in
          ("ptr", p)
        end
        else
          let (v, t) = val_of fc o in
          (t, v))
      args
  in
  match name, args with
  | "str_len", [ a ] ->
    let (v, _) = val_of fc a in
    (match dst with
     | None -> ()
     | Some d -> emitf fc "  %s = call i64 @strlen(ptr %s)" d v)
  (* i1 布尔 -> i8 适配（tostr_bool） *)
  | "zfy_tostr_bool", [ a ] ->
    let (v, _) = val_of fc a in
    let z = fresh_r fc in
    emitf fc "  %s = zext i1 %s to i32" z v;
    (match dst with
     | None -> ()
     | Some d -> emitf fc "  %s = call ptr @zfy_tostr_bool(i32 %s)" d z)
  (* prec(v, n)：输出长度控制（总字符数，截断/右补空格），返回 malloc 串 *)
  | "zfy.prec", [ v; n ] ->
    (match dst with
     | None -> ()
     | Some d ->
       let n64 =
         match n.oty with
         | TChar ->
           let (c, _) = val_of fc n in
           let r = fresh_r fc in
           emitf fc "  %s = call i64 @zfy_char_digit(i8 %s)" r c;
           r
         | TBool ->
           let (nv, _) = val_of fc n in
           let r = fresh_r fc in
           emitf fc "  %s = zext i1 %s to i64" r nv;
           r
         | TInt 128 | TUint 128 ->
           let (nv, _) = val_of fc n in
           let r = fresh_r fc in
           emitf fc "  %s = trunc %s %s to i64" r (ll_ty n.oty) nv;
           r
         | TInt w ->
           let (nv, _) = val_of fc n in
           if w < 64 then begin
             let r = fresh_r fc in
             emitf fc "  %s = sext i%d %s to i64" r w nv;
             r
           end else nv
         | TUint w ->
           let (nv, _) = val_of fc n in
           if w < 64 then begin
             let r = fresh_r fc in
             emitf fc "  %s = zext i%d %s to i64" r w nv;
             r
           end else nv
         | TFloat _ ->
           let (nv, _) = val_of fc n in
           let r = fresh_r fc in
           emitf fc "  %s = fptosi %s %s to i64" r (ll_ty n.oty) nv;
           r
         | _ -> lerr None "prec 长度参数类型错误"
       in
       let sp = tostr_ptr fc v in
       emitf fc "  %s = call ptr @zfy_prec_str(ptr %s, i64 %s)" d sp n64)
  | _ ->
    let callee = if name = "main" then "@zfy.main" else "@" ^ name in
    let targs = arg_values () in
    let args_str =
      String.concat ""
        (List.map (fun (t, v) -> Printf.sprintf ", %s %s" t v) targs)
    in
    if is_agg ret_ty then begin
      match dst with
      | None -> lerr None "聚合返回值必须被接收"
      | Some d ->
        if not (Hashtbl.mem fc.allocas d) then
          lerr None "接收聚合返回值的必须是变量";
        let (addr, _) = Hashtbl.find fc.allocas d in
        emitf fc "  call void %s(ptr %s%s)" callee addr args_str
    end
    else begin
      let args_str =
        if args_str = "" then ""
        else String.sub args_str 2 (String.length args_str - 2)
      in
      match ret_ty, dst with
      | TVoid, _ -> emitf fc "  call void %s(%s)" callee args_str
      | rt, Some d ->
        emitf fc "  %s = call %s %s(%s)" d (ll_ty rt) callee args_str
      | _ -> lerr None "非 void 返回值必须被使用"
    end

(* ---------- 用户函数调用（所有权传参） ---------- *)

(* MCallOwn 实参：move=true 直接移交指针值；false 由调用方克隆（值语义）。
   frac 借传槽地址（被调方 memcpy 值拷贝） *)
let own_arg fc (o : operand) (mv : bool) : string * string =
  match o.oty with
  | TFrac _ ->
    let (p, t) = ptr_of fc o in
    (t, p)
  | TString ->
    let (v, t) = val_of fc o in
    if mv then (t, v)
    else begin
      let r = fresh_r fc in
      emitf fc "  %s = call ptr @zfy_strdup(ptr %s)" r v;
      (t, r)
    end
  | TArray _ | TList _ ->
    let (v, t) = val_of fc o in
    if mv then (t, v)
    else begin
      let is_str =
        (match o.oty with TArray (TString, _) | TList TString -> 1 | _ -> 0) in
      let r = fresh_r fc in
      emitf fc "  %s = call ptr @zfy_seq_clone(ptr %s, i8 %d)" r v is_str;
      (t, r)
    end
  | _ -> val_of fc o

let gen_call_own fc dst name (args : (operand * bool) list) (ret_ty : zty)
    (clears : (string * zty) list) =
  let callee = if name = "main" then "@zfy.main" else "@" ^ name in
  let targs = List.map (fun (o, mv) -> own_arg fc o mv) args in
  let args_str =
    String.concat ""
      (List.map (fun (t, v) -> Printf.sprintf ", %s %s" t v) targs)
  in
  if is_agg ret_ty then begin
    match dst with
    | None -> lerr None "聚合返回值必须被接收"
    | Some d ->
      if not (Hashtbl.mem fc.allocas d) then
        lerr None "接收聚合返回值的必须是变量";
      let (addr, _) = Hashtbl.find fc.allocas d in
      emitf fc "  call void %s(ptr %s%s)" callee addr args_str
  end
  else begin
    let args_str =
      if args_str = "" then ""
      else String.sub args_str 2 (String.length args_str - 2)
    in
    match ret_ty, dst with
    | TVoid, _ -> emitf fc "  call void %s(%s)" callee args_str
    | rt, Some d ->
      emitf fc "  %s = call %s %s(%s)" d (ll_ty rt) callee args_str
    | _ -> lerr None "非 void 返回值必须被使用"
  end;
  (* move 的变量实参：调用完成后清槽（所有权已移交，防 RAII 双释放） *)
  List.iter
    (fun (n, ty) ->
      let (dstp, _) = ptr_of fc (operand_of_name n ty) in
      emitf fc "  store ptr null, ptr %s" dstp)
    clears

(* ---------- 指令生成 ---------- *)

let gen_instr fc (i : instr) : unit =
  match i with
  | MCopy (name, v, ty) ->
    if String.length name > 0 && name.[0] = '%'
       && not (Hashtbl.mem fc.allocas name)
    then begin
      (* 常量折叠产生的纯临时：值进寄存器表 *)
      let (v', _) = val_of fc v in
      Hashtbl.replace fc.regs name v'
    end
    else begin
      let (dstp, _) = ptr_of fc (operand_of_name name ty) in
      (* 先释放槽中旧资源：string 旧堆串、数组/列表旧 seq（string 元素一并释放） *)
      (match ty with
       | TString ->
         let ov = fresh_r fc in
         emitf fc "  %s = load ptr, ptr %s" ov dstp;
         emitf fc "  call void @zfy_free_str(ptr %s)" ov
       | TArray _ | TList _ ->
         let ov = fresh_r fc in
         emitf fc "  %s = load ptr, ptr %s" ov dstp;
         let fe = (match ty with TArray (TString, _) | TList TString -> 1 | _ -> 0) in
         emitf fc "  call void @zfy_seq_free(ptr %s, i8 %d)" ov fe
       | _ -> ());
      (match ty with
       | TArray _ | TList _ ->
         (* 深拷贝 seq：避免两个变量共享同一资源导致双重释放 *)
         let is_str =
           match ty with TArray (TString, _) | TList TString -> 1 | _ -> 0 in
         let (sv, _) = val_of fc v in
         let r = fresh_r fc in
         emitf fc "  %s = call ptr @zfy_seq_clone(ptr %s, i8 %d)" r sv is_str;
         emitf fc "  store ptr %s, ptr %s" r dstp
       | TString ->
         (* 深拷贝语义：槽内恒持有独立堆串（字面量为全局常量，需 strdup） *)
         let (sv, _) = val_of fc v in
         let r = fresh_r fc in
         emitf fc "  %s = call ptr @zfy_strdup(ptr %s)" r sv;
         emitf fc "  store ptr %s, ptr %s" r dstp
       | TFrac _ ->
         (* frac 聚合：memcpy *)
         let (srcp, _) = ptr_of fc v in
         gen_memcpy fc dstp srcp (size_of fc.g ty)
       | _ ->
         let (v', t) = val_of fc v in
         let tt = ll_ty ty in
         if t <> tt then lerr None "槽位类型 %s 与值类型 %s 不一致" tt t;
         emitf fc "  store %s %s, ptr %s" tt v' dstp)
    end
  | MMoveSeq (name, v, ty) ->
    (* 所有权转移：释放目标旧值后直接接管临时指针（免克隆）。
       临时从 stmt_temps 移除，语句末不会再释放（mir 侧保证）。 *)
    let (dstp, _) = ptr_of fc (operand_of_name name ty) in
    let ov = fresh_r fc in
    emitf fc "  %s = load ptr, ptr %s" ov dstp;
    (match ty with
     | TString -> emitf fc "  call void @zfy_free_str(ptr %s)" ov
     | _ ->
       let fe = (match ty with TArray (TString, _) | TList TString -> 1 | _ -> 0) in
       emitf fc "  call void @zfy_seq_free(ptr %s, i8 %d)" ov fe);
    let (sv, st) = val_of fc v in
    if st <> "ptr" then lerr None "move 目标槽类型 %s 非法" st;
    emitf fc "  store ptr %s, ptr %s" sv dstp
  | MClear (name, ty) ->
    (* move 后清槽：资源所有权已移交，置空防 RAII 双释放 *)
    let (dstp, _) = ptr_of fc (operand_of_name name ty) in
    emitf fc "  store ptr null, ptr %s" dstp
  | MBinop (d, bop, a, b) ->
    let r = fresh_r fc in
    gen_binop fc r bop a b;
    Hashtbl.replace fc.regs d r
  | MUnop (d, u, a) ->
    let r = fresh_r fc in
    gen_unop fc r u a;
    Hashtbl.replace fc.regs d r
  | MCast (d, a, t) ->
    let r = fresh_r fc in
    gen_cast fc r a t;
    Hashtbl.replace fc.regs d r
  | MCall (d, name, args, ret) ->
    (match d with
     | Some d' when is_agg ret ->
       let addr = fresh_r fc in
       emitf_entry fc "  %s = alloca %s" addr (ll_ty ret);
       Hashtbl.replace fc.allocas d' (addr, ret);
       gen_call fc (Some d') name args ret
     | _ ->
       gen_call fc d name args ret;
       (match d with
        | Some d' when ret <> TVoid ->
          Hashtbl.replace fc.regs d' d'
        | _ -> ()))
  | MCallOwn (d, name, args, ret, clears) ->
    (match d with
     | Some d' when is_agg ret ->
       let addr = fresh_r fc in
       emitf_entry fc "  %s = alloca %s" addr (ll_ty ret);
       Hashtbl.replace fc.allocas d' (addr, ret);
       gen_call_own fc (Some d') name args ret clears
     | _ ->
       gen_call_own fc d name args ret clears;
       (match d with
        | Some d' when ret <> TVoid ->
          Hashtbl.replace fc.regs d' d'
        | _ -> ()))
  | MThrow v ->
    let (vv, _) = val_of fc v in
    emitf fc "  call void @zfy_throw(ptr %s)" vv
  | MTryFrame name ->
    emitf_entry fc "  %s = alloca [512 x i8], align 16" name
  | MTrySetup (res, frame) ->
    let r = fresh_r fc in
    emitf fc "  %s = call i32 @zfy_try_setup(ptr %s) returns_twice" r frame;
    let b = fresh_r fc in
    emitf fc "  %s = icmp ne i32 %s, 0" b r;
    Hashtbl.replace fc.regs res b
  | MTryLeave ->
    emitf fc "  call void @zfy_try_leave()"
  | MTryMsg (name, _ty) ->
    (match Hashtbl.find_opt fc.allocas name with
     | Some (addr, _) ->
       let r = fresh_r fc in
       emitf fc "  %s = call ptr @zfy_try_msg()" r;
       emitf fc "  store ptr %s, ptr %s" r addr
     | None -> lerr None "未定义的变量 %s" name)
  | MAlloca (name, ty) ->
    if String.length name > 0 && name.[0] = '@' then begin
      (* 顶层变量槽：模块级 global 定义（零初始化即 zfy 零值），去重 *)
      let gname = name in  (* 已含 '@' 前缀，直接作 LLVM 全局名 *)
      if not (Hashtbl.mem fc.g.globals name) then begin
        Hashtbl.replace fc.g.globals name ();
        Buffer.add_string fc.g.mbuf
          (Printf.sprintf "%s = global %s zeroinitializer\n" gname (ll_ty ty))
      end;
      Hashtbl.replace fc.allocas name (gname, ty)
    end
    else begin
      let addr =
        if String.length name > 0 && name.[0] = '%' then name
        else Printf.sprintf "%%v.%s" name
      in
      emitf_entry fc "  %s = alloca %s" addr (ll_ty ty);
      Hashtbl.replace fc.allocas name (addr, ty);
      (* 值槽清零（零值即各类型默认值；随后声明初值语句会覆盖） *)
      (match ty with
       | TString | TArray _ | TList _ ->
         emitf fc "  store ptr null, ptr %s" addr
       | _ -> emitf fc "  store %s zeroinitializer, ptr %s" (ll_ty ty) addr)
    end
  | MFracNew (d, ty, num, den) ->
    let addr = fresh_r fc in
    let fty = ll_ty ty in
    emitf_entry fc "  %s = alloca %s" addr fty;
    Hashtbl.replace fc.allocas d (addr, ty);
    let np = gen_gep fc addr fty 0 in
    let (nv, nt) = val_of fc num in
    emitf fc "  store %s %s, ptr %s" nt nv np;
    let dp = gen_gep fc addr fty 1 in
    let (dv, dt) = val_of fc den in
    emitf fc "  store %s %s, ptr %s" dt dv dp
  | MNorm (name, ty) ->
    (* 非 unreduced frac 槽存入后自动约分 *)
    let elem = (match ty with TFrac e -> e | _ -> lerr None "norm 类型错误") in
    (match Hashtbl.find_opt fc.allocas name with
     | Some (p, _) ->
       emitf fc "  call void @zfy_frac_norm_%s(ptr %s)" (Hir.suffix_of elem) p
     | None -> lerr None "未定义的变量 %s" name)
  | MSeqRemove (name, elem, idx, is_list) ->
    (* remove：数组=槽位填零值（string 元素先释放旧串）；列表=删除并左移，长度-1 *)
    let (seqp, _) = val_of fc (operand_of_name name (TList (TInt 64))) in
    let (iv, _) = val_of fc idx in
    if is_list then begin
      let free_elems = (match elem with TString -> 1 | _ -> 0) in
      emitf fc "  call void @zfy_seq_remove(ptr %s, i64 %s, i8 %d)" seqp iv free_elems
    end else begin
      let free_elems = (match elem with TString -> 1 | _ -> 0) in
      emitf fc "  call void @zfy_seq_zero(ptr %s, i64 %s, i8 %d)" seqp iv free_elems
    end
  | MAugSlice (name, elem, a, b, st, bop, v) ->
    (* a[x,y:st] op= v：运行时逐元素原地运算（值经 i128 位模式缓冲传递） *)
    let (seqp, _) = val_of fc (operand_of_name name (TList (TInt 64))) in
    let (av, _) = val_of fc a and (bv, _) = val_of fc b in
    let (sv, _) = val_of fc st and (vv, vt) = val_of fc v in
    let opn =
      match bop with
      | BAdd -> 0 | BSub -> 1 | BMul -> 2 | BDiv -> 3 | BMod -> 4
      | _ -> lerr None "切片复合赋值不支持的运算"
    in
    let width = elem_width elem in
    let sgn = elem_signed elem in
    let isf = (match elem with TFloat _ -> 1 | _ -> 0) in
    let bits = fresh_r fc in
    emitf_entry fc "  %s = alloca i128" bits;
    let z =
      match elem with
      | TFloat 32 ->
        let c = fresh_r fc in
        emitf fc "  %s = bitcast %s %s to i32" c vt vv;
        let z = fresh_r fc in
        emitf fc "  %s = zext i32 %s to i128" z c;
        z
      | TFloat 64 ->
        let c = fresh_r fc in
        emitf fc "  %s = bitcast %s %s to i64" c vt vv;
        let z = fresh_r fc in
        emitf fc "  %s = zext i64 %s to i128" z c;
        z
      | TInt _ | TUint _ | TBool | TChar ->
        if width >= 8 then begin
          (* i64/u64：i64 寄存器；i128/u128：i128 寄存器直接传 *)
          if vt = "i128" then vv
          else begin
            let z = fresh_r fc in
            emitf fc "  %s = zext i64 %s to i128" z vv;
            z
          end
        end
        else begin
          let op64 = if sgn = 1 then "sext" else "zext" in
          let c = fresh_r fc in
          emitf fc "  %s = %s %s %s to i64" c op64 (ll_ty elem) vv;
          let z = fresh_r fc in
          emitf fc "  %s = zext i64 %s to i128" z c;
          z
        end
      | _ -> lerr None "切片复合赋值不支持的元素类型"
    in
    emitf fc "  store i128 %s, ptr %s" z bits;
    emitf fc
      "  call void @zfy_seq_aug_range(ptr %s, i64 %s, i64 %s, i64 %s, i32 %d, ptr %s, i32 %d, i32 %d, i32 %d)"
      seqp av bv sv opn bits width sgn isf
  | MReduce (root, ty, cnt, start) ->
    (match Hashtbl.find_opt fc.allocas root with
     | Some (p, _) ->
       let elem = (match ty with TFrac e -> e | _ -> lerr None "reduce 类型错误") in
       let callee = Printf.sprintf "@zfy_frac_reduce_%s" (Hir.suffix_of elem) in
       let (cv, _) = val_of fc cnt and (sv, _) = val_of fc start in
       emitf fc "  call void %s(ptr %s, i64 %s, i64 %s)" callee p cv sv
     | None -> lerr None "未定义的变量 %s" root)
  | MPrintStr s ->
    let p = str_value fc s in
    emitf fc "  call void @zfy_print_str(ptr %s)" p
  | MPrintVal o -> gen_print_val fc o
  | MInput (name, ty, delim) -> gen_input fc name ty delim
  | MFreeVar (name, ty) ->
    (* RAII 释放：string 释放堆串；数组/列表释放 seq（string 元素一并释放） *)
    (match Hashtbl.find_opt fc.allocas name with
     | Some (addr, _) ->
       (match ty with
        | TString ->
          let sp = fresh_r fc in
          emitf fc "  %s = load ptr, ptr %s" sp addr;
          emitf fc "  call void @zfy_free_str(ptr %s)" sp;
          emitf fc "  store ptr null, ptr %s" addr
        | TArray (TString, _) | TList TString ->
          let sp = fresh_r fc in
          emitf fc "  %s = load ptr, ptr %s" sp addr;
          emitf fc "  call void @zfy_seq_free(ptr %s, i8 1)" sp;
          emitf fc "  store ptr null, ptr %s" addr
        | TArray _ | TList _ ->
          let sp = fresh_r fc in
          emitf fc "  %s = load ptr, ptr %s" sp addr;
          emitf fc "  call void @zfy_seq_free(ptr %s, i8 0)" sp;
          emitf fc "  store ptr null, ptr %s" addr
        | _ -> ())
     | None -> lerr None "未定义的变量 %s" name)
  | MFreeTemp name ->
    (* 语句末释放临时堆串（寄存器中持有 malloc 指针） *)
    (match Hashtbl.find_opt fc.regs name with
     | Some v -> emitf fc "  call void @zfy_free_str(ptr %s)" v
     | None -> lerr None "未定义的临时 %s" name)
  | MFreeSeqTemp (name, is_str) ->
    (* 语句末释放临时 seq（切片结果等） *)
    (match Hashtbl.find_opt fc.regs name with
     | Some v ->
       emitf fc "  call void @zfy_seq_free(ptr %s, i8 %d)" v (if is_str then 1 else 0)
     | None -> lerr None "未定义的临时 %s" name)
  | MSeqAlloc (name, elem, len, is_list) ->
    (* 分配数组/列表：数组 len=容量=长度；列表空起步、初始容量 8（不够自动扩长） *)
    let (slotp, _) = ptr_of fc (operand_of_name name (TList (TInt 64))) in
    let (cnt, cap) =
      if is_list then (0L, 8L)
      else (len, max len 1L)
    in
    let r = fresh_r fc in
    emitf fc "  %s = call ptr @zfy_seq_new(i64 %Ld, i64 %Ld, i32 %d)"
      r cnt cap (elem_width elem);
    emitf fc "  store ptr %s, ptr %s" r slotp
  | MSeqSet (name, elem, idx, v, grow) ->
    (* 元素写入：按元素宽度存储；string 元素深拷贝（数组独占堆串）。
       非 string 且不扩长时走内联路径（边界检查 + 直接 store），
       消除逐元素函数调用与 i128 中转槽；其余走运行时函数。 *)
    let (seqp, _) = val_of fc (operand_of_name name (TList (TInt 64))) in
    let (iv, _) = val_of fc idx in
    (match elem, grow with
     | TString, _ ->
       let (sv, _) = val_of fc v in
       emitf fc
         "  call void @zfy_seq_set_str(ptr %s, i64 %s, ptr %s, i8 %d)"
         seqp iv sv (if grow then 1 else 0)
     | _, true ->
       (* 扩长写入（列表下标=len 追加）：仍走运行时 *)
       let bits = bits_of fc v in
       let slot = fresh_r fc in
       emitf_entry fc "  %s = alloca i128" slot;
       emitf fc "  store i128 %s, ptr %s" bits slot;
       emitf fc
         "  call void @zfy_seq_set_w(ptr %s, i64 %s, ptr %s, i32 %d, i8 %d)"
         seqp iv slot (elem_width elem) 1
     | _, false ->
       let (ep, jb) = inline_elem_addr fc seqp iv elem in
       let bits = bits_of fc v in
       let w = elem_width elem * 8 in
       (if w < 128 then begin
          let sv = fresh_r fc in
          emitf fc "  %s = trunc i128 %s to i%d" sv bits w;
          emitf fc "  store i%d %s, ptr %s, align 1" w sv ep
        end else
          emitf fc "  store i128 %s, ptr %s, align 1" bits ep);
       emitf fc "  br label %%%s" jb;
       emitf fc "%s:" jb)
  | MSeqGet (d, base, idx, elem) ->
    (* 非 string 元素走内联路径：边界检查 + 直接 load 元素位模式，
       再按元素类型还原（窄整数截断/位转换）；string 仍走运行时。 *)
    (match elem with
     | TString ->
       let tmp = fresh_r fc in
       emitf_entry fc "  %s = alloca i128" tmp;
       let (seqp, _) = val_of fc base in
       let (iv, _) = val_of fc idx in
       emitf fc "  call void @zfy_seq_get(ptr %s, i64 %s, ptr %s, i32 %d, i8 %d)"
         seqp iv tmp (elem_width elem) (elem_signed elem);
       let raw = fresh_r fc in
       emitf fc "  %s = load i128, ptr %s" raw tmp;
       let (v, _) = from_bits fc raw elem in
       Hashtbl.replace fc.regs d v
     | _ ->
       let (seqp, _) = val_of fc base in
       let (iv, _) = val_of fc idx in
       let (ep, jb) = inline_elem_addr fc seqp iv elem in
       let raw = fresh_r fc in
       let w = elem_width elem * 8 in
       emitf fc "  %s = load i%d, ptr %s, align 1" raw w ep;
       (* 按元素宽度读出后扩展回 i128 位模式（窄整数符号扩展，复刻
          运行时 zfy_seq_get 语义），再交给 from_bits 还原元素类型 *)
       let bits =
         if w >= 128 then raw
         else begin
           let ext = (match elem with TInt _ -> "sext" | _ -> "zext") in
           let r = fresh_r fc in
           emitf fc "  %s = %s i%d %s to i128" r ext w raw;
           r
         end
       in
       emitf fc "  br label %%%s" jb;
       emitf fc "%s:" jb;
       let (v, _) = from_bits fc bits elem in
       Hashtbl.replace fc.regs d v)
  | MSeqLen (d, base) ->
    (* 读 zfy.seq 的 len 字段（第 3 个字段） *)
    let (seqp, _) = val_of fc base in
    let lp = fresh_r fc in
    emitf fc "  %s = getelementptr inbounds %%zfy.seq, ptr %s, i32 0, i32 2" lp seqp;
    let r = fresh_r fc in
    emitf fc "  %s = load i64, ptr %s" r lp;
    Hashtbl.replace fc.regs d r
  | MSeqSlice (d, src, a, b, st, is_str) ->
    (* 数组/列表切片：运行时生成新 seq（元素深拷贝，string 元素 strdup） *)
    let (sv, _) = val_of fc src in
    let (av, _) = val_of fc a in
    let (bv, _) = val_of fc b in
    let (stv, _) = val_of fc st in
    let r = fresh_r fc in
    emitf fc "  %s = call ptr @zfy_seq_slice(ptr %s, i64 %s, i64 %s, i64 %s, i8 %d)"
      r sv av bv stv (if is_str then 1 else 0);
    Hashtbl.replace fc.regs d r

(* ---------- 终结符 ---------- *)

let block_label bid = Printf.sprintf "b%d" bid

let zero_value g (t : zty) : string =
  match t with
  | TInt _ | TUint _ -> "0"
  | TFloat _ -> "0.0"
  | TBool -> "false"
  | TChar -> "0"
  | TString -> "null"
  | _ -> lerr None "该类型不能作为返回默认值"

let gen_term fc (t : term) =
  match t with
  | TBr b -> emitf fc "  br label %%%s" (block_label b)
  | TCondBr (o, a, b) ->
    let (v, _) = val_of fc o in
    emitf fc "  br i1 %s, label %%%s, label %%%s" v (block_label a) (block_label b)
  | TRet None ->
    if fc.fret = TVoid || is_agg fc.fret then emitf fc "  ret void"
    else emitf fc "  ret %s %s" (ll_ty fc.fret) (zero_value fc.g fc.fret)
  | TRet (Some o) ->
    if is_agg o.oty then begin
      let (sp, _) = ptr_of fc o in
      gen_memcpy fc "%out" sp (size_of fc.g o.oty);
      emitf fc "  ret void"
    end
    else begin
      let (v, t) = val_of fc o in
      (* string 字面量 intern 为全局常量；返回前 strdup 一份堆串，
         避免调用方把返回值当临时串释放时破坏常量 *)
      let v =
        match (o.oty, o.o) with
        | TString, OStr _ ->
          let r = fresh_r fc in
          emitf fc "  %s = call ptr @zfy_strdup(ptr %s)" r v;
          r
        | _ -> v
      in
      emitf fc "  ret %s %s" t v
    end
  | TUnreachable -> emitf fc "  unreachable"

(* ---------- 函数生成 ---------- *)

let gen_fn g (f : mfn) : string =
  if Sys.getenv_opt "ZFY_DEBUG" = Some "1" then
    Printf.eprintf "[llvmgen] %s\n" f.mname;
  let buf = Buffer.create 512 in
  let ebuf = Buffer.create 256 in
  let body = Buffer.create 512 in
  let fc =
    { g; buf = body; ebuf; nr = 0; allocas = Hashtbl.create 16; regs = Hashtbl.create 16;
      fret = f.mret; nl = 0 }
  in
  let ret_ll = if is_agg f.mret then "void" else ll_ty f.mret in
  let sret_part =
    if is_agg f.mret then Printf.sprintf "ptr sret(%s) %%out, " (ll_ty f.mret)
    else ""
  in
  let params_ll =
    String.concat ", "
      (List.map
         (fun (n, t) ->
           if is_agg t then Printf.sprintf "ptr %%%s" n
           else Printf.sprintf "%s %%%s" (ll_ty t) n)
         f.mparams)
  in
  let fname = if f.mname = "main" then "@zfy.main" else "@" ^ f.mname in
  Buffer.add_string buf
    (Printf.sprintf "define %s %s(%s%s) {\n" ret_ll fname sret_part params_ll);
  (* 参数落槽（所有权传参约定：string/数组/列表实参的指针值即资源本体，
     直接接管进本地槽，不再克隆——调用方对非 move 实参已先行克隆） *)
  List.iter
    (fun (n, t) ->
      let addr = Printf.sprintf "%%v.%s" n in
      emitf fc "  %s = alloca %s" addr (ll_ty t);
      Hashtbl.replace fc.allocas n (addr, t);
      if is_agg t then begin
        (* frac：借传槽地址，值拷贝（memcpy 语义） *)
        let r = fresh_r fc in
        emitf fc "  %s = load %s, ptr %%%s" r (ll_ty t) n;
        emitf fc "  store %s %s, ptr %s" (ll_ty t) r addr
      end
      else if t = TString then
        (* 所有权接管：直接持有调用方移交的堆串 *)
        emitf fc "  store ptr %%%s, ptr %s" n addr
      else
        match t with
        | TArray _ | TList _ ->
          (* 所有权接管：直接持有调用方移交的 seq *)
          emitf fc "  store ptr %%%s, ptr %s" n addr
        | _ ->
          emitf fc "  store %s %%%s, ptr %s" (ll_ty t) n addr)
    f.mparams;
  (* 基本块（入口块不写标签：参数落槽即入口块前奏） *)
  List.iteri
    (fun i (b : block) ->
      if i > 0 then Buffer.add_string body (block_label b.bid ^ ":\n");
      List.iter (gen_instr fc) b.body;
      (match b.term with
       | Some t -> gen_term fc t
       | None -> emitf fc "  unreachable"))
    f.mblocks;
  (* 组装：函数头 + 入口块 alloca 区 + 参数落槽/基本块 *)
  Buffer.add_buffer buf ebuf;
  Buffer.add_buffer buf body;
  Buffer.add_string buf "}\n";
  Buffer.contents buf

(* ---------- 模块生成 ---------- *)

let gen_program (m : mir) : string =
  let g =
    { mbuf = Buffer.create 512; nstr = 0; globals = Hashtbl.create 16 }
  in
  (* frac 类型定义：{ 分子, 分母 }（预生成全部后缀，未使用的定义合法） *)
  let frac_defs =
    [ "i8", "i8"; "i16", "i16"; "i32", "i32"; "i64", "i64"; "i128", "i128";
      "u8", "i8"; "u16", "i16"; "u32", "i32"; "u64", "i64"; "u128", "i128";
      "f32", "float"; "f64", "double" ]
  in
  List.iter
    (fun (suf, ll) ->
      Buffer.add_string g.mbuf
        (Printf.sprintf "%%frac.%s = type { %s, %s }\n" suf ll ll))
    frac_defs;
  (* 数组/列表与类型定义 *)
  Buffer.add_string g.mbuf "%zfy.seq = type { ptr, ptr, i64 }\n";
  (* 运行时声明 *)
  Buffer.add_string g.mbuf "declare i64 @strlen(ptr)\n";
  Buffer.add_string g.mbuf "declare void @llvm.memcpy.p0.p0.i64(ptr, ptr, i64, i1)\n";
  (* output 运行时函数 *)
  Buffer.add_string g.mbuf "declare void @zfy_print_str(ptr)\n";
  Buffer.add_string g.mbuf "declare void @zfy_print_i64(i64)\n";
  Buffer.add_string g.mbuf "declare void @zfy_print_u64(i64)\n";
  Buffer.add_string g.mbuf "declare void @zfy_print_i128(i128)\n";
  Buffer.add_string g.mbuf "declare void @zfy_print_u128(i128)\n";
  Buffer.add_string g.mbuf "declare void @zfy_print_f64(double)\n";
  Buffer.add_string g.mbuf "declare void @zfy_print_char(i8)\n";
  Buffer.add_string g.mbuf "declare void @zfy_print_bool(i32)\n";
  (* 释放辅助 *)
  Buffer.add_string g.mbuf "declare void @zfy_free_str(ptr)\n";
  Buffer.add_string g.mbuf "declare ptr @zfy_strdup(ptr)\n";
  (* 值 -> string 转换（sep/end/delim 与内建参数的强转） *)
  Buffer.add_string g.mbuf "declare ptr @zfy_tostr_char(i8)\n";
  Buffer.add_string g.mbuf "declare ptr @zfy_tostr_bool(i32)\n";
  Buffer.add_string g.mbuf "declare ptr @zfy_tostr_i64(i64)\n";
  Buffer.add_string g.mbuf "declare ptr @zfy_tostr_u64(i64)\n";
  Buffer.add_string g.mbuf "declare ptr @zfy_tostr_i128(i128)\n";
  Buffer.add_string g.mbuf "declare ptr @zfy_tostr_u128(i128)\n";
  Buffer.add_string g.mbuf "declare ptr @zfy_tostr_f64(double)\n";
  (* prec 输出长度控制 与 string -> 数值解析 *)
  Buffer.add_string g.mbuf "declare ptr @zfy_prec_str(ptr, i64)\n";
  Buffer.add_string g.mbuf "declare i64 @zfy_char_digit(i8)\n";
  Buffer.add_string g.mbuf "declare i64 @zfy_stoi(ptr)\n";
  Buffer.add_string g.mbuf "declare double @zfy_stod(ptr)\n";
  (* input 运行时函数：EOF/解析失败直接报运行时错误退出 *)
  Buffer.add_string g.mbuf "declare void @zfy_input_str(ptr, ptr)\n";
  Buffer.add_string g.mbuf "declare void @zfy_input_i64(ptr, ptr)\n";
  Buffer.add_string g.mbuf "declare void @zfy_input_i128(ptr, ptr)\n";
  Buffer.add_string g.mbuf "declare void @zfy_input_u128(ptr, ptr)\n";
  Buffer.add_string g.mbuf "declare void @zfy_input_f64(ptr, ptr, i32)\n";
  Buffer.add_string g.mbuf "declare void @zfy_input_bool(ptr, ptr)\n";
  Buffer.add_string g.mbuf "declare void @zfy_input_char(ptr, ptr)\n";
  (* 数组/列表运行时函数（按元素宽度存储，未初始化槽位填零值） *)
  Buffer.add_string g.mbuf "declare ptr @zfy_seq_new(i64, i64, i32)\n";
  Buffer.add_string g.mbuf "declare void @zfy_seq_set_w(ptr, i64, ptr, i32, i8)\n";
  Buffer.add_string g.mbuf "declare void @zfy_seq_set_str(ptr, i64, ptr, i8)\n";
  Buffer.add_string g.mbuf "declare void @zfy_seq_get(ptr, i64, ptr, i32, i8)\n";
  Buffer.add_string g.mbuf "declare void @zfy_bounds_fail()\n";
  (* 异常机制：setjmp/longjmp 异常帧（try 区域外零开销） *)
  Buffer.add_string g.mbuf "declare i32 @zfy_try_setup(ptr) returns_twice\n";
  Buffer.add_string g.mbuf "declare void @zfy_try_leave()\n";
  Buffer.add_string g.mbuf "declare ptr @zfy_try_msg()\n";
  Buffer.add_string g.mbuf "declare void @zfy_throw(ptr)\n";
  Buffer.add_string g.mbuf "declare void @zfy_seq_free(ptr, i8)\n";
  Buffer.add_string g.mbuf "declare ptr @zfy_seq_clone(ptr, i8)\n";
  (* 字符串操作运行时函数 *)
  Buffer.add_string g.mbuf "declare i8 @zfy_str_char(ptr, i64)\n";
  Buffer.add_string g.mbuf "declare ptr @zfy_str_slice(ptr, i64, i64, i64)\n";
  Buffer.add_string g.mbuf "declare i64 @zfy_str_find(ptr, i8, i64)\n";
  Buffer.add_string g.mbuf "declare ptr @zfy_str_trim(ptr, i8)\n";
  Buffer.add_string g.mbuf "declare ptr @zfy_str_trim_str(ptr, ptr)\n";
  Buffer.add_string g.mbuf "declare ptr @zfy_str_replace(ptr, i64, i64, ptr)\n";
  Buffer.add_string g.mbuf "declare ptr @zfy_str_replace_from(ptr, i64, ptr)\n";
  Buffer.add_string g.mbuf "declare ptr @zfy_str_concat(ptr, ptr)\n";
  Buffer.add_string g.mbuf "declare ptr @zfy_str_split(ptr, i8)\n";
  Buffer.add_string g.mbuf "declare ptr @zfy_str_split_str(ptr, ptr)\n";
  Buffer.add_string g.mbuf "declare ptr @zfy_seq_slice(ptr, i64, i64, i64, i8)\n";
  (* frac 运行时函数声明（12 后缀 × add/sub/mul/div + 比较 + reduce/print） *)
  let sufs = [ "i8"; "i16"; "i32"; "i64"; "i128"; "u8"; "u16"; "u32"; "u64";
               "u128"; "f32"; "f64" ] in
  let ops = [ "add"; "sub"; "mul"; "div"; "eq"; "ne"; "lt"; "gt"; "le"; "ge" ] in
  List.iter
    (fun suf ->
      List.iter
        (fun opn ->
          if List.mem opn [ "eq"; "ne"; "lt"; "gt"; "le"; "ge" ] then
            Buffer.add_string g.mbuf
              (Printf.sprintf "declare i1 @zfy_frac_%s_%s(ptr, ptr)\n" opn suf)
          else
            Buffer.add_string g.mbuf
              (Printf.sprintf
                 "declare void @zfy_frac_%s_%s(ptr sret(%%frac.%s), ptr, ptr)\n"
                 opn suf suf))
        ops;
      Buffer.add_string g.mbuf
    (Printf.sprintf "declare void @zfy_frac_reduce_%s(ptr, i64, i64)\n" suf);
      Buffer.add_string g.mbuf
        (Printf.sprintf "declare void @zfy_frac_norm_%s(ptr)\n" suf);
      Buffer.add_string g.mbuf
        (Printf.sprintf "declare void @zfy_frac_print_%s(ptr)\n" suf);
      Buffer.add_string g.mbuf
        (Printf.sprintf "declare ptr @zfy_frac_str_%s(ptr)\n" suf))
    sufs;
  (* remove 运行时函数：数组槽位填零 / 列表删除并左移 *)
  Buffer.add_string g.mbuf "declare void @zfy_seq_zero(ptr, i64, i8)\n";
  Buffer.add_string g.mbuf "declare void @zfy_seq_remove(ptr, i64, i8)\n";
  Buffer.add_string g.mbuf
    "declare void @zfy_seq_aug_range(ptr, i64, i64, i64, i32, ptr, i32, i32, i32)\n";
  (* 函数 *)
  let fbuf = Buffer.create 4096 in
  let main_ret = ref None in
  List.iter
    (fun (f : mfn) ->
      if f.mname = "main" then main_ret := Some f.mret;
      Buffer.add_string fbuf (gen_fn g f))
    m.mfns;
  (* main 包装：C 运行时要求 i32 main()；最先执行 zfy.globals 完成顶层变量初始化 *)
  (match !main_ret with
   | Some TVoid ->
     Buffer.add_string fbuf
       "define i32 @main() {\n  call void @zfy.globals()\n  call void @zfy.main()\n  ret i32 0\n}\n"
   | Some (TInt 64 as rt) ->
     Buffer.add_string fbuf
       (Printf.sprintf
          "define i32 @main() {\n  call void @zfy.globals()\n  %%r = call i64 @zfy.main()\n  %%t = trunc i64 %%r to i32\n  ret i32 %%t\n}\n")
   | Some rt ->
     lerr None "main 的返回类型只能是 void 或 i64，得到 %s" (Hir.pp_zty rt)
   | None -> ());
  Buffer.contents g.mbuf ^ Buffer.contents fbuf
