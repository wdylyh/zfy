# -*- coding: utf-8 -*-
# 重写 typeck.ml 中 check_lambda 区间（1178..1444）为干净版
import io

P = r"D:\zfy\compiler\lib\typeck.ml"
lines = io.open(P, encoding="utf-8").read().split("\n")
# 行号 1-based：1178..1444 替换（含），即 index 1177..1443
head = lines[:1177]
tail = lines[1444:]

new = r'''(* ---------- lambda / 嵌套函数（v3.7 函数式轮） ---------- *)

(* env 字段访问 texpr：值捕获 = EField(deref env, idx)；
   引用捕获 = deref(EField(deref env, idx))（字段类型 TPtr，idx 0 = code 头） *)
and cap_ref env idx is_ref ty p' =
  match env.capctx with
  | Some cc ->
    let envp = { e = EVarK "$env"; ety = TPtr (TStruct cc.clenv); epos = p' } in
    let deref_env = { e = EDerefK envp; ety = TStruct cc.clenv; epos = p' } in
    let fld = { e = EFieldK (deref_env, idx);
                ety = (if is_ref then TPtr ty else ty); epos = p' } in
    if is_ref then { e = EDerefK fld; ety = ty; epos = p' } else fld
  | None -> assert false

(* lambda 捕获尝试：本地 miss 且在 lambda 体上下文 → 外层局部变量登记
   捕获（隐式值捕获；显式 [&x] 引用捕获在 check_lambda 入口预登记）。
   全局('@')/const(内联)/不可捕获类型返回 None 落普通路径 *)
and try_capture env name p' =
  match env.capctx with
  | None -> None
  | Some cc ->
    if String.contains name '.' || name = "err" then None
    else begin
      let skip = List.length env.scopes - cc.base in
      let rec go n = function
        | [] -> None
        | sc :: rest ->
          if n < skip then go (n + 1) rest
          else match Hashtbl.find_opt sc name with
               | Some l -> Some l
               | None -> go (n + 1) rest
      in
      match go 0 env.scopes with
      | Some l
        when not (String.length l.lslot > 0 && l.lslot.[0] = '@')
             && not l.lconst && cap_ty_ok l.lty ->
        (match Hashtbl.find_opt cc.caps name with
         | Some (idx, is_ref, ty, _) -> Some (cap_ref env idx is_ref ty p')
         | None ->
           let idx = Hashtbl.length cc.caps + 1 in
           Hashtbl.replace cc.caps name (idx, false, l.lty, p');
           Some (cap_ref env idx false l.lty p'))
      | _ -> None
    end

(* lambda 检查（v3.7）：ELambda 表达式与 SFn 嵌套函数共用。
   nmopt = Some 名（嵌套函数，实例名用其名）；产 EClNewK（h 句柄）。
   实例 tfn（env 参数 + 捕获改写后的 body）进 lambda_out_acc。
   v1 约定：lambda 参数必须显式类型；捕获字段限标量/string/bool/char/
   指针/句柄（seq/struct 捕获不支持）；env 堆块生命周期 = 进程。 *)
and check_lambda env (lam : lambda) (lp : pos) (nmopt : string option) =
  let mk k ty = { e = k; ety = ty; epos = lp } in
  let ptys =
    List.map
      (fun (prm : lparam) ->
        match prm.lpty with
        | Some t -> resolve (conv_ty env.g prm.lppos t)
        | None ->
          terr prm.lppos
            "lambda parameter '%s' needs an explicit type, e.g. fn(i32 x) => x * 2 (context inference is not supported yet)"
            prm.lpname)
      lam.lparams
  in
  List.iter
    (fun z ->
      if not (cap_ty_ok z) then
        terr lp "lambda parameter type %s is not supported (v1: scalar/string/pointer)"
          (pp_zty z))
    ptys;
  let ret0 =
    match lam.lbody with
    | LBlock (_, Some rt) -> Some (resolve (conv_ty env.g lp rt))
    | LBlock (_, None) -> assert false
    | LExpr _ -> None   (* 由体表达式类型决定 *)
  in
  (match ret0 with
   | Some r ->
     (match resolve r with
      | TVoid | TInt _ | TUint _ | TFloat _ | TBool | TChar | TString -> ()
      | _ -> terr lp "lambda return type %s is not supported (v1: scalar/string/void)" (pp_zty r))
   | None -> ());
  incr lambda_cnt;
  let n = !lambda_cnt in
  let clenv_name = Printf.sprintf "clenv$%d" n in
  let fname =
    match nmopt with
    | Some nm -> Printf.sprintf "lambda$%s$%d" nm n
    | None -> Printf.sprintf "lambda$%d" n
  in
  let cc = { caps = Hashtbl.create 4; clenv = clenv_name;
             base = List.length env.scopes } in
  let saved_uses = env.uses in
  let saved_fnvars = env.fnvars in
  let saved_moved = env.moved in
  let saved_ret = env.fncur_ret in
  let saved_cap = env.capctx in
  let saved_ldepth = env.ldepth in
  let saved_slotn = env.slotn in
  let r =
    try
      env.fnvars <- Hashtbl.create 8;
      env.moved <- Hashtbl.create 8;
      env.uses <- [];
      env.ldepth <- 0;
      env.capctx <- Some cc;
      (* 显式引用捕获预登记（名字须为外层局部变量；字段序随登记序） *)
      List.iter
        (fun (is_ref, cn, cp) ->
          if Hashtbl.mem cc.caps cn then
            terr cp "capture '%s' listed twice" cn;
          let skip = List.length env.scopes - cc.base in
          let rec go k = function
            | [] ->
              terr cp "captured variable '%s' is not a local variable of the enclosing function" cn
            | sc :: rest ->
              if k < skip then go (k + 1) rest
              else match Hashtbl.find_opt sc cn with
                   | Some l -> l
                   | None -> go (k + 1) rest
          in
          let l = go 0 env.scopes in
          if String.length l.lslot > 0 && l.lslot.[0] = '@' then
            terr cp "cannot capture global '%s' by reference (globals are always accessible directly)" cn;
          if l.lconst then
            terr cp "cannot capture const '%s'" cn;
          if not (cap_ty_ok l.lty) then
            terr cp "captured variable '%s' has unsupported type %s" cn (pp_zty l.lty);
          let idx = Hashtbl.length cc.caps + 1 in
          Hashtbl.replace cc.caps cn (idx, is_ref, l.lty, cp))
        lam.lcaps;
      push_scope env;
      declare env "$env"
        { lconst = false; lty = TPtr (TStruct clenv_name); lslot = "";
          lunred = false; lconstp = false };
      let envslot =
        match lookup_var env "$env" with
        | Some l -> l.lslot | None -> assert false
      in
      let param_slots =
        List.map
          (fun (prm : lparam) z ->
            declare env prm.lpname
              { lconst = false; lty = z; lslot = ""; lunred = false; lconstp = false };
            let slot =
              match lookup_var env prm.lpname with
              | Some l -> l.lslot | None -> assert false
            in
            (false, slot, z, false))
          lam.lparams ptys
      in
      let (tret, tbody) =
        match lam.lbody with
        | LExpr e ->
          let te = check_expr env e in
          let rt = resolve te.ety in
          (rt, [ { s = SExprK te; spos = lp } ])
        | LBlock (blk, Some _) ->
          env.fncur_ret <- (match ret0 with Some r -> r | None -> assert false);
          let tb = check_block env blk in
          ((match ret0 with Some r -> r | None -> assert false), tb)
      in
      pop_scope env;
      (* 缺 return 检查（非 void） *)
      (match ret0 with
       | Some r ->
         (match resolve r with
          | TVoid -> ()
          | _ ->
            let has_ret =
              List.exists (fun (st : tstmt) ->
                match st.s with
                | SReturnK _ -> true
                | SUnwrapBlockK (_, true, _, _, _, _, _) -> true
                | _ -> false) tbody
              ||
              (match List.rev tbody with
               | { s = SExprK _; _ } :: _ -> true
               | _ -> false)
            in
            if not has_ret then
              terr lp "lambda declares return type %s but may not return a value" (pp_zty r))
       | None -> ());
      env.capctx <- saved_cap;
      env.fncur_ret <- saved_ret;
      env.uses <- saved_uses;
      env.fnvars <- saved_fnvars;
      env.moved <- saved_moved;
      env.ldepth <- saved_ldepth;
      env.slotn <- saved_slotn;
      while List.length env.scopes > cc.base do pop_scope env done;
      (* 冻结捕获表 → 注册 clenv$N struct（字段 0 = code 头） *)
      let caps_list =
        List.sort (fun a b -> compare (fun (i, _, _, _, _) -> i) a b)
          (Hashtbl.fold (fun cn (idx, is_ref, ty, cpos) acc ->
             (idx, cn, is_ref, ty, cpos) :: acc) cc.caps [])
      in
      let env_fields =
        [ ("code", TPtr (TUint 8)) ] @
        List.map (fun (_, cn, is_ref, ty, _) ->
            (cn, if is_ref then TPtr ty else ty)) caps_list
      in
      if not (Hashtbl.mem env.g.structs clenv_name) then
        Hashtbl.replace env.g.structs clenv_name
          { spacked = false;
            sfields = List.map (fun (fn2, ft) -> (fn2, ft, None)) env_fields };
      (* 组装 tfn 并登记 lambda 函数签名（首参 env 指针） *)
      let sig_params = TPtr (TStruct clenv_name) :: ptys in
      Hashtbl.replace env.g.fns fname
        { params = sig_params;
          prefs = List.map (fun _ -> false) sig_params;
          ret = tret; runred = false };
      let tf = { fname;
                 fparams = (false, envslot, TPtr (TStruct clenv_name), false) :: param_slots;
                 fret = tret; frunred = false; fbody = tbody } in
      lambda_out_acc := !lambda_out_acc @ [ tf ];
      (tret, ptys, caps_list)
    with TypeError (p2, m2) ->
      env.capctx <- saved_cap;
      env.fncur_ret <- saved_ret;
      env.uses <- saved_uses;
      env.fnvars <- saved_fnvars;
      env.moved <- saved_moved;
      env.ldepth <- saved_ldepth;
      env.slotn <- saved_slotn;
      while List.length env.scopes > cc.base do pop_scope env done;
      raise (TypeError (p2, m2))
  in
  let (tret, ptys, caps_list) = r in
  let mangle = ensure_clo_struct env.g tret ptys in
  (* caps 实参：重新 check 外层变量（capctx 已恢复）——值捕获读槽，
     引用捕获取地址；深拷贝由 llvmgen MClNew 按类型完成 *)
  let caps_ops =
    List.map
      (fun (_, cn, is_ref, _, cpos) ->
        let v = check_expr env (EVar (cn, cpos)) in
        if is_ref then
          { e = EAddrOfK v; ety = TPtr v.ety; epos = cpos }
        else v)
      caps_list
  in
  mk (EClNewK (mangle, clenv_name, caps_ops)) (TStruct mangle)'''

out = head + new.split("\n") + tail
io.open(P, "w", encoding="utf-8", newline="\n").write("\n".join(out))
print("ok, new total lines:", len(out))
