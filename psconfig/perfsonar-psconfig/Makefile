#
# Makefile for python-pscheduler module
#

default: build

build:
	python3 setup.py build

install:
ifndef PERFSONAR-ROOTPATH
	@echo No PERFSONAR-ROOTPATH specified for installation
	@false
endif
ifndef PERFSONAR-CONFIGPATH
	@echo No PERFSONAR-CONFIGPATH specified for installation
	@false
endif
ifndef PYTHON-ROOTPATH
	@echo No PYTHON-ROOTPATH specified for installation
	@false
endif
ifndef PERFSONAR-DATAPATH
	@echo No PERFSONAR-DATAPATH specified for installation
	@false
endif
	python3 setup.py install --root=${PYTHON-ROOTPATH} -O1 --record=INSTALLED_FILES
	mkdir -p ${PERFSONAR-ROOTPATH}/bin 
	mkdir -p ${PERFSONAR-CONFIGPATH} 
	mkdir -p ${PERFSONAR-DATAPATH} 
	install -m 0755 bin/* ${PERFSONAR-ROOTPATH}/bin
	install -m 0644 etc/*.json ${PERFSONAR-CONFIGPATH}/
	install -m 0644 etc/*.conf ${PERFSONAR-CONFIGPATH}/

clean:
	make -C tests $@
	find . -name "*.pyc" | xargs rm -f
	python3 setup.py clean --all
