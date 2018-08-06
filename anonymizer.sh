#!/bin/sh
#
#  anonymizer.sh
#  Checker
#
#  Created by Ellie Shin on 7/16/18.
#  Copyright © 2018 Ellie Shin. All rights reserved.

awk '
BEGIN {
    
    # Mapping of keywords and temporary tokens
    keywords["if"] = "¢01"
    keywords["else"] = "¢02"
    keywords["return"] = "¢03"
    keywords["guard"] = "¢04"
    keywords["in"] = "¢05"
    keywords["while"] = "¢06"
    keywords["for"] = "¢07"
    keywords["break"] = "¢08"
    keywords["case"] = "¢09"
    keywords["continue"] = "¢10"
    keywords["self"] = "¢11"
    keywords["super"] = "¢12"
    keywords["var"] = "¢13"
    keywords["let"] = "¢14"
    keywords["init"] = "¢15"
    keywords["do"] = "¢16"
    keywords["weak"] = "¢17"
    keywords["func"] = "¢20"
    keywords["class"] = "¢21"
    keywords["protocol"] = "¢22"
    keywords["extension"] = "¢23"
    keywords["struct"] = "¢24"
    keywords["enum"] = "¢25"
    keywords["final"] = "¢31"
    keywords["override"] = "¢32"
    keywords["static"] = "¢33"
    keywords["public"] = "¢34"
    keywords["open"] = "¢35"
    keywords["private"] = "¢36"
    keywords["fileprivate"] = "¢37"
    keywords["internal"] = "¢38"
    keywords["lazy"] = "¢39"
    keywords["required"] = "¢40"
    keywords["convenience"] = "¢41"
    keywords["selector"] = "¢50"
    keywords["objc"] = "¢51"
    keywords["available"] = "¢52"
    keywords["discardableResult"] = "¢53"
    keywords["available"] = "¢54"
    keywords["escaping"] = "¢55"
    keywords["ifdef"] = "¢60"
    keywords["endif"] = "¢61"
    keywords["define"] = "¢62"
    keywords["keyPath"] = "¢63"
    keywords["function"] = "¢64"
    keywords["imageLiteral"] = "¢65"
    keywords["colorLiteral"] = "¢66"
    keywords["stringLiteral"] = "¢67"
    
    # A regexp that matches lines that start a file-level "unit", which is emitted when a new unit is found.
    unit_start_regexp = "^(func|class|struct|enum|protocol|extension)"
    
    # An accumulation buffer for the current file-level unit
    current_unit = ""
    
    in_multiline_comment = 0
    
    numeric_regexp = "^[0-9]+"
    
    # A single character that is not part of an identifier, such as
    # . { } [ ] < > ( ) ? / \ | & ! @ # $ % ^ * + = = , : ; " ` ~
    non_alphanumeric_regexp = "[^0-9a-zA-Z_]"
}

function flush_current_unit()
{
    if (current_unit)
        printf("%s", current_unit)  # this will just print current_unit instead of current_unit and a new line
    current_unit = ""
}

function append_current_unit(processedline)
{
    # Now append the current line onto the end of the unit accumulation buffer,
    # using a newline as a separator.
    current_unit = current_unit processedline "\n"
}


# If an import line is found, replace with "" and move to the next line
/^import/ {
    append_current_unit("");
    next;
}

# Remove comments that are entirely on this line
{
    # Remove // comments
    sub (/[ \t]*\/\/.*/, "")
    
    # Remove complete /* ... */ comments
    sub (/[ \t]*\/\*.*\*\/[ \t]*/, "")
}

# If we are inside a multiline comment, see if we should terminate it, else continue to the next line.
in_multiline_comment {
    if (sub (/^.*\*\//, "")) {
        in_multiline_comment = 0
    } else {
        append_current_unit("");
        next;
    }
}

# Transforms an input line to a pattern string
function transform()
{
    n_tokens = split($0, tokens, " ");
    ret = ""
    
    for (i=1; i <= n_tokens; i++) {
        token = tokens[i]
        
        # Check if there are non-alphanumeric chars in this token
        matched = match(token, non_alphanumeric_regexp);
        
        # If matched, replace identifiers (alphanumeric) in the token with "x".
        while (matched > 0) {
            # Replace the alphanumeric part with a special temporary token if keyword or "x" if not.
            if (matched > 1 && matched <= length(token)) {
                subtoken = substr(token, 1, matched-1)
                if (subtoken in keywords) {
                    ret = ret subtoken;
                } else if (subtoken ~ numeric_regexp) {
                    ret = ret subtoken;
                } else {
                    ret = ret "x";
                }
            }
            
            # Keep the non-alphanumeric char.
            ret = ret substr(token, matched, RLENGTH)
            # Reset token to the remaining substring after the previous match.
            token = substr(token, matched+RLENGTH, length(token))
            # Check if there are non-alphanumeric chars in the reset token.
            matched = match(token, non_alphanumeric_regexp);
        }
        
        # If unmatched, replace this entire token or the remaining part of the token
        # that now only consists of alphanumeric chars with "x".
        if (matched == 0 && length(token) > 0) {
            # Replace keywords with special temporary tokens
            if (token in keywords) {
                ret = ret token;
            } else if (token ~ numeric_regexp) {
                ret = ret token;
            } else {
                ret = ret "x";
            }
        }
        
        if (i < n_tokens)
        ret = ret " ";
    }
    
    $0 = ret;
}

{
    # See if there is a multi-line comment starting here, and save return value to
    # a var (1 if found, 0 if not)
    in_multiline_comment = sub (/[ \t]*\/\*.*$/, "")
    
    # Replace identifiers with "x", keywords with temporary tokens, but keep
    # non-alphanumeric chars as is.
    transform()
    
    # If this is the start of a new file-level unit, flush the current unit
    if ($0 ~ unit_start_regexp)
    flush_current_unit()
    
    append_current_unit($0)
}

END { flush_current_unit() }
' "$@"
