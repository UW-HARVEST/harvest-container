FROM nixos/nix

RUN nix-channel --update

COPY default.nix /tmp/
COPY s3_wrapper.py /tmp/
COPY translate.sh /tmp/

RUN chmod +x /tmp/s3_wrapper.py
RUN nix-env --install --file /tmp/default.nix

ENTRYPOINT [ "s3_wrapper.py" ]
