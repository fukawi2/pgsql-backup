### The project name
PROJECT=pgsql-backup

### Dependencies
DEP_BINS=bash pg_dump psql rm mkdir date ln sed du grep cat mail gzip bzip2

### Destination Paths
D_BIN=/usr/local/sbin
D_DOC=/usr/local/share/doc/$(PROJECT)
D_MAN=/usr/local/share/man
D_CNF=/etc

###############################################################################

all: install

install: test bin config
	# install the actual scripts
	install -D -m 0755 src/$(PROJECT).sh $(DESTDIR)$(D_BIN)/$(PROJECT)

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

config: $(PROJECT).conf
	# Install (without overwriting) configuration files
	[[ -e $(DESTDIR)$(D_CNF)/$(PROJECT).conf ]] || \
		install -D -m 0644 $(PROJECT).conf $(DESTDIR)$(D_CNF)/$(PROJECT).conf

uninstall:
	rm -f $(DESTDIR)$(D_BIN)/$(PROJECT)
	@echo "Leaving '$(DESTDIR)$(D_CNF)/$(PROJECT).conf' untouched"
