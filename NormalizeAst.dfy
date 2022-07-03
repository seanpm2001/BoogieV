include "BoogieLang.dfy"
include "BoogieSemantics.dfy"
include "Util.dfy"

module NormalizeAst {
  import opened BoogieLang
  import opened BoogieSemantics
  import opened Wrappers
  import Util

  function SeqCmdOpt(c1Opt: Option<Cmd>, c2Opt: Option<Cmd>) : Option<Cmd>
  {
    if c1Opt.Some? && c2Opt.Some? then
      Some(Seq(c1Opt.value, c2Opt.value))
    else if c1Opt.Some? then
      Some(c1Opt.value)
    else
      c2Opt
  }

  function SeqSimpleOptCmd(c1Opt: Option<SimpleCmd>, c2: Cmd) : Cmd
  {
    if c1Opt.Some? then
      Seq(SimpleCmd(c1Opt.value), c2)
    else 
      c2
  }

  function SeqCmdSimpleOpt(c1Opt: Option<Cmd>, c2Opt: Option<SimpleCmd>) : Cmd
    requires c1Opt.Some? || c2Opt.Some?
  {
    if c1Opt.Some? && c2Opt.Some? then
      Seq(c1Opt.value, SimpleCmd(c2Opt.value))
    else if c1Opt.Some? then
      c1Opt.value
    else
      SimpleCmd(c2Opt.value)
  }

  /** Makes sure that adjacent simple commands are combined into the same simple command.
      This way the AST-to-CFG transformation can be made simpler while reducing the number of generated
      basic blocks. */
  function NormalizeAst(c: Cmd, precedingSimple: Option<SimpleCmd>) : (Option<Cmd>, Option<SimpleCmd>)
    ensures var (cOpt', scExitOpt) := NormalizeAst(c, precedingSimple); cOpt'.Some? || scExitOpt.Some?
  {
    match c 
    case SimpleCmd(sc) => 
      if precedingSimple.Some? then (None, Some(SeqSimple(precedingSimple.value, sc))) else (None, Some(sc))
    case Break(_) => 
      (Some(SeqSimpleOptCmd(precedingSimple, c)), None)
    case Seq(c1, c2) => 
      var (c1Opt', scExitOpt1) := NormalizeAst(c1, precedingSimple);
      var (c2Opt', scExitOpt2) := NormalizeAst(c2, scExitOpt1);

      var prefixCmd := SeqCmdOpt(c1Opt', c2Opt');
      
      (prefixCmd, scExitOpt2)
    case Scope(optLabel, varDecls, body) =>
      var (body', scExitOpt) := NormalizeAst(body, None);
      var bodyNew := SeqCmdSimpleOpt(body', scExitOpt);

      (Some(SeqSimpleOptCmd(precedingSimple, Scope(optLabel, varDecls, bodyNew))), None)
    case If(optCond, thn, els) =>
      var (thnOpt', scExitOpt1) := NormalizeAst(thn, None);
      var (elsOpt', scExitOpt2) := NormalizeAst(els, None);

      var thn' := SeqCmdSimpleOpt(thnOpt', scExitOpt1);
      var els' := SeqCmdSimpleOpt(elsOpt', scExitOpt2);

      (Some(SeqSimpleOptCmd(precedingSimple, If(optCond, thn', els'))), None)
    case Loop(invs, body) =>
      var (bodyOpt', scExitOpt) := NormalizeAst(body, None);
      var body' := SeqCmdSimpleOpt(bodyOpt', scExitOpt);

      (Some(SeqSimpleOptCmd(precedingSimple, Loop(invs, body') )), None)
  }

  lemma TransformAstCorrectness<A(!new)>(a: absval_interp<A>, c: Cmd, precedingSimple: Option<SimpleCmd>, post: WpPostShallow<A>, s: state<A>)
    requires LabelsWellDefAux(SeqSimpleOptCmd(precedingSimple, c), post.scopes.Keys)
    requires var (cOpt', scExitOpt):= NormalizeAst(c, precedingSimple);
             LabelsWellDefAux(SeqCmdSimpleOpt(cOpt', scExitOpt), post.scopes.Keys)
    ensures 
      var (cOpt', scExitOpt):= NormalizeAst(c, precedingSimple);
      WpShallow(a, SeqSimpleOptCmd(precedingSimple, c), post)(s) == 
      WpShallow(a, SeqCmdSimpleOpt(cOpt', scExitOpt), post)(s)
  {
    reveal WpShallow();

    var (cOpt', scExitOpt):= NormalizeAst(c, precedingSimple);

    match c
    case SimpleCmd(sc) =>
    case Break(_) =>
    case Seq(c1, c2) => 
      var (c1Opt', scExitOpt1) := NormalizeAst(c1, precedingSimple);
      var (c2Opt', scExitOpt2) := NormalizeAst(c2, scExitOpt1);
      var post2 := WpShallow(a, c2, post);

      calc {
        WpShallow(a, SeqSimpleOptCmd(precedingSimple, Seq(c1,c2)), post)(s); 
        WpShallow(a, SeqSimpleOptCmd(precedingSimple, c1), WpPostShallow(post2, post.currentScope, post.scopes))(s); //IH1
          { TransformAstCorrectness(a, c1, precedingSimple, WpPostShallow(post2, post.currentScope, post.scopes), s); }
        WpShallow(a, SeqCmdSimpleOpt(c1Opt', scExitOpt1), WpPostShallow(post2, post.currentScope, post.scopes))(s);
      }

      if c1Opt'.Some? {
        var p := WpPostShallow(WpShallow(a, SeqSimpleOptCmd(scExitOpt1, c2), post), post.currentScope, post.scopes);
        var q := WpPostShallow(WpShallow(a, SeqCmdSimpleOpt(c2Opt', scExitOpt2), post), post.currentScope, post.scopes);

        calc {
          WpShallow(a, SeqCmdSimpleOpt(c1Opt', scExitOpt1), WpPostShallow(post2, post.currentScope, post.scopes))(s);
          WpShallow(a, c1Opt'.value, p)(s); 
            { 
              forall s' | true 
              ensures WpShallow(a, SeqSimpleOptCmd(scExitOpt1, c2), post)(s') ==
                      WpShallow(a, SeqCmdSimpleOpt(c2Opt', scExitOpt2), post)(s')
              {
                TransformAstCorrectness(a, c2, scExitOpt1, post, s');
              }

              WpShallowPointwise(a, c1Opt'.value, p, q, s);
            }//IH2 + WP pointwise
          WpShallow(a, c1Opt'.value, q)(s);
          WpShallow(a, Seq(c1Opt'.value, SeqCmdSimpleOpt(c2Opt', scExitOpt2)), post)(s);
          WpShallow(a, SeqCmdSimpleOpt(SeqCmdOpt(c1Opt', c2Opt'), scExitOpt2), post)(s);
        }
      } else {
          TransformAstCorrectness(a, c2, scExitOpt1, post, s);
      }
    case Scope(optLabel, varDecls, body) =>
      var (body', scExitOpt) := NormalizeAst(body, None);
      var bodyNew := SeqCmdSimpleOpt(body', scExitOpt);
      var updatedScopes := if optLabel.Some? then post.scopes[optLabel.value := post.normal] else post.scopes;

      var post' := WpPostShallow(post.normal, post.normal, updatedScopes);
      var updatedPost := prevState => ResetVarsPost(varDecls, post', prevState);

      assert updatedScopes.Keys == if optLabel.Some? then {optLabel.value} + post.scopes.Keys else post.scopes.Keys;

      forall s' | true
        ensures LabelsWellDefAux(body, updatedPost(s').scopes.Keys)
      { }

      forall s' | true
        ensures LabelsWellDefAux(bodyNew, updatedPost(s').scopes.Keys)
      { }

      forall s',sPrev | true
      ensures WpShallow(a, body, updatedPost(sPrev))(s') == WpShallow(a, bodyNew, updatedPost(sPrev))(s')
      {

        assert updatedPost(sPrev).scopes.Keys == if optLabel.Some? then {optLabel.value} + post.scopes.Keys else post.scopes.Keys;
        TransformAstCorrectness(a, body, None, updatedPost(sPrev), s');
      }

      forall s' | true
        ensures ForallVarDeclsShallow(a, varDecls, WpShallow(a, body, updatedPost(s')))(s') == ForallVarDeclsShallow(a, varDecls, WpShallow(a, bodyNew, updatedPost(s')))(s')
      {
        assert forall s' :: WpShallow(a, body, updatedPost(s'))(s') == WpShallow(a, bodyNew, updatedPost(s'))(s');
        ForallVarDeclsPointwise(a, varDecls,  WpShallow(a, body, updatedPost(s')), WpShallow(a, bodyNew, updatedPost(s')), s');
      }

      var c' := SeqSimpleOptCmd(precedingSimple, Scope(optLabel, varDecls, bodyNew));

      forall s' | true
      ensures WpShallow(a, Scope(optLabel, varDecls, body), post)(s') == WpShallow(a, Scope(optLabel, varDecls, bodyNew), post)(s')
      {
        calc {
          WpShallow(a, Scope(optLabel, varDecls, body), post)(s');
          ForallVarDeclsShallow(a, varDecls, WpShallow(a, body, updatedPost(s')))(s');
        }
      }
      
      if(precedingSimple.Some?) {
        var post1 := WpPostShallow(WpShallow(a, c, post), post.currentScope, post.scopes);
        var post2 := WpPostShallow(WpShallow(a, Scope(optLabel, varDecls, bodyNew), post), post.currentScope, post.scopes);
        calc {
          WpShallow(a, Seq(SimpleCmd(precedingSimple.value), c), post)(s);
          WpShallow(a, SimpleCmd(precedingSimple.value), post1)(s); 
          { 
            WpShallowPointwise(a, SimpleCmd(precedingSimple.value), post1, post2, s); }
          WpShallow(a, SimpleCmd(precedingSimple.value), post2)(s);
        }
      }     
    case If(condOpt, thn, els) =>
      var (thnOpt', scExitOpt1) := NormalizeAst(thn, None);
      var (elsOpt', scExitOpt2) := NormalizeAst(els, None);
      var thn' := SeqCmdSimpleOpt(thnOpt', scExitOpt1);
      var els' := SeqCmdSimpleOpt(elsOpt', scExitOpt2);

      forall s' | true 
      ensures 
        WpShallow(a, If(condOpt, thn, els), post)(s') == WpShallow(a, If(condOpt, thn', els'), post)(s')
      {
          TransformAstCorrectness(a, thn, None, post, s');
          TransformAstCorrectness(a, els, None, post, s');
      }

      if precedingSimple.Some? {
        var post1 := WpPostShallow(WpShallow(a, If(condOpt, thn, els), post), post.currentScope, post.scopes);
        var post2 := WpPostShallow(WpShallow(a, If(condOpt, thn', els'), post), post.currentScope, post.scopes);
        calc {
          WpShallow(a, SimpleCmd(precedingSimple.value), post1)(s);
            { WpShallowPointwise(a, SimpleCmd(precedingSimple.value), post1, post2, s); }
          WpShallow(a, SimpleCmd(precedingSimple.value), post2)(s);
        }
      }      
    case _ => assume false;
  }

}