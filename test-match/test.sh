#!/bin/bash
latest_rev=""
ns=pywebapp
deployment=pywebapp
tests_path=~/pod-reloader/
setup_path=$tests_path/setup
modified_path=$tests_path/modified
debug=false
if [[ "$LOG_LEVEL" == "debug" ]]; then
  debug=true
fi
# Text colors
Color_Off='\033[0m'       # Text Reset
Red='\033[0;31m'          # Red
Green='\033[0;32m'        # Green

get_revision() {
  kubectl -n "$ns" get deploy "$deployment" -o jsonpath='{.metadata.annotations.deployment\.kubernetes\.io/revision}'
}

update_latest_rev() {
  latest_rev="$(get_revision)"
}

is_updated() {
  current_rev="$(get_revision)"
  if [[ "$current_rev" != "$latest_rev" ]]; then
    return 0
  fi
  return 1
}

test_must_be_rolled_out() {
  if is_updated; then
    echo -e "${Green}PASS${Color_Off}"
  else
    echo -e "${Red}FAIL${Color_Off}"
  fi
}

test_must_not_be_rolled_out() {
  if ! is_updated; then
    echo -e "${Green}PASS${Color_Off}"
  else
    echo -e "${Red}FAIL${Color_Off}"
  fi
}

reset_state() {
  echo "Resetting state..."
  # instead of delete all annotations, delete deployment
  kubectl -n "$ns" delete deploy "$deployment" > /dev/null 2>&1
  kubectl -n "$ns" apply -f $setup_path/ > /dev/null 2>&1
  # wait for deployment to be ready
  kubectl -n "$ns" rollout status deployment "$deployment" > /dev/null 2>&1
  update_latest_rev
  echo "State reset."
}

debug_info() {
  echo "Latest revision: $latest_rev"
  echo "Current revision: $(get_revision)"
  kubectl -n "$ns" rollout status deployment "$deployment"
  kubectl -n "$ns" get deploy "$deployment" -o yaml
  kubectl -n "$ns" get pods
}


# --- Start ---
reset_state
echo "--- pod-reloader.deckhouse.io/search=true"
kubectl -n "$ns" annotate deployment "$deployment" pod-reloader.deckhouse.io/search="true"

echo "- Deployment MUST be rolled out with changed matching configmap"
kubectl -n "$ns" apply -f $modified_path/match-cm.yaml
sleep 1
if $debug; then
  debug_info
else
  kubectl -n "$ns" rollout status deployment "$deployment"
fi
test_must_be_rolled_out
update_latest_rev

echo "- Deployment MUST NOT be rolled out with changed non-matching configmap"
kubectl -n "$ns" apply -f $modified_path/default-cm.yaml
sleep 1
if $debug; then
  debug_info
else
  kubectl -n "$ns" rollout status deployment "$deployment"
fi
test_must_not_be_rolled_out
update_latest_rev

echo "- Deployment MUST be rolled out with changed matching secret"
kubectl -n "$ns" apply -f $modified_path/match-secret.yaml
sleep 1
if $debug; then
  debug_info
else
  kubectl -n "$ns" rollout status deployment "$deployment"
fi
test_must_be_rolled_out
update_latest_rev

echo "- Deployment MUST NOT be rolled out with changed non-matching secret"
kubectl -n "$ns" apply -f $modified_path/default-secret.yaml
sleep 1
if $debug; then
  debug_info
else
  kubectl -n "$ns" rollout status deployment "$deployment"
fi
test_must_not_be_rolled_out
reset_state



echo "--- pod-reloader.deckhouse.io/secret-reload=default-secret"
kubectl -n "$ns" annotate deployment "$deployment" pod-reloader.deckhouse.io/secret-reload="default-secret"

echo "- Deployment MUST be rolled out with changed matching secret"
kubectl -n "$ns" apply -f $modified_path/default-secret.yaml
sleep 1
if $debug; then
  debug_info
else
  kubectl -n "$ns" rollout status deployment "$deployment"
fi
test_must_be_rolled_out
update_latest_rev

echo "- Deployment MUST NOT be rolled out with changed non-matching secret"
kubectl -n "$ns" apply -f $modified_path/match-secret.yaml
sleep 1
if $debug; then
  debug_info
else
  kubectl -n "$ns" rollout status deployment "$deployment"
fi
test_must_not_be_rolled_out
update_latest_rev



echo "--- pod-reloader.deckhouse.io/configmap-reload=default-cm"
kubectl -n "$ns" annotate deployment "$deployment" pod-reloader.deckhouse.io/configmap-reload="default-cm"

echo "- Deployment MUST be rolled out with changed matching configmap"
kubectl -n "$ns" apply -f $modified_path/default-cm.yaml
sleep 1
if $debug; then
  debug_info
else
  kubectl -n "$ns" rollout status deployment "$deployment"
fi
test_must_be_rolled_out
update_latest_rev

echo "- Deployment MUST NOT be rolled out with changed non-matching configmap"
kubectl -n "$ns" apply -f $modified_path/match-cm.yaml
sleep 1
if $debug; then
  debug_info
else
  kubectl -n "$ns" rollout status deployment "$deployment"
fi
test_must_not_be_rolled_out
reset_state
