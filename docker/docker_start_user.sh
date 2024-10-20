#!/usr/bin/env bash

function _create_user_account() {
  local user_name="$1"
  local uid="$2"
  local group_name="$3"
  local gid="$4"
  addgroup --gid "${gid}" "${group_name}"

  adduser --disabled-password --force-badname --gecos '' \
    "${user_name}" --uid "${uid}" --gid "${gid}" # 2>/dev/null

  usermod -aG sudo "${user_name}"
  echo "%sudo   ALL=(ALL:ALL) NOPASSWD: ALL" >> /etc/sudoers
}

function setup_user_bashrc() {
  local uid="$1"
  local gid="$2"
  local user_home="/home/$3"
  cp -rf /etc/skel/.{profile,bash*} "${user_home}"
  cp -rf /root/.local  "${user_home}"/
  cp /root/.bashrc "${user_home}"/
  # Set user files ownership to current user, such as .bashrc, .profile, etc.
  echo "setup permission"
  chown -R "${uid}:${gid}" "${user_home}"
  chown -R "${uid}:${gid}" "/usr/local/rustup"
  chown -R "${uid}:${gid}" "/usr/local/cargo"
  sed -i 's|#force_color_prompt=yes|force_color_prompt=yes|' /"${user_home}"/.bashrc
  echo "${uid}:${gid}"
}

function setup_user_account_if_not_exist() {
  local user_name="$1"
  local uid="$2"
  local group_name="$3"
  local gid="$4"
  if grep -q "^${user_name}:" /etc/passwd; then
    echo "User ${user_name} already exist. Skip setting user account."
    return
  fi
  _create_user_account "$@"
  setup_user_bashrc "${uid}" "${gid}" "${user_name}"
}

##===================== Main ==============================##
function main() {
  local user_name="$1"
  local uid="$2"
  local group_name="$3"
  local gid="$4"

  if [ "${uid}" != "${gid}" ]; then
    echo "Warning: uid(${uid}) != gid(${gid}) found."
  fi
  if [ "${user_name}" != "${group_name}" ]; then
    echo "Warning: user_name(${user_name}) != group_name(${group_name}) found."
  fi
  setup_user_account_if_not_exist "$@"
  chown -R "${uid}:${gid}" /workspace
}

main "${DOCKER_USER}" "${DOCKER_USER_ID}" "${DOCKER_GRP}" "${DOCKER_GRP_ID}"
