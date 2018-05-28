PY_JSON_LOAD() {
  index=
  while [ ! -z $1 ];do
    if echo $1 | egrep -q '^[0-9]+$'; then
      index="${index}[$1]"
    else
      index="${index}['$1']"
    fi
    shift
  done
  cmd="import sys, json; print(json.load(sys.stdin)${index})"
  val=`cat $CONF_FILE|python3 -c "$cmd"`
  code=$?
  if [ $code -eq 0 ];then
    echo $val
  fi
}
