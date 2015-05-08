EMACS=emacs

ifeq ($(OS),Windows_NT)
HOME_DIR=$(HOME)
CASK_BIN=~/.cask/bin/cask
PIP_BIN=pip
RM_TREE=rmdir /S /Q
else
HOME_DIR=~
CASK_BIN=$(HOME_DIR)/.cask/bin/cask
PIP_BIN=sudo pip
RM_TREE=rm -rf
endif

all:

init:
	curl -fsSkL https://raw.github.com/cask/cask/master/go | python

package:
	$(CASK_BIN) install

clean:
	$(RM_TREE) $(HOME_DIR)/.cask
	$(RM_TREE) $(HOME_DIR)/.emacs.d

compile:
	emacs -batch -f batch-byte-compile *.el

py_rope:
	$(PIP_BIN) install rope ropemode ropemacs

py_lint:
	$(PIP_BIN) install pylint

py_flakes:
	$(PIP_BIN) install pyflakes

pymacs:
	$(RM_TREE) Pymacs
	git clone https://github.com/pinard/Pymacs.git
	cd Pymacs
	make -C Pymacs all
	sudo make -C Pymacs install
	$(RM_TREE) Pymacs

py_jedi:
	$(PIP_BIN) install jedi

py_epc:
	$(PIP_BIN) install epc argparse

external: py_rope py_lint py_flakes pymacs py_jedi py_epc
