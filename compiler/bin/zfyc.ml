(* zfyc 驱动：子命令调度 *)
open Tokens

let read_file path =
  let ic = open_in_bin path in
  let n = in_channel_length ic in
  let s = really_input_string ic n in
  close_in ic;
  s

let pp_pos p = Printf.sprintf "%d:%d" p.Tokens.line p.Tokens.col

let cmd_tokens path =
  let src = read_file path in
  let toks = Lexer.tokenize src in
  List.iter
    (fun (t, p) -> Printf.printf "%6s  %s\n" (pp_pos p) (pp_token t))
    toks

let cmd_ast path =
  let src = read_file path in
  let toks = Lexer.tokenize src in
  let prog = Parser.parse_program (Parser.make toks) in
  let n_items = List.length prog in
  let count_stmts =
    List.fold_left
      (fun acc (it : Ast.item) ->
        match it with
        | Ast.IFn f -> acc + List.length f.body
        | _ -> acc)
      0 prog
  in
  Printf.printf "AST OK: %d 个顶层项, main 中 %d 条语句\n" n_items count_stmts

let cmd_hir path =
  let src = read_file path in
  let toks = Lexer.tokenize src in
  let prog = Parser.parse_program (Parser.make toks) in
  let hir = Typeck.check_program prog in
  List.iter
    (fun (f : Hir.tfn) ->
      let ps =
        String.concat ", "
          (List.map
             (fun (_, n, t) -> Printf.sprintf "%s: %s" n (Hir.pp_zty t))
             f.fparams)
      in
      Printf.printf "fn %s(%s) -> %s\n" f.fname ps (Hir.pp_zty f.fret))
    hir.hfns;
  Printf.printf "HIR OK: %d 函数\n" (List.length hir.hfns)

let cmd_mir path =
  let src = read_file path in
  let toks = Lexer.tokenize src in
  let prog = Parser.parse_program (Parser.make toks) in
  let hir = Typeck.check_program prog in
  let m = Mir.lower hir in
  Printf.printf "MIR OK: %d 函数\n" (List.length m.Mir.mfns);
  List.iter
    (fun (f : Mir.mfn) ->
      Printf.printf "fn %s(%d 参数) -> %s, %d 块\n"
        f.Mir.mname (List.length f.Mir.mparams) (Hir.pp_zty f.Mir.mret)
        (List.length f.Mir.mblocks))
    m.Mir.mfns

let cmd_llvm path =
  let src = read_file path in
  let toks = Lexer.tokenize src in
  let prog = Parser.parse_program (Parser.make toks) in
  let hir = Typeck.check_program prog in
  let m = Mir.lower hir in
  print_string (Llvmgen.gen_program m)

let cmd_build path =
  let exe = Driver.compile path in
  Printf.printf "OK: %s\n" exe

let dispatch argv =
  match (argv : string array) with
  | [| _; "tokens"; path |] -> cmd_tokens path
  | [| _; "ast"; path |] -> cmd_ast path
  | [| _; "hir"; path |] -> cmd_hir path
  | [| _; "mir"; path |] -> cmd_mir path
  | [| _; "llvm"; path |] -> cmd_llvm path
  | [| _; "build"; path |] -> cmd_build path
  | _ ->
    Printf.eprintf "用法: zfyc <tokens|ast|hir|mir|llvm|build> <file.zfy>\n";
    exit 2

let () =
  try dispatch Sys.argv with
  | Lexer.LexError (p, m) ->
    Printf.eprintf "词法错误 %s: %s\n" (pp_pos p) m;
    exit 1
  | Parser.ParseError (p, m) ->
    Printf.eprintf "语法错误 %s: %s\n" (pp_pos p) m;
    exit 1
  | Typeck.TypeError (p, m) ->
    Printf.eprintf "类型错误 %s: %s\n" (pp_pos p) m;
    exit 1
  | Mir.MirError (p, m) ->
    Printf.eprintf "MIR 降码错误 %s: %s\n" (pp_pos p) m;
    exit 1
  | Llvmgen.LlvmError (p, m) ->
    (match p with
     | Some p -> Printf.eprintf "代码生成错误 %s: %s\n" (pp_pos p) m
     | None -> Printf.eprintf "代码生成错误: %s\n" m);
    exit 1
  | Driver.CompileError (p, m) ->
    (match p with
     | Some p -> Printf.eprintf "编译错误 %s: %s\n" (pp_pos p) m
     | None -> Printf.eprintf "编译错误: %s\n" m);
    exit 1
