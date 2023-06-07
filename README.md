# My development setup

This repo contains my bash, vim and other (.) files. 

> This is an opioniated repo for [Kishorekumar Neelamegam](https://www.linkedin.com/in/kishorekumarneelamegam/?originalSubdomain=in). I am recording my setup just so i dont forget how to bring back my workstation when there is a crash


# OS

Either

[FreeBSD](https://www.freebsd.org/) 

(or)

[ArchLinux](https://archlinux.org/)

At the moment I am on [ArchLinux](https://archlinux.org/) + Gnome, 

I find Archlinux much faster but eventually move to FreeBSD or OpenBSD for OCaml dev.

# K380 cheat sheet

The cheat sheet for the K380, need this to refer 

- PrntScrn
- Home
- End
- Page up
- PAge down

![image](https://user-images.githubusercontent.com/1402479/161395539-2b1ec230-97d1-4994-a394-af56070d3d2b.png)

# Product Management

## Writing a good story

As a (type of user), I want to (perform some action) so that I (can achieve some goal/result/value).”

## [Writing a good acceptance criteria](https://rubygarage.org/blog/clear-acceptance-criteria-and-why-its-important)

```
Scenario #1: User submits feedback form with the valid data
*Given I’m in a role of logged-in or guest user
When I open the Feedback page
Then the system shows me the Submit Feedback form containing “Email”,“Name” and “Comment” fields which are required
When I fill in the “Email” field with a valid email address
And I fill in the “Name” field with my name
And I fill in the “Comment” field with my comment
And I click the “Submit Feedback” button
Then the system submits my feedback
And the system shows the “You’ve successfully submitted your feedback” flash message
And the system clears the fields of the Submit Feedback form*
```


# Upon install

What tweaks are needed to bring my workstation.

1. Trizen
2. VIM & Vundle
3. Yarn
4. Node
3. Rust
4. OCaml
5. Slack
6. Flameshot
7. Libreoffice

## Trizen

```
pacman trizen
```

### Install from trizen package (recommended)

This is recommended and have moved to this approach

Why, the install from release source is great, but have experienced slowness (un sure why) on the latest builds

```

trizen vim

```

### Install from source

- Download release tar ball https://github.com/vim/vim/

```
mv ~/Downloads/vim*.tar.gz ~/bin; tar -xvf vim*.tar.gz
make
sudo make install
```
### VIM plugins

ℹ️ Install Vundle(plugin manager)

https://github.com/VundleVim/Vundle.vim

ℹ️ Powerline fonts

```
trizen nerd-fonts-source-code-pro
```

ℹ️ Search using ripgrep

```
trizen ripgrep
```

ℹ️ Clipboard

trizen xsel

```
vim --version | grep clipboard
```

If you see `+clipboard` or `+xterm_clipboard`, you are good to go. 

If it's `-clipboard` and `-xterm_clipboard`, 
you will need to install

```
trizen gvim vim
```

### Node

> Note, as of this writing 18.16.0 was  the latest, but replace the wget `https` **url** with the latest by visiting [Node.js](https://nodejs.org) to grab the latest LTS

```
cd ~/bin; wget https://nodejs.org/dist/v18.16.0/node-v18.16.0-linux-x64.tar

tar -xvf node*.tar.xz; mv ~/bin/node* ~/bin/node

```

### Rust

```
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

trizen postgresql-libs

```

### OCaml

trizen ocaml

### Slack/Flameshot/Libreoffice

These packages are installed by searching in trizen.


# WIP

Need to write a perl (or) bash script to all of the above gets done by clone this repo. 
