#!/usr/bin/env bash
set -euo pipefail

# --- helper: source scripts safely even under 'set -u' ---
#safe_source() {
#  set +u
  # shellcheck disable=SC1090
#  source "$1"
#  set -u
#}

# ========== 0) User setup ==========
: "${USER:=root}"
: "${PASSWORD:=ubuntu}"

HOME_DIR="/root"
if [ "$USER" != "root" ]; then
  echo "* Creating user: $USER"
  useradd --create-home --shell /bin/bash --user-group --groups adm,sudo "$USER"
  echo "$USER ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers
  echo "$USER:${PASSWORD}" | chpasswd
  HOME_DIR="/home/$USER"
  # copy some defaults if they exist
  cp -r /root/.config "$HOME_DIR" 2>/dev/null || true
  chown -R "$USER:$USER" "$HOME_DIR"
fi

# ========== 1) ROS environment convenience ==========
# Make every shell "ROS-ready"
BASHRC="$HOME_DIR/.bashrc"
grep -F "source /opt/ros/${ROS_DISTRO}/setup.bash" "$BASHRC" >/dev/null 2>&1 || \
  echo "source /opt/ros/${ROS_DISTRO}/setup.bash" >> "$BASHRC"
chown "$USER:$USER" "$BASHRC"

# ========== 2) VNC password & xstartup ==========
VNC_PASS="${PASSWORD}"
mkdir -p "$HOME_DIR/.vnc"
# Set VNC password file
echo "$VNC_PASS" | vncpasswd -f > "$HOME_DIR/.vnc/passwd"
chmod 600 "$HOME_DIR/.vnc/passwd"
chown -R "$USER:$USER" "$HOME_DIR/.vnc"

# VNC xstartup to start the full Ubuntu MATE session
cat > "$HOME_DIR/.vnc/xstartup" <<'EOF'
#!/bin/sh
unset DBUS_SESSION_BUS_ADDRESS
unset SESSION_MANAGER
mate-session
EOF
chmod 755 "$HOME_DIR/.vnc/xstartup"
chown "$USER:$USER" "$HOME_DIR/.vnc/xstartup"

# ========== 3) Robust VNC runner (cleans stale X locks) ==========
cat > "$HOME_DIR/.vnc/vnc_run.sh" <<'EOF'
#!/bin/sh
# Clean stale locks (helps after crashes or docker commit)
[ -e /tmp/.X1-lock ] && rm -f /tmp/.X1-lock
[ -e /tmp/.X11-unix/X1 ] && rm -f /tmp/.X11-unix/X1
mkdir -p /tmp/.X11-unix && chmod 1777 /tmp/.X11-unix

# Launch TigerVNC server on :1 (1920x1080@24bpp; adjust as you like)
if [ "$(uname -m)" = "aarch64" ]; then
  LD_PRELOAD=/lib/aarch64-linux-gnu/libgcc_s.so.1 vncserver :1 -fg -geometry 1920x1080 -depth 24
else
  vncserver :1 -fg -geometry 1920x1080 -depth 24
fi
EOF
chmod +x "$HOME_DIR/.vnc/vnc_run.sh"
chown "$USER:$USER" "$HOME_DIR/.vnc/vnc_run.sh"

# ========== 4) Supervisord config (VNC + noVNC) ==========
mkdir -p /etc/supervisor/conf.d
cat > /etc/supervisor/conf.d/supervisord.conf <<EOF
[supervisord]
nodaemon=true
user=root
logfile=/var/log/supervisor/supervisord.log
pidfile=/var/run/supervisord.pid

[program:vnc]
command=/usr/sbin/gosu $USER bash $HOME_DIR/.vnc/vnc_run.sh
autostart=true
autorestart=true
priority=10
stdout_logfile=/var/log/supervisor/vnc.log
stderr_logfile=/var/log/supervisor/vnc.err

[program:novnc]
command=/usr/sbin/gosu $USER bash -lc "/usr/lib/novnc/utils/novnc_proxy --vnc localhost:5901 --listen 6080"
autostart=true
autorestart=true
priority=20
stdout_logfile=/var/log/supervisor/novnc.log
stderr_logfile=/var/log/supervisor/novnc.err
EOF

# --- Desktop icons and autostart (no DBus needed) ---
USER_HOME="$(eval echo ~"$USER")"
DESKTOP_DIR="$USER_HOME/Desktop"
AUTOSTART_DIR="$USER_HOME/.config/autostart"
mkdir -p "$DESKTOP_DIR" "$AUTOSTART_DIR"

# Firefox icon
cat > "$DESKTOP_DIR/firefox.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=Firefox
Comment=Browse the Web
Exec=firefox %u
Icon=firefox
Categories=Network;WebBrowser;
Terminal=false
EOF

# VSCodium icon
cat > "$DESKTOP_DIR/codium.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=VSCodium
Comment=Code Editing. Redefined.
#Exec=codium --no-sandbox --unity-launch %F
Exec=env DONT_PROMPT_WSL_INSTALL=1 LIBGL_ALWAYS_SOFTWARE=1 codium --no-sandbox --disable-gpu %F
#Exec=codium --no-sandbox %F
Icon=vscodium
Categories=Development;IDE;TextEditor;
Terminal=false
EOF

# Terminator icon
cat > "$DESKTOP_DIR/terminator.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=Terminator
Comment=Multiple terminals in one window
Exec=terminator
Icon=utilities-terminal
Categories=Utility;TerminalEmulator;
Terminal=false
EOF

# (Optional) autostart a terminal so you always have one
cat > "$AUTOSTART_DIR/terminator.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=Terminator
Exec=terminator
X-GNOME-Autostart-enabled=true
EOF


# --- Ensure Caja manages the desktop so icons appear ---
mkdir -p "$HOME/.config/autostart"
cat > "$HOME/.config/autostart/caja-desktop.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=Caja Desktop
Exec=caja --force-desktop
X-GNOME-Autostart-enabled=true
EOF



# --- Fix permissions for Caja / MATE settings ---
mkdir -p "$USER_HOME/.config/dconf"
chown -R "$USER:$USER" "$USER_HOME/.config"
chmod -R u+rw "$USER_HOME/.config"

# Make them executable and owned by the login user
chmod +x "$DESKTOP_DIR/"*.desktop "$AUTOSTART_DIR/"*.desktop
chown -R "$USER:$USER" "$DESKTOP_DIR" "$AUTOSTART_DIR"

echo "============================================================================================"
echo "Desktop is starting under user: $USER (password: ${PASSWORD})"
echo "Open http://localhost:6080 in your browser to access the Ubuntu MATE desktop."
echo "If you need a different resolution, edit $HOME_DIR/.vnc/vnc_run.sh (geometry)."
echo "============================================================================================"


# ========== 5) Start supervisord via tini ==========
exec /bin/tini -- supervisord -n -c /etc/supervisor/conf.d/supervisord.conf
