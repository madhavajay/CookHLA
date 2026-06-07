FROM mambaorg/micromamba:2.0.5

USER root

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        bash \
        ca-certificates \
        coreutils \
        curl \
        gzip \
    && rm -rf /var/lib/apt/lists/*

RUN micromamba install -y -n base \
        -c conda-forge \
        -c bioconda \
        python=3.10 \
        pandas \
        pyliftover \
        plink \
        tcsh \
        r-base \
        r-data.table \
        openjdk \
        perl \
    && micromamba clean -a -y

ENV PATH=/opt/conda/bin:/opt/CookHLA/dependency:$PATH
ENV MAMBA_DOCKERFILE_ACTIVATE=1

WORKDIR /opt/CookHLA

COPY --chown=$MAMBA_USER:$MAMBA_USER . /opt/CookHLA

RUN chmod +x /opt/CookHLA/dependency/plink \
             /opt/CookHLA/dependency/mach1 \
             /opt/CookHLA/dependency/tcsh \
             /opt/CookHLA/docker/entrypoint.sh \
    && mkdir -p /opt/CookHLA/work/chains \
    && curl -L --fail \
        -o /opt/CookHLA/work/chains/hg38ToHg19.over.chain.gz \
        https://hgdownload.soe.ucsc.edu/goldenPath/hg38/liftOver/hg38ToHg19.over.chain.gz \
    && curl -L --fail \
        -o /opt/CookHLA/work/chains/hg19ToHg18.over.chain.gz \
        https://hgdownload.soe.ucsc.edu/goldenPath/hg19/liftOver/hg19ToHg18.over.chain.gz \
    && chown -R $MAMBA_USER:$MAMBA_USER /opt/CookHLA

USER $MAMBA_USER

ENTRYPOINT ["/opt/CookHLA/docker/entrypoint.sh"]
CMD ["--help"]
