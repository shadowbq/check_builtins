#!/bin/bash
# Test script to verify bash precedence

echo "=== Testing bash command precedence ==="

echo "1. Default echo (should be builtin):"
echo --version 2>&1 | head -1

echo -e "\n2. Forced external echo:"
command echo --version 2>&1 | head -1

echo -e "\n3. Direct path echo:"
/usr/bin/echo --version 2>&1 | head -1

echo -e "\n4. Builtin disabled echo:"
enable -n echo
echo --version 2>&1 | head -1
enable echo

echo -e "\n5. What type says:"
type echo

echo -e "\n6. What type -a says:"
type -a echo
