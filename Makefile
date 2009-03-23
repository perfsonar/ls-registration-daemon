PACKAGE=perfSONAR_PS-LSRegistrationDaemon
ROOTPATH=/opt/perfsonar_ps/ls_registration_daemon

default:
	@echo No need to build the package. Just run \"make install\"

dist:
	mkdir /tmp/$(PACKAGE)
	tar ch -T MANIFEST | tar x -C /tmp/$(PACKAGE)
	tar czf $(PACKAGE).tar.gz -C /tmp $(PACKAGE)
	rm -rf /tmp/$(PACKAGE)

install:
	mkdir -p ${ROOTPATH}
	tar ch --exclude=etc/* --exclude=*spec --exclude=MANIFEST --exclude=Makefile -T MANIFEST | tar x -C ${ROOTPATH}
	for i in `cat MANIFEST | grep ^etc`; do  mkdir -p `dirname $(ROOTPATH)/$${i}`; if [ -e $(ROOTPATH)/$${i} ]; then install -m 640 -c $${i} $(ROOTPATH)/$${i}.new; else install -m 640 -c $${i} $(ROOTPATH)/$${i}; fi; done