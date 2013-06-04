### The project name
PROJECT=pgsql-backup

### Dependencies
# Note we don't include deps that have configurable paths since they may exist
# in a location not included in $PATH (hence why they have config options)
DEP_BINS=bash rm mkdir date ln sed du grep cat

### Destination Paths
PREFIX=/usr/local
D_CNF=/etc

###############################################################################

all: install

install: test bin config docs
	# install the actual scripts
	install -D -m 0755 src/$(PROJECT).sh $(DESTDIR)$(PREFIX)/bin/$(PROJECT)
	install -D -m 0644 $(PROJECT).1.man $(DESTDIR)$(PREFIX)/share/man/man1/$(PROJECT).1p

test:
	@echo "==> Checking for required external dependencies"
	for bindep in $(DEP_BINS) ; do \
		which $$bindep > /dev/null || { echo "$$bindep not found"; exit 1;} ; \
	done

	@echo "==> Checking for valid script syntax"
	for bs in src/*.sh ; do \
		bash -n $$bs ; \
	done

	@echo "==> It all looks good Captain!"

bin: test src/$(PROJECT).sh

config: pgsql-backup.conf
	# Install (without overwriting) configuration files
	[[ -e $(DESTDIR)$(D_CNF)/pgsql-backup.conf ]] || \
		install -D -m 0644 $(PROJECT).conf $(DESTDIR)$(D_CNF)/pgsql-backup.conf

docs: $(PROJECT).pod
	# build man pages
	pod2man --name=$(PROJECT) $(PROJECT).pod $(PROJECT).1.man

uninstall:
	rm -f $(DESTDIR)$(PREFIX)/bin/$(PROJECT)
	rm -f $(DESTDIR)$(PREFIX)/share/man/man1/$(PROJECT).1p
	@echo "Leaving '$(DESTDIR)$(D_CNF)/pgsql-backup.conf' untouched"
