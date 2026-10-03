(* 完整管线驱动：源码 -> .ll -> 可执行文件 *)
open Tokens
open Ast

exception CompileError of pos option * string

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

let expand_uses (main : program) (main_dir : string) : program =
  let names : (string, unit) Hashtbl.t = Hashtbl.create 16 in
  let loaded : (string, unit) Hashtbl.t = Hashtbl.create 8 in
  let out : item list ref = ref [] in
  let reg name p =
    if Hashtbl.mem names name then
      raise (CompileError (Some p, Printf.sprintf "导入冲突：%s 已存在" name));
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
    | EBlock (bl, p) -> EBlock (rw_block m bl, p)
    | e -> e
  and rw_block m bl = List.map (rw_stmt m) bl
  and rw_stmt m (s : stmt) : stmt =
    match s with
    | SDecl (a, b, c, n, t, e, p) -> SDecl (a, b, c, n, t, Option.map (rw_expr m) e, p)
    | SSeqDecl (a, n, t, len, isl, inits, p) ->
      SSeqDecl (a, n, t, Option.map (rw_expr m) len, isl,
                List.map (rw_expr m) inits, p)
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
             | FIDecl (a, n, t, e, p) -> FIDecl (a, n, t, Option.map (rw_expr m) e, p)
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
    | SRemove (a, b, p) -> SRemove (rw_expr m a, rw_expr m b, p)
    | s -> s
  in
  (* 把一个文件的函数并入全局：ns 前缀；import 为 None 导入全部，Some m 只导入模块 m *)
  let add_items ns (items : item list) (import : string option) =
    let own : (string * string) list ref = ref [] in
    let collect its =
      let rec go_mod mname its2 =
        List.iter
          (function
            | IFn f -> own := (f.name, ns ^ mname ^ "." ^ f.name) :: !own
            | IMod _ | IUse _ -> ())
          its2
      in
      List.iter
        (function
          | IFn f -> own := (f.name, ns ^ f.name) :: !own
          | IMod (m, its2, _) -> go_mod m its2
          | IUse _ -> ())
        its
    in
    collect items;
    let m = !own in
    let emit_fn name fpos fparams fret fbody =
      reg name fpos;
      out := IFn { name; params = fparams; ret = fret; rfrac = false;
                  body = rw_block m fbody; pos = fpos } :: !out
    in
    let rec go_mod ns_mod mname its2 =
      List.iter
        (function
          | IFn f -> emit_fn (ns_mod ^ f.name) f.pos f.params f.ret f.body
          | IMod (_, _, p) ->
            raise (CompileError (Some p, "模块不允许嵌套"))
          | IDecl _ | IUse _ -> ())
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
              | None -> emit_fn (ns ^ f.name) f.pos f.params f.ret f.body)))
      items
  in
  let rec load_use base_dir (upath, uimport, ualias, upos) =
    let path =
      if Filename.is_relative upath then Filename.concat base_dir upath
      else upath
    in
    if not (Sys.file_exists path) then
      raise (CompileError (Some upos, Printf.sprintf "use：找不到文件 %s" upath));
    let norm = String.lowercase_ascii (Filename.concat (Sys.getcwd ()) path) in
    if not (Hashtbl.mem loaded norm) then begin
      Hashtbl.replace loaded norm ();
      let src = read_file path in
      let toks = Lexer.tokenize src in
      let sub = Parser.parse_program (Parser.make toks) in
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
      | IUse _ -> ()
      | (IFn _ | IMod _ | IDecl _) as it -> out := it :: !out)
    main;
  List.rev !out

let run_pipeline path : string =
  let src = read_file path in
  let toks = Lexer.tokenize src in
  let prog = Parser.parse_program (Parser.make toks) in
  let prog = expand_uses prog (Filename.dirname path) in
  let hir = Typeck.check_program prog in
  let m = Mir.lower hir in
  Llvmgen.gen_program m

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

(* 编译到可执行文件，返回可执行文件路径 *)
let compile path : string =
  let ll = run_pipeline path in
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
  let cmd =
    (* cmd.exe 对整串引号处理怪异：路径无空格时不加引号 *)
    if String.contains clang ' ' then
      Printf.sprintf "\"%s\" %s\"%s\" %s-O2 -o \"%s\"" clang target ll_path runtime exe
  else
    (* -O2：链接时对 LLVM IR 做 mem2reg/内联等优化（否则 alloca 槽全走内存，性能差数倍） *)
    Printf.sprintf "%s %s%s %s-O2 -o %s" clang target ll_path runtime exe
  in
  let code = Sys.command cmd in
  if code <> 0 then begin
    Printf.eprintf "链接失败（clang 退出码 %d）\n" code;
    exit 1
  end;
  exe
