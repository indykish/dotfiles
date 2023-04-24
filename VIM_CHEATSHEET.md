# VIM

## Cheat sheet


# 1. Search with spaces

    :Ack foo\ bar
This approach to escaping is taken in order to make it straightfoward to use
powerful Perl-compatible regular expression syntax in an unambiguous way
without having to worry about shell escaping rules:

:Ack \blog\((['"]).*?\1\) -i --ignore-dir=src/vendor src dist build

## 1.1 Search  
CTRL-R CTRL-W   : pull word under the cursor into a command line or search
CTRL-R CTRL-A   : pull whole word including punctuation

# 2. Fix indentation in the whole file

Start in the top of a file (to get there, press gg anywhere in the file.). 

Then press `=G`



## 2.1 Indent/Unindent a line or multiple lines

>> ⁠– indents a line
<< ⁠– unindents a line
=% - (re)indent the current braces { ... }

# 3. How to retrace your movements (backwards)
Often, when you edit a file with code, you open another one in the same window. Then it's not so easy to come back to the one you just worked on. 

You can use `CTRL+o` for this.

# 4. How to retrace your movements (forward)

You can use `CTRL+L` for this.
