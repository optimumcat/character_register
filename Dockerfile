FROM debian:latest

WORKDIR /opt/character_register
EXPOSE 5000
ENTRYPOINT ["python3"]
CMD ["app.py"]

COPY app/* /opt/character_register/

RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install python3 python3-pip -y && \
    pip3 install --break-system-packages -r /opt/character_register/requirements.txt
