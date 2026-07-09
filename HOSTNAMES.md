# Hostname sequence

Machines are named after Quenya (Elvish) numerals, in order, spelled without
diacritics since NixOS hostnames only permit ASCII letters, digits, hyphens,
and underscores.

The bootstrap script picks the first name in this list that doesn't already
have a matching `hosts/<name>/` directory. Once a name is assigned to a host,
it's permanent - don't rename an existing `hosts/<name>/` directory. Feel
free to append more names to the end of this list whenever needed.

1. mine     (minë   - one)   - in use
2. atta     (atta   - two)
3. nelde    (neldë  - three)
4. canta    (canta  - four)
5. lempe    (lempë  - five)
6. enque    (enquë  - six)
7. otso     (otso   - seven)
8. tolto    (tolto  - eight)
9. nerte    (nertë  - nine)
10. cainen  (cainen - ten)
