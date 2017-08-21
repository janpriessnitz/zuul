.PHONY: tarball build install clean

SOURCES := sources.tar
VIRTUALENV ?= /usr/bin/virtualenv
VENV_DIR := .venv
VENV_ACTIVATE := source $(VENV_DIR)/bin/activate
PWD := $(shell pwd)
WEBAPP_DIR := etc/status

# Create source archive
tarball:
	git archive --format=tar HEAD^{tree} > $(SOURCES)
	tar rvf $(SOURCES) $(WEBAPP_DIR)

# Build zuul bundle
build:
	$(VIRTUALENV) $(VENV_DIR)
	$(VENV_ACTIVATE) && pip install -U pip
	$(VENV_ACTIVATE) && pip install -r requirements.txt
	$(VENV_ACTIVATE) && ./etc/status/fetch-dependencies.sh # web assets fetch
	$(VENV_ACTIVATE) && python setup.py install
	rm -f $(VENV_DIR)/pip-selfcheck.json
	$(VIRTUALENV) --relocatable $(VENV_DIR)

# Install zuul bundle into DESTDIR
install:
	install -d -m 755 '$(DESTDIR)'
	cp -a $(VENV_DIR)/* '$(DESTDIR)'
	cp -a $(WEBAPP_DIR) '$(DESTDIR)'

clean:
	rm -rf $(SOURCES) $(PIP_DEPS_DIR) $(VENV_DIR)

test-logging:
	rm -f integration/.test/log/*
	tox -e venv -- timeout --preserve-status 10 zuul-server -c integration/config/zuul.conf -d
	grep -F 'zuul.GithubConnection' integration/.test/log/zuul.log

check: build
	$(VENV_ACTIVATE) && \
		pip install -r test-requirements.txt -r requirements.txt
	$(VENV_ACTIVATE) && \
		OS_TEST_TIMEOUT=30 python setup.py testr --slowest
