# Kishore's Development Setup

This is an opinionated repository containing configuration files like `.bashrc`, `.vimrc`, and other dotfiles used for personal development setup.

> 🧠 Tailored for [Kishorekumar Neelamegam](https://www.linkedin.com/in/kishorekumarneelamegam/?originalSubdomain=in)  
> 🛠️ We've documented the setup to easily restore the workstation in case of crashes or fresh installs.

---

## 📚 Table of Contents

- [Operating Systems](#operating-systems)
- [Logitech Keyboard Cheat Sheets](#logitech-keyboard-cheat-sheets)
  - [Pebble Keys 2 K380s](#logitech-pebble-keys-2-k380s)
  - [Logitech K380](#logitech-k380)
- [ArchLinux Setup Notes](#archlinux-setup-notes)
  - [Fixing Git Permission Errors](#fixing-git-permission-errors)
  - [Essential Tools](#essential-tools)
- [Vim Setup](#vim-setup)
  - [Vim Plugins](#vim-plugins)
  - [Clipboard Support](#clipboard-support)
  - [Mapping Verification](#mapping-verification)
- [Using Ansible](#using-ansible)
- [Product Management](#product-management)
  - [Writing Good User Stories](#writing-good-user-stories)
  - [Acceptance Criteria](#acceptance-criteria)

---

## 👥 Operating Systems

My primary operating systems:

- [ArchLinux](https://archlinux.org/)
- [FreeBSD](https://www.freebsd.org/)

**Current Setup:** ArchLinux + XFCE

> ⚡ ArchLinux is fast and developer-friendly

---

## ⌨️ Logitech Keyboard Cheat Sheets

### Logitech Pebble Keys 2 K380s

Similar to the K380 but needed remapping for:

- `PrntScrn`
- `Home`
- `End`
- `Page Up`
- `Page Down`

> 🧹 Logitech, take notes from the Rapoo folks!

![Pebble K380s](https://github.com/indykish/dotfiles/assets/1402479/0c127ed6-6cf6-4465-bc68-14070958cbfe)

---

### Logitech K380

Shortcut key references:

- `PrntScrn`
- `Home`
- `End`
- `Page Up`
- `Page Down`

![K380](https://user-images.githubusercontent.com/1402479/161395539-2b1ec230-97d1-4994-a394-af56070d3d2b.png)

---

## 🐧 ArchLinux Setup Notes

Steps and tweaks needed post-install to get the workstation dev-ready.

### 🔧 Fixing Git Permission Errors

![git-permissions](https://github.com/indykish/dotfiles/assets/1402479/bcef5bc1-f56c-4716-a577-81830f442cf0)

---

### 🧰 Essential Tools

Install using `trizen`:

```bash
trizen starship
trizen libreoffice
trizen flameshot
trizen mise
trizen docker
```

---

## 📝 Vim Setup

> ⚙️ Recommended setup, now preferred over source builds (which sometimes feel sluggish).

Install via:

```bash
trizen vim
```

---

### 🔌 Vim Plugins

- 📦 Plugin Manager: [Vundle](https://github.com/VundleVim/Vundle.vim)
- 🎨 Devicons Fonts:

```bash
trizen ttf-nerd-fonts-symbols
```

- 🔍 Ripgrep for searching:

```bash
trizen ripgrep
```

---

### 📋 Clipboard Support (Wayland)

```bash
trizen wl-clipboard
vim --version | grep clipboard
```

Look for `+clipboard` or `+xterm_clipboard`. If not available, install:

```bash
trizen gvim vim
```

---

### ⌨️ Mapping Verification

To verify key mappings like Ctrl+V:

```bash
:verbose map <C-V>
```

![vim-ctrl-v](https://github.com/kishoreneelamegam/dotfiles/assets/1402479/8630d6c4-1108-482d-a49d-0c489b2088d2)

---

## 🩹 Using Ansible

Automate workstation setup using Ansible during OS installation.

> 🧼 Runs locally without daemons or agents.

### ▶️ Run Setup Script

```bash
sh run.sh
```

---

## 📋 Product Management

### ✍️ Writing Good User Stories

```
As a (type of user), I want to (perform some action) so that I (can achieve some goal/result/value).
```

---

### ✅ Acceptance Criteria

📖 [More on writing clear criteria](https://rubygarage.org/blog/clear-acceptance-criteria-and-why-its-important)

```gherkin
Scenario #1: User submits feedback form with valid data

* Given I’m a logged-in or guest user
  When I open the Feedback page
  Then the system shows me the Submit Feedback form with “Email”, “Name”, and “Comment” fields (required)
  When I fill in the “Email” field with a valid email address
  And I fill in the “Name” field with my name
  And I fill in the “Comment” field with my comment
  And I click the “Submit Feedback” button
  Then the system submits my feedback
  And the system shows the “You’ve successfully submitted your feedback” message
  And the form fields are cleared
```

---
