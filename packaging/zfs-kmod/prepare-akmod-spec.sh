#!/usr/bin/bash
set -euo pipefail

spec=$1

sed -i \
  -e 's/^%define buildforkernels akmod/#define buildforkernels akmod/' \
  -e 's/^#define buildforkernels current/%define buildforkernels current/' \
  -e 's/ %{?buildforkernels:--%{buildforkernels}} --devel/ %{?buildforkernels:--%{buildforkernels}} %{?kernels:--for-kernels "%{?kernels}"} --devel/g' \
  "$spec"
