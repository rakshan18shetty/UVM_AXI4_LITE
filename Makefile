#=====================================================================
# VCS / UVM Regression Makefile
#=====================================================================

# ---- Config ---------------------------------------------------------

TESTLIST      ?= basic_test read_only_test write_simul_test wr_rd_simul_test write_aw_then_w_test write_w_then_aw_test back_pressure_test out_of_range_addr_test unaligned_addr_test full_regression_test
NUM_RUNS      ?= 1
UVM_VERBOSITY ?= UVM_MEDIUM
UVM_TIMEOUT   ?= 2000000

# Set to 1 to also generate an HTML report for every individual run
PER_RUN_REPORT ?= 0

# Standalone smoke-test coverage directory
CM_DIR        ?= simv.vdb

# Compile-time coverage DB
DESIGN_VDB    ?= simv.vdb

# Single-test runs
SINGLE_ROOT   ?= single_runs

# Regression layout:
#   regression_cm/runs/<test>_run<i>/simv.vdb
#   regression_cm/runs/<test>_run<i>/<test>_run<i>.log
#   regression_cm/merged/simv.vdb
#   regression_cm/merged/report/dashboard.html

REGR_ROOT       ?= regression_cm
REGR_RUNS_DIR    = $(REGR_ROOT)/runs
REGR_MERGED_DIR  = $(REGR_ROOT)/merged
REGR_MERGED      = $(REGR_MERGED_DIR)/simv
REGR_REPORT      = $(REGR_MERGED_DIR)/report

CM_OPTS = -cm line+cond+fsm+tgl+branch+assert

SIMV = $(CURDIR)/simv

SETUP_ENV = source /fetools/synopsys/source/source.sh

.PHONY: all compile run regression merge_regression clean clean_regression start git

all: compile


# ---- Compile ---------------------------------------------------------

compile:
	@echo ">>> Compiling with VCS..."
	/bin/csh -c "$(SETUP_ENV) && cd $(CURDIR) && vcs -full64 -sverilog -ntb_opts uvm -licqueue $(CM_OPTS) -assert svaext -lca -assert enable_diag top.sv -l compile.log"

	@if [ ! -x "$(SIMV)" ]; then \
		echo "!!! ERROR: simv was not generated"; \
		exit 1; \
	fi

	@echo ">>> VCS compilation successful"
	@echo ">>> Simulator: $(SIMV)"


# ---- Run a single, arbitrary test on demand -------------------------

# Usage:
#   make run TEST=basic_test
#   make run TEST=basic_test SEED=12345

run:
ifndef TEST
	$(error Usage: make run TEST=<test_name> [SEED=<n>])
endif

	@if [ ! -x "$(SIMV)" ]; then \
		echo "!!! ERROR: simv not found. Run 'make compile' first."; \
		exit 1; \
	fi

	@rm -rf $(SINGLE_ROOT)/$(TEST)
	@mkdir -p $(SINGLE_ROOT)/$(TEST)

	@echo ">>> Running $(TEST)..."

	/bin/csh -c "$(SETUP_ENV) && cd $(CURDIR) && $(SIMV) $(CM_OPTS) -cm_dir $(SINGLE_ROOT)/$(TEST)/simv.vdb +UVM_TESTNAME=$(TEST) +UVM_VERBOSITY=$(UVM_VERBOSITY) +UVM_TIMEOUT=$(UVM_TIMEOUT) $(if $(SEED),+ntb_random_seed=$(SEED)) -l $(SINGLE_ROOT)/$(TEST)/$(TEST).log"

	@echo ">>> Log            : $(SINGLE_ROOT)/$(TEST)/$(TEST).log"
	@echo ">>> Coverage DB    : $(SINGLE_ROOT)/$(TEST)/simv.vdb"

	/bin/csh -c "$(SETUP_ENV) && cd $(CURDIR) && urg -dir $(DESIGN_VDB) $(SINGLE_ROOT)/$(TEST)/simv.vdb -report $(SINGLE_ROOT)/$(TEST)/report"

	@echo ">>> Coverage report: $(SINGLE_ROOT)/$(TEST)/report/dashboard.html"


# ---- Regression ------------------------------------------------------

# Every run gets its own directory containing:
#   simv.vdb
#   <test>_run<i>.log
#
# Every run that produces a VDB is added to vdb_list.txt.
# Failed runs are recorded in failed_runs.txt.

regression:
	@if [ ! -x "$(SIMV)" ]; then \
		echo "!!! ERROR: simv not found. Run 'make compile' first."; \
		exit 1; \
	fi

	@mkdir -p $(REGR_RUNS_DIR)
	@rm -f $(REGR_ROOT)/vdb_list.txt $(REGR_ROOT)/failed_runs.txt

	@for t in $(TESTLIST); do \
		for i in $$(seq 1 $(NUM_RUNS)); do \
			run_dir=$(REGR_RUNS_DIR)/$${t}_run$${i}; \
			vdb=$$run_dir/simv.vdb; \
			log=$$run_dir/$${t}_run$${i}.log; \
			rm -rf $$run_dir; \
			mkdir -p $$run_dir; \
			echo ">>> Running $$t (run $$i/$(NUM_RUNS)) -> $$run_dir"; \
			/bin/csh -c "$(SETUP_ENV) && cd $(CURDIR) && $(SIMV) $(CM_OPTS) -cm_dir $$vdb +UVM_TESTNAME=$$t +UVM_VERBOSITY=$(UVM_VERBOSITY) +UVM_TIMEOUT=$(UVM_TIMEOUT) +ntb_random_seed_automatic -l $$log"; \
			status=$$?; \
			if grep -qE "UVM_FATAL *: *[1-9]|UVM_ERROR *: *[1-9]" $$log 2>/dev/null; then \
				status=1; \
			fi; \
			if [ $$status -ne 0 ]; then \
				echo "$$t run $$i (exit=$$status) -> $$log" >> $(REGR_ROOT)/failed_runs.txt; \
				echo "!!! $$t run $$i FAILED - see $$log (coverage still merged if a vdb exists)"; \
			fi; \
			if [ -d $$vdb ] && [ -n "$$(ls -A $$vdb 2>/dev/null)" ]; then \
				echo $$vdb >> $(REGR_ROOT)/vdb_list.txt; \
				echo ">>> Coverage DB generated: $$vdb"; \
			else \
				echo "!!! $$t run $$i produced no coverage DB - nothing to merge for this run"; \
				echo "$$t run $$i (NO VDB) -> $$log" >> $(REGR_ROOT)/failed_runs.txt; \
			fi; \
			if [ "$(PER_RUN_REPORT)" = "1" ] && [ -d $$vdb ]; then \
				/bin/csh -c "$(SETUP_ENV) && cd $(CURDIR) && urg -dir $(DESIGN_VDB) $$vdb -report $$run_dir/report" > /dev/null 2>&1; \
			fi; \
		done; \
	done

	@$(MAKE) merge_regression


# ---- Merge coverage from every run that produced a VDB ---------------

merge_regression:
	@if [ ! -s $(REGR_ROOT)/vdb_list.txt ]; then \
		echo "!!! No coverage DBs found to merge. Check per-run logs in $(REGR_RUNS_DIR)."; \
		exit 1; \
	fi

	@echo ">>> Merging coverage from $$(wc -l < $(REGR_ROOT)/vdb_list.txt) run(s) (failed runs included)..."

	@rm -rf $(REGR_MERGED_DIR)
	@mkdir -p $(REGR_MERGED_DIR)

	/bin/csh -c "$(SETUP_ENV) && cd $(CURDIR) && urg -dir $(DESIGN_VDB) \`cat $(REGR_ROOT)/vdb_list.txt\` -dbname $(REGR_MERGED) -report $(REGR_REPORT)"

	@echo ">>> Merged coverage DB : $(REGR_MERGED).vdb"
	@echo ">>> Merged HTML report : $(REGR_REPORT)/dashboard.html"

	@if [ -s $(REGR_ROOT)/failed_runs.txt ]; then \
		echo ">>> NOTE: Some runs failed."; \
		echo ">>> See: $(REGR_ROOT)/failed_runs.txt"; \
	fi


# ---- Housekeeping ----------------------------------------------------

clean_regression:
	rm -rf $(REGR_ROOT)

clean:
	rm -rf simv simv.daidir csrc *.log $(CM_DIR) urgReport DVEfiles ucli.key $(SINGLE_ROOT)


# ---- Interactive Synopsys shell --------------------------------------

start:
	/bin/csh -c "source /fetools/synopsys/source/source.sh && cd $(CURDIR) && exec /bin/csh"


# ---- Git --------------------------------------------------------------

git:
	@echo "Enter your git commit message:"
	@read msg; \
	git add *.sv Makefile; \
	git commit -m "$$msg"; \
	git push

