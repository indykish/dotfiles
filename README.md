# Kishore's development setup

This is an opinionated repo that contains out bash, vim and other (.) files. 

> This is an opioniated repo for [Kishorekumar Neelamegam](https://www.linkedin.com/in/kishorekumarneelamegam/?originalSubdomain=in).
> We have recorded our setup just so we dont forget how to bring back the workstation when there is a crash


# OS

Either

[FreeBSD](https://www.freebsd.org/) 

(or)

[ArchLinux](https://archlinux.org/)

At the moment on [ArchLinux](https://archlinux.org/) + Gnome, 

Archlinux is much faster but eventually will move to FreeBSD or OpenBSD for OCaml dev.

# Logitech K380 cheat sheet

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
5. Rust
6. OCaml
7. Flameshot
8. Libreoffice
9. Brave
10. VLC

## 1 Trizen



```
pacman trizen
```

## 2 Vim

This is recommended and have moved to this approach

Why, the install from release source is great, but have experienced slowness (un sure why) on the latest builds

```

trizen vim

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

To verify a mapping for CTRL-C and CTRL-V

```
::verbose map <C-V>

```
![image](https://github.com/kishoreneelamegam/dotfiles/assets/1402479/8630d6c4-1108-482d-a49d-0c489b2088d2)

## 3 Yarn

> Note, as of this writing 18.16.0 was  the latest, but replace the wget `https` **url** with the latest by visiting [Node.js](https://nodejs.org) to grab the latest LTS

```
cd ~/bin; wget https://nodejs.org/dist/v18.16.0/node-v18.16.0-linux-x64.tar

tar -xvf node*.tar.xz; mv ~/bin/node* ~/bin/node

```

## 4 Node

> Note, as of this writing 18.16.0 was  the latest, but replace the wget `https` **url** with the latest by visiting [Node.js](https://nodejs.org) to grab the latest LTS

```
cd ~/bin; wget https://nodejs.org/dist/v18.16.0/node-v18.16.0-linux-x64.tar

tar -xvf node*.tar.xz; mv ~/bin/node* ~/bin/node

```

## 5 Rust

```
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

trizen postgresql-libs

```

## 6 OCaml

trizen ocaml

## 7 Flameshot

```

trizen flameshot

```

The app indicator extension is gnome is needed. 

```

trizen gnome-shell-extension-appindicator

```

## 8 Libreoffice

```

trizen libreoffice

```

## 9 Brave

```

trizen brave

```
## 10 VLC

```

trizen vlc

```

# Jumpup.pl(for Kishore only)

🩹 Need to write a perl script that can setup a my stuff.
⚓ May be use ChatGPT to generate a pl script.


---

# FreeBSD Migration

The following must be tested and completed prior to the move.

The workarounds can be additional workstation (Zoom) or Mobile can help.

- [x] Slack (Completed)
- [ ] Zoom (Incomplete)
- [ ] Team (Incomplete)
- [ ] Vim (Completed)
- [ ] OCaml (Incomplete)
- [ ] Rust (Incomplete)
- [x] Perl (Completed)
- [ ] Typescript (Incomplete)
- [ ] Dry run ui (Incomplete)
- [ ] Dry run coreapi/auth (Completed)
- [ ] Dry run python, perl scripts (Incomplete)
