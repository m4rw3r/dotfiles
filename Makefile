HOME ?= ~

FILES=$(filter-out Makefile projects.vim keys.sh oh-my-zsh-plugins, $(wildcard *))

help:
	@echo "Dotfiles installer, usage:\n\tmake install\n\nWill set the following links:\n"
	@for f in $(FILES); do printf "%-30s -> %s\n" "$(HOME)/.$$f" "$(CURDIR)/$$f"; done
	@echo "\nThe following variables can configure the command:\n\tHOME: Directory where the dot-prefixed links will be placed"

install: $(FILES) vim_vundle

.PHONY: $(FILES)
$(FILES):
	@if [[ -f $(HOME)/.$@ ]] || [[ -d $(HOME)/.$@ ]];\
		then\
		n=;\
		f=$(HOME)/.$@.orig;\
		while [[ -f "$$f" ]] || [[ -d "$$f" ]];\
		do\
			n=$$(( $${n:=0} + 1 ));\
			f=$(HOME)/.$@.orig$$n;\
		done;\
		echo "Moving old $(HOME)/.$@ to $$f";\
		mv $(HOME)/.$@ $$f;\
	fi
	@ln -s $(CURDIR)/$@ $(HOME)/.$@

.PHONY: vim_vundle
vim_vundle:
	vim +BundleInstall +qall
