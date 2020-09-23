require ["variables", "envelope", "fileinto", "subaddress", "mailbox"];

if envelope :matches :detail "to" "*" {
  set :lower "name" "${1}";

  if not string :is "${name}" "" {
    fileinto :create "subs";
  }
}
