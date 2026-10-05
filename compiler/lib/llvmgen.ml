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
  | TFloat n -> lerr None "unsupported float width f%d" n
  | TBool -> "i1"
  | TChar -> "i8"
  | TString -> "ptr"
  | TVoid -> "void"
  | TFrac e -> Printf.sprintf "%%frac.%s" (Hir.suffix_of e)
  | TArray _ | TList _ -> "ptr"      (* 槽内是指向 zfy_seq 的指针 *)
  | TStruct s -> Printf.sprintf "%%struct.%s" s
  | TPtr _ | TFunSig _ -> "ptr"      (* 指针/函数指针：裸地址 *)
  | TErr e ->
    (* T! 错误值聚合：%err.<elem> = { i32 code; ptr msg; <value 容器> }。
       value 容器统一 8 字节：整数/bool/char → i64，浮点 → double（C 端
       zfy_stod_err 按 double 写），string/指针 → ptr（与 C 端 zfy_err
       { int32_t; char*; union {int64_t; double; void*} } 布局一致） *)
    (match e with
     | TInt 128 | TUint 128 | TFloat 128 ->
       lerr None "error value element type does not support 128-bit width (T! is limited to <=64-bit scalars/string/pointers)"
     | TFloat w -> Printf.sprintf "%%err.f%d" w
     | TInt w -> Printf.sprintf "%%err.i%d" w
     | TUint w -> Printf.sprintf "%%err.u%d" w
     | TBool -> "%err.bool"
     | TChar -> "%err.char"
     | TString -> "%err.str"
     | TPtr _ -> "%err.ptr"
     | _ -> lerr None "invalid error value element type (scalar/string/pointer only)")
  | TVar _ -> lerr None "unresolved type variable"

(* frac 与 struct 是真正的 LLVM 聚合；数组/列表槽是 ptr 标量 *)
let is_agg = function TFrac _ | TStruct _ | TErr _ -> true | _ -> false

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
  structs : sdef list;             (* struct 定义表（布局与辅助函数生成用） *)
}

let struct_ty_name (s : string) : string = Printf.sprintf "%%struct.%s" s

let find_struct (g : gctx) (s : string) : sdef option =
  List.find_opt (fun sd -> sd.sname = s) g.structs

let rec size_of g (t : zty) : int =
  match t with
  | TInt n | TUint n -> n / 8
  | TFloat n -> n / 8
  | TBool | TChar -> 1
  | TString -> 8
  | TPtr _ | TFunSig _ -> 8
  | TFrac e -> 2 * size_of g e
  | TArray _ | TList _ -> 8        (* 槽：seq 指针 *)
  | TErr _ -> 24                   (* { i32 code; ptr msg; 8 字节 value 容器 } *)
  | TStruct s ->
    (match find_struct g s with
     | Some sd -> fst (Hir.struct_size_align g.structs sd)
     | None -> lerr None "undefined struct %s" s)
  | TVoid | TVar _ -> lerr None "cannot determine type size"

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
  | _ -> lerr None "unsupported array/list element type"

(* 标量操作数 -> LLVM 值 *)
let rec val_of fc (o : operand) : string * string =
  let t = ll_ty o.oty in
  match o.o with
  | OInt n ->
    (match o.oty with
     | TFloat w ->
       let f = Int64.to_float n in
       (float_const o.oty f, ll_ty (TFloat w))
     | TPtr _ | TFunSig _ ->
       if n = 0L then ("null", t)
       else lerr None "pointer constant must be null"
     | _ -> (Printf.sprintf "%Ld" n, t))
  | OFloat f -> (float_const o.oty f, t)
  | OBool b -> ((if b then "1" else "0"), t)
  | OChar c -> (string_of_int (Char.code c), t)
  | OStr s -> (str_value fc s, t)
  | OLocal n ->
    if Hashtbl.mem fc.regs n then (Hashtbl.find fc.regs n, t)
    else if Hashtbl.mem fc.allocas n then begin
      if is_agg o.oty then lerr None "aggregate value %s must be used as a pointer" n;
      let (addr, _) = Hashtbl.find fc.allocas n in
      let r = fresh_r fc in
      emitf fc "  %s = load %s, ptr %s" r t addr;
      (r, t)
    end
    else lerr None "undefined local variable %s" n

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
  | _ -> lerr None "type cannot be stored as an array/list element"

(* 聚合操作数 -> 指针（槽位地址） *)
let ptr_of fc (o : operand) : string * string =
  let dbg = function
    | OInt n -> Printf.sprintf "OInt %Ld" n
    | OFloat f -> Printf.sprintf "OFloat %g" f
    | OStr s -> Printf.sprintf "OStr \"%s\"" (String.escaped s)
    | OBool b -> Printf.sprintf "OBool %b" b
    | OChar c -> Printf.sprintf "OChar %C" c
    | OLocal n -> Printf.sprintf "OLocal %s" n
  in
  match o.o with
  | OLocal n ->
    if Hashtbl.mem fc.allocas n then
      let (addr, ty) = Hashtbl.find fc.allocas n in
      (addr, ll_ty ty)
    else lerr None "undefined variable %s" n
  | _ -> lerr None "expected aggregate local: %s (oty=%s)" (dbg o.o) (Hir.pp_zty o.oty)

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
  if is_agg a.oty then lerr None "aggregate type does not support arithmetic";
  let (va, tya) = val_of fc a and (vb, _) = val_of fc b in
  match a.oty with
  | TPtr _ ->
    (* 指针运算（typeck 限定 unsafe 块内）：p±n 走 GEP（按指向元素步长），
       p-q 走 ptrtoint 差再除元素大小；比较按地址 icmp *)
    let elem = (match a.oty with TPtr e -> e | _ -> assert false) in
    let b_is_ptr = (match b.oty with TPtr _ | TFunSig _ -> true | _ -> false) in
    (match bop with
     | BAdd when not b_is_ptr ->
       emitf fc "  %s = getelementptr inbounds %s, ptr %s, i64 %s"
         d (ll_ty elem) va vb
     | BSub when b_is_ptr ->
       let ia = fresh_r fc in
       emitf fc "  %s = ptrtoint ptr %s to i64" ia va;
       let ib = fresh_r fc in
       emitf fc "  %s = ptrtoint ptr %s to i64" ib vb;
       let raw = fresh_r fc in
       emitf fc "  %s = sub i64 %s, %s" raw ia ib;
       emitf fc "  %s = sdiv i64 %s, %d" d raw (size_of fc.g elem)
     | BSub ->
       let neg = fresh_r fc in
       emitf fc "  %s = sub i64 0, %s" neg vb;
       emitf fc "  %s = getelementptr inbounds %s, ptr %s, i64 %s"
         d (ll_ty elem) va neg
     | BEq | BNe | BLt | BGt | BLe | BGe ->
       emitf fc "  %s = icmp %s ptr %s, %s" d (cmp_op_int false bop) va vb
     | _ -> lerr None "unsupported pointer operation")
  | TFloat _ ->
    (match bop with
     | BAdd -> emitf fc "  %s = fadd %s %s, %s" d tya va vb
     | BSub -> emitf fc "  %s = fsub %s %s, %s" d tya va vb
     | BMul -> emitf fc "  %s = fmul %s %s, %s" d tya va vb
     | BDiv -> emitf fc "  %s = fdiv %s %s, %s" d tya va vb
     | BMod -> lerr None "float type does not support modulo"
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
     | _ -> lerr None "bool type does not support this operation")
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
  if is_agg a.oty then lerr None "aggregate type does not support unary operations";
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
  | _ -> lerr None "type cannot convert to string"

let gen_cast fc d (a : operand) (t : zty) =
  if is_agg a.oty || is_agg t then lerr None "aggregate type does not support cast";
  let (va, ta) = val_of fc a in
  let tb = ll_ty t in
  let int_like = function TInt _ | TUint _ | TBool | TChar -> true | _ -> false in
  let is_unsigned = function TUint _ -> true | _ -> false in
  if ta = tb then begin
    match a.oty with
    | TFloat _ -> emitf fc "  %s = fadd %s %s, 0.0" d ta va
    | TPtr _ | TFunSig _ -> emitf fc "  %s = bitcast ptr %s to ptr" d va
    | _ -> emitf fc "  %s = add %s %s, 0" d ta va
  end
  else
    match a.oty, t with
    | (TPtr _ | TFunSig _), (TPtr _ | TFunSig _) ->
      emitf fc "  %s = bitcast ptr %s to ptr" d va
    | (TInt 64 | TUint 64), (TPtr _ | TFunSig _) ->
      emitf fc "  %s = inttoptr i64 %s to ptr" d va
    | (TPtr _ | TFunSig _), (TInt 64 | TUint 64) ->
      emitf fc "  %s = ptrtoint ptr %s to i64" d va
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
    | _ -> lerr None "unsupported conversion %s -> %s" ta tb

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
  | _ -> lerr None "unsupported array/list element type"

(* 元素读出时的扩展方式：有符号整数符号扩展，其余零扩展 *)
let elem_signed (e : zty) : int =
  match e with TInt _ -> 1 | _ -> 0

(* 内联元素地址：边界检查（icmp ult 同时覆盖负下标：负数无符号比较必失败）
   + GEP 到元素字节地址。checked=false（unsafe 块内）跳过检查直接寻址。
   失败路径调用 zfy_bounds_fail（不返回）后 unreachable。
   返回 (元素地址, join 标签)：调用方在快速块内完成 load/store 后须
   `br label %join` 收尾；join 块只有一个前驱（快速块），无需 phi。 *)
let inline_elem_addr fc (seqp : string) (iv : string) (elem : zty) ~(checked : bool) : string * string =
  let dp0 = fresh_r fc in
  emitf fc "  %s = load ptr, ptr %s" dp0 seqp;
  if not checked then begin
    (* unsafe：跳过边界检查，直接 GEP 元素地址 *)
    let off = fresh_r fc in
    emitf fc "  %s = mul i64 %s, %d" off iv (elem_width elem);
    let ep = fresh_r fc in
    emitf fc "  %s = getelementptr inbounds i8, ptr %s, i64 %s" ep dp0 off;
    (ep, fresh_lbl fc)   (* join 标签由调用方 br 收尾（无phi，同检查路径） *)
  end
  else begin
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
    let off = fresh_r fc in
    emitf fc "  %s = mul i64 %s, %d" off iv (elem_width elem);
    let ep = fresh_r fc in
    emitf fc "  %s = getelementptr inbounds i8, ptr %s, i64 %s" ep dp0 off;
    (ep, jb)
  end

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
  | _ -> lerr None "output does not support this argument type"

(* 读入一段输入存入变量槽：runtime 按 delim 分段、解析并写入值槽
   （EOF 或解析失败直接报运行时错误退出）；delim 为空串时用
   默认"换行和空格"字符集（' ' 或 '\n' 任一命中即切分） *)
let gen_input fc name (ty : zty) delim =
  match Hashtbl.find_opt fc.allocas name with
  | None -> lerr None "undefined variable %s" name
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
      | TErr e ->
        (* T! 目标：失败不退出，写错误值（code=INPUT, msg=原因）；value 容器按元素 *)
        (match e with
         | TInt _ | TUint _ -> ("zfy_input_err_i64", "")
         | TFloat 16 | TFloat 32 | TFloat 64 -> ("zfy_input_err_f64", "")
         | TString -> ("zfy_input_err_str", "")
         | TBool -> ("zfy_input_err_bool", "")
         | TChar -> ("zfy_input_err_char", "")
         | _ -> lerr None "input does not support this error-value element type")
      | _ -> lerr None "input does not support this target type"
    in
    emitf fc "  call void @%s(ptr %s, ptr %s%s)"
      fname addr dp extra

(* ---------- 内建函数 ---------- *)

(* 9d：i128 判定（extern "C" 的 __int128 ABI 适配用） *)
let is_i128 = function TInt 128 | TUint 128 -> true | _ -> false

let gen_call fc dst name (args : operand list) (ret_ty : zty) =
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
         | _ -> lerr None "invalid prec length parameter type"
       in
       let sp = tostr_ptr fc v in
       emitf fc "  %s = call ptr @zfy_prec_str(ptr %s, i64 %s)" d sp n64)
  | _ ->
    let callee = if name = "main" then "@zfy.main" else "@" ^ name in
    let is_ext = Hashtbl.mem Typeck.extern_fns name in
    let targs =
      List.map
        (fun (o : operand) ->
          if is_agg o.oty then begin
            (* 聚合参数按指针传递 *)
            let (p, _) = ptr_of fc o in
            ("ptr", p)
          end
          else if is_ext && is_i128 o.oty then begin
            (* 9d：extern i128 参数按引用传（clang win32 __int128 ABI） *)
            let a = fresh_r fc in
            emitf_entry fc "  %s = alloca i128" a;
            let (v, _) = val_of fc o in
            emitf fc "  store i128 %s, ptr %s" v a;
            ("ptr", a)
          end
          else
            let (v, t) = val_of fc o in
            (t, v))
        args
    in
    let args_str =
      String.concat ""
        (List.map (fun (t, v) -> Printf.sprintf ", %s %s" t v) targs)
    in
    if is_agg ret_ty then begin
      match dst with
      | None -> lerr None "aggregate return value must be captured"
      | Some d ->
        if not (Hashtbl.mem fc.allocas d) then
          lerr None "aggregate return value must be captured into a variable";
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
      | rt, Some d when is_ext && is_i128 rt ->
        (* 9d：extern i128 返回值按 <2 x i64> 接收后 bitcast（clang win32 ABI） *)
        let r = fresh_r fc in
        emitf fc "  %s = call <2 x i64> %s(%s)" r callee args_str;
        emitf fc "  %s = bitcast <2 x i64> %s to i128" d r
      | rt, Some d ->
        emitf fc "  %s = call %s %s(%s)" d (ll_ty rt) callee args_str
      | _ -> lerr None "non-void return value must be used"
    end

(* ---------- 用户函数调用（所有权传参） ---------- *)

(* 用户定义函数名集合：MCallOwn 仅对用户函数生效；内建/运行时调用走普通调用 *)
let user_fns : (string, unit) Hashtbl.t = Hashtbl.create 16

(* MCallOwn 实参：move=true 直接移交指针值；false 由调用方克隆（值语义）。
   frac 借传槽地址（被调方 memcpy 值拷贝） *)
let own_arg fc (o : operand) (mv : bool) : string * string =
  match o.oty with
  | TFrac _ ->
    let (p, _) = ptr_of fc o in
    ("ptr", p)
  | TErr _ ->
    (* 错误值：借传槽地址（被调方 memcpy 接管，值语义） *)
    let (p, _) = ptr_of fc o in
    ("ptr", p)
  | TStruct _ ->
    (* struct 始终借传槽地址：被调方深拷贝接管（值语义），调用方槽保持不变 *)
    let (p, _) = ptr_of fc o in
    ("ptr", p)
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
  | _ -> let (v, t) = val_of fc o in (t, v)

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
    | None -> lerr None "aggregate return value must be captured"
    | Some d ->
      if not (Hashtbl.mem fc.allocas d) then
        lerr None "aggregate return value must be captured into a variable";
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
    | _ -> lerr None "non-void return value must be used"
  end;
  (* move 的变量实参：调用完成后清槽（所有权已移交，防 RAII 双释放） *)
  List.iter
    (fun (n, ty) ->
      let (dstp, _) = ptr_of fc (operand_of_name n ty) in
      emitf fc "  store ptr null, ptr %s" dstp)
    clears

(* ---------- 指令生成 ---------- *)

(* ---------- struct 字段访问辅助 ---------- *)

(* 按字段序号链逐级 GEP（LLVM 布局与 hir 手算 C 布局一致）；
   中间层为 TPtr(TStruct) 时先 load 解引用再继续（链式指针字段 p.next.x） *)
let rec gen_field_path fc (p : string) (ty : zty) (idxs : int list) : string =
  match idxs with
  | [] -> p
  | i :: rest ->
    let (p, ty) =
      match ty with
      | TPtr t' ->
        let ld = fresh_r fc in
        emitf fc "  %s = load ptr, ptr %s" ld p;
        (ld, t')
      | _ -> (p, ty)
    in
    let s =
      match ty with
      | TStruct s -> s
      | _ -> lerr None "field access target is not a struct"
    in
    let fp = gen_gep fc p (ll_ty ty) i in
    let fty =
      match find_struct fc.g s with
      | Some sd ->
        (match List.nth_opt sd.sfields i with
         | Some (_, ft) -> ft
         | None -> lerr None "struct %s has no field index %d" s i)
      | None -> lerr None "undefined struct %s" s
    in
    gen_field_path fc fp fty rest

(* 字段写入（值语义：深拷贝新值；free_old 时先释放旧资源） *)
let gen_field_store ~(free_old : bool) fc (fp : string) (v : operand) : unit =
  match v.oty with
  | TString ->
    if free_old then begin
      let old = fresh_r fc in
      emitf fc "  %s = load ptr, ptr %s" old fp;
      emitf fc "  call void @zfy_free_str(ptr %s)" old
    end;
    let (sv, _) = val_of fc v in
    let r = fresh_r fc in
    emitf fc "  %s = call ptr @zfy_strdup(ptr %s)" r sv;
    emitf fc "  store ptr %s, ptr %s" r fp
  | TArray _ | TList _ ->
    let fe = (match v.oty with TArray (TString, _) | TList TString -> 1 | _ -> 0) in
    if free_old then begin
      let old = fresh_r fc in
      emitf fc "  %s = load ptr, ptr %s" old fp;
      emitf fc "  call void @zfy_seq_free(ptr %s, i8 %d)" old fe
    end;
    let (sv, _) = val_of fc v in
    let r = fresh_r fc in
    emitf fc "  %s = call ptr @zfy_seq_clone(ptr %s, i8 %d)" r sv fe;
    emitf fc "  store ptr %s, ptr %s" r fp
  | TStruct s ->
    let (sp, _) = ptr_of fc v in
    emitf fc "  call void @zfy_struct_assign_%s(ptr %s, ptr %s)" s fp sp
  | _ ->
    let (vv, tt) = val_of fc v in
    emitf fc "  store %s %s, ptr %s" tt vv fp

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
       | TErr _ ->
         (* 错误值聚合：memcpy（msg 指针共享但 strdup 泄漏约定下安全；
         code≠0 时 value 不读，浅拷无悬垂风险） *)
         let (srcp, _) = ptr_of fc v in
         gen_memcpy fc dstp srcp (size_of fc.g ty)
       | TStruct s ->
         (* 深拷贝 struct：assign 先释放旧资源再逐字段复制 *)
         let (sp, _) = ptr_of fc v in
         emitf fc "  call void @zfy_struct_assign_%s(ptr %s, ptr %s)" s dstp sp
       | _ ->
         let (v', t) = val_of fc v in
         let tt = ll_ty ty in
         if t <> tt then lerr None "slot type %s does not match value type %s" tt t;
         emitf fc "  store %s %s, ptr %s" tt v' dstp)
    end
  | MStrAppend (name, ops) ->
    (* string 原地追加（T7 优化）：槽独占堆串 realloc 扩容逐个并入，
       槽指针所有权保留（不 free 旧串）；realloc 可能移动缓冲区，
       typeck 保证操作数不引用槽本身 *)
    let (dstp, _) = ptr_of fc (operand_of_name name TString) in
    let cur0 = fresh_r fc in
    emitf fc "  %s = load ptr, ptr %s" cur0 dstp;
    let cur =
      List.fold_left
        (fun cur (o : operand) ->
          let (vv, _) = val_of fc o in
          let r = fresh_r fc in
          emitf fc "  %s = call ptr @zfy_str_append(ptr %s, ptr %s)" r cur vv;
          r)
        cur0 ops
    in
    emitf fc "  store ptr %s, ptr %s" cur dstp
  | MMoveSeq (name, v, ty) ->
    (* 所有权转移：释放目标旧值后直接接管临时（免克隆）。
       临时从 stmt_temps 移除，语句末不会再释放（mir 侧保证）。 *)
    let (dstp, _) = ptr_of fc (operand_of_name name ty) in
    (match ty with
     | TStruct s ->
       (* struct：释放目标旧资源后槽 memcpy（资源所有权随临时移交） *)
       emitf fc "  call void @zfy_struct_free_%s(ptr %s)" s dstp;
       let (sp, _) = ptr_of fc v in
       gen_memcpy fc dstp sp (size_of fc.g ty)
     | _ ->
       let ov = fresh_r fc in
       emitf fc "  %s = load ptr, ptr %s" ov dstp;
       (match ty with
        | TString -> emitf fc "  call void @zfy_free_str(ptr %s)" ov
        | _ ->
          let fe = (match ty with TArray (TString, _) | TList TString -> 1 | _ -> 0) in
          emitf fc "  call void @zfy_seq_free(ptr %s, i8 %d)" ov fe);
       let (sv, st) = val_of fc v in
       if st <> "ptr" then lerr None "invalid move target slot type %s" st;
       emitf fc "  store ptr %s, ptr %s" sv dstp)
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
    if Hashtbl.mem user_fns name || name = "main" then begin
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
    end else begin
      (* 内建/运行时调用：无所有权语义，退化为普通调用 *)
      let plain = List.map fst args in
      (match d with
       | Some d' when is_agg ret ->
         let addr = fresh_r fc in
         emitf_entry fc "  %s = alloca %s" addr (ll_ty ret);
         Hashtbl.replace fc.allocas d' (addr, ret);
         gen_call fc (Some d') name plain ret
       | _ ->
         gen_call fc d name plain ret;
         (match d with
          | Some d' when ret <> TVoid ->
            Hashtbl.replace fc.regs d' d'
          | _ -> ()))
    end
  | MErrNew (d, ty, code, msg) ->
    (* fail(code, msg)：错误值槽清零后写 code/msg（value 保持 0 = 元素零值，
       误读安全）；msg strdup 一份永不释放（有意的最小泄漏，免生命周期管理） *)
    let addr = fresh_r fc in
    emitf_entry fc "  %s = alloca %s" addr (ll_ty ty);
    Hashtbl.replace fc.allocas d (addr, ty);
    emitf fc "  store %s zeroinitializer, ptr %s" (ll_ty ty) addr;
    let cp = gen_gep fc addr (ll_ty ty) 0 in
    let (cv, ct) = val_of fc code in
    if ct <> "i32" then lerr None "fail's code must be i32";
    emitf fc "  store i32 %s, ptr %s" cv cp;
    let mp = gen_gep fc addr (ll_ty ty) 1 in
    let (mv, _) = val_of fc msg in
    let r = fresh_r fc in
    emitf fc "  %s = call ptr @zfy_strdup(ptr %s)" r mv;
    emitf fc "  store ptr %s, ptr %s" r mp
  | MErrOk (d, ty, v) ->
    (* 成功包装：错误值槽清零（code=0, msg=null）后写 value 字段。
       string 元素 strdup 深拷贝（值语义）；标量按容器宽度转换 *)
    let addr = fresh_r fc in
    emitf_entry fc "  %s = alloca %s" addr (ll_ty ty);
    Hashtbl.replace fc.allocas d (addr, ty);
    emitf fc "  store %s zeroinitializer, ptr %s" (ll_ty ty) addr;
    let vp = gen_gep fc addr (ll_ty ty) 2 in
    let elem = (match ty with TErr e -> e | _ -> lerr None "MErrOk type error: %s" (Hir.pp_zty ty)) in
    (match elem with
     | TString ->
       let (sv, _) = val_of fc v in
       let r = fresh_r fc in
       emitf fc "  %s = call ptr @zfy_strdup(ptr %s)" r sv;
       emitf fc "  store ptr %s, ptr %s" r vp
     | TPtr _ ->
       let (pv, pt) = val_of fc v in
       emitf fc "  store %s %s, ptr %s" pt pv vp
     | TFloat 64 ->
       let (fv, ft) = val_of fc v in
       emitf fc "  store %s %s, ptr %s" ft fv vp
     | TFloat _ ->
       let (fv, ft) = val_of fc v in
       let d64 = fresh_r fc in
       emitf fc "  %s = fpext %s %s to double" d64 ft fv;
       emitf fc "  store double %s, ptr %s" d64 vp
     | TBool ->
       let (bv, _) = val_of fc v in
       let z = fresh_r fc in
       emitf fc "  %s = zext i1 %s to i64" z bv;
       emitf fc "  store i64 %s, ptr %s" z vp
     | TChar ->
       let (cv2, _) = val_of fc v in
       let z = fresh_r fc in
       emitf fc "  %s = zext i8 %s to i64" z cv2;
       emitf fc "  store i64 %s, ptr %s" z vp
     | TUint _ ->
       let (iv, it) = val_of fc v in
       let z =
         if it = "i64" then iv
         else begin
           let r = fresh_r fc in
           emitf fc "  %s = zext %s %s to i64" r it iv;
           r
         end
       in
       emitf fc "  store i64 %s, ptr %s" z vp
     | TInt _ ->
       let (iv, it) = val_of fc v in
       let z =
         if it = "i64" then iv
         else begin
           let r = fresh_r fc in
           emitf fc "  %s = sext %s %s to i64" r it iv;
           r
         end
       in
       emitf fc "  store i64 %s, ptr %s" z vp
     | _ -> lerr None "invalid error value element type")
  | MErrIsOk (d, slot, ty) ->
    (* 判定成功：code == 0 *)
    let (sp, _) = ptr_of fc slot in
    let cp = gen_gep fc sp (ll_ty ty) 0 in
    let c = fresh_r fc in
    emitf fc "  %s = load i32, ptr %s" c cp;
    let r = fresh_r fc in
    emitf fc "  %s = icmp eq i32 %s, 0" r c;
    Hashtbl.replace fc.regs d r
  | MErrValue (d, slot, ty) ->
    (* 取成功值：load value 字段并按元素类型还原（窄整数截断、
       浮点 fptrunc、string/指针 inttoptr 由容器类型直接匹配） *)
    let (sp, _) = ptr_of fc slot in
    let vp = gen_gep fc sp (ll_ty ty) 2 in
    let elem = (match ty with TErr e -> e | _ -> lerr None "MErrValue type error") in
    (match elem with
     | TString | TPtr _ ->
       let r = fresh_r fc in
       emitf fc "  %s = load ptr, ptr %s" r vp;
       Hashtbl.replace fc.regs d r
     | TFloat 64 ->
       let r = fresh_r fc in
       emitf fc "  %s = load double, ptr %s" r vp;
       Hashtbl.replace fc.regs d r
     | TFloat _ ->
       let d64 = fresh_r fc in
       emitf fc "  %s = load double, ptr %s" d64 vp;
       let r = fresh_r fc in
       emitf fc "  %s = fptrunc double %s to %s" r d64 (ll_ty elem);
       Hashtbl.replace fc.regs d r
     | TBool ->
       let raw = fresh_r fc in
       emitf fc "  %s = load i64, ptr %s" raw vp;
       let r = fresh_r fc in
       emitf fc "  %s = trunc i64 %s to i1" r raw;
       Hashtbl.replace fc.regs d r
     | TChar ->
       let raw = fresh_r fc in
       emitf fc "  %s = load i64, ptr %s" raw vp;
       let r = fresh_r fc in
       emitf fc "  %s = trunc i64 %s to i8" r raw;
       Hashtbl.replace fc.regs d r
     | TUint w ->
       let raw = fresh_r fc in
       emitf fc "  %s = load i64, ptr %s" raw vp;
       let r =
         if w < 64 then begin
           let t = fresh_r fc in
           emitf fc "  %s = trunc i64 %s to i%d" t raw w;
           t
         end else raw
       in
       Hashtbl.replace fc.regs d r
     | TInt w ->
       let raw = fresh_r fc in
       emitf fc "  %s = load i64, ptr %s" raw vp;
       let r =
         if w < 64 then begin
           let t = fresh_r fc in
           emitf fc "  %s = trunc i64 %s to i%d" t raw w;
           t
         end else raw
       in
       Hashtbl.replace fc.regs d r
     | _ -> lerr None "invalid error value element type")
  | MErrFillErr (errslot, v, ty) ->
    (* TErr 值 → Err struct 槽：拷 code/msg 两字段（Err = { i32 code; ptr msg }） *)
    let (ep, _) = ptr_of fc (operand_of_name errslot (TStruct "Err")) in
    let (sp, _) = ptr_of fc v in
    let cp = gen_gep fc sp (ll_ty ty) 0 in
    let c = fresh_r fc in
    emitf fc "  %s = load i32, ptr %s" c cp;
    let ecp = gen_gep fc ep "%struct.Err" 0 in
    emitf fc "  store i32 %s, ptr %s" c ecp;
    let mp = gen_gep fc sp (ll_ty ty) 1 in
    let m = fresh_r fc in
    emitf fc "  %s = load ptr, ptr %s" m mp;
    let emp = gen_gep fc ep "%struct.Err" 1 in
    emitf fc "  store ptr %s, ptr %s" m emp
  | MErrFillOut (v, ty) ->
    (* a? 失败路径：错误值 memcpy 到 sret 返回槽 %out（随后 TRet None → ret void） *)
    let (sp, _) = ptr_of fc v in
    gen_memcpy fc "%out" sp (size_of fc.g ty)
  | MPanic (code, msg) ->
    (* panic：调 zfy_panic（不可恢复：先调 handler 再退出进程）；
       后继由 mir 置 TUnreachable *)
    let cv =
      match code with
      | Some o ->
        let (v, t) = val_of fc o in
        if t <> "i32" then lerr None "panic's code must be i32";
        v
      | None -> "0"
    in
    let (mv, _) = val_of fc msg in
    emitf fc "  call void @zfy_panic(i32 %s, ptr %s)" cv mv
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
    (* 非 unred frac 槽存入后自动约分 *)
    let elem = (match ty with TFrac e -> e | _ -> lerr None "norm type error") in
    (match Hashtbl.find_opt fc.allocas name with
     | Some (p, _) ->
       emitf fc "  call void @zfy_frac_norm_%s(ptr %s)" (Hir.suffix_of elem) p
     | None -> lerr None "undefined variable %s" name)
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
      | _ -> lerr None "unsupported augmented-assignment operation on slices"
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
      | _ -> lerr None "unsupported element type for slice augmented assignment"
    in
    emitf fc "  store i128 %s, ptr %s" z bits;
    emitf fc
      "  call void @zfy_seq_aug_range(ptr %s, i64 %s, i64 %s, i64 %s, i32 %d, ptr %s, i32 %d, i32 %d, i32 %d)"
      seqp av bv sv opn bits width sgn isf
  | MReduce (root, ty, cnt, start) ->
    (match Hashtbl.find_opt fc.allocas root with
     | Some (p, _) ->
       let elem = (match ty with TFrac e -> e | _ -> lerr None "reduce type error") in
       let callee = Printf.sprintf "@zfy_frac_reduce_%s" (Hir.suffix_of elem) in
       let (cv, _) = val_of fc cnt and (sv, _) = val_of fc start in
       emitf fc "  call void %s(ptr %s, i64 %s, i64 %s)" callee p cv sv
     | None -> lerr None "undefined variable %s" root)
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
        | TStruct s ->
          (* struct：释放内含堆资源后清零槽（防重复释放） *)
          emitf fc "  call void @zfy_struct_free_%s(ptr %s)" s addr;
          emitf fc "  store %s zeroinitializer, ptr %s" (ll_ty ty) addr
        | _ -> ())
     | None -> lerr None "undefined variable %s" name)
  | MFreeTemp name ->
    (* 语句末释放临时堆串（寄存器中持有 malloc 指针） *)
    (match Hashtbl.find_opt fc.regs name with
     | Some v -> emitf fc "  call void @zfy_free_str(ptr %s)" v
     | None -> lerr None "undefined temp %s" name)
  | MFreeSeqTemp (name, is_str) ->
    (* 语句末释放临时 seq（切片结果等） *)
    (match Hashtbl.find_opt fc.regs name with
     | Some v ->
       emitf fc "  call void @zfy_seq_free(ptr %s, i8 %d)" v (if is_str then 1 else 0)
     | None -> lerr None "undefined temp %s" name)
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
  | MSeqSet (name, elem, idx, v, grow, unchecked) ->
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
       let (ep, jb) = inline_elem_addr fc seqp iv elem ~checked:(not unchecked) in
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
  | MSeqGet (d, base, idx, elem, unchecked) ->
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
       let (ep, jb) = inline_elem_addr fc seqp iv elem ~checked:(not unchecked) in
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
  | MStructNew (d, ty, fields) ->
    (* struct 构造：聚合槽清零后逐字段写入（槽已清零，无需释放旧值；
       缺省字段保持零值位模式） *)
    let addr = fresh_r fc in
    emitf_entry fc "  %s = alloca %s" addr (ll_ty ty);
    Hashtbl.replace fc.allocas d (addr, ty);
    emitf fc "  store %s zeroinitializer, ptr %s" (ll_ty ty) addr;
    List.iter
      (fun (idx, v) ->
        let fp = gen_gep fc addr (ll_ty ty) idx in
        gen_field_store ~free_old:false fc fp v)
      fields
  | MFieldGet (d, root, rootty, idxs, fty) ->
    (* 字段读取：GEP 链直达最终字段。标量/string/seq 字段 load 值（借用，
       赋值时才深拷贝）；嵌套 struct 字段深拷贝到目标槽（值语义）。
       根为指针（自动解引用 r.x）时基址 = load 出的指针值，首层按 struct 步进 *)
    let (rp, base_ty) =
      match rootty with
      | TStruct _ -> (fst (ptr_of fc root), rootty)
      | TPtr (TStruct s) -> (fst (val_of fc root), TStruct s)
      | _ -> lerr None "invalid root type for field access"
    in
    let fp = gen_field_path fc rp base_ty idxs in
    (match fty with
     | TStruct s ->
       let addr = fresh_r fc in
       emitf_entry fc "  %s = alloca %s" addr (ll_ty fty);
       emitf fc "  store %s zeroinitializer, ptr %s" (ll_ty fty) addr;
       Hashtbl.replace fc.allocas d (addr, fty);
       emitf fc "  call void @zfy_struct_assign_%s(ptr %s, ptr %s)" s addr fp
     | TString | TArray _ | TList _ ->
       let r = fresh_r fc in
       emitf fc "  %s = load ptr, ptr %s" r fp;
       Hashtbl.replace fc.regs d r
     | _ ->
       let r = fresh_r fc in
       emitf fc "  %s = load %s, ptr %s" r (ll_ty fty) fp;
       Hashtbl.replace fc.regs d r)
  | MFieldStore (root, rootty, idxs, v) ->
    (* 字段写入：GEP 链直达字段，深拷贝新值 + 释放旧值（指针根自动解引用） *)
    let (rp, base_ty) =
      match rootty with
      | TStruct _ -> (fst (ptr_of fc root), rootty)
      | TPtr (TStruct s) -> (fst (val_of fc root), TStruct s)
      | _ -> lerr None "invalid root type for field access"
    in
    let fp = gen_field_path fc rp base_ty idxs in
    gen_field_store ~free_old:true fc fp v
  | MEmptySeq (d, ty) ->
    (* 数组/列表字段缺省分配：定长数组按声明长度分配全零槽；
       列表空起步（长度 0、容量 8，随 push 扩容） *)
    let (elem, len, cap) =
      match ty with
      | TArray (et, n) -> (et, Int64.of_int n, Int64.of_int n)
      | TList et -> (et, 0L, 8L)
      | _ -> lerr None "MEmptySeq type is not an array/list"
    in
    let r = fresh_r fc in
    emitf fc "  %s = call ptr @zfy_seq_new(i64 %Ld, i64 %Ld, i32 %d)" r len cap
      (elem_width elem);
    Hashtbl.replace fc.regs d r
  | MAddrOf (d, slot) ->
    (* 取地址：dst = 变量槽地址（全局 @g.x 与局部 %v.x 都登记在 allocas） *)
    (match Hashtbl.find_opt fc.allocas slot with
     | Some (addr, _) -> Hashtbl.replace fc.regs d addr
     | None -> lerr None "address-of target is undefined: %s" slot)
  | MLoadK (d, src, ty) ->
    (* 解引用读：src 求值为指针，load 目标类型 *)
    let (pv, _) = val_of fc src in
    let r = fresh_r fc in
    emitf fc "  %s = load %s, ptr %s" r (ll_ty ty) pv;
    Hashtbl.replace fc.regs d r
  | MStoreK (addr, ty, v) ->
    (* 解引用写：addr 求值为指针，store 值（仅标量/指针目标） *)
    let (pv, _) = val_of fc addr in
    let (vv, vt) = val_of fc v in
    let tt = ll_ty ty in
    if vt <> tt then lerr None "dereference-assignment type mismatch %s vs %s" tt vt;
    emitf fc "  store %s %s, ptr %s" tt vv pv
  | MFieldAddr (d, root, rootty, idxs, _) ->
    (* 字段地址：根为 struct 槽（基址=槽地址）或指针值（基址=load 出的指针） *)
    let (rp, base_ty) =
      match rootty with
      | TStruct _ -> (fst (ptr_of fc root), rootty)
      | TPtr (TStruct s) -> (fst (val_of fc root), TStruct s)
      | _ -> lerr None "invalid root type for field address"
    in
    let fp = gen_field_path fc rp base_ty idxs in
    Hashtbl.replace fc.regs d fp
  | MElemAddr (d, base, idx, elem) ->
    (* 元素地址（裸指针，无越界检查）：&a[i] 或 &p[i]。
       基为数组/列表槽（值=seq 指针，再取 data 字段）或指针值（直接指向元素） *)
    let (bp, _) = val_of fc base in
    let (iv, _) = val_of fc idx in
    let dp =
      match base.oty with
      | TArray _ | TList _ ->
        (* bp = seq 结构指针（槽值），load 取 data 字段（第 0 字段） *)
        let dp = fresh_r fc in
        emitf fc "  %s = load ptr, ptr %s" dp bp;
        dp
      | TPtr _ -> bp
      | _ -> lerr None "invalid root type for element address"
    in
    let off = fresh_r fc in
    emitf fc "  %s = mul i64 %s, %d" off iv (elem_width elem);
    let ep = fresh_r fc in
    emitf fc "  %s = getelementptr inbounds i8, ptr %s, i64 %s" ep dp off;
    Hashtbl.replace fc.regs d ep
  | MIndirectCall (d, f, args, ret) ->
    (* 函数指针间接调用：call <ret> ptr %f(<args>)（实参标量语义借传） *)
    let (fv, _) = val_of fc f in
    let targs =
      List.map
        (fun (o : operand) ->
          if is_agg o.oty then
            let (p, _) = ptr_of fc o in
            ("ptr", p)
          else
            let (v, t) = val_of fc o in
            (t, v))
        args
    in
    let args_str =
      String.concat ", " (List.map (fun (t, v) -> t ^ " " ^ v) targs)
    in
    (match d with
     | Some d' ->
       let r = fresh_r fc in
       emitf fc "  %s = call %s %s(%s)" r (ll_ty ret) fv args_str;
       Hashtbl.replace fc.regs d' r
     | None -> emitf fc "  call void %s(%s)" fv args_str)
  | MFunAddr (d, name) ->
    (* 函数入口地址：寄存器表直接持有 LLVM 符号文本（@名） *)
    Hashtbl.replace fc.regs d ("@" ^ name)
  | MFreeStructTemp (name, ty) ->
    (* 语句末释放临时 struct 槽持有的资源（槽本身在栈上，无需释放） *)
    (match Hashtbl.find_opt fc.allocas name with
     | Some (addr, _) ->
       let s =
         match ty with
         | TStruct s -> s
         | _ -> lerr None "freed temp type is not a struct"
       in
       emitf fc "  call void @zfy_struct_free_%s(ptr %s)" s addr
     | None -> lerr None "undefined temp %s" name)

(* ---------- 终结符 ---------- *)

let block_label bid = Printf.sprintf "b%d" bid

let zero_value g (t : zty) : string =
  match t with
  | TInt _ | TUint _ -> "0"
  | TFloat _ -> "0.0"
  | TBool -> "false"
  | TChar -> "0"
  | TString -> "null"
  | TPtr _ | TFunSig _ -> "null"
  | _ -> lerr None "type cannot be a return default value"

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
  let params_ll =
    String.concat ", "
      ((if is_agg f.mret then [ Printf.sprintf "ptr sret(%s) %%out" (ll_ty f.mret) ] else [])
       @ List.map
           (fun (n, t) ->
             if is_agg t then Printf.sprintf "ptr %%%s" n
             else Printf.sprintf "%s %%%s" (ll_ty t) n)
           f.mparams)
  in
  let fname = if f.mname = "main" then "@zfy.main" else "@" ^ f.mname in
  Buffer.add_string buf
    (Printf.sprintf "define %s %s(%s) {\n" ret_ll fname params_ll);
  (* 参数落槽（所有权传参约定：string/数组/列表实参的指针值即资源本体，
     直接接管进本地槽，不再克隆——调用方对非 move 实参已先行克隆） *)
  List.iter
    (fun (n, t) ->
      let addr = Printf.sprintf "%%v.%s" n in
      emitf fc "  %s = alloca %s" addr (ll_ty t);
      Hashtbl.replace fc.allocas n (addr, t);
      if is_agg t then begin
        match t with
        | TStruct s ->
          (* struct：借传槽地址，深拷贝接管（值语义；先清零防释放未初始化垃圾） *)
          emitf fc "  store %s zeroinitializer, ptr %s" (ll_ty t) addr;
          emitf fc "  call void @zfy_struct_assign_%s(ptr %s, ptr %%%s)" s addr n
        | TErr _ ->
          (* 错误值：借传槽地址，memcpy 值拷贝（msg strdup 泄漏约定，无 RAII） *)
          gen_memcpy fc addr (Printf.sprintf "%%%s" n) (size_of fc.g t)
        | _ ->
          (* frac：借传槽地址，值拷贝（memcpy 语义，无堆资源） *)
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

(* struct LLVM 类型定义：直接按字段类型列表定义——LLVM 自然布局
   （成员按自然对齐放置，总大小补齐到最大成员对齐）与 hir 手算 C 布局
   一致；packed 用 <{ }>（紧排无填充），与手算 packed 布局一致。
   故字段 GEP 的元素序号即字段序号（勿再插入显式 padding 元素——
   那会使 GEP 字段序号与 LLVM 元素序号错位，见 w-006 段错误）。 *)
let gen_struct_type_def (_ : gctx) (sd : sdef) : string =
  let body =
    String.concat ", " (List.map (fun (_, fty) -> ll_ty fty) sd.sfields)
  in
  if sd.spacked then
    Printf.sprintf "%s = type <{ %s }>\n" (struct_ty_name sd.sname) body
  else
    Printf.sprintf "%s = type { %s }\n" (struct_ty_name sd.sname) body

(* 生成 @zfy_struct_free_<名>(ptr)：逐字段释放堆资源
   （string/seq/嵌套 struct 递归；运行时 free 函数均 NULL 安全） *)
let gen_struct_free_fn (sd : sdef) : string =
  let b = Buffer.create 128 in
  let emit : 'a. ('a, unit, string, unit) format4 -> 'a =
    fun fmt -> Printf.ksprintf (fun s -> Buffer.add_string b (s ^ "\n")) fmt
  in
  let sn = struct_ty_name sd.sname in
  emit "define void @zfy_struct_free_%s(ptr %%p) {" sd.sname;
  List.iteri
    (fun i (_, fty) ->
      match fty with
      | TString ->
        let fp = Printf.sprintf "%%f%d" i and v = Printf.sprintf "%%v%d" i in
        emit "  %s = getelementptr inbounds %s, ptr %%p, i32 0, i32 %d" fp sn i;
        emit "  %s = load ptr, ptr %s" v fp;
        emit "  call void @zfy_free_str(ptr %s)" v
      | TArray _ | TList _ ->
        let is_str =
          (match fty with TArray (TString, _) | TList TString -> 1 | _ -> 0) in
        let fp = Printf.sprintf "%%f%d" i and v = Printf.sprintf "%%v%d" i in
        emit "  %s = getelementptr inbounds %s, ptr %%p, i32 0, i32 %d" fp sn i;
        emit "  %s = load ptr, ptr %s" v fp;
        emit "  call void @zfy_seq_free(ptr %s, i8 %d)" v is_str
      | TStruct s2 ->
        let fp = Printf.sprintf "%%f%d" i in
        emit "  %s = getelementptr inbounds %s, ptr %%p, i32 0, i32 %d" fp sn i;
        emit "  call void @zfy_struct_free_%s(ptr %s)" s2 fp
      | _ -> ())
    sd.sfields;
  Buffer.add_string b "  ret void\n}\n";
  Buffer.contents b

(* 生成 @zfy_struct_assign_<名>(ptr dst, ptr src)：逐字段深拷贝
   （string strdup / seq clone / 嵌套 struct 递归 assign），先释放 dst 旧资源。
   运行时 free/strdup/clone 均 NULL 安全，无需判空分支 *)
let gen_struct_assign_fn (sd : sdef) : string =
  let b = Buffer.create 256 in
  let emit : 'a. ('a, unit, string, unit) format4 -> 'a =
    fun fmt -> Printf.ksprintf (fun s -> Buffer.add_string b (s ^ "\n")) fmt
  in
  let sn = struct_ty_name sd.sname in
  emit "define void @zfy_struct_assign_%s(ptr %%dst, ptr %%src) {" sd.sname;
  List.iteri
    (fun i (_, fty) ->
      let dp = Printf.sprintf "%%d%d" i and sp = Printf.sprintf "%%s%d" i in
      emit "  %s = getelementptr inbounds %s, ptr %%dst, i32 0, i32 %d" dp sn i;
      emit "  %s = getelementptr inbounds %s, ptr %%src, i32 0, i32 %d" sp sn i;
      match fty with
      | TString ->
        let old = Printf.sprintf "%%o%d" i in
        let nv = Printf.sprintf "%%n%d" i in
        let cp = Printf.sprintf "%%c%d" i in
        emit "  %s = load ptr, ptr %s" old dp;
        emit "  call void @zfy_free_str(ptr %s)" old;
        emit "  %s = load ptr, ptr %s" nv sp;
        emit "  %s = call ptr @zfy_strdup(ptr %s)" cp nv;
        emit "  store ptr %s, ptr %s" cp dp
      | TArray _ | TList _ ->
        let is_str =
          (match fty with TArray (TString, _) | TList TString -> 1 | _ -> 0) in
        let old = Printf.sprintf "%%o%d" i in
        let nv = Printf.sprintf "%%n%d" i in
        let cp = Printf.sprintf "%%c%d" i in
        emit "  %s = load ptr, ptr %s" old dp;
        emit "  call void @zfy_seq_free(ptr %s, i8 %d)" old is_str;
        emit "  %s = load ptr, ptr %s" nv sp;
        emit "  %s = call ptr @zfy_seq_clone(ptr %s, i8 %d)" cp nv is_str;
        emit "  store ptr %s, ptr %s" cp dp
      | TStruct s2 ->
        emit "  call void @zfy_struct_assign_%s(ptr %s, ptr %s)" s2 dp sp
      | _ ->
        let v = Printf.sprintf "%%v%d" i in
        emit "  %s = load %s, ptr %s" v (ll_ty fty) sp;
        emit "  store %s %s, ptr %s" (ll_ty fty) v dp)
    sd.sfields;
  Buffer.add_string b "  ret void\n}\n";
  Buffer.contents b

let gen_program (m : mir) : string =
  let g =
    { mbuf = Buffer.create 512; nstr = 0; globals = Hashtbl.create 16;
      structs = m.mstructs }
  in
  (* frac 类型定义：{ 分子, 分母 }（预生成全部后缀，未使用的定义合法） *)
  let frac_defs =
    [ "i8", "i8"; "i16", "i16"; "i32", "i32"; "i64", "i64"; "i128", "i128";
      "u8", "i8"; "u16", "i16"; "u32", "i32"; "u64", "i64"; "u128", "i128";
      "f32", "float"; "f64", "double"; "f128", "x86_fp80" ]
  in
  List.iter
    (fun (suf, ll) ->
      Buffer.add_string g.mbuf
        (Printf.sprintf "%%frac.%s = type { %s, %s }\n" suf ll ll))
    frac_defs;
  (* 数组/列表与类型定义 *)
  Buffer.add_string g.mbuf "%zfy.seq = type { ptr, ptr, i64 }\n";
  (* 错误值类型定义：{ i32 code; ptr msg; <8 字节 value 容器> }（全部 24 字节，
     与 C 端 zfy_err 布局一致；预生成全部后缀，未使用的定义合法） *)
  let err_defs =
    [ "i8", "i64"; "i16", "i64"; "i32", "i64"; "i64", "i64";
      "u8", "i64"; "u16", "i64"; "u32", "i64"; "u64", "i64";
      "f16", "double"; "f32", "double"; "f64", "double";
      "bool", "i64"; "char", "i64"; "str", "ptr"; "ptr", "ptr" ]
  in
  List.iter
    (fun (suf, vll) ->
      Buffer.add_string g.mbuf
        (Printf.sprintf "%%err.%s = type { i32, ptr, %s }\n" suf vll))
    err_defs;
  (* struct 类型定义与深拷贝/释放辅助函数（嵌套引用同模块前向合法） *)
  List.iter
    (fun sd -> Buffer.add_string g.mbuf (gen_struct_type_def g sd))
    m.mstructs;
  List.iter
    (fun sd ->
      Buffer.add_string g.mbuf (gen_struct_free_fn sd);
      Buffer.add_string g.mbuf (gen_struct_assign_fn sd))
    m.mstructs;
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
  (* ZEM 错误模型运行时：panic / 错误值构造（sret 写 TErr 聚合） /
     错误码查找 / T! 输入；sret 参数为首个 ptr（布局由调用方槽决定） *)
  Buffer.add_string g.mbuf "declare void @zfy_panic(i32, ptr)\n";
  Buffer.add_string g.mbuf "declare void @zfy_set_panic_handler(ptr)\n";
  Buffer.add_string g.mbuf "declare void @zfy_stoi_err(ptr, ptr)\n";
  Buffer.add_string g.mbuf "declare void @zfy_stod_err(ptr, ptr)\n";
  Buffer.add_string g.mbuf "declare void @zfy_err_find(ptr, ptr, i8, i64)\n";
  Buffer.add_string g.mbuf "declare void @zfy_input_err_i64(ptr, ptr)\n";
  Buffer.add_string g.mbuf "declare void @zfy_input_err_f64(ptr, ptr)\n";
  Buffer.add_string g.mbuf "declare void @zfy_input_err_str(ptr, ptr)\n";
  Buffer.add_string g.mbuf "declare void @zfy_input_err_bool(ptr, ptr)\n";
  Buffer.add_string g.mbuf "declare void @zfy_input_err_char(ptr, ptr)\n";
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
  Buffer.add_string g.mbuf "declare ptr @zfy_str_append(ptr, ptr)\n";
  Buffer.add_string g.mbuf "declare ptr @zfy_str_split(ptr, i8)\n";
  Buffer.add_string g.mbuf "declare ptr @zfy_str_split_str(ptr, ptr)\n";
  Buffer.add_string g.mbuf "declare ptr @zfy_seq_slice(ptr, i64, i64, i64, i8)\n";
  (* frac 运行时函数声明（12 后缀 × add/sub/mul/div + 比较 + reduce/print） *)
  let sufs = [ "i8"; "i16"; "i32"; "i64"; "i128"; "u8"; "u16"; "u32"; "u64";
               "u128"; "f32"; "f64"; "f128" ] in
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
  Hashtbl.reset user_fns;
  List.iter (fun (f : mfn) -> Hashtbl.replace user_fns f.mname ()) m.mfns;
  (* extern "C" 函数声明：收集 MCall/MCallOwn 中非本模块定义、非内建运行时
     的 callee，按实参/返回类型生成 declare（去重，同名首见签名生效） *)
  let is_rt_name (n : string) =
    Hashtbl.mem user_fns n || n = "main" || n = "strlen"
    || String.length n >= 4 && String.sub n 0 4 = "zfy_"
    || String.length n >= 4 && String.sub n 0 4 = "zfy."
    || n = "str_len" || n = "zfy.prec"
  in
  let decls : (string, string * string) Hashtbl.t = Hashtbl.create 8 in
  let add_decl name (args : operand list) ret =
    if not (is_rt_name name) && not (Hashtbl.mem decls name) then begin
      let is_ext = Hashtbl.mem Typeck.extern_fns name in
      let atys =
        List.map
          (fun (o : operand) ->
            if is_agg o.oty then "ptr"
            else if is_ext && is_i128 o.oty then "ptr"   (* 9d：按引用传 *)
            else ll_ty o.oty)
          args
      in
      let rty =
        if is_agg ret then "ptr"
        else if is_ext && is_i128 ret then "<2 x i64>"   (* 9d：sret 等价形式 *)
        else ll_ty ret
      in
      Hashtbl.replace decls name (rty, String.concat ", " atys)
    end
  in
  List.iter
    (fun (f : mfn) ->
      List.iter
        (fun (b : block) ->
          List.iter
            (fun i ->
              match i with
              | MCall (_, name, args, ret) -> add_decl name args ret
              | MCallOwn (_, name, args, ret, _) ->
                add_decl name (List.map fst args) ret
              | _ -> ())
            b.body)
        f.mblocks)
    m.mfns;
  Hashtbl.iter
    (fun name (rty, atys) ->
      Buffer.add_string g.mbuf
        (Printf.sprintf "declare %s @%s(%s)\n" rty name atys))
    decls;
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
     lerr None "main's return type must be void or i64, got %s" (Hir.pp_zty rt)
   | None -> ());
  Buffer.contents g.mbuf ^ Buffer.contents fbuf
