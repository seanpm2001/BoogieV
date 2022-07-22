include "../dafny-libraries/src/Wrappers.dfy"
include "../dafny-libraries/src/Collections/Sequences/Seq.dfy"

module Util {
  import opened Wrappers
  import Seq

  function method RemoveDuplicates<T(==)>(s: seq<T>): seq<T>
  {
    RemoveDuplicatesAux(s, {})
  }

  function method RemoveDuplicatesAux<T>(s: seq<T>, alreadyIncluded: set<T>): seq<T>
  {
    if |s| == 0 then []
    else 
      if s[0] in alreadyIncluded then 
        RemoveDuplicatesAux(s[1..], alreadyIncluded) 
      else 
        [s[0]] + RemoveDuplicatesAux(s[1..], {s[0]}+alreadyIncluded)
  }

  function method IntToString(i: int) : string {
    if i < 0 then "-"+NatToString(-i) else NatToString(i)
  }

  function method NatToString(n: nat) : string {
    if n == 0 then "0"
    else 
      var digit := n % 10;
      var digitString := ['0' + digit as char];
      var remainder := n/10;
      digitString + if remainder > 0 then NatToString(n/10) else ""
  }

  lemma HashTagNotInNatString(n: nat)
    ensures '#' !in NatToString(n)
  { }

  lemma test(n: nat, c1: char, c2: char)
  {
    var digit := n % 10;
    var c3 := '0' + (digit as char);
  }
  lemma NatToStringInjective(n1: nat, n2: nat)
    requires n1 != n2
    ensures NatToString(n1) != NatToString(n2)
  {
    assume false; //TODO adjust proof
    if n1 == 0 {
      //trivial
    } else {
      var digit1 := n1 % 10;
      var digitString1 := ['0' + digit1 as char];
      var res1 := digitString1 + NatToString(n1/10);

      var digit2 := n2 % 10;
      var digitString2 := ['0' + digit2 as char];
      var res2 := digitString2 + NatToString(n2/10);

      assert |digitString1| == |digitString2|;

      if digit1 != digit2 {
        assert ('0'+ digit1 as char) != ('0'+ digit2 as char);
        assert digitString1 != digitString2;
        assert res1[0] != res2[0];
      } else {
        assert NatToString(n1/10) != NatToString(n2/10) by {
          assert n1/10 != n2/10;
          NatToStringInjective(n1/10, n2/10);
        }
        assert res1[1..] != res2[1..];
      }
    }
  }

  function method BoolToString(b: bool) : string {
    if b then "true" else "false"
  }

  function method IndentString(s: string, n: nat) : string {
    seq(n, _ => ' ') + s
  }

  function AndOpt(b1Opt: Option<bool>, b2Opt: Option<bool>) : Option<bool> {
    if b1Opt.Some? && b2Opt.Some? then Some(b1Opt.value && b2Opt.value) else None
  }

  //the first occurrence for a key k in the sequence is relevant for the map
  function method {:opaque} SequenceToMap<K,V>(s: seq<(K,V)>) : map<K,V>
  {
    if |s| == 0 then map[]
    else SequenceToMap(s[1..])[s[0].0 := s[0].1]
  }

  lemma OptionBoolExhaust(a: Option<bool>)
    ensures a == None || a == Some(true) || a == Some(false)
  {
    match a
    case None => 
    case Some(true) =>
    case Some(false) =>
  }
}