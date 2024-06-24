(require 'package)
(add-to-list 'package-archives '("melpa" . "https://melpa.org/packages/") t)
(package-initialize)

; Evil setup
(require 'evil)
(evil-mode 1)

(unless (display-graphic-p)
  (require 'evil-terminal-cursor-changer)
  (evil-terminal-cursor-changer-activate)

  (setq evil-motion-state-cursor 'box)  ; █
  (setq evil-visual-state-cursor 'box)  ; █
  (setq evil-normal-state-cursor 'box)  ; █
  (setq evil-insert-state-cursor 'bar)  ; ⎸
  (setq evil-emacs-state-cursor  'hbar) ; _
  )
