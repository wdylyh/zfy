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
             (fun (_, n, t, _) -> Printf.sprintf "%s: %s" n (Hir.pp_zty t))
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
    Printf.eprintf "zfy:error[E5006] in 0 of (cli) because (usage: zfyc <tokens|ast|hir|mir|llvm|build> <file.zfy>)\n";
    exit 2

(* 全局 flags（P0-4，v3.27）：--panic-mode exit|abort、--panic-exit <n>
   （默认 exit/1）。从 argv 提取后调 Llvmgen.set_panic_opts，剩余参数
   继续走 dispatch *)
let extract_flags (argv : string array) : string array =
  let rest = ref [] in
  (* 前缀匹配（--target=<t> / --linker-script=<p> 两种写法都支持） *)
  let pref s p =
    String.length s >= String.length p && String.sub s 0 (String.length p) = p in
  let strip s p = String.sub s (String.length p) (String.length s - String.length p) in
  let rec go i =
    if i >= Array.length argv then ()
    (* freestanding 裸机模式（§31）：入口/panic_handler/运行时裁剪 + 编译期禁用表 *)
    else if argv.(i) = "--freestanding" then begin
      Driver.set_freestanding true; go (i + 1)
    end
    else if argv.(i) = "--no-link" then begin
      (* 只产 .ll，不做最终链接（裸机 ELF 目标在 Windows 宿主无法链接） *)
      Driver.set_no_link true; go (i + 1)
    end
    else if argv.(i) = "--emit-ll" then
      (* 默认已写出 .ll；保留显式开关便于脚本自描述 *)
      go (i + 1)
    else if pref argv.(i) "--target=" then begin
      Driver.set_target_triple (strip argv.(i) "--target="); go (i + 1)
    end
    else if argv.(i) = "--target" && i + 1 < Array.length argv then begin
      Driver.set_target_triple argv.(i + 1); go (i + 2)
    end
    else if pref argv.(i) "--linker-script=" || pref argv.(i) "--link-script=" then begin
      let p = if pref argv.(i) "--linker-script="
        then strip argv.(i) "--linker-script=" else strip argv.(i) "--link-script=" in
      Driver.set_linker_script p; go (i + 1)
    end
    else if (argv.(i) = "--linker-script" || argv.(i) = "--link-script")
            && i + 1 < Array.length argv then begin
      Driver.set_linker_script argv.(i + 1); go (i + 2)
    end
    else if argv.(i) = "--panic-mode" && i + 1 < Array.length argv then begin
      let m = argv.(i + 1) in
      if m <> "exit" && m <> "abort" then begin
        Printf.eprintf "zfy:error[E5007] (cli) because (--panic-mode expects exit|abort, got %s)\n" m;
        exit 2
      end;
      Llvmgen.set_panic_opts m !Llvmgen.panic_exit_code;
      go (i + 2)
    end
    else if argv.(i) = "--panic-exit" && i + 1 < Array.length argv then begin
      (match int_of_string_opt argv.(i + 1) with
       | Some c -> Llvmgen.set_panic_opts !Llvmgen.panic_mode c
       | None ->
         Printf.eprintf "zfy:error[E5007] (cli) because (--panic-exit expects an integer, got %s)\n" argv.(i + 1);
         exit 2);
      go (i + 2)
    end
    else if argv.(i) = "--wrap-overflow"
            || argv.(i) = "-Wno-overflow-check" then begin
      (* 任务一：整数溢出静默回绕（旧语义）；默认检查模式。
         常量折叠同步切回回绕折叠 *)
      Llvmgen.set_wrap_overflow true;
      Mir.set_wrap_overflow true;
      go (i + 1)
    end
    else begin
      rest := argv.(i) :: !rest;
      go (i + 1)
    end
  in
  go 0;
  Array.of_list (List.rev !rest)

let () =
  try dispatch (extract_flags Sys.argv) with
  | Lexer.LexError (p, m) ->
    Printf.eprintf "lex error %s: %s\n" (pp_pos p) m;
    exit 1
  | Parser.ParseError (p, m) ->
    Printf.eprintf "syntax error %s: %s\n" (pp_pos p) m;
    exit 1
  | Typeck.TypeError (p, m) ->
    Printf.eprintf "type error %s: %s\n" (pp_pos p) m;
    exit 1
  | Mir.MirError (p, m) ->
    Printf.eprintf "MIR lowering error %s: %s\n" (pp_pos p) m;
    exit 1
  | Llvmgen.LlvmError (p, m) ->
    (match p with
     | Some p -> Printf.eprintf "codegen error %s: %s\n" (pp_pos p) m
     | None -> Printf.eprintf "codegen error: %s\n" m);
    exit 1
  | Driver.CompileError (p, m) ->
    (match p with
     | Some p -> Printf.eprintf "compile error %s: %s\n" (pp_pos p) m
     | None -> Printf.eprintf "compile error: %s\n" m);
    exit 1
