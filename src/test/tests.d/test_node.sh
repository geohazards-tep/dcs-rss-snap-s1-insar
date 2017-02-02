#!/bin/bash

export ciop_job_include="/usr/lib/ciop/libexec/ciop-functions.sh"
source ./test_common.sh

test_log_input()
{
  local input="test"
  assertEquals "${input}" "test"
}

. ${SHUNIT2_HOME}/shunit2
