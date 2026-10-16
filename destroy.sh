#!/bin/bash
# ==============================================================================
# Automated Teardown Script - IU Cloud Programming (Task 1)
# ==============================================================================
set -e

echo "=== Destroying all AWS Cloud Infrastructure ==="
terraform destroy -auto-approve

echo "=== All resources destroyed. No lingering AWS charges. ==="
