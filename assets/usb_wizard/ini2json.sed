# whitespace trim
s/\s\+=/=/
s/^\s+//
s/=\(\s\+\)\?/=/
s/\r//g

# remove comments
s/^;.*//
s/^[ \t]*$//

# escaping quotes
s/"/\\"/g

# handle escaped equal sign
s/\\=/ESCAPED_EQUAL_SIGN/g

# split by the equal sign
s/\(.*\?\)=false/"\1": false,/I
s/\(.*\?\)=true/"\1": true,/I
s/\(.*\?\)=\(.\+\)/"\1": "\2",/

# restore escaped equal sign
s/ESCAPED_EQUAL_SIGN/=/g

# indent
s/^/    /

# First line and last line
$ s/$/\n}/
1 s/^/{\n/