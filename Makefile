CASK=~/.cask/bin/cask
EMACS=emacs

init:
	curl -fsSkL https://raw.github.com/cask/cask/master/go | python
	git clone git@bitbucket.org:toracle/.emacs.d.git ~/.emacs.d

cask:
	$(CASK) install

clean:
	rm -rf ~/.cask
	rm -rf ~/.emacs.d

all: cask
