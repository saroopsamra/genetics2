FROM ucsdets/datahub-base-notebook:2020.2-stable

USER root

# install linux packages
RUN apt-get update && \
    apt-get install tk-dev \
                    tcl-dev \
                    cmake \
                    wget \
                    default-jdk \
                    libbz2-dev \
                    -y

# build conda environment with required r packages & install RStudio into it 
COPY r-bio.yaml /tmp
RUN conda env create --file /tmp/r-bio.yaml

ENV RSTUDIO_PKG=rstudio-server-1.2.5042-amd64.deb
ENV RSTUDIO_URL=https://download2.rstudio.org/server/bionic/amd64/${RSTUDIO_PKG}
ENV PATH="${PATH}:/usr/lib/rstudio-server/bin"
ENV LD_LIBRARY_PATH="/usr/lib/R/lib:/lib:/usr/lib/x86_64-linux-gnu:/usr/lib/jvm/java-7-openjdk-amd64/jre/lib/amd64/server:/opt/conda/envs/r-bio/bin/R/lib"
ENV SHELL=/bin/bash

RUN conda run -n r-bio /bin/bash -c "ln -s /opt/conda/bin/R /usr/bin/R && \
                                      apt-get update && \
                                      apt-get -qq install -y apt-utils gdebi-core dpkg-sig && \
                                      gpg --keyserver keys.gnupg.net --recv-keys 3F32EE77E331692F && \
                                      curl -L ${RSTUDIO_URL} > ${RSTUDIO_PKG} && \
                                      dpkg-sig --verify ${RSTUDIO_PKG} && \
                                      gdebi -n ${RSTUDIO_PKG} && \
                                      rm -f ${RSTUDIO_PKG} && \
                                      echo '/opt/conda/envs/r-bio/bin/R' > /etc/ld.so.conf.d/r.conf && /sbin/ldconfig -v && \
                                      apt-get clean && rm -rf /var/lib/apt/lists/* && \
                                      rm -f /usr/bin/R && \
                                      pip install jupyter-rsession-proxy && \
                                      mkdir -p /etc/rstudio && echo 'auth-minimum-user-id=100' >> /etc/rstudio/rserver.conf && \
                                      ( echo 'http_proxy=${http_proxy-http://web.ucsd.edu:3128}' ; echo 'https_proxy=${https_proxy-http://web.ucsd.edu:3128}' ) >> /opt/conda/envs/r-bio/bin/R/etc/Renviron.site && \
                                      ( echo 'LD_PRELOAD=/opt/k8s-support/lib/libnss_wrapper.so'; echo 'NSS_WRAPPER_PASSWD=/tmp/passwd.wrap'; echo 'NSS_WRAPPER_GROUP=/tmp/group.wrap' ) >> /opt/conda/envs/r-bio/bin/R/etc/Renviron.site && \
									  ipython kernel install --name=r-bio"

# create py-bio conda environment with required python packages 
COPY py-bio.yaml /tmp
RUN conda env create --file /tmp/py-bio.yaml && \
    conda run -n py-bio /bin/bash -c "ipython kernel install --name=py-bio"

# Venn Diagrams
RUN conda install --quiet --yes matplotlib-venn
RUN python3 -m pip install matplotlib-venn

# Install GATK
RUN pwd && \
    apt-get update && \
    apt-get install --yes default-jdk && \
    cd /opt && \
    wget -q https://github.com/broadinstitute/gatk/releases/download/4.1.4.1/gatk-4.1.4.1.zip && \
    unzip -q gatk-4.1.4.1.zip && \
    ln -s /opt/gatk-4.1.4.1/gatk /usr/bin/gatk && \
    rm gatk-4.1.4.1.zip && \
    cd /opt/gatk-4.1.4.1 && \
    ls -al  && \
    cd /home/jovyan

# install vcftools
RUN apt-get install --yes build-essential autoconf pkg-config zlib1g-dev && \
    cd /tmp && \
    wget -q -O vcftools.tar.gz https://github.com/vcftools/vcftools/releases/download/v0.1.16/vcftools-0.1.16.tar.gz && \
#    ls -al && \
    tar -xvf vcftools.tar.gz && \
    cd vcftools-0.1.16 && \
#    ls -al && \
    ./autogen.sh && \
    ./configure && \
    make && \
    make install && \
    rm -f /tmp/vcftools.tar.gz

# install samtools
RUN apt-get install --yes ncurses-dev libbz2-dev liblzma-dev && \
    cd /opt && \
    wget -q https://github.com/samtools/samtools/releases/download/1.10/samtools-1.10.tar.bz2 && \
    tar xvfj samtools-1.10.tar.bz2 && \
    cd samtools-1.10 && \
    ./configure && \
    make && \
    make install

# install bcftools
RUN apt-get install --yes ncurses-dev libbz2-dev liblzma-dev && \
    cd /opt && \
    wget -q https://github.com/samtools/bcftools/releases/download/1.10.2/bcftools-1.10.2.tar.bz2 && \
    tar xvfj bcftools-1.10.2.tar.bz2 && \
    cd bcftools-1.10.2 && \
    ./configure && \
    make && \
    make install

# install htslib
RUN apt-get install --yes ncurses-dev libbz2-dev liblzma-dev && \
    cd /opt && \
    wget -q https://github.com/samtools/htslib/releases/download/1.10.2/htslib-1.10.2.tar.bz2 && \
    tar xvfj htslib-1.10.2.tar.bz2 && \
    cd htslib-1.10.2 && \
    ./configure && \
    make && \
    make install

# Install TrimGalore and cutadapt
RUN wget http://www.bioinformatics.babraham.ac.uk/projects/trim_galore/trim_galore_v0.4.1.zip -P /tmp/ && \
    unzip /tmp/trim_galore_v0.4.1.zip && \
    rm /tmp/trim_galore_v0.4.1.zip && \
    mv trim_galore_zip /opt/

RUN curl https://bootstrap.pypa.io/get-pip.py -o get-pip.py && \
    python2 get-pip.py && \
    python2 -m pip install Cython

# path /opt/conda/bin/cutadapt
RUN python3 -m pip install --upgrade cutadapt

# FastQC 
RUN wget http://www.bioinformatics.babraham.ac.uk/projects/fastqc/fastqc_v0.11.5.zip -P /tmp && \
    unzip /tmp/fastqc_v0.11.5.zip && \
    mv FastQC /opt/ && \
    chmod 755 /opt/FastQC/fastqc && \
    rm -rf /tmp/fastqc_*

# STAR
RUN wget https://github.com/alexdobin/STAR/archive/2.5.2b.zip -P /tmp && \
    unzip /tmp/2.5.2b.zip && \
    mv STAR-* /opt/ && \
    rm -rf /tmp/*.zip

# Picard
RUN wget http://downloads.sourceforge.net/project/picard/picard-tools/1.88/picard-tools-1.88.zip -P /tmp && \
    unzip /tmp/picard-tools-1.88.zip && \
    mv picard-tools-* /opt/ && \
    rm /tmp/picard-tools-1.88.zip

# SRA Tools
RUN wget https://ftp-trace.ncbi.nlm.nih.gov/sra/sdk/2.10.8/sratoolkit.2.10.8-centos_linux64.tar.gz -P /tmp && \
    tar xvf /tmp/sratoolkit* && \
    mv sratoolkit* /opt/ && \
    rm -rf /tmp/*.tar.gz

RUN wget https://github.com/pachterlab/kallisto/releases/download/v0.42.4/kallisto_linux-v0.42.4.tar.gz -P /tmp && \
    tar -xvf /tmp/kallisto_linux-v0.42.4.tar.gz && \
    mv kallisto_* /opt/ && \
    rm /tmp/kallisto_linux-v0.42.4.tar.gz


# set r-bio as default
COPY run_jupyter.sh /
RUN chmod +x /run_jupyter.sh

USER $NB_USER
