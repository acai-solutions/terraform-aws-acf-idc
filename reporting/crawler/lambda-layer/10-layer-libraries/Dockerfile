#tfsec:ignore:DS026
#tfsec:ignore:DS002
# https://gallery.ecr.aws/lambda/python
FROM public.ecr.aws/lambda/python:3.12-arm64

RUN dnf install -y gcc-c++ make
COPY requirements.txt ${LAMBDA_TASK_ROOT}
RUN pip install -r requirements.txt -t ${LAMBDA_TASK_ROOT}/python

RUN rm -rf /root/.cache/pip
RUN dnf clean all
