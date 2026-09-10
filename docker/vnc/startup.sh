#!/bin/bash
set -e

# Prepara el entorno ROS para cualquier terminal que se abra en el escritorio
echo "source /opt/ros/humble/setup.bash" >> /home/user/.bashrc
echo "source /ros2_ws/install/setup.bash" >> /home/user/.bashrc

# Configura la contraseña de VNC y la resolución de pantalla
export VNC_PASSWORD=${VNC_PASSWORD:-password}
export VNC_RESOLUTION=${VNC_RESOLUTION:-1920x1080}

# Crea el directorio y los archivos de configuración de VNC
mkdir -p /home/user/.vnc
echo "$VNC_PASSWORD" | vncpasswd -f > /home/user/.vnc/passwd
chmod 600 /home/user/.vnc/passwd

echo "#!/bin/bash
xrdb \$HOME/.Xresources
mate-session &" > /home/user/.vnc/xstartup
chmod +x /home/user/.vnc/xstartup

# --- ¡LA CORRECCIÓN CLAVE ESTÁ AQUÍ! ---
# Lanza el servidor VNC en PRIMER PLANO (-fg)
# Ya no necesitamos el comando 'tail -f'.
vncserver :0 -geometry ${VNC_RESOLUTION} -depth 24 -rfbport 5900 -fg
