# =========================================================
# Ubuntu MATE Desktop + noVNC + ROS 2 Humble + TurtleBot3
# VSCodium + Firefox, with workspace prebuilt
# Base: OSRF Humble desktop
# =========================================================
FROM osrf/ros:humble-desktop

ENV DEBIAN_FRONTEND=noninteractive
ENV ROS_DISTRO=humble
# Avoid WSL prompt in Codium launcher
ENV DONT_PROMPT_WSL_INSTALL=1

# Use bash in RUN steps for 'source'
SHELL ["/bin/bash", "-lc"]

# ---------------------------------------------------------
# 1) Base upgrade
# ---------------------------------------------------------
RUN apt-get update -q && \
    apt-get full-upgrade -y && \
    apt-get autoclean -y && \
    apt-get autoremove -y && \
    rm -rf /var/lib/apt/lists/*

# ---------------------------------------------------------
# 2) Desktop, VNC stack, utilities
# ---------------------------------------------------------
RUN apt-get update -q && \
    apt-get install -y --no-install-recommends \
      ubuntu-mate-desktop dbus-x11 mate-terminal terminator \
      tigervnc-standalone-server tigervnc-common tigervnc-tools \
      supervisor gosu tini \
      git curl wget xz-utils ca-certificates \
      python3-pip python3-full build-essential \
      bash-completion locales tzdata sudo \
      # Electron/GTK deps for Codium/Firefox rendering in VNC
      libnss3 libxkbfile1 libxss1 libxshmfence1 libgbm1 libdrm2 libxdamage1 \
      libasound2 libnotify4 libxtst6 libxrandr2 libx11-xcb1 libsecret-1-0 libgtk-3-0 \
      desktop-file-utils && \
    apt-get autoclean -y && \
    apt-get autoremove -y && \
    rm -rf /var/lib/apt/lists/*

# ---------------------------------------------------------
# 3) noVNC (stable) + websockify
# Served at :6080; proxies to VNC at :5901
# ---------------------------------------------------------
RUN git clone --branch v1.4.0 --depth=1 https://github.com/novnc/noVNC.git /usr/lib/novnc && \
    git clone --branch v0.11.0 --depth=1 https://github.com/novnc/websockify.git /usr/lib/novnc/utils/websockify && \
    ln -s /usr/lib/novnc/vnc.html /usr/lib/novnc/index.html

# ---------------------------------------------------------
# 4) Firefox (official tarball; avoids Snap)
# ---------------------------------------------------------
RUN wget -qO /tmp/firefox.tar.xz "https://download.mozilla.org/?product=firefox-latest&os=linux64&lang=en-US" && \
    mkdir -p /opt/firefox && \
    tar -xJf /tmp/firefox.tar.xz -C /opt/firefox --strip-components=1 && \
    ln -sf /opt/firefox/firefox /usr/local/bin/firefox && \
    # Install icons so Icon=firefox works
    install -d /usr/share/icons/hicolor/{32x32,48x48,64x64,128x128}/apps && \
    install -m 644 /opt/firefox/browser/chrome/icons/default/default32.png  /usr/share/icons/hicolor/32x32/apps/firefox.png && \
    install -m 644 /opt/firefox/browser/chrome/icons/default/default48.png  /usr/share/icons/hicolor/48x48/apps/firefox.png && \
    install -m 644 /opt/firefox/browser/chrome/icons/default/default64.png  /usr/share/icons/hicolor/64x64/apps/firefox.png && \
    install -m 644 /opt/firefox/browser/chrome/icons/default/default128.png /usr/share/icons/hicolor/128x128/apps/firefox.png && \
    gtk-update-icon-cache -f /usr/share/icons/hicolor || true && \
    rm -f /tmp/firefox.tar.xz

# ---------------------------------------------------------
# 5) VSCodium (apt repo) and patch WSL guard
# ---------------------------------------------------------
RUN wget -qO /usr/share/keyrings/vscodium-archive-keyring.asc \
      https://gitlab.com/paulcarroty/vscodium-deb-rpm-repo/-/raw/master/pub.gpg && \
    echo 'deb [signed-by=/usr/share/keyrings/vscodium-archive-keyring.asc] https://paulcarroty.gitlab.io/vscodium-deb-rpm-repo/debs vscodium main' \
      > /etc/apt/sources.list.d/vscodium.list && \
    apt-get update -q && \
    apt-get install -y --no-install-recommends codium && \
    # Make sure codium is on PATH (also in case launcher uses this path)
    ln -sf /usr/share/codium/bin/codium /usr/local/bin/codium && \
    # Be tolerant to upstream script changes
    sed -i 's/^.*Windows Subsystem for Linux.*$/# removed WSL guard/' /usr/share/codium/bin/codium || true && \
    sed -i 's/\<is-wsl\>/is-wsl-disabled/g' /usr/share/codium/bin/codium || true && \
    rm -rf /var/lib/apt/lists/*

# ---------------------------------------------------------
# 6) ROS 2 extras: TurtleBot3 + Gazebo ROS pkgs
# ---------------------------------------------------------
RUN apt-get update -q && \
    apt-get install -y --no-install-recommends \
      ros-humble-turtlebot3 \
      ros-humble-turtlebot3-gazebo \
      ros-humble-turtlebot3-description \
      ros-humble-gazebo-ros-pkgs \
      python3-colcon-common-extensions && \
    apt-get autoclean -y && \
    apt-get autoremove -y && \
    rm -rf /var/lib/apt/lists/*

# ---------------------------------------------------------
# 7) Gazebo/TB3 env vars (models, plugins, resources)
# ---------------------------------------------------------
ENV TURTLEBOT3_MODEL=burger
# Gazebo/ROS plugins
ENV GAZEBO_PLUGIN_PATH=/opt/ros/${ROS_DISTRO}/lib:$GAZEBO_PLUGIN_PATH
# Model paths (system TB3 + workspace TB3 after build)
ENV GAZEBO_MODEL_PATH=/opt/ros/${ROS_DISTRO}/share/turtlebot3_gazebo/models:$GAZEBO_MODEL_PATH
# Gazebo resource path so worlds/models resolve from your built workspace
ENV GZ_SIM_RESOURCE_PATH=/ros2_ws/install/turtlebot3_gazebo/share/turtlebot3_gazebo/models:$GZ_SIM_RESOURCE_PATH
# Software GL is safer in virtual/Xvfb
ENV MESA_GL_VERSION_OVERRIDE=4.1
ENV LIBGL_ALWAYS_SOFTWARE=1

# ---------------------------------------------------------
# 8) Copy and build ROS 2 workspace (bakes TB3 models into /ros2_ws/install)
# Make sure your host has: ros2_ws/src/<your packages>
# ---------------------------------------------------------
WORKDIR /ros2_ws
COPY ./ros2_ws/src ./src
RUN source /opt/ros/${ROS_DISTRO}/setup.bash && \
    colcon build --symlink-install

# ---------------------------------------------------------
# 9) Entry point script (you already have it in the project root)
# It should start: Xvnc on :1, websockify on :6080, MATE session, and
# create .desktop icons for Firefox/Codium/Terminator if desired.
# ---------------------------------------------------------
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Helper to start Gazebo + spawn TB3 + driver
COPY run_tb3_sim.sh /usr/local/bin/run_tb3_sim.sh
RUN chmod +x /usr/local/bin/run_tb3_sim.sh


EXPOSE 6080
ENTRYPOINT ["/bin/bash", "/usr/local/bin/entrypoint.sh"]
