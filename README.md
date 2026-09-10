# ROS2 "Bump and Go" Demo

This project is part of one of the exercises of the [ACM SIGSOFT Summer School for Software Engineering](https://scivenia.com/en/event/acm-sigsoft-summer-school-for-software-engineering-in-robotic) for Robotics that took place in June 2025 at TU Delft. [Prof. Dr. Jose Miguel Guerrero](https://github.com/jmguerreroh) presented it. 

The project provides a simple demonstration of a reactive navigation algorithm known as "Bump and Go." It shows a simulated [TurtleBot3](https://www.turtlebot.com/turtlebot3/) robot in a TurtleBot3 world, controlled by a ROS2 node written in Python. The robot uses its LIDAR sensor to detect obstacles. When the frontal distance is detected to be less than a pre-defined threshold, the robot rotates for 2 seconds and then continues moving forward until it bumps into the next object.

![Demostración del Robot en Acción](videos/bump_and_go.gif)

## Features

- **Algorithm:** Simple "Bump and Go" logic.
- **Robot:** TurtleBot3 Burger.
- **Environment:** TurtleBot3 world.
- **Framework:** ROS2 Humble.
- **Simulator:** Gazebo.
- **Visualization:** RViz2.

---

## Prerequisites

**Install Docker Engine:**
    Follow the official installation guide for your operating system.
    - [Docker installation instructions for Ubuntu](https://docs.docker.com/engine/install/ubuntu/)

---

## How to Run the Demo

The process is very straightforward and consists of 3 steps.

### 1. Clone the Repository

Open a terminal and clone this project to your local machine.

```bash
git clone https://github.com/garrid0/first-ROS2-project.git
cd first-ROS2-project
```

### 2. Build the Docker Image
From the root of the project directory, run the following command to build the container image:
```bash
docker compose build
```

### 3. Run docker image
After building the Docker image, run it with the following command :
```bash
docker compose up
```

### 3. Open Ubuntu desktop
Open http://localhost:6080 in your browser to access the Ubuntu MATE desktop.


### 4. Run the application
Inside ros2_ws directory run:
```bash
cd /ros2_ws
colcon build --symlink-install
source /ros2_ws/install/setup.bash
ros2 launch bump_and_go_pkg start_demo.launch.py
```




