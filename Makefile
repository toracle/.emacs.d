EMACS=emacs

ifeq ($(OS),Windows_NT)
CASK_BIN=~/.cask/bin/cask
PIP_BIN=pip
else
CASK_BIN=$(HOME_DIR)/.cask/bin/cask
PIP_BIN=sudo pip
endif

all:

init: ~/.cask
	curl -fsSkL https://raw.github.com/cask/cask/master/go | python

cask: Cask
	$(CASK_BIN) install

clean:
	rm -rf ~/.cask
	rm -rf ~/.emacs.d

compile:
	emacs -batch -f batch-byte-compile *.el

py_rope:
	$(PIP_BIN) install rope ropemode ropemacs

py_lint:
	$(PIP_BIN) install pylint

py_flakes:
	$(PIP_BIN) install pyflakes

pymacs:
	rm -rf Pymacs
	git clone https://github.com/pinard/Pymacs.git
	cd Pymacs
	make -C Pymacs all
	sudo make -C Pymacs install
	rm -rf Pymacs

py_jedi:
	$(PIP_BIN) install jedi

py_epc:
	$(PIP_BIN) install epc argparse

external: py_rope py_lint py_flakes pymacs py_jedi py_epc
