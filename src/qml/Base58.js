.pragma library

const ALPHABET = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"

// Encode a hex string to base58.
function encode(hexStr) {
    if (!hexStr || hexStr.length === 0) return ""
    const clean = hexStr.toLowerCase().replace(/^0x/, "")
    if (clean.length === 0 || clean.length % 2 !== 0) return hexStr

    const bytes = []
    for (let i = 0; i < clean.length; i += 2)
        bytes.push(parseInt(clean.substr(i, 2), 16))

    let leadingZeros = 0
    while (leadingZeros < bytes.length && bytes[leadingZeros] === 0)
        leadingZeros++

    // digits[i] holds base-58 digits, least-significant first.
    // For each input byte, multiply existing digits by 256 and add the byte.
    const digits = []
    for (let i = 0; i < bytes.length; i++) {
        let carry = bytes[i]
        for (let j = 0; j < digits.length; j++) {
            carry += digits[j] * 256
            digits[j] = carry % 58
            carry = Math.floor(carry / 58)
        }
        while (carry > 0) {
            digits.push(carry % 58)
            carry = Math.floor(carry / 58)
        }
    }

    let result = "1".repeat(leadingZeros)
    for (let i = digits.length - 1; i >= 0; i--)
        result += ALPHABET[digits[i]]
    return result
}

// Decode a base58 string to hex.
function decode(b58Str) {
    if (!b58Str || b58Str.length === 0) return ""

    let leadingZeros = 0
    while (leadingZeros < b58Str.length && b58Str[leadingZeros] === "1")
        leadingZeros++

    // digits[i] holds base-256 (byte) digits, least-significant first.
    // For each input char, multiply existing digits by 58 and add the char value.
    const digits = []
    for (let i = 0; i < b58Str.length; i++) {
        const idx = ALPHABET.indexOf(b58Str[i])
        if (idx < 0) return ""
        let carry = idx
        for (let j = 0; j < digits.length; j++) {
            carry += digits[j] * 58
            digits[j] = carry % 256
            carry = Math.floor(carry / 256)
        }
        while (carry > 0) {
            digits.push(carry % 256)
            carry = Math.floor(carry / 256)
        }
    }

    let hex = "00".repeat(leadingZeros)
    for (let i = digits.length - 1; i >= 0; i--)
        hex += (digits[i] < 16 ? "0" : "") + digits[i].toString(16)
    return hex
}
