PACKAGE=perfSONAR_PS-LSRegistrationDaemon
DESTDIR?=/opt/perfsonar
VERSION=3.5
RELEASE=0.1.rc1
BIN=$(DESTDIR)/bin
DOC=$(DESTDIR)/doc
ETC=$(DESTDIR)/etc
LIB=$(DESTDIR)/lib

default:
	@echo No need to build the package. Just run \"make install\"

dist:
	mkdir /tmp/$(PACKAGE)-$(VERSION).$(RELEASE)
	tar ch -T MANIFEST | tar x -C /tmp/$(PACKAGE)-$(VERSION).$(RELEASE)
	cd /tmp/$(PACKAGE)-$(VERSION).$(RELEASE) && ln -s doc/LICENSE LICENSE
	cd /tmp/$(PACKAGE)-$(VERSION).$(RELEASE) && ln -s doc/INSTALL INSTALL
	cd /tmp/$(PACKAGE)-$(VERSION).$(RELEASE) && ln -s doc/README README
	tar czf $(PACKAGE)-$(VERSION).$(RELEASE).tar.gz -C /tmp $(PACKAGE)-$(VERSION).$(RELEASE)
	rm -rf /tmp/$(PACKAGE)-$(VERSION).$(RELEASE)

upgrade:
	mkdir /tmp/$(PACKAGE)-$(VERSION).$(RELEASE)
	tar ch --exclude=etc/* -T MANIFEST | tar x -C /tmp/$(PACKAGE)-$(VERSION).$(RELEASE)
	tar czf $(PACKAGE)-$(VERSION).$(RELEASE)-upgrade.tar.gz -C /tmp $(PACKAGE)-$(VERSION).$(RELEASE)
	rm -rf /tmp/$(PACKAGE)-$(VERSION).$(RELEASE)

rpminstall:
	mkdir -p ${DESTDIR}
	tar ch --exclude=etc/* --exclude=*spec --exclude=MANIFEST --exclude=Makefile -T MANIFEST | tar x -C ${DESTDIR}
	for i in `cat MANIFEST | grep ^etc`; do  mkdir -p `dirname $(DESTDIR)/$${i}`; if [ -e $(DESTDIR)/$${i} ]; then install -m 640 -c $${i} $(DESTDIR)/$${i}.new; else install -m 640 -c $${i} $(DESTDIR)/$${i}; fi; done
 
install:
	install -d $(BIN) $(DOC) $(ETC) $(LIB)
	tar ch ./lib/perfSONAR_PS/LSRegistrationDaemon | tar x -C $(LIB)

