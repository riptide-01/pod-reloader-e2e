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

wait_module_ready() {
  kubectl -n d8-pod-reloader rollout status deployment pod-reloader
  kubectl -n d8-pod-reloader wait po --for=condition=Ready --all
}


# --- Start ---
reset_state
kubectl -n "$ns" annotate deployment "$deployment" pod-reloader.deckhouse.io/auto="true"

echo "--- reloadOnDelete=true"
kubectl apply -f $tests_path/test-on-delete/mc-true.yaml

is_reload_on_delete_true=$(kubectl -n d8-pod-reloader get deploy pod-reloader -o yaml | grep -e '--reload-on-delete=true' | wc -l)
echo "is_reload_on_delete_true: $is_reload_on_delete_true"
while [[ "$is_reload_on_delete_true" -eq 0 ]]; do
  sleep 1
  is_reload_on_delete_true=$(kubectl -n d8-pod-reloader get deploy pod-reloader -o yaml | grep -e '--reload-on-delete=true' | wc -l)
  echo "Waiting for reloadOnDelete=true to be set..."
done
wait_module_ready
sleep 5

echo "- Deployment MUST be rolled out with deleted configmap"
kubectl -n "$ns" delete -f $setup_path/default-cm.yaml
sleep 1
if $debug; then
  debug_info
else
  kubectl -n "$ns" rollout status deployment "$deployment"
fi
test_must_be_rolled_out
update_latest_rev

echo "--- reloadOnDelete=false"
reset_state
kubectl apply -f $tests_path/test-on-delete/mc-false.yaml
sleep 1
wait_module_ready

echo "- Deployment MUST NOT be rolled out with deleted configmap"
kubectl -n "$ns" delete -f $setup_path/default-cm.yaml
sleep 1
if $debug; then
  debug_info
else
  kubectl -n "$ns" rollout status deployment "$deployment"
fi
test_must_not_be_rolled_out
reset_state
