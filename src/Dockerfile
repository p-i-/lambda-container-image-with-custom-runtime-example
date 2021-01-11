# Use Amazon Linux 2 (It's based on CentOS) as base image
FROM amazon/aws-lambda-provided:al2

COPY bootstrap   /var/runtime/bootstrap
COPY function.sh /var/task/function.sh

RUN chmod u+rx \
    /var/runtime/bootstrap \
    /var/task/function.sh

CMD [ "function.sh.handler" ]
