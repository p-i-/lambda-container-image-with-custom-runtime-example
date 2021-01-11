function handler () {
    EVENT_DATA=$1
    echo "$EVENT_DATA" 1>&2

    echo "Event Data:" > /tmp/output.log
    echo "    $EVENT_DATA" >> /tmp/output.log
    echo "🌸 Response:" >> /tmp/output.log

    echo "contents" > /tmp/generated-file.txt

    RESPONSE="$(cat /tmp/output.log)"
    echo "$RESPONSE"
}
