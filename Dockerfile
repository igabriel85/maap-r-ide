# https://registry.access.redhat.com/ubi8/ubi
FROM --platform=linux/amd64 registry.access.redhat.com/ubi8/ubi:8.9-1107
LABEL maintainer="Red Hat, Inc."

LABEL com.redhat.component="devfile-base-container"
LABEL name="devfile/base-developer-image"
LABEL version="ubi8"

#label for EULA
LABEL com.redhat.license_terms="https://www.redhat.com/en/about/red-hat-end-user-license-agreements#UBI"

#labels for container catalog
LABEL summary="devfile base developer image"
LABEL description="Image with base developers tools. Languages SDK and runtimes excluded."
LABEL io.k8s.display-name="devfile-developer-base"
LABEL modified.at="IeAT"
LABEL modified.by="Gabriel Iuhasz"
LABEL modified.version="0.0.5"
LABEL modified.for="MAAP Jupyter R IDE"

# add env variables
ENV HOME=/home/tooling
ENV BMAP_BACKEND_URL=http://backend-val.biomass-maap.com/bmap-web/

USER 0

RUN mkdir -p /home/tooling/

RUN dnf install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm && \
    dnf update -y && \
    dnf install -y bash curl diffutils git git-lfs iproute jq less lsof man nano procps p7zip p7zip-plugins \
                   perl-Digest-SHA net-tools openssh-clients rsync socat sudo time vim wget zip stow && \
                   dnf clean all

## gh-cli
RUN \
    TEMP_DIR="$(mktemp -d)"; \
    cd "${TEMP_DIR}"; \
    GH_VERSION="2.0.0"; \
    GH_ARCH="linux_amd64"; \
    GH_TGZ="gh_${GH_VERSION}_${GH_ARCH}.tar.gz"; \
    GH_TGZ_URL="https://github.com/cli/cli/releases/download/v${GH_VERSION}/${GH_TGZ}"; \
    GH_CHEKSUMS_URL="https://github.com/cli/cli/releases/download/v${GH_VERSION}/gh_${GH_VERSION}_checksums.txt"; \
    curl -sSLO "${GH_TGZ_URL}"; \
    curl -sSLO "${GH_CHEKSUMS_URL}"; \
    sha256sum --ignore-missing -c "gh_${GH_VERSION}_checksums.txt" 2>&1 | grep OK; \
    tar -zxvf "${GH_TGZ}"; \
    mv "gh_${GH_VERSION}_${GH_ARCH}"/bin/gh /usr/local/bin/; \
    mv "gh_${GH_VERSION}_${GH_ARCH}"/share/man/man1/* /usr/local/share/man/man1; \
    cd -; \
    rm -rf "${TEMP_DIR}"

## ripgrep
RUN \
    TEMP_DIR="$(mktemp -d)"; \
    cd "${TEMP_DIR}"; \
    RG_VERSION="13.0.0"; \
    RG_ARCH="x86_64-unknown-linux-musl"; \
    RG_TGZ="ripgrep-${RG_VERSION}-${RG_ARCH}.tar.gz"; \
    RG_TGZ_URL="https://github.com/BurntSushi/ripgrep/releases/download/${RG_VERSION}/${RG_TGZ}"; \
    curl -sSLO "${RG_TGZ_URL}"; \
    tar -zxvf "${RG_TGZ}"; \
    mv "ripgrep-${RG_VERSION}-${RG_ARCH}"/rg /usr/local/bin/; \
    mv "ripgrep-${RG_VERSION}-${RG_ARCH}"/doc/rg.1 /usr/local/share/man/man1; \
    cd -; \
    rm -rf "${TEMP_DIR}"

## bat
RUN \
    TEMP_DIR="$(mktemp -d)"; \
    cd "${TEMP_DIR}"; \
    BAT_VERSION="0.18.3"; \
    BAT_ARCH="x86_64-unknown-linux-musl"; \
    BAT_TGZ="bat-v${BAT_VERSION}-${BAT_ARCH}.tar.gz"; \
    BAT_TGZ_URL="https://github.com/sharkdp/bat/releases/download/v${BAT_VERSION}/${BAT_TGZ}"; \
    curl -sSLO "${BAT_TGZ_URL}"; \
    tar -zxvf "${BAT_TGZ}"; \
    mv "bat-v${BAT_VERSION}-${BAT_ARCH}"/bat /usr/local/bin/; \
    mv "bat-v${BAT_VERSION}-${BAT_ARCH}"/bat.1 /usr/local/share/man/man1; \
    cd -; \
    rm -rf "${TEMP_DIR}"

## fd
RUN \
    TEMP_DIR="$(mktemp -d)" && \
    cd "${TEMP_DIR}" && \
    FD_VERSION="8.7.0" && \
    FD_ARCH="x86_64-unknown-linux-musl" &&\
    FD_TGZ="fd-v${FD_VERSION}-${FD_ARCH}.tar.gz" && \
    FD_TGZ_URL="https://github.com/sharkdp/fd/releases/download/v${FD_VERSION}/${FD_TGZ}" && \
    curl -sSLO "${FD_TGZ_URL}" && \
    tar -xvf "${FD_TGZ}" && \
    mv "fd-v${FD_VERSION}-${FD_ARCH}"/fd /usr/local/bin && \
    mv "fd-v${FD_VERSION}-${FD_ARCH}"/fd.1 /usr/local/share/man/man1 && \
    cd - && \
    rm -rf "${TEMP_DIR}"

COPY --chown=0:0 .stow-local-ignore /home/tooling/
RUN \
    # add user and configure it
    useradd -u 1234 -G wheel,root -d /home/user --shell /bin/bash -m user && \
    # Setup $PS1 for a consistent and reasonable prompt
    touch /etc/profile.d/udi_prompt.sh && \
    chown 1234 /etc/profile.d/udi_prompt.sh && \
    echo "export PS1='\W \`git branch --show-current 2>/dev/null | sed -r -e \"s@^(.+)@\(\1\) @\"\`$ '" >> /etc/profile.d/udi_prompt.sh && \
    # Copy the global git configuration to user config as global /etc/gitconfig
    # file may be overwritten by a mounted file at runtime
    cp /etc/gitconfig ${HOME}/.gitconfig && \
    chown 1234 ${HOME}/ ${HOME}/.viminfo ${HOME}/.gitconfig ${HOME}/.stow-local-ignore && \
    # Set permissions on /etc/passwd and /home to allow arbitrary users to write
    chgrp -R 0 /home && \
    chmod -R g=u /etc/passwd /etc/group /home && \
    # Create symbolic links from /home/tooling/ -> /home/user/
    stow . -t /home/user/ -d /home/tooling/ && \
    # .viminfo cannot be a symbolic link for security reasons, so copy it to /home/user/
    cp /home/tooling/.viminfo /home/user/.viminfo && \
    # Bash-related files are backed up to /home/tooling/ incase they are deleted when persistUserHome is enabled.
    cp /home/user/.bashrc /home/tooling/.bashrc && \
    cp /home/user/.bash_profile /home/tooling/.bash_profile && \
    chown 1234 /home/tooling/.bashrc /home/tooling/.bash_profile

# Ajust permissions
#RUN chgrp -Rf root /home/user && chmod -Rf g+w /home/user

#install packages
#RUN dnf install -y gdal-devel geos-devel udunits2-devel proj-devel freetype-devel libjpeg-turbo-devel && \
#    dnf install -y fftw-devel hdf hdf5 libpq-devel protobuf-devel netcdf-devel sqlite-devel openssl-devel udunits2-devel netcdf postgis protobuf-compiler sqlite tcl-devel unixODBC-devel --nobest && \
#
## install opengl
#RUN dnf install -y mesa-libGL mesa-libGLU && \
#    dnf clean all

# set user as the owner of /opt
RUN chown -R 1234:0 /opt && \
    chmod -R g=u /opt

# Set CONDA and system environment variables
ENV CONDA_DIR /opt/conda
ENV CONDA_MAAP_ENV "pymaap"
ENV PATH "$PATH:$CONDA_DIR/bin"
#ENV HOME=/home/tooling

# copy environment.yml
COPY environment.yml /

# Set variables.py
USER 1234

# Miniconda install
RUN wget --quiet https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O ~/miniconda.sh && \
    bash ~/miniconda.sh -b -p $CONDA_DIR && rm ~/miniconda.sh

# conda init
RUN $CONDA_DIR/bin/conda init bash

# create CONDA_MAAP_ENV conda env using a environment.yaml
RUN $CONDA_DIR/bin/conda env create -y -n $CONDA_MAAP_ENV -f /environment.yml

# activate CONDA_MAAP_ENV environment by default
RUN echo "conda activate $CONDA_MAAP_ENV" >> ~/.bashrc

# switch to conda CONDA_MAAP_ENV environment for installation
ENV BASH_ENV ~/.bashrc
SHELL ["/bin/bash", "-c"]


# Additional settings jupyter
ENV CONFIG $HOME/.jupyter/jupyter_notebook_config.py
ENV CONFIG_IPYTHON $HOME/.ipython/profile_default/ipython_config.py

RUN jupyter notebook --generate-config --allow-root && \
    ipython profile create

RUN echo "c.NotebookApp.ip = '*'" >>${CONFIG} && \
    echo "c.NotebookApp.open_browser = False" >>${CONFIG} && \
    echo "c.NotebookApp.iopub_data_rate_limit=10000000000" >>${CONFIG} && \
    echo "c.NotebookApp.terminado_settings = {'shell_command': ['/bin/bash']}" >>${CONFIG}

RUN echo "c.InteractiveShellApp.exec_lines = ['%matplotlib inline']" >>${CONFIG_IPYTHON}

# Enable a more liberal Content-Security-Policy so that we can display Jupyter
# in an iframe.
RUN echo "c.NotebookApp.tornado_settings = {" >> $CONFIG && \
       echo "    'headers': {" >> $CONFIG && \
       echo "        'Content-Security-Policy': \"frame-ancestors 'self' *\"" >> $CONFIG && \
       echo "    }" >> $CONFIG && \
       echo "}" >> $CONFIG


#### CLEANUP PHASE
USER 0
# cleanup installation
RUN rm -f /environment.yml

# cleanup YUM repos
RUN yum -y clean all
# cleanup conda
RUN conda clean -afy
#### /END CLEANUP

COPY --chown=0:0 entrypoint.sh /
RUN chmod +x /entrypoint.sh

USER 1234 
# Set the working directory
WORKDIR /projects

# reset home to user
ENV HOME=/home/user

# create .Rprofile and add CRAN mirror
RUN echo "options(repos = c(CRAN = 'https://cloud.r-project.org'))" > $HOME/.Rprofile

#activate env
#SHELL ["conda", "run", "-n", "pymaap", "/bin/bash", "-c"]

# install R packages
RUN /opt/conda/envs/pymaap/bin/R -e 'install.packages("lasR", repos="https://r-lidar.r-universe.dev")'
RUN /opt/conda/envs/pymaap/bin/R -e 'install.packages("lidR")'

# reset shell
#SHELL ["/bin/bash", "-c"]

# Expose port
EXPOSE 8888

ENTRYPOINT ["/entrypoint.sh" ]
CMD ["tail", "-f", "/dev/null"]