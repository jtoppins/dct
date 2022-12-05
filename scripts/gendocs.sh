#!/bin/sh

export LC_ALL=C
export TZ="UTC 0"

cwd=$(pwd)
base=$(dirname $0)
srcroot="${cwd}/${base}/.."

DCT_SRC_ROOT="${srcroot}"
DCT_DATA_ROOT=${DCT_DATA_ROOT:-${srcroot}/data}
DCT_TEMPLATE_PATH=${DCT_TEMPLATE_PATH:-${srcroot}/../dcs-mission-oeo-templates}
DCT_TEST_LOG="${DCT_DATA_ROOT}/dct_test.log"
if ! test -d "${DCT_TEMPLATE_PATH}"; then
	unset DCT_TEMPLATE_PATH
fi
LUA_EXEC=${LUA_EXEC:-lua5.1}
LUA_LIB_PATH=${LUA_LIB_PATH:-${srcroot}/../lua-libs/src/?.lua}
LUA_PATH="${srcroot}/src/?.lua;${LUA_LIB_PATH}"
LUA_PATH="${LUA_PATH};;"
export LUA_PATH
export DCT_DATA_ROOT
export DCT_TEMPLATE_PATH
export DCT_TEST_LOG
export DCT_SRC_ROOT
#echo "lua-path: ${LUA_PATH}"
#echo "DCT data root: ${DCT_DATA_ROOT}"
#echo "DCT template path: ${DCT_TEMPLATE_PATH}"

cd "${base}"

cat << EOF | ${LUA_EXEC} -
require("os")
require("io")
require("lfs")
require("dcttestlibs")
require("dct")
local Template = require("dct.templates.Template")
Template.genDocs()
EOF

cd "${cwd}"
exit 0
