#
set -o pipefail
set -o nounset
set -o errexit

main() {
  echo "airflow test"
  trigger_dag
  echo "Waiting for the job to finish..."
  sleep 60
  check_result_dag
}

trigger_dag() {
  echo "Enabling port forward"
  kubectl port-forward svc/airflow-test-webserver -n airflow 8080 &
  sleep 10
  echo "Enabling \"example_local_kubernetes_executor DAG\""
  curl -X 'PATCH' \
    'http://localhost:8080/api/v1/dags/example_local_kubernetes_executor' \
    -H 'accept: application/json' \
    -H 'Content-Type: application/json' \
    --user "admin:admin" \
    -d '{ "is_paused": false }'

  echo "Triggering DAG \"example_local_kubernetes_executor\""
  curl -X 'POST' \
    'http://localhost:8080/api/v1/dags/example_local_kubernetes_executor/dagRuns' \
    -H 'accept: application/json' \
    -H 'Content-Type: application/json' \
    --user "admin:admin" \
    -d '{ "conf": {}, "dag_run_id": "string", "logical_date": "2023-09-15T12:29:23.444Z", "note": "string"}'
}

check_result_dag() {
  curl -X 'GET' \
    'http://localhost:8080/api/v1/dags/example_local_kubernetes_executor/dagRuns?limit=100' \
    --user "admin:admin" \
    -H 'accept: application/json' > out.json
  export RESULT=$(cat out.json | jq -cs '.[0].dag_runs[0].state' | sed 's/"//g')
  EXPECTED_RESULT="success"
  if [ "$RESULT" == "$EXPECTED_RESULT" ]; then
    echo "Airflow is OK"
    exit 0
  else
    echo "Airflow has some trouble; please check"
    exit 1
  fi
}

main "$@"
