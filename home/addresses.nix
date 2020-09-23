# A little bit of obscurity to slow down email harvesters.
{ ... }:
let
  mkAddr = local: domain: "${local}@${domain}";
in
{
  primary = mkAddr "pjones" "devalot.com";

  secondary = [
    (mkAddr "pjones" "pmade.com")
    (mkAddr "mlists" "pmade.com")
    (mkAddr "mlists" "devalot.com")
    (mkAddr "pmadeinc" "gmail.com")
  ];
}
