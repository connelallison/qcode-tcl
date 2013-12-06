package provide qcode 2.6.1
namespace eval qc {
    namespace export pkcs_padding_append pkcs_padding_strip encrypt_bf_tcl encrypt_bf_db encrypt_bf decrypt_bf_tcl decrypt_bf_db decrypt_bf
}
package require base64 
package require blowfish

proc qc::pkcs_padding_append {string} {
    #| Pads out the string to be multiple of 8 bytes in length.
    #| Padding character as per PKCS (RFC 2898).
    set padding_length [expr {8 - ([string length $string]%8)}]
    set padding_char [format %c $padding_length]
    set padding [string repeat $padding_char $padding_length]

    return "${string}${padding}"
}
doc qc::pkcs_padding_append {
    Examples {
	% set pkcs_padding_append "Hello World"
	Hello World\5\5\5\5\5
    }
}

proc qc::pkcs_padding_strip {string} {
    #| Trim PKCS padding from end of string.
    set padding_char [string index $string end] 
    set padding_length [scan $padding_char %c]
    set padding [string repeat $padding_char $padding_length]

    if { [string range $string end-[expr {$padding_length-1}] end] eq $padding } {
        return [string replace $string end-[expr {$padding_length-1}] end]
    } else {
        return $string
    }
}
doc qc::pkcs_padding_strip {
    Examples {
	% set pkcs_padding_append "Hello World\5\5\5\5\5"
	Hello World
    }
}

proc qc::encrypt_bf_tcl {key plaintext} {
    #| Encrypt plaintext using TCLLib blowfish package. Return base64 encoded ciphertext.
    #| Ciphertext can be decrypted by qc::decrypt_bf_tcl and qc::decrypt_bf_db.
    if { $plaintext eq "" } {
        return $plaintext 
    } else {
        set padded_plaintext [qc::pkcs_padding_append [encoding convertto utf-8 $plaintext]]
        return [base64::encode [blowfish::blowfish -mode cbc -dir encrypt -iv [string repeat \0 8] -key $key $padded_plaintext]]
    }
}
doc qc::encrypt_bf_tcl {
    Examples {
        % encrypt_bf_tcl secretkey "Hello World"
        wYYxpOLlcLa7VDcRSERH9g==
    }
}

proc qc::encrypt_bf_db {key plaintext} {
    #| Encrypt plaintext using Postgresql's pg_crypto blowfish functions. Return base64 encoded ciphertext.
    #| Ciphertext can be decrypted by qc::decrypt_bf_db and qc::decrypt_bf_tcl.
    set key_base64 [base64::encode $key]
    set plaintext_base64 [base64::encode [encoding convertto utf-8 $plaintext]]

    # Try clause to prevent disclosure of encryption key by error Handler
    qc::try {
        db_1row {
            select 
            encode(
                   encrypt_iv(
                              decode(:plaintext_base64,'base64'),
                              decode(:key_base64,'base64'),
                              repeat(E'\\000',8)::bytea,
                              'bf-cbc/pad:pkcs'
                              )
                   ,'base64'
                   ) as ciphertext
        }
    } {
        error "Unable to encrypt string"
    }
    return $ciphertext
}
doc qc::encrypt_bf_db {
    Examples {
        % encrypt_bf_db secretkey "Hello World"
        wYYxpOLlcLa7VDcRSERH9g==
    }
}

proc qc::encrypt_bf {key plaintext} {
    return [encrypt_db_tcl $key $plaintext]
}
doc qc::encrypt_bf {
    Examples {
        % encrypt_bf secretkey "Hello World"
        wYYxpOLlcLa7VDcRSERH9g==
    }
}

proc qc::decrypt_bf_tcl {key ciphertext} {
    #| Decrypt base64 encoded ciphertext using TCLLib blowfish package. Return plaintext.   
    #| This proc can decrypt ciphertext generated by qc::decrypt_bf_tcl and qc::decrypt_bf_db.
    if { $ciphertext eq "" } {
        return $ciphertext 
    } else {
        set padded_plaintext [blowfish::blowfish -mode cbc -dir decrypt -iv [string repeat \0 8] -key $key [::base64::decode $ciphertext]]
        return [encoding convertfrom utf-8 [qc::pkcs_padding_strip $padded_plaintext]]
    }
}
doc qc::decrypt_bf_tcl {
    Examples {
        % decrypt_bf_tcl secretkey wYYxpOLlcLa7VDcRSERH9g==
        Hello World
    }
}

proc qc::decrypt_bf_db {key ciphertext} {
    #| Decrypt base64 encoded ciphertext using Postgresql's pg_crypto blowfish functions. Return plaintext.   
    #| This proc can decrypt ciphertext generated by qc::decrypt_bf_db and qc::decrypt_bf_tcl.
    set key_base64 [base64::encode $key]

    # Try clause to prevent disclosure of encryption key by error Handler
    qc::try {
        db_1row {
            select 
            encode(
                   decrypt_iv(
                              decode(:ciphertext::text,'base64'),
                              decode(:key_base64::text,'base64'),
                              repeat(E'\\000',8)::bytea,
                              'bf-cbc/pad:pkcs'
                              )
                   ,'base64'
                   ) as plaintext_base64
        }
    } {
        error "Unable to decrypt \"$ciphertext\""
    }
    return [encoding convertfrom utf-8 [::base64::decode $plaintext_base64]]
}
doc qc::decrypt_bf_db {
    Examples {
        % decrypt_bf_db secretkey wYYxpOLlcLa7VDcRSERH9g==
        Hello World
    }
}


proc qc::decrypt_bf {key ciphertext} {
    return [decrypt_db_tcl $key $ciphertext]
}
doc qc::decrypt_bf {
    Examples {
        % decrypt_bf secretkey wYYxpOLlcLa7VDcRSERH9g==
        Hello World
    }
}
