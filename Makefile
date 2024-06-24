RMEM ?= rmem
HERD ?= herd7
MCOMPARE ?= mcompare7
MSORT ?= msort7
MSUM ?= msum7
LITMUS ?= litmus7

GCC ?= gcc

ATFILE ?= tests/@all

######################################################################
# The following targets are usable even if you do not have the models
# (i.e. they do not trigger rebuild of the model logs)

verify-allow-%:
	@python3 tools/verify.py allow $*

verify-forbidden-%:
	@python3 tools/verify.py forbidden $*

# 'make show-test TEST=<name>' where <name> is a litmus test name
# (e.g. MP) shows the litmus test and the model results for it
show-test:
	@$(MAKE) -s show-test-file
	@echo
	@$(MAKE) -s show-herd-test
	@echo
	@$(MAKE) -s show-hw-test
show-test-file: TESTFILES := $(shell find tests -name "$(subst [,\[,$(subst ],\],$(TEST))).litmus")
show-test-file:
	$(if $(TESTFILES),,$(error Error: cannot find $(TEST)))
	$(if $(word 2,$(TESTFILES)),$(warning $(TEST) was found multiple times))
	@ls -1 $(TESTFILES)
	@echo ----------------------------------------
	@cat $(word 1,$(TESTFILES))
	@echo ----------------------------------------
show-%-test:
	@echo "$(TEST)" > names.temp
	@echo "*** $* model results: ***"
	@$(MSUM) -names names.temp model-results/$*.logs 2>/dev/null | grep . || echo NONE
	@rm -f names.temp
show-hw-test:
	@echo "$(TEST)" > names.temp
	@echo "*** $* hardware results: ***"
	@$(MSUM) -names names.temp hw-results/run.log 2>/dev/null | grep . || echo NONE
	@rm -f names.temp
.PHONY: show-test show-test-file show-hw-test

clean: clean-model-logs clean-hw-tests
.PHONY: clean

######################################################################
# For the following targets you will need to have the models
# NOTE: using the '-rR' command line options, to disable make's
# built-in rules and variables, is significantly faster

# Rebuild the model logs by running the models
run-models: model-results/herd.logs
.PHONY: run-models

# Remove old model logs
clean-model-logs: clean-model-logs-herd
.PHONY: clean-model-logs

# '$(call ats,<@file>)' expands to the list of @ files that are
# included by <@file> (recursively), including <@file> at the
# beginning of the list
ats = $(eval _atscum:=)$(eval $(call _ats,$1))$(_atscum)
define _ats =
_atscum += $1
$$(foreach at,$(shell grep @ $1),$$(eval $$(call _ats,$(dir $1)$$(at))))
endef

-include herd-tests.d
%-tests.d: $(call ats,$(ATFILE))
	$(MSORT) $< | grep -v '^[[:space:]]*#' | awk '{\
	  print "model-results/$*/" $$1 ".log: count =" , NR;\
	  print "model-results/$*/" $$1 ".log:" , $$1;\
	  print "model-results/$*.logs: model-results/$*/" $$1 ".log";\
	}\
	END {\
	  print "model-results/$*.logs: totalc =" , NR;\
	}' > $@
model-results/herd/%.log: RUNMODEL = $(HERD) -model riscv.cat "$<" > "$@"
model-results/%.log:
	@printf "%5d/$(totalc) $(notdir $*)\n" "$(count)"
	@mkdir -p $(dir $@)
	@$(RUNMODEL)
clean-model-logs-%:
	rm -rf model-results/$*/tests

model-results/%.logs:
	rm -f $@
	$(call long-cat,$^,$@)

# '$(call long-cat,<in-files>,<out-file>)' chops <in-files> to
# multiple parts of LONGCATMAX files each, and executes
# 'cat <in-part-n> >> <out-file>' for each part.
LONGCATMAX ?= 1000
long-cat = $(eval ts :=)$(foreach t,$1,$(if $(filter $(LONGCATMAX),$(words $(ts))),$(_long-cat)$(eval ts := $t),$(eval ts += $t)))$(_long-cat)
define _long-cat =
@echo 'cat [...] >> $2'
@cat $(ts) >> $2

endef

######################################################################

# Generate, build and run the tests on this machine
run-hw-tests: | hw-tests
	cd $| && ./run.sh
	$(MAKE) merge-hw-tests
.PHONY: run-hw-tests

# Generate and cross-compile the tests, to be run on a different machine
hw-single-test: CORES ?= $(shell grep '^[[:space:]]*P0\([[:space:]]*|[[:space:]]*P[0-9]\+\)\+[[:space:]]*;[[:space:]]*$$' "$(LITMUSFILE)" | sed 's/[^P]//g' | tr -d '\n' | wc -m)
hw-tests hw-single-test: hw-%: hw-%-src/run.exe hw-%-src/run.sh
	mkdir -p $@
	cp $^ $@

# Generate the C program that runs the tests, but do not compile it
hw-%-src.tgz: hw-%-src/run.sh | hw-%-src
	tar -caf $@ hw-%-src


hw-%-src/run.exe: | hw-%-src
	$(MAKE) -C $|


hw-tests-src: TESTFILE = $(ATFILE)
hw-single-test-src: TESTFILE = $(LITMUSFILE)
hw-%-src:
	rm -rf $@
	mkdir -p $@
	$(LITMUS) -mach ./riscv.cfg -avail $(CORES) $(foreach e,$^,-excl $(e)) -o $@ "$(TESTFILE)"

### This will produce 1.2 billion results for a 2-thread test
# -s values for litmus run.exe
SIZES=50k 500k 10k 100k 5k 1M
# -st values for litmus run.exe
STRIDES=1 2 3 4 5 6 7 8 31 133
count := $(shell echo '$(words $(STRIDES)) * $(words $(SIZES))' | bc)
# Calculate a value for litmus run.exe -r argument, given a value to
# the -s argument and the number of cores in the machine, in order to
# produce 20 million results for a 2-thread test
r-for-s = $(shell printf 'scale=2; x=40000000 / (%d * $(CORES)) + 0.5; scale=0; if (x > 1) x/1 else 1\n' "`echo '$1' | sed 's/[mM]$$/000000/; s/[kK]$$/000/'`" | bc | sed 's/000000$$/M/; s/000$$/k/')
hw-%-src/run.sh: | hw-%-src
	@{ echo '#!/bin/sh';\
	  echo 'echo "Running a quick test"';\
	  echo './run.exe -st 1 -s 5k -r 20 > run.test.log';\
	  echo 'c=0';\
	  $(foreach st,$(STRIDES),\
	    $(foreach s,$(SIZES),\
	      echo 'c=$$(($$c + 1))';\
	      echo 'echo "Running test $$c out of $(count)"';\
	      echo './run.exe -st $(st) -s $(s) -r $(call r-for-s,$(s)) > "run.$$c.log"';\
	    )\
	  )\
	  echo 'touch done';\
	  echo 'echo "Done"';\
	} > $@
	chmod a+x $@


FORCE:
.PHONY: FORCE

clean-hw-tests:
	rm -rf herd-tests.d
	rm -rf hw-tests hw-tests-src hw-tests-src.tgz
	rm -rf hw-single-test hw-single-test-src hw-single-test-src.tgz
.PHONY: clean-hw-tests
