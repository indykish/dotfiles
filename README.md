# dotfiles
My bash, vim and other (.) files.

# OS

Either
[FreeBSD](https://www.freebsd.org/) (or)
[ArcoLinux](https://arcolinux.com/)

At the moment 

[ArcoLinux](https://arcolinux.com/) + Gnome, 

I find Arcolinux much faster than Manjaro or base ArchLinux.

# Upon install

Usually by trying to fix something in my laptop i fat finger since Arch provides great flexibility in downgrading or upgrading levels of software


## Vim 


- Download release tar ball https://github.com/vim/vim/

```
mv ~/Downloads/vim*.tar.gz ~/bin; tar -xvf vim*.tar.gz
make
sudo make install
```
### Vim plugins

https://github.com/VundleVim/Vundle.vim

pacman trizen

trizen nerd-fonts-source-code-pro

trizen xsel

trizel ripgrep

## Dev

### node
cd ~/bin; wget https://nodejs.org/dist/v12.16.1/node-v12.16.1-linux-x64.tar.xz

tar -xvf node*.tar.xz; mv ~/bin/node* ~/bin/node

### yarn
cd ~/bin; wget https://yarnpkg.com/latest.tar.gz
tar zvxf latest.tar.gz
mv ~/bin/yarn*  ~/bin/yarn

### rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
trizen postgresql-libs

### ocaml

trizen ocaml

# WIP
Need to write a bash script to all of the above gets done by clone this repo. 
