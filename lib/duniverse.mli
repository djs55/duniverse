type unresolved = Git.Ref.t

type resolved = Git.Ref.resolved

module Deps : sig
  module Opam : sig
    type t = { name : string; version : string option }
    (** Type of dependencies to install through opam *)

    val equal : t -> t -> bool

    val pp : t Fmt.t
  end

  module Source : sig
    type 'ref t = { dir : string; upstream : string; ref : 'ref; provided_packages : Opam.t list }
    (** Type of dependencies to clone in the duniverse *)

    val equal : ('ref -> 'ref -> bool) -> 'ref t -> 'ref t -> bool

    (**/**)

    (* Exposed for test purposes only *)

    val raw_pp : 'ref Fmt.t -> 'ref t Fmt.t

    module Package : sig
      type t = { opam : Opam.t; upstream : string; ref : unresolved }
    end

    val aggregate : unresolved t -> Package.t -> unresolved t

    val aggregate_packages : Package.t list -> unresolved t list

    (**/**)
  end

  type 'ref t = { opamverse : Opam.t list; duniverse : 'ref Source.t list }
  (** The type for dependencies of a project. The duniverse and opamverse are complementary,
      that is a dependency either can be installed by pulling the sources and is in the duniverse
      or has to be installed through opam and is in the opamverse. *)

  val equal : ('ref -> 'ref -> bool) -> 'ref t -> 'ref t -> bool

  val from_opam_entries :
    get_default_branch:(string -> (string, Rresult.R.msg) result) ->
    Types.Opam.entry list ->
    (unresolved t, [ `Msg of string ]) result
  (** Build opamverse and duniverse from a list of [Types.Opam.entry] values.
      It filters out virtual packages and packages with unknown dev-repo.  *)

  val resolve :
    resolve_ref:(upstream:string -> ref:unresolved -> (resolved, Rresult.R.msg) result) ->
    unresolved t ->
    (resolved t, Rresult.R.msg) result
  (** Apply the given [resolve_ref] function to bind each source repo to a specific commit
      rather than a "floating" ref. *)

  val count : _ t -> int
  (** Returns the total number of dependencies represented by the given [t] value. *)

  (**/**)

  (* Exposed for test purposes only *)

  val raw_pp : 'ref Fmt.t -> 'ref t Fmt.t

  module Classified : sig
    type t = Opam of Opam.t | Source of Source.Package.t

    val equal : t -> t -> bool

    val raw_pp : t Fmt.t

    val from_opam_entry :
      get_default_branch:(string -> (string, Rresult.R.msg) result) ->
      Types.Opam.entry ->
      (t option, [ `Msg of string ]) result
  end

  (**/**)
end

module Config : sig
  type pull_mode = Submodules | Source [@@deriving sexp]

  type t = {
    version : string;
    root_packages : Types.Opam.package list;
    pull_mode : pull_mode; [@default Submodules]
    ocaml_compilers : string list; [@default []]
  }
  [@@deriving sexp]
end

type t = { config : Config.t; deps : resolved Deps.t } [@@deriving sexp]

(* Converts a [t] to an opam file.
   Extensions are used to store extra information and depends, pin-depends and depexts
   fields are properly set so that the resulting lockfile can be reproducibly
   opam-installed. *)
val to_opam : t -> OpamFile.OPAM.t

(* Parses a duniverse generated opam lockfile to a [t] value.
   The optional [file] argument is used for improved error reporting only, it should
   be passed when available. *)
val from_opam : ?file:string -> OpamFile.OPAM.t -> (t, [> `Msg of string ]) result

val load : file:Fpath.t -> (t, [> `Msg of string ]) result

val save : file:Fpath.t -> t -> (unit, [> `Msg of string ]) result

(* Load a [t] from a legacy dune-get file.
   Should be used for migration to the .opam.locked format only. *)
val load_dune_get : file:Fpath.t -> (t, [> `Msg of string ]) result
  [@@deprecated "dune-get files are a legacy format, you should use load instead"]
