(* 模块解析 pass（new2.md 第4条 方案A）：
   parse 之后、typeck 之前独立成 pass，三阶段严格分离：
   1. 模块树构建：内联 mod（可嵌套）+ 文件模块 mod name;（查 name.zfy 或
      name/mod.zfy，相对父模块文件目录）；文件 include 环报完整环路径。
   2. 名字解析与可见性：use 只建名字绑定（不搬运 AST 不复制 IR）；
      可见性 = pub，或引用方与定义模块有祖先/后代关系（父可见子私有，
      子可见父私有，旁支须 pub）；crate/self/super 特判；不做隐式遮蔽、
      不做路径 fallback，查不到直接报错。
   3. 限定名扁平化：m::f → "m.f"（嵌套 a::b::f → "a.b.f"），root 顶层
      项名不变；输出扁平 program 喂 typeck（typeck/llvmgen 零改动）。
   use 依赖图检测环（A use B 且 B use A 报完整环路径）。
   main() 必须在 root：子模块项带前缀，typeck 对扁平 program 找 main
   即等价于要求 main 在 root。 *)

open Tokens
open Ast

(* 错误类别：文件模块加载产生的词法/语法错误归原阶段码，其余归 driver *)
type rerr_kind = RLex | RParse | RDriver

(* 绑定值：use local = 目标 item（扁平名）或目标模块（绝对路径段） *)
type bind_val =
  | BItem of string
  | BMod of string list

type modt = {
  mpath : string list;                          (* 绝对路径段（root 为 []） *)
  mutable parent : modt option;
  mutable children : (string * modt) list;      (* 保序 *)
  mutable locals : (string * bool * string) list;
    (* 本地名 -> (pub, 类别 "fn"/"struct"/"alias"/"const"/"extern"/"mod") *)
  mutable binds : (string, bind_val) Hashtbl.t; (* use 名字绑定 *)
  mutable raw : item list;                      (* 原始项（IPub 已剥离） *)
  dir : string;                                 (* 本模块体所在文件目录 *)
}

let collected : (rerr_kind * pos * string) list ref = ref []
let collect k p m = collected := (k, p, m) :: !collected

let mk_mod mpath dir =
  { mpath; parent = None; children = []; locals = []; raw = [];
    binds = Hashtbl.create 8; dir }

let flat_prefix (mpath : string list) : string =
  match mpath with [] -> "" | _ -> String.concat "." mpath ^ "."

let module_str (m : modt) : string =
  match m.mpath with [] -> "<root>" | p -> String.concat "::" p

let child_opt (m : modt) s = List.assoc_opt s m.children
let local_find (m : modt) s = List.find_opt (fun (n, _, _) -> n = s) m.locals

let key_of (mpath : string list) : string = String.concat "." mpath

let read_file path =
  let ic = open_in_bin path in
  let n = in_channel_length ic in
  let s = really_input_string ic n in
  close_in ic;
  s

let has_dcolon (s : string) : bool =
  let n = String.length s in
  let rec go i =
    i + 1 < n && (s.[i] = ':' && s.[i + 1] = ':' || go (i + 1))
  in
  n >= 2 && go 0

let split_dcolon (s : string) : string list =
  let segs = ref [] and buf = Buffer.create 16 in
  let n = String.length s in
  let i = ref 0 in
  while !i < n do
    if !i + 1 < n && s.[!i] = ':' && s.[!i + 1] = ':' then begin
      segs := Buffer.contents buf :: !segs;
      Buffer.clear buf;
      i := !i + 2
    end else begin
      Buffer.add_char buf s.[!i];
      incr i
    end
  done;
  segs := Buffer.contents buf :: !segs;
  List.rev !segs

let pos_of_item (it : item) : pos =
  match it with
  | IUse u -> u.pos
  | IUseP u -> u.pos
  | IFn f -> f.pos
  | IStruct s -> s.pos
  | IEnum e -> e.pos
  | IMod (_, _, p) | IModFile (_, p) | IPub (_, p) -> p
  | IExtern e -> e.pos
  | ITypeAlias a -> a.pos
  | IDecl (_, p) -> p

(* 可见性：item 定义于模块 target（pub 与否另判），引用方为 cur。
   cur 是 target 的后代（子可见父私有）或祖先（父可见子私有）→ 可见；
   旁支必须 pub。 *)
let related (cur : modt) (target : string list) : bool =
  let rec pref a b =
    match a, b with
    | [], _ -> true
    | _, [] -> false
    | x :: ra, y :: rb -> x = y && pref ra rb
  in
  pref target cur.mpath || pref cur.mpath target

let visible (cur : modt) (target_mpath : string list) (pub : bool) : bool =
  pub || related cur target_mpath

(* ---------- 主流程 ---------- *)

let resolve (main : program) (main_dir : string)
    (rerrs : (rerr_kind * pos * string) list ref) : program option =
  collected := [];
  let root = mk_mod [] main_dir in

  (* ---- 阶段1：模块树构建（含文件模块加载与 include 环检测） ---- *)
  let stack : (string * string) list ref = ref [] in   (* (规范路径, 模块名) *)
  let loaded : (string, modt) Hashtbl.t = Hashtbl.create 8 in
  let read_parse path =
    try
      let src = read_file path in
      let pp = Parser.make (Lexer.tokenize ~file:path src) in
      let prog = Parser.parse_program pp in
      List.iter (fun (p, m) -> collect RParse p m) pp.Parser.errs;
      prog
    with
    | Lexer.LexError (p, m) -> collect RLex p m; []
    | Parser.ParseError (p, m) -> collect RParse p m; []
    | Sys_error m ->
      collect RDriver { file = path; line = 0; col = 0 }
        ("cannot read source file: " ^ m);
      []
  in
  let add_local modt name pub kind p =
    if List.exists (fun (n, _, _) -> n = name) modt.locals then
      collect RDriver p
        (Printf.sprintf "name conflict: '%s' is already defined in module %s"
           name (module_str modt))
    else modt.locals <- modt.locals @ [ (name, pub, kind) ]
  in
  let find_mod_file dir name =
    let try_dir d =
      let c1 = Filename.concat d (name ^ ".zfy") in
      let c2 = Filename.concat (Filename.concat d name) "mod.zfy" in
      if Sys.file_exists c1 then Some c1
      else if Sys.file_exists c2 then Some c2
      else None
    in
    match try_dir dir with
    | Some p -> Some p
    | None ->
      (* stdlib 回退（v3.2 随机数模块）：本目录找不到时沿父目录链查
         <d>/stdlib/name.zfy（最多 6 级），支持子目录源文件引用标准库 *)
      let rec up d n =
        if n <= 0 then None
        else
          match try_dir (Filename.concat d "stdlib") with
          | Some p -> Some p
          | None ->
            let parent = Filename.dirname d in
            if parent = d then None else up parent (n - 1)
      in
      up dir 6
  in
  (* ---- 分组 use 的 stdlib 回退（v3.5 DX）----
     use widgets::{App, ...} 首段无本地 mod 声明时，若 find_mod_file 命中
     （本目录/父链 stdlib），隐式注入 mod 声明——与显式 `mod widgets;`
     语义完全一致。先全局收集去重，再统一插到 item 列表最前。
     对主文件与每个加载的模块文件都生效（stdlib 内部互相 use 同样受益）。 *)
  let fixup_uses dir (skip : string list) items =
    let declared =
      List.fold_left
        (fun acc it ->
           match it with
           | IMod (n, _, _) | IModFile (n, _) -> n :: acc
           | _ -> acc)
        [] items
    in
    let implicit =
      List.fold_left
        (fun acc it ->
           match it with
           | IUseP { binds; _ } ->
             List.fold_left
               (fun acc2 (_, segs, _) ->
                  match segs with
                  | s :: _ :: _ ->
                    if List.mem s acc2 || List.mem s declared
                       || List.mem s skip then acc2
                    else
                      (match find_mod_file dir s with
                       | Some _ -> s :: acc2
                       | None -> acc2)
                  | _ -> acc2)
               acc binds
           | _ -> acc)
        [] items
    in
    List.map
      (fun n -> IModFile (n, { file = "<implicit>"; line = 0; col = 0 }))
      (List.rev implicit)
    @ items
  in
  (* modt 祖先链上所有可见 mod 名（含各级 children）：隐式注入去重用——
     祖先已有同名 mod（如 root 显式 `mod gui;`）时不再注入，交给祖先链解析 *)
  let anc_mod_names (m : modt) : string list =
    let rec up acc (mm : modt) =
      let acc = List.fold_left (fun a (n, _) -> n :: a) acc mm.children in
      match mm.parent with
      | Some p -> up acc p
      | None -> acc
    in
    up [] m
  in
  let rec add_item modt it pub =
    match it with
    | IPub (it2, _) -> add_item modt it2 true
    | IMod (name, its, _p) ->
      add_local modt name pub "mod" (pos_of_item it);
      let c = mk_mod (modt.mpath @ [ name ]) modt.dir in
      c.parent <- Some modt;
      modt.children <- modt.children @ [ (name, c) ];
      modt.raw <- modt.raw @ [ it ];
      List.iter (fun x -> add_item c x false) its
    | IModFile (name, p) ->
      add_local modt name pub "mod" p;
      modt.raw <- modt.raw @ [ it ];
      (match find_mod_file modt.dir name with
       | None ->
         collect RDriver p
           (Printf.sprintf "module file not found: mod %s (looked for %s.zfy, %s%cm%czfy and <parents>%cstdlib%c%s.zfy)"
              name name name '/' 'm' '/' '/' name)
       | Some path ->
         let norm = String.lowercase_ascii (Filename.concat (Sys.getcwd ()) path) in
         if List.exists (fun (n, _) -> n = norm) !stack then begin
           (* include 环优先于重复加载判定（环路径上的文件必然已在 loaded） *)
           let ring = List.map snd (!stack @ [ (norm, name) ]) in
           collect RDriver p
             ("circular module dependency: " ^ String.concat " -> " ring)
         end else begin
           (* 同一模块文件被多处 mod 声明引用（如 main 与 store 都 mod model）：
              共享已加载的模块节点，挂到当前 mod 的 children——两处 use 经各自
              父链解析到同一棵子树，类型身份唯一（此前按 E5009 拒绝，但跨文件
              类型名解析器不可见，用户无法绕开，属真实项目结构缺陷） *)
           let c =
             match Hashtbl.find_opt loaded norm with
             | Some prev -> prev
             | None ->
               let c = mk_mod (modt.mpath @ [ name ]) (Filename.dirname path) in
               c.parent <- Some modt;
               Hashtbl.replace loaded norm c;
               let body =
                 fixup_uses (Filename.dirname path) (anc_mod_names modt)
                   (read_parse path)
               in
               (stack := !stack @ [ (norm, name) ];
                List.iter (fun x -> add_item c x false) body;
                (match List.rev !stack with
                 | _ :: r -> stack := List.rev r
                 | [] -> ()));
               c
           in
           modt.children <- modt.children @ [ (name, c) ]
         end)
    | IFn f -> add_local modt f.name pub "fn" f.pos; modt.raw <- modt.raw @ [ it ]
    | IStruct s -> add_local modt s.name pub "struct" s.pos; modt.raw <- modt.raw @ [ it ]
    | IEnum e -> add_local modt e.name pub "enum" e.pos; modt.raw <- modt.raw @ [ it ]
    | ITypeAlias a -> add_local modt a.name pub "alias" a.pos; modt.raw <- modt.raw @ [ it ]
    | IExtern e ->
      List.iter (fun fn -> add_local modt fn.ename pub "extern" fn.epos) e.funcs;
      modt.raw <- modt.raw @ [ it ]
    | IDecl (SDecl (_, _, _, n, _, _, p), _) when modt.mpath <> [] ->
      (* 模块内：只允许 const 标量（root 顶层全局变量合法，原样放行） *)
      add_local modt n pub "const" p; modt.raw <- modt.raw @ [ it ]
    | IDecl (_, p) when modt.mpath <> [] ->
      collect RDriver p "top-level declarations in modules must be const scalars"
    | IDecl _ -> modt.raw <- modt.raw @ [ it ]
    | IUse _ | IUseP _ -> modt.raw <- modt.raw @ [ it ]
    | IMod _ | IModFile _ -> assert false
  in
  List.iter (fun it -> add_item root it false) (fixup_uses root.dir [] main);

  (* ---- 阶段2：use 名字绑定解析（存在性 + 可见性 + 冲突） ---- *)
  let rec find_mod (m : modt) (mpath : string list) : modt option =
    match mpath with
    | [] -> Some m
    | s :: r ->
      (match child_opt m s with
       | Some c -> find_mod c r
       | None -> None)
  in
  let resolve_path (from_mod : modt) (segs : string list) (pos : pos) : bind_val option =
    let fail m = collect RDriver pos m; None in
    let rec descend (m : modt) segs =
      match segs with
      | [] -> Some (BMod m.mpath)
      | s :: rest ->
        (match child_opt m s with
         | Some c ->
           (* 路径中模块段本身须可见 *)
           (match local_find m s with
            | Some (_, pub, _) when visible from_mod m.mpath pub -> descend c rest
            | _ ->
              fail (Printf.sprintf "'%s' is not visible from module %s (module is private: only its ancestors/descendants can name it)"
                      s (module_str from_mod)))
         | None ->
           (match rest with
            | [] ->
              (match local_find m s with
               | Some (_, pub, _kind) ->
                 if visible from_mod m.mpath pub then
                   Some (BItem (flat_prefix m.mpath ^ s))
                 else
                   fail (Printf.sprintf "'%s' is not visible from module %s (private item: only the defining module and its ancestors/descendants can use it; declare it pub to export)"
                           s (module_str from_mod))
               | None ->
                 fail (Printf.sprintf "unresolved path: '%s' not found in module %s"
                         s (module_str m)))
            | _ ->
              fail (Printf.sprintf "unresolved path: '%s' in %s is not a module"
                      s (module_str m))))
    in
    match segs with
    | [] -> None
    | s :: rest ->
      if s = "crate" then descend root rest
      else if s = "self" then descend from_mod rest
      else if s = "super" then
        (match from_mod.parent with
         | Some par -> descend par rest
         | None -> fail "super: module has no parent (already at root)")
      else
        (match child_opt from_mod s with
         | Some c -> descend c rest
         | None ->
           (match Hashtbl.find_opt from_mod.binds s with
            | Some (BItem flat) ->
              (match rest with
               | [] -> Some (BItem flat)
               | _ -> fail (Printf.sprintf "'%s' (bound to %s) is not a module" s flat))
            | Some (BMod tp) ->
              (match find_mod root tp with
               | Some m -> descend m rest
               | None -> fail (Printf.sprintf "unresolved path: %s" (String.concat "::" segs)))
            | None ->
              (* 祖先链 children（近到远）；不做 fallback 到 root 之外的猜测 *)
              let rec up par =
                match par with
                | None -> None
                | Some pmod ->
                  (match child_opt pmod s with
                   | Some c -> Some c
                   | None -> up pmod.parent)
              in
              (match up from_mod.parent with
               | Some c -> descend c rest
               | None ->
                 fail (Printf.sprintf "unresolved path: '%s' not found (first segment must be a local submodule, a use binding, or an ancestor's submodule)"
                         s))))
  in
  (* 共享模块节点（同一文件被多处 mod 引用）只处理一次——物理相等去重，
     否则同一 use 绑定沿两条父链各登记一遍误报 E5009 *)
  let seen_binds : modt list ref = ref [] in
  let phys_eq a b = a == b in
  let rec resolve_binds (m : modt) : unit =
    if not (List.exists (phys_eq m) !seen_binds) then begin
      seen_binds := m :: !seen_binds;
      List.iter
        (function
          | IUseP { binds; _ } ->
            List.iter
              (fun (local, segs, bpos) ->
                match resolve_path m segs bpos with
                | Some bv ->
                  if List.exists (fun (n, _, _) -> n = local) m.locals
                     || Hashtbl.mem m.binds local then
                    collect RDriver bpos
                      (Printf.sprintf "name conflict: use binding '%s' already defined in module %s"
                         local (module_str m))
                  else Hashtbl.replace m.binds local bv
                | None -> ())
              binds
          | _ -> ())
        m.raw;
      List.iter (fun (_, c) -> resolve_binds c) m.children
    end
  in
  resolve_binds root;

  (* ---- use 依赖环检测 ---- *)
  let edges : (string, (string * pos) list) Hashtbl.t = Hashtbl.create 16 in
  let add_edge from to_ pos =
    let l = match Hashtbl.find_opt edges from with Some l -> l | None -> [] in
    if not (List.exists (fun (t, _) -> t = to_) l) && from <> to_ then
      Hashtbl.replace edges from (l @ [ (to_, pos) ])
  in
  let rec gather_edges (m : modt) : unit =
    Hashtbl.iter
      (fun _ bv ->
        let target =
          match bv with
          | BMod tp -> Some tp
          | BItem flat ->
            if has_dcolon flat then None
            else if String.contains flat '.' then
              (match List.rev (String.split_on_char '.' flat) with
               | _ :: r -> Some (List.rev r)
               | [] -> None)
            else Some []
        in
        match target with
        | Some tp -> add_edge (key_of m.mpath) (key_of tp) (pos_of_item (List.hd m.raw))
        | None -> ())
      m.binds;
    List.iter (fun (_, c) -> gather_edges c) m.children
  in
  gather_edges root;
  let state : (string, int) Hashtbl.t = Hashtbl.create 16 in   (* 0白 1灰 2黑 *)
  let rec dfs (k : string) (path : string list) : unit =
    Hashtbl.replace state k 1;
    (match Hashtbl.find_opt edges k with
     | Some es ->
       List.iter
         (fun (t, pos) ->
           let st = match Hashtbl.find_opt state t with Some s -> s | None -> 0 in
           if st = 1 then begin
             (* 环：path 中从 t 出现处起 + 当前 *)
             let rec take acc = function
               | x :: r when x <> t -> take (x :: acc) r
               | _ -> t :: List.rev acc
             in
             let ring = take [] path @ [ k; t ] in
             collect RDriver pos
               ("circular module dependency: " ^ String.concat " -> " ring)
           end
           else if st = 0 then dfs t (path @ [ k ])
           else ())
         es
     | None -> ());
    Hashtbl.replace state k 2
  in
  (match Hashtbl.find_opt edges (key_of root.mpath) with
   | Some _ -> dfs (key_of root.mpath) []
   | None -> ());
  Hashtbl.iter
    (fun k _ ->
      let st = match Hashtbl.find_opt state k with Some s -> s | None -> 0 in
      if st = 0 then dfs k [])
    edges;

  if !collected <> [] then begin
    rerrs := !collected;
    None
  end
  else begin
    (* ---- 阶段3：限定名扁平化 + 输出 ---- *)
    let resolve_name (m : modt) (name : string) (pos : pos) : string =
      if has_dcolon name then
        (match resolve_path m (split_dcolon name) pos with
         | Some (BItem flat) -> flat
         | Some (BMod _) -> name   (* 模块名作值：保留，typeck 报错 *)
         | None -> name)           (* 错误已收集；保留避免级联 *)
      else if String.contains name '.' then
        (* 点分名：首段为 use 绑定时展开（w-015 #2 整模块绑定）——
           BMod 沿剩余段下钻（子模块链 + 末段 item，可见性与 resolve_path
           同规则）取扁平名；BItem 或未绑定的点分名保留原样
           （legacy 命名空间/扁平名直查/字段路径） *)
        (match String.split_on_char '.' name with
         | hd :: rest when rest <> [] && Hashtbl.mem m.binds hd ->
           (match Hashtbl.find m.binds hd with
            | BItem _ -> name
            | BMod tp ->
              let rec go cur segs =
                match segs with
                | [] -> None
                | [ last ] ->
                  (match find_mod root cur with
                   | Some mm ->
                     (match local_find mm last with
                      | Some (_, pub, _) when visible m cur pub ->
                        Some (flat_prefix cur ^ last)
                      | _ -> None)
                   | None -> None)
                | s2 :: r2 ->
                  (match find_mod root cur with
                   | Some mm ->
                     (match child_opt mm s2 with
                      | Some c -> go c.mpath r2
                      | None -> None)
                   | None -> None)
              in
              (match go tp rest with
               | Some flat -> flat
               | None -> name))
         | _ -> name)
      else
        (match local_find m name with
         (* extern "C" 符号名不改（C 链接名恒为原名；IExtern 也不扁平化） *)
         | Some (_, _, k) when k <> "mod" && k <> "extern" ->
           flat_prefix m.mpath ^ name
         | Some _ -> name
         | None ->
           (match Hashtbl.find_opt m.binds name with
            | Some (BItem flat) -> flat
            | _ -> name))
    in
    let rec rw_ty (m : modt) (t : ty) : ty =
      match t with
      | TNamed (n, p) -> TNamed (resolve_name m n p, p)
      | TPtr (t2, p) -> TPtr (rw_ty m t2, p)
      | TPtrC (t2, p) -> TPtrC (rw_ty m t2, p)
      | TErr (t2, p) -> TErr (rw_ty m t2, p)
      | TSeq (t2, p) -> TSeq (rw_ty m t2, p)
      | TSeqN (t2, len, p) -> TSeqN (rw_ty m t2, len, p)
      | TFun (r, ps, p) -> TFun (rw_ty m r, List.map (rw_ty m) ps, p)
      | TApp (n, ts, p) -> TApp (resolve_name m n p, List.map (rw_ty m) ts, p)
      | TClo (ps, r, p) -> TClo (List.map (rw_ty m) ps, rw_ty m r, p)
    in
    let rec rw_expr (m : modt) (e : expr) : expr =
      match e with
      | EVar (n, p) -> EVar (resolve_name m n p, p)
      | EBigInt _ -> e
      | EBin (op, l, r, p) -> EBin (op, rw_expr m l, rw_expr m r, p)
      | EUn (op, x, p) -> EUn (op, rw_expr m x, p)
      | ECall (callee, args, p) ->
        ECall (rw_expr m callee,
               List.map
                 (function
                   | CPos x -> CPos (rw_expr m x)
                   | CMove x -> CMove (rw_expr m x)
                   | CCopy x -> CCopy (rw_expr m x)
                   | CRef x -> CRef (rw_expr m x)
                   | CNamed (s, x) -> CNamed (s, rw_expr m x))
                 args,
               p)
      | EIndex (b, i, p) -> EIndex (rw_expr m b, rw_expr m i, p)
      | ESlice (b, a, b2, st, p) ->
        ESlice (rw_expr m b, rw_expr m a, rw_expr m b2, Option.map (rw_expr m) st, p)
      | ECast (x, t, p) -> ECast (rw_expr m x, rw_ty m t, p)
      | EStructNew (n, args, p) ->
        EStructNew (resolve_name m n p,
                    List.map
                      (function
                        | CPos x -> CPos (rw_expr m x)
                        | CMove x -> CMove (rw_expr m x)
                        | CCopy x -> CCopy (rw_expr m x)
                        | CRef x -> CRef (rw_expr m x)
                        | CNamed (s, x) -> CNamed (s, rw_expr m x))
                      args,
                    p)
      | EField (b, f, p) -> EField (rw_expr m b, f, p)
      | EBlock (bl, p) -> EBlock (rw_block m bl, p)
      | EAddrOf (x, p) -> EAddrOf (rw_expr m x, p)
      | EDeref (x, p) -> EDeref (rw_expr m x, p)
      | ENull _ -> e
      | EFail (c, msg, p) -> EFail (rw_expr m c, rw_expr m msg, p)
      | EPanic (c, msg, p) -> EPanic (Option.map (rw_expr m) c, rw_expr m msg, p)
      | EUnwrap (a, b, p) -> EUnwrap (rw_expr m a, rw_expr m b, p)
      | EPropagate (x, p) -> EPropagate (rw_expr m x, p)
      | ERemove (b, i, p) -> ERemove (rw_expr m b, rw_expr m i, p)
      | ELambda (lam, p) ->
        ELambda ({ lam with
                   lparams = lam.lparams;
                   lcaps = lam.lcaps;
                   lbody = (match lam.lbody with
                            | LExpr x -> LExpr (rw_expr m x)
                            | LBlock (bl, rt) -> LBlock (rw_block m bl, rt)) },
                  p)
      | EInt _ | EFloat _ | EStr _ | EChar _ | EBool _ -> e
    and rw_block m bl = List.map (rw_stmt m) bl
    and rw_stmt m (s : stmt) : stmt =
      match s with
      | SDecl (a, b, c, n, t, ie, p) ->
        SDecl (a, b, c, n, Option.map (rw_ty m) t, Option.map (rw_expr m) ie, p)
      | SSeqDecl (a, f2, u2, n, t, len, isl, inits, p) ->
        SSeqDecl (a, f2, u2, n, rw_ty m t, Option.map (rw_expr m) len, isl,
                  List.map (rw_expr m) inits, p)
      | SDeclList ss -> SDeclList (List.map (rw_stmt m) ss)
      | SAssign (l, r, p) -> SAssign (rw_expr m l, rw_expr m r, p)
      | SAssignList (l, rs, p) ->
        SAssignList (rw_expr m l, List.map (rw_expr m) rs, p)
      | SAug (op, l, r, p) -> SAug (op, rw_expr m l, rw_expr m r, p)
      | SInc (x, p) -> SInc (rw_expr m x, p)
      | SDec (x, p) -> SDec (rw_expr m x, p)
      | SExpr x -> SExpr (rw_expr m x)
      | SReturn (x, p) -> SReturn (Option.map (rw_expr m) x, p)
      | SIf (c, a, b, p) ->
        SIf (rw_expr m c, rw_block m a, Option.map (rw_block m) b, p)
      | SWhile (c, b, p) -> SWhile (rw_expr m c, rw_block m b, p)
      | SFor (inits, c, ups, b, p) ->
        SFor
          (List.map
             (function
               | FIDecl (a, f2, u2, n, t, ie, p) ->
                 FIDecl (a, f2, u2, n, Option.map (rw_ty m) t, Option.map (rw_expr m) ie, p)
               | FIExpr (x, p) -> FIExpr (rw_expr m x, p))
             inits,
           rw_expr m c,
           List.map
             (function
               | FUAssign (l, r, p) -> FUAssign (rw_expr m l, rw_expr m r, p)
               | FUOp (op, l, r, p) -> FUOp (op, rw_expr m l, rw_expr m r, p)
               | FUInc (x, p) -> FUInc (rw_expr m x, p)
               | FUDec (x, p) -> FUDec (rw_expr m x, p))
             ups,
           rw_block m b,
           p)
      | SOutput (es, sep, endd, p) ->
        SOutput (List.map (rw_expr m) es, Option.map (rw_expr m) sep,
                 Option.map (rw_expr m) endd, p)
      | SInput (ts, d, p) ->
        SInput
          (List.map
             (function
               | InNew (n, t, p) -> InNew (n, rw_ty m t, p)
               | InUse (n, p) -> InUse (n, p))
             ts,
           Option.map (rw_expr m) d,
           p)
      | SReduce (a, b, c, p) ->
        SReduce (rw_expr m a, rw_expr m b, rw_expr m c, p)
      | SForIn (n, idx, sx, b, p) ->
        SForIn (n, idx, rw_expr m sx, rw_block m b, p)
      | SBlock (bs, p) -> SBlock (rw_block m bs, p)
      | SUnsafe (b, p) -> SUnsafe (rw_block m b, p)
      | SFn (nm, params, ret, fr, body, p) ->
        SFn (nm, params, Option.map (rw_ty m) ret, fr, rw_block m body, p)
      | SMatch (sx, arms, p) ->
        SMatch
          (rw_expr m sx,
           List.map
             (fun (a : marm) ->
               { mpat =
                   (match a.mpat with
                    | PWild -> PWild
                    | PLit e -> PLit (rw_expr m e)
                    | PVar (vn, bs, vp) ->
                           PVar (resolve_name m vn a.mpos, bs, vp));
                 mbody = rw_block m a.mbody;
                 mpos = a.mpos })
             arms,
           p)
      | SBreak _ | SContinue _ -> s
    in
    let rw_param m pr = { pr with pty = rw_ty m pr.pty } in
    let rw_field m f =
      { f with fty = rw_ty m f.fty; fdefault = Option.map (rw_expr m) f.fdefault }
    in
    let out : item list ref = ref [] in
    let seen_emit : modt list ref = ref [] in   (* emit 阶段独立去重表 *)
    let rec emit_item (m : modt) (it : item) : unit =
      match it with
      | IFn f ->
        out := IFn { name = flat_prefix m.mpath ^ f.name;
                     params = List.map (rw_param m) f.params;
                     ret = Option.map (rw_ty m) f.ret;
                     rfrac = f.rfrac;
                     runred = f.runred;
                     body = rw_block m f.body;
                     pos = f.pos;
                     tparams = f.tparams } :: !out
      | IStruct s ->
        out := IStruct { name = flat_prefix m.mpath ^ s.name; packed = s.packed;
                         fields = List.map (rw_field m) s.fields; pos = s.pos;
                         tparams = s.tparams;
                         methods =
                           List.map
                             (fun mth ->
                               (* v3.3.8 修复：方法参数/返回类型同样要扁平化
                                  （此前只重写 mbody，mod 文件内方法的 struct
                                  类型参数保持裸名 → E3001 undefined type） *)
                               { mth with
                                 mparams = List.map (rw_param m) mth.mparams;
                                 mret = Option.map (rw_ty m) mth.mret;
                                 mbody = rw_block m mth.mbody })
                             s.methods } :: !out
      | IEnum e ->
        out := IEnum { name = flat_prefix m.mpath ^ e.name;
                       variants =
                         List.map (fun (vn, pys) -> (vn, List.map (rw_ty m) pys))
                           e.variants;
                       pos = e.pos } :: !out
      | ITypeAlias a ->
        out := ITypeAlias { name = flat_prefix m.mpath ^ a.name;
                            ty = rw_ty m a.ty; pos = a.pos } :: !out
      | IExtern e -> out := IExtern e :: !out   (* C 符号名不改 *)
      | IDecl (SDecl (a, b, c, n, t, ie, p), pd) ->
        (* 顶层 const：名字也要扁平化（与引用处的 resolve_name 对齐） *)
        out := IDecl
                 (SDecl (a, b, c, flat_prefix m.mpath ^ n, Option.map (rw_ty m) t,
                         Option.map (rw_expr m) ie, p),
                 pd) :: !out
      | IDecl (d, p) -> out := IDecl (rw_stmt m d, p) :: !out
      | IUse _ | IUseP _ | IMod _ | IModFile _ | IPub _ -> ()
    in
    let rec emit_tree (m : modt) ~(is_root : bool) : unit =
      (* 共享模块节点只 emit 一次（同 resolve_binds 的物理相等去重） *)
      if is_root || not (List.exists (fun v -> v == m) !seen_emit) then begin
        if not is_root then seen_emit := m :: !seen_emit;
        List.iter
        (function
          | IMod (name, _, _) | IModFile (name, _) ->
            (match child_opt m name with
             | Some c -> emit_tree c ~is_root:false
             | None -> ())   (* 加载失败的文件模块：错误已收集，跳过 *)
          | IUseP _ -> ()
          | IUse u ->
            (* legacy use：root 保留给后续 expand_uses；模块内无法处理 *)
            if is_root then out := IUse u :: !out
            else
              collect RDriver u.pos
                "legacy use (file.zfy) is only allowed at file top level, not inside mod"
          | it -> emit_item m it)
        m.raw
      end
    in
    emit_tree root ~is_root:true;
    (* 阶段3 内部（resolve_name 改写）也会收集错误：失败则整体拒绝输出，
       避免半改写的扁平 program 泄漏到 typeck 产生级联错误 *)
    if !collected <> [] then begin
      rerrs := !collected;
      None
    end
    else Some (List.rev !out)
  end
