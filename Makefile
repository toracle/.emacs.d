EMACS=emacs
ifneq ("$(wildcard pip)","")
PIP_BIN=pip
else
PIP_BIN=pip3
endif

ifeq ($(OS),Windows_NT)
HOME_DIR=$(HOME)
RM_TREE=rmdir /S /Q
else
HOME_DIR=~
RM_TREE=rm -rf
endif

all: external compile

compile:
	emacs -batch -f batch-byte-compile *.el

clean:
	$(RM_TREE) $(HOME_DIR)/.emacs.d

clean_packages:
	$(RM_TREE) $(HOME_DIR)/.emacs.d/elpa

py_lint:
	$(PIP_BIN) install pylint

py_flakes:
	$(PIP_BIN) install pyflakes

py_jedi:
	$(PIP_BIN) install jedi

py_epc:
	$(PIP_BIN) install epc argparse

py_virtualenvwrapper:
	$(PIP_BIN) install virtualenvwrapper

python_external: py_lint py_flakes py_epc py_jedi py_virtualenvwrapper

external: python_external
