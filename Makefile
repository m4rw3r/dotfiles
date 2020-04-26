HOME    ?= ~
REPLACE ?=

FILES     = $(filter-out Makefile mac_resources patches projects.vim tmux.sh keys.sh oh-my-zsh-plugins, $(wildcard *))
GIT_REPOS = $(addsuffix /.git, oh-my-zsh $(wildcard oh-my-zsh-plugins/plugins/*) tmux-resurrect)
PATCHES   = $(wildcard patches/**.patch)

help:
	@echo -e "Dotfiles installer, usage:\n\tmake install\n\nWill set the following links:\n"
	@for f in $(FILES); do printf "%-40s -> %s\n" "$(HOME)/.$$f" "$(CURDIR)/$$f"; done
	@echo -e "\nThe following variables can configure the command:"
	@echo -e "\tHOME:    Directory where the dot-prefixed links will be placed"
	@echo -e "\tREPLACE: Set to truthy value to replace the files instead of moving"
	@echo -e "\nOther commands:"
	@echo -e "\tmake update\tWill update all git repositories and re-apply patches"
	@echo -e "\tmake patch\tWill apply patches"
	@echo -e "\tmake reset\tWill reset patched git repositories to upstream"

install: $(FILES) patches vim_vundle

.PHONY: $(FILES)
$(FILES):
	@if [[ -z "$(REPLACE)" ]] && ([[ -e $(HOME)/.$@ ]] || [[ -L $(HOME)/.$@ ]]) && ! [ $(HOME)/.$@ -ef $(CURDIR)/$@ ];\
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
	@if ! [ $(HOME)/.$@ -ef $(CURDIR)/$@ ]; then ln -sf $(CURDIR)/$@ $(HOME)/.$@; fi

.PHONY: vim_vundle
vim_vundle:
	vim +BundleInstall +qall

.PHONY: reset
reset:
	for r in $(GIT_REPOS); do \
		(cd $$r/..; git reset --hard @{u});\
	done

.PHONY: update
update: git-pull patches

.PHONY: git-pull
git-pull: $(GIT_REPOS)

.PHONY: $(GIT_REPOS)
$(GIT_REPOS):
	@echo Updating $(patsubst %/.git,%,$@)
	@(cd $(patsubst %/.git,%,$@); git checkout master && git reset --hard @{u} && git pull --rebase)
	@echo Updated $(patsubst %/.git,%,$@)

.PHONY: patches
patches: $(PATCHES)

.PHONY: $(PATCHES)
$(PATCHES):
	@echo Patching $(patsubst patches/%.patch,%,$@)
	@(cd $(patsubst patches/%.patch,%,$@); git reset --hard @{u}; git apply $(CURDIR)/$@)
	@echo Patched $(patsubst patches/%.patch,%,$@)
