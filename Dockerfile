FROM nixos/nix

WORKDIR /usr/c2rust_execution
COPY translate.sh /bin/
RUN ["chmod", "+x", "/bin/translate.sh"]


ENTRYPOINT [ "/bin/translate.sh" ]
