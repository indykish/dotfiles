# Kishore's development setup

This is an opinionated repo that contains our bash, vim and other (.) files. 

> This is an opioniated repo for [Kishorekumar Neelamegam](https://www.linkedin.com/in/kishorekumarneelamegam/?originalSubdomain=in).
> We have recorded our setup just so we dont forget how to bring back the workstation when there is a crash


# OS

My primary OS is either

[ArchLinux](https://archlinux.org/)
(or)
[FreeBSD](https://www.freebsd.org/) Please refer the section below for the status of the migration.
(or)
Chromebook eventually - with everything on cloud 😄

At the moment on [ArchLinux](https://archlinux.org/) + Gnome. 

Archlinux is much faster but eventually will move to FreeBSD or OpenBSD for OCaml dev.

# Logitech K380 cheat sheet

The K380 cheat sheet is available for referencing the shortcut keys mentioned below.

- PrntScrn
- Home
- End
- Page up
- Page down

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


# ArchLinux

Upon install, what tweaks are needed to bring my workstation up to the state for dev.

1.  Trizen
2.  VIM & Vundle
3.  Node
4.  Rust
5.  OCaml
6.  Flameshot
7.  Libreoffice
8.  Brave
9.  VLC
10. Docker
11. Nautilus extensions

## 1 Trizen


```

pacman trizen

```

## 2 Vim

This is recommended and have moved to this approach.

The install from release source is great, but have experienced slowness (un sure why) on the latest builds

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


## 3 Node

> Note, as of this writing 20.x was  the latest, but replace the wget `https` **url** with the latest by visiting [Node.js](https://nodejs.org) to grab the latest LTS

```
cd ~/bin; wget https://nodejs.org/dist/v18.16.0/node-v18.16.0-linux-x64.tar

tar -xvf node*.tar.xz; mv ~/bin/node* ~/bin/node

```

## 4 Rust

```
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

trizen postgresql-libs

```

## 5 OCaml

```

trizen ocaml

```

## 6 Flameshot

```

trizen flameshot

```

The app indicator extension is gnome is needed. 

```

trizen gnome-shell-extension-appindicator

```

## 7 Libreoffice

```

trizen libreoffice

```

## 8 Brave

```

trizen brave

```
## 9 VLC

```

trizen vlc

```

## WIP: 10 Docker

```


```

## 11 Nautilus extensions

```

trizen nautilus-open-any-terminal

```

## 12 [1Password](https://support.1password.com/install-linux/#arch-linux)

```
curl -sS https://downloads.1password.com/linux/keys/1password.asc | gpg --import

trizen 1password

```

# 🩹 Work in progress - Using Ansible, Chef, or SaltStack 

Compose Ansible, Chef, or SaltStack code to configure the workstation during the OS installation. 

The objective is to have the script operate solely locally without running any daemons or agents.

⚓ Perhaps leverage ChatGPT to generate the script.

# FreeBSD Migration

The current status of my FreeBSD migration is as follows:

I haven't had much luck with a full switch yet. I am not inclined to work using an emulation layer.

I prefer native solutions or workarounds. However, the list below is still a work in progress:

Workarounds for Teams and Zoom can function as additional workstations, running either Windows or Linux or connecting via mobile.

- [x] Slack (Completed)
- [ ] Zoom (Incomplete)
- [ ] Teams (Incomplete)
- [x] Vim (Completed)
- [ ] OCaml (Incomplete)
- [ ] Rust (Incomplete)
- [ ] Perl (Incomplete)
- [ ] Typescript (Incomplete)
- [ ] Dry run ui (Incomplete)
- [ ] Dry run coreapi/auth (Incomplete)
- [ ] Dry run python, perl scripts (Incomplete)
