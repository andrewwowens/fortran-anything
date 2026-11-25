# make's built-in default for FC is f77, so ?= would never apply.
ifeq ($(origin FC),default)
FC = gfortran
endif
FFLAGS ?= -std=f2018 -Wall -Wextra -O2
BUILD := build
FA := $(BUILD)/fortran-anything
WORK := $(BUILD)/demo

.PHONY: all demo test clean

all: $(FA)

$(FA): src/fortran_anything.f90
	@mkdir -p $(BUILD)
	$(FC) $(FFLAGS) -J $(BUILD) -o $@ $<

$(BUILD)/roman: demo/fortran/roman.f90
	@mkdir -p $(BUILD)
	$(FC) $(FFLAGS) -J $(BUILD) -o $@ $<

# Record the Python original, replay against the Fortran port, check the gate.
demo: $(FA) $(BUILD)/roman
	$(FA) record --cases demo/cases.txt --dir $(WORK) -- python3 demo/original/roman.py
	$(FA) diff --dir $(WORK) -- $(BUILD)/roman
	$(FA) gate --dir $(WORK)

# The demo must pass, and a wrong port must be caught.
test: demo
	@if $(FA) diff --dir $(WORK) -- echo > /dev/null; then \
		echo "FAIL: diff accepted a wrong port"; exit 1; fi
	@if $(FA) gate --dir $(WORK) > /dev/null; then \
		echo "FAIL: gate opened after a failed diff"; exit 1; fi
	@$(FA) diff --dir $(WORK) -- $(BUILD)/roman > /dev/null
	@$(FA) gate --dir $(WORK)
	@echo "ok"

clean:
	rm -rf $(BUILD)
