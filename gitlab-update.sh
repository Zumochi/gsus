#!/bin/bash

# Pause On Error
poe() {
  if [ $1 -ne 0 ]
  then
    echo -e "\e[31m\e[1mThe last command did not return 0."
    echo -e "\e[0mPress ^C to exit or enter to continue."
    read
  fi
}

_1_backup() {
    echo "Creating backup..."
    cd $GIT_DIR/gitlab
    bundle exec rake gitlab:backup:create
    poe $?
}

_2_update_repo() {
    git fetch
    poe $?

    if ! git rev-parse -q --verify remotes/origin/$NEW_VER
    then
        echo -e "\e[31m\e[1mSpecified branch $NEW_VER does not exist."
        exit 1
    fi

    git checkout -- db/schema.rb Gemfile.lock
    if $PATCH
    then
        git pull
        poe $?
    else
        git checkout $NEW_VER
        poe $?
    fi
}

_3_update_gitlab() {
    echo "Updating bundles..."
    bundle install --without postgres development test --deployment
    poe $?

    echo "Cleaning up old bundles..."
    bundle clean

    echo "Running database migrations..."
    bundle exec rake db:migrate
    poe $?

    echo "Cleanup assets and cache"
    bundle exec rake assets:clean assets:precompile cache:clear
    poe $?
}

_4_update_workhorse() {
    echo "Updating gitlab-workhorse..."
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
    echo "Updating gitlab-shell..."
    cd $GIT_DIR/gitlab-shell
    git fetch
    poe $?
    SHELL_VERSION=$(cat $GIT_DIR/gitlab/GITLAB_SHELL_VERSION)
    poe $?
    git checkout -B v${SHELL_VERSION}
    poe $?
}

_6_update_config() {
    if $PATCH; then return fi

    gitlab_config
    nginx_config
    init_script
    echo "Please apply them appropriately."
}

gitlab_config() {
    echo "Checking for GitLab configuration changes..."
    cd $GIT_DIR/gitlab
    git diff \
        origin/$CUR_VER:config/gitlab.yml.example \
        origin/$NEW_VER:config/gitlab.yml.example
}

nginx_config() {
    echo "Checking for Nginx configuration changes..."
    cd $GIT_DIR/gitlab
    git diff \
        origin/$CUR_VER:lib/support/nginx/gitlab-ssl \
        origin/$NEW_VER:lib/support/nginx/gitlab-ssl
}

init_script() {
    echo "Checking for changes in init script..."
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
if [ $(whoami) != 'git' ]
then
    echo "Please run this script as the 'git' user."
    exit 1
fi

GIT_DIR=$(eval echo ~$USER)
RAILS_ENV=production
cd $GIT_DIR/gitlab
CUR_VER=$(git rev-parse --abbrev-ref HEAD)

echo "What version would you like to update to?"
echo -n "Please specify a git branch (e.g. 8-15-stable): "
read NEW_VER

if [ $CUR_VER = $NEW_VER ]
then
    echo "New version is same as current version. Assuming you want to patch."
    PATCH=1
fi

while true; do
    read -p "Would you like to continue? [y/N]" yn
    case $yn in
        [Yy]* ) run; break;;
        * ) exit;;
    esac
done

