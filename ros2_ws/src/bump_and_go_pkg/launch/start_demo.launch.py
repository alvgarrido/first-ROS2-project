# launch/start_demo.launch.py
import os
from ament_index_python.packages import get_package_share_path
from launch import LaunchDescription
from launch.actions import IncludeLaunchDescription, SetEnvironmentVariable, TimerAction
from launch.launch_description_sources import PythonLaunchDescriptionSource
from launch_ros.actions import Node

def generate_launch_description():
    gazebo_ros_share = get_package_share_path('gazebo_ros')
    tb3_gazebo_share = get_package_share_path('turtlebot3_gazebo')

    world_file = tb3_gazebo_share / 'worlds' / 'turtlebot3_world.world'
    model_file = tb3_gazebo_share / 'models' / 'turtlebot3_burger' / 'model.sdf'

    # Start Gazebo via gazebo_ros and explicitly load the ROS system plugins
    gazebo = IncludeLaunchDescription(
        PythonLaunchDescriptionSource(str(gazebo_ros_share / 'launch' / 'gazebo.launch.py')),
        launch_arguments={
            'world': str(world_file),
            'verbose': 'true',
            # This is the key bit that ensures /spawn_entity exists:
            'extra_gazebo_args': '-s libgazebo_ros_init.so -s libgazebo_ros_factory.so',
            # Show GUI; set to 'false' if you want headless
            'gui': 'true',
        }.items()
    )

    # Spawn the TurtleBot3 (delay a bit so /spawn_entity is ready)
    spawn = Node(
        package='gazebo_ros',
        executable='spawn_entity.py',
        arguments=[
            '-entity', 'burger',
            '-file', str(model_file),
            '-x', '-2.0', '-y', '-0.5', '-z', '0.01'
        ],
        output='screen'
    )
    spawn_after_gazebo = TimerAction(period=2.0, actions=[spawn])

    # Your bump-and-go driver
    driver = Node(
        package='bump_and_go_pkg',
        executable='driver',
        name='bump_and_go_driver',
        output='screen'
    )

    # Optional: RViz (you can keep or remove)
    rviz = Node(
        package='rviz2',
        executable='rviz2',
        name='rviz2',
        output='screen'
    )

    return LaunchDescription([
        # Env that helps in VNC/Xvfb environments and TB3 assets
        SetEnvironmentVariable('TURTLEBOT3_MODEL', 'burger'),
        SetEnvironmentVariable('GAZEBO_PLUGIN_PATH', '/opt/ros/humble/lib:' + os.environ.get('GAZEBO_PLUGIN_PATH', '')),
        SetEnvironmentVariable('GAZEBO_MODEL_PATH', '/opt/ros/humble/share/turtlebot3_gazebo/models:' + os.environ.get('GAZEBO_MODEL_PATH', '')),
        SetEnvironmentVariable('LIBGL_ALWAYS_SOFTWARE', '1'),
        SetEnvironmentVariable('QT_X11_NO_MITSHM', '1'),
        # Launch order
        gazebo,
        spawn_after_gazebo,
        driver,
        rviz,
    ])
