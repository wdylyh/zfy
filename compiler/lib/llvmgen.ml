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
  | TFile -> "ptr"                   (* 槽内是句柄对象指针 {FILE* fp; int closed} *)
  | TStruct s -> Printf.sprintf "%%struct.%s" s
  | TPtr _ | TFunSig _ -> "ptr"      (* 指针/函数指针：裸地址 *)
  | TErr e ->
    (* T! 错误值聚合：%err.<elem> = { i32 code; ptr msg; <value 容器> }。
       ≤64 位元素容器统一 8 字节（整数/bool/char → i64，浮点 → double，
       string/指针 → ptr，与 C 端 zfy_err 布局一致）；128 位整数容器为
       i128（32 字节，与 C 端 zfy_err_wide 布局一致，new.md 2026-10-11） *)
    (match e with
     | TFloat 128 ->
       lerr None "f128 does not support T! wrapping (128-bit integers do; use f64! or cast stepwise)"
     | TInt 128 -> "%err.i128"
     | TUint 128 -> "%err.u128"
     | TFloat w -> Printf.sprintf "%%err.f%d" w
     | TInt w -> Printf.sprintf "%%err.i%d" w
     | TUint w -> Printf.sprintf "%%err.u%d" w
     | TBool -> "%err.bool"
     | TChar -> "%err.char"
     | TString -> "%err.str"
     | TPtr _ | TFile -> "%err.ptr"
     | _ -> lerr None "invalid error value element type (scalar/string/pointer only)")
  | TVar _ | TError -> lerr None "unresolved type variable"

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
  srcfiles : (string, string) Hashtbl.t; (* panic 行号（v3.5 DX）：文件名 → 常量全局名 *)
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
  | TErr e ->
    (match e with TInt 128 | TUint 128 -> 32 | _ -> 24)   (* { i32; ptr; value 容器 } *)
  | TStruct s ->
    (match find_struct g s with
     | Some sd -> fst (Hir.struct_size_align g.structs sd)
     | None -> lerr None "undefined struct %s" s)
  | TVoid | TVar _ | TError -> lerr None "cannot determine type size"

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

(* double -> 最近 f32 的 double 位型（round-to-nearest-even，v3.3.1）。
   返回值是一个"恰好等于该 f32 值"的 double 的 64 位位型——f32 值必为
   double 子集，直接把 52 位尾数低 29 位清零（正规域）即可表示 *)
let f32_as_double_bits (f : float) : Int64.t =
  let bits = Int64.bits_of_float f in
  let sgn = Int64.logand (Int64.shift_right_logical bits 63) 1L in
  let e = Int64.to_int (Int64.logand (Int64.shift_right_logical bits 52) 0x7FFL) in
  let m = Int64.logand bits 0xFFFFFFFFFFFFFL in
  let with_sign b = Int64.logor (Int64.shift_left sgn 63) b in
  if e = 0x7FF then
    (* inf/nan：按 f32 特值发（LLVM 接受 double 位型特值落 float 槽） *)
    if m = 0L then with_sign 0x7FF0000000000000L
    else with_sign 0x7FF8000000000000L
  else if e = 0 then
    (* |f| < 2^-1022 << f32 最小次正规 2^-149 → 零 *)
    with_sign 0L
  else begin
    let ed = e - 1023 in
    (* round-to-nearest-even：丢低 sh 位 *)
    let round_sh (v : Int64.t) (sh : int) : Int64.t =
      let hi = Int64.shift_right_logical v sh in
      let rem = Int64.logand v (Int64.sub (Int64.shift_left 1L sh) 1L) in
      let half = Int64.shift_left 1L (sh - 1) in
      if Int64.unsigned_compare rem half > 0
      || (Int64.compare rem half = 0 && Int64.logand hi 1L = 1L)
      then Int64.add hi 1L
      else hi
    in
    if ed > 127 then with_sign 0x7FF0000000000000L      (* 溢出 -> inf *)
    else if ed >= -126 then begin
      (* f32 正规：53 位有效位丢低 29 位得 24 位 *)
      let m24 = round_sh (Int64.logor m 0x10000000000000L) 29 in
      let m24, ed =
        if Int64.compare m24 0x1000000L >= 0            (* 24 位进位 *)
        then (Int64.shift_right_logical m24 1, ed + 1)
        else (m24, ed)
      in
      if ed > 127 then with_sign 0x7FF0000000000000L
      else
        with_sign
          (Int64.logor
             (Int64.shift_left (Int64.of_int (ed + 1023)) 52)
             (Int64.shift_left (Int64.logand m24 0x7FFFFFL) 29))
    end
    else begin
      (* f32 次正规：value = sig x 2^(ed-52) = k x 2^-149，
         k = sig >> (29 + (-126 - ed))（含隐含位一起舍入） *)
      let sh = 29 + (-126 - ed) in
      let k = round_sh (Int64.logor m 0x10000000000000L) sh in
      if Int64.compare k 0L = 0 then with_sign 0L
      else if Int64.compare k 0x800000L >= 0 then
        (* 舍入进位到最小正规 2^-126 *)
        with_sign (Int64.shift_left 897L 52)
      else begin
        (* 值 = k x 2^-149，k 最高位在第 kt-1 位（kt = 1..23） *)
        let rec topbit v i = if Int64.logand v (Int64.shift_left 1L i) <> 0L then i else topbit v (i - 1) in
        let kt = topbit k 22 in
        with_sign
          (Int64.logor
             (Int64.shift_left (Int64.of_int (kt + 874)) 52)
             (Int64.shift_left (Int64.sub k (Int64.shift_left 1L kt)) (52 - kt)))
      end
    end
  end

(* 浮点字面量 -> LLVM 常量文本 *)
let float_const (t : zty) (f : float) : string =
  (* 十进制形式：clang 要求带小数点——"1e+40" 这类无点指数形被
     "integer constant must have integer type" 拒绝 → 插 .0 *)
  let dec () =
    let s = Printf.sprintf "%.17g" f in
    if String.contains s '.' then s
    else if String.contains s 'e' then begin
      match String.index_opt s 'e' with
      | Some i ->
        String.sub s 0 i ^ ".0" ^ String.sub s i (String.length s - i)
      | None -> s ^ ".0"
    end
    else s ^ ".0"
  in
  match t with
  | TFloat 16 -> Printf.sprintf "0xH%04X" (double_to_half_bits f)
  | TFloat 128 ->
    let (hi, lo) = double_to_fp80_bits f in
    Printf.sprintf "0xK%04X%016LX" hi lo
  | TFloat 32 ->
    (* LLVM 要求 float 十进制常量在 f32 精度下精确可表示（0.1/2.249
       均非，报 "floating point constant invalid for type"）。53 位尾数
       低 29 位已清零且在 f32 正规域 → 十进制精确，按原样发；否则按
       最近 f32 位型发 double hex（clang 同款 0x%016LX 形式） *)
    let bits = Int64.bits_of_float f in
    let e = Int64.to_int (Int64.logand (Int64.shift_right_logical bits 52) 0x7FFL) in
    let m = Int64.logand bits 0xFFFFFFFFFFFFFL in
    if e <> 0 && e <> 0x7FF && e - 1023 >= -126 && e - 1023 <= 127
       && Int64.logand m 0x1FFFFFFFL = 0L then dec ()
    else Printf.sprintf "0x%016LX" (f32_as_double_bits f)
  | _ ->
    (* v3.3.2：f64 非有限字面量（1e400 → inf、0/0 折叠 → nan）不能走
       十进制——%.17g 产 "inf.0"/"nan.0" 被 LLVM 拒（expected value
       token）。按 double 位型 hex 发（LLVM 标准特值写法） *)
    if Float.is_finite f then dec ()
    else Printf.sprintf "0x%016LX" (Int64.bits_of_float f)

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
  | OBig digits ->
    (* i128/u128 大字面量（w-014 #6）：LLVM 任意精度整数字面量按
       目标类型截断（数字串已由 typeck 校验范围） *)
    ((if String.length digits = 0 then "0" else digits), t)
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
     | BPow ->
       (* ** 幂：libm pow/powf（v3.3） *)
       (match tya with
        | "float" ->
          emitf fc "  %s = call float @powf(float %s, float %s)" d va vb
        | _ ->
          emitf fc "  %s = call double @pow(double %s, double %s)" d va vb)
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
     | BBitAnd -> emitf fc "  %s = and %s %s, %s" d tya va vb
     | BBitOr -> emitf fc "  %s = or %s %s, %s" d tya va vb
     | BBitXor -> emitf fc "  %s = xor %s %s, %s" d tya va vb
     | BShl -> emitf fc "  %s = shl %s %s, %s" d tya va vb
     | BShr -> emitf fc "  %s = lshr %s %s, %s" d tya va vb
     | BPow ->
       (* ** 整数幂：运行时快速幂（无符号版），≤64 位；结果截回目标宽度。
          128 位走 zfy_pow_u128 64 位对接口（参数/结果全 64 位，规避
          win32 __int128 ABI），LLVM 侧拆/拼 i128（v3.3.3） *)
       if tya = "i128" then begin
         let blo = fresh_r fc in
         emitf fc "  %s = trunc %s %s to i64" blo tya va;
         let bh1 = fresh_r fc in
         emitf fc "  %s = lshr %s %s, 64" bh1 tya va;
         let bhi = fresh_r fc in
         emitf fc "  %s = trunc i128 %s to i64" bhi bh1;
         let elo = fresh_r fc in
         emitf fc "  %s = trunc %s %s to i64" elo tya vb;
         let eh1 = fresh_r fc in
         emitf fc "  %s = lshr %s %s, 64" eh1 tya vb;
         let ehi = fresh_r fc in
         emitf fc "  %s = trunc i128 %s to i64" ehi eh1;
         let op = fresh_r fc in
         emitf_entry fc "  %s = alloca [2 x i64]" op;
         emitf fc "  call void @zfy_pow_u128(ptr %s, i64 %s, i64 %s, i64 %s, i64 %s)"
           op blo bhi elo ehi;
         let p1 = fresh_r fc in
         emitf fc "  %s = getelementptr inbounds [2 x i64], ptr %s, i32 0, i32 1" p1 op;
         let lo = fresh_r fc in
         emitf fc "  %s = load i64, ptr %s" lo op;
         let hi = fresh_r fc in
         emitf fc "  %s = load i64, ptr %s" hi p1;
         let low = fresh_r fc in
         emitf fc "  %s = zext i64 %s to i128" low lo;
         let hiw = fresh_r fc in
         emitf fc "  %s = zext i64 %s to i128" hiw hi;
         let his = fresh_r fc in
         emitf fc "  %s = shl i128 %s, 64" his hiw;
         emitf fc "  %s = or i128 %s, %s" d low his
       end
       else begin
         let ext v =
           if tya = "i64" then v
           else
             let z = fresh_r fc in
             emitf fc "  %s = zext %s %s to i64" z tya v;
             z
         in
         let a64 = ext va and b64 = ext vb in
         (match tya with
          | "i64" ->
            emitf fc "  %s = call i64 @zfy_pow_ull(i64 %s, i64 %s)" d a64 b64
          | _ ->
            let c = fresh_r fc in
            emitf fc "  %s = call i64 @zfy_pow_ull(i64 %s, i64 %s)" c a64 b64;
            emitf fc "  %s = trunc i64 %s to %s" d c tya)
       end
     | bopc -> emitf fc "  %s = icmp %s %s %s, %s" d (cmp_op_int true bopc) tya va vb)
  | _ ->
    (match bop with
     | BAdd -> emitf fc "  %s = add %s %s, %s" d tya va vb
     | BSub -> emitf fc "  %s = sub %s %s, %s" d tya va vb
     | BMul -> emitf fc "  %s = mul %s %s, %s" d tya va vb
     | BDiv -> emitf fc "  %s = sdiv %s %s, %s" d tya va vb
     | BMod -> emitf fc "  %s = srem %s %s, %s" d tya va vb
     | BBitAnd -> emitf fc "  %s = and %s %s, %s" d tya va vb
     | BBitOr -> emitf fc "  %s = or %s %s, %s" d tya va vb
     | BBitXor -> emitf fc "  %s = xor %s %s, %s" d tya va vb
     | BShl -> emitf fc "  %s = shl %s %s, %s" d tya va vb
     | BShr -> emitf fc "  %s = ashr %s %s, %s" d tya va vb
     | BPow ->
       (* ** 整数幂：运行时快速幂（有符号版，负指数得 0）。
          128 位走 zfy_pow_i128 64 位对接口（同无符号版，v3.3.3）；
          hi 用 lshr 取原始位型（补码语义由 runtime 内部转换处理） *)
       if tya = "i128" then begin
         let blo = fresh_r fc in
         emitf fc "  %s = trunc %s %s to i64" blo tya va;
         let bh1 = fresh_r fc in
         emitf fc "  %s = lshr %s %s, 64" bh1 tya va;
         let bhi = fresh_r fc in
         emitf fc "  %s = trunc i128 %s to i64" bhi bh1;
         let elo = fresh_r fc in
         emitf fc "  %s = trunc %s %s to i64" elo tya vb;
         let eh1 = fresh_r fc in
         emitf fc "  %s = lshr %s %s, 64" eh1 tya vb;
         let ehi = fresh_r fc in
         emitf fc "  %s = trunc i128 %s to i64" ehi eh1;
         let op = fresh_r fc in
         emitf_entry fc "  %s = alloca [2 x i64]" op;
         emitf fc "  call void @zfy_pow_i128(ptr %s, i64 %s, i64 %s, i64 %s, i64 %s)"
           op blo bhi elo ehi;
         let p1 = fresh_r fc in
         emitf fc "  %s = getelementptr inbounds [2 x i64], ptr %s, i32 0, i32 1" p1 op;
         let lo = fresh_r fc in
         emitf fc "  %s = load i64, ptr %s" lo op;
         let hi = fresh_r fc in
         emitf fc "  %s = load i64, ptr %s" hi p1;
         let low = fresh_r fc in
         emitf fc "  %s = zext i64 %s to i128" low lo;
         let hiw = fresh_r fc in
         emitf fc "  %s = zext i64 %s to i128" hiw hi;
         let his = fresh_r fc in
         emitf fc "  %s = shl i128 %s, 64" his hiw;
         emitf fc "  %s = or i128 %s, %s" d low his
       end
       else begin
         let ext v =
           if tya = "i64" then v
           else
             let z = fresh_r fc in
             emitf fc "  %s = sext %s %s to i64" z tya v;
             z
         in
         let a64 = ext va and b64 = ext vb in
         (match tya with
          | "i64" ->
            emitf fc "  %s = call i64 @zfy_pow_ll(i64 %s, i64 %s)" d a64 b64
          | _ ->
            let c = fresh_r fc in
            emitf fc "  %s = call i64 @zfy_pow_ll(i64 %s, i64 %s)" c a64 b64;
            emitf fc "  %s = trunc i64 %s to %s" d c tya)
       end
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
  | UBitNot -> emitf fc "  %s = xor %s %s, -1" d tya va

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
        (* bool 存 i1：零扩展（true=1，不随符号位扩散成 -1） *)
        if is_unsigned a.oty || a.oty = TBool then
          emitf fc "  %s = zext %s %s to %s" d ta va tb
        else emitf fc "  %s = sext %s %s to %s" d ta va tb
      end
      else emitf fc "  %s = trunc %s %s to %s" d ta va tb
    | _ -> lerr None "unsupported conversion %s -> %s" ta tb

(* ---------- output / input ---------- *)

(* 数组/列表元素的存储宽度（字节）：bool/char/i8/u8/f16 1-2、i32/f32 4、
   i64/f64/string 8、i128/u128/f128 16、T! 24（128 位元素 32） *)
let elem_width (g : gctx) (e : zty) : int =
  match e with
  | TInt 8 | TUint 8 | TBool | TChar -> 1
  | TFloat 16 | TInt 16 | TUint 16 -> 2
  | TInt 32 | TUint 32 | TFloat 32 -> 4
  | TInt 64 | TUint 64 | TFloat 64 | TString -> 8
  | TInt 128 | TUint 128 | TFloat 128 -> 16
  | TErr ee -> (match ee with TInt 128 | TUint 128 -> 32 | _ -> 24)
  | TList _ | TArray _ -> 8   (* 嵌套 seq：元素为内层 seq 指针（w-014 #4） *)
  | TStruct _ ->              (* struct 元素：按 C 布局大小整块存储（w-014 #2） *)
    (match e with
     | TStruct s ->
       (match find_struct g s with
        | Some sd -> fst (Hir.struct_size_align g.structs sd)
        | None -> lerr None "undefined struct in element position")
     | _ -> assert false)
  | _ -> lerr None "unsupported array/list element type"

(* 元素存储种类（w-014 #2/#4）：随 zfy_seq_new_k 写入 seq 头部，
   运行时 free/clone/slice/set/get 按头部驱动：
   0=标量 1=string 2=嵌套 seq 3=struct（ops 指向深拷贝/释放函数对）
   4=T!（new.md 2026-10-11：24/32 字节聚合，clone=memcpy、free=no-op——
   msg 按 strdup 泄漏约定不释放，浅拷无悬垂） *)
let elem_kind_ops (e : zty) : int * string option =
  match e with
  | TString -> (1, None)
  | TList _ | TArray _ -> (2, None)
  | TStruct s -> (3, Some ("@zfy.ops.struct." ^ s))
  | TErr _ -> (4, None)
  | _ -> (0, None)

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
    emitf fc "  %s = mul i64 %s, %d" off iv (elem_width fc.g elem);
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
    emitf fc "  %s = mul i64 %s, %d" off iv (elem_width fc.g elem);
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
      | TInt 64 | TUint 64 -> ("zfy_input_i64", "")
      | TInt 32 -> ("zfy_input_i32", "")
      | TUint 32 -> ("zfy_input_u32", "")
      | TInt 16 -> ("zfy_input_i16", "")
      | TUint 16 -> ("zfy_input_u16", "")
      | TInt 8 -> ("zfy_input_i8", "")
      | TUint 8 -> ("zfy_input_u8", "")
      | TInt _ | TUint _ -> ("zfy_input_i64", "")
      | TBool -> ("zfy_input_bool", "")
      | TChar -> ("zfy_input_char", "")
      | TFloat 16 -> ("zfy_input_f64", ", i32 2")
      | TFloat 32 -> ("zfy_input_f64", ", i32 1")   (* as_f32：按 4 字节写槽 *)
      | TFloat 64 -> ("zfy_input_f64", ", i32 0")
      | TFloat 128 -> ("zfy_input_f64", ", i32 3")
      | TErr e ->
        (* T! 目标：失败不退出，写错误值（code=INPUT, msg=原因）；value 容器按元素；
           128 位整数用 32 字节 zfy_err_wide 容器（new.md 2026-10-11） *)
        (match e with
         | TInt 128 | TUint 128 -> ("zfy_input_err_i128", "")
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

(* ---------- v3.6 容器谓词/比较器 thunk ----------
 * C ABI（元素按指针传入）→ zfy 函数（按值）适配器：
 *   filter/any/all 谓词：i32 (ptr)——load 元素值后调用，TBool zext i32
 *   sort_by 比较器：     i32 (ptr, ptr)
 * 按 (函数名, 签名) 缓存去重；定义体在 gen_program 末尾统一落盘 *)
let thunk_buf = Buffer.create 1024
let thunk_cache : (string, string) Hashtbl.t = Hashtbl.create 8
let thunk_cnt = ref 0

let zfy_thunk (fname : string) (ptys : zty list) (ret : zty) : string =
  let key = fname ^ "#" ^ String.concat "," (List.map Hir.pp_zty ptys) in
  match Hashtbl.find_opt thunk_cache key with
  | Some tn -> tn
  | None ->
    incr thunk_cnt;
    let tn = Printf.sprintf "zfy.thunk.%d" !thunk_cnt in
    let b = Buffer.create 256 in
    Buffer.add_string b (Printf.sprintf "define internal i32 @\"%s\"(" tn);
    List.iteri
      (fun i _ ->
        Buffer.add_string b
          (if i = 0 then "ptr %a0" else Printf.sprintf ", ptr %%a%d" i))
      ptys;
    Buffer.add_string b ") {\n";
    List.iteri
      (fun i t ->
        Buffer.add_string b
          (Printf.sprintf "  %%v%d = load %s, ptr %%a%d\n" i (ll_ty t) i))
      ptys;
    Buffer.add_string b (Printf.sprintf "  %%r = call %s @%s(" (ll_ty ret) fname);
    List.iteri
      (fun i t ->
        Buffer.add_string b
          (if i = 0 then ll_ty t else Printf.sprintf ", %s" (ll_ty t));
        Buffer.add_string b (Printf.sprintf " %%v%d" i))
      ptys;
    Buffer.add_string b ")\n";
    (match Typeck.resolve ret with
     | TBool -> Buffer.add_string b "  %z = zext i1 %r to i32\n  ret i32 %z\n"
     | TInt 32 -> Buffer.add_string b "  ret i32 %r\n"
     | _ -> ());
    Buffer.add_string b "}\n";
    Buffer.add_string thunk_buf (Buffer.contents b);
    Hashtbl.replace thunk_cache key tn;
    tn

(* 运行时 i32 布尔返回集（v3.6）：gen_call 做 icmp ne 0 → i1 *)
let bool_i32_rts =
  [ "zfy_map_has_i"; "zfy_map_has_s"; "zfy_map_del_i"; "zfy_map_del_s";
    "zfy_contains_i8"; "zfy_contains_i16"; "zfy_contains_i32";
    "zfy_contains_i64"; "zfy_contains_u8"; "zfy_contains_u16";
    "zfy_contains_u32"; "zfy_contains_u64"; "zfy_contains_f32";
    "zfy_contains_f64"; "zfy_contains_str" ]

let gen_call fc dst name (args : operand list) (ret_ty : zty) =
  if name = "zfy_stoi_wide" then begin
    (* string → 128 位整数 fail-fast 转换（t-016 遗留修复）：运行时以
       返回值写低 64 位、指针写高 64 位（规避 win32 __int128 返回值
       ABI 的 sret 隐藏指针约定），LLVM 侧拼装 i128 *)
    (match dst, args with
     | Some d, [ s ] ->
       let (sp, _) = val_of fc s in
       let hip = fresh_r fc in
       emitf_entry fc "  %s = alloca i64" hip;
       let lo = fresh_r fc in
       emitf fc "  %s = call i64 @zfy_stoi_wide(ptr %s, ptr %s)" lo hip sp;
       let hi = fresh_r fc in
       emitf fc "  %s = load i64, ptr %s" hi hip;
       let low = fresh_r fc in
       emitf fc "  %s = zext i64 %s to i128" low lo;
       let hiw = fresh_r fc in
       emitf fc "  %s = zext i64 %s to i128" hiw hi;
       let his = fresh_r fc in
       emitf fc "  %s = shl i128 %s, 64" his hiw;
       (* 结果直接绑定 dst 寄存器名（MCall 约定 regs[dst]=dst） *)
       emitf fc "  %s = or i128 %s, %s" d low his
     | _ -> lerr None "zfy_stoi_wide call shape error")
  end
  else
  match name, args with
  | "zfy_set_add_i", [ s; v ] ->
    (* set_add（v3.6）：map put 值恒 1 *)
    (match dst with
     | _ ->
       let (sp, _) = ptr_of fc s in
       let (vv, _) = val_of fc v in
       emitf fc "  call void @zfy_map_put_i_i64(ptr %s, i64 %s, i64 1)" sp vv)
  | "zfy_set_add_s", [ s; v ] ->
    (match dst with
     | _ ->
       let (sp, _) = ptr_of fc s in
       let (vv, _) = val_of fc v in
       emitf fc "  call void @zfy_map_put_s_i64(ptr %s, ptr %s, i64 1)" sp vv)
  | "zfy_map_values", [ m ] ->
    (* 值列表（v3.6）：vstr/元素宽度由返回类型推导（常量实参注入） *)
    (match dst, ret_ty with
     | Some d, TList vt ->
       let (mp, _) = ptr_of fc m in
       let vstr, w =
         match Typeck.resolve vt with
         | TString -> (1, 8)
         | TInt w | TUint w -> (0, w / 8)
         | TFloat 32 -> (0, 4)
         | TFloat 64 -> (0, 8)
         | _ -> lerr None "zfy_map_values: unsupported value type"
       in
       emitf fc "  %s = call ptr @zfy_map_values(ptr %s, i32 %d, i32 %d)"
         d mp vstr w
     | _ -> lerr None "zfy_map_values: missing destination")
  | (("zfy_filter" | "zfy_any" | "zfy_all" | "zfy_sort_by") as bn), [ seq; pred ] ->
    (* 谓词/比较器 thunk（v3.6）：实参须为函数名（EFunPtrK 落 @名 寄存器） *)
    (match dst with
     | None -> ()
     | Some d ->
       let (sp, _) = val_of fc seq in
       let (pv, _) = val_of fc pred in
       if String.length pv = 0 || pv.[0] <> '@' then
         lerr None "%s: predicate/comparator must be a function name" bn
       else begin
         let fname = String.sub pv 1 (String.length pv - 1) in
         let (ptys, pret) =
           match Typeck.resolve pred.oty with
           | TPtr (TFunSig (ps, r)) -> (ps, r)
           | _ -> lerr None "%s: predicate type error" bn
         in
         let tn = zfy_thunk fname ptys pret in
         match bn with
         | "zfy_filter" ->
           emitf fc "  %s = call ptr @zfy_filter(ptr %s, ptr @\"%s\")" d sp tn
         | "zfy_sort_by" ->
           emitf fc "  %s = call ptr @zfy_sort_by(ptr %s, ptr @\"%s\")" d sp tn
         | _ ->
           let r = fresh_r fc in
           emitf fc "  %s = call i32 @%s(ptr %s, ptr @\"%s\")" r bn sp tn;
           emitf fc "  %s = icmp ne i32 %s, 0" d r
       end)
  | "abs", [ a ] ->
    (* abs 重载（v3.2）：无符号=恒等；有符号=内联 sub+icmp+select（规避
       C abs 的 32 位截断，i128 同样适用）；浮点=@fabs。is_rt_name 已排除
       "abs"，不会误生成 declare *)
    (match dst with
     | None -> ()
     | Some d ->
       (match a.oty with
        | TUint _ ->
          let (v, t) = val_of fc a in
          emitf fc "  %s = add %s %s, 0" d t v
        | TInt _ ->
          let (v, t) = val_of fc a in
          let neg = fresh_r fc in
          emitf fc "  %s = sub %s 0, %s" neg t v;
          let c = fresh_r fc in
          emitf fc "  %s = icmp slt %s %s, 0" c t v;
          emitf fc "  %s = select i1 %s, %s %s, %s %s" d c t neg t v
        | TFloat 32 ->
          let (v, _) = val_of fc a in
          emitf fc "  %s = call float @fabsf(float %s)" d v
        | TFloat _ ->
          let (v, _) = val_of fc a in
          emitf fc "  %s = call double @fabs(double %s)" d v
        | _ -> lerr None "abs: unsupported argument type"))
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
      | TBool, Some d when List.mem name bool_i32_rts ->
        (* 运行时 i32 布尔（has/del/contains）：icmp 转 i1（v3.6） *)
        let r = fresh_r fc in
        emitf fc "  %s = call i32 %s(%s)" r callee args_str;
        emitf fc "  %s = icmp ne i32 %s, 0" d r
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
      let r = fresh_r fc in
      emitf fc "  %s = call ptr @zfy_seq_clone(ptr %s)" r v;
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
  (* 注意顺序：先深拷贝新值、后释放旧值——右值可能就是旧字段本身
     （bag.x = bag.x 类自引用，或 push 原地修改后返回的头部），先释放
     会立刻悬垂 *)
  match v.oty with
  | TString ->
    let (sv, _) = val_of fc v in
    let r = fresh_r fc in
    emitf fc "  %s = call ptr @zfy_strdup(ptr %s)" r sv;
    if free_old then begin
      let old = fresh_r fc in
      emitf fc "  %s = load ptr, ptr %s" old fp;
      emitf fc "  call void @zfy_free_str(ptr %s)" old
    end;
    emitf fc "  store ptr %s, ptr %s" r fp
  | TArray _ | TList _ ->
    let (sv, _) = val_of fc v in
    let r = fresh_r fc in
    emitf fc "  %s = call ptr @zfy_seq_clone(ptr %s)" r sv;
    if free_old then begin
      let old = fresh_r fc in
      emitf fc "  %s = load ptr, ptr %s" old fp;
      emitf fc "  call void @zfy_seq_free(ptr %s)" old
    end;
    emitf fc "  store ptr %s, ptr %s" r fp
  | TStruct s ->
    let (sp, _) = ptr_of fc v in
    emitf fc "  call void @zfy_struct_assign_%s(ptr %s, ptr %s)" s fp sp
  | _ ->
    let (vv, tt) = val_of fc v in
    emitf fc "  store %s %s, ptr %s" tt vv fp

(* 元素写入公共体（MSeqSet/MSeqSetAt/MSeqLit 共用，w-14 #3）：
   seqp 为 seq 结构指针值。按元素宽度存储；string 元素深拷贝（数组独占
   堆串）；非 string 且不扩长时走内联路径（边界检查 + 直接 store），
   消除逐元素函数调用与 i128 中转槽；其余走运行时函数。 *)
(* v3.3.4：下标/长度统一提升 i64（length 返回 i32 后，push 追加位等
   直接以 i32 长度作下标；既有 u32 下标同样补齐） *)
let idx64 fc (idx : operand) =
  let (iv, ity) = val_of fc idx in
  match idx.oty with
  | TInt 64 | TUint 64 -> iv
  | TUint _ | TBool ->
    let r = fresh_r fc in
    emitf fc "  %s = zext %s %s to i64" r ity iv;
    r
  | _ ->
    let r = fresh_r fc in
    emitf fc "  %s = sext %s %s to i64" r ity iv;
    r

let gen_seq_set fc seqp (elem : zty) (idx : operand) (v : operand) grow unchecked =
  let iv = idx64 fc idx in
  match elem, grow with
  | TString, _ ->
    let (sv, _) = val_of fc v in
    emitf fc
      "  call void @zfy_seq_set_str(ptr %s, i64 %s, ptr %s, i8 %d)"
      seqp iv sv (if grow then 1 else 0)
  | (TStruct _ | TList _ | TArray _ | TErr _), _ ->
    (* 聚合元素（struct 深拷贝 / 嵌套 seq clone / T! 整块 memcpy，w-014
       #2/#4、new.md 2026-10-11）：值以指针传递——alloca 槽 load 出指针
       （struct/err 槽即槽地址、seq 槽 load 出内层 seq 指针），寄存器临时
       （切片结果）已是 seq 指针值直接使用；运行时按头部 kind/ops 深拷贝
       进槽位（先释放旧元素），扩长与边界检查同在运行时完成 *)
    let sv =
      match v.o with
      | OLocal n when Hashtbl.mem fc.allocas n -> fst (ptr_of fc v)
      | _ ->
        (* 寄存器临时（切片结果）：落入临时槽（set_agg 的 src 须指向
           持值槽：struct 字节 / seq 指针持有者） *)
        let t = fresh_r fc in
        emitf_entry fc "  %s = alloca ptr" t;
        let (rv, _) = val_of fc v in
        emitf fc "  store ptr %s, ptr %s" rv t;
        t
    in
    emitf fc
      "  call void @zfy_seq_set_agg(ptr %s, i64 %s, ptr %s, i8 %d)"
      seqp iv sv (if grow then 1 else 0)
  | _, true ->
    (* 扩长写入（列表下标=len 追加）：仍走运行时 *)
    let bits = bits_of fc v in
    let slot = fresh_r fc in
    emitf_entry fc "  %s = alloca i128" slot;
    emitf fc "  store i128 %s, ptr %s" bits slot;
    emitf fc
      "  call void @zfy_seq_set_w(ptr %s, i64 %s, ptr %s, i32 %d, i8 %d)"
      seqp iv slot (elem_width fc.g elem) 1
  | _, false ->
    let (ep, jb) = inline_elem_addr fc seqp iv elem ~checked:(not unchecked) in
    let bits = bits_of fc v in
    let w = elem_width fc.g elem * 8 in
    (if w < 128 then begin
       let sv = fresh_r fc in
       emitf fc "  %s = trunc i128 %s to i%d" sv bits w;
       emitf fc "  store i%d %s, ptr %s, align 1" w sv ep
     end else
       emitf fc "  store i128 %s, ptr %s, align 1" bits ep);
    emitf fc "  br label %%%s" jb;
    emitf fc "%s:" jb

(* 嵌套定长数组行分配（w-014 #4）：新分配的外层 seq 若元素为 TArray，
   每个元素槽写入新分配的内层行 seq（len=cap=行长度，元素种类随内层）；
   递归处理更深嵌套。seqp 为 seq 结构指针值，count 为外层长度 *)
let rec gen_seq_rows fc (seqp : string) (elem : zty) (count : Int64.t) =
  match elem with
  | TArray (ie, n) when count > 0L ->
    let dp = fresh_r fc in
    emitf fc "  %s = load ptr, ptr %s" dp seqp;   (* data 字段（偏移 0） *)
    (* 行 seq 的头部描述"行的元素"（ie）：宽度/种类取内层层级 *)
    let (rkind, rops) = elem_kind_ops ie in
    let w = elem_width fc.g ie and ln = Int64.of_int n in
    for i = 0 to Int64.to_int count - 1 do
      let off = fresh_r fc in
      emitf fc "  %s = mul i64 %d, 8" off i;
      let slot = fresh_r fc in
      emitf fc "  %s = getelementptr inbounds i8, ptr %s, i64 %s" slot dp off;
      let row = fresh_r fc in
      (match rops with
       | Some og ->
         emitf fc "  %s = call ptr @zfy_seq_new_k(i64 %Ld, i64 %Ld, i32 %d, i32 %d, ptr %s)"
           row ln ln w rkind og
       | None ->
         emitf fc "  %s = call ptr @zfy_seq_new_k(i64 %Ld, i64 %Ld, i32 %d, i32 %d, ptr null)"
           row ln ln w rkind);
      gen_seq_rows fc row ie ln;
      emitf fc "  store ptr %s, ptr %s" row slot
    done
  | _ -> ()

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
      (* 先深拷贝新值、后释放槽中旧资源（顺序敏感：右值可能引用旧槽，
         如 xs = push(xs, v) 特判未命中的兜底路径——先释放会悬垂） *)
      (match ty with
       | TArray _ | TList _ ->
         (* 深拷贝 seq：避免两个变量共享同一资源导致双重释放 *)
         let (sv, _) = val_of fc v in
         let r = fresh_r fc in
         emitf fc "  %s = call ptr @zfy_seq_clone(ptr %s)" r sv;
         let ov = fresh_r fc in
         emitf fc "  %s = load ptr, ptr %s" ov dstp;
         emitf fc "  call void @zfy_seq_free(ptr %s)" ov;
         emitf fc "  store ptr %s, ptr %s" r dstp
       | TString ->
         (* 深拷贝语义：槽内恒持有独立堆串（字面量为全局常量，需 strdup） *)
         let (sv, _) = val_of fc v in
         let r = fresh_r fc in
         emitf fc "  %s = call ptr @zfy_strdup(ptr %s)" r sv;
         let ov = fresh_r fc in
         emitf fc "  %s = load ptr, ptr %s" ov dstp;
         emitf fc "  call void @zfy_free_str(ptr %s)" ov;
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
    (* string 原地追加（T7 优化）：槽独占堆串批量 realloc 扩容一次并入
       （zfy_str_append_n），槽指针所有权保留（不 free 旧串）；
       realloc 可能移动缓冲区，typeck 保证操作数不引用槽本身 *)
    let (dstp, _) = ptr_of fc (operand_of_name name TString) in
    let n = List.length ops in
    let arr = fresh_r fc in
    emitf fc "  %s = alloca [%d x ptr], align 8" arr n;
    List.iteri
      (fun i (o : operand) ->
        let (vv, _) = val_of fc o in
        let gp = fresh_r fc in
        emitf fc "  %s = getelementptr inbounds ptr, ptr %s, i64 %d" gp arr i;
        emitf fc "  store ptr %s, ptr %s" vv gp)
      ops;
    let cur = fresh_r fc in
    emitf fc "  %s = load ptr, ptr %s" cur dstp;
    let np = fresh_r fc in
    emitf fc "  %s = call ptr @zfy_str_append_n(ptr %s, ptr %s, i64 %d)"
      np cur arr n;
    emitf fc "  store ptr %s, ptr %s" np dstp
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
     | TFile ->
       (* File：目标旧句柄自动 close（幂等，null/已关闭跳过）后接管新句柄 *)
       let ov = fresh_r fc in
       emitf fc "  %s = load ptr, ptr %s" ov dstp;
       emitf fc "  call void @zfy_file_autoclose(ptr %s)" ov;
       let (sv, st) = val_of fc v in
       if st <> "ptr" then lerr None "invalid move target slot type %s" st;
       emitf fc "  store ptr %s, ptr %s" sv dstp
     | _ ->
       let ov = fresh_r fc in
       emitf fc "  %s = load ptr, ptr %s" ov dstp;
       (match ty with
        | TString -> emitf fc "  call void @zfy_free_str(ptr %s)" ov
        | _ -> emitf fc "  call void @zfy_seq_free(ptr %s)" ov);
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
     | TPtr _ | TFile ->
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
     | TInt 128 | TUint 128 ->
       (* 128 位容器：i128 直接存取（new.md 2026-10-11） *)
       let (iv, it) = val_of fc v in
       if it <> "i128" then
         lerr None "128-bit error value container expects i128, got %s" it;
       emitf fc "  store i128 %s, ptr %s" iv vp
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
     | TString | TPtr _ | TFile ->
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
     | TInt 128 | TUint 128 ->
       (* 128 位容器：直接 load i128（new.md 2026-10-11） *)
       let r = fresh_r fc in
       emitf fc "  %s = load i128, ptr %s" r vp;
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
  | MSetLoc (file, line) ->
    (* panic 行号追踪（v3.5 DX）：语句入口写全局，zfy_panic 打印 at file:line *)
    let gp =
      match Hashtbl.find_opt fc.g.srcfiles file with
      | Some g' -> g'
      | None ->
        let g' = intern_string fc.g file in
        Hashtbl.replace fc.g.srcfiles file g';
        g'
    in
    emitf fc "  store i32 %d, ptr @zfy_cur_line" line;
    emitf fc "  store ptr %s, ptr @zfy_cur_file" gp
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
  | MTempAlloca (name, ty) ->
    (* 归一用临时聚合槽：入口块 alloca（循环内不重复分配栈空间） *)
    let addr = Printf.sprintf "%%v%s" (String.sub name 1 (String.length name - 1)) in
    emitf_entry fc "  %s = alloca %s" addr (ll_ty ty);
    Hashtbl.replace fc.allocas name (addr, ty)
  | MNorm (name, ty) ->
    (* 非 unred frac 槽存入后自动约分 *)
    let elem = (match ty with TFrac e -> e | _ -> lerr None "norm type error") in
    (match Hashtbl.find_opt fc.allocas name with
     | Some (p, _) ->
       emitf fc "  call void @zfy_frac_norm_%s(ptr %s)" (Hir.suffix_of elem) p
     | None -> lerr None "undefined variable %s" name)
  | MSeqRemove (d, base, idx, elem, is_list) ->
    (* remove 表达式（v3 2026-10-11）：runtime 原子地"读出被删元素到 out +
       删除"。数组=槽位填零（长度不变）；列表=删除并左移。
       被删元素为深拷贝副本（elem_init 出独立值） *)
    let (seqp, _) = val_of fc base in
    let iv = idx64 fc idx in
    let out = fresh_r fc in
    (match elem with
     | TStruct _ | TErr _ ->
       emitf_entry fc "  %s = alloca %s" out (ll_ty elem);
       Hashtbl.replace fc.allocas d (out, elem);
       emitf fc "  store %s zeroinitializer, ptr %s" (ll_ty elem) out
     | TList _ | TArray _ ->
       emitf_entry fc "  %s = alloca ptr" out;
       Hashtbl.replace fc.allocas d (out, TList (TInt 64))
     | _ ->
       emitf_entry fc "  %s = alloca i128" out);
    if is_list then
      emitf fc "  call void @zfy_seq_remove(ptr %s, i64 %s, ptr %s)" seqp iv out
    else
      emitf fc "  call void @zfy_seq_zero(ptr %s, i64 %s, ptr %s)" seqp iv out;
    (match elem with
     | TStruct _ | TErr _ | TList _ | TArray _ -> ()  (* 槽即结果（allocas 已登记） *)
     | _ ->
       let raw = fresh_r fc in
       emitf fc "  %s = load i128, ptr %s" raw out;
       let (v, _) = from_bits fc raw elem in
       Hashtbl.replace fc.regs d v)
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
    let width = elem_width fc.g elem in
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
  | MPrintSeq (o, kind, sep) ->
    (* output(数组/列表)（w-013）：槽内是 zfy_seq 指针，长度/元素大小由
       运行时读（data+0 / len+16 / elemsz+32），元素间以 sep 分隔。
       操作数可为变量槽（alloca，load 取指针）或切片等寄存器临时
       （regs 中已是 seq 指针）——val_of 两种形态统一处理（w-014 #7） *)
    let (sp, _) = val_of fc o in
    let (sv, _) = val_of fc sep in
    emitf fc "  call void @zfy_print_seq(ptr %s, i32 %d, ptr %s)" sp kind sv
  | MPrintSeqNest (o, depth, leafkind, sep) ->
    (* output(嵌套序列)（w-015 #6）：运行时逐层递归输出 [ ... ]，
       叶元素类型码编译期传入；操作数形态与 MPrintSeq 一致 *)
    let (sp, _) = val_of fc o in
    let (sv, _) = val_of fc sep in
    emitf fc "  call void @zfy_print_seq_nest(ptr %s, i32 %d, i32 %d, ptr %s)"
      sp depth leafkind sv
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
        | TArray _ | TList _ ->
          (* 元素资源按 seq 头部 kind/ops 释放（w-014 #2/#4） *)
          let sp = fresh_r fc in
          emitf fc "  %s = load ptr, ptr %s" sp addr;
          emitf fc "  call void @zfy_seq_free(ptr %s)" sp;
          emitf fc "  store ptr null, ptr %s" addr
        | TStruct s ->
          (* struct：释放内含堆资源后清零槽（防重复释放） *)
          emitf fc "  call void @zfy_struct_free_%s(ptr %s)" s addr;
          emitf fc "  store %s zeroinitializer, ptr %s" (ll_ty ty) addr
        | TFile ->
          (* File：作用域退出自动 close（幂等；null=已 move，跳过；
             close 失败 panic——design_fileio.md 规则 3/4） *)
          let sp = fresh_r fc in
          emitf fc "  %s = load ptr, ptr %s" sp addr;
          emitf fc "  call void @zfy_file_autoclose(ptr %s)" sp;
          emitf fc "  store ptr null, ptr %s" addr
        | _ -> ())
     | None -> lerr None "undefined variable %s" name)
  | MFreeTemp name ->
    (* 语句末释放临时堆串（寄存器中持有 malloc 指针） *)
    (match Hashtbl.find_opt fc.regs name with
     | Some v -> emitf fc "  call void @zfy_free_str(ptr %s)" v
     | None -> lerr None "undefined temp %s" name)
  | MFreeSeqTemp (name, is_str) ->
    (* 语句末释放临时 seq（切片结果为寄存器；MSeqLit 字面量临时为
       alloca 持指针槽，w-014 #3——两种形态都支持） *)
    let v =
      match Hashtbl.find_opt fc.regs name with
      | Some v -> Some v
      | None ->
        (match Hashtbl.find_opt fc.allocas name with
         | Some (addr, _) ->
           let r = fresh_r fc in
           emitf fc "  %s = load ptr, ptr %s" r addr;
           Some r
         | None -> None)
    in
    (match v with
     | Some v ->
       emitf fc "  call void @zfy_seq_free(ptr %s)" v
     | None -> lerr None "undefined temp %s" name)
  | MSeqAlloc (name, elem, len, is_list) ->
    (* 分配数组/列表：数组 len=容量=长度；列表空起步、初始容量 8（不够自动扩长）。
       元素种类 kind/ops 写入 seq 头部（w-014 #2/#4） *)
    let (slotp, _) = ptr_of fc (operand_of_name name (TList (TInt 64))) in
    let (cnt, cap) =
      if is_list then (0L, 8L)
      else (len, max len 1L)
    in
    let (kind, ops) = elem_kind_ops elem in
    let r = fresh_r fc in
    (match ops with
     | Some og ->
       emitf fc "  %s = call ptr @zfy_seq_new_k(i64 %Ld, i64 %Ld, i32 %d, i32 %d, ptr %s)"
         r cnt cap (elem_width fc.g elem) kind og
     | None ->
       emitf fc "  %s = call ptr @zfy_seq_new_k(i64 %Ld, i64 %Ld, i32 %d, i32 %d, ptr null)"
         r cnt cap (elem_width fc.g elem) kind);
    gen_seq_rows fc r elem cnt;
    emitf fc "  store ptr %s, ptr %s" r slotp
  | MSeqSet (name, elem, idx, v, grow, unchecked) ->
    let (seqp, _) = val_of fc (operand_of_name name (TList (TInt 64))) in
    gen_seq_set fc seqp elem idx v grow unchecked
  | MSeqSetAt (slot, elem, idx, v, grow, unchecked) ->
    (* 槽地址版元素写（w-014 #3）：槽地址（字段链 GEP / ref 解引用 /
       元素槽）先 load 出 seq 指针，再走与 MSeqSet 相同的写入路径 *)
    let (sp, _) = val_of fc slot in
    let seqp = fresh_r fc in
    emitf fc "  %s = load ptr, ptr %s" seqp sp;
    gen_seq_set fc seqp elem idx v grow unchecked
  | MLoadSeq (d, slot) ->
    (* 从槽地址 load seq 指针（w-014 #3） *)
    let (sp, _) = val_of fc slot in
    let r = fresh_r fc in
    emitf fc "  %s = load ptr, ptr %s" r sp;
    Hashtbl.replace fc.regs d r
  | MSeqLit (d, elem, vs) ->
    (* 序列字面量（w-014 #3）：目标为 %tN 临时——自行 alloca 一个持
       seq 指针的槽并登记 allocas；分配 len=cap=元素个数 的 seq
       （元素种类 kind/ops 随头部）后逐元素写入（下标静态，免边界检查） *)
    let addr = fresh_r fc in
    emitf_entry fc "  %s = alloca ptr" addr;
    Hashtbl.replace fc.allocas d (addr, TList (TInt 64));
    let n = Int64.of_int (List.length vs) in
    let (kind, ops) = elem_kind_ops elem in
    let r = fresh_r fc in
    (match ops with
     | Some og ->
       emitf fc "  %s = call ptr @zfy_seq_new_k(i64 %Ld, i64 %Ld, i32 %d, i32 %d, ptr %s)"
         r n (max n 1L) (elem_width fc.g elem) kind og
     | None ->
       emitf fc "  %s = call ptr @zfy_seq_new_k(i64 %Ld, i64 %Ld, i32 %d, i32 %d, ptr null)"
         r n (max n 1L) (elem_width fc.g elem) kind);
    emitf fc "  store ptr %s, ptr %s" r addr;
    List.iteri
      (fun i v ->
        let idx = op (OInt (Int64.of_int i)) (TInt 64) in
        gen_seq_set fc r elem idx v false true)
      vs
  | MFreeVal (o, ty) ->
    (* 释放寄存器持有的堆值（w-014 #3） *)
    let (v, _) = val_of fc o in
    (match ty with
     | TString -> emitf fc "  call void @zfy_free_str(ptr %s)" v
     | TList _ | TArray _ ->
       emitf fc "  call void @zfy_seq_free(ptr %s)" v
     | _ -> lerr None "MFreeVal: type does not own heap resources")
  | MSeqGet (d, base, idx, elem, unchecked) ->
    (* 聚合元素（struct/嵌套 seq，w-014 #2/#4）：运行时深拷贝出独立
       副本到目标槽（struct 临时 / 持 seq 指针的槽，值语义）。
       非 string 标量走内联路径：边界检查 + 直接 load 元素位模式，
       再按元素类型还原（窄整数截断/位转换）；string 仍走运行时。 *)
    (match elem with
     | TStruct _ | TList _ | TArray _ | TErr _ ->
       let (seqp, _) = val_of fc base in
       let iv = idx64 fc idx in
       let dst_addr = fresh_r fc in
       (match elem with
        | TStruct _ | TErr _ ->
          emitf_entry fc "  %s = alloca %s" dst_addr (ll_ty elem);
          Hashtbl.replace fc.allocas d (dst_addr, elem);
          emitf fc "  store %s zeroinitializer, ptr %s" (ll_ty elem) dst_addr
        | _ ->
          emitf_entry fc "  %s = alloca ptr" dst_addr;
          Hashtbl.replace fc.allocas d (dst_addr, TList (TInt 64)));
       emitf fc "  call void @zfy_seq_get_agg(ptr %s, i64 %s, ptr %s)"
         seqp iv dst_addr
     | TString ->
       let tmp = fresh_r fc in
       emitf_entry fc "  %s = alloca i128" tmp;
       let (seqp, _) = val_of fc base in
       let iv = idx64 fc idx in
       emitf fc "  call void @zfy_seq_get(ptr %s, i64 %s, ptr %s, i32 %d, i8 %d)"
         seqp iv tmp (elem_width fc.g elem) (elem_signed elem);
       let raw = fresh_r fc in
       emitf fc "  %s = load i128, ptr %s" raw tmp;
       let (v, _) = from_bits fc raw elem in
       Hashtbl.replace fc.regs d v
     | _ ->
       let (seqp, _) = val_of fc base in
       let iv = idx64 fc idx in
       let (ep, jb) = inline_elem_addr fc seqp iv elem ~checked:(not unchecked) in
       let raw = fresh_r fc in
       let w = elem_width fc.g elem * 8 in
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
    (* 读 zfy.seq 的 len 字段（第 3 个字段，i64），截断为 i32（v3.3.4：
       length 返回 i32） *)
    let (seqp, _) = val_of fc base in
    let lp = fresh_r fc in
    emitf fc "  %s = getelementptr inbounds %%zfy.seq, ptr %s, i32 0, i32 2" lp seqp;
    let r64 = fresh_r fc in
    emitf fc "  %s = load i64, ptr %s" r64 lp;
    let r = fresh_r fc in
    emitf fc "  %s = trunc i64 %s to i32" r r64;
    Hashtbl.replace fc.regs d r
  | MSeqSlice (d, src, a, b, st, _is_str) ->
    (* 数组/列表切片：运行时生成新 seq（元素按头部 kind/ops 深拷贝，
       w-014 #2/#4——is_str 标志已废退役保留占位） *)
    let (sv, _) = val_of fc src in
    let (av, _) = val_of fc a in
    let (bv, _) = val_of fc b in
    let (stv, _) = val_of fc st in
    let r = fresh_r fc in
    emitf fc "  %s = call ptr @zfy_seq_slice(ptr %s, i64 %s, i64 %s, i64 %s)"
      r sv av bv stv;
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
       列表空起步（长度 0、容量 8，随 push 扩容）。
       元素种类 kind/ops 随头部；嵌套定长数组递归分配内层行（w-014 #4） *)
    let (elem, len, cap) =
      match ty with
      | TArray (et, n) -> (et, Int64.of_int n, Int64.of_int n)
      | TList et -> (et, 0L, 8L)
      | _ -> lerr None "MEmptySeq type is not an array/list"
    in
    let (kind, ops) = elem_kind_ops elem in
    let r = fresh_r fc in
    (match ops with
     | Some og ->
       emitf fc "  %s = call ptr @zfy_seq_new_k(i64 %Ld, i64 %Ld, i32 %d, i32 %d, ptr %s)"
         r len cap (elem_width fc.g elem) kind og
     | None ->
       emitf fc "  %s = call ptr @zfy_seq_new_k(i64 %Ld, i64 %Ld, i32 %d, i32 %d, ptr null)"
         r len cap (elem_width fc.g elem) kind);
    gen_seq_rows fc r elem len;
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
  | MElemAddr (d, base, idx, elem, checked) ->
    (* 元素地址：&a[i] / &p[i]（显式取地址无越界检查）或写目标定位
       （checked=1 时先做 icmp ult 边界检查，w-014 #3）。
       基为数组/列表槽（值=seq 指针，再取 data 字段）或指针值（直接指向元素） *)
    let (bp, _) = val_of fc base in
    let iv = idx64 fc idx in
    let jb =
      if checked then begin
        let lenp = fresh_r fc in
        emitf fc "  %s = getelementptr inbounds %%zfy.seq, ptr %s, i32 0, i32 2" lenp bp;
        let len = fresh_r fc in
        emitf fc "  %s = load i64, ptr %s" len lenp;
        let ok = fresh_r fc in
        emitf fc "  %s = icmp ult i64 %s, %s" ok iv len;
        let lb = fresh_lbl fc and fb = fresh_lbl fc and jb' = fresh_lbl fc in
        emitf fc "  br i1 %s, label %%%s, label %%%s" ok lb fb;
        emitf fc "%s:" fb;
        emitf fc "  call void @zfy_bounds_fail()";
        emitf fc "  unreachable";
        emitf fc "%s:" lb;
        jb'
      end else ""
    in
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
    emitf fc "  %s = mul i64 %s, %d" off iv (elem_width fc.g elem);
    let ep = fresh_r fc in
    emitf fc "  %s = getelementptr inbounds i8, ptr %s, i64 %s" ep dp off;
    (if checked then begin
       emitf fc "  br label %%%s" jb;
       emitf fc "%s:" jb
     end);
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
  (* 内建容器 map$/set$（v3.6）：句柄 struct 整体走 runtime 深释放 *)
  if Typeck.is_map_struct sd.sname || (String.length sd.sname > 4 && String.sub sd.sname 0 4 = "set$") then
    Printf.sprintf
      "define void @zfy_struct_free_%s(ptr %%p) {\n  call void @zfy_map_free(ptr %%p)\n  ret void\n}\n"
      sd.sname
  else begin
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
        let fp = Printf.sprintf "%%f%d" i and v = Printf.sprintf "%%v%d" i in
        emit "  %s = getelementptr inbounds %s, ptr %%p, i32 0, i32 %d" fp sn i;
        emit "  %s = load ptr, ptr %s" v fp;
        emit "  call void @zfy_seq_free(ptr %s)" v
      | TStruct s2 ->
        let fp = Printf.sprintf "%%f%d" i in
        emit "  %s = getelementptr inbounds %s, ptr %%p, i32 0, i32 %d" fp sn i;
        emit "  call void @zfy_struct_free_%s(ptr %s)" s2 fp
      | _ -> ())
    sd.sfields;
  Buffer.add_string b "  ret void\n}\n";
  Buffer.contents b
  end

(* 生成 @zfy_struct_assign_<名>(ptr dst, ptr src)：逐字段深拷贝
   （string strdup / seq clone / 嵌套 struct 递归 assign）。顺序：先拷贝
   新值、后释放 dst 旧资源（src 可能引用 dst 自身字段，先释放会悬垂）。
   运行时 free/strdup/clone 均 NULL 安全，无需判空分支 *)
let gen_struct_assign_fn (sd : sdef) : string =
  (* 内建容器 map$/set$（v3.6）：整体深拷贝（值语义） *)
  if Typeck.is_map_struct sd.sname || (String.length sd.sname > 4 && String.sub sd.sname 0 4 = "set$") then
    Printf.sprintf
      "define void @zfy_struct_assign_%s(ptr %%dst, ptr %%src) {\n  call void @zfy_map_assign(ptr %%dst, ptr %%src)\n  ret void\n}\n"
      sd.sname
  else begin
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
        emit "  %s = load ptr, ptr %s" nv sp;
        emit "  %s = call ptr @zfy_strdup(ptr %s)" cp nv;
        emit "  %s = load ptr, ptr %s" old dp;
        emit "  call void @zfy_free_str(ptr %s)" old;
        emit "  store ptr %s, ptr %s" cp dp
      | TArray _ | TList _ ->
        let old = Printf.sprintf "%%o%d" i in
        let nv = Printf.sprintf "%%n%d" i in
        let cp = Printf.sprintf "%%c%d" i in
        emit "  %s = load ptr, ptr %s" nv sp;
        emit "  %s = call ptr @zfy_seq_clone(ptr %s)" cp nv;
        emit "  %s = load ptr, ptr %s" old dp;
        emit "  call void @zfy_seq_free(ptr %s)" old;
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
  end

let gen_program (m : mir) : string =
  let g =
    { mbuf = Buffer.create 512; nstr = 0; globals = Hashtbl.create 16;
      srcfiles = Hashtbl.create 4; structs = m.mstructs }
  in
  (* 显式声明模块 triple：与 clang --target=x86_64-w64-mingw32 的推断一致，
     消除链接阶段 "overriding the module target triple" 警告（w-015 #8） *)
  Buffer.add_string g.mbuf "target triple = \"x86_64-w64-windows-gnu\"\n";
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
  Buffer.add_string g.mbuf "%zfy.seq = type { ptr, ptr, i64, i64, i64, i32, ptr }\n";
  (* 错误值类型定义：{ i32 code; ptr msg; <8 字节 value 容器> }（全部 24 字节，
     与 C 端 zfy_err 布局一致；预生成全部后缀，未使用的定义合法） *)
  let err_defs =
    [ "i8", "i64"; "i16", "i64"; "i32", "i64"; "i64", "i64";
      "u8", "i64"; "u16", "i64"; "u32", "i64"; "u64", "i64";
      "i128", "i128"; "u128", "i128";
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
  (* 每个 struct 的元素操作对（w-014 #2）：struct 作 seq 元素时
     zfy_seq_set_agg/get_agg/free 按头部 ops 深拷贝/释放 *)
  List.iter
    (fun sd ->
      Buffer.add_string g.mbuf
        (Printf.sprintf
           "@zfy.ops.struct.%s = constant { ptr, ptr } { ptr @zfy_struct_assign_%s, ptr @zfy_struct_free_%s }\n"
           sd.sname sd.sname sd.sname))
    m.mstructs;
  (* 运行时声明 *)
  Buffer.add_string g.mbuf "declare i64 @strlen(ptr)\n";
  Buffer.add_string g.mbuf "declare double @fabs(double)\n";
  Buffer.add_string g.mbuf "declare float @fabsf(float)\n";
  Buffer.add_string g.mbuf "declare double @pow(double, double)\n";
  Buffer.add_string g.mbuf "declare float @powf(float, float)\n";
  Buffer.add_string g.mbuf "declare i64 @zfy_pow_ll(i64, i64)\n";
  Buffer.add_string g.mbuf "declare i64 @zfy_pow_ull(i64, i64)\n";
  Buffer.add_string g.mbuf "declare void @zfy_pow_u128(ptr, i64, i64, i64, i64)\n";
  Buffer.add_string g.mbuf "declare void @zfy_pow_i128(ptr, i64, i64, i64, i64)\n";
  (* 时间内建（v3.3.6）：zfy_time_local 为 sret 形态（首参 = datetime 结果槽） *)
  Buffer.add_string g.mbuf "declare i64 @zfy_time_now()\n";
  Buffer.add_string g.mbuf "declare i64 @zfy_time_tick()\n";
  Buffer.add_string g.mbuf "declare void @zfy_time_sleep(i64)\n";
  Buffer.add_string g.mbuf "declare void @zfy_time_local(ptr, i64)\n";
  Buffer.add_string g.mbuf "declare i64 @zfy_time_mktime(i64, i64, i64, i64, i64, i64)\n";
  (* GUI 核心层（v3.3.7 design_gui.md L0；stdlib/gui.zfy extern 声明同名符号，
     declare 收集器对 zfy_ 前缀豁免，故在此统一定义） *)
  Buffer.add_string g.mbuf "declare i32 @zfy_gui_open(i32, i32, ptr)\n";
  Buffer.add_string g.mbuf "declare i32 @zfy_gui_poll(ptr, ptr, ptr, ptr)\n";
  Buffer.add_string g.mbuf "declare i32 @zfy_gui_alive()\n";
  Buffer.add_string g.mbuf "declare i32 @zfy_gui_should_close()\n";
  Buffer.add_string g.mbuf "declare i32 @zfy_gui_w()\n";
  Buffer.add_string g.mbuf "declare i32 @zfy_gui_h()\n";
  Buffer.add_string g.mbuf "declare i32 @zfy_gui_dpi()\n";
  Buffer.add_string g.mbuf "declare void @zfy_gui_close()\n";
  Buffer.add_string g.mbuf "declare void @zfy_gui_title(ptr)\n";
  Buffer.add_string g.mbuf "declare void @zfy_gui_present()\n";
  Buffer.add_string g.mbuf "declare void @zfy_gui_fill_rect(i32, i32, i32, i32, i32)\n";
  Buffer.add_string g.mbuf "declare void @zfy_gui_draw_text(i32, i32, ptr, i32)\n";
  Buffer.add_string g.mbuf "declare i32 @zfy_gui_text_w(ptr)\n";
  Buffer.add_string g.mbuf "declare i32 @zfy_gui_clip_get(ptr, i32)\n";
  Buffer.add_string g.mbuf "declare void @zfy_gui_clip_set(ptr)\n";
  Buffer.add_string g.mbuf "declare i32 @zfy_gui_alive_any()\n";
  Buffer.add_string g.mbuf "declare i32 @zfy_gui_self()\n";
  Buffer.add_string g.mbuf "declare void @zfy_gui_select(i64)\n";
  Buffer.add_string g.mbuf "declare void @zfy_gui_set_icon(ptr)\n";
  Buffer.add_string g.mbuf "declare void @zfy_gui_font(i32, i32)\n";
  Buffer.add_string g.mbuf "declare void @zfy_gui_round_rect(i32, i32, i32, i32, i32, i32, i32)\n";
  Buffer.add_string g.mbuf "declare void @zfy_gui_line(i32, i32, i32, i32, i32)\n";
  Buffer.add_string g.mbuf "declare void @zfy_gui_fill_grad(i32, i32, i32, i32, i32, i32, i32)\n";
  Buffer.add_string g.mbuf "declare void @zfy_os_random_u64(ptr)\n";
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
  Buffer.add_string g.mbuf "declare void @zfy_input_i32(ptr, ptr)\n";
  Buffer.add_string g.mbuf "declare void @zfy_input_i16(ptr, ptr)\n";
  Buffer.add_string g.mbuf "declare void @zfy_input_i8(ptr, ptr)\n";
  Buffer.add_string g.mbuf "declare void @zfy_input_u32(ptr, ptr)\n";
  Buffer.add_string g.mbuf "declare void @zfy_input_u16(ptr, ptr)\n";
  Buffer.add_string g.mbuf "declare void @zfy_input_u8(ptr, ptr)\n";
  Buffer.add_string g.mbuf "declare void @zfy_input_i128(ptr, ptr)\n";
  Buffer.add_string g.mbuf "declare void @zfy_input_u128(ptr, ptr)\n";
  Buffer.add_string g.mbuf "declare void @zfy_input_f64(ptr, ptr, i32)\n";
  Buffer.add_string g.mbuf "declare void @zfy_input_bool(ptr, ptr)\n";
  Buffer.add_string g.mbuf "declare void @zfy_input_char(ptr, ptr)\n";
  (* 数组/列表运行时函数（按元素宽度存储，未初始化槽位填零值）。
     zfy_seq 头部携带元素种类 kind/ops（w-014 #2/#4）：
     free/clone/slice/set_agg/get_agg 全部头部驱动，无需逐调用点传标志 *)
  Buffer.add_string g.mbuf "declare ptr @zfy_seq_new(i64, i64, i32)\n";
  Buffer.add_string g.mbuf "declare ptr @zfy_seq_new_k(i64, i64, i32, i32, ptr)\n";
  Buffer.add_string g.mbuf "declare void @zfy_seq_set_w(ptr, i64, ptr, i32, i8)\n";
  Buffer.add_string g.mbuf "declare void @zfy_seq_set_str(ptr, i64, ptr, i8)\n";
  Buffer.add_string g.mbuf "declare void @zfy_seq_get(ptr, i64, ptr, i32, i8)\n";
  Buffer.add_string g.mbuf "declare void @zfy_seq_set_agg(ptr, i64, ptr, i8)\n";
  Buffer.add_string g.mbuf "declare void @zfy_seq_get_agg(ptr, i64, ptr)\n";
  Buffer.add_string g.mbuf "declare void @zfy_bounds_fail()\n";
  (* ZEM 错误模型运行时：panic / 错误值构造（sret 写 TErr 聚合） /
     错误码查找 / T! 输入；sret 参数为首个 ptr（布局由调用方槽决定） *)
  Buffer.add_string g.mbuf "declare void @zfy_panic(i32, ptr)\n";
  Buffer.add_string g.mbuf "@zfy_cur_line = external global i32\n";
  Buffer.add_string g.mbuf "@zfy_cur_file = external global ptr\n";
  Buffer.add_string g.mbuf "declare void @zfy_set_panic_handler(ptr)\n";
  Buffer.add_string g.mbuf "declare void @zfy_stoi_err(ptr, ptr)\n";
  Buffer.add_string g.mbuf "declare void @zfy_stod_err(ptr, ptr)\n";
  Buffer.add_string g.mbuf "declare void @zfy_stoi_wide_err(ptr, ptr)\n";
  Buffer.add_string g.mbuf "declare i64 @zfy_stoi_wide(ptr, ptr)\n";
  Buffer.add_string g.mbuf "declare x86_fp80 @zfy_stod_wide(ptr)\n";
  Buffer.add_string g.mbuf "declare void @zfy_err_find(ptr, ptr, i8, i64)\n";
  Buffer.add_string g.mbuf "declare void @zfy_err_find_str(ptr, ptr, ptr, i64)\n";
  Buffer.add_string g.mbuf "declare void @zfy_input_err_i64(ptr, ptr)\n";
  Buffer.add_string g.mbuf "declare void @zfy_input_err_i128(ptr, ptr)\n";
  Buffer.add_string g.mbuf "declare void @zfy_input_err_f64(ptr, ptr)\n";
  Buffer.add_string g.mbuf "declare void @zfy_input_err_str(ptr, ptr)\n";
  Buffer.add_string g.mbuf "declare void @zfy_input_err_bool(ptr, ptr)\n";
  Buffer.add_string g.mbuf "declare void @zfy_input_err_char(ptr, ptr)\n";
  Buffer.add_string g.mbuf "declare void @zfy_seq_free(ptr)\n";
  Buffer.add_string g.mbuf "declare ptr @zfy_seq_clone(ptr)\n";
  (* 字符串操作运行时函数 *)
  Buffer.add_string g.mbuf "declare i8 @zfy_str_char(ptr, i64)\n";
  Buffer.add_string g.mbuf "declare void @zfy_str_set(ptr, i64, i8)\n";
  Buffer.add_string g.mbuf "declare ptr @zfy_str_slice(ptr, i64, i64, i64)\n";
  Buffer.add_string g.mbuf "declare i64 @zfy_str_find(ptr, i8, i64)\n";
  Buffer.add_string g.mbuf "declare ptr @zfy_str_trim(ptr, i8)\n";
  Buffer.add_string g.mbuf "declare ptr @zfy_str_trim_str(ptr, ptr)\n";
  Buffer.add_string g.mbuf "declare ptr @zfy_str_replace(ptr, i64, i64, ptr)\n";
  Buffer.add_string g.mbuf "declare i32 @zfy_str_cmp(ptr, ptr)\n";
  Buffer.add_string g.mbuf "declare i64 @zfy_utf8_len(ptr)\n";
  Buffer.add_string g.mbuf "declare ptr @zfy_utf8_char_at(ptr, i64)\n";
  Buffer.add_string g.mbuf "declare ptr @zfy_utf8_sub(ptr, i64, i64)\n";
  Buffer.add_string g.mbuf "declare ptr @zfy_str_concat(ptr, ptr)\n";
  Buffer.add_string g.mbuf "declare i64 @zfy_str_eq(ptr, ptr)\n";
  Buffer.add_string g.mbuf "declare i64 @zfy_str_ne(ptr, ptr)\n";
  Buffer.add_string g.mbuf "declare void @zfy_print_seq(ptr, i32, ptr)\n";
  Buffer.add_string g.mbuf "declare void @zfy_print_seq_nest(ptr, i32, i32, ptr)\n";
  Buffer.add_string g.mbuf "declare ptr @zfy_str_append_n(ptr, ptr, i64)\n";
  Buffer.add_string g.mbuf "declare ptr @zfy_str_split(ptr, i8)\n";
  Buffer.add_string g.mbuf "declare ptr @zfy_str_split_str(ptr, ptr)\n";
  Buffer.add_string g.mbuf "declare ptr @zfy_seq_slice(ptr, i64, i64, i64)\n";
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
  (* remove 运行时函数：数组槽位填零 / 列表删除并左移（元素资源按头部释放） *)
  Buffer.add_string g.mbuf "declare void @zfy_seq_zero(ptr, i64, ptr)\n";
  Buffer.add_string g.mbuf "declare void @zfy_seq_remove(ptr, i64, ptr)\n";
  Buffer.add_string g.mbuf
    "declare void @zfy_seq_aug_range(ptr, i64, i64, i64, i32, ptr, i32, i32, i32)\n";
  (* 文件 I/O（design_fileio.md）：句柄对象 {FILE* fp; int closed}，
     open 分配 / autoclose 幂等 / 失效与关闭后使用 panic *)
  Buffer.add_string g.mbuf
    "declare void @zfy_file_open_err(ptr sret(%err.ptr), ptr, ptr)\n";
  Buffer.add_string g.mbuf
    "declare void @zfy_file_read_all_err(ptr sret(%err.str), ptr)\n";
  Buffer.add_string g.mbuf
    "declare void @zfy_file_read_line_err(ptr sret(%err.str), ptr)\n";
  Buffer.add_string g.mbuf
    "declare void @zfy_file_write(ptr, ptr, i32)\n";
  Buffer.add_string g.mbuf
    "declare void @zfy_file_close(ptr)\n";
  Buffer.add_string g.mbuf
    "declare void @zfy_file_autoclose(ptr)\n";
  Buffer.add_string g.mbuf
    "declare i32 @zfy_file_exists(ptr)\n";
  Buffer.add_string g.mbuf
    "declare void @zfy_file_read_file_err(ptr sret(%err.str), ptr)\n";
  Buffer.add_string g.mbuf
    "declare ptr @zfy_file_read_lines(ptr)\n";
  Buffer.add_string g.mbuf
    "declare void @zfy_file_write_file_err(ptr sret(%err.i64), ptr, ptr)\n";
  (* 内建容器 map/set 与列表算法（v3.6） *)
  List.iter
    (fun s -> Buffer.add_string g.mbuf s)
    [ "declare void @zfy_map_put_i_i64(ptr, i64, i64)\n";
      "declare void @zfy_map_put_i_f32(ptr, i64, float)\n";
      "declare void @zfy_map_put_i_f64(ptr, i64, double)\n";
      "declare void @zfy_map_put_i_str(ptr, i64, ptr)\n";
      "declare void @zfy_map_put_s_i64(ptr, ptr, i64)\n";
      "declare void @zfy_map_put_s_f32(ptr, ptr, float)\n";
      "declare void @zfy_map_put_s_f64(ptr, ptr, double)\n";
      "declare void @zfy_map_put_s_str(ptr, ptr, ptr)\n";
      "declare void @zfy_map_get_err_i_i64(ptr sret(%err.i64), ptr, i64)\n";
      "declare void @zfy_map_get_err_i_f32(ptr sret(%err.f32), ptr, i64)\n";
      "declare void @zfy_map_get_err_i_f64(ptr sret(%err.f64), ptr, i64)\n";
      "declare void @zfy_map_get_err_i_str(ptr sret(%err.str), ptr, i64)\n";
      "declare void @zfy_map_get_err_s_i64(ptr sret(%err.i64), ptr, ptr)\n";
      "declare void @zfy_map_get_err_s_f32(ptr sret(%err.f32), ptr, ptr)\n";
      "declare void @zfy_map_get_err_s_f64(ptr sret(%err.f64), ptr, ptr)\n";
      "declare void @zfy_map_get_err_s_str(ptr sret(%err.str), ptr, ptr)\n";
      "declare i32 @zfy_map_has_i(ptr, i64)\n";
      "declare i32 @zfy_map_has_s(ptr, ptr)\n";
      "declare i32 @zfy_map_del_i(ptr, i64)\n";
      "declare i32 @zfy_map_del_s(ptr, ptr)\n";
      "declare i64 @zfy_map_len(ptr)\n";
      "declare void @zfy_map_clear(ptr)\n";
      "declare void @zfy_map_assign(ptr, ptr)\n";
      "declare void @zfy_map_free(ptr)\n";
      "declare ptr @zfy_map_keys(ptr)\n";
      "declare ptr @zfy_map_values(ptr, i32, i32)\n";
      "declare ptr @zfy_sort_i8(ptr)\n";
      "declare ptr @zfy_sort_i16(ptr)\n";
      "declare ptr @zfy_sort_i32(ptr)\n";
      "declare ptr @zfy_sort_i64(ptr)\n";
      "declare ptr @zfy_sort_u8(ptr)\n";
      "declare ptr @zfy_sort_u16(ptr)\n";
      "declare ptr @zfy_sort_u32(ptr)\n";
      "declare ptr @zfy_sort_u64(ptr)\n";
      "declare ptr @zfy_sort_f32(ptr)\n";
      "declare ptr @zfy_sort_f64(ptr)\n";
      "declare ptr @zfy_sort_str(ptr)\n";
      "declare ptr @zfy_reverse(ptr)\n";
      "declare ptr @zfy_join(ptr, ptr)\n";
      "declare i32 @zfy_contains_i8(ptr, i8)\n";
      "declare i32 @zfy_contains_i16(ptr, i16)\n";
      "declare i32 @zfy_contains_i32(ptr, i32)\n";
      "declare i32 @zfy_contains_i64(ptr, i64)\n";
      "declare i32 @zfy_contains_u8(ptr, i8)\n";
      "declare i32 @zfy_contains_u16(ptr, i16)\n";
      "declare i32 @zfy_contains_u32(ptr, i32)\n";
      "declare i32 @zfy_contains_u64(ptr, i64)\n";
      "declare i32 @zfy_contains_f32(ptr, float)\n";
      "declare i32 @zfy_contains_f64(ptr, double)\n";
      "declare i32 @zfy_contains_str(ptr, ptr)\n";
      "declare ptr @zfy_filter(ptr, ptr)\n";
      "declare i32 @zfy_any(ptr, ptr)\n";
      "declare i32 @zfy_all(ptr, ptr)\n";
      "declare ptr @zfy_sort_by(ptr, ptr)\n";
      "declare i8 @zfy_fold_i8(ptr, ptr, i8)\n";
      "declare i16 @zfy_fold_i16(ptr, ptr, i16)\n";
      "declare i32 @zfy_fold_i32(ptr, ptr, i32)\n";
      "declare i64 @zfy_fold_i64(ptr, ptr, i64)\n";
      "declare i8 @zfy_fold_u8(ptr, ptr, i8)\n";
      "declare i16 @zfy_fold_u16(ptr, ptr, i16)\n";
      "declare i32 @zfy_fold_u32(ptr, ptr, i32)\n";
      "declare i64 @zfy_fold_u64(ptr, ptr, i64)\n";
      "declare float @zfy_fold_f32(ptr, ptr, float)\n";
      "declare double @zfy_fold_f64(ptr, ptr, double)\n";
      "declare ptr @zfy_fold_str(ptr, ptr, ptr)\n" ];
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
    || n = "str_len" || n = "zfy.prec" || n = "abs"
    || n = "pow" || n = "powf"   (* ** 幂与 pow 内建共用 prelude declare，避免重复声明 *)
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
   | Some (TInt 32 as rt) ->
     Buffer.add_string fbuf
       (Printf.sprintf
          "define i32 @main() {\n  call void @zfy.globals()\n  %%r = call %s @zfy.main()\n  ret i32 %%r\n}\n"
          (ll_ty rt))
   | Some (TInt 64 as rt) ->
     Buffer.add_string fbuf
       (Printf.sprintf
          "define i32 @main() {\n  call void @zfy.globals()\n  %%r = call i64 @zfy.main()\n  %%t = trunc i64 %%r to i32\n  ret i32 %%t\n}\n")
   | Some rt ->
     lerr None "main's return type must be void, i32 or i64, got %s" (Hir.pp_zty rt)
   | None -> ());
  (* v3.6 容器谓词/比较器 thunk 定义（gen_call 期间累积） *)
  Buffer.add_string g.mbuf (Buffer.contents thunk_buf);
  Hashtbl.reset thunk_cache;
  Buffer.reset thunk_buf;
  Buffer.contents g.mbuf ^ Buffer.contents fbuf
