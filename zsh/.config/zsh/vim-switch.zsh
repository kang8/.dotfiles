alias nvim-lazy="NVIM_APPNAME=LazyVim nvim"    # git clone --depth 1 git@github.com:LazyVim/LazyVim.git ~/.config/LazyVim
alias nvim-kick="NVIM_APPNAME=kickstart nvim"  # git clone --depth 1 git@github.com:nvim-lua/kickstart.nvim.git ~/.config/kickstart
alias nvim-chad="NVIM_APPNAME=NvChad nvim"     # git clone --depth 1 git@github.com:NvChad/NvChad.git ~/.config/NvChad
alias nvim-astro="NVIM_APPNAME=AstroNvim nvim" # git clone --depth 1 git@github.com:AstroNvim/AstroNvim.git ~/.config/AstroNvim

function nvims() {
  items=("default" "kickstart" "LazyVim" "NvChad" "AstroNvim")
  config=$(printf "%s\n" "${items[@]}" | fzf --prompt=" Neovim Config  " --height=~50% --layout=reverse --border --exit-0)
  if [[ -z $config ]]; then
    echo "Nothing selected"
    return 0
  elif [[ $config == "default" ]]; then
    config=""
  fi
  NVIM_APPNAME=$config nvim $@
}
