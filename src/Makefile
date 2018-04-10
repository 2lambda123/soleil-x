ifndef LG_RT_DIR
$(error LG_RT_DIR is not set)
endif

# HDF options
export USE_HDF ?= 1
export HDF_HEADER ?= hdf5.h
HDF_LIBNAME ?= hdf5

# C compiler options
CFLAGS += -g -O2 -Wall -Werror -I$(LG_RT_DIR)
CXXFLAGS += -std=c++11 -g -O2 -Wall -Werror -I$(LG_RT_DIR)

# Regent options
export INCLUDE_PATH := .
ifdef HDF_ROOT
export INCLUDE_PATH := $(INCLUDE_PATH);$(HDF_ROOT)/include
endif
REGENT := $(LG_RT_DIR)/../language/regent.py -g
SOLEIL_FLAGS := -fflow 0 -fopenmp 1 -fcuda 1 -fcuda-offline 1
DOM_HOST_FLAGS := -fflow 0

# Link flags
ifdef CRAYPE_VERSION
LINK_FLAGS += -Bdynamic
LINK_FLAGS += $(CRAY_UGNI_POST_LINK_OPTS) -lugni
LINK_FLAGS += $(CRAY_UDREG_POST_LINK_OPTS) -ludreg
endif
LINK_FLAGS += -L$(LG_RT_DIR)/../bindings/regent -lregent
ifdef HDF_ROOT
LINK_FLAGS += -L$(HDF_ROOT)/lib
export LD_LIBRARY_PATH := $(LD_LIBRARY_PATH):$(HDF_ROOT)/lib
endif
ifeq ($(USE_HDF), 1)
LINK_FLAGS += -l$(HDF_LIBNAME)
endif
LINK_FLAGS += -lm

.PHONY: default all clean

default: soleil.exec

all: soleil.exec dom_host.exec

clean:
	$(RM) soleil.exec soleil.o dom_host.exec dom_host.o \
		soleil_mapper.o config_schema.o config_schema.h json.o

soleil.exec: soleil.o soleil_mapper.o config_schema.o json.o
	$(CXX) -o $@ $^ $(LINK_FLAGS)

soleil.o: soleil.rg soleil_mapper.h config_schema.h hdf_helper.rg dom.rg util.rg
	$(REGENT) soleil.rg $(SOLEIL_FLAGS)

dom_host.exec: dom_host.o config_schema.o json.o
	$(CXX) -o $@ $^ $(LINK_FLAGS)

dom_host.o: dom_host.rg config_schema.h dom.rg util.rg
	$(REGENT) dom_host.rg $(DOM_HOST_FLAGS)

soleil_mapper.o: soleil_mapper.cc soleil_mapper.h config_schema.h
	$(CXX) $(CXXFLAGS) -c -o  $@ $<

config_schema.o config_schema.h: config_helper.rg config_schema.lua json.h util.rg
	$(REGENT) config_helper.rg config_schema.lua

json.o: json.c json.h
	$(CC) $(CFLAGS) -c -o $@ $<