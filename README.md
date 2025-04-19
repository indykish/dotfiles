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
- [Fixing Git Permission Errors](#fixing-git-permission-errors) 
- [Vim Setup](#vim-setup)
  - [Vim Plugins](#vim-plugins)
  - [Clipboard Support](#clipboard-support)
  - [Mapping Verification](#mapping-verification)
- [Setup your system](#using-ansible)

---

## 👥 Operating Systems

My primary operating systems: ⚡ ArchLinux is fast and developer-friendly

- [ArchLinux](https://archlinux.org/) + Gnome

---

## ⌨️ Keyboard Cheat Sheets

### Logitech Pebble Keys 2 K380s

Similar to the K380 but needed remapping for:

- `PrntScrn`

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

## 🔧 Fixing Git Permission Errors

![git-permissions](https://github.com/indykish/dotfiles/assets/1402479/bcef5bc1-f56c-4716-a577-81830f442cf0)

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

## 🩹 Setup your system

The run.sh installs ansible and the base packages to jumpstart the system.

### ▶️ Run Setup Script

```bash
sh run.sh
```

