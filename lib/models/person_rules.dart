/// What a name and an email address must look like before they are sent
/// (v1.12.44, QA Z-10 and D-02). The server checks the same, and more: it asks
/// whether an address's domain takes mail at all (backend v1.12.34).
library;

/// A name: letters in any script (ñ and accents too), with spaces, periods,
/// apostrophes and hyphens between them — "Ma. Luisa", "O'Neil",
/// "Anne-Marie", "Juan Dela Cruz Jr." No digits, no emoji.
final RegExp _name = RegExp(
  r"^[\p{L}\p{M}]+(?:[ .'’-]+[\p{L}\p{M}]+)*\.?$",
  unicode: true,
);

/// Whether [name] (already trimmed) is a name RepLiT accepts.
bool looksLikeName(String name) => name.length <= 200 && _name.hasMatch(name);

/// A whole address: something, @, a domain with a dot and a 2+ letter ending,
/// no spaces.
final RegExp _email = RegExp(
  r"^[^\s@]+@[^\s@.]+(?:\.[^\s@.]+)*\.[A-Za-z]{2,}$",
);

/// Whether [email] (already trimmed) looks like a whole email address.
bool looksLikeEmail(String email) => _email.hasMatch(email);
