(require 'package)
(add-to-list 'package-archives '("melpa" . "https://melpa.org/packages/") t)
(package-initialize)

; Evil setup
(require 'evil)
(evil-mode 1)

