#
# ~/.bash_profile
#

[[ -f ~/.bashrc ]] && . ~/.bashrc
. "$HOME/.cargo/env"

# opam configuration
test -r /home/kishore/.opam/opam-init/init.sh && . /home/kishore/.opam/opam-init/init.sh > /dev/null 2> /dev/null || true
