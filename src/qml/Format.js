.pragma library

// Display helpers for the long opaque strings this wallet deals in — base58
// account ids, public keys, transaction hashes.
//
// Why truncate in JS rather than let Text elide: an elided Text cannot be
// selected or made copyable, because eliding is a paint-time effect on text the
// item still holds in full, whereas selection needs a TextEdit — and TextEdit has
// no elide. Shortening the *string* sidesteps that: the item holds exactly what
// it shows, so it can be a LogosSelectableText / LogosCopyableText, with the full
// value carried separately in `copyText` for the clipboard.
//
// The trade is that the user can only select the shortened form. That is the
// right way round for these values: nobody transcribes an address by hand, they
// copy it, and the copy is always complete.

// Middle-truncate: keep `head` leading and `tail` trailing characters.
//
//     shortenMiddle("8550a250fdce13fea6e560a758935fa296e8a5391bc058a9b635fccbce84229f")
//     → "8550a2…229f"
//
// Returns the value untouched when it is already short enough that truncating
// would not save anything.
function shortenMiddle(value, head, tail) {
    var s = value || ""
    var h = (head === undefined) ? 6 : head
    var t = (tail === undefined) ? 4 : tail
    if (s.length <= h + t + 1)
        return s
    return s.slice(0, h) + "…" + s.slice(-t)
}

// Leading-only form, for the short mnemonic names shown beside an account
// ("Account 8550"). Distinct from shortenMiddle because these read as names
// rather than as values to be checked against something.
function shortenHead(value, head) {
    var s = value || ""
    var h = (head === undefined) ? 4 : head
    return s.length <= h ? s : s.slice(0, h)
}
