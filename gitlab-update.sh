#!/bin/bash

# Shiny colours.
CDEFAULT='\e[0m'
CINFO='\e[1;32m'
CWARN='\e[1;33m'
CERROR='\e[1;31m\e[1m'
CINPUT='\e[1;36m'
# Overwrite with formatting.
CINFO="${CINFO}[INFO]${CDEFAULT}"
CWARN="${CWARN}[WARNING]${CDEFAULT}"
CERROR="${CERROR}[ERROR]${CDEFAULT}"
CINPUT="${CINPUT}[INPUT]${CDEFAULT}"

# Pause On Error
poe() {
  if [ $1 -ne 0 ]
  then
    echo -e "${CERROR} The last command did not return 0."
    echo -e "${CINPUT} Press ^C to exit or enter to continue."
    read
  fi
}

_1_backup() {
    echo -e "${CINFO} Creating backup..."
    cd $GIT_DIR/gitlab
    bundle exec rake gitlab:backup:create
    poe $?
}

_2_update_repo() {
    git fetch
    poe $?

    if ! git rev-parse -q --verify remotes/origin/$NEW_VER
    then
        echo -e "${CERROR} Specified branch $NEW_VER does not exist."
        exit 1
    fi

    git checkout -- db/schema.rb Gemfile.lock
    if [ "$PATCH" = "true" ]
    then
        git pull
        poe $?
    else
        git checkout $NEW_VER
        poe $?
    fi
}

_3_update_gitlab() {
    echo -e "${CINFO} Updating bundles..."
    bundle install --without postgres development test --deployment
    poe $?

    echo -e "${CINFO} Cleaning up old bundles..."
    bundle clean
    poe $?

    echo -e "${CINFO} Running database migrations..."
    bundle exec rake db:migrate
    poe $?

    echo -e "${CINFO} Cleanup assets and cache..."
    bundle exec rake assets:clean assets:precompile cache:clear
    poe $?
}

_4_update_workhorse() {
    echo -e "${CINFO} Updating gitlab-workhorse..."
    cd $GIT_DIR/gitlab-workhorse
    git fetch
    poe $?
    WORKHORSE_VERSION=$(cat $GIT_DIR/gitlab/GITLAB_WORKHORSE_VERSION)
    poe $?
    git checkout -B $WORKHORSE_VERSION
    poe $?
    make 
    poe $?
}

_5_update_shell() {
    echo -e "${CINFO} Updating gitlab-shell..."
    cd $GIT_DIR/gitlab-shell
    git fetch
    poe $?
    SHELL_VERSION=$(cat $GIT_DIR/gitlab/GITLAB_SHELL_VERSION)
    poe $?
    git checkout -B v${SHELL_VERSION}
    poe $?
}

_6_update_config() {
    if [ "$PATCH" = "true" ]; then return; fi

    gitlab_config
    nginx_config
    init_script
    echo -e "${CWARN} Please apply them appropriately."
}

gitlab_config() {
    echo -e "${CINFO} Checking for GitLab configuration changes..."
    cd $GIT_DIR/gitlab
    git diff \
        origin/$CUR_VER:config/gitlab.yml.example \
        origin/$NEW_VER:config/gitlab.yml.example
}

nginx_config() {
    echo -e "${CINFO} Checking for Nginx configuration changes..."
    cd $GIT_DIR/gitlab
    git diff \
        origin/$CUR_VER:lib/support/nginx/gitlab-ssl \
        origin/$NEW_VER:lib/support/nginx/gitlab-ssl
}

init_script() {
    echo -e "${CINFO} Checking for changes in init script..."
    cd $GIT_DIR/gitlab
    git diff \
        origin/$CUR_VER:lib/support/init.d/gitlab \
        origin/$NEW_VER:lib/support/init.d/gitlab
}

run() {
    _1_backup
    _2_update_repo
    _3_update_gitlab
    _4_update_workhorse
    _5_update_shell
    _6_update_config
}

WHOAMI=$(whoami)
WHOAMI='git'
if [ "$WHOAMI" != 'git' ]
then
    echo -e "${CWARN} Please run this script as the 'git' user."
    exit 1
fi

GIT_DIR=$(eval echo ~$USER)
RAILS_ENV=production
cd $GIT_DIR/gitlab
CUR_VER=$(git rev-parse --abbrev-ref HEAD)

echo -e "${CINFO} What version would you like to update to?"
echo -en "${CINPUT} Please specify a git branch (e.g. 8-15-stable): "
read NEW_VER

if [ "$CUR_VER" = "$NEW_VER" ]
then
    echo -e "${CWARN} New version is same as current version. Assuming you want to patch."
    PATCH="true"
fi

while true; do
    echo -en "${CINPUT} Would you like to continue? [y/N] "
    read YN
    case $YN in
        [Yy]* ) run; break;;
        * ) exit;;
    esac
done

