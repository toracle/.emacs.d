CASK=~/.cask/bin/cask
EMACS=emacs
PIP=sudo pip

all:

init: ~/.cask
	curl -fsSkL https://raw.github.com/cask/cask/master/go | python

cask: Cask
	$(CASK) install

clean:
	rm -rf ~/.cask
	rm -rf ~/.emacs.d

compile:
	emacs -batch -f batch-byte-compile *.el

py_rope:
	$(PIP) install rope ropemode ropemacs

py_lint:
	$(PIP) install pylint

py_flakes:
	$(PIP) install pyflakes

pymacs:
	rm -rf Pymacs
	git clone https://github.com/pinard/Pymacs.git
	cd Pymacs
	make -C Pymacs all
	sudo make -C Pymacs install
	rm -rf Pymacs

py_jedi:
	$(PIP) install jedi

py_epc:
	$(PIP) install epc argparse

external: py_rope py_lint py_flakes pymacs py_jedi py_epc
