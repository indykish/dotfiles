# My development setup

This repo contains my bash, vim and other (.) files. 

> This is an opioniated repo for [Kishorekumar Neelamegam](https://www.linkedin.com/in/kishorekumarneelamegam/?originalSubdomain=in). I am recording my setup just so i dont forget how to bring back my workstation when there is a crash


# OS

Either

[FreeBSD](https://www.freebsd.org/) 

(or)

[ArchLinux](https://archlinux.org/)

At the moment I am on [ArchLinux](https://archlinux.org/) + Gnome, 

I find Archlinux much faster but eventually move to Free or OpenBSD for OCaml dev.

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


## VIM

### Cheat sheet


1. [https://vim.rtorr.com/](https://vim.rtorr.com/)


2. Search with spaces

    :Ack foo\ bar
This approach to escaping is taken in order to make it straightfoward to use
powerful Perl-compatible regular expression syntax in an unambiguous way
without having to worry about shell escaping rules:

:Ack \blog\((['"]).*?\1\) -i --ignore-dir=src/vendor src dist build



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

https://github.com/VundleVim/Vundle.vim


trizen nerd-fonts-source-code-pro

trizen xsel

trizel ripgrep


### Node

> Note, as of this writing 16.14.2 was  the latest, but replace the wget `https` **url** with the latest by visiting [Node.js](https://nodejs.org) to grab the latest LTS

```
cd ~/bin; wget https://nodejs.org/dist/v16.14.2/node-v16.14.2-linux-x64.tar.xz

tar -xvf node*.tar.xz; mv ~/bin/node* ~/bin/node

```

### Yarn 1.x

```
cd ~/bin; wget https://yarnpkg.com/latest.tar.gz

tar zvxf latest.tar.gz

mv ~/bin/yarn*  ~/bin/yarn

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

Need to write a bash script to all of the above gets done by clone this repo. 
