(*
 * Copyright (c) 2016 - present Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 *)

open! IStd
module F = Format

let all_formals_untainted pdesc =
  let make_untainted (name, typ) = (name, typ, None) in
  List.map ~f:make_untainted (Procdesc.get_formals pdesc)


module type Kind = sig
  include TraceElem.Kind

  val get : Typ.Procname.t -> HilExp.t list -> Tenv.t -> (t * int option) option

  val get_tainted_formals : Procdesc.t -> Tenv.t -> (Mangled.t * Typ.t * t option) list
end

module type S = sig
  include TraceElem.S

  type spec = {source: t; index: int option}

  val get : CallSite.t -> HilExp.t list -> Tenv.t -> spec option

  val get_tainted_formals : Procdesc.t -> Tenv.t -> (Mangled.t * Typ.t * t option) list
end

module Make (Kind : Kind) = struct
  module Kind = Kind

  type t = {kind: Kind.t; site: CallSite.t} [@@deriving compare]

  type spec = {source: t; index: int option}

  let call_site t = t.site

  let kind t = t.kind

  let make ?indexes:_ kind site = {site; kind}

  let get site actuals tenv =
    match Kind.get (CallSite.pname site) actuals tenv with
    | Some (kind, index) ->
        let source = make kind site in
        Some {source; index}
    | None ->
        None


  let get_tainted_formals pdesc tenv =
    let site = CallSite.make (Procdesc.get_proc_name pdesc) (Procdesc.get_loc pdesc) in
    List.map
      ~f:(fun (name, typ, kind_opt) ->
        (name, typ, Option.map kind_opt ~f:(fun kind -> make kind site)))
      (Kind.get_tainted_formals pdesc tenv)


  let pp fmt s = F.fprintf fmt "%a(%a)" Kind.pp s.kind CallSite.pp s.site

  let with_callsite t callee_site = {t with site= callee_site}

  module Set = PrettyPrintable.MakePPSet (struct
    type nonrec t = t

    let compare = compare

    let pp = pp
  end)
end

module Dummy = struct
  type t = unit [@@deriving compare]

  type spec = {source: t; index: int option}

  let call_site _ = CallSite.dummy

  let kind t = t

  let make ?indexes:_ kind _ = kind

  let pp _ () = ()

  let get _ _ _ = None

  let get_tainted_formals pdesc _ =
    List.map ~f:(fun (name, typ) -> (name, typ, None)) (Procdesc.get_formals pdesc)


  module Kind = struct
    type nonrec t = t

    let compare = compare

    let matches ~caller ~callee = Int.equal 0 (compare caller callee)

    let pp = pp
  end

  module Set = PrettyPrintable.MakePPSet (struct
    type nonrec t = t

    let compare = compare

    let pp = pp
  end)

  let with_callsite t _ = t
end
