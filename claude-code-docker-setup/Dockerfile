# syntax=docker/dockerfile:1.7
ARG NODE_IMAGE=node:24.18.0-bookworm-slim@sha256:6f7b03f7c2c8e2e784dcf9295400527b9b1270fd37b7e9a7285cf83b6951452d
ARG PYTHON_IMAGE=python:3.12.13-slim-bookworm@sha256:d50fb7611f86d04a3b0471b46d7557818d88983fc3136726336b2a4c657aa30b
ARG STATA_IMAGE=dataeditors/stata19-se-i-python@sha256:1691fce6250011bef77cb64df58316bc72ed82b9791456e4b804832d9bfd747d
ARG STATA_EDITION=se
ARG CODEX_VERSION=0.156.1
ARG CLAUDE_VERSION=2.1.281

FROM --platform=linux/amd64 ${NODE_IMAGE} AS node-runtime

FROM --platform=linux/amd64 ${NODE_IMAGE} AS credential-proxy
WORKDIR /opt/proxy
COPY credential-proxy.mjs codex-egress-proxy.mjs /opt/proxy/
RUN chmod 0555 /opt/proxy/credential-proxy.mjs /opt/proxy/codex-egress-proxy.mjs
USER node
ENTRYPOINT ["node", "/opt/proxy/credential-proxy.mjs"]

FROM --platform=linux/amd64 ${STATA_IMAGE} AS stata

FROM --platform=linux/amd64 ${PYTHON_IMAGE} AS agent
ARG STATA_EDITION
ARG CODEX_VERSION
ARG CLAUDE_VERSION
LABEL org.opencontainers.image.title="Unified research agents container" \
      org.opencontainers.image.description="Hardened containerized research environment"

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8 \
    EDITOR=nano \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PIP_NO_CACHE_DIR=1 \
    DISABLE_AUTOUPDATER=1

# The agent stage uses the official Python 3.12 image. Copy the pinned Node
# runtime from the matching Debian Bookworm Node stage so Python remains the
# primary runtime while npm-installed agent CLIs continue to work.
COPY --from=node-runtime /usr/local/ /usr/local/
COPY --from=node-runtime /opt/ /opt/

# Debian mirrors and intermediary caches can briefly disagree about package
# metadata. Retry from a clean apt cache while preserving hash verification;
# never bypass APT's integrity checks.
RUN set -eux; \
    installed=0; \
    for attempt in 1 2 3; do \
        rm -rf /var/lib/apt/lists/*; \
        rm -f /var/cache/apt/archives/*.deb; \
        if apt-get -o Acquire::Retries=5 -o Acquire::http::No-Cache=true -o Acquire::https::No-Cache=true update \
            && apt-get -o Acquire::Retries=5 -o Acquire::http::No-Cache=true -o Acquire::https::No-Cache=true install -y --no-install-recommends \
        bash ca-certificates git curl wget openssh-client gh jq ripgrep unzip libnss-wrapper bubblewrap socat \
        build-essential gfortran cmake pkg-config \
        libcurl4-openssl-dev libssl-dev libxml2-dev \
        libfontconfig1-dev libharfbuzz-dev libfribidi-dev \
        libfreetype6-dev libpng-dev libtiff-dev libjpeg-dev \
        libgdal-dev libgeos-dev libproj-dev libudunits2-dev \
        libglpk-dev libsodium-dev libsqlite3-dev libnlopt-dev libzmq3-dev \
        libuv1-dev \
        pandoc nano r-base r-base-dev \
        ruby-full ruby-dev libyaml-dev libffi-dev zlib1g-dev libatomic1 \
        libncurses6 libcurl4 locales fontconfig fonts-dejavu-core fonts-liberation \
        texlive-latex-recommended texlive-latex-extra texlive-fonts-recommended \
        texlive-plain-generic texlive-xetex texlive-science texlive-pictures \
        latexmk lmodern ghostscript poppler-utils qpdf; then \
            installed=1; \
            break; \
        fi; \
        printf 'APT install attempt %s failed; clearing caches before retry\n' "$attempt" >&2; \
        sleep $((attempt * 5)); \
    done; \
    test "$installed" -eq 1; \
    localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8; \
    ln -sf /usr/lib/x86_64-linux-gnu/libnss_wrapper.so /usr/local/lib/libnss_wrapper.so; \
    apt-get clean; \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*

RUN python3 -c 'import sys; assert sys.version_info[:2] == (3, 12), sys.version' \
 && python3 -m pip --version \
 && node --version \
 && npm --version \
 && yarn --version

RUN missing=""; \
    for sty in caption pdflscape colortbl makecell multirow upquote \
               pdfpages eso-pic grfext grffile booktabs longtable array float \
               threeparttable threeparttablex ulem wrapfig xcolor tabu setspace \
               geometry hyperref siunitx tikz; do \
        kpsewhich "$sty.sty" >/dev/null 2>&1 || missing="$missing $sty"; \
    done; \
    test -z "$missing" || { echo "Missing LaTeX packages:$missing" >&2; exit 1; }

RUN gem install --no-document bundler:2.6.9 jekyll:4.4.1

COPY requirements-python.txt python-stack-smoke.py /tmp/
RUN python3 -m pip install --no-cache-dir -r /tmp/requirements-python.txt \
 && python3 -m pip check \
 && python3 /tmp/python-stack-smoke.py \
 && rm -f /tmp/requirements-python.txt /tmp/python-stack-smoke.py

# Direct package names are fixed in this Dockerfile. CRAN and apt transitive
# artifacts remain a documented residual supply-chain risk; see SECURITY.md.
RUN printf '%s\n' 'options(repos = c(CRAN = "https://cloud.r-project.org/"), timeout = 600)' >> /etc/R/Rprofile.site
RUN R -e "install.packages(c('tidyverse','data.table','haven','readxl','openxlsx','janitor','lubridate','here','fs','jsonlite','glue','httr2'), Ncpus=parallel::detectCores())" \
 && R -e "install.packages(c('fixest','did','lfe','estimatr','sandwich','clubSandwich','plm','AER','ivreg','rdrobust','DRDID','gsynth','Synth'), Ncpus=parallel::detectCores())" \
 && R -e "if (!requireNamespace('remotes', quietly=TRUE)) install.packages('remotes'); tryCatch(remotes::install_github('synth-inference/synthdid', upgrade='never'), error=function(e) message('synthdid github install skipped: ', conditionMessage(e)))" \
 && R -e "install.packages(c('lme4','survival','caret','randomForest','MASS','Matrix','broom','car'), Ncpus=parallel::detectCores())" \
 && R -e "install.packages(c('modelsummary','stargazer','kableExtra','knitr','rmarkdown','tinytex'), Ncpus=parallel::detectCores())" \
 && R -e "install.packages(c('patchwork','cowplot','ggrepel','ggthemes','viridis','scales','gridExtra'), Ncpus=parallel::detectCores())" \
 && R -e "install.packages(c('parallel','foreach','doParallel','future','devtools','Rcpp','sf','terra'), Ncpus=parallel::detectCores())"

# install.packages() only WARNS when a package fails to build, so the image can
# otherwise ship with silently missing packages (this is how a build shipped
# without a working rmarkdown). Verify the ones the workflow depends on and fail
# the build if any are absent.
RUN set -eu; \
    R -q -e 'options(timeout=3600); need <- c("tidyverse","data.table","haven","fixest","did","DRDID","Synth","modelsummary","kableExtra","knitr","rmarkdown","tinytex","ggplot2","evaluate","xfun","htmltools","bslib","jquerylib","fontawesome","yaml"); miss <- need[!need %in% rownames(installed.packages())]; if (length(miss)) { cat("repairing missing R packages:", paste(miss, collapse=", "), "\n"); install.packages(miss, Ncpus=parallel::detectCores()) } else cat("no repair needed\n")'; \
    R -q -e 'need <- c("tidyverse","data.table","haven","fixest","did","DRDID","Synth","modelsummary","kableExtra","knitr","rmarkdown","tinytex","ggplot2"); miss <- need[!need %in% rownames(installed.packages())]; if (length(miss)) { cat("MISSING R PACKAGES:", paste(miss, collapse=", "), "\n"); quit(status=1) }; cat("R package verification: all present\n")'; \
    if ! command -v pandoc >/dev/null; then echo "MISSING: pandoc (rmarkdown::render needs it)"; exit 1; fi; \
    echo "pandoc verification: present"

# Install IRkernel in the system site library before R_LIBS_USER is defined.
# A project cache mounted at runtime therefore cannot hide the kernel package.
RUN R -e "install.packages('IRkernel', lib='/usr/local/lib/R/site-library')" \
 && R -e "IRkernel::installspec(user=FALSE)" \
 && test -d /usr/local/lib/R/site-library/IRkernel

# Use a high fallback UID rather than the common desktop UID 1000. The
# launchers override it with the invoking host UID/GID so bind-mounted
# files remain owned by the host user.
RUN useradd --uid 10001 --create-home --shell /bin/bash --user-group agent \
 && mkdir -p /workspace /opt/agent \
             /home/agent/R/library /home/agent/.local /home/agent/ado/plus \
 && chown -R 10001:10001 /workspace /home/agent

COPY --from=stata /usr/local/stata /usr/local/stata
RUN chmod -R go-w /usr/local/stata \
 && printf '[nbstata]\nstata_dir = /usr/local/stata\nedition = %s\ngraph_format = png\nsplash = False\n' "${STATA_EDITION}" > /opt/agent/nbstata.conf \
 && python3 -m nbstata.install --sys-prefix \
 && jupyter kernelspec list

COPY container-entrypoint.sh /usr/local/bin/container-entrypoint
COPY github-helper.sh /opt/agent/github-helper
COPY stata-license-helper.sh /opt/agent/stata-license-helper
COPY AGENTS.md /opt/agent/AGENTS.md
COPY AGENTS-locked.md /opt/agent/AGENTS-locked.md
COPY codex-system-config.toml /etc/codex/config.toml
RUN chmod 0555 /usr/local/bin/container-entrypoint /opt/agent/github-helper /opt/agent/stata-license-helper \
 && chmod 0444 /opt/agent/nbstata.conf /opt/agent/AGENTS.md /opt/agent/AGENTS-locked.md \
 && chmod -R a-w /opt/agent /etc/codex/config.toml

RUN npm install -g "@openai/codex@${CODEX_VERSION}" "@anthropic-ai/claude-code@${CLAUDE_VERSION}" \
 && command -v codex && codex --version \
 && command -v claude && claude --version
LABEL org.opencontainers.image.version="codex-${CODEX_VERSION}_claude-${CLAUDE_VERSION}"

ENV HOME=/home/agent \
    R_LIBS_USER=/home/agent/R/library \
    PYTHONUSERBASE=/home/agent/.local \
    STATAPATH=/home/agent/ado \
    PATH=/usr/local/stata:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/home/agent/.local/bin \
    CODEX_HOME=/home/agent/.codex
USER 10001:10001
WORKDIR /workspace
ENTRYPOINT ["/usr/local/bin/container-entrypoint"]
CMD ["bash"]
