#
# Makefile for python-pscheduler module
#

default: build

test: file-setup
	python3 -m nose

build:
	python3 setup.py build

install:
ifndef INSTALL_ROOT
	python3 setup.py install
else
	python3 setup.py install --root=${INSTALL_ROOT} -O1 --record=INSTALLED_FILES
endif

clean:
	make -C tests $@
	find . -name "*.pyc" | xargs rm -f
