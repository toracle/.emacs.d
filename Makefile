EMACS=emacs
ifneq ("$(wildcard pip)","")
PIP_BIN=pip
else
PIP_BIN=pip3
endif

NPM_BIN=npm
NPM_OPTS=-g

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

py_mypy:
	$(PIP_BIN) install mypy

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

python_external: py_mypy py_flakes py_epc py_jedi py_virtualenvwrapper

js_eslint:
	$(NPM_BIN) install $(NPM_OPTS) eslint

js_tern:
	$(NPM_BIN) install $(NPM_OPTS) tern

js_external: js_eslint js_tern

rust_racer:
	cargo install racer
	echo "Add ~/.cargo/bin/racer to PATH env variable"

rust_src:
	mkdir -p ~/src
	git clone git@github.com:rust-lang/rust.git ~/src/rust

rust_external: rust_racer rust_src

external: python_external js_external rust_external
