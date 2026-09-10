#!/usr/bin/env bash
set -eo pipefail

# --- helper: source scripts safely even under 'set -u' ---
#safe_source() {
#  set +u
#  # shellcheck disable=SC1090
#  source "$1"
#  set -u
#}


LOG_DIR=/tmp
SIM_LOG="$LOG_DIR/sim.log"
SPAWN_LOG="$LOG_DIR/spawn.log"
DRIVER_LOG="$LOG_DIR/driver.log"
CLIENT_LOG="$LOG_DIR/gzclient.log"

# 1) Source environments
source /opt/ros/humble/setup.bash
if [ -f /ros2_ws/install/setup.bash ]; then
  source /ros2_ws/install/setup.bash
fi

# 2) Env for TB3 + Gazebo in VNC/Xvfb
export TURTLEBOT3_MODEL=${TURTLEBOT3_MODEL:-burger}
export GAZEBO_PLUGIN_PATH=/opt/ros/humble/lib:${GAZEBO_PLUGIN_PATH:-}
export GAZEBO_MODEL_PATH=/opt/ros/humble/share/turtlebot3_gazebo/models:${GAZEBO_MODEL_PATH:-}
export GZ_SIM_RESOURCE_PATH=/ros2_ws/install/turtlebot3_gazebo/share/turtlebot3_gazebo/models:${GZ_SIM_RESOURCE_PATH:-}
export LIBGL_ALWAYS_SOFTWARE=1
export QT_X11_NO_MITSHM=1
# optionally lower GL if gzclient crashes in your environment:
# export MESA_GL_VERSION_OVERRIDE=3.3

WORLD=/opt/ros/humble/share/turtlebot3_gazebo/worlds/turtlebot3_world.world
MODEL=/opt/ros/humble/share/turtlebot3_gazebo/models/turtlebot3_${TURTLEBOT3_MODEL}/model.sdf

echo "[run_tb3_sim] Launching gzserver with ROS plugins..." | tee -a "$SIM_LOG"
# 3) Start gzserver WITH plugins (this creates /spawn_entity)
setsid bash -lc "gzserver --verbose -s libgazebo_ros_init.so -s libgazebo_ros_factory.so \"$WORLD\" >> \"$SIM_LOG\" 2>&1" &

# 4) Wait until /spawn_entity exists
echo "[run_tb3_sim] Waiting for /spawn_entity service..." | tee -a "$SPAWN_LOG"
for i in {1..60}; do
  if ros2 service list | grep -q '/spawn_entity'; then
    echo "[run_tb3_sim] /spawn_entity available" | tee -a "$SPAWN_LOG"
    break
  fi
  sleep 0.5
  if [ $i -eq 60 ]; then
    echo "[run_tb3_sim] ERROR: /spawn_entity not found after timeout" | tee -a "$SPAWN_LOG"
    exit 1
  fi
done

# 5) Spawn the robot
echo "[run_tb3_sim] Spawning TurtleBot3 ($TURTLEBOT3_MODEL)..." | tee -a "$SPAWN_LOG"
ros2 run gazebo_ros spawn_entity.py \
  -entity burger \
  -file "$MODEL" \
  -x -2.0 -y -0.5 -z 0.01 >> "$SPAWN_LOG" 2>&1

# 6) Start your bump-and-go driver
echo "[run_tb3_sim] Starting bump_and_go driver..." | tee -a "$DRIVER_LOG"
setsid bash -lc "ros2 run bump_and_go_pkg driver >> \"$DRIVER_LOG\" 2>&1" &

# 7) Optionally start the GUI (gzclient). Toggle with env GUI=1
if [ "${GUI:-1}" = "1" ]; then
  echo "[run_tb3_sim] Starting gzclient GUI..." | tee -a "$CLIENT_LOG"
  setsid bash -lc "gzclient --verbose >> \"$CLIENT_LOG\" 2>&1" &
fi

echo "[run_tb3_sim] All set. Logs: $SIM_LOG | $SPAWN_LOG | $DRIVER_LOG | $CLIENT_LOG"
